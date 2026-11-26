import AIStageCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct DockCellCentersKey: PreferenceKey {
    static let defaultValue: [String: CGPoint] = [:]
    static func reduce(value: inout [String: CGPoint], nextValue: () -> [String: CGPoint]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Focused Dock host rendering the notch-aware Dynamic Island (or EmptyView in Loop-only radial mode).
public struct DockView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @ObservedObject var coordinator: StageCoordinator
    @ObservedObject var interactionState: DockInteractionState
    let currentDockSize: () -> CGSize
    let currentPanelFrameAppKit: () -> CGRect
    let onOpenAddApp: () -> Void
    let onOpenSettings: () -> Void

    @Namespace private var glassSelectionNS
    @State private var hoveredBundleID: String?
    @State private var draggingBundleID: String?
    @State private var cellCenters: [String: CGPoint] = [:]

    private var iconSize: CGFloat { CGFloat(coordinator.settings.iconSize) }
    private var iconSpacing: CGFloat { CGFloat(coordinator.settings.iconSpacing) }
    private var islandContentPadding: CGFloat { max(8, CGFloat(coordinator.settings.islandContentPadding)) }
    private var adaptiveIndicatorSize: CGFloat { CGFloat(coordinator.settings.effectiveIndicatorSize) }
    private var pillWidth: CGFloat { iconSize + 8 }
    private var pillHeight: CGFloat { iconSize + 10 }
    private var pillCornerRadius: CGFloat { min(18, max(9, iconSize * 0.30)) }
    private var actionButtonSize: CGFloat { max(24, min(52, round(iconSize * 0.82))) }

    private var isIslandExpanded: Bool {
        coordinator.isDynamicIslandExpanded || coordinator.settings.dynamicIslandPinned
    }

    private var isAppleGlassIsland: Bool {
        coordinator.settings.dynamicIslandTheme == .appleGlass
    }

    private var islandEdge: DockEdgePosition {
        coordinator.settings.islandPosition
    }

    private var isCollapsedVertical: Bool {
        islandEdge.isVertical
    }

    private var isExpandedVertical: Bool {
        coordinator.settings.isExpandedIslandVertical
    }

    private var rootAlignment: Alignment {
        switch islandEdge {
        case .top: return .top
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }

    public var body: some View {
        ZStack(alignment: rootAlignment) {
            if coordinator.settings.dockShape == .dynamicIsland {
                dynamicIslandBody
            }
        }
        .coordinateSpace(name: "dockPanel")
        .onPreferenceChange(DockCellCentersKey.self) { updated in
            var changed = updated.count != cellCenters.count
            if !changed {
                for (k, v) in updated {
                    guard let prev = cellCenters[k], hypot(prev.x - v.x, prev.y - v.y) <= 1.5 else {
                        changed = true
                        break
                    }
                }
            }
            if changed {
                cellCenters = updated
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: rootAlignment)
    }

    private func magnificationScale(for bundleID: String) -> CGFloat {
        guard coordinator.settings.dockShape == .dynamicIsland,
              coordinator.settings.magnificationScale > 1.01,
              let pointer = interactionState.pointerInPanel,
              let center = cellCenters[bundleID]
        else { return 1.0 }

        let distance = isExpandedVertical ? abs(pointer.y - center.y) : abs(pointer.x - center.x)
        return StageSettings.magnificationFactor(
            distance: distance,
            iconSize: iconSize,
            maxScale: CGFloat(coordinator.settings.magnificationScale)
        )
    }

    // MARK: - Dynamic Island (Single-Shell Spring Morph & Magnetic Edge Drag)

    private var edgeUnitPoint: UnitPoint {
        switch islandEdge {
        case .top: return .top
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }

    private var contentSlideOffset: CGSize {
        switch islandEdge {
        case .top: return CGSize(width: 0, height: -10)
        case .bottom: return CGSize(width: 0, height: 10)
        case .left: return CGSize(width: -10, height: 0)
        case .right: return CGSize(width: 10, height: 0)
        }
    }

    private var collapsedStatusDotColor: Color {
        isAppleGlassIsland ? Color.primary.opacity(0.68) : Color.white.opacity(0.84)
    }

    private var dynamicIslandBody: some View {
        let p = min(1.0, max(0.0, interactionState.islandExpandProgress))
        let contentP = min(1.0, max(0.0, (p - 0.12) / 0.88))
        let anchor = edgeUnitPoint
        let slide = contentSlideOffset
        let topFlare: CGFloat = 10 + 4 * p
        let bottomRadius: CGFloat = 14 + 10 * p
        let islandShape = DynamicIslandShape(topFlare: topFlare, bottomRadius: bottomRadius, edge: islandEdge)

        return ZStack(alignment: rootAlignment) {
            islandBackground(
                topFlare: topFlare,
                bottomRadius: bottomRadius,
                progress: p
            )

            // Clip inner content strictly inside the Dynamic Island shell so scrolled icons
            // and bottom status dots can never leak outside the concave ear walls or glass rim.
            ZStack(alignment: rootAlignment) {
                if p < 0.98 {
                    let outP = min(1, p * 2.1)
                    collapsedDynamicIslandContent
                        .opacity(Double(max(0, 1 - outP)))
                        .scaleEffect(1.0 - 0.06 * min(1, p * 2), anchor: anchor)
                        .blur(radius: 5 * outP)
                        .allowsHitTesting(p < 0.35)
                }

                if p > 0.02 {
                    let remaining = 1 - contentP
                    expandedDynamicIslandContent
                        .opacity(Double(contentP))
                        .scaleEffect(0.92 + 0.08 * contentP, anchor: anchor)
                        .offset(x: slide.width * remaining, y: slide.height * remaining)
                        .blur(radius: 5 * remaining)
                        .allowsHitTesting(p > 0.45)
                }

                if coordinator.isDraggingDock, let previewEdge = coordinator.dragPreviewEdge {
                    dockSnapPreviewBanner(edge: previewEdge)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(islandShape)
        }
        .environment(\.colorScheme, isAppleGlassIsland ? systemColorScheme : .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dockSnapPreviewBanner(edge: DockEdgePosition) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "pin.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("松手固定到\(edge.label)")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(isAppleGlassIsland ? Color.primary : Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.75))
        )
        .shadow(color: Color.black.opacity(0.20), radius: 8, y: 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
    }

    private func glassMaterial(for style: AppleGlassStyle) -> NSVisualEffectView.Material {
        switch style {
        case .clear: return .underWindowBackground
        case .regular: return .hudWindow
        case .frosted: return .menu
        }
    }

    private func glassBlurAlpha(style: AppleGlassStyle, opacity: Double) -> CGFloat {
        switch style {
        case .clear: return min(1.0, max(0.42, CGFloat(0.42 + opacity * 0.75)))
        case .regular: return min(1.0, max(0.55, CGFloat(0.58 + opacity * 0.60)))
        case .frosted: return min(1.0, max(0.72, CGFloat(0.74 + opacity * 0.36)))
        }
    }

    @ViewBuilder
    private func islandBackground(topFlare: CGFloat, bottomRadius: CGFloat, progress: CGFloat) -> some View {
        let t = Double(min(1, max(0, progress)))
        let shape = DynamicIslandShape(topFlare: topFlare, bottomRadius: bottomRadius, edge: islandEdge)
        if isAppleGlassIsland {
            let isDark = systemColorScheme == .dark
            let style = coordinator.settings.glassStyle
            let frost = coordinator.settings.glassOpacity
            let spec = coordinator.settings.glassSpecularIntensity
            let material = glassMaterial(for: style)
            let blurAlpha = glassBlurAlpha(style: style, opacity: frost)
            let tintColors: [Color] = isDark
                ? [Color.white.opacity(frost * 0.32), Color.white.opacity(frost * 0.10)]
                : [Color.white.opacity(frost * 0.62), Color.white.opacity(frost * 0.22)]
            let rimColors: [Color] = [
                Color.white.opacity(isDark ? spec * 0.55 : spec * 0.92),
                Color.white.opacity(isDark ? spec * 0.16 : spec * 0.28),
                Color.white.opacity(isDark ? spec * 0.36 : spec * 0.62)
            ]

            ZStack {
                IslandFrostedBackdrop(
                    topFlare: topFlare,
                    bottomRadius: bottomRadius,
                    edge: islandEdge,
                    material: material,
                    blurAlpha: blurAlpha
                )

                shape
                    .fill(
                        LinearGradient(
                            colors: tintColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        shape.strokeBorder(
                            LinearGradient(
                                colors: rimColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                    )
                    .shadow(color: Color.black.opacity(0.16 + 0.08 * t), radius: 8 + 6 * t, y: 3 + 3 * t)
            }
        } else {
            // Interpolate everything with progress so shadow and rim never pop at a threshold.
            let isNotchTop = (islandEdge == .top && coordinator.screenHasNotch)
            let collapsedShadowAlpha = isNotchTop ? 0.24 : 0.34
            let collapsedShadowRadius: CGFloat = isNotchTop ? 5 : 9
            let rimAlpha = isNotchTop ? 0.14 * min(1, t * 2.5) : 0.14
            shape
                .fill(isNotchTop ? Color.black : Color.black.opacity(0.94))
                .overlay(
                    shape.strokeBorder(
                        Color.white.opacity(rimAlpha),
                        lineWidth: 0.7
                    )
                )
                .shadow(
                    color: Color.black.opacity(collapsedShadowAlpha + (0.45 - collapsedShadowAlpha) * t),
                    radius: collapsedShadowRadius + (18 - collapsedShadowRadius) * CGFloat(t),
                    y: 2 + 4 * CGFloat(t)
                )
        }
    }

    /// Active app first, then the other running apps (stage order). The active app is always
    /// shown, even when it is not running, so a hotkey switch is visible at a glance.
    private var collapsedIconApps: (active: StageAppItem?, others: [StageAppItem]) {
        let activeItem = coordinator.apps.first(where: { $0.bundleIdentifier == coordinator.activeBundleID })
            ?? coordinator.displayedApps.first
        let others = coordinator.apps.filter {
            $0.bundleIdentifier != activeItem?.bundleIdentifier
                && coordinator.runtimeInfo[$0.bundleIdentifier]?.isRunning == true
        }
        return (activeItem, others)
    }

    private func collapsedIcon(_ item: StageAppItem, size: CGFloat, isActive: Bool) -> some View {
        let badge: String? = coordinator.settings.showNotificationBadges
            ? coordinator.runtimeInfo[item.bundleIdentifier]?.badgeLabel
            : nil
        return Image(nsImage: coordinator.discovery.icon(for: item))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .opacity(isActive ? 1.0 : 0.86)
            .shadow(color: Color.black.opacity(isActive ? 0.22 : 0.0), radius: 1.5, y: 0.5)
            .overlay(alignment: .topTrailing) {
                if let badge, !badge.isEmpty {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.23, blue: 0.19))
                        .frame(width: 6.5, height: 6.5)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 0.8))
                        .shadow(color: Color.black.opacity(0.30), radius: 1.5, y: 0.5)
                        .offset(x: 2, y: -2)
                }
            }
            .help(item.displayName)
    }

    @ViewBuilder
    private func collapsedActiveIcon(_ item: StageAppItem?, size: CGFloat, labelColor: Color) -> some View {
        if let item {
            collapsedIcon(item, size: size, isActive: true)
                .id(item.bundleIdentifier)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(labelColor.opacity(0.86))
        }
    }

    private var collapsedDynamicIslandContent: some View {
        let (activeItem, otherRunningApps) = collapsedIconApps
        let statusColor = collapsedStatusDotColor
        let labelColor: Color = isAppleGlassIsland ? .primary : .white
        let activeSize: CGFloat = 20
        let otherSize: CGFloat = 15

        return ZStack {
            if isCollapsedVertical {
                VStack(spacing: 6) {
                    collapsedActiveIcon(activeItem, size: activeSize, labelColor: labelColor)
                    ForEach(otherRunningApps.prefix(4), id: \.bundleIdentifier) { item in
                        collapsedIcon(item, size: otherSize, isActive: false)
                    }
                    Spacer(minLength: 0)
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5.5, height: 5.5)
                        .shadow(color: Color.white.opacity(0.45), radius: 2.5)
                }
                .padding(.vertical, 12)
            } else if islandEdge == .top && coordinator.screenHasNotch {
                // The camera notch splits the island: current app on the left wing,
                // the other running apps on the right wing.
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                        collapsedActiveIcon(activeItem, size: activeSize, labelColor: labelColor)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 8)
                    .frame(maxWidth: .infinity)

                    Color.clear
                        .frame(width: coordinator.screenNotchWidth + 6)

                    HStack(spacing: 4) {
                        Spacer(minLength: 0)
                        // The wing beside the notch is 58pt: two icons plus the dot fit.
                        ForEach(otherRunningApps.prefix(2), id: \.bundleIdentifier) { item in
                            collapsedIcon(item, size: 14, isActive: false)
                        }
                        Circle()
                            .fill(statusColor)
                            .frame(width: 5.5, height: 5.5)
                            .shadow(color: Color.white.opacity(0.45), radius: 2.5)
                    }
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 10)
            } else {
                HStack(spacing: 7) {
                    collapsedActiveIcon(activeItem, size: activeSize, labelColor: labelColor)
                    ForEach(otherRunningApps.prefix(5), id: \.bundleIdentifier) { item in
                        collapsedIcon(item, size: otherSize, isActive: false)
                    }
                    Spacer(minLength: 2)
                    Circle()
                        .fill(statusColor)
                        .frame(width: 5.5, height: 5.5)
                        .shadow(color: Color.white.opacity(0.45), radius: 2.5)
                }
                .padding(.horizontal, 14)
            }

            whitespaceDragSurface(onTap: { coordinator.setDynamicIslandExpanded(true) })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.30, dampingFraction: 0.80), value: coordinator.activeBundleID)
        .contextMenu { overflowMenuItems }
        .help("点击展开或按住空白处拖动停靠到屏幕顶部、底端、左端、右端")
    }

    private func whitespaceDragSurface(onTap: (() -> Void)? = nil) -> some View {
        DockDragHandle(
            requiresDragThreshold: true,
            onTap: onTap,
            onDragStart: { coordinator.beginDockDrag() },
            onDragDeltaQuartz: { delta in coordinator.updateDockDrag(deltaQuartz: delta) },
            onDragEnd: { coordinator.endDockDrag() }
        )
    }

    private var expandedDynamicIslandContent: some View {
        let topBand: CGFloat = (islandEdge == .top && coordinator.screenHasNotch)
            ? max(32, coordinator.screenNotchHeight)
            : DisplayGeometry.islandHeaderInset
        let flareInset: CGFloat = 14

        return Group {
            if isExpandedVertical {
                VStack(spacing: 0) {
                    if islandEdge == .top && coordinator.screenHasNotch {
                        Color.clear
                            .frame(height: max(32, coordinator.screenNotchHeight))
                    }

                    GeometryReader { proxy in
                        let vAlign: HorizontalAlignment = islandEdge == .right ? .trailing : (islandEdge == .left ? .leading : .center)
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: vAlign, spacing: iconSpacing) {
                                groupedAppCells
                                inlineAddButton(size: actionButtonSize)
                                islandOverflowButton(size: actionButtonSize)
                            }
                            .padding(.vertical, islandContentPadding)
                            .padding(.horizontal, max(10, round(islandContentPadding * 0.55)))
                            .frame(
                                minWidth: max(0, proxy.size.width),
                                minHeight: max(0, proxy.size.height),
                                alignment: .center
                            )
                            .background {
                                whitespaceDragSurface()
                            }
                        }
                    }
                    .padding(.vertical, islandEdge.isVertical ? flareInset : 0)
                    .padding(.horizontal, !islandEdge.isVertical ? flareInset : 4)
                    .padding(.bottom, islandEdge == .top ? 8 : 0)
                    .padding(.top, islandEdge == .bottom ? 8 : 0)
                }
            } else {
                VStack(spacing: 0) {
                    if islandEdge == .bottom {
                        horizontalIslandTray
                            .padding(.horizontal, !islandEdge.isVertical ? flareInset : 0)
                            .padding(.top, 8)
                            .padding(.bottom, 2)
                        Color.clear.frame(height: topBand)
                    } else {
                        Color.clear.frame(height: topBand)
                        horizontalIslandTray
                            .padding(.horizontal, !islandEdge.isVertical ? flareInset : 0)
                            .padding(.top, 2)
                            .padding(.bottom, islandEdge == .top ? 8 : 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            whitespaceDragSurface()
        }
        .contextMenu { overflowMenuItems }
    }

    private var horizontalIslandTray: some View {
        let isBottom = (islandEdge == .bottom)
        return GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: isBottom ? .bottom : .top, spacing: iconSpacing) {
                    groupedAppCells
                    inlineAddButton(size: actionButtonSize)
                    islandOverflowButton(size: actionButtonSize)
                }
                .padding(.horizontal, islandContentPadding)
                .padding(.vertical, 2)
                .frame(minWidth: max(0, proxy.size.width), minHeight: max(0, proxy.size.height), alignment: .center)
                .background {
                    whitespaceDragSurface()
                }
            }
        }
    }

    /// Settings button in the tray right after "+", matching the app icon cell footprint and spacing.
    private func islandOverflowButton(size: CGFloat) -> some View {
        let iconTint: Color = isAppleGlassIsland ? .primary : .white
        return IslandSettingsButton(tint: iconTint, size: size, action: onOpenSettings)
            .frame(width: pillWidth + 2, height: pillHeight)
    }

    // MARK: - Grouped App Icons

    @ViewBuilder
    private var groupedAppCells: some View {
        let runningApps = coordinator.runningDisplayedApps
        let inactiveApps = coordinator.inactiveDisplayedApps
        let showSeparator = coordinator.settings.sortRunningAppsFirst
            && !runningApps.isEmpty
            && !inactiveApps.isEmpty

        Group {
            if isExpandedVertical {
                VStack(alignment: .center, spacing: iconSpacing) {
                    ForEach(Array(runningApps.enumerated()), id: \.element.bundleIdentifier) { idx, item in
                        makeIconCell(item: item, globalIndex: idx)
                    }
                    if showSeparator {
                        Capsule()
                            .fill(Color.primary.opacity(0.22))
                            .frame(width: max(18, iconSize * 0.62), height: 1)
                            .padding(.vertical, 2)
                    }
                    ForEach(Array(inactiveApps.enumerated()), id: \.element.bundleIdentifier) { offset, item in
                        makeIconCell(item: item, globalIndex: runningApps.count + offset)
                    }
                }
            } else {
                HStack(alignment: islandEdge == .bottom ? .bottom : .top, spacing: iconSpacing) {
                    ForEach(Array(runningApps.enumerated()), id: \.element.bundleIdentifier) { idx, item in
                        makeIconCell(item: item, globalIndex: idx)
                    }
                    if showSeparator {
                        Capsule()
                            .fill(Color.primary.opacity(0.22))
                            .frame(width: 1, height: max(18, iconSize * 0.62))
                            .padding(.horizontal, 2)
                    }
                    ForEach(Array(inactiveApps.enumerated()), id: \.element.bundleIdentifier) { offset, item in
                        makeIconCell(item: item, globalIndex: runningApps.count + offset)
                    }
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.80), value: coordinator.activeBundleID)
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: coordinator.displayedApps.map(\.bundleIdentifier))
    }

    private func makeIconCell(item: StageAppItem, globalIndex: Int) -> some View {
        let waveScale = magnificationScale(for: item.bundleIdentifier)
        let baseSlotW = pillWidth + (isExpandedVertical ? 8 : 2)
        let baseSlotH = pillHeight + max(4, adaptiveIndicatorSize + 1) + 2
        let extraSpread = (waveScale - 1.0) * iconSize * 0.56
        let slotW = isExpandedVertical ? baseSlotW : (baseSlotW + extraSpread)
        let slotH = isExpandedVertical ? (baseSlotH + extraSpread) : baseSlotH
        let cellAlignment: Alignment = switch islandEdge {
        case .top: isExpandedVertical ? .center : .top
        case .bottom: isExpandedVertical ? .center : .bottom
        case .left: isExpandedVertical ? .leading : .center
        case .right: isExpandedVertical ? .trailing : .center
        }

        return DockAppIconCell(
            item: item,
            index: globalIndex,
            iconImage: coordinator.discovery.icon(for: item),
            runtime: coordinator.runtimeInfo[item.bundleIdentifier] ?? AppRuntimeInfo(),
            settings: coordinator.settings,
            iconSize: iconSize,
            adaptiveIndicatorSize: adaptiveIndicatorSize,
            pillWidth: pillWidth,
            pillHeight: pillHeight,
            pillCornerRadius: pillCornerRadius,
            waveScale: waveScale,
            islandEdge: islandEdge,
            isVerticalLayout: isExpandedVertical,
            isPrimaryActive: coordinator.activeBundleID == item.bundleIdentifier,
            isSplitSecondary: coordinator.splitSecondaryBundleID == item.bundleIdentifier,
            isSplitMode: coordinator.layoutMode == .split2,
            isLaunching: coordinator.launchingBundleIDs.contains(item.bundleIdentifier),
            isHovered: hoveredBundleID == item.bundleIdentifier,
            bounceTrigger: (coordinator.lastSwitchedBundleID == item.bundleIdentifier) ? coordinator.switchBounceTick : 0,
            glassNamespace: glassSelectionNS,
            onClick: { isCmd, isOpt in
                let sourceIconRect: CGRect? = {
                    let panelFrame = currentPanelFrameAppKit()
                    guard panelFrame.width > 1,
                          let localCenter = cellCenters[item.bundleIdentifier]
                    else { return nil }
                    let appKitCenterX = panelFrame.minX + localCenter.x
                    let appKitCenterY = panelFrame.maxY - localCenter.y
                    let side = iconSize * waveScale
                    return CGRect(
                        x: appKitCenterX - side * 0.5,
                        y: appKitCenterY - side * 0.5,
                        width: side,
                        height: side
                    )
                }()
                withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                    coordinator.handleIconClick(
                        bundleID: item.bundleIdentifier,
                        isCommandPressed: isCmd,
                        isOptionPressed: isOpt,
                        sourceIconRectAppKit: sourceIconRect
                    )
                }
            },
            onPullToCurrentScreen: {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                    coordinator.switchToApp(bundleID: item.bundleIdentifier, forceAlignToDockScreen: true)
                }
            },
            onSplitWithCurrent: {
                if let current = coordinator.activeBundleID, current != item.bundleIdentifier {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                        coordinator.enterSplitMode(leftBundleID: current, rightBundleID: item.bundleIdentifier)
                    }
                } else {
                    coordinator.switchToApp(bundleID: item.bundleIdentifier)
                }
            },
            onExitSplit: {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                    coordinator.exitSplitMode()
                }
            },
            onRelaunch: { coordinator.relaunchApp(bundleID: item.bundleIdentifier) },
            onQuit: { coordinator.quitApp(bundleID: item.bundleIdentifier) },
            onReveal: { coordinator.revealInFinder(bundleID: item.bundleIdentifier) },
            onRemove: { coordinator.removeApp(bundleID: item.bundleIdentifier) }
        )
        .frame(width: slotW, height: slotH, alignment: cellAlignment)
        .zIndex(Double(waveScale))
        .background {
            GeometryReader { geo in
                let frame = geo.frame(in: .named("dockPanel"))
                Color.clear.preference(
                    key: DockCellCentersKey.self,
                    value: [item.bundleIdentifier: CGPoint(x: frame.midX, y: frame.midY)]
                )
            }
        }
        .animation(.interactiveSpring(response: 0.16, dampingFraction: 0.78), value: waveScale)
        .onHover { hovering in
            withAnimation(.spring(response: 0.18, dampingFraction: 0.76)) {
                hoveredBundleID = hovering ? item.bundleIdentifier : (hoveredBundleID == item.bundleIdentifier ? nil : hoveredBundleID)
            }
        }
        .onDrag {
            draggingBundleID = item.bundleIdentifier
            return NSItemProvider(object: item.bundleIdentifier as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: DockIconDropDelegate(
                targetBundleID: item.bundleIdentifier,
                draggingBundleID: $draggingBundleID,
                coordinator: coordinator
            )
        )
    }

    private static let addButtonCellKey = "__aistage_add_button__"

    private func addButtonProximity() -> CGFloat {
        guard let pointer = interactionState.pointerInPanel,
              let center = cellCenters[Self.addButtonCellKey]
        else { return 0.0 }
        let dist = hypot(pointer.x - center.x, pointer.y - center.y)
        let radius = max(iconSize * 2.6, 124)
        guard dist < radius else { return 0.0 }
        let t = max(0, 1.0 - dist / radius)
        return 0.5 * (1.0 - cos(t * .pi))
    }

    private func inlineAddButton(size: CGFloat) -> some View {
        let tint: Color = isAppleGlassIsland ? .primary : .white
        let p = addButtonProximity()
        let bgTop = tint.opacity(0.05 + 0.21 * p)
        let bgBot = tint.opacity(0.02 + 0.09 * p)
        let borderAlpha = 0.09 + 0.45 * p
        let iconAlpha = 0.28 + 0.70 * p

        return Button(action: onOpenAddApp) {
            Image(systemName: "plus")
                .font(.system(size: max(13, size * 0.42), weight: .semibold))
                .foregroundStyle(tint.opacity(iconAlpha))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [bgTop, bgBot],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(tint.opacity(borderAlpha), lineWidth: 0.75)
                        )
                )
                .shadow(color: tint.opacity(0.24 * p), radius: 3 + 6 * p)
                .scaleEffect(1.0 + 0.06 * p)
        }
        .buttonStyle(.plain)
        .frame(width: pillWidth + 2, height: pillHeight)
        .background {
            GeometryReader { geo in
                let frame = geo.frame(in: .named("dockPanel"))
                Color.clear.preference(
                    key: DockCellCentersKey.self,
                    value: [Self.addButtonCellKey: CGPoint(x: frame.midX, y: frame.midY)]
                )
            }
        }
        .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.80), value: p)
        .help("添加应用到工作台")
    }

    @ViewBuilder
    private var overflowMenuItems: some View {
        if coordinator.layoutMode == .split2 {
            Button("退出双屏对比") {
                coordinator.exitSplitMode()
            }
        }
        Button("添加应用…", action: onOpenAddApp)
        Divider()
        Button("偏好设置…", action: onOpenSettings)
    }
}

