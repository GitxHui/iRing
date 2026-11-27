import AppKit
import CoreGraphics

/// Deterministic multi-monitor coordinate & locked-stage geometry engine.
///
/// Coordinate conventions:
/// - **Quartz / Accessibility (`AXPosition`, `CGDisplay`)**:
///   Origin `(0, 0)` is at the **top-left** of the primary display; Y increases **downward**.
/// - **AppKit (`NSWindow.frame`, `NSScreen.frame`, `NSScreen.visibleFrame`)**:
///   Origin `(0, 0)` is at the **bottom-left** of the primary display; Y increases **upward**.
public enum DisplayGeometry {

    public enum DockPopDirection: Equatable, Sendable {
        case up
        case down
        case left
        case right
        case none
    }

    public struct ScreenInfo: Equatable, Sendable {
        public let id: String
        public let frameAppKit: CGRect
        public let visibleFrameAppKit: CGRect
        public let frameQuartz: CGRect
        public let visibleFrameQuartz: CGRect
        public let safeAreaTop: CGFloat
        public let menuBarHeight: CGFloat
        public let notchWidth: CGFloat

        public init(
            id: String,
            frameAppKit: CGRect,
            visibleFrameAppKit: CGRect,
            primaryHeight: CGFloat,
            safeAreaTop: CGFloat = 0,
            notchWidth: CGFloat? = nil
        ) {
            self.id = id
            self.frameAppKit = frameAppKit
            self.visibleFrameAppKit = visibleFrameAppKit
            self.frameQuartz = DisplayGeometry.appKitToQuartz(frameAppKit, primaryHeight: primaryHeight)
            self.visibleFrameQuartz = DisplayGeometry.appKitToQuartz(visibleFrameAppKit, primaryHeight: primaryHeight)
            self.safeAreaTop = safeAreaTop
            self.menuBarHeight = max(0, frameAppKit.maxY - visibleFrameAppKit.maxY)
            self.notchWidth = notchWidth ?? (safeAreaTop > 0 ? 186 : 0)
        }
    }

    public static func primaryScreenHeight(screens: [NSScreen] = NSScreen.screens) -> CGFloat {
        if let primary = screens.first(where: { $0.frame.origin == .zero }) ?? screens.first {
            return primary.frame.height
        }
        return 1080
    }

