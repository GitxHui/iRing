import AIStageCore
import AppKit
import QuartzCore
import SwiftUI

/// Live pointer coordinates inside the Dock panel (top-left SwiftUI space) and 120Hz spring expand progress.
@MainActor
public final class DockInteractionState: ObservableObject {
    @Published public var pointerInPanel: CGPoint? = nil
    @Published public var islandExpandProgress: CGFloat = 0.0
    public init() {}
}

/// While the island springs, the panel stays at a fixed oversized "canvas" and the island's
/// visible rect (top-left SwiftUI coordinates inside the panel) animates here instead of
/// resizing the NSWindow every frame. `nil` means the island fills the panel.
@MainActor
public final class DockCanvasState: ObservableObject {
    @Published public var islandRect: CGRect? = nil
    public init() {}
}

/// Positions the Dock content inside the (possibly oversized) panel canvas.
struct DockCanvasHost<Content: View>: View {
    @ObservedObject var canvas: DockCanvasState
    let content: Content

    var body: some View {
        // A single view structure for both states: switching between an if/else pair would
        // give DockView a new identity and reset its @State (hover, cell centers, namespace)
        // at the start and end of every animation.
        GeometryReader { geo in
            let rect = canvas.islandRect ?? CGRect(origin: .zero, size: geo.size)
            content
                .frame(width: rect.width, height: rect.height)
                .clipped()
                .position(x: rect.midX, y: rect.midY)
        }
    }
}

/// Non-activating borderless panel hosting the macOS 26 Liquid Glass Dock without stealing typing focus.
public final class StageDockPanel: NSPanel {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.worksWhenModal = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.animationBehavior = .none
    }
}

@MainActor
public final class DockPanelController: NSObject {
    public let panel: StageDockPanel
    private let coordinator: StageCoordinator
    private let interactionState = DockInteractionState()
    private let canvasState = DockCanvasState()
    /// AppKit frame of the oversized panel canvas while a spring is running (nil when settled).
    private var canvasRect: CGRect?
    /// AppKit frame of the island as the user sees it (differs from `panel.frame` mid-animation).
    private var visibleIslandFrame: CGRect = .zero

    private var settingsWindow: NSWindow?
    private var addAppWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private let metalTransitionController = MetalWindowTransitionController()
    nonisolated(unsafe) private var scrollEventMonitor: Any?
    nonisolated(unsafe) private var localMouseMonitor: Any?
    nonisolated(unsafe) private var globalMouseMonitor: Any?
    private var lastWheelSwitchUptime: TimeInterval = 0
    /// Scroll distance gathered toward the next app switch (precise/trackpad scrolling).
    private var wheelSwitchAccumulator: CGFloat = 0

    private var islandExpandWorkItem: DispatchWorkItem?
    private var islandCollapseWorkItem: DispatchWorkItem?
    private var autoHideRetractWorkItem: DispatchWorkItem?
    private var hoverExitWorkItem: DispatchWorkItem?
    private var screenFollowWorkItem: DispatchWorkItem?

    // 120Hz Apple Spring Physics state (AppKit coordinates)
    private var springDisplayLink: CADisplayLink?
    private var springMidX: CGFloat = 0
    private var springMidY: CGFloat = 0
    private var springW: CGFloat = 64
    private var springH: CGFloat = 30
    private var targetMidX: CGFloat = 0
    private var targetMidY: CGFloat = 0
    private var targetW: CGFloat = 64
    private var targetH: CGFloat = 30
    private var velMidX: CGFloat = 0
    private var velMidY: CGFloat = 0
    private var velW: CGFloat = 0
    private var velH: CGFloat = 0
    private var springProgress: CGFloat = 0
    private var targetProgress: CGFloat = 0
    private var velProgress: CGFloat = 0
    // Staggered springs: the axis along the docking edge leads, the perpendicular axis and
    // the content progress follow slightly behind (reversed on collapse).
    private var majorOmega: CGFloat = 20
    private var majorDamping: CGFloat = 0.82
    private var minorOmega: CGFloat = 20
    private var minorDamping: CGFloat = 0.82
    private var progressOmega: CGFloat = 20
    private var progressDamping: CGFloat = 0.88
    private var pinnedAnchorEdge: DockEdgePosition? = nil
    private var pinnedAnchorCoord: CGFloat = 0
    private var lastAnimatedEdge: DockEdgePosition
    private var lastAnimatedScreenID: String?
    private var hasInitializedSpringState = false
    /// True while one of our menus (the island "…" menu) is open; the island must not collapse
    /// underneath it, or the menu's anchor disappears and the island looks like it vanished.
    private var isMenuTracking = false
    nonisolated(unsafe) private var menuTrackingObservers: [NSObjectProtocol] = []