// MARK: - App Icon Cell inside Dynamic Island

private struct DockAppIconCell: View {
    @Environment(\.colorScheme) private var systemColorScheme
    let item: StageAppItem
    let index: Int
    let iconImage: NSImage
    let runtime: AppRuntimeInfo
    let settings: StageSettings
    let iconSize: CGFloat
    let adaptiveIndicatorSize: CGFloat
    let pillWidth: CGFloat
    let pillHeight: CGFloat
    let pillCornerRadius: CGFloat
    let waveScale: CGFloat
    let islandEdge: DockEdgePosition
    let isVerticalLayout: Bool
    let isPrimaryActive: Bool
    let isSplitSecondary: Bool
    let isSplitMode: Bool
    let isLaunching: Bool
    let isHovered: Bool
    let bounceTrigger: Int
    let glassNamespace: Namespace.ID

    let onClick: (Bool, Bool) -> Void
    let onPullToCurrentScreen: () -> Void
    let onSplitWithCurrent: () -> Void
    let onExitSplit: () -> Void
    let onRelaunch: () -> Void
    let onQuit: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void

    @State private var isPressed = false
    @State private var bounceOffsetY: CGFloat = 0

    private var isDarkSurface: Bool {
        settings.dynamicIslandTheme != .appleGlass || systemColorScheme == .dark
    }