    public static func allScreens() -> [ScreenInfo] {
        let screens = NSScreen.screens
        let primaryH = primaryScreenHeight(screens: screens)
        return screens.enumerated().map { idx, screen in
            let screenID: String
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                screenID = num.stringValue
            } else {
                screenID = "screen-\(idx)"
            }
            let safeTop: CGFloat
            let notchW: CGFloat
            if #available(macOS 12.0, *) {
                safeTop = screen.safeAreaInsets.top
                if let left = screen.auxiliaryTopLeftArea,
                   let right = screen.auxiliaryTopRightArea,
                   left.width > 0, right.width > 0 {
                    notchW = max(0, round(screen.frame.width - left.width - right.width))
                } else {
                    notchW = safeTop > 0 ? 186 : 0
                }
            } else {
                safeTop = 0
                notchW = 0
            }
            return ScreenInfo(
                id: screenID,
                frameAppKit: screen.frame,
                visibleFrameAppKit: screen.visibleFrame,
                primaryHeight: primaryH,
                safeAreaTop: safeTop,
                notchWidth: notchW
            )
        }
    }

    public static func appKitToQuartz(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryHeight - (rect.origin.y + rect.size.height),
            width: rect.size.width,
            height: rect.size.height
        )
    }

    public static func quartzToAppKit(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryHeight - (rect.origin.y + rect.size.height),
            width: rect.size.width,
            height: rect.size.height
        )
    }

    public static func screen(containingQuartzPoint point: CGPoint, screens: [ScreenInfo]) -> ScreenInfo? {
        guard !screens.isEmpty else { return nil }
        if let exact = screens.first(where: { $0.frameQuartz.contains(point) }) {
            return exact
        }
        return screens.min { a, b in
            hypot(a.frameQuartz.midX - point.x, a.frameQuartz.midY - point.y)
                < hypot(b.frameQuartz.midX - point.x, b.frameQuartz.midY - point.y)
        }
    }

    public static func screen(containingQuartzRect rect: CGRect, screens: [ScreenInfo]) -> ScreenInfo? {
        guard !screens.isEmpty else { return nil }
        let center = CGPoint(x: rect.midX, y: rect.midY)

        if let exact = screens.first(where: { $0.frameQuartz.contains(center) }) {
            return exact
        }

        let bestIntersect = screens.max { a, b in
            let ia = a.frameQuartz.intersection(rect)
            let ib = b.frameQuartz.intersection(rect)
            let areaA = ia.isNull ? 0 : ia.width * ia.height
            let areaB = ib.isNull ? 0 : ib.width * ib.height
            return areaA < areaB
        }
        if let best = bestIntersect {
            let inter = best.frameQuartz.intersection(rect)
            if !inter.isNull && inter.width * inter.height > 0 {
                return best
            }
        }

        return screens.min { a, b in
            hypot(a.frameQuartz.midX - center.x, a.frameQuartz.midY - center.y)
                < hypot(b.frameQuartz.midX - center.x, b.frameQuartz.midY - center.y)
        }
    }

    public static func nextScreen(after currentScreenID: String?, screens: [ScreenInfo]) -> ScreenInfo? {
        guard !screens.isEmpty else { return nil }
        let ordered = screens.sorted {
            if $0.frameQuartz.minX != $1.frameQuartz.minX {
                return $0.frameQuartz.minX < $1.frameQuartz.minX
            }
            return $0.frameQuartz.minY < $1.frameQuartz.minY
        }
        guard let currentID = currentScreenID,
              let idx = ordered.firstIndex(where: { $0.id == currentID })
        else {
            return ordered.first
        }
        return ordered[(idx + 1) % ordered.count]
    }

    public static func nearestEdge(forQuartzPoint point: CGPoint, on screen: ScreenInfo) -> DockEdgePosition {
        let vis = screen.visibleFrameQuartz
        guard vis.width > 0, vis.height > 0 else { return .top }
        let dTop = max(0, point.y - vis.minY) / vis.height
        let dBottom = max(0, vis.maxY - point.y) / vis.height
        let dLeft = max(0, point.x - vis.minX) / vis.width
        let dRight = max(0, vis.maxX - point.x) / vis.width

        var bestEdge: DockEdgePosition = .top
        var bestDist = dTop
        if dBottom < bestDist {
            bestDist = dBottom
            bestEdge = .bottom
        }
        if dLeft < bestDist {
            bestDist = dLeft
            bestEdge = .left
        }
        if dRight < bestDist {
            bestEdge = .right
        }
        return bestEdge
    }

    // MARK: - Strictly Locked Stage & Multi-Shape Draggable/Resizable Dock Geometry

    public static func fullStageFrameQuartz(on screen: ScreenInfo, margin: CGFloat) -> CGRect {
        let vis = screen.visibleFrameQuartz
        return CGRect(
            x: vis.minX + margin,
            y: vis.minY + margin,
            width: max(480, vis.width - margin * 2),
            height: max(360, vis.height - margin * 2)
        ).integral
    }

    /// Top inset of the expanded island when there is no camera notch to clear.
    public static let islandHeaderInset: CGFloat = 4

    /// Outer breathing room between the running-indicator dot and the island rim.
    public static let islandIndicatorOuterPadding: CGFloat = 3.5
    /// Gap between the icon tile (`iconSize + 4`) and the indicator slot on horizontal islands.
    public static let horizontalIndicatorGap: CGFloat = 0.5
    /// Gap between the icon tile (`iconSize + 4`) and the indicator slot on vertical islands.
    public static let verticalIndicatorGap: CGFloat = 1.5

    /// Symmetric inset (above and below the icon tile) for horizontal expanded islands without a notch.
    public static func horizontalIslandEdgeInset(for settings: StageSettings) -> CGFloat {
        let iconSz = CGFloat(settings.iconSize)
        let showDot = settings.indicatorStyle != .hidden
        guard showDot else {
            return max(4, round(iconSz * 0.14))
        }
        let dotH = max(4, CGFloat(settings.effectiveIndicatorSize))
        return ceil(horizontalIndicatorGap + dotH + islandIndicatorOuterPadding)
    }

    /// Symmetric inset (left and right of the icon tile) for vertical expanded islands.
    public static func verticalIslandEdgeInset(for settings: StageSettings) -> CGFloat {
        let iconSz = CGFloat(settings.iconSize)
        let showDot = settings.indicatorStyle != .hidden
        guard showDot else {
            return max(4, round(iconSz * 0.14))
        }
        let dotW = max(4, CGFloat(settings.effectiveIndicatorSize))
        return ceil(verticalIndicatorGap + dotW + islandIndicatorOuterPadding)
    }

    public static func magnificationOverflow(settings: StageSettings) -> CGFloat {
        guard settings.magnificationScale > 1.01 else { return 0 }
        return ceil(CGFloat(settings.iconSize) * CGFloat(settings.magnificationScale - 1.0) * 0.65)
    }

    public static func minExpandedIslandDepth(
        settings: StageSettings,
        topBand: CGFloat,
        isVerticalTray: Bool
    ) -> CGFloat {
        let iconSz = CGFloat(settings.iconSize)
        let pillSpan = iconSz + 4
        if isVerticalTray {
            let sideInset = verticalIslandEdgeInset(for: settings)
            return ceil(sideInset + pillSpan + sideInset)
        }
        let edgeInset = horizontalIslandEdgeInset(for: settings)
        let effectiveTop = max(topBand, edgeInset)
        return ceil(effectiveTop + pillSpan + edgeInset)
    }

    public static func dynamicIslandFramesQuartz(
        on screen: ScreenInfo,
        settings: StageSettings,
        expanded: Bool,
        desiredExpandedWidth: CGFloat
    ) -> (island: CGRect, stage: CGRect) {
        let vis = screen.visibleFrameQuartz
        let margin = CGFloat(settings.effectiveOuterMargin)
        let stage = fullStageFrameQuartz(on: screen, margin: margin)
        let edge = settings.islandPosition

        let magOverflow = magnificationOverflow(settings: settings)
        let isPerp = (settings.islandExpandAxis == .perpendicular)

        switch edge {
        case .top:
            if !expanded {
                let height: CGFloat
                let width: CGFloat
                if screen.notchWidth > 0 {
                    height = max(30, min(42, screen.safeAreaTop))
                    let wingWidth: CGFloat = 58
                    width = round(screen.notchWidth + 6 + wingWidth * 2 + 20)
                } else {
                    height = max(26, min(32, screen.menuBarHeight > 0 ? screen.menuBarHeight : 28))
                    width = 224
                }
                let island = CGRect(
                    x: screen.frameQuartz.midX - width / 2,
                    y: screen.frameQuartz.minY,
                    width: width,
                    height: height
                ).integral
                return (island, stage)
            }

            let topNotchBand: CGFloat = screen.notchWidth > 0 ? max(32, screen.safeAreaTop) : islandHeaderInset
            if isPerp {
                let minSafeW = max(screen.notchWidth > 0 ? round(screen.notchWidth + 16) : 44, minExpandedIslandDepth(settings: settings, topBand: 0, isVerticalTray: true))
                let autoWidth = minSafeW + magOverflow
                let maxW = min(260, vis.width - 48)
                let width = settings.islandCustomWidth > 1
                    ? min(maxW, max(minSafeW, round(CGFloat(settings.islandCustomWidth))))
                    : autoWidth
                let maxH = max(200, vis.height - 48)
                let autoHeight = min(max(140, desiredExpandedWidth + topNotchBand), maxH)
                let height = settings.islandCustomHeight > 1
                    ? min(maxH, max(140, round(CGFloat(settings.islandCustomHeight))))
                    : autoHeight
                let island = CGRect(
                    x: round(screen.frameQuartz.midX - width / 2),
                    y: screen.frameQuartz.minY,
                    width: width,
                    height: height
                ).integral
                return (island, stage)
            }

            let minSafeTopH = minExpandedIslandDepth(settings: settings, topBand: topNotchBand, isVerticalTray: false)
            let autoHeight = minSafeTopH + magOverflow
            let maxCustomH = max(minSafeTopH, min(260, vis.height - 48))
            let height = settings.islandCustomHeight > 1
                ? min(maxCustomH, max(minSafeTopH, round(CGFloat(settings.islandCustomHeight))))
                : autoHeight
            let minExpandedW: CGFloat = screen.notchWidth > 0 ? max(220, screen.notchWidth + 40) : 140
            let maxW = max(minExpandedW, vis.width - 40)
            let autoWidth = min(max(minExpandedW, desiredExpandedWidth), maxW)
            let minCustomW: CGFloat = screen.notchWidth > 0 ? max(220, round(screen.notchWidth + 40)) : 140
            let width = settings.islandCustomWidth > 1
                ? min(maxW, max(minCustomW, round(CGFloat(settings.islandCustomWidth))))
                : autoWidth
            let island = CGRect(
                x: round(screen.frameQuartz.midX - width / 2),
                y: screen.frameQuartz.minY,
                width: width,
                height: height
            ).integral
            return (island, stage)

        case .bottom:
            if !expanded {
                let height: CGFloat = 30
                let width: CGFloat = 224
                let island = CGRect(
                    x: round(vis.midX - width / 2),
                    y: vis.maxY - height,
                    width: width,
                    height: height
                ).integral
                return (island, stage)
            }

            if isPerp {
                let minSafeW = minExpandedIslandDepth(settings: settings, topBand: 0, isVerticalTray: true)
                let autoWidth = minSafeW + magOverflow
                let maxW = min(260, vis.width - 48)
                let width = settings.islandCustomWidth > 1
                    ? min(maxW, max(minSafeW, round(CGFloat(settings.islandCustomWidth))))
                    : autoWidth
                let maxH = max(200, vis.height - 48)
                let autoHeight = min(max(140, desiredExpandedWidth), maxH)
                let height = settings.islandCustomHeight > 1
                    ? min(maxH, max(140, round(CGFloat(settings.islandCustomHeight))))
                    : autoHeight
                let island = CGRect(
                    x: round(vis.midX - width / 2),
                    y: vis.maxY - height,
                    width: width,
                    height: height
                ).integral
                return (island, stage)
            }

            let minSafeBotH = minExpandedIslandDepth(settings: settings, topBand: islandHeaderInset, isVerticalTray: false)
            let autoHeight = minSafeBotH + magOverflow
            let maxCustomH = max(minSafeBotH, min(260, vis.height - 48))
            let height = settings.islandCustomHeight > 1
                ? min(maxCustomH, max(minSafeBotH, round(CGFloat(settings.islandCustomHeight))))
                : autoHeight
            let maxW = max(140, vis.width - 40)
            let autoWidth = min(max(140, desiredExpandedWidth), maxW)
            let width = settings.islandCustomWidth > 1
                ? min(maxW, max(140, round(CGFloat(settings.islandCustomWidth))))
                : autoWidth
            let island = CGRect(
                x: round(vis.midX - width / 2),
                y: vis.maxY - height,
                width: width,
                height: height
            ).integral
            return (island, stage)

        case .left:
            if !expanded {
                let width: CGFloat = 34
                let height: CGFloat = 168
                let island = CGRect(
                    x: vis.minX,
                    y: round(vis.midY - height / 2),
                    width: width,
                    height: height
                ).integral
                return (island, stage)
            }

            if isPerp {
                let minSafeLeftH = minExpandedIslandDepth(settings: settings, topBand: islandHeaderInset, isVerticalTray: false)
                let autoHeight = minSafeLeftH + magOverflow
                let maxCustomH = max(minSafeLeftH, min(260, vis.height - 48))
                let height = settings.islandCustomHeight > 1
                    ? min(maxCustomH, max(minSafeLeftH, round(CGFloat(settings.islandCustomHeight))))
                    : autoHeight
                let maxW = max(140, vis.width - 48)
                let autoWidth = min(max(140, desiredExpandedWidth), maxW)
                let width = settings.islandCustomWidth > 1
                    ? min(maxW, max(140, round(CGFloat(settings.islandCustomWidth))))
                    : autoWidth
                let island = CGRect(
                    x: vis.minX,
                    y: round(vis.midY - height / 2),
                    width: width,
                    height: height
                ).integral
                return (island, stage)
            }

            let minSafeLeftW = minExpandedIslandDepth(settings: settings, topBand: 0, isVerticalTray: true)
            let autoWidth = minSafeLeftW + magOverflow
            let maxW = min(260, vis.width - 48)
            let width = settings.islandCustomWidth > 1
                ? min(maxW, max(minSafeLeftW, round(CGFloat(settings.islandCustomWidth))))
                : autoWidth
            let maxH = max(200, vis.height - 48)
            let autoHeight = min(max(140, desiredExpandedWidth), maxH)
            let height = settings.islandCustomHeight > 1
                ? min(maxH, max(140, round(CGFloat(settings.islandCustomHeight))))
                : autoHeight
            let island = CGRect(
                x: vis.minX,
                y: round(vis.midY - height / 2),
                width: width,
                height: height
            ).integral
            return (island, stage)

        case .right:
            if !expanded {
                let width: CGFloat = 34
                let height: CGFloat = 168
                let island = CGRect(
                    x: vis.maxX - width,
                    y: round(vis.midY - height / 2),
                    width: width,
                    height: height
                ).integral
                return (island, stage)
            }

            if isPerp {
                let minSafeRightH = minExpandedIslandDepth(settings: settings, topBand: islandHeaderInset, isVerticalTray: false)
                let autoHeight = minSafeRightH + magOverflow
                let maxCustomH = max(minSafeRightH, min(260, vis.height - 48))
                let height = settings.islandCustomHeight > 1
                    ? min(maxCustomH, max(minSafeRightH, round(CGFloat(settings.islandCustomHeight))))
                    : autoHeight
                let maxW = max(140, vis.width - 48)
                let autoWidth = min(max(140, desiredExpandedWidth), maxW)
                let width = settings.islandCustomWidth > 1
                    ? min(maxW, max(140, round(CGFloat(settings.islandCustomWidth))))
                    : autoWidth
                let island = CGRect(
                    x: vis.maxX - width,
                    y: round(vis.midY - height / 2),
                    width: width,
                    height: height
                ).integral
                return (island, stage)
            }

            let minSafeRightW = minExpandedIslandDepth(settings: settings, topBand: 0, isVerticalTray: true)
            let autoWidth = minSafeRightW + magOverflow
            let maxW = min(260, vis.width - 48)
            let width = settings.islandCustomWidth > 1
                ? min(maxW, max(minSafeRightW, round(CGFloat(settings.islandCustomWidth))))
                : autoWidth
            let maxH = max(200, vis.height - 48)
            let autoHeight = min(max(140, desiredExpandedWidth), maxH)
            let height = settings.islandCustomHeight > 1
                ? min(maxH, max(140, round(CGFloat(settings.islandCustomHeight))))
                : autoHeight
            let island = CGRect(
                x: vis.maxX - width,
                y: round(vis.midY - height / 2),
                width: width,
                height: height
            ).integral
            return (island, stage)
        }
    }

    public static func dockAndStageFramesQuartz(
        on screen: ScreenInfo,
        customDockOriginQuartz: CGPoint?,
        settings: StageSettings,
        desiredDockHeight: CGFloat
    ) -> (dock: CGRect, stage: CGRect) {
        let vis = screen.visibleFrameQuartz
        let margin = CGFloat(settings.effectiveOuterMargin)
        let fullStage = fullStageFrameQuartz(on: screen, margin: margin)

        switch settings.dockShape {
        case .dynamicIsland:
            let res = dynamicIslandFramesQuartz(
                on: screen,
                settings: settings,
                expanded: settings.dynamicIslandPinned,
                desiredExpandedWidth: desiredDockHeight
            )
            return (dock: res.island, stage: res.stage)

        case .radialOnly:
            let diameter = min(360, max(200, CGFloat(settings.radialRingDiameter)))
            let dock = CGRect(
                x: vis.midX - diameter / 2,
                y: vis.midY - diameter / 2,
                width: diameter,
                height: diameter
            ).integral
            return (dock, fullStage)
        }
    }

    public static func popDirection(
        for dock: CGRect,
        on screen: ScreenInfo,
        shape: DockShapeMode,
        islandPosition: DockEdgePosition = .top
    ) -> DockPopDirection {
        switch shape {
        case .dynamicIsland:
            switch islandPosition {
            case .top: return .down
            case .bottom: return .up
            case .left: return .right
            case .right: return .left
            }
        case .radialOnly:
            return .none
        }
    }

    // MARK: - Loop-Style Radial Menu Sector Math & Screen Clamping

    public static func radialSelectedIndex(
        from anchorAppKit: CGPoint,
        to currentAppKit: CGPoint,
        itemCount: Int,
        deadzoneRadius: CGFloat = 24
    ) -> (index: Int?, angleRadians: CGFloat, distance: CGFloat) {
        let dx = currentAppKit.x - anchorAppKit.x
        let dyDown = -(currentAppKit.y - anchorAppKit.y)
        let distance = hypot(dx, dyDown)
        let angle = atan2(dyDown, dx)

        guard itemCount > 0, distance >= deadzoneRadius else {
            return (nil, angle, distance)
        }

        let twoPi = CGFloat.pi * 2.0
        let step = twoPi / CGFloat(itemCount)
        var relative = angle - (-.pi / 2.0) + step / 2.0
        relative = relative.truncatingRemainder(dividingBy: twoPi)
        if relative < 0 { relative += twoPi }

        let idx = min(itemCount - 1, max(0, Int(floor(relative / step))))
        return (idx, angle, distance)
    }

    /// Target window frame (Quartz) for a Loop-style radial layout choice inside a base stage rect.
    public static func radialLayoutFrameQuartz(
        _ layout: RadialLayoutTarget,
        base: CGRect,
        screen: ScreenInfo,
        splitGap: CGFloat
    ) -> CGRect {
        let gap = max(0, splitGap)
        switch layout {
        case .stage:
            return base.integral

        case .leftHalf:
            return splitFrames(forStage: base, splitGap: gap).left

        case .rightHalf:
            return splitFrames(forStage: base, splitGap: gap).right

        case .topHalf:
            let topH = floor((base.height - gap) / 2)
            return CGRect(x: base.minX, y: base.minY, width: base.width, height: max(220, topH)).integral

        case .bottomHalf:
            let topH = floor((base.height - gap) / 2)
            let botH = base.height - gap - topH
            return CGRect(x: base.minX, y: base.minY + topH + gap, width: base.width, height: max(220, botH)).integral

        case .topLeftQuarter:
            let lr = splitFrames(forStage: base, splitGap: gap).left
            let topH = floor((base.height - gap) / 2)
            return CGRect(x: lr.minX, y: base.minY, width: lr.width, height: max(220, topH)).integral

        case .topRightQuarter:
            let rr = splitFrames(forStage: base, splitGap: gap).right
            let topH = floor((base.height - gap) / 2)
            return CGRect(x: rr.minX, y: base.minY, width: rr.width, height: max(220, topH)).integral

        case .bottomLeftQuarter:
            let lr = splitFrames(forStage: base, splitGap: gap).left
            let topH = floor((base.height - gap) / 2)
            let botH = base.height - gap - topH
            return CGRect(x: lr.minX, y: base.minY + topH + gap, width: lr.width, height: max(220, botH)).integral

        case .bottomRightQuarter:
            let rr = splitFrames(forStage: base, splitGap: gap).right
            let topH = floor((base.height - gap) / 2)
            let botH = base.height - gap - topH
            return CGRect(x: rr.minX, y: base.minY + topH + gap, width: rr.width, height: max(220, botH)).integral

        case .maximize:
            return screen.visibleFrameQuartz.integral

        case .center:
            let w = min(base.width, max(480, base.width * 0.72))
            let h = min(base.height, max(360, base.height * 0.78))
            return CGRect(x: base.midX - w / 2, y: base.midY - h / 2, width: w, height: h).integral
        }
    }

    /// Scales a layout rect anchored to its split edge (used by Ring + Modifier + Scroll resize).
    public static func scaledFrameQuartz(
        _ rect: CGRect,
        scale: CGFloat,
        within bounds: CGRect,
        anchor: RadialLayoutTarget
    ) -> CGRect {
        let s = min(1.0, max(0.45, scale))
        guard s < 0.999 else { return rect.integral }

        let targetW = max(320, round(rect.width * s))
        let targetH = max(240, round(rect.height * s))

        let x: CGFloat
        switch anchor {
        case .leftHalf, .topLeftQuarter, .bottomLeftQuarter:
            x = rect.minX
        case .rightHalf, .topRightQuarter, .bottomRightQuarter:
            x = rect.maxX - targetW
        default:
            x = rect.midX - targetW * 0.5
        }

        let y: CGFloat
        switch anchor {
        case .topHalf, .topLeftQuarter, .topRightQuarter:
            y = rect.minY
        case .bottomHalf, .bottomLeftQuarter, .bottomRightQuarter:
            y = rect.maxY - targetH
        default:
            y = rect.midY - targetH * 0.5
        }

        let clampedX = min(max(x, bounds.minX), max(bounds.minX, bounds.maxX - targetW))
        let clampedY = min(max(y, bounds.minY), max(bounds.minY, bounds.maxY - targetH))
        return CGRect(x: clampedX, y: clampedY, width: targetW, height: targetH).integral
    }

    public static func adjustedWindowScale(
        current: CGFloat,
        pointerDeltaY: CGFloat
    ) -> CGFloat {
        let next = current + pointerDeltaY / 240.0
        return min(1.0, max(0.45, next))
    }

    public static func adjustedWindowScale(
        current: CGFloat,
        scrollDelta: CGFloat,
        precise: Bool
    ) -> CGFloat {
        let step: CGFloat = precise ? (scrollDelta / 180.0) : (scrollDelta > 0 ? 0.05 : -0.05)
        return min(1.0, max(0.45, current + step))
    }

    /// Loop-style 8-direction compass (4 halves + 4 quarters) + center deadzone.
    public static func loopSplitTarget(
        from anchorAppKit: CGPoint,
        to currentAppKit: CGPoint,
        deadzoneRadius: CGFloat = 24,
        centerDefault: RadialLayoutTarget = .maximize
    ) -> (target: RadialLayoutTarget, sectorIndex: Int?, angleDegrees: Double, isOuterRing: Bool) {
        let dx = currentAppKit.x - anchorAppKit.x
        let dyDown = -(currentAppKit.y - anchorAppKit.y)
        let distance = hypot(dx, dyDown)
        guard distance >= deadzoneRadius else {
            return (centerDefault, nil, 0, false)
        }

        let angle = atan2(dyDown, dx)
        let twoPi = CGFloat.pi * 2.0
        let step = twoPi / 8.0
        var relative = angle - (-.pi / 2.0) + step / 2.0
        relative = relative.truncatingRemainder(dividingBy: twoPi)
        if relative < 0 { relative += twoPi }

        let sector = min(7, max(0, Int(floor(relative / step))))
        let wedgeDeg = Double(sector) * 45.0

        let target: RadialLayoutTarget
        switch sector {
        case 0: target = .topHalf
        case 1: target = .topRightQuarter
        case 2: target = .rightHalf
        case 3: target = .bottomRightQuarter
        case 4: target = .bottomHalf
        case 5: target = .bottomLeftQuarter
        case 6: target = .leftHalf
        case 7: target = .topLeftQuarter
        default: target = centerDefault
        }
        return (target, sector, wedgeDeg, false)
    }

    public static func radialPanelRectAppKit(
        centeredAt anchorAppKit: CGPoint,
        panelSize: CGFloat,
        screens: [ScreenInfo]
    ) -> CGRect {
        let primaryH = screens.first(where: { $0.frameAppKit.origin == .zero })?.frameAppKit.height
            ?? screens.first?.frameAppKit.height
            ?? 1080
        let anchorQuartz = CGPoint(x: anchorAppKit.x, y: primaryH - anchorAppKit.y)
        let scr = screen(containingQuartzPoint: anchorQuartz, screens: screens)
        let vis = scr?.visibleFrameAppKit ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let pad: CGFloat = 8
        let half = panelSize / 2.0
        let minCenterX = vis.minX + pad + half
        let maxCenterX = max(minCenterX, vis.maxX - pad - half)
        let minCenterY = vis.minY + pad + half
        let maxCenterY = max(minCenterY, vis.maxY - pad - half)

        let cx = min(max(anchorAppKit.x, minCenterX), maxCenterX)
        let cy = min(max(anchorAppKit.y, minCenterY), maxCenterY)
        return CGRect(x: cx - half, y: cy - half, width: panelSize, height: panelSize).integral
    }

    public static func expandRect(
        _ rect: CGRect,
        toward direction: DockPopDirection,
        by amount: CGFloat
    ) -> CGRect {
        guard amount > 0 else { return rect }
        switch direction {
        case .up:
            return CGRect(x: rect.minX, y: rect.minY - amount, width: rect.width, height: rect.height + amount)
        case .down:
            return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height + amount)
        case .left:
            return CGRect(x: rect.minX - amount, y: rect.minY, width: rect.width + amount, height: rect.height)
        case .right:
            return CGRect(x: rect.minX, y: rect.minY, width: rect.width + amount, height: rect.height)
        case .none:
            return rect
        }
    }

    public static func lockedStageFrameQuartz(on screen: ScreenInfo, settings: StageSettings) -> CGRect {
        dockAndStageFramesQuartz(
            on: screen,
            customDockOriginQuartz: nil,
            settings: settings,
            desiredDockHeight: 460
        ).stage
    }

    public static func lockedDockFrameQuartz(
        on screen: ScreenInfo,
        settings: StageSettings,
        desiredHeight: CGFloat
    ) -> CGRect {
        dockAndStageFramesQuartz(
            on: screen,
            customDockOriginQuartz: nil,
            settings: settings,
            desiredDockHeight: desiredHeight
        ).dock
    }

    // MARK: - 50/50 Split & Stage-Manager Card-Grid Tiling

    public static func splitFrames(forStage stage: CGRect, splitGap: CGFloat) -> (left: CGRect, right: CGRect) {
        let halfW = floor((stage.width - splitGap) / 2)
        let rightW = stage.width - splitGap - halfW
        let left = CGRect(
            x: stage.minX,
            y: stage.minY,
            width: max(320, halfW),
            height: stage.height
        ).integral
        let right = CGRect(
            x: left.maxX + splitGap,
            y: stage.minY,
            width: max(320, rightW),
            height: stage.height
        ).integral
        return (left, right)
    }

    public enum WindowSwitchAction: Equatable, Sendable {
        case preserveExisting
        case moveToScreenPreservingSize(CGRect)
        case fitToStage
    }

    public static func resolveWindowSwitchAction(
        autoFitWindowOnSwitch: Bool,
        pullCrossScreenAppsToIsland: Bool,
        existingFrameQuartz: CGRect?,
        windowScreenID: String?,
        dockScreen: ScreenInfo?,
        hasExplicitOverrideFrame: Bool,
        forceAlignToDockScreen: Bool
    ) -> WindowSwitchAction {
        if hasExplicitOverrideFrame || forceAlignToDockScreen {
            return .fitToStage
        }
        guard let frame = existingFrameQuartz, !frame.isEmpty else {
            return autoFitWindowOnSwitch ? .fitToStage : .preserveExisting
        }
        let isOnOtherScreen = (windowScreenID != nil && dockScreen != nil && windowScreenID != dockScreen!.id)
        if isOnOtherScreen {
            if !pullCrossScreenAppsToIsland {
                return .preserveExisting
            }
            if autoFitWindowOnSwitch {
                return .fitToStage
            }
            let vis = dockScreen!.visibleFrameQuartz
            let w = min(frame.width, vis.width)
            let h = min(frame.height, vis.height)
            let moved = CGRect(
                x: vis.midX - w / 2.0,
                y: vis.midY - h / 2.0,
                width: w,
                height: h
            ).integral
            return .moveToScreenPreservingSize(moved)
        }
        return autoFitWindowOnSwitch ? .fitToStage : .preserveExisting
    }

    public static func shouldPreserveExistingWindowFrame(
        policy: MultiScreenAppPolicy,
        windowScreenID: String?,
        dockScreenID: String?,
        hasExplicitOverrideFrame: Bool,
        forceAlignToDockScreen: Bool
    ) -> Bool {
        guard !hasExplicitOverrideFrame, !forceAlignToDockScreen else { return false }
        guard let windowScreenID else { return false }
        switch policy {
        case .followDockScreen:
            return false
        case .keepOriginalScreen:
            return true
        case .smartKeepOtherScreen:
            guard let dockScreenID else { return false }
            return windowScreenID != dockScreenID
        }
    }

    /// Returns `true` only when committing an app from the radial ring should apply an explicit
    /// resize/split/pinned fill frame instead of preserving the app's own screen and window geometry.
    public static func shouldPassOverrideFrameOnAppCommit(
        layout: RadialLayoutTarget,
        pinnedFillFrame: CGRect?,
        customWindowScale: CGFloat
    ) -> Bool {
        layout != .stage || pinnedFillFrame != nil || customWindowScale < 0.999
    }

    /// Resolves which display's other staged apps may be hidden; on multi-display systems, never
    /// falls back to the dock display if the target app's display cannot be confirmed.
    public static func effectiveHideTargetScreenID(
        explicitScreenID: String?,
        targetAppLiveScreenID: String?,
        dockScreenID: String?,
        screenCount: Int
    ) -> String? {
        if let explicitScreenID { return explicitScreenID }
        if let targetAppLiveScreenID { return targetAppLiveScreenID }
        return screenCount <= 1 ? dockScreenID : nil
    }

    /// Returns `true` only when hiding the process cannot vanish any visible window on another display.
    public static func shouldHideAppOnScreenSwitch(
        appWindowFramesQuartz: [CGRect],
        targetScreenID: String?,
        screens: [ScreenInfo]
    ) -> Bool {
        guard let targetScreenID, !screens.isEmpty else { return false }
        if screens.count <= 1 {
            return true
        }
        guard !appWindowFramesQuartz.isEmpty else { return false }
        for frame in appWindowFramesQuartz {
            guard let winScreenID = screen(containingQuartzRect: frame, screens: screens)?.id else {
                return false
            }
            if winScreenID != targetScreenID {
                return false
            }
        }
        return true
    }
}
