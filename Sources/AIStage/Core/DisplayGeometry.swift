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

    /// Top inset of the expanded island when there is no camera notch to clear. The title
    /// header (app name + "…") was removed; "…" now lives in the tray after "+".
    public static let islandHeaderInset: CGFloat = 12

    public static func minExpandedIslandDepth(
        settings: StageSettings,
        topBand: CGFloat,
        isVerticalTray: Bool
    ) -> CGFloat {
        let iconSz = CGFloat(settings.iconSize)
        if isVerticalTray {
            return ceil(iconSz + 36)
        }
        let pillH = iconSz + 10
        let dotH = max(5, CGFloat(settings.effectiveIndicatorSize) + 2)
        let gap = max(2, round(iconSz * 0.055))
        return ceil(topBand + pillH + gap + dotH + 14)
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

        let iconBand = CGFloat(settings.iconSize) + max(28, CGFloat(settings.iconSize) * 0.52)
        let magHeadroom: CGFloat = settings.magnificationScale > 1.01
            ? ceil(CGFloat(settings.iconSize) * CGFloat(settings.magnificationScale - 1.0) * 0.65) + 8
            : 0
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
                let minSafeW = max(screen.notchWidth > 0 ? round(screen.notchWidth + 16) : 64, minExpandedIslandDepth(settings: settings, topBand: 0, isVerticalTray: true))
                let baseW = round(iconBand + magHeadroom + 26)
                let autoWidth = max(minSafeW, screen.notchWidth > 0 ? max(baseW, round(screen.notchWidth + 16)) : baseW)
                let maxW = min(260, vis.width - 48)
                let width = settings.islandCustomWidth > 1
                    ? min(maxW, max(minSafeW, round(CGFloat(settings.islandCustomWidth))))
                    : autoWidth
                let maxH = max(300, vis.height - 48)
                let autoHeight = min(max(300, desiredExpandedWidth + topNotchBand), maxH)
                let height = settings.islandCustomHeight > 1
                    ? min(maxH, max(220, round(CGFloat(settings.islandCustomHeight))))
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
            let autoHeight = max(minSafeTopH, round(topNotchBand + 8 + iconBand + magHeadroom))
            let maxCustomH = max(minSafeTopH, min(260, vis.height - 48))
            let height = settings.islandCustomHeight > 1
                ? min(maxCustomH, max(minSafeTopH, round(CGFloat(settings.islandCustomHeight))))
                : autoHeight
            let minExpandedW: CGFloat = screen.notchWidth > 0 ? max(420, screen.notchWidth + 230) : 320
            let maxW = max(minExpandedW, vis.width - 40)
            let autoWidth = min(max(minExpandedW, desiredExpandedWidth), maxW)
            let minCustomW: CGFloat = screen.notchWidth > 0 ? max(280, round(screen.notchWidth + 120)) : 260
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
                let autoWidth = max(minSafeW, round(iconBand + magHeadroom + 24))
                let maxW = min(260, vis.width - 48)
                let width = settings.islandCustomWidth > 1
                    ? min(maxW, max(minSafeW, round(CGFloat(settings.islandCustomWidth))))
                    : autoWidth
                let maxH = max(300, vis.height - 48)
                let autoHeight = min(max(300, desiredExpandedWidth), maxH)
                let height = settings.islandCustomHeight > 1
                    ? min(maxH, max(220, round(CGFloat(settings.islandCustomHeight))))
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
            let autoHeight = max(minSafeBotH, round(islandHeaderInset + 8 + iconBand + magHeadroom))
            let maxCustomH = max(minSafeBotH, min(260, vis.height - 48))
            let height = settings.islandCustomHeight > 1
                ? min(maxCustomH, max(minSafeBotH, round(CGFloat(settings.islandCustomHeight))))
                : autoHeight
            let maxW = max(320, vis.width - 40)
            let autoWidth = min(max(320, desiredExpandedWidth), maxW)
            let width = settings.islandCustomWidth > 1
                ? min(maxW, max(260, round(CGFloat(settings.islandCustomWidth))))
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
                let autoHeight = max(minSafeLeftH, round(islandHeaderInset + 8 + iconBand + magHeadroom))
                let maxCustomH = max(minSafeLeftH, min(260, vis.height - 48))
                let height = settings.islandCustomHeight > 1
                    ? min(maxCustomH, max(minSafeLeftH, round(CGFloat(settings.islandCustomHeight))))
                    : autoHeight
                let maxW = max(320, vis.width - 48)
                let autoWidth = min(max(320, desiredExpandedWidth), maxW)
                let width = settings.islandCustomWidth > 1
                    ? min(maxW, max(260, round(CGFloat(settings.islandCustomWidth))))
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
            let autoWidth = max(minSafeLeftW, round(iconBand + magHeadroom + 20))
            let maxW = min(260, vis.width - 48)
            let width = settings.islandCustomWidth > 1
                ? min(maxW, max(minSafeLeftW, round(CGFloat(settings.islandCustomWidth))))
                : autoWidth
            let maxH = max(300, vis.height - 48)
            let autoHeight = min(max(300, desiredExpandedWidth), maxH)
            let height = settings.islandCustomHeight > 1
                ? min(maxH, max(220, round(CGFloat(settings.islandCustomHeight))))
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
                let autoHeight = max(minSafeRightH, round(islandHeaderInset + 8 + iconBand + magHeadroom))
                let maxCustomH = max(minSafeRightH, min(260, vis.height - 48))
                let height = settings.islandCustomHeight > 1
                    ? min(maxCustomH, max(minSafeRightH, round(CGFloat(settings.islandCustomHeight))))
                    : autoHeight
                let maxW = max(320, vis.width - 48)
                let autoWidth = min(max(320, desiredExpandedWidth), maxW)
                let width = settings.islandCustomWidth > 1
                    ? min(maxW, max(260, round(CGFloat(settings.islandCustomWidth))))
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
            let autoWidth = max(minSafeRightW, round(iconBand + magHeadroom + 20))
            let maxW = min(260, vis.width - 48)
            let width = settings.islandCustomWidth > 1
                ? min(maxW, max(minSafeRightW, round(CGFloat(settings.islandCustomWidth))))
                : autoWidth
            let maxH = max(300, vis.height - 48)
            let autoHeight = min(max(300, desiredExpandedWidth), maxH)
            let height = settings.islandCustomHeight > 1
                ? min(maxH, max(220, round(CGFloat(settings.islandCustomHeight))))
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

        case .leftThird:
            let thirdW = max(280, floor((base.width - gap * 2) / 3))
            return CGRect(x: base.minX, y: base.minY, width: thirdW, height: base.height).integral

        case .centerThird:
            let thirdW = max(280, floor((base.width - gap * 2) / 3))
            return CGRect(x: base.minX + thirdW + gap, y: base.minY, width: thirdW, height: base.height).integral

        case .rightThird:
            let thirdW = max(280, floor((base.width - gap * 2) / 3))
            let x = base.minX + (thirdW + gap) * 2
            let w = max(280, base.maxX - x)
            return CGRect(x: x, y: base.minY, width: w, height: base.height).integral

        case .leftTwoThirds:
            let thirdW = max(280, floor((base.width - gap * 2) / 3))
            return CGRect(x: base.minX, y: base.minY, width: thirdW * 2 + gap, height: base.height).integral

        case .rightTwoThirds:
            let thirdW = max(280, floor((base.width - gap * 2) / 3))
            let x = base.minX + thirdW + gap
            let w = max(320, base.maxX - x)
            return CGRect(x: x, y: base.minY, width: w, height: base.height).integral

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
        case .leftHalf, .leftThird, .leftTwoThirds, .topLeftQuarter, .bottomLeftQuarter:
            x = rect.minX
        case .rightHalf, .rightThird, .rightTwoThirds, .topRightQuarter, .bottomRightQuarter:
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

    /// Loop-style 8-direction compass + center deadzone + outer third-ring geometry.
    public static func loopSplitTarget(
        from anchorAppKit: CGPoint,
        to currentAppKit: CGPoint,
        deadzoneRadius: CGFloat = 24,
        outerThirdRadius: CGFloat = 148,
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
        let isOuter = distance >= outerThirdRadius
        let wedgeDeg = Double(sector) * 45.0

        let target: RadialLayoutTarget
        switch sector {
        case 0: target = isOuter ? .maximize : .topHalf
        case 1: target = .topRightQuarter
        case 2: target = isOuter ? .rightThird : .rightHalf
        case 3: target = .bottomRightQuarter
        case 4: target = isOuter ? .centerThird : .bottomHalf
        case 5: target = .bottomLeftQuarter
        case 6: target = isOuter ? .leftThird : .leftHalf
        case 7: target = .topLeftQuarter
        default: target = centerDefault
        }
        return (target, sector, wedgeDeg, isOuter)
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