    private var tooltipText: String {
        var parts: [String] = [item.displayName]
        if let prefix = settings.numberSwitchModifier.symbolPrefix, index < 9 {
            parts.append("\(prefix)\(index + 1)")
        }
        if isLaunching {
            parts.append("启动中…")
        } else if runtime.isRunning {
            parts.append(runtime.memoryMB > 0 ? "运行中 · \(runtime.memoryMB) MB" : "运行中")
        } else {
            parts.append("未运行（点击启动）")
        }
        if let badge = runtime.badgeLabel, !badge.isEmpty {
            parts.append("未读 \(badge)")
        }
        parts.append("⌘+点击双屏")
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let effectiveScale: CGFloat = isPressed ? (waveScale * 0.90) : (waveScale > 1.02 ? waveScale : (isHovered ? 1.12 : 1.0))
        let lift = max(0, waveScale - 1.0) * iconSize * 0.14
        let spacingBelowIcon: CGFloat = max(2.0, round(iconSize * 0.055))
        let isParallelAxis = (isVerticalLayout == islandEdge.isVertical)
        let scaleAnchor: UnitPoint = if isParallelAxis {
            switch islandEdge {
            case .top: .top
            case .bottom: .bottom
            case .left: .leading
            case .right: .trailing
            }
        } else {
            .center
        }
        let waveOffsetX: CGFloat = isParallelAxis
            ? (islandEdge == .left ? (lift + bounceOffsetY) : (islandEdge == .right ? -(lift + bounceOffsetY) : 0))
            : 0
        let waveOffsetY: CGFloat = isParallelAxis
            ? (islandEdge == .top ? (lift + bounceOffsetY) : (islandEdge == .bottom ? -(lift + bounceOffsetY) : 0))
            : (isVerticalLayout ? 0 : -(lift * 0.45 + bounceOffsetY * 0.5))

        VStack(spacing: spacingBelowIcon) {
            ZStack {
                if isPrimaryActive {
                    let fillTop = isDarkSurface ? Color.white.opacity(0.18) : Color.white.opacity(0.52)
                    let fillBot = isDarkSurface ? Color.white.opacity(0.06) : Color.white.opacity(0.20)
                    let rimTop = isDarkSurface ? Color.white.opacity(0.34) : Color.white.opacity(0.82)
                    let rimBot = isDarkSurface ? Color.white.opacity(0.08) : Color.white.opacity(0.20)
                    RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                        .fill(LinearGradient(colors: [fillTop, fillBot], startPoint: .top, endPoint: .bottom))
                        .overlay(
                            RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(colors: [rimTop, rimBot], startPoint: .top, endPoint: .bottom),
                                    lineWidth: 0.75
                                )
                        )
                        .shadow(color: Color.black.opacity(isDarkSurface ? 0.20 : 0.08), radius: 4, y: 1.5)
                        .frame(width: pillWidth, height: pillHeight)
                        .matchedGeometryEffect(id: "activeGlassPlatter", in: glassNamespace)
                }

                if isSplitSecondary {
                    RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: pillCornerRadius, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.65), lineWidth: 1)
                        )
                        .frame(width: pillWidth, height: pillHeight)
                }

                Image(nsImage: iconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .overlay(alignment: .topTrailing) {
                        if settings.showNotificationBadges, let badge = runtime.badgeLabel, !badge.isEmpty {
                            MacDockRedBadge(label: badge)
                                .offset(x: 4, y: -3)
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                        }
                    }
                    .scaleEffect(effectiveScale, anchor: scaleAnchor)
                    .offset(x: waveOffsetX, y: waveOffsetY)
                    .zIndex(10)
                    .shadow(
                        color: Color.black.opacity(effectiveScale > 1.05 ? 0.30 : 0.18),
                        radius: effectiveScale > 1.05 ? 6 : 2.5,
                        y: effectiveScale > 1.05 ? 3.5 : 1.5
                    )
            }
            .frame(width: pillWidth, height: pillHeight)
            .overlay(alignment: .topLeading) {
                if isSplitMode && (isPrimaryActive || isSplitSecondary) {
                    Text(isPrimaryActive ? "L" : "R")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor.opacity(0.92)))
                        .shadow(color: Color.black.opacity(0.22), radius: 2, y: 1)
                        .offset(x: -1, y: -1)
                }
            }

            statusIndicatorView
                .frame(height: max(4, adaptiveIndicatorSize + 1))
        }
        .frame(width: pillWidth + 2)
        .contentShape(Rectangle())
        .onChange(of: bounceTrigger) {
            guard settings.animateOpeningApps, bounceTrigger > 0 else { return }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.50)) {
                bounceOffsetY = 5.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.58)) {
                    bounceOffsetY = 0
                }
            }
        }
        .onTapGesture {
            let flags = NSEvent.modifierFlags
            let cmdPressed = flags.contains(.command)
            let optPressed = flags.contains(.option)
            withAnimation(.spring(response: 0.15, dampingFraction: 0.70)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                    isPressed = false
                }
            }
            onClick(cmdPressed, optPressed)
        }
        .help(tooltipText)
        .contextMenu {
            Button("切换到 \(item.displayName)") { onClick(false, false) }
            Button("拉回到当前舞台屏 (⌥+点击)") { onPullToCurrentScreen() }
            if !isPrimaryActive {
                Button("与当前应用双屏对比 (⌘+点击)") { onSplitWithCurrent() }
            }
            if isSplitMode {
                Button("退出双屏对比") { onExitSplit() }
            }
            Divider()
            if runtime.isRunning {
                if runtime.memoryMB > 0 {
                    Text("当前内存占用：\(runtime.memoryMB) MB")
                }
                Button("重新启动") { onRelaunch() }
                Button("彻底退出（释放内存）") { onQuit() }
            } else {
                Button("启动应用") { onClick(false, false) }
            }
            Divider()
            Button("在访达中显示") { onReveal() }
            Button("从列表移除", role: .destructive) { onRemove() }
        }
    }

    @ViewBuilder
    private var statusIndicatorView: some View {
        let style = settings.indicatorStyle
        let baseSize = max(3.6, adaptiveIndicatorSize * 0.90)
        let activeW = min(16, max(12, iconSize * 0.30))
        let activeH = max(3.2, min(4.0, adaptiveIndicatorSize * 0.78))
        let shouldShow = isPrimaryActive || (style != .hidden && (runtime.isRunning || isLaunching || settings.showInactiveIndicator))

        if shouldShow {
            let fillColor = resolvedIndicatorColor
            let indW: CGFloat = isPrimaryActive
                ? activeW
                : (style == .pill ? max(8, baseSize * 2.1) : baseSize)
            let indH: CGFloat = isPrimaryActive
                ? activeH
                : (style == .pill ? max(2.2, baseSize * 0.56) : baseSize)
            let haloColor: Color = isPrimaryActive
                ? (isDarkSurface ? Color.white.opacity(0.55) : Color.primary.opacity(0.28))
                : fillColor.opacity(runtime.isRunning ? 0.30 : 0.0)
            let haloRadius: CGFloat = isPrimaryActive ? 3.5 : (runtime.isRunning ? 1.5 : 0)

            Capsule()
                .fill(fillColor)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(isPrimaryActive ? 0.35 : 0.0), lineWidth: 0.5)
                )
                .frame(width: indW, height: indH)
                .shadow(color: haloColor, radius: haloRadius)
                .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isPrimaryActive)
        } else {
            Color.clear.frame(width: 1, height: baseSize)
        }
    }

    private var resolvedIndicatorColor: Color {
        if isLaunching { return Color(red: 1.0, green: 0.72, blue: 0.25) }
        if isPrimaryActive {
            switch settings.indicatorColor {
            case .classic:
                return isDarkSurface ? Color.white.opacity(0.92) : Color.primary.opacity(0.84)
            case .emerald:
                return Color(red: 0.20, green: 0.82, blue: 0.48)
            case .accent:
                return .accentColor
            case .skyBlue:
                return Color(red: 0.22, green: 0.68, blue: 1.0)
            case .amber:
                return Color(red: 1.0, green: 0.65, blue: 0.16)
            }
        }
        guard runtime.isRunning else { return Color.primary.opacity(0.16) }
        switch settings.indicatorColor {
        case .classic:
            return isDarkSurface ? Color.white.opacity(0.54) : Color.primary.opacity(0.45)
        case .emerald:
            return Color(red: 0.20, green: 0.82, blue: 0.48)
        case .accent:
            return .accentColor
        case .skyBlue:
            return Color(red: 0.22, green: 0.68, blue: 1.0)
        case .amber:
            return Color(red: 1.0, green: 0.65, blue: 0.16)
        }
    }
}

