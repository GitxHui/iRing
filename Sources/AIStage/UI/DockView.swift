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
    private var iconSpacing: CGFloat { max(2, round(iconSize * 0.05)) }
    private var islandContentPadding: CGFloat { max(4, round(iconSize * 0.13)) }
    private var expandedTopFlare: CGFloat { min(12, max(9, round(iconSize * 0.25))) }
    private var adaptiveIndicatorSize: CGFloat { CGFloat(coordinator.settings.effectiveIndicatorSize) }
    private var pillWidth: CGFloat { iconSize + 4 }
    private var pillHeight: CGFloat { iconSize + 4 }
    private var pillCornerRadius: CGFloat { min(16, max(8, iconSize * 0.28)) }
    private var actionButtonSize: CGFloat { max(20, min(46, round(iconSize * 0.78))) }

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
        let _ = coordinator.settings.language
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
        let flareTarget = expandedTopFlare
        let topFlare: CGFloat = 9 + max(0, flareTarget - 9) * p
        let bottomRadius: CGFloat = 12 + 8 * p
        let islandShape = DynamicIslandShape(topFlare: topFlare, bottomRadius: bottomRadius, edge: islandEdge)
        let rawOverflow: CGFloat = (coordinator.settings.islandExpandAxis == .alongEdge)
            ? DisplayGeometry.magnificationOverflow(settings: coordinator.settings)
            : 0
        let activeOverflow = rawOverflow * p

        return GeometryReader { geo in
            let bgWidth = (islandEdge.isVertical && rawOverflow > 0)
                ? max(24, geo.size.width - activeOverflow)
                : geo.size.width
            let bgHeight = (!islandEdge.isVertical && rawOverflow > 0)
                ? max(24, geo.size.height - activeOverflow)
                : geo.size.height

            ZStack(alignment: rootAlignment) {
                islandBackground(
                    topFlare: topFlare,
                    bottomRadius: bottomRadius,
                    progress: p
                )
                .frame(width: bgWidth, height: bgHeight)

                if p < 0.98 {
                    let outP = min(1, p * 2.1)
                    collapsedDynamicIslandContent
                        .frame(width: bgWidth, height: bgHeight)
                        .clipShape(islandShape)
                        .opacity(Double(max(0, 1 - outP)))
                        .scaleEffect(1.0 - 0.06 * min(1, p * 2), anchor: anchor)
                        .blur(radius: 5 * outP)
                        .allowsHitTesting(p < 0.35)
                }

                if p > 0.02 {
                    let remaining = 1 - contentP
                    let expandedView = expandedDynamicIslandContent(
                        bgWidth: bgWidth,
                        bgHeight: bgHeight,
                        panelWidth: geo.size.width,
                        panelHeight: geo.size.height,
                        flareInset: flareTarget
                    )
                    .opacity(Double(contentP))
                    .scaleEffect(0.92 + 0.08 * contentP, anchor: anchor)
                    .offset(x: slide.width * remaining, y: slide.height * remaining)
                    .blur(radius: 5 * remaining)
                    .allowsHitTesting(p > 0.45)

                    if p < 0.96 || rawOverflow <= 0 {
                        expandedView
                            .frame(width: bgWidth, height: bgHeight)
                            .clipShape(islandShape)
                    } else {
                        expandedView
                            .frame(width: geo.size.width, height: geo.size.height, alignment: rootAlignment)
                    }
                }

                if coordinator.isDraggingDock, let previewEdge = coordinator.dragPreviewEdge {
                    dockSnapPreviewBanner(edge: previewEdge)
                        .frame(width: bgWidth, height: bgHeight)
                        .clipShape(islandShape)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: rootAlignment)
        }
        .environment(\.colorScheme, isAppleGlassIsland ? systemColorScheme : .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dockSnapPreviewBanner(edge: DockEdgePosition) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "pin.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(L10n.t("松手固定到\(edge.label)", "Release to snap to \(edge.label)"))
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

    private func glassRimAngularGradient(peak: Double, mid: Double) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: Color.white.opacity(mid), location: 0.00),
                .init(color: Color.white.opacity(peak * 0.92), location: 0.125),
                .init(color: Color.white.opacity(mid), location: 0.25),
                .init(color: Color.white.opacity(peak * 0.72), location: 0.375),
                .init(color: Color.white.opacity(mid * 1.1), location: 0.50),
                .init(color: Color.white.opacity(peak), location: 0.625),
                .init(color: Color.white.opacity(mid), location: 0.75),
                .init(color: Color.white.opacity(peak * 0.78), location: 0.875),
                .init(color: Color.white.opacity(mid), location: 1.00)
            ]),
            center: .center
        )
    }

    @ViewBuilder
    private func islandBackground(topFlare: CGFloat, bottomRadius: CGFloat, progress: CGFloat) -> some View {
        let t = Double(min(1, max(0, progress)))
        let shape = DynamicIslandShape(topFlare: topFlare, bottomRadius: bottomRadius, edge: islandEdge)
        let openRim = DynamicIslandShape(topFlare: topFlare, bottomRadius: bottomRadius, edge: islandEdge, closeAttachedEdge: false)
        if isAppleGlassIsland {
            let isDark = systemColorScheme == .dark
            let frost = coordinator.settings.clampedGlassOpacity
            let layers = StageSettings.glassLayerOpacities(forFrost: frost)
            let rim = StageSettings.glassRimMetrics(forFrost: frost, isDark: isDark)
            let bodySheenColors: [Color] = isDark
                ? [
                    Color(white: 0.22).opacity(0.18 + layers.tintVeil * 0.38),
                    Color(white: 0.08).opacity(0.10 + layers.tintVeil * 0.28),
                    Color(white: 0.14).opacity(0.14 + layers.tintVeil * 0.34)
                ]
                : [
                    Color.white.opacity(0.14 + layers.tintVeil * 0.48),
                    Color.white.opacity(0.05 + layers.tintVeil * 0.28),
                    Color.white.opacity(0.11 + layers.tintVeil * 0.36)
                ]

            ZStack {
                if #available(macOS 26.0, *) {
                    if layers.clearBlur > 0.005 {
                        Color.clear
                            .glassEffect(.clear, in: shape)
                            .opacity(layers.clearBlur)
                    }
                    if layers.regularBlur > 0.005 {
                        Color.clear
                            .glassEffect(.regular, in: shape)
                            .opacity(layers.regularBlur)
                    }
                } else if layers.clearBlur > 0.005 {
                    let material = glassMaterial(for: StageSettings.derivedGlassStyle(forOpacity: frost))
                    let blurAlpha = CGFloat(layers.clearBlur * 0.55 + layers.regularBlur * 0.45)
                    IslandFrostedBackdrop(
                        topFlare: topFlare,
                        bottomRadius: bottomRadius,
                        edge: islandEdge,
                        material: material,
                        blurAlpha: blurAlpha
                    )
                }

                // Optical glass sheen + progressive milky tint
                shape
                    .fill(
                        LinearGradient(
                            colors: bodySheenColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Layer 1: Soft inner glass-wall depth band (blurred strictly inside shape)
                openRim
                    .inset(by: 1.3)
                    .stroke(
                        glassRimAngularGradient(peak: rim.bevelPeakAlpha, mid: rim.bevelMidAlpha),
                        style: StrokeStyle(lineWidth: rim.bevelWidth, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: rim.bevelBlur)
                    .clipShape(shape)

                // Layer 2: Directional curved-corner specular catch-lights (adapts with clarity slider)
                openRim
                    .inset(by: 0.75)
                    .stroke(
                        glassRimAngularGradient(peak: rim.specularPeakAlpha, mid: rim.specularMidAlpha),
                        style: StrokeStyle(lineWidth: 1.05, lineCap: .round, lineJoin: .round)
                    )
                    .clipShape(shape)

                // Layer 3: Delicate outer dark-glass refractive contour (adapts with clarity slider)
                openRim
                    .inset(by: 0.3)
                    .stroke(
                        Color.black.opacity(rim.outerContactAlpha),
                        style: StrokeStyle(lineWidth: 0.6, lineCap: .round, lineJoin: .round)
                    )
            }
        } else {
            // Interpolate everything with progress so rim never pops at a threshold.
            let isNotchTop = (islandEdge == .top && coordinator.screenHasNotch)
            let rimAlpha = isNotchTop ? 0.14 * min(1, t * 2.5) : 0.14
            shape
                .fill(isNotchTop ? Color.black : Color.black.opacity(0.94))
                .overlay(
                    openRim
                        .inset(by: 0.35)
                        .stroke(
                            Color.white.opacity(rimAlpha),
                            style: StrokeStyle(lineWidth: 0.7, lineCap: .round, lineJoin: .round)
                        )
                )
        }
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
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                if !isCollapsedVertical && !(islandEdge == .top && coordinator.screenHasNotch) {
                    Text(L10n.t("添加应用", "Add Apps"))
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(labelColor.opacity(0.88))
        }
    }

    private var collapsedDynamicIslandContent: some View {
        let (activeItem, otherRunningApps) = coordinator.collapsedIconApps
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

            whitespaceDragSurface(onTap: {
                if coordinator.apps.isEmpty {
                    onOpenAddApp()
                } else {
                    coordinator.setDynamicIslandExpanded(true)
                }
            })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .animation(islandSpring(baseResponse: 0.28, damping: 0.80), value: coordinator.activeBundleID)
        .contextMenu { overflowMenuItems }
        .help(L10n.t(
            "点击展开或按住空白处拖动停靠到屏幕顶部、底端、左端、右端",
            "Click to expand or drag empty space to snap to Top, Bottom, Left, or Right edge"
        ))
    }

    private func islandSpring(baseResponse: Double, damping: Double, interactive: Bool = false) -> Animation? {
        let speed = coordinator.settings.islandAnimationSpeed
        guard !speed.isInstant else { return nil }
        let response = max(0.08, baseResponse * speed.springScale)
        return interactive
            ? .interactiveSpring(response: response, dampingFraction: damping)
            : .spring(response: response, dampingFraction: damping)
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

    private func estimatedExpandedTraySpan() -> CGFloat {
        let count = CGFloat(max(1, coordinator.displayedApps.count))
        let showSep = coordinator.settings.sortRunningAppsFirst
            && !coordinator.runningDisplayedApps.isEmpty
            && !coordinator.inactiveDisplayedApps.isEmpty
        let sepExtra: CGFloat = showSep ? 7 : 0
        let pitch = pillWidth + iconSpacing
        return islandContentPadding * 2 + (count + 2) * pitch - iconSpacing + sepExtra
    }

    private func expandedDynamicIslandContent(
        bgWidth: CGFloat,
        bgHeight: CGFloat,
        panelWidth: CGFloat,
        panelHeight: CGFloat,
        flareInset: CGFloat
    ) -> some View {
        let horizEdgeInset = DisplayGeometry.horizontalIslandEdgeInset(for: coordinator.settings)
        let vertEdgeInset = DisplayGeometry.verticalIslandEdgeInset(for: coordinator.settings)
        let topBand: CGFloat = (islandEdge == .top && coordinator.screenHasNotch)
            ? max(32, coordinator.screenNotchHeight)
            : horizEdgeInset
        let showDot = coordinator.settings.indicatorStyle != .hidden
        let horizDotOuterPad: CGFloat = showDot ? DisplayGeometry.islandIndicatorOuterPadding : horizEdgeInset
        let vertDotOuterPad: CGFloat = showDot ? DisplayGeometry.islandIndicatorOuterPadding : vertEdgeInset
        let dotPad: CGFloat = showDot ? (max(4, adaptiveIndicatorSize) + DisplayGeometry.verticalIndicatorGap) : 0
        let actionLeadingPad: CGFloat = (isExpandedVertical && islandEdge == .left) ? dotPad : 0
        let actionTrailingPad: CGFloat = (isExpandedVertical && islandEdge == .right) ? dotPad : 0
        let horizActionBotPad: CGFloat = (islandEdge == .bottom && showDot)
            ? (max(4, adaptiveIndicatorSize) + DisplayGeometry.horizontalIndicatorGap)
            : 0
        let estimatedSpan = estimatedExpandedTraySpan()

        return ZStack(alignment: rootAlignment) {
            whitespaceDragSurface()
                .frame(width: bgWidth, height: bgHeight)

            if isExpandedVertical {
                let innerVAvail = max(40, bgHeight - (islandEdge.isVertical ? flareInset * 2 : 8) - (islandEdge == .top && coordinator.screenHasNotch ? max(32, coordinator.screenNotchHeight) : 0))
                let needsVScroll = estimatedSpan > innerVAvail + 1
                let vAlign: HorizontalAlignment = islandEdge == .right ? .trailing : (islandEdge == .left ? .leading : .center)
                let vStack = VStack(alignment: vAlign, spacing: iconSpacing) {
                    groupedAppCells
                    inlineAddButton(size: actionButtonSize)
                        .padding(.leading, actionLeadingPad)
                        .padding(.trailing, actionTrailingPad)
                    islandOverflowButton(size: actionButtonSize)
                        .padding(.leading, actionLeadingPad)
                        .padding(.trailing, actionTrailingPad)
                }
                .padding(.vertical, islandContentPadding)
                .padding(.leading, islandEdge == .left ? vertDotOuterPad : vertEdgeInset)
                .padding(.trailing, islandEdge == .right ? vertDotOuterPad : vertEdgeInset)

                if needsVScroll {
                    VStack(spacing: 0) {
                        if islandEdge == .top && coordinator.screenHasNotch {
                            Color.clear
                                .frame(height: max(32, coordinator.screenNotchHeight))
                        }
                        GeometryReader { proxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                vStack
                                    .frame(
                                        minWidth: max(0, proxy.size.width),
                                        minHeight: max(0, proxy.size.height),
                                        alignment: islandEdge == .right ? .trailing : (islandEdge == .left ? .leading : .center)
                                    )
                                    .background {
                                        whitespaceDragSurface()
                                    }
                            }
                        }
                        .padding(.vertical, islandEdge.isVertical ? flareInset : 2)
                        .padding(.horizontal, !islandEdge.isVertical ? flareInset : 0)
                    }
                    .frame(width: panelWidth, height: panelHeight)
                } else {
                    vStack
                        .padding(.top, (islandEdge == .top && coordinator.screenHasNotch) ? max(32, coordinator.screenNotchHeight) : (islandEdge.isVertical ? flareInset : 2))
                        .padding(.bottom, islandEdge.isVertical ? flareInset : 2)
                        .frame(
                            width: panelWidth,
                            height: panelHeight,
                            alignment: islandEdge == .right ? .trailing : (islandEdge == .left ? .leading : .center)
                        )
                }
            } else {
                let innerHAvail = max(40, bgWidth - (!islandEdge.isVertical ? flareInset * 2 : 0))
                let needsHScroll = estimatedSpan > innerHAvail + 1
                let vCellAlign: VerticalAlignment = islandEdge == .bottom ? .bottom : (islandEdge == .top ? .top : .center)
                let hStack = HStack(alignment: vCellAlign, spacing: iconSpacing) {
                    groupedAppCells
                    inlineAddButton(size: actionButtonSize)
                        .padding(.bottom, horizActionBotPad)
                    islandOverflowButton(size: actionButtonSize)
                        .padding(.bottom, horizActionBotPad)
                }
                .padding(.horizontal, islandContentPadding)
                .padding(.top, topBand)
                .padding(.bottom, horizDotOuterPad)

                if needsHScroll {
                    GeometryReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            hStack
                                .frame(
                                    minWidth: max(0, proxy.size.width),
                                    minHeight: max(0, proxy.size.height),
                                    alignment: islandEdge == .bottom ? .bottom : (islandEdge == .top ? .top : .center)
                                )
                                .background {
                                    whitespaceDragSurface()
                                }
                        }
                    }
                    .padding(.horizontal, !islandEdge.isVertical ? flareInset : 2)
                    .frame(width: panelWidth, height: panelHeight)
                } else {
                    hStack
                        .frame(
                            width: max(0, bgWidth - (!islandEdge.isVertical ? flareInset * 2 : 4)),
                            height: panelHeight,
                            alignment: islandEdge == .bottom ? .bottom : (islandEdge == .top ? .top : .center)
                        )
                }
            }
        }
        .frame(width: panelWidth, height: panelHeight, alignment: rootAlignment)
        .contextMenu { overflowMenuItems }
    }

    /// Settings button in the tray right after "+", matching the app icon cell footprint and spacing.
    private func islandOverflowButton(size: CGFloat) -> some View {
        let iconTint: Color = isAppleGlassIsland ? .primary : .white
        return IslandSettingsButton(
            tint: iconTint,
            size: size,
            animationSpeed: coordinator.settings.islandAnimationSpeed,
            action: onOpenSettings
        )
            .frame(width: pillWidth, height: pillHeight)
    }

    // MARK: - Grouped App Icons

    @ViewBuilder
    private var groupedAppCells: some View {
        let runningApps = coordinator.runningDisplayedApps
        let inactiveApps = coordinator.inactiveDisplayedApps
        let showSeparator = coordinator.settings.sortRunningAppsFirst
            && !runningApps.isEmpty
            && !inactiveApps.isEmpty
        let slotLookup = Dictionary(
            uniqueKeysWithValues: coordinator.numberShortcutApps.enumerated().map { ($0.element.bundleIdentifier, $0.offset) }
        )

        Group {
            if isExpandedVertical {
                VStack(alignment: .center, spacing: iconSpacing) {
                    ForEach(runningApps, id: \.bundleIdentifier) { item in
                        makeIconCell(item: item, shortcutSlotIndex: slotLookup[item.bundleIdentifier])
                    }
                    if showSeparator {
                        Capsule()
                            .fill(Color.primary.opacity(0.22))
                            .frame(width: max(18, iconSize * 0.62), height: 1)
                            .padding(.vertical, 2)
                    }
                    ForEach(inactiveApps, id: \.bundleIdentifier) { item in
                        makeIconCell(item: item, shortcutSlotIndex: slotLookup[item.bundleIdentifier])
                    }
                }
            } else {
                HStack(alignment: islandEdge == .bottom ? .bottom : .top, spacing: iconSpacing) {
                    ForEach(runningApps, id: \.bundleIdentifier) { item in
                        makeIconCell(item: item, shortcutSlotIndex: slotLookup[item.bundleIdentifier])
                    }
                    if showSeparator {
                        Capsule()
                            .fill(Color.primary.opacity(0.22))
                            .frame(width: 1, height: max(18, iconSize * 0.62))
                            .padding(.horizontal, 2)
                            .frame(height: pillHeight)
                    }
                    ForEach(inactiveApps, id: \.bundleIdentifier) { item in
                        makeIconCell(item: item, shortcutSlotIndex: slotLookup[item.bundleIdentifier])
                    }
                }
            }
        }
        .animation(islandSpring(baseResponse: 0.30, damping: 0.80), value: coordinator.activeBundleID)
        .animation(islandSpring(baseResponse: 0.32, damping: 0.84), value: coordinator.displayedApps.map(\.bundleIdentifier))
    }

    private func makeIconCell(item: StageAppItem, shortcutSlotIndex: Int?) -> some View {
        let waveScale = magnificationScale(for: item.bundleIdentifier)
        let showDot = coordinator.settings.indicatorStyle != .hidden
        let dotFootprint: CGFloat = showDot ? max(4, adaptiveIndicatorSize) : 0
        let dotSpacing: CGFloat = showDot ? (isExpandedVertical ? DisplayGeometry.verticalIndicatorGap : DisplayGeometry.horizontalIndicatorGap) : 0
        let baseSlotW = isExpandedVertical
            ? (pillWidth + (islandEdge.isVertical && showDot ? (dotFootprint + dotSpacing) : 0))
            : pillWidth
        let baseSlotH = isExpandedVertical
            ? pillHeight
            : (pillHeight + dotFootprint + dotSpacing)
        let extraSpread = (waveScale - 1.0) * iconSize * 0.48
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
            shortcutSlotIndex: shortcutSlotIndex,
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
        .animation(islandSpring(baseResponse: 0.16, damping: 0.78, interactive: true), value: waveScale)
        .onHover { hovering in
            withAnimation(islandSpring(baseResponse: 0.18, damping: 0.76)) {
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
        .frame(width: pillWidth, height: pillHeight)
        .background {
            GeometryReader { geo in
                let frame = geo.frame(in: .named("dockPanel"))
                Color.clear.preference(
                    key: DockCellCentersKey.self,
                    value: [Self.addButtonCellKey: CGPoint(x: frame.midX, y: frame.midY)]
                )
            }
        }
        .animation(islandSpring(baseResponse: 0.18, damping: 0.80, interactive: true), value: p)
        .help(L10n.t("添加应用到 iRing", "Add Apps to iRing"))
    }

    @ViewBuilder
    private var overflowMenuItems: some View {
        if coordinator.layoutMode == .split2 {
            Button(L10n.t("退出双屏对比", "Exit Split View")) {
                coordinator.exitSplitMode()
            }
        }
        Button(L10n.t("添加应用…", "Add Apps…"), action: onOpenAddApp)
        Divider()
        Button(L10n.t("偏好设置…", "Settings…"), action: onOpenSettings)
    }
}

// MARK: - App Icon Cell inside Dynamic Island

private struct DockAppIconCell: View {
    @Environment(\.colorScheme) private var systemColorScheme
    let item: StageAppItem
    let shortcutSlotIndex: Int?
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
        let _ = settings.language
        var parts: [String] = [item.displayName]
        if let prefix = settings.effectiveNumberSwitchSymbolPrefix,
           let slot = shortcutSlotIndex, slot < 9 {
            parts.append("\(prefix)\(slot + 1)")
        }
        if isLaunching {
            parts.append(L10n.t("启动中…", "Launching…"))
        } else if runtime.isRunning {
            parts.append(runtime.memoryMB > 0
                ? L10n.t("运行中 · \(runtime.memoryMB) MB", "Running · \(runtime.memoryMB) MB")
                : L10n.t("运行中", "Running"))
        } else {
            parts.append(L10n.t("未运行（点击启动）", "Not Running (Click to Launch)"))
        }
        if let badge = runtime.badgeLabel, !badge.isEmpty {
            parts.append(L10n.t("未读 \(badge)", "\(badge) unread"))
        }
        parts.append(L10n.t("⌘+点击双屏", "⌘+Click Split"))
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let _ = settings.language
        let magEnabled = settings.magnificationScale > 1.01
        let effectiveScale: CGFloat = isPressed
            ? (waveScale * 0.90)
            : (magEnabled ? (waveScale > 1.02 ? waveScale : (isHovered ? 1.08 : 1.0)) : 1.0)
        let isAlongEdge = (settings.islandExpandAxis == .alongEdge)
        let lift = max(0, waveScale - 1.0) * iconSize * (isAlongEdge ? 0.08 : 0.04)
        let spacingToIndicator: CGFloat = DisplayGeometry.horizontalIndicatorGap
        let isEdgeVertical = isVerticalLayout && islandEdge.isVertical
        let showIndicator = settings.indicatorStyle != .hidden
        let scaleAnchor: UnitPoint = if isAlongEdge {
            switch islandEdge {
            case .top: .top
            case .bottom: .bottom
            case .left: .leading
            case .right: .trailing
            }
        } else {
            .center
        }
        let waveOffsetX: CGFloat = isEdgeVertical
            ? (islandEdge == .left ? (lift + bounceOffsetY) : -(lift + bounceOffsetY))
            : 0
        let waveOffsetY: CGFloat = isEdgeVertical
            ? 0
            : (islandEdge == .top ? (lift + bounceOffsetY) : (islandEdge == .bottom ? -(lift + bounceOffsetY) : -(lift * 0.45 + bounceOffsetY * 0.5)))

        let iconTile = ZStack {
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
                        MacDockRedBadge(label: badge, iconSize: iconSize)
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

        Group {
            if isEdgeVertical {
                HStack(spacing: showIndicator ? DisplayGeometry.verticalIndicatorGap : 0) {
                    if islandEdge == .left {
                        if showIndicator {
                            statusIndicatorView(verticalOrientation: true)
                                .frame(width: max(4, adaptiveIndicatorSize))
                        }
                        iconTile
                    } else {
                        iconTile
                        if showIndicator {
                            statusIndicatorView(verticalOrientation: true)
                                .frame(width: max(4, adaptiveIndicatorSize))
                        }
                    }
                }
            } else {
                VStack(spacing: showIndicator ? spacingToIndicator : 0) {
                    iconTile
                    if showIndicator {
                        statusIndicatorView(verticalOrientation: false)
                            .frame(height: max(4, adaptiveIndicatorSize))
                    }
                }
            }
        }
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
            Button(L10n.t("切换到 \(item.displayName)", "Switch to \(item.displayName)")) { onClick(false, false) }
            Button(L10n.t("移到当前屏幕 (⌥+点击)", "Move to Current Display (⌥+Click)")) { onPullToCurrentScreen() }
            if !isPrimaryActive {
                Button(L10n.t("与当前应用双屏对比 (⌘+点击)", "Split with Current App (⌘+Click)")) { onSplitWithCurrent() }
            }
            if isSplitMode {
                Button(L10n.t("退出双屏对比", "Exit Split View")) { onExitSplit() }
            }
            Divider()
            if runtime.isRunning {
                if runtime.memoryMB > 0 {
                    Text(L10n.t("当前内存占用：\(runtime.memoryMB) MB", "Memory Usage: \(runtime.memoryMB) MB"))
                }
                Button(L10n.t("重新启动", "Relaunch")) { onRelaunch() }
                Button(L10n.t("彻底退出（释放内存）", "Quit App")) { onQuit() }
            } else {
                Button(L10n.t("启动应用", "Launch App")) { onClick(false, false) }
            }
            Divider()
            Button(L10n.t("在访达中显示", "Show in Finder")) { onReveal() }
            Button(L10n.t("从列表移除", "Remove from iRing"), role: .destructive) { onRemove() }
        }
    }

    @ViewBuilder
    private func statusIndicatorView(verticalOrientation: Bool) -> some View {
        let style = settings.indicatorStyle
        let baseSize = max(3.6, adaptiveIndicatorSize * 0.90)
        let activeW = min(14, max(10, iconSize * 0.26))
        let activeH = max(3.0, min(3.8, adaptiveIndicatorSize * 0.74))
        let shouldShow = style != .hidden && (isPrimaryActive || runtime.isRunning || isLaunching || settings.showInactiveIndicator)

        if shouldShow {
            let fillColor = resolvedIndicatorColor
            let rawW: CGFloat = isPrimaryActive
                ? activeW
                : (style == .pill ? max(8, baseSize * 2.1) : baseSize)
            let rawH: CGFloat = isPrimaryActive
                ? activeH
                : (style == .pill ? max(2.2, baseSize * 0.56) : baseSize)
            let indW = verticalOrientation ? rawH : rawW
            let indH = verticalOrientation ? rawW : rawH
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
                .animation(
                    settings.islandAnimationSpeed.isInstant
                        ? nil
                        : .spring(response: max(0.08, 0.26 * settings.islandAnimationSpeed.springScale), dampingFraction: 0.78),
                    value: isPrimaryActive
                )
        } else {
            Color.clear.frame(
                width: verticalOrientation ? baseSize : 1,
                height: verticalOrientation ? 1 : baseSize
            )
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
    var iconSize: CGFloat = 46
    private var displayLabel: String { label.count > 3 ? "99+" : label }

    var body: some View {
        let isSingleChar = displayLabel.count <= 1
        let side = max(15, min(20, round(iconSize * 0.36)))
        Text(displayLabel)
            .font(.system(size: round(side * 0.62), weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, isSingleChar ? 0 : round(side * 0.28))
            .frame(minWidth: side, minHeight: side)
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

private struct DynamicIslandShape: InsettableShape, Sendable {
    let topFlare: CGFloat
    let bottomRadius: CGFloat
    let edge: DockEdgePosition
    var closeAttachedEdge: Bool = true
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
        if closeAttachedEdge {
            p.closeSubpath()
        }
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
    let animationSpeed: AnimationSpeedPreset
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
        .animation(
            (reduceMotion || animationSpeed.isInstant)
                ? nil
                : .interactiveSpring(response: max(0.08, 0.18 * animationSpeed.springScale), dampingFraction: 0.80),
            value: isHovered
        )
        .onHover { isHovered = $0 }
        .help(L10n.t("偏好设置", "Settings"))
    }
}