    public init(coordinator: StageCoordinator) {
        self.coordinator = coordinator
        self.lastAnimatedEdge = coordinator.settings.islandPosition
        self.lastAnimatedScreenID = coordinator.pinnedScreenID
        self.interactionState.islandExpandProgress = (coordinator.isDynamicIslandExpanded || coordinator.settings.dynamicIslandPinned) ? 1.0 : 0.0
        self.springProgress = self.interactionState.islandExpandProgress
        self.targetProgress = self.interactionState.islandExpandProgress

        let initialRect = NSRect(x: 16, y: 200, width: coordinator.settings.dockWidth, height: 480)
        self.panel = StageDockPanel(contentRect: initialRect)
        super.init()

        setupGlassContent()
        bindCoordinatorCallbacks()
        applyWindowLevel(isTopDynamicIsland: coordinator.settings.dockShape == .dynamicIsland && coordinator.settings.islandPosition == .top)
        installScrollWheelMonitor()
        installMouseTrackingMonitors()
        installMenuTrackingObservers()
    }

    private func installMenuTrackingObservers() {
        let center = NotificationCenter.default
        menuTrackingObservers.append(center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isMenuTracking = true
                self.islandCollapseWorkItem?.cancel()
                self.islandCollapseWorkItem = nil
            }
        })
        menuTrackingObservers.append(center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isMenuTracking = false
                // Re-evaluate hover now that the menu is gone (collapses if the pointer left).
                self.processPointerLocation()
            }
        })
    }

    deinit {
        springDisplayLink?.invalidate()
        for token in menuTrackingObservers {
            NotificationCenter.default.removeObserver(token)
        }
        if let monitor = scrollEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupGlassContent() {
        let rootView = DockCanvasHost(
            canvas: canvasState,
            content: DockView(
                coordinator: coordinator,
                interactionState: interactionState,
                currentDockSize: { [weak self] in self?.currentVisibleFrame.size ?? CGSize(width: 64, height: 420) },
                currentPanelFrameAppKit: { [weak self] in self?.panel.frame ?? .zero },
                onOpenAddApp: { [weak self] in self?.showAddAppWindow() },
                onOpenSettings: { [weak self] in self?.showSettingsWindow() }
            )
        )
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = panel.contentRect(forFrameRect: panel.frame)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.shadowOpacity = 0
        panel.contentView = hostingView
    }

    private func applyWindowLevel(isTopDynamicIsland: Bool) {
        if isTopDynamicIsland {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        } else {
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        }
    }

    private func bindCoordinatorCallbacks() {
        coordinator.onDockWindowLevelShouldUpdate = { [weak self] isTopDynamicIsland in
            self?.applyWindowLevel(isTopDynamicIsland: isTopDynamicIsland)
        }

        coordinator.onDockFrameShouldUpdate = { [weak self] targetAppKitFrame, animated in
            self?.animateDockFrame(to: targetAppKitFrame, animated: animated)
        }

        coordinator.onDockVisibilityShouldChange = { [weak self] visible in
            guard let self = self else { return }
            if visible {
                self.panel.alphaValue = 1.0
                self.panel.orderFrontRegardless()
            } else {
                self.finishSpringImmediately()
                self.panel.orderOut(nil)
            }
        }

        coordinator.onDockZOrderShouldUpdate = { [weak self] mode in
            guard let self = self else { return }
            switch mode {
            case .floatingFront:
                self.applyWindowLevel(isTopDynamicIsland: self.coordinator.settings.dockShape == .dynamicIsland && self.coordinator.settings.islandPosition == .top)
                self.panel.orderFrontRegardless()
            case .normalBelow(let frontWindowNumber):
                if self.panel.level != .normal {
                    self.panel.level = .normal
                }
                if let winNum = frontWindowNumber {
                    self.panel.order(.below, relativeTo: winNum)
                }
            case .hidden:
                self.finishSpringImmediately()
                self.panel.orderOut(nil)
            }
        }

        coordinator.onOpenSettingsRequested = { [weak self] in
            self?.showSettingsWindow()
        }

        coordinator.onOpenAddAppRequested = { [weak self] in
            self?.showAddAppWindow()
        }

        coordinator.onLanguageDidChange = { [weak self] in
            guard let self else { return }
            self.settingsWindow?.title = L10n.t("iRing 偏好设置", "iRing Settings")
            self.addAppWindow?.title = L10n.t("添加应用到 iRing", "Add Apps to iRing")
            self.onboardingWindow?.title = L10n.t("欢迎使用 iRing", "Welcome to iRing")
        }

        coordinator.onPlayWindowPopTransition = { [weak self] style, item, image, fromIconRect, toWindowRect, duration, completion in
            guard let self else {
                completion()
                return
            }
            let icon = self.coordinator.discovery.icon(for: item)
            self.metalTransitionController.playTransition(
                style: style,
                image: image,
                appName: item.displayName,
                icon: icon,
                fromIconRectAppKit: fromIconRect,
                toWindowRectAppKit: toWindowRect,
                duration: duration,
                completion: completion
            )
        }
    }

    /// The island's on-screen AppKit frame: the spring rect while animating, otherwise the panel frame.
    private var currentVisibleFrame: CGRect {
        canvasRect != nil ? visibleIslandFrame : panel.frame
    }

    /// Visible background frame excluding the transparent magnification pop-out strip.
    private var currentBackgroundFrame: CGRect {
        var r = currentVisibleFrame
        guard coordinator.settings.dockShape == .dynamicIsland,
              coordinator.settings.islandExpandAxis == .alongEdge
        else { return r }
        let overflow = DisplayGeometry.magnificationOverflow(settings: coordinator.settings) * interactionState.islandExpandProgress
        guard overflow > 0.5 else { return r }
        switch coordinator.settings.islandPosition {
        case .top:
            r.origin.y += overflow
            r.size.height = max(24, r.size.height - overflow)
        case .bottom:
            r.size.height = max(24, r.size.height - overflow)
        case .left:
            r.size.width = max(24, r.size.width - overflow)
        case .right:
            r.origin.x += overflow
            r.size.width = max(24, r.size.width - overflow)
        }
        return r
    }

    private func animateDockFrame(to targetAppKitFrame: CGRect, animated: Bool) {
        let rounded = targetAppKitFrame.integral
        let edge = coordinator.settings.islandPosition
        let screenID = coordinator.pinnedScreenID
        let desiredProgress: CGFloat = (coordinator.isDynamicIslandExpanded || coordinator.settings.dynamicIslandPinned) ? 1.0 : 0.0
        let speed = coordinator.settings.islandAnimationSpeed
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if !hasInitializedSpringState {
            hasInitializedSpringState = true
            springMidX = rounded.midX
            springMidY = rounded.midY
            springW = rounded.width
            springH = rounded.height
            springProgress = desiredProgress
        }

        let current = currentVisibleFrame
        let delta = abs(current.origin.x - rounded.origin.x)
            + abs(current.origin.y - rounded.origin.y)
            + abs(current.size.width - rounded.size.width)
            + abs(current.size.height - rounded.size.height)
            + abs(interactionState.islandExpandProgress - desiredProgress) * 100.0

        let prevEdge = lastAnimatedEdge
        let prevScreenID = lastAnimatedScreenID
        lastAnimatedEdge = edge
        lastAnimatedScreenID = screenID

        if !animated || speed.isInstant || reduceMotion || delta <= 0.5 || !panel.isVisible {
            stopSpringDisplayLink()
            springMidX = rounded.midX
            springMidY = rounded.midY
            springW = rounded.width
            springH = rounded.height
            targetMidX = rounded.midX
            targetMidY = rounded.midY
            targetW = rounded.width
            targetH = rounded.height
            velMidX = 0
            velMidY = 0
            velW = 0
            velH = 0
            springProgress = desiredProgress
            targetProgress = desiredProgress
            velProgress = 0
            if interactionState.islandExpandProgress != desiredProgress {
                interactionState.islandExpandProgress = desiredProgress
            }
            settleCanvas(to: rounded)
            return
        }

        if springDisplayLink == nil {
            springMidX = current.midX
            springMidY = current.midY
            springW = max(24, current.width)
            springH = max(24, current.height)
            springProgress = interactionState.islandExpandProgress
        }

        let sameEdgeAndScreen = (edge == prevEdge && screenID == prevScreenID)
        let edgeOffset: CGFloat = switch edge {
        case .top: abs(current.maxY - rounded.maxY)
        case .bottom: abs(current.minY - rounded.minY)
        case .left: abs(current.minX - rounded.minX)
        case .right: abs(current.maxX - rounded.maxX)
        }
        let isSameScreenInPlace = !coordinator.isDraggingDock && sameEdgeAndScreen && edgeOffset < 120

        if isSameScreenInPlace {
            pinnedAnchorEdge = edge
            switch edge {
            case .top: pinnedAnchorCoord = rounded.maxY
            case .bottom: pinnedAnchorCoord = rounded.minY
            case .left: pinnedAnchorCoord = rounded.minX
            case .right: pinnedAnchorCoord = rounded.maxX
            }
        } else {
            pinnedAnchorEdge = nil
        }

        targetMidX = rounded.midX
        targetMidY = rounded.midY
        targetW = rounded.width
        targetH = rounded.height
        targetProgress = desiredProgress

        let scaleFactor: CGFloat = switch speed {
        case .instant: 0.0
        case .fast: 0.78
        case .smooth: 1.0
        case .relaxed: 1.32
        }

        // Expand: the edge-parallel axis leads with a hint of overshoot, the perpendicular
        // axis drops in ~40ms later, content fades in last. Collapse: reverse order, no overshoot.
        let majorResponse: CGFloat
        let minorResponse: CGFloat
        let progressResponse: CGFloat
        if abs(desiredProgress - springProgress) > 0.05 {
            if desiredProgress > springProgress {
                majorResponse = 0.32; majorDamping = 0.74
                minorResponse = 0.38; minorDamping = 0.84
                progressResponse = 0.36; progressDamping = 0.90
            } else {
                majorResponse = 0.30; majorDamping = 0.92
                minorResponse = 0.24; minorDamping = 0.94
                progressResponse = 0.20; progressDamping = 0.96
            }
        } else {
            majorResponse = 0.34; majorDamping = 0.84
            minorResponse = 0.34; minorDamping = 0.84
            progressResponse = 0.34; progressDamping = 0.88
        }
        majorOmega = (2.0 * .pi) / max(0.08, majorResponse * scaleFactor)
        minorOmega = (2.0 * .pi) / max(0.08, minorResponse * scaleFactor)
        progressOmega = (2.0 * .pi) / max(0.08, progressResponse * scaleFactor)

        if springDisplayLink == nil, let view = panel.contentView {
            let link = view.displayLink(target: self, selector: #selector(handleSpringDisplayLink(_:)))
            link.add(to: .main, forMode: .common)
            springDisplayLink = link
        }
    }

    private func stopSpringDisplayLink() {
        springDisplayLink?.invalidate()
        springDisplayLink = nil
    }

    /// Ends canvas mode: the panel snaps back to exactly the island frame (one resize).
    private func settleCanvas(to frame: CGRect) {
        let wasCanvas = canvasRect != nil
        canvasRect = nil
        visibleIslandFrame = frame
        // Reset the inner rect before resizing, and don't force an immediate redraw when
        // leaving canvas mode: the window size and SwiftUI layout must land in the same pass,
        // otherwise one frame shows the island at its canvas offset inside the small window.
        if canvasState.islandRect != nil {
            canvasState.islandRect = nil
        }
        if panel.frame != frame {
            panel.setFrame(frame, display: !wasCanvas)
        }
    }

    /// Jumps a running spring straight to its target (used when the panel is hidden mid-flight,
    /// since a display link stops firing for an off-screen window and would leave the canvas stuck).
    private func finishSpringImmediately() {
        guard springDisplayLink != nil || canvasRect != nil else { return }
        stopSpringDisplayLink()
        let finalRect = CGRect(
            x: targetMidX - targetW / 2.0,
            y: targetMidY - targetH / 2.0,
            width: targetW,
            height: targetH
        ).integral
        springMidX = finalRect.midX
        springMidY = finalRect.midY
        springW = finalRect.width
        springH = finalRect.height
        springProgress = targetProgress
        velMidX = 0; velMidY = 0; velW = 0; velH = 0; velProgress = 0
        interactionState.islandExpandProgress = targetProgress
        settleCanvas(to: finalRect)
    }

    /// Real hardware button state. NSEvent.pressedMouseButtons follows the event stream, so any
    /// event tap that swallows a button-up (ours or another app's) can leave it stuck "pressed".
    private var anyMouseButtonPhysicallyDown: Bool {
        for button in [CGMouseButton.left, .right, .center] {
            if CGEventSource.buttonState(.hidSystemState, button: button) { return true }
        }
        for raw: UInt32 in [3, 4] {
            if let extra = CGMouseButton(rawValue: raw),
               CGEventSource.buttonState(.hidSystemState, button: extra) {
                return true
            }
        }
        return false
    }

    /// Grows the panel once to a canvas covering the start, the target and spring overshoot,
    /// clamped so it never extends past the anchored screen edge.
    private func makeCanvas(covering rect: CGRect) -> CGRect {
        let target = CGRect(x: targetMidX - targetW / 2, y: targetMidY - targetH / 2, width: targetW, height: targetH)
        let travel = abs(targetW - rect.width) + abs(targetH - rect.height)
            + abs(targetMidX - rect.midX) + abs(targetMidY - rect.midY)
        let margin = 20 + travel * 0.14
        var canvas = rect.union(target).insetBy(dx: -margin, dy: -margin)
        if let anchor = pinnedAnchorEdge {
            switch anchor {
            case .top: canvas.size.height = pinnedAnchorCoord - canvas.minY
            case .bottom:
                canvas.size.height = canvas.maxY - pinnedAnchorCoord
                canvas.origin.y = pinnedAnchorCoord
            case .left:
                canvas.size.width = canvas.maxX - pinnedAnchorCoord
                canvas.origin.x = pinnedAnchorCoord
            case .right: canvas.size.width = pinnedAnchorCoord - canvas.minX
            }
        }
        return canvas.integral
    }

    @objc private func handleSpringDisplayLink(_ link: CADisplayLink) {
        let rawDt = link.targetTimestamp - link.timestamp
        let dt = CGFloat(min(1.0 / 30.0, max(1.0 / 240.0, rawDt > 0 ? rawDt : (1.0 / 60.0))))
        let subSteps = 2
        let subDt = dt / CGFloat(subSteps)
        let horizontalMajor = !coordinator.settings.islandPosition.isVertical
        let xOmega = horizontalMajor ? majorOmega : minorOmega
        let xDamping = horizontalMajor ? majorDamping : minorDamping
        let yOmega = horizontalMajor ? minorOmega : majorOmega
        let yDamping = horizontalMajor ? minorDamping : majorDamping

        for _ in 0..<subSteps {
            stepSpring(&springMidX, &velMidX, target: targetMidX, omega: xOmega, zeta: xDamping, dt: subDt)
            stepSpring(&springW, &velW, target: targetW, omega: xOmega, zeta: xDamping, dt: subDt)
            stepSpring(&springMidY, &velMidY, target: targetMidY, omega: yOmega, zeta: yDamping, dt: subDt)
            stepSpring(&springH, &velH, target: targetH, omega: yOmega, zeta: yDamping, dt: subDt)
            stepSpring(&springProgress, &velProgress, target: targetProgress, omega: progressOmega, zeta: progressDamping, dt: subDt)
        }

        let clampedW = max(24, springW)
        let clampedH = max(24, springH)
        var originX = springMidX - clampedW / 2.0
        var originY = springMidY - clampedH / 2.0

        if let anchorEdge = pinnedAnchorEdge {
            switch anchorEdge {
            case .top:
                originY = pinnedAnchorCoord - clampedH
            case .bottom:
                originY = pinnedAnchorCoord
            case .left:
                originX = pinnedAnchorCoord
            case .right:
                originX = pinnedAnchorCoord - clampedW
            }
        }

        let nextRect = CGRect(x: originX, y: originY, width: clampedW, height: clampedH)
        visibleIslandFrame = nextRect

        // Resize the window only when the island would leave the current canvas
        // (normally once per transition), then move the island inside it in SwiftUI.
        if canvasRect == nil || !(canvasRect!.contains(nextRect)) {
            let canvas = makeCanvas(covering: nextRect)
            canvasRect = canvas
            panel.setFrame(canvas, display: false)
        }
        if let canvas = canvasRect {
            canvasState.islandRect = CGRect(
                x: nextRect.minX - canvas.minX,
                y: canvas.maxY - nextRect.maxY,
                width: nextRect.width,
                height: nextRect.height
            )
        }

        let clampedProgress = min(1.0, max(0.0, springProgress))
        if abs(interactionState.islandExpandProgress - clampedProgress) > 0.002 {
            interactionState.islandExpandProgress = clampedProgress
        }

        let distErr = abs(springMidX - targetMidX)
            + abs(springMidY - targetMidY)
            + abs(springW - targetW)
            + abs(springH - targetH)
        let velMag = abs(velMidX) + abs(velMidY) + abs(velW) + abs(velH) + abs(velProgress) * 100.0
        let progErr = abs(springProgress - targetProgress)

        if distErr < 0.35 && progErr < 0.004 && velMag < 1.0 {
            let finalRect = CGRect(
                x: targetMidX - targetW / 2.0,
                y: targetMidY - targetH / 2.0,
                width: targetW,
                height: targetH
            ).integral
            interactionState.islandExpandProgress = targetProgress
            springMidX = finalRect.midX
            springMidY = finalRect.midY
            springW = finalRect.width
            springH = finalRect.height
            springProgress = targetProgress
            velMidX = 0; velMidY = 0; velW = 0; velH = 0; velProgress = 0
            stopSpringDisplayLink()
            settleCanvas(to: finalRect)
        }
    }

    private func stepSpring(
        _ value: inout CGFloat,
        _ velocity: inout CGFloat,
        target: CGFloat,
        omega: CGFloat,
        zeta: CGFloat,
        dt: CGFloat
    ) {
        let accel = omega * omega * (target - value) - 2.0 * zeta * omega * velocity
        velocity += accel * dt
        value += velocity * dt
    }

    // MARK: - Pointer Tracking (Wave Magnification, Dynamic Island Hover & Auto-Hide Edge Peek)

    private func installMouseTrackingMonitors() {
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.processPointerLocation()
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in
                self?.processPointerLocation()
            }
        }
    }

    private func processPointerLocation() {
        guard !coordinator.isStageHidden, panel.isVisible else {
            if interactionState.pointerInPanel != nil {
                interactionState.pointerInPanel = nil
            }
            return
        }

        let mouseAppKit = NSEvent.mouseLocation
        let mouseButtonsPressed = anyMouseButtonPhysicallyDown

        // 0. Optional Pointer Screen-Follow (off by default: explicit drag moves across screens)
        if coordinator.settings.followActiveScreen && !mouseButtonsPressed && coordinator.settings.dockShape == .dynamicIsland {
            let primaryH = DisplayGeometry.primaryScreenHeight()
            let mouseQuartz = CGPoint(x: mouseAppKit.x, y: primaryH - mouseAppKit.y)
            let screens = DisplayGeometry.allScreens()
            if let mouseScreen = DisplayGeometry.screen(containingQuartzPoint: mouseQuartz, screens: screens),
               mouseScreen.id != coordinator.pinnedScreenID {
                if mouseQuartz.y <= mouseScreen.frameQuartz.minY + 48 {
                    screenFollowWorkItem?.cancel()
                    screenFollowWorkItem = nil
                    coordinator.followToScreen(mouseScreen, animated: false)
                    if !coordinator.settings.dynamicIslandPinned {
                        coordinator.setDynamicIslandExpanded(true)
                    }
                    return
                } else if screenFollowWorkItem == nil {
                    let work = DispatchWorkItem { [weak self] in
                        self?.screenFollowWorkItem = nil
                        guard let self = self,
                              self.coordinator.settings.followActiveScreen,
                              !self.anyMouseButtonPhysicallyDown
                        else { return }
                        let nowAppKit = NSEvent.mouseLocation
                        let nowH = DisplayGeometry.primaryScreenHeight()
                        let nowQuartz = CGPoint(x: nowAppKit.x, y: nowH - nowAppKit.y)
                        let curScreens = DisplayGeometry.allScreens()
                        if let curScr = DisplayGeometry.screen(containingQuartzPoint: nowQuartz, screens: curScreens),
                           curScr.id != self.coordinator.pinnedScreenID {
                            self.coordinator.followToScreen(curScr, animated: false)
                        }
                    }
                    screenFollowWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: work)
                }
            } else {
                screenFollowWorkItem?.cancel()
                screenFollowWorkItem = nil
            }
        }

        let frame = currentVisibleFrame
        let bgFrame = currentBackgroundFrame

        // 1. Parabolic Magnification Pointer Tracking
        let inPanel = bgFrame.contains(mouseAppKit)
        let inMagnificationCatchZone = bgFrame.insetBy(dx: -8, dy: -8).contains(mouseAppKit)

        if inPanel {
            let localPoint = CGPoint(
                x: mouseAppKit.x - frame.minX,
                y: frame.maxY - mouseAppKit.y
            )
            if let existing = interactionState.pointerInPanel {
                if hypot(existing.x - localPoint.x, existing.y - localPoint.y) > 0.6 {
                    interactionState.pointerInPanel = localPoint
                }
            } else {
                interactionState.pointerInPanel = localPoint
            }
            hoverExitWorkItem?.cancel()
            hoverExitWorkItem = nil
            coordinator.setDockPointerHovering(true)
        } else {
            if interactionState.pointerInPanel != nil {
                interactionState.pointerInPanel = nil
            }
            if !inMagnificationCatchZone && coordinator.isDockPointerHovering && !mouseButtonsPressed {
                if hoverExitWorkItem == nil {
                    let item = DispatchWorkItem { [weak self] in
                        self?.hoverExitWorkItem = nil
                        self?.coordinator.setDockPointerHovering(false)
                    }
                    hoverExitWorkItem = item
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.26, execute: item)
                }
            } else if inMagnificationCatchZone {
                hoverExitWorkItem?.cancel()
                hoverExitWorkItem = nil
            }
        }

        // 2. Dynamic Island Hover-to-Expand with Hysteresis
        if coordinator.settings.dockShape == .dynamicIsland {
            if coordinator.isDraggingDock || coordinator.settings.dynamicIslandPinned {
                islandExpandWorkItem?.cancel()
                islandCollapseWorkItem?.cancel()
                return
            }

            let expanded = coordinator.isDynamicIslandExpanded
            if !expanded {
                let triggerRect = bgFrame.insetBy(dx: -10, dy: -8)
                if triggerRect.contains(mouseAppKit) {
                    islandCollapseWorkItem?.cancel()
                    islandCollapseWorkItem = nil
                    if islandExpandWorkItem == nil {
                        let work = DispatchWorkItem { [weak self] in
                            self?.islandExpandWorkItem = nil
                            self?.coordinator.setDynamicIslandExpanded(true)
                        }
                        islandExpandWorkItem = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
                    }
                } else {
                    islandExpandWorkItem?.cancel()
                    islandExpandWorkItem = nil
                }
            } else {
                let targetSpringFrame = CGRect(
                    x: targetMidX - targetW / 2.0,
                    y: targetMidY - targetH / 2.0,
                    width: targetW,
                    height: targetH
                )
                let combinedFrame = (springDisplayLink != nil && !targetSpringFrame.isEmpty)
                    ? bgFrame.union(targetSpringFrame)
                    : bgFrame
                let keepOpenRect = combinedFrame.insetBy(dx: -16, dy: -16)
                if keepOpenRect.contains(mouseAppKit) || mouseButtonsPressed || isMenuTracking {
                    islandCollapseWorkItem?.cancel()
                    islandCollapseWorkItem = nil
                } else if islandCollapseWorkItem == nil {
                    let work = DispatchWorkItem { [weak self] in
                        guard let self else { return }
                        self.islandCollapseWorkItem = nil
                        // Backup for the menu notifications: while a menu is open the main run
                        // loop sits in event-tracking mode. didEndTracking re-checks afterwards.
                        if self.isMenuTracking || RunLoop.current.currentMode == .eventTracking {
                            return
                        }
                        self.coordinator.setDynamicIslandExpanded(false)
                    }
                    islandCollapseWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.36, execute: work)
                }
            }
        }
    }

    // MARK: - Scroll Wheel Navigation & Horizontal Wheel Support

    private func installScrollWheelMonitor() {
        scrollEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            return self.handleScrollWheelEvent(event)
        }
    }

    private func handleScrollWheelEvent(_ event: NSEvent) -> NSEvent? {
        guard event.window === self.panel else { return event }

        let optionHeld = event.modifierFlags.contains(.option)

        if coordinator.settings.scrollWheelBehavior.switchesApp(optionHeld: optionHeld) {
            // Momentum after a trackpad flick is not intent: ignoring it means one flick can
            // never chain through several apps.
            if !event.momentumPhase.isEmpty { return nil }

            let primaryDelta = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX)
                ? event.scrollingDeltaY
                : event.scrollingDeltaX
            let now = ProcessInfo.processInfo.systemUptime

            if event.hasPreciseScrollingDeltas {
                // Trackpad / Magic Mouse: require a deliberate ~30pt of travel per switch.
                if event.phase.contains(.began) { wheelSwitchAccumulator = 0 }
                wheelSwitchAccumulator += primaryDelta
                guard abs(wheelSwitchAccumulator) >= 30 else { return nil }
            } else {
                // Notched wheel: one notch = one switch.
                guard abs(primaryDelta) >= 0.8 else { return nil }
                wheelSwitchAccumulator = primaryDelta
            }
            guard now - lastWheelSwitchUptime >= 0.18 else { return nil }
            lastWheelSwitchUptime = now

            let step = wheelSwitchAccumulator < 0 ? 1 : -1
            wheelSwitchAccumulator = 0
            coordinator.stepActiveApp(delta: step)
            return nil
        }

        let isHorizontalScrollableShape = coordinator.settings.dockShape == .dynamicIsland
            && !coordinator.settings.isExpandedIslandVertical
            && (coordinator.isDynamicIslandExpanded || coordinator.settings.dynamicIslandPinned)

        if isHorizontalScrollableShape,
           abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX),
           abs(event.scrollingDeltaY) > 0.1,
           let contentView = panel.contentView,
           let scrollView = firstScrollView(in: contentView),
           let docView = scrollView.documentView {
            let clipView = scrollView.contentView
            let stepMultiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1.0 : 12.0
            let deltaX = -event.scrollingDeltaY * stepMultiplier
            let maxX = max(0, docView.bounds.width - clipView.bounds.width)
            if maxX > 0 {
                let targetX = min(max(0, clipView.bounds.origin.x + deltaX), maxX)
                clipView.scroll(to: NSPoint(x: targetX, y: clipView.bounds.origin.y))
                scrollView.reflectScrolledClipView(clipView)
                return nil
            }
        }

        return event
    }

    private func firstScrollView(in view: NSView) -> NSScrollView? {
        if let sv = view as? NSScrollView {
            return sv
        }
        for sub in view.subviews {
            if let found = firstScrollView(in: sub) {
                return found
            }
        }
        return nil
    }

    // MARK: - Auxiliary Native Windows (Settings & Add App)

    public func showSettingsWindow() {
        if let existing = settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let view = SettingsView(coordinator: coordinator)
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = L10n.t("iRing 偏好设置", "iRing Settings")
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.setContentSize(NSSize(width: 660, height: 560))
        win.minSize = NSSize(width: 580, height: 480)
        win.center()
        win.isReleasedWhenClosed = false
        self.settingsWindow = win

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    public func showAddAppWindow() {
        if let existing = addAppWindow {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let view = AddAppSheetView(coordinator: coordinator) { [weak self] in
            self?.addAppWindow?.close()
        }
        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.title = L10n.t("添加应用到 iRing", "Add Apps to iRing")
        win.styleMask = [.titled, .closable, .resizable]
        win.setContentSize(NSSize(width: 440, height: 520))
        win.center()
        win.isReleasedWhenClosed = false
        self.addAppWindow = win

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    public func showOnboardingWindowIfNeeded() {
        guard !coordinator.settings.hasCompletedOnboarding else { return }
        if coordinator.isAccessibilityTrusted && !coordinator.apps.isEmpty {
            coordinator.updateSettings { $0.hasCompletedOnboarding = true }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self,
                  !self.coordinator.settings.hasCompletedOnboarding,
                  (!self.coordinator.isAccessibilityTrusted || self.coordinator.apps.isEmpty)
            else { return }
            if let existing = self.onboardingWindow {
                NSApp.activate(ignoringOtherApps: true)
                existing.makeKeyAndOrderFront(nil)
                return
            }

            let view = OnboardingPermissionView(coordinator: self.coordinator) { [weak self] in
                self?.onboardingWindow?.close()
            }
            let hosting = NSHostingController(rootView: view)
            let win = NSWindow(contentViewController: hosting)
            win.title = L10n.t("欢迎使用 iRing", "Welcome to iRing")
            win.styleMask = [.titled, .closable]
            win.setContentSize(NSSize(width: 480, height: 420))
            win.center()
            win.isReleasedWhenClosed = false
            self.onboardingWindow = win

            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
        }
    }
}