private struct MacDockRedBadge: View {
    let label: String
    private var displayLabel: String { label.count > 3 ? "99+" : label }

    var body: some View {
        let isSingleChar = displayLabel.count <= 1
        Text(displayLabel)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, isSingleChar ? 0 : 4.5)
            .frame(minWidth: 16, minHeight: 16)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.27, blue: 0.23),
                                Color(red: 0.90, green: 0.16, blue: 0.14)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5))
            )
            .shadow(color: Color.black.opacity(0.28), radius: 2.5, y: 1)
    }
}

private struct DockIconDropDelegate: DropDelegate {
    let targetBundleID: String
    @Binding var draggingBundleID: String?
    let coordinator: StageCoordinator

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingBundleID, dragging != targetBundleID else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            coordinator.moveApp(fromBundleID: dragging, toBundleID: targetBundleID)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingBundleID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Apple Hardware-Notch Concave Dynamic Island Shape

private struct DynamicIslandShape: InsettableShape {
    let topFlare: CGFloat
    let bottomRadius: CGFloat
    let edge: DockEdgePosition
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let r = edge.isVertical ? rect.insetBy(dx: 0, dy: insetAmount) : rect.insetBy(dx: insetAmount, dy: 0)
        guard r.width > 8, r.height > 8 else {
            return Path(r)
        }
        let span = edge.isVertical ? r.height : r.width
        let depth = edge.isVertical ? r.width : r.height
        let flare = min(topFlare, span * 0.14)
        let maxSideRadius = max(2, depth - flare - 2)
        let br = min(bottomRadius, min(maxSideRadius, (span - flare * 2) * 0.36))

        var p = Path()
        switch edge {
        case .top:
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.minX + flare, y: r.minY + flare), control: CGPoint(x: r.minX + flare, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX + flare, y: r.maxY - insetAmount - br))
            p.addQuadCurve(to: CGPoint(x: r.minX + flare + br, y: r.maxY - insetAmount), control: CGPoint(x: r.minX + flare, y: r.maxY - insetAmount))
            p.addLine(to: CGPoint(x: r.maxX - flare - br, y: r.maxY - insetAmount))
            p.addQuadCurve(to: CGPoint(x: r.maxX - flare, y: r.maxY - insetAmount - br), control: CGPoint(x: r.maxX - flare, y: r.maxY - insetAmount))
            p.addLine(to: CGPoint(x: r.maxX - flare, y: r.minY + flare))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.maxX - flare, y: r.minY))
        case .bottom:
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.minX + flare, y: r.maxY - flare), control: CGPoint(x: r.minX + flare, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + flare, y: r.minY + insetAmount + br))
            p.addQuadCurve(to: CGPoint(x: r.minX + flare + br, y: r.minY + insetAmount), control: CGPoint(x: r.minX + flare, y: r.minY + insetAmount))
            p.addLine(to: CGPoint(x: r.maxX - flare - br, y: r.minY + insetAmount))
            p.addQuadCurve(to: CGPoint(x: r.maxX - flare, y: r.minY + insetAmount + br), control: CGPoint(x: r.maxX - flare, y: r.minY + insetAmount))
            p.addLine(to: CGPoint(x: r.maxX - flare, y: r.maxY - flare))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.maxX - flare, y: r.maxY))
        case .left:
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.minX + flare, y: r.minY + flare), control: CGPoint(x: r.minX, y: r.minY + flare))
            p.addLine(to: CGPoint(x: r.maxX - insetAmount - br, y: r.minY + flare))
            p.addQuadCurve(to: CGPoint(x: r.maxX - insetAmount, y: r.minY + flare + br), control: CGPoint(x: r.maxX - insetAmount, y: r.minY + flare))
            p.addLine(to: CGPoint(x: r.maxX - insetAmount, y: r.maxY - flare - br))
            p.addQuadCurve(to: CGPoint(x: r.maxX - insetAmount - br, y: r.maxY - flare), control: CGPoint(x: r.maxX - insetAmount, y: r.maxY - flare))
            p.addLine(to: CGPoint(x: r.minX + flare, y: r.maxY - flare))
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY), control: CGPoint(x: r.minX, y: r.maxY - flare))
        case .right:
            p.move(to: CGPoint(x: r.maxX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX - flare, y: r.minY + flare), control: CGPoint(x: r.maxX, y: r.minY + flare))
            p.addLine(to: CGPoint(x: r.minX + insetAmount + br, y: r.minY + flare))
            p.addQuadCurve(to: CGPoint(x: r.minX + insetAmount, y: r.minY + flare + br), control: CGPoint(x: r.minX + insetAmount, y: r.minY + flare))
            p.addLine(to: CGPoint(x: r.minX + insetAmount, y: r.maxY - flare - br))
            p.addQuadCurve(to: CGPoint(x: r.minX + insetAmount + br, y: r.maxY - flare), control: CGPoint(x: r.minX + insetAmount, y: r.maxY - flare))
            p.addLine(to: CGPoint(x: r.maxX - flare, y: r.maxY - flare))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY - flare))
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Apple Frosted Island Backdrop (NSVisualEffectView OUTSIDE .compositingGroup)

private struct IslandFrostedBackdrop: NSViewRepresentable {
    let topFlare: CGFloat
    let bottomRadius: CGFloat
    let edge: DockEdgePosition
    let material: NSVisualEffectView.Material
    let blurAlpha: CGFloat

    func makeNSView(context: Context) -> MaskedIslandVisualEffectView {
        let view = MaskedIslandVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.alphaValue = blurAlpha
        view.topFlare = topFlare
        view.bottomRadius = bottomRadius
        view.edge = edge
        return view
    }

    func updateNSView(_ nsView: MaskedIslandVisualEffectView, context: Context) {
        nsView.material = material
        nsView.alphaValue = blurAlpha
        nsView.topFlare = topFlare
        nsView.bottomRadius = bottomRadius
        nsView.edge = edge
        nsView.refreshMaskIfNeeded()
    }
}

private final class MaskedIslandVisualEffectView: NSVisualEffectView {
    var topFlare: CGFloat = 10
    var bottomRadius: CGFloat = 14
    var edge: DockEdgePosition = .top
    private var lastMaskSize: CGSize = .zero
    private var lastFlare: CGFloat = -1
    private var lastBottomRadius: CGFloat = -1
    private var lastEdge: DockEdgePosition?

    override func layout() {
        super.layout()
        refreshMaskIfNeeded()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        refreshMaskIfNeeded()
    }

    func refreshMaskIfNeeded() {
        let sz = bounds.size
        guard sz.width > 8, sz.height > 8 else { return }
        guard abs(sz.width - lastMaskSize.width) > 0.5
            || abs(sz.height - lastMaskSize.height) > 0.5
            || abs(topFlare - lastFlare) > 0.25
            || abs(bottomRadius - lastBottomRadius) > 0.25
            || edge != lastEdge
        else { return }

        lastMaskSize = sz
        lastFlare = topFlare
        lastBottomRadius = bottomRadius
        lastEdge = edge

        let span = edge.isVertical ? sz.height : sz.width
        let depth = edge.isVertical ? sz.width : sz.height
        let flare = min(topFlare, span * 0.14)
        let maxSideRadius = max(2, depth - flare - 2)
        let br = min(bottomRadius, min(maxSideRadius, (span - flare * 2) * 0.36))
        let targetEdge = edge

        maskImage = NSImage(size: sz, flipped: true) { r in
            let p = NSBezierPath()
            switch targetEdge {
            case .top:
                p.move(to: NSPoint(x: r.minX, y: r.minY))
                Self.addQuad(to: p, from: NSPoint(x: r.minX, y: r.minY), control: NSPoint(x: r.minX + flare, y: r.minY), end: NSPoint(x: r.minX + flare, y: r.minY + flare))
                p.line(to: NSPoint(x: r.minX + flare, y: r.maxY - br))
                Self.addQuad(to: p, from: NSPoint(x: r.minX + flare, y: r.maxY - br), control: NSPoint(x: r.minX + flare, y: r.maxY), end: NSPoint(x: r.minX + flare + br, y: r.maxY))
                p.line(to: NSPoint(x: r.maxX - flare - br, y: r.maxY))
                Self.addQuad(to: p, from: NSPoint(x: r.maxX - flare - br, y: r.maxY), control: NSPoint(x: r.maxX - flare, y: r.maxY), end: NSPoint(x: r.maxX - flare, y: r.maxY - br))
                p.line(to: NSPoint(x: r.maxX - flare, y: r.minY + flare))
                Self.addQuad(to: p, from: NSPoint(x: r.maxX - flare, y: r.minY + flare), control: NSPoint(x: r.maxX - flare, y: r.minY), end: NSPoint(x: r.maxX, y: r.minY))
            case .bottom:
                p.move(to: NSPoint(x: r.minX, y: r.maxY))
                Self.addQuad(to: p, from: NSPoint(x: r.minX, y: r.maxY), control: NSPoint(x: r.minX + flare, y: r.maxY), end: NSPoint(x: r.minX + flare, y: r.maxY - flare))
                p.line(to: NSPoint(x: r.minX + flare, y: r.minY + br))
                Self.addQuad(to: p, from: NSPoint(x: r.minX + flare, y: r.minY + br), control: NSPoint(x: r.minX + flare, y: r.minY), end: NSPoint(x: r.minX + flare + br, y: r.minY))
                p.line(to: NSPoint(x: r.maxX - flare - br, y: r.minY))
                Self.addQuad(to: p, from: NSPoint(x: r.maxX - flare - br, y: r.minY), control: NSPoint(x: r.maxX - flare, y: r.minY), end: NSPoint(x: r.maxX - flare, y: r.minY + br))
                p.line(to: NSPoint(x: r.maxX - flare, y: r.maxY - flare))
                Self.addQuad(to: p, from: NSPoint(x: r.maxX - flare, y: r.maxY - flare), control: NSPoint(x: r.maxX - flare, y: r.maxY), end: NSPoint(x: r.maxX, y: r.maxY))
            case .left:
                p.move(to: NSPoint(x: r.minX, y: r.minY))
                Self.addQuad(to: p, from: NSPoint(x: r.minX, y: r.minY), control: NSPoint(x: r.minX, y: r.minY + flare), end: NSPoint(x: r.minX + flare, y: r.minY + flare))
                p.line(to: NSPoint(x: r.maxX - br, y: r.minY + flare))
                Self.addQuad(to: p, from: NSPoint(x: r.maxX - br, y: r.minY + flare), control: NSPoint(x: r.maxX, y: r.minY + flare), end: NSPoint(x: r.maxX, y: r.minY + flare + br))
                p.line(to: NSPoint(x: r.maxX, y: r.maxY - flare - br))
                Self.addQuad(to: p, from: NSPoint(x: r.maxX, y: r.maxY - flare - br), control: NSPoint(x: r.maxX, y: r.maxY - flare), end: NSPoint(x: r.maxX - br, y: r.maxY - flare))
                p.line(to: NSPoint(x: r.minX + flare, y: r.maxY - flare))
                Self.addQuad(to: p, from: NSPoint(x: r.minX + flare, y: r.maxY - flare), control: NSPoint(x: r.minX, y: r.maxY - flare), end: NSPoint(x: r.minX, y: r.maxY))
            case .right:
                p.move(to: NSPoint(x: r.maxX, y: r.minY))
                Self.addQuad(to: p, from: NSPoint(x: r.maxX, y: r.minY), control: NSPoint(x: r.maxX, y: r.minY + flare), end: NSPoint(x: r.maxX - flare, y: r.minY + flare))
                p.line(to: NSPoint(x: r.minX + br, y: r.minY + flare))
                Self.addQuad(to: p, from: NSPoint(x: r.minX + br, y: r.minY + flare), control: NSPoint(x: r.minX, y: r.minY + flare), end: NSPoint(x: r.minX, y: r.minY + flare + br))
                p.line(to: NSPoint(x: r.minX, y: r.maxY - flare - br))
                Self.addQuad(to: p, from: NSPoint(x: r.minX, y: r.maxY - flare - br), control: NSPoint(x: r.minX, y: r.maxY - flare), end: NSPoint(x: r.minX + br, y: r.maxY - flare))
                p.line(to: NSPoint(x: r.maxX - flare, y: r.maxY - flare))
                Self.addQuad(to: p, from: NSPoint(x: r.maxX - flare, y: r.maxY - flare), control: NSPoint(x: r.maxX, y: r.maxY - flare), end: NSPoint(x: r.maxX, y: r.maxY))
            }
            p.close()
            NSColor.black.setFill()
            p.fill()
            return true
        }
    }

    private static func addQuad(to path: NSBezierPath, from p0: NSPoint, control c: NSPoint, end p2: NSPoint) {
        let cp1 = NSPoint(x: p0.x + (c.x - p0.x) * (2.0 / 3.0), y: p0.y + (c.y - p0.y) * (2.0 / 3.0))
        let cp2 = NSPoint(x: p2.x + (c.x - p2.x) * (2.0 / 3.0), y: p2.y + (c.y - p2.y) * (2.0 / 3.0))
        path.curve(to: p2, controlPoint1: cp1, controlPoint2: cp2)
    }
}

// MARK: - Native Drag Handle

private struct DockDragHandle: NSViewRepresentable {
    var requiresDragThreshold: Bool = true
    var onTap: (() -> Void)? = nil
    let onDragStart: () -> Void
    let onDragDeltaQuartz: (CGPoint) -> Void
    let onDragEnd: () -> Void

    func makeNSView(context: Context) -> DockDragNSView {
        let view = DockDragNSView()
        view.requiresDragThreshold = requiresDragThreshold
        view.onTap = onTap
        view.onDragStart = onDragStart
        view.onDragDeltaQuartz = onDragDeltaQuartz
        view.onDragEnd = onDragEnd
        return view
    }

    func updateNSView(_ nsView: DockDragNSView, context: Context) {
        nsView.requiresDragThreshold = requiresDragThreshold
        nsView.onTap = onTap
        nsView.onDragStart = onDragStart
        nsView.onDragDeltaQuartz = onDragDeltaQuartz
        nsView.onDragEnd = onDragEnd
    }
}

private final class DockDragNSView: NSView {
    var requiresDragThreshold = true
    var onTap: (() -> Void)?
    var onDragStart: (() -> Void)?
    var onDragDeltaQuartz: ((CGPoint) -> Void)?
    var onDragEnd: (() -> Void)?

    private var dragStartMouseAppKit: NSPoint?
    private var hasStartedDrag = false

    override func mouseDown(with event: NSEvent) {
        dragStartMouseAppKit = NSEvent.mouseLocation
        hasStartedDrag = !requiresDragThreshold
        if hasStartedDrag {
            NSCursor.closedHand.set()
            onDragStart?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStartMouseAppKit else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - start.x
        let dyQuartz = -(current.y - start.y)
        if !hasStartedDrag {
            guard hypot(dx, dyQuartz) >= 6.0 else { return }
            hasStartedDrag = true
            NSCursor.closedHand.set()
            onDragStart?()
        }
        onDragDeltaQuartz?(CGPoint(x: dx, y: dyQuartz))
    }

    override func mouseUp(with event: NSEvent) {
        let didDrag = hasStartedDrag
        dragStartMouseAppKit = nil
        hasStartedDrag = false
        if didDrag {
            NSCursor.arrow.set()
            onDragEnd?()
        } else {
            onTap?()
        }
    }
}


/// Direct settings button drawn in the same circle language as the inline "+" button: a faint plate
/// at rest that brightens on hover.
private struct IslandSettingsButton: View {
    let tint: Color
    let size: CGFloat
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: max(12, size * 0.38), weight: .semibold))
                .foregroundStyle(tint.opacity(isHovered ? 0.98 : 0.45))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(width: size, height: size)
        .background(
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(isHovered ? 0.26 : 0.05), tint.opacity(isHovered ? 0.11 : 0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(Circle().strokeBorder(tint.opacity(isHovered ? 0.50 : 0.09), lineWidth: 0.75))
        )
        .scaleEffect(isHovered ? 1.06 : 1.0)
        .animation(reduceMotion ? nil : .interactiveSpring(response: 0.18, dampingFraction: 0.80), value: isHovered)
        .onHover { isHovered = $0 }
        .help("偏好设置")
    }
}
