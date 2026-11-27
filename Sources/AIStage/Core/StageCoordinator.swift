import AppKit
import ApplicationServices
import Combine
import Foundation
import ServiceManagement

@MainActor
public final class StageCoordinator: ObservableObject {

    // MARK: - Published State

    @Published public var apps: [StageAppItem] = []
    @Published public var runtimeInfo: [String: AppRuntimeInfo] = [:]
    @Published public var appUsageCounts: [String: Int] = [:]
    @Published public var activeBundleID: String?
    @Published public var splitSecondaryBundleID: String?
    @Published public var launchingBundleIDs: Set<String> = []
    @Published public var isStageHidden: Bool = false
    @Published public var isAccessibilityTrusted: Bool = false
    @Published public var layoutMode: StageLayoutMode = .monocleStack
    @Published public var pinnedScreenID: String?
    @Published public private(set) var customDockOriginQuartz: CGPoint?
    @Published public var settings: StageSettings = StageSettings()
    @Published public var isDynamicIslandExpanded: Bool = false
    @Published public var isAutoHideRevealed: Bool = false
    @Published public var activeDockPopDirection: DisplayGeometry.DockPopDirection = .up
    @Published public var isDockPointerHovering: Bool = false
    @Published public var isDraggingDock: Bool = false
    @Published public var dragPreviewEdge: DockEdgePosition? = nil
    @Published public var autoHideEdge: DockEdgePosition = .bottom
    @Published public var dockVisualLength: CGSize = CGSize(width: 64, height: 420)
    @Published public var lastSwitchedBundleID: String?
    @Published public var switchBounceTick: Int = 0
    @Published public var screenHasNotch: Bool = false
    @Published public var screenNotchWidth: CGFloat = 0
    @Published public var screenNotchHeight: CGFloat = 32

    // MARK: - Computed Display Order (Supports Running-First Sorting)

    public var runningDisplayedApps: [StageAppItem] {
        guard settings.sortRunningAppsFirst else { return apps }
        return apps.filter { isAppConsideredRunning($0.bundleIdentifier) }
    }

    public var inactiveDisplayedApps: [StageAppItem] {
        guard settings.sortRunningAppsFirst else { return [] }
        return apps.filter { !isAppConsideredRunning($0.bundleIdentifier) }
    }

    public var displayedApps: [StageAppItem] {
        guard settings.sortRunningAppsFirst else { return apps }
        return runningDisplayedApps + inactiveDisplayedApps
    }

    public var collapsedIconApps: (active: StageAppItem?, runningOthers: [StageAppItem]) {
        let runningIDs = Set(apps.map(\.bundleIdentifier).filter { runtimeInfo[$0]?.isRunning == true })
        let res = StageSettings.orderedCollapsedIslandApps(
            apps: apps,
            activeBundleID: activeBundleID,
            runningBundleIDs: runningIDs,
            sortRunningFirst: settings.sortRunningAppsFirst
        )
        return (res.active, res.runningOthers)
    }

    public var numberShortcutApps: [StageAppItem] {
        let runningIDs = Set(apps.map(\.bundleIdentifier).filter { runtimeInfo[$0]?.isRunning == true })
        return StageSettings.orderedCollapsedIslandApps(
            apps: apps,
            activeBundleID: activeBundleID,
            runningBundleIDs: runningIDs,
            sortRunningFirst: settings.sortRunningAppsFirst
        ).allSlots
    }

    public var radialDisplayedApps: [StageAppItem] {
        let runningIDs = Set(apps.map(\.bundleIdentifier).filter { isAppConsideredRunning($0) })
        return StageSettings.orderedRadialApps(
            apps: apps,
            runningBundleIDs: runningIDs,
            usageCounts: appUsageCounts,
            lastUsedTimestamps: appLastUsedTimestamps,
            orderMode: settings.radialAppOrderMode,
            sortRunningFirst: settings.sortRunningAppsFirst,
            showInactiveApps: settings.showInactiveAppsInRing
        )
    }

    private var appLastUsedTimestamps: [String: Double] = [:]
    private var lastUsageRecordedBundleID: String?
    private var lastUsageRecordedUptime: TimeInterval = 0

    private func isAppConsideredRunning(_ bundleID: String) -> Bool {
        runtimeInfo[bundleID]?.isRunning == true || launchingBundleIDs.contains(bundleID)
    }

    private func recordAppUsage(bundleID: String) {
        guard apps.contains(where: { $0.bundleIdentifier == bundleID }) else { return }
        let nowUptime = ProcessInfo.processInfo.systemUptime
        if lastUsageRecordedBundleID == bundleID && nowUptime - lastUsageRecordedUptime < 2.0 {
            return
        }
        lastUsageRecordedBundleID = bundleID
        lastUsageRecordedUptime = nowUptime
        appUsageCounts[bundleID, default: 0] += 1
        appLastUsedTimestamps[bundleID] = Date().timeIntervalSince1970
        scheduleSave()
    }

    // MARK: - Dock Overlay Bridge Callbacks

    public enum DockZOrderMode {
        case floatingFront
        case normalBelow(windowNumber: Int?)
        case hidden
    }

    public var onDockFrameShouldUpdate: ((CGRect, Bool) -> Void)?
    public var onDockVisibilityShouldChange: ((Bool) -> Void)?
    public var onDockZOrderShouldUpdate: ((DockZOrderMode) -> Void)?
    public var onDockCornerRadiusShouldUpdate: ((CGFloat) -> Void)?
    public var onDockWindowLevelShouldUpdate: ((Bool) -> Void)?
    public var onMenuBarVisibilityShouldChange: ((Bool) -> Void)?
    public var onLanguageDidChange: (() -> Void)?
    public var onRadialKeyboardTriggerPressed: (() -> Void)?
    public var onRadialKeyboardTriggerReleased: (() -> Void)?
    public var onSplitRingHotkeyPressed: (() -> Void)?
    public var onSplitRingHotkeyReleased: (() -> Void)?
    public var onOpenSettingsRequested: (() -> Void)?
    public var onOpenAddAppRequested: (() -> Void)?
    public var onAccessibilityTrustChanged: ((Bool) -> Void)?
    public var onPlayWindowPopTransition: ((WindowPopAnimationStyle, StageAppItem, CGImage?, CGRect, CGRect, Double, @escaping () -> Void) -> Void)?

    // MARK: - Services

    public let discovery = AppDiscoveryService()
    public let snapshotCache = WindowSnapshotCache()
    private let frameAnimator = WindowFrameAnimator()
    private let persistence: PersistenceStore
    private let hotkeyManager = GlobalHotkeyManager()

    private var dragStartDockOriginQuartz: CGPoint = .zero
    private var dragStartDockSize: CGSize = .zero
    private var resizeInitialWidth: Double = 66
    private var resizeInitialHeight: Double = 460
    private var resizeInitialOriginQuartz: CGPoint = .zero
    private var saveWorkItem: DispatchWorkItem?
    private var pendingHideWork: DispatchWorkItem?
    private var switchInFlightUntil: TimeInterval = 0
    private var windowAlignGeneration: UInt64 = 0
    private var hotkeysSuspended: Bool = false
    private var statusTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObserver: NSObjectProtocol?
    private var cachedLSBadgeSnapshot = AXWindowController.DockBadgeSnapshot()
    private var isFetchingLSBadges = false

    private static let excludedBundleIDs: Set<String> = []

    // MARK: - Init

    public init(persistence: PersistenceStore = PersistenceStore()) {
        self.persistence = persistence
        self.isAccessibilityTrusted = AXWindowController.isAccessibilityTrusted(promptIfNeeded: false)
        loadInitialState()
    }

    deinit {
        statusTimer?.invalidate()
        for token in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        if let dist = distributedObserver {
            DistributedNotificationCenter.default().removeObserver(dist)
        }
    }

    // MARK: - Lifecycle

    public func start() {
        isAccessibilityTrusted = AXWindowController.isAccessibilityTrusted(promptIfNeeded: false)
        refreshRuntimeInfo()
        installWorkspaceObservers()
        installAccessibilityObserver()
        applyHotkeys()
        startTimers()

        // Ensure pinnedScreenID points to a valid connected display
        _ = resolvedScreen()

        if activeBundleID == nil || !apps.contains(where: { $0.bundleIdentifier == activeBundleID }) {
            activeBundleID = displayedApps.first(where: { runtimeInfo[$0.bundleIdentifier]?.isRunning == true })?.bundleIdentifier
                ?? displayedApps.first?.bundleIdentifier
        }

        isStageHidden = false
        updateGlassCornerRadius()
        if Bundle.main.bundleURL.pathExtension == "app" {
            let registered = (SMAppService.mainApp.status == .enabled)
            if settings.launchAtLogin != registered {
                settings.launchAtLogin = registered
            }
        }
        onMenuBarVisibilityShouldChange?(!settings.hideMenuBarIcon)
        onDockWindowLevelShouldUpdate?(settings.dockShape == .dynamicIsland && settings.islandPosition == .top)
        syncDockFrame(animated: false)
        onDockVisibilityShouldChange?(settings.dockShape != .radialOnly)

        if let front = NSWorkspace.shared.frontmostApplication {
            updateZOrderForFrontmostApp(front)
        } else {
            onDockZOrderShouldUpdate?(.floatingFront)
        }
    }

    // MARK: - Locked Stage & Dock Geometry (Zero Shake)

    public func resolvedScreen() -> DisplayGeometry.ScreenInfo? {
        let screens = DisplayGeometry.allScreens()
        guard !screens.isEmpty else { return nil }
        if let pid = pinnedScreenID, let match = screens.first(where: { $0.id == pid }) {
            return match
        }
        // Default to the screen under the mouse cursor, or primary
        let mouseAppKit = NSEvent.mouseLocation
        let primaryH = DisplayGeometry.primaryScreenHeight()
        let mouseQuartz = CGPoint(x: mouseAppKit.x, y: primaryH - mouseAppKit.y)
        let picked = screens.first(where: { $0.frameQuartz.contains(mouseQuartz) }) ?? screens.first
        pinnedScreenID = picked?.id
        return picked
    }

    public func currentDockAndStageFramesQuartz() -> (dock: CGRect, stage: CGRect) {
        guard let scr = resolvedScreen() else {
            let dock = CGRect(x: 8, y: 200, width: settings.dockWidth, height: estimatedDockLength())
            let stage = CGRect(x: 8 + settings.dockWidth + settings.dockGap, y: 40, width: 1300, height: 860)
            return (dock, stage)
        }
        if settings.dockShape == .dynamicIsland {
            let res = DisplayGeometry.dynamicIslandFramesQuartz(
                on: scr,
                settings: settings,
                expanded: isDynamicIslandExpanded || settings.dynamicIslandPinned,
                desiredExpandedWidth: estimatedDockLength()
            )
            return (dock: res.island, stage: res.stage)
        }
        return DisplayGeometry.dockAndStageFramesQuartz(
            on: scr,
            customDockOriginQuartz: customDockOriginQuartz,
            settings: settings,
            desiredDockHeight: estimatedDockLength()
        )
    }

    public func currentLockedStageFrameQuartz() -> CGRect {
        currentDockAndStageFramesQuartz().stage
    }

    public var magnificationHeadroomPoints: CGFloat { 0 }

    public func syncDockFrame(animated: Bool) {
        let scr = resolvedScreen()
        if let scr {
            let hasNotch = scr.notchWidth > 0
            let notchH: CGFloat = hasNotch ? max(30, scr.safeAreaTop) : 26
            if screenHasNotch != hasNotch {
                screenHasNotch = hasNotch
            }
            if screenNotchWidth != scr.notchWidth {
                screenNotchWidth = scr.notchWidth
            }
            if screenNotchHeight != notchH {
                screenNotchHeight = notchH
            }
        }

        let pair = currentDockAndStageFramesQuartz()
        if let scr {
            let popDir = DisplayGeometry.popDirection(
                for: pair.dock,
                on: scr,
                shape: settings.dockShape,
                islandPosition: settings.islandPosition
            )
            if activeDockPopDirection != popDir {
                activeDockPopDirection = popDir
            }
        }
        if dockVisualLength != pair.dock.size {
            dockVisualLength = pair.dock.size
        }

        let primaryH = DisplayGeometry.primaryScreenHeight()
        let dockAppKit = DisplayGeometry.quartzToAppKit(pair.dock, primaryHeight: primaryH)
        onDockFrameShouldUpdate?(dockAppKit, animated)
    }

    public func estimatedDockLength() -> CGFloat {
        let separatorExtra: CGFloat = (settings.sortRunningAppsFirst && !runningDisplayedApps.isEmpty && !inactiveDisplayedApps.isEmpty) ? 7 : 0
        let iconSz = CGFloat(settings.iconSize)
        let spacing = max(2, round(iconSz * 0.05))
        let pad = max(4, round(iconSz * 0.13))
        let itemCount = CGFloat(max(1, apps.count))
        let pillSpan = iconSz + 4
        let pitch = pillSpan + spacing
        let flare = min(12, max(9, round(iconSz * 0.25)))
        let flareExtra: CGFloat = flare * 2
        let contentLen = flareExtra + pad * 2 + (itemCount + 2) * pitch - spacing + separatorExtra

        switch settings.dockShape {
        case .dynamicIsland:
            if settings.isExpandedIslandVertical {
                return min(960, max(140, contentLen))
            } else {
                return min(1200, max(140, contentLen))
            }
        case .radialOnly:
            return CGFloat(settings.radialRingDiameter)
        }
    }

    public func cycleDockShape() {
        setDockShape(settings.dockShape.nextShape)
    }

    public func setDockShape(_ mode: DockShapeMode) {
        guard settings.dockShape != mode else { return }
        settings.dockShape = mode
        customDockOriginQuartz = nil
        isDockPointerHovering = false
        if mode != .dynamicIsland {
            isDynamicIslandExpanded = false
        }
        onDockWindowLevelShouldUpdate?(mode == .dynamicIsland && settings.islandPosition == .top)
        updateGlassCornerRadius()
        syncDockFrame(animated: true)
        onDockVisibilityShouldChange?(mode != .radialOnly && !isStageHidden)
        realignCurrentLayout()
        if mode == .dynamicIsland {
            onDockZOrderShouldUpdate?(.floatingFront)
        }
        scheduleSave()
    }

    public func setDynamicIslandExpanded(_ expanded: Bool) {
        guard settings.dockShape == .dynamicIsland else { return }
        let target = expanded || settings.dynamicIslandPinned
        guard isDynamicIslandExpanded != target else { return }
        isDynamicIslandExpanded = target
        updateGlassCornerRadius()
        syncDockFrame(animated: true)
        if target && settings.showNotificationBadges {
            refreshRuntimeInfo()
        }
    }

    public func toggleDynamicIslandPinned() {
        settings.dynamicIslandPinned.toggle()
        isDynamicIslandExpanded = settings.dynamicIslandPinned
        updateGlassCornerRadius()
        syncDockFrame(animated: true)
        scheduleSave()
    }

    public func setDockPointerHovering(_ hovering: Bool) {
        guard isDockPointerHovering != hovering else { return }
        isDockPointerHovering = hovering
    }

    private func updateGlassCornerRadius() {
        let radius: CGFloat
        switch settings.dockShape {
        case .dynamicIsland:
            radius = (isDynamicIslandExpanded || settings.dynamicIslandPinned) ? 24 : 15
        case .radialOnly:
            radius = CGFloat(settings.radialRingDiameter) / 2.0
        }
        onDockCornerRadiusShouldUpdate?(radius)
    }

    // MARK: - Core Switching: Pre-Align Behind -> Atomic Raise (Zero Shake)

    public func handleIconClick(
        bundleID: String,
        isCommandPressed: Bool,
        isOptionPressed: Bool = false,
        sourceIconRectAppKit: CGRect? = nil
    ) {
        if isCommandPressed,
           let primary = activeBundleID,
           primary != bundleID {
            enterSplitMode(leftBundleID: primary, rightBundleID: bundleID)
        } else {
            switchToApp(
                bundleID: bundleID,
                forceAlignToDockScreen: isOptionPressed,
                sourceIconRectAppKit: sourceIconRectAppKit
            )
        }
    }

    public func switchToSlot(_ index: Int) {
        if settings.followActiveScreen {
            syncPinnedScreenToMouseIfNeeded()
        }
        let ordered = numberShortcutApps
        guard index >= 0, index < ordered.count else { return }
        switchToApp(bundleID: ordered[index].bundleIdentifier)
    }

    public func stepActiveApp(delta: Int) {
        if settings.followActiveScreen {
            syncPinnedScreenToMouseIfNeeded()
        }
        let ordered = displayedApps
        guard !ordered.isEmpty, delta != 0 else { return }
        if let activeBundleID,
           let currentIdx = ordered.firstIndex(where: { $0.bundleIdentifier == activeBundleID }) {
            let nextIdx = ((currentIdx + delta) % ordered.count + ordered.count) % ordered.count
            switchToApp(bundleID: ordered[nextIdx].bundleIdentifier)
        } else {
            let idx = delta > 0 ? 0 : (ordered.count - 1)
            switchToApp(bundleID: ordered[idx].bundleIdentifier)
        }
    }

    public func switchToApp(
        bundleID: String,
        targetScreenID: String? = nil,
        overrideFrameQuartz: CGRect? = nil,
        forceAlignToDockScreen: Bool = false,
        sourceIconRectAppKit: CGRect? = nil,
        isSplitLayout: Bool = false
    ) {
        if bundleID == Bundle.main.bundleIdentifier || bundleID == "com.iring.mac" || bundleID == "com.aistage.mac" {
            onOpenSettingsRequested?()
            return
        }
        guard let item = apps.first(where: { $0.bundleIdentifier == bundleID }) else { return }
        recordAppUsage(bundleID: bundleID)

        if !isAccessibilityTrusted {
            isAccessibilityTrusted = AXWindowController.isAccessibilityTrusted(promptIfNeeded: false)
        }

        let previousActiveBundleID = activeBundleID
        captureSnapshotOfOutgoingApp(beforeSwitchingTo: bundleID)
        frameAnimator.cancelAll()

        if let targetScreenID, targetScreenID != pinnedScreenID {
            pinnedScreenID = targetScreenID
            customDockOriginQuartz = nil
        }

        pendingHideWork?.cancel()
        pendingHideWork = nil
        windowAlignGeneration &+= 1
        let gen = windowAlignGeneration
        switchInFlightUntil = ProcessInfo.processInfo.systemUptime + 0.35

        layoutMode = .monocleStack
        splitSecondaryBundleID = nil
        activeBundleID = bundleID
        lastSwitchedBundleID = bundleID
        switchBounceTick &+= 1
        isStageHidden = false

        syncDockFrame(animated: false)
        onDockVisibilityShouldChange?(settings.dockShape != .radialOnly)
        if settings.dockShape != .radialOnly {
            onDockZOrderShouldUpdate?(.floatingFront)
        }

        let screens = DisplayGeometry.allScreens()
        let dockScreen = resolvedScreen()
        let dockScreenID = dockScreen?.id
        let primaryHeight = DisplayGeometry.primaryScreenHeight()
        let shouldHideOthers = settings.hideInactiveStagedApps && !isSplitLayout
        let isSameAppResizing = (previousActiveBundleID == bundleID && overrideFrameQuartz != nil)
        let popDuration = settings.windowPopAnimationStyle.effectiveDuration(speed: settings.animationSpeed)
        let canAnimatePop = false && popDuration > 0.02
            && sourceIconRectAppKit != nil
            && !isSameAppResizing
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            && onPlayWindowPopTransition != nil

        var resolvedMoveFrame: CGRect? = nil

        if let running = AXWindowController.runningApp(bundleIdentifier: bundleID) {
            if running.isHidden && overrideFrameQuartz == nil && !forceAlignToDockScreen
                && (!settings.autoFitWindowOnSwitch || !settings.pullCrossScreenAppsToIsland) {
                running.unhide()
            }
            let win = isAccessibilityTrusted ? AXWindowController.primaryWindow(for: running.processIdentifier) : nil
            let existingFrame = liveWindowFrameQuartz(for: running.processIdentifier, preferredWindow: win)
            let winScreenID = existingFrame.flatMap { DisplayGeometry.screen(containingQuartzRect: $0, screens: screens)?.id }

            let switchAction = DisplayGeometry.resolveWindowSwitchAction(
                autoFitWindowOnSwitch: settings.autoFitWindowOnSwitch,
                pullCrossScreenAppsToIsland: settings.pullCrossScreenAppsToIsland,
                existingFrameQuartz: existingFrame,
                windowScreenID: winScreenID,
                dockScreen: dockScreen,
                hasExplicitOverrideFrame: overrideFrameQuartz != nil,
                forceAlignToDockScreen: forceAlignToDockScreen
            )

            switch switchAction {
            case .preserveExisting:
                if let win {
                    AXWindowController.unminimizeIfNeeded(win)
                }
                if canAnimatePop, let sourceRect = sourceIconRectAppKit, let existingFrame {
                    let snapshot = snapshotCache.cachedSnapshot(for: bundleID)
                    let targetAppKit = DisplayGeometry.quartzToAppKit(existingFrame, primaryHeight: primaryHeight)
                    onPlayWindowPopTransition?(
                        settings.windowPopAnimationStyle,
                        item,
                        snapshot?.image,
                        sourceRect,
                        targetAppKit,
                        popDuration
                    ) { [weak self] in
                        guard let self,
                              self.windowAlignGeneration == gen,
                              self.activeBundleID == bundleID
                        else { return }
                        AXWindowController.activateApplication(running, window: win, appURL: item.appURL)
                        if shouldHideOthers {
                            self.scheduleHideOtherStagedApps(except: item.bundleIdentifier, onScreenID: winScreenID)
                        }
                        self.scheduleSnapshotRefresh(for: item.bundleIdentifier, generation: gen)
                    }
                } else {
                    AXWindowController.activateApplication(running, window: win, appURL: item.appURL)
                    if existingFrame != nil {
                        if shouldHideOthers {
                            scheduleHideOtherStagedApps(except: item.bundleIdentifier, onScreenID: winScreenID)
                        }
                    } else {
                        scheduleDeferredFocusFollowUp(
                            bundleID: item.bundleIdentifier,
                            pid: running.processIdentifier,
                            shouldHideOthers: shouldHideOthers,
                            generation: gen
                        )
                    }
                    scheduleSnapshotRefresh(for: item.bundleIdentifier, generation: gen)
                }
                if let existingFrame {
                    warpCursorToCenterIfNeeded(of: existingFrame)
                }
                scheduleSave()
                return

            case .moveToScreenPreservingSize(let movedFrame):
                resolvedMoveFrame = movedFrame

            case .fitToStage:
                resolvedMoveFrame = nil
            }
        } else if !settings.autoFitWindowOnSwitch && overrideFrameQuartz == nil && !forceAlignToDockScreen {
            // Launch cleanly without forcing window resize
            launchingBundleIDs.insert(item.bundleIdentifier)
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: item.appURL, configuration: config) { [weak self] app, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        NSLog("[AIStage] Failed to launch \(item.displayName): \(error.localizedDescription)")
                    }
                    self.launchingBundleIDs.remove(item.bundleIdentifier)
                    self.refreshRuntimeInfo()
                    if let launchedPID = app?.processIdentifier
                        ?? AXWindowController.runningApp(bundleIdentifier: item.bundleIdentifier)?.processIdentifier {
                        self.scheduleDeferredFocusFollowUp(
                            bundleID: item.bundleIdentifier,
                            pid: launchedPID,
                            shouldHideOthers: shouldHideOthers,
                            generation: gen
                        )
                    }
                }
            }
            scheduleSave()
            return
        }

        let stage = overrideFrameQuartz ?? resolvedMoveFrame ?? currentLockedStageFrameQuartz()
        let targetAlignScreenID = DisplayGeometry.screen(containingQuartzRect: stage, screens: screens)?.id ?? dockScreenID
        let shouldSmoothResize = (overrideFrameQuartz != nil || resolvedMoveFrame != nil)
            && settings.smoothWindowTransitions
            && !settings.ringAnimationSpeed.isInstant
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if canAnimatePop, let sourceRect = sourceIconRectAppKit {
            if let running = AXWindowController.runningApp(bundleIdentifier: bundleID),
               isAccessibilityTrusted,
               let win = AXWindowController.primaryWindow(for: running.processIdentifier),
               !AXWindowController.isFullScreen(win) {
                AXWindowController.unminimizeIfNeeded(win)
                AXWindowController.setFrame(stage, of: win, pid: running.processIdentifier)
            }
            let snapshot = snapshotCache.cachedSnapshot(for: bundleID)
            let targetAppKit = DisplayGeometry.quartzToAppKit(stage, primaryHeight: primaryHeight)
            onPlayWindowPopTransition?(
                settings.windowPopAnimationStyle,
                item,
                snapshot?.image,
                sourceRect,
                targetAppKit,
                popDuration
            ) { [weak self] in
                guard let self,
                      self.windowAlignGeneration == gen,
                      self.activeBundleID == bundleID
                else { return }
                self.preAlignAndActivate(
                    item: item,
                    to: stage,
                    hideOthersAfter: shouldHideOthers,
                    onScreenID: targetAlignScreenID,
                    generation: gen,
                    smoothResize: false
                )
                self.scheduleSnapshotRefresh(for: item.bundleIdentifier, generation: gen)
            }
            warpCursorToCenterIfNeeded(of: stage)
            scheduleSave()
            return
        }

        preAlignAndActivate(
            item: item,
            to: stage,
            hideOthersAfter: shouldHideOthers,
            onScreenID: targetAlignScreenID,
            generation: gen,
            smoothResize: shouldSmoothResize
        )
        scheduleSnapshotRefresh(for: item.bundleIdentifier, generation: gen)
        warpCursorToCenterIfNeeded(of: stage)
        scheduleSave()
    }

    /// Applies any Loop-style radial layout directly to the currently active foreground window
    /// (works for any macOS app, whether or not it is staged in AIStage) without hiding other split apps.
    public func applySplitLayoutToFrontmostWindow(layout: RadialLayoutTarget, screenID: String?, overrideFrameQuartz: CGRect? = nil) {
        if !isAccessibilityTrusted {
            isAccessibilityTrusted = AXWindowController.isAccessibilityTrusted(promptIfNeeded: false)
        }
        guard isAccessibilityTrusted else {
            NSLog("[AIStage] Split skipped: Accessibility permission not trusted")
            return
        }
        guard let targetQuartz = overrideFrameQuartz ?? radialTargetFrameQuartz(screenID: screenID, layout: layout),
              let front = NSWorkspace.shared.frontmostApplication,
              front.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return }

        if let bid = front.bundleIdentifier, apps.contains(where: { $0.bundleIdentifier == bid }) {
            activeBundleID = bid
            lastSwitchedBundleID = bid
        }

        frameAnimator.cancelAll()
        pendingHideWork?.cancel()
        pendingHideWork = nil
        windowAlignGeneration &+= 1
        let gen = windowAlignGeneration

        let pid = front.processIdentifier
        guard let win = AXWindowController.primaryWindow(for: pid),
              !AXWindowController.isFullScreen(win)
        else { return }

        AXWindowController.unminimizeIfNeeded(win)
        let smooth = settings.smoothWindowTransitions
            && !settings.ringAnimationSpeed.isInstant
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if smooth {
            let duration = max(0.14, settings.ringAnimationSpeed.previewFrameDuration)
            frameAnimator.animate(
                window: win,
                pid: pid,
                runningApp: front,
                to: targetQuartz,
                duration: duration
            ) { [weak self] _ in
                AXWindowController.raise(win)
                self?.scheduleFrameVerification(pid: pid, targetFrame: targetQuartz, generation: gen)
            }
        } else {
            AXWindowController.setFrame(targetQuartz, of: win, pid: pid)
            AXWindowController.raise(win)
            scheduleFrameVerification(pid: pid, targetFrame: targetQuartz, generation: gen)
        }
        warpCursorToCenterIfNeeded(of: targetQuartz)
    }

    /// Moves and resizes a specific running window (found under cursor) without hiding other windows.
    public func applyFrameToWindow(
        pid: pid_t,
        frameQuartz: CGRect,
        screenID: String?,
        preferredWindowFrameQuartz: CGRect? = nil
    ) {
        if !isAccessibilityTrusted {
            isAccessibilityTrusted = AXWindowController.isAccessibilityTrusted(promptIfNeeded: false)
        }
        guard isAccessibilityTrusted else {
            NSLog("[AIStage] Split skipped: Accessibility permission not trusted")
            return
        }
        guard let running = NSRunningApplication(processIdentifier: pid),
              running.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return }

        if let bid = running.bundleIdentifier, apps.contains(where: { $0.bundleIdentifier == bid }) {
            activeBundleID = bid
            lastSwitchedBundleID = bid
        }

        frameAnimator.cancelAll()
        pendingHideWork?.cancel()
        pendingHideWork = nil
        windowAlignGeneration &+= 1
        let gen = windowAlignGeneration

        guard let win = AXWindowController.window(for: pid, matchingFrameQuartz: preferredWindowFrameQuartz),
              !AXWindowController.isFullScreen(win)
        else { return }

        AXWindowController.unminimizeIfNeeded(win)
        AXWindowController.activateApplication(running, window: win, appURL: running.bundleURL)

        let smooth = settings.smoothWindowTransitions
            && !settings.ringAnimationSpeed.isInstant
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if smooth {
            let duration = max(0.14, settings.ringAnimationSpeed.previewFrameDuration)
            frameAnimator.animate(
                window: win,
                pid: pid,
                runningApp: running,
                to: frameQuartz,
                duration: duration
            ) { [weak self] _ in
                AXWindowController.raise(win)
                self?.scheduleFrameVerification(
                    pid: pid,
                    window: win,
                    targetFrame: frameQuartz,
                    generation: gen,
                    delays: [0.08, 0.24, 0.45]
                )
            }
        } else {
            AXWindowController.setFrame(frameQuartz, of: win, pid: pid)
            AXWindowController.raise(win)
            scheduleFrameVerification(
                pid: pid,
                window: win,
                targetFrame: frameQuartz,
                generation: gen,
                delays: [0.08, 0.24, 0.45]
            )
        }
        warpCursorToCenterIfNeeded(of: frameQuartz)
    }

    /// Square all running staged apps to the exact same locked stage rectangle in one click.
    public func alignAllRunningAppsToLockedStage() {
        guard isAccessibilityTrusted else {
            requestAccessibilityPermission()
            return
        }

        pendingHideWork?.cancel()
        pendingHideWork = nil
        switchInFlightUntil = ProcessInfo.processInfo.systemUptime + 0.35

        layoutMode = .monocleStack
        splitSecondaryBundleID = nil

        let stage = currentLockedStageFrameQuartz()
        for item in apps where item.bundleIdentifier != activeBundleID {
            if let running = AXWindowController.runningApp(bundleIdentifier: item.bundleIdentifier),
               !running.isHidden,
               let win = AXWindowController.primaryWindow(for: running.processIdentifier),
               !AXWindowController.isFullScreen(win) {
                AXWindowController.unminimizeIfNeeded(win)
                AXWindowController.setFrame(stage, of: win, pid: running.processIdentifier)
            }
        }

        if let activeID = activeBundleID,
           let activeItem = apps.first(where: { $0.bundleIdentifier == activeID }) {
            preAlignAndActivate(
                item: activeItem,
                to: stage,
                hideOthersAfter: settings.hideInactiveStagedApps,
                onScreenID: resolvedScreen()?.id
            )
        }
    }

    // MARK: - 50/50 Split Comparison Mode

    public func enterSplitMode(leftBundleID: String, rightBundleID: String) {
        guard let leftItem = apps.first(where: { $0.bundleIdentifier == leftBundleID }),
              let rightItem = apps.first(where: { $0.bundleIdentifier == rightBundleID }),
              leftBundleID != rightBundleID
        else { return }

        windowAlignGeneration &+= 1
        let gen = windowAlignGeneration

        layoutMode = .split2
        activeBundleID = leftBundleID
        splitSecondaryBundleID = rightBundleID
        isStageHidden = false

        syncDockFrame(animated: false)
        onDockVisibilityShouldChange?(settings.dockShape != .radialOnly)
        if settings.dockShape != .radialOnly {
            onDockZOrderShouldUpdate?(.floatingFront)
        }

        let stage = currentLockedStageFrameQuartz()
        let (leftFrame, rightFrame) = DisplayGeometry.splitFrames(forStage: stage, splitGap: settings.splitGap)
        let targetScreenID = resolvedScreen()?.id

        preAlignAndActivate(item: rightItem, to: rightFrame, hideOthersAfter: false, onScreenID: targetScreenID, generation: gen)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            guard let self, self.windowAlignGeneration == gen, self.layoutMode == .split2 else { return }
            self.preAlignAndActivate(item: leftItem, to: leftFrame, hideOthersAfter: false, onScreenID: targetScreenID, generation: gen)
        }
        scheduleSave()
    }

    public func exitSplitMode() {
        guard let primary = activeBundleID else { return }
        switchToApp(bundleID: primary)
    }

    // MARK: - Global Show / Hide Stage

    public func toggleStageVisibility() {
        let frontBID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let isManagedFrontmost = frontBID != nil && (
            frontBID == Bundle.main.bundleIdentifier ||
            apps.contains(where: { $0.bundleIdentifier == frontBID })
        )

        if !isStageHidden && isManagedFrontmost {
            hideStageGroup()
        } else {
            summonStageGroup()
        }
    }

    public func hideStageGroup() {
        isStageHidden = true
        onDockVisibilityShouldChange?(false)

        let toHide = Set([activeBundleID, splitSecondaryBundleID].compactMap { $0 })

        for item in apps where toHide.contains(item.bundleIdentifier) {
            if let running = AXWindowController.runningApp(bundleIdentifier: item.bundleIdentifier),
               !running.isHidden {
                running.hide()
            }
        }
    }

    public func summonStageGroup() {
        if settings.followActiveScreen {
            syncPinnedScreenToMouseIfNeeded()
        }
        isStageHidden = false
        syncDockFrame(animated: false)
        onDockVisibilityShouldChange?(settings.dockShape != .radialOnly)
        if settings.dockShape != .radialOnly {
            onDockZOrderShouldUpdate?(.floatingFront)
        }

        if layoutMode == .split2, let left = activeBundleID, let right = splitSecondaryBundleID {
            enterSplitMode(leftBundleID: left, rightBundleID: right)
            return
        }

        let targetID = activeBundleID
            ?? displayedApps.first(where: { runtimeInfo[$0.bundleIdentifier]?.isRunning == true })?.bundleIdentifier
            ?? displayedApps.first?.bundleIdentifier

        if let id = targetID, runtimeInfo[id]?.isRunning == true {
            switchToApp(bundleID: id)
        }
    }

    // MARK: - Multi-Monitor Transfer & Auto-Follow

    public func syncPinnedScreenToMouseIfNeeded(force: Bool = false) {
        guard force || settings.followActiveScreen else { return }
        let screens = DisplayGeometry.allScreens()
        let primaryH = DisplayGeometry.primaryScreenHeight()
        let mouseAppKit = NSEvent.mouseLocation
        let mouseQuartz = CGPoint(x: mouseAppKit.x, y: primaryH - mouseAppKit.y)
        guard let mouseScreen = DisplayGeometry.screen(containingQuartzPoint: mouseQuartz, screens: screens),
              mouseScreen.id != pinnedScreenID
        else { return }
        followToScreen(mouseScreen, animated: true)
    }

    public func followToScreen(_ screen: DisplayGeometry.ScreenInfo, animated: Bool = true) {
        guard pinnedScreenID != screen.id else { return }
        pinnedScreenID = screen.id
        customDockOriginQuartz = nil
        if settings.dockShape == .dynamicIsland {
            isDynamicIslandExpanded = settings.dynamicIslandPinned
        }
        updateGlassCornerRadius()
        syncDockFrame(animated: animated)
        scheduleSave()
    }

    /// Frame (Quartz) where the radial switcher would place an app on the given screen, without moving the Dock.
    public func radialTargetFrameQuartz(screenID: String?, layout: RadialLayoutTarget) -> CGRect? {
        let screens = DisplayGeometry.allScreens()
        let scr: DisplayGeometry.ScreenInfo? = settings.useScreenWithCursor
            ? (screens.first(where: { $0.id == screenID }) ?? resolvedScreen())
            : resolvedScreen()
        guard let scr else { return nil }
        let base: CGRect = (scr.id == pinnedScreenID)
            ? currentLockedStageFrameQuartz()
            : DisplayGeometry.fullStageFrameQuartz(on: scr, margin: CGFloat(settings.effectiveOuterMargin))
        return DisplayGeometry.radialLayoutFrameQuartz(
            layout,
            base: base,
            screen: scr,
            splitGap: CGFloat(settings.splitGap)
        )
    }

    public func moveStageToNextScreen() {
        let screens = DisplayGeometry.allScreens()
        guard let next = DisplayGeometry.nextScreen(after: pinnedScreenID, screens: screens) else { return }
        pinnedScreenID = next.id
        customDockOriginQuartz = nil
        isStageHidden = false

        syncDockFrame(animated: true)
        onDockVisibilityShouldChange?(settings.dockShape != .radialOnly)
        if settings.dockShape != .radialOnly {
            onDockZOrderShouldUpdate?(.floatingFront)
        }

        realignCurrentLayout()
        warpCursorToCenterIfNeeded(of: currentLockedStageFrameQuartz())
        scheduleSave()
    }

    private func liveWindowFrameQuartz(for pid: pid_t, preferredWindow: AXUIElement? = nil) -> CGRect? {
        if let preferredWindow, let frame = AXWindowController.frame(of: preferredWindow), !frame.isEmpty {
            return frame
        }
        if isAccessibilityTrusted,
           let win = AXWindowController.primaryWindow(for: pid),
           let frame = AXWindowController.frame(of: win),
           !frame.isEmpty {
            return frame
        }
        return AXWindowController.onScreenWindowFramesQuartz(for: pid).first(where: { !$0.isEmpty })
    }

    private func scheduleDeferredFocusFollowUp(
        bundleID: String,
        pid: pid_t,
        shouldHideOthers: Bool,
        generation: UInt64
    ) {
        var didFollowUp = false
        for delay in [0.08, 0.22] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self,
                      !didFollowUp,
                      self.windowAlignGeneration == generation,
                      self.activeBundleID == bundleID,
                      let frame = self.liveWindowFrameQuartz(for: pid)
                else { return }
                didFollowUp = true
                self.warpCursorToCenterIfNeeded(of: frame)
                if shouldHideOthers {
                    let screens = DisplayGeometry.allScreens()
                    let screenID = DisplayGeometry.screen(containingQuartzRect: frame, screens: screens)?.id
                    self.scheduleHideOtherStagedApps(except: bundleID, onScreenID: screenID)
                }
            }
        }
    }

    private func warpCursorToCenterIfNeeded(of frameQuartz: CGRect) {
        guard settings.moveCursorWithWindow, !frameQuartz.isEmpty else { return }
        CGWarpMouseCursorPosition(CGPoint(x: frameQuartz.midX, y: frameQuartz.midY))
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    // MARK: - Freely Draggable Dock & Auto-Follow Stage

    public func beginDockDrag() {
        let dock = currentDockAndStageFramesQuartz().dock
        dragStartDockOriginQuartz = dock.origin
        dragStartDockSize = dock.size
        isDraggingDock = true
        dragPreviewEdge = settings.dockShape == .dynamicIsland ? settings.islandPosition : nil
    }

    public func updateDockDrag(deltaQuartz: CGPoint) {
        let proposedOrigin = CGPoint(
            x: round(dragStartDockOriginQuartz.x + deltaQuartz.x),
            y: round(dragStartDockOriginQuartz.y + deltaQuartz.y)
        )
        let proposedRect = CGRect(origin: proposedOrigin, size: dragStartDockSize)

        let screens = DisplayGeometry.allScreens()
        let primaryH = DisplayGeometry.primaryScreenHeight()
        let mouseAppKit = NSEvent.mouseLocation
        let mouseQuartz = CGPoint(x: mouseAppKit.x, y: primaryH - mouseAppKit.y)

        // Prefer the screen under the user's cursor during cross-monitor drag, then fallback to rect intersection
        let targetScreen = screens.first(where: { $0.frameQuartz.contains(mouseQuartz) })
            ?? DisplayGeometry.screen(containingQuartzRect: proposedRect, screens: screens)

        if let targetScreen = targetScreen {
            pinnedScreenID = targetScreen.id
            let bounds = targetScreen.frameQuartz
            let clampedX = min(max(proposedOrigin.x, bounds.minX), max(bounds.minX, bounds.maxX - dragStartDockSize.width))
            let clampedY = min(max(proposedOrigin.y, bounds.minY), max(bounds.minY, bounds.maxY - dragStartDockSize.height))
            let liveRect = CGRect(x: clampedX, y: clampedY, width: dragStartDockSize.width, height: dragStartDockSize.height).integral
            customDockOriginQuartz = liveRect.origin
            onDockFrameShouldUpdate?(DisplayGeometry.quartzToAppKit(liveRect, primaryHeight: primaryH), false)

            if settings.dockShape == .dynamicIsland {
                let candidate = DisplayGeometry.nearestEdge(forQuartzPoint: mouseQuartz, on: targetScreen)
                if dragPreviewEdge != candidate {
                    dragPreviewEdge = candidate
                    if settings.radialHapticsEnabled {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    }
                }
            }
        } else {
            customDockOriginQuartz = proposedOrigin
            onDockFrameShouldUpdate?(DisplayGeometry.quartzToAppKit(proposedRect, primaryHeight: primaryH), false)
        }
    }

    public func endDockDrag() {
        let screens = DisplayGeometry.allScreens()
        let primaryH = DisplayGeometry.primaryScreenHeight()
        let mouseAppKit = NSEvent.mouseLocation
        let mouseQuartz = CGPoint(x: mouseAppKit.x, y: primaryH - mouseAppKit.y)
        if let targetScreen = screens.first(where: { $0.frameQuartz.contains(mouseQuartz) }) ?? resolvedScreen() {
            pinnedScreenID = targetScreen.id
            if settings.dockShape == .dynamicIsland {
                let snappedEdge = DisplayGeometry.nearestEdge(forQuartzPoint: mouseQuartz, on: targetScreen)
                if settings.islandPosition != snappedEdge {
                    settings.islandPosition = snappedEdge
                    onDockWindowLevelShouldUpdate?(snappedEdge == .top)
                }
            }
        }

        isDraggingDock = false
        dragPreviewEdge = nil
        customDockOriginQuartz = nil
        updateGlassCornerRadius()
        syncDockFrame(animated: true)
        realignCurrentLayout()
        scheduleSave()
    }

    public func resetCustomDockLayout() {
        customDockOriginQuartz = nil
        settings.iconSize = 44
        updateGlassCornerRadius()
        syncDockFrame(animated: true)
        realignCurrentLayout()
        scheduleSave()
    }

    private func realignCurrentLayout() {
        if !isAccessibilityTrusted {
            isAccessibilityTrusted = AXWindowController.isAccessibilityTrusted(promptIfNeeded: false)
        }
        if layoutMode == .split2, let left = activeBundleID, let right = splitSecondaryBundleID {
            enterSplitMode(leftBundleID: left, rightBundleID: right)
        } else if let activeID = activeBundleID,
                  let activeItem = apps.first(where: { $0.bundleIdentifier == activeID }),
                  AXWindowController.runningApp(bundleIdentifier: activeID) != nil {
            preAlignAndActivate(
                item: activeItem,
                to: currentLockedStageFrameQuartz(),
                hideOthersAfter: settings.hideInactiveStagedApps
            )
        }
    }

    // MARK: - Manual App List Management & Process Controls

    public func addApp(_ item: StageAppItem) {
        guard !Self.excludedBundleIDs.contains(item.bundleIdentifier) else { return }
        guard !apps.contains(where: { $0.bundleIdentifier == item.bundleIdentifier }) else { return }
        apps.append(item)
        refreshRuntimeInfo()
        syncDockFrame(animated: true)
        scheduleSave()
    }

    @discardableResult
    public func addCurrentlyRunningRegularApps(limit: Int = 6) -> Int {
        let selfBID = Bundle.main.bundleIdentifier
        var added = 0
        for running in NSWorkspace.shared.runningApplications where running.activationPolicy == .regular {
            guard added < limit else { break }
            guard let bid = running.bundleIdentifier,
                  bid != selfBID,
                  bid != "com.iring.mac",
                  bid != "com.aistage.mac",
                  !Self.excludedBundleIDs.contains(bid),
                  !apps.contains(where: { $0.bundleIdentifier == bid }),
                  let url = running.bundleURL,
                  let item = discovery.appItem(from: url)
            else { continue }
            apps.append(item)
            added += 1
        }
        if added > 0 {
            if activeBundleID == nil {
                activeBundleID = apps.first?.bundleIdentifier
            }
            refreshRuntimeInfo()
            syncDockFrame(animated: true)
            scheduleSave()
        }
        return added
    }

    public func removeApp(bundleID: String) {
        apps.removeAll { $0.bundleIdentifier == bundleID }
        if activeBundleID == bundleID {
            activeBundleID = displayedApps.first?.bundleIdentifier
        }
        if splitSecondaryBundleID == bundleID {
            splitSecondaryBundleID = nil
            layoutMode = .monocleStack
        }
        syncDockFrame(animated: true)
        scheduleSave()
    }

    public func moveApp(fromBundleID sourceID: String, toBundleID targetID: String) {
        guard sourceID != targetID,
              let fromIdx = apps.firstIndex(where: { $0.bundleIdentifier == sourceID }),
              let toIdx = apps.firstIndex(where: { $0.bundleIdentifier == targetID })
        else { return }
        let moved = apps.remove(at: fromIdx)
        apps.insert(moved, at: toIdx)
        scheduleSave()
    }

    public func quitApp(bundleID: String) {
        guard let running = AXWindowController.runningApp(bundleIdentifier: bundleID) else { return }
        running.terminate()
        if splitSecondaryBundleID == bundleID {
            splitSecondaryBundleID = nil
            layoutMode = .monocleStack
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshRuntimeInfo()
        }
    }

    public func relaunchApp(bundleID: String) {
        guard let item = apps.first(where: { $0.bundleIdentifier == bundleID }) else { return }
        recordAppUsage(bundleID: bundleID)
        if let running = AXWindowController.runningApp(bundleIdentifier: bundleID) {
            running.terminate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.switchToApp(bundleID: item.bundleIdentifier)
            }
        } else {
            switchToApp(bundleID: item.bundleIdentifier)
        }
    }

    public func revealInFinder(bundleID: String) {
        guard let item = apps.first(where: { $0.bundleIdentifier == bundleID }) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.appURL])
    }

    public func updateSettings(_ mutate: (inout StageSettings) -> Void) {
        let oldHotkey = settings.toggleHotkey
        let oldCustomToggle = settings.customToggleShortcut
        let oldCustomMoveScreen = settings.customMoveScreenShortcut
        let oldRadialKbMode = settings.radialKeyboardMode
        let oldRadialKbShortcut = settings.radialKeyboardShortcut
        let oldSplitRingEnabled = settings.splitRingHotkeyEnabled
        let oldSplitRingShortcut = settings.splitRingShortcut
        let oldNumMod = settings.numberSwitchModifier
        let oldCustomNumMods = settings.customNumberSwitchModifiers
        let oldLanguage = settings.language
        let oldIconSize = settings.iconSize
        let oldWidth = settings.dockWidth
        let oldHorizH = settings.horizontalDockHeight
        let oldCircD = settings.circularDockDiameter
        let oldShape = settings.dockShape
        let oldIslandPos = settings.islandPosition
        let oldExpandedVertical = settings.isExpandedIslandVertical
        let oldIslandCustomW = settings.islandCustomWidth
        let oldIslandCustomH = settings.islandCustomHeight
        let oldAutoHide = settings.autoHideDock
        let oldPinned = settings.dynamicIslandPinned
        let oldHideMenuBar = settings.hideMenuBarIcon
        let oldLaunchAtLogin = settings.launchAtLogin
        let oldIncludePadding = settings.includePadding
        let oldOuterMargin = settings.outerMargin
        let oldSplitGap = settings.splitGap

        mutate(&settings)

        if abs(settings.iconSize - oldIconSize) > 0.1 {
            let newThickness = settings.effectiveDockThickness
            settings.dockWidth = newThickness
            settings.horizontalDockHeight = newThickness
        }
        if oldExpandedVertical != settings.isExpandedIslandVertical {
            settings.islandCustomWidth = 0
            settings.islandCustomHeight = 0
        }
        if settings.autoHideDock && !oldAutoHide {
            isAutoHideRevealed = false
        }
        if settings.dynamicIslandPinned != oldPinned {
            isDynamicIslandExpanded = settings.dynamicIslandPinned
        }
        if oldHideMenuBar != settings.hideMenuBarIcon {
            onMenuBarVisibilityShouldChange?(!settings.hideMenuBarIcon)
        }
        if oldLaunchAtLogin != settings.launchAtLogin {
            syncLaunchAtLogin(enabled: settings.launchAtLogin)
        }
        if oldLanguage != settings.language {
            L10n.setLanguage(settings.language)
            onLanguageDidChange?()
        }

        if oldHotkey != settings.toggleHotkey
            || oldCustomToggle != settings.customToggleShortcut
            || oldCustomMoveScreen != settings.customMoveScreenShortcut
            || oldRadialKbMode != settings.radialKeyboardMode
            || oldRadialKbShortcut != settings.radialKeyboardShortcut
            || oldSplitRingEnabled != settings.splitRingHotkeyEnabled
            || oldSplitRingShortcut != settings.splitRingShortcut
            || oldNumMod != settings.numberSwitchModifier
            || oldCustomNumMods != settings.customNumberSwitchModifiers {
            applyHotkeys()
        }
        if oldShape != settings.dockShape || oldIslandPos != settings.islandPosition {
            onDockWindowLevelShouldUpdate?(settings.dockShape == .dynamicIsland && settings.islandPosition == .top)
            isDockPointerHovering = false
            isAutoHideRevealed = false
        }
        if oldWidth != settings.dockWidth
            || oldHorizH != settings.horizontalDockHeight
            || oldCircD != settings.circularDockDiameter
            || oldShape != settings.dockShape
            || oldPinned != settings.dynamicIslandPinned
            || abs(oldIslandCustomW - settings.islandCustomWidth) > 0.1
            || abs(oldIslandCustomH - settings.islandCustomHeight) > 0.1 {
            updateGlassCornerRadius()
        }
        syncDockFrame(animated: true)

        let stageLayoutGeometryChanged = (oldIncludePadding != settings.includePadding)
            || (abs(oldOuterMargin - settings.outerMargin) > 0.1)
            || (abs(oldSplitGap - settings.splitGap) > 0.1)
            || (oldShape != settings.dockShape)
        if stageLayoutGeometryChanged {
            if layoutMode == .split2, let left = activeBundleID, let right = splitSecondaryBundleID {
                enterSplitMode(leftBundleID: left, rightBundleID: right)
            } else if let activeID = activeBundleID,
                      let running = AXWindowController.runningApp(bundleIdentifier: activeID),
                      isAccessibilityTrusted,
                      let win = AXWindowController.primaryWindow(for: running.processIdentifier) {
                AXWindowController.setFrame(currentLockedStageFrameQuartz(), of: win, pid: running.processIdentifier)
            }
        }

        if !settings.smartZOrder && !isStageHidden {
            onDockZOrderShouldUpdate?(.floatingFront)
        }
        scheduleSave()
    }

    public func requestAccessibilityPermission() {
        let wasTrusted = isAccessibilityTrusted
        isAccessibilityTrusted = AXWindowController.isAccessibilityTrusted(promptIfNeeded: true)
        if !wasTrusted && isAccessibilityTrusted {
            onAccessibilityTrustChanged?(true)
        }
        if !isAccessibilityTrusted,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        } else {
            refreshRuntimeInfo()
        }
    }

    private func syncLaunchAtLogin(enabled: Bool) {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        do {
            let current = (SMAppService.mainApp.status == .enabled)
            if enabled && !current {
                try SMAppService.mainApp.register()
            } else if !enabled && current {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("[AIStage] Launch at login update failed: \(error.localizedDescription)")
            settings.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    public func relaunchSelf() {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", "sleep 0.35; open -n \"\(bundleURL.path)\""]
        try? proc.run()
        NSApp.terminate(nil)
    }

    // MARK: - Internal Pre-Align & Activation

    private func preAlignAndActivate(
        item: StageAppItem,
        to frame: CGRect,
        hideOthersAfter: Bool,
        onScreenID: String? = nil,
        generation: UInt64? = nil,
        smoothResize: Bool = false
    ) {
        let gen = generation ?? windowAlignGeneration
        if let running = AXWindowController.runningApp(bundleIdentifier: item.bundleIdentifier) {
            let wasHidden = running.isHidden
            if wasHidden {
                running.unhide()
            }
            if isAccessibilityTrusted {
                if let win = AXWindowController.primaryWindow(for: running.processIdentifier) {
                    applyAndVerifyFrame(
                        item: item,
                        running: running,
                        win: win,
                        to: frame,
                        hideOthersAfter: hideOthersAfter,
                        onScreenID: onScreenID,
                        wasHidden: wasHidden,
                        generation: gen,
                        smoothResize: smoothResize && !wasHidden
                    )
                    return
                } else {
                    AXWindowController.activateApplication(running, window: nil, appURL: item.appURL)
                    let pid = running.processIdentifier
                    let delays = wasHidden ? [0.06, 0.16, 0.34, 0.55] : [0.06, 0.18, 0.38]
                    for delay in delays {
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                            guard let self = self,
                                  self.windowAlignGeneration == gen,
                                  self.isAccessibilityTrusted,
                                  self.activeBundleID == item.bundleIdentifier,
                                  let win = AXWindowController.primaryWindow(for: pid),
                                  !AXWindowController.isFullScreen(win)
                            else { return }
                            AXWindowController.unminimizeIfNeeded(win)
                            AXWindowController.setFrame(frame, of: win, pid: pid)
                            AXWindowController.raise(win)
                        }
                    }
                    if hideOthersAfter {
                        scheduleHideOtherStagedApps(except: item.bundleIdentifier, onScreenID: onScreenID)
                    }
                    return
                }
            }
            AXWindowController.activateApplication(running, window: nil, appURL: item.appURL)
            if hideOthersAfter {
                scheduleHideOtherStagedApps(except: item.bundleIdentifier, onScreenID: onScreenID)
            }
            return
        }

        launchAndWaitForWindow(item: item, targetFrame: frame, hideOthersAfter: hideOthersAfter, onScreenID: onScreenID)
    }

    private func captureSnapshotOfOutgoingApp(beforeSwitchingTo nextBundleID: String) {
        guard WindowSnapshotCache.isScreenCaptureAuthorized,
              settings.windowPopAnimationStyle != .off,
              let previousID = activeBundleID,
              previousID != nextBundleID,
              let prevRunning = AXWindowController.runningApp(bundleIdentifier: previousID),
              !prevRunning.isHidden
        else { return }
        let fallbackFrame = isAccessibilityTrusted
            ? AXWindowController.primaryWindow(for: prevRunning.processIdentifier).flatMap { AXWindowController.frame(of: $0) }
            : nil
        snapshotCache.captureAsync(
            bundleID: previousID,
            pid: prevRunning.processIdentifier,
            fallbackFrameQuartz: fallbackFrame
        )
    }

    private func scheduleSnapshotRefresh(for bundleID: String, generation: UInt64, delay: TimeInterval = 0.65) {
        guard WindowSnapshotCache.isScreenCaptureAuthorized else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self,
                  self.windowAlignGeneration == generation,
                  self.activeBundleID == bundleID,
                  let running = AXWindowController.runningApp(bundleIdentifier: bundleID),
                  !running.isHidden
            else { return }
            let fallbackFrame = self.isAccessibilityTrusted
                ? AXWindowController.primaryWindow(for: running.processIdentifier).flatMap { AXWindowController.frame(of: $0) }
                : nil
            self.snapshotCache.captureAsync(
                bundleID: bundleID,
                pid: running.processIdentifier,
                fallbackFrameQuartz: fallbackFrame
            )
        }
    }

    private func applyAndVerifyFrame(
        item: StageAppItem,
        running: NSRunningApplication,
        win: AXUIElement,
        to frame: CGRect,
        hideOthersAfter: Bool,
        onScreenID: String? = nil,
        wasHidden: Bool = false,
        generation: UInt64,
        smoothResize: Bool = false
    ) {
        if smoothResize && !AXWindowController.isFullScreen(win) {
            AXWindowController.unminimizeIfNeeded(win)
            AXWindowController.activateApplication(running, window: win, appURL: item.appURL)
            let pid = running.processIdentifier
            let animDuration = max(0.14, settings.ringAnimationSpeed.previewFrameDuration)
            frameAnimator.animate(
                window: win,
                pid: pid,
                runningApp: running,
                to: frame,
                duration: animDuration
            ) { [weak self] _ in
                guard let self,
                      self.windowAlignGeneration == generation,
                      self.activeBundleID == item.bundleIdentifier
                else { return }
                AXWindowController.raise(win)
                self.scheduleFrameVerification(
                    pid: pid,
                    window: win,
                    targetFrame: frame,
                    generation: generation,
                    delays: wasHidden ? [0.06, 0.18, 0.38, 0.60] : [0.08, 0.24, 0.45]
                )
                if hideOthersAfter {
                    self.scheduleHideOtherStagedApps(except: item.bundleIdentifier, onScreenID: onScreenID)
                }
            }
            return
        }

        if !AXWindowController.isFullScreen(win) {
            AXWindowController.unminimizeIfNeeded(win)
            // 1. Align silently behind the current frontmost window FIRST (zero shake)
            AXWindowController.setFrame(frame, of: win, pid: running.processIdentifier)
        }
        // 2. Atomically raise & activate
        AXWindowController.activateApplication(running, window: win, appURL: item.appURL)

        // 3. Post-activation confirmations for cross-display, hidden-app unhide, or Electron/Chromium windows
        let pid = running.processIdentifier
        let delays = wasHidden ? [0.06, 0.16, 0.34, 0.55] : [0.06, 0.18, 0.38]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self,
                      self.windowAlignGeneration == generation,
                      self.isAccessibilityTrusted,
                      self.activeBundleID == item.bundleIdentifier,
                      let currentWin = AXWindowController.primaryWindow(for: pid),
                      !AXWindowController.isFullScreen(currentWin)
                else { return }
                if let currentF = AXWindowController.frame(of: currentWin) {
                    let d = abs(currentF.origin.x - frame.origin.x)
                        + abs(currentF.origin.y - frame.origin.y)
                        + abs(currentF.width - frame.width)
                        + abs(currentF.height - frame.height)
                    if d > 4.0 {
                        AXWindowController.setFrame(frame, of: currentWin, pid: pid)
                        AXWindowController.raise(currentWin)
                    }
                }
            }
        }
        if hideOthersAfter {
            scheduleHideOtherStagedApps(except: item.bundleIdentifier, onScreenID: onScreenID)
        }
    }

    private func scheduleFrameVerification(
        pid: pid_t,
        window targetWindow: AXUIElement? = nil,
        targetFrame: CGRect,
        generation: UInt64,
        delays: [TimeInterval] = [0.08, 0.22]
    ) {
        let rounded = targetFrame.integral
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self,
                      self.windowAlignGeneration == generation,
                      self.isAccessibilityTrusted,
                      let currentWin = targetWindow ?? AXWindowController.primaryWindow(for: pid),
                      !AXWindowController.isFullScreen(currentWin)
                else { return }
                if let currentF = AXWindowController.frame(of: currentWin) {
                    let d = abs(currentF.origin.x - rounded.origin.x)
                        + abs(currentF.origin.y - rounded.origin.y)
                        + abs(currentF.width - rounded.width)
                        + abs(currentF.height - rounded.height)
                    if d > 4.0 {
                        AXWindowController.setFrame(rounded, of: currentWin, pid: pid)
                        AXWindowController.raise(currentWin)
                    }
                }
            }
        }
    }

    private func scheduleHideOtherStagedApps(except keepBundleID: String, onScreenID: String? = nil) {
        pendingHideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self,
                  self.activeBundleID == keepBundleID,
                  !self.isStageHidden
            else { return }
            self.hideOtherStagedApps(except: keepBundleID, onScreenID: onScreenID)
        }
        pendingHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func hideOtherStagedApps(except keepBundleID: String, onScreenID: String? = nil) {
        let screens = DisplayGeometry.allScreens()
        let targetLiveScreenID: String? = AXWindowController.runningApp(bundleIdentifier: keepBundleID)
            .flatMap { liveWindowFrameQuartz(for: $0.processIdentifier) }
            .flatMap { DisplayGeometry.screen(containingQuartzRect: $0, screens: screens)?.id }
        guard let effectiveScreenID = DisplayGeometry.effectiveHideTargetScreenID(
            explicitScreenID: onScreenID,
            targetAppLiveScreenID: targetLiveScreenID,
            dockScreenID: resolvedScreen()?.id,
            screenCount: screens.count
        ) else { return }

        for other in apps where other.bundleIdentifier != keepBundleID {
            guard let running = AXWindowController.runningApp(bundleIdentifier: other.bundleIdentifier),
                  !running.isHidden
            else { continue }

            var frames = AXWindowController.onScreenWindowFramesQuartz(for: running.processIdentifier)
            if frames.isEmpty && isAccessibilityTrusted,
               let win = AXWindowController.primaryWindow(for: running.processIdentifier),
               let frame = AXWindowController.frame(of: win) {
                frames = [frame]
            }
            guard DisplayGeometry.shouldHideAppOnScreenSwitch(
                appWindowFramesQuartz: frames,
                targetScreenID: effectiveScreenID,
                screens: screens
            ) else {
                continue
            }
            running.hide()
        }
    }

    private func launchAndWaitForWindow(item: StageAppItem, targetFrame: CGRect, hideOthersAfter: Bool, onScreenID: String? = nil) {
        launchingBundleIDs.insert(item.bundleIdentifier)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.openApplication(at: item.appURL, configuration: config) { [weak self] app, error in
            Task { @MainActor in
                guard let self = self else { return }
                if let error = error {
                    NSLog("[AIStage] Failed to launch \(item.displayName): \(error.localizedDescription)")
                    self.launchingBundleIDs.remove(item.bundleIdentifier)
                    return
                }
                let pid = app?.processIdentifier
                await self.pollUntilWindowReady(
                    bundleID: item.bundleIdentifier,
                    pidHint: pid,
                    targetFrame: targetFrame,
                    hideOthersAfter: hideOthersAfter,
                    onScreenID: onScreenID
                )
                self.launchingBundleIDs.remove(item.bundleIdentifier)
                self.refreshRuntimeInfo()
            }
        }
    }

    private func pollUntilWindowReady(
        bundleID: String,
        pidHint: pid_t?,
        targetFrame: CGRect,
        hideOthersAfter: Bool,
        onScreenID: String? = nil
    ) async {
        for _ in 0..<50 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            let running = AXWindowController.runningApp(bundleIdentifier: bundleID)
            let pid = running?.processIdentifier ?? pidHint
            if let pid = pid, isAccessibilityTrusted, let win = AXWindowController.primaryWindow(for: pid) {
                AXWindowController.unminimizeIfNeeded(win)
                AXWindowController.setFrame(targetFrame, of: win, pid: pid)
                if let running = running {
                    AXWindowController.activateApplication(
                        running,
                        window: win,
                        appURL: apps.first(where: { $0.bundleIdentifier == bundleID })?.appURL
                    )
                } else {
                    AXWindowController.raise(win)
                }
                if hideOthersAfter {
                    scheduleHideOtherStagedApps(except: bundleID, onScreenID: onScreenID)
                }
                syncDockFrame(animated: false)
                if settings.dockShape != .radialOnly {
                    onDockZOrderShouldUpdate?(.floatingFront)
                }
                return
            }
        }
    }

    // MARK: - Smart Z-Order & System Observers

    private func installAccessibilityObserver() {
        distributedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                Task { @MainActor in
                    guard let self = self else { return }
                    let wasTrusted = self.isAccessibilityTrusted
                    self.isAccessibilityTrusted = AXWindowController.isAccessibilityTrusted(promptIfNeeded: false)
                    if !wasTrusted && self.isAccessibilityTrusted {
                        self.onAccessibilityTrustChanged?(true)
                    }
                    self.refreshRuntimeInfo()
                }
            }
        }
    }

    private func installWorkspaceObservers() {
        let nc = NSWorkspace.shared.notificationCenter

        let actToken = nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                self?.handleFrontmostAppChanged(app)
            }
        }

        let launchToken = nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshRuntimeInfo()
            }
        }

        let termToken = nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                if let bid = app?.bundleIdentifier {
                    if bid == self?.splitSecondaryBundleID {
                        self?.splitSecondaryBundleID = nil
                        self?.layoutMode = .monocleStack
                    }
                    self?.refreshRuntimeInfo()
                }
            }
        }

        workspaceObservers = [actToken, launchToken, termToken]
    }

    private func handleFrontmostAppChanged(_ app: NSRunningApplication?) {
        guard let app = app, let bid = app.bundleIdentifier else { return }

        if ProcessInfo.processInfo.systemUptime < switchInFlightUntil && bid != activeBundleID {
            return
        }

        if apps.contains(where: { $0.bundleIdentifier == bid }) {
            recordAppUsage(bundleID: bid)
            isStageHidden = false
            onDockVisibilityShouldChange?(settings.dockShape != .radialOnly)

            if bid != activeBundleID && bid != splitSecondaryBundleID {
                splitSecondaryBundleID = nil
                layoutMode = .monocleStack
                activeBundleID = bid
            }
            onDockZOrderShouldUpdate?(.floatingFront)
            if settings.showNotificationBadges {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                    self?.refreshRuntimeInfo()
                }
            }
            return
        }

        updateZOrderForFrontmostApp(app)
    }

    private func updateZOrderForFrontmostApp(_ app: NSRunningApplication?) {
        guard !isStageHidden else {
            onDockZOrderShouldUpdate?(.hidden)
            return
        }
        guard let app = app, let bid = app.bundleIdentifier else { return }

        if bid == Bundle.main.bundleIdentifier || apps.contains(where: { $0.bundleIdentifier == bid }) || settings.dockShape == .dynamicIsland {
            onDockZOrderShouldUpdate?(.floatingFront)
        } else if settings.smartZOrder {
            let frontWinNum = AXWindowController.topmostWindowNumber(for: app.processIdentifier)
            onDockZOrderShouldUpdate?(.normalBelow(windowNumber: frontWinNum))
        } else {
            onDockZOrderShouldUpdate?(.floatingFront)
        }
    }

    // MARK: - Runtime Sampling & Dock Badges

    public func refreshRuntimeInfo() {
        let trustedNow = AXWindowController.isAccessibilityTrusted(promptIfNeeded: false)
        if trustedNow != isAccessibilityTrusted {
            isAccessibilityTrusted = trustedNow
            if trustedNow {
                onAccessibilityTrustChanged?(true)
            }
        }

        let badgeSnapshot: AXWindowController.DockBadgeSnapshot?
        if settings.showNotificationBadges {
            let axSnapshot = trustedNow ? AXWindowController.readDockBadges() : AXWindowController.DockBadgeSnapshot()
            badgeSnapshot = cachedLSBadgeSnapshot.merged(with: axSnapshot)
        } else {
            cachedLSBadgeSnapshot = AXWindowController.DockBadgeSnapshot()
            badgeSnapshot = nil
        }

        var next: [String: AppRuntimeInfo] = [:]
        var runningBundleIDs: [String] = []
        for item in apps {
            let running = AXWindowController.runningApp(bundleIdentifier: item.bundleIdentifier)
            let badge = badgeSnapshot?.badge(
                forBundleID: item.bundleIdentifier,
                appURL: item.appURL,
                displayName: item.displayName,
                localizedName: running?.localizedName
            )

            if let running {
                runningBundleIDs.append(item.bundleIdentifier)
                let pid = running.processIdentifier
                let mem = AppDiscoveryService.memoryUsageMB(for: pid)
                var title = runtimeInfo[item.bundleIdentifier]?.windowTitle ?? ""
                if trustedNow && item.bundleIdentifier == activeBundleID,
                   let win = AXWindowController.primaryWindow(for: pid) {
                    title = AXWindowController.windowTitle(of: win)
                }
                next[item.bundleIdentifier] = AppRuntimeInfo(
                    isRunning: true,
                    pid: pid,
                    memoryMB: mem,
                    windowTitle: title,
                    badgeLabel: badge
                )
            } else {
                next[item.bundleIdentifier] = AppRuntimeInfo(
                    isRunning: false,
                    badgeLabel: badge
                )
            }
        }
        runtimeInfo = next

        if settings.showNotificationBadges, !runningBundleIDs.isEmpty {
            scheduleLaunchServicesBadgeRefresh(forBundleIDs: runningBundleIDs)
        }
    }

    private func scheduleLaunchServicesBadgeRefresh(forBundleIDs bundleIDs: [String]) {
        guard !isFetchingLSBadges else { return }
        isFetchingLSBadges = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let freshLS = AXWindowController.readLaunchServicesBadges(forBundleIDs: bundleIDs)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isFetchingLSBadges = false
                guard self.settings.showNotificationBadges else { return }
                guard freshLS.byBundleID != self.cachedLSBadgeSnapshot.byBundleID else { return }
                self.cachedLSBadgeSnapshot = freshLS
                let axSnapshot = self.isAccessibilityTrusted
                    ? AXWindowController.readDockBadges()
                    : AXWindowController.DockBadgeSnapshot()
                let merged = freshLS.merged(with: axSnapshot)
                var updated = self.runtimeInfo
                for item in self.apps {
                    let running = AXWindowController.runningApp(bundleIdentifier: item.bundleIdentifier)
                    let badge = merged.badge(
                        forBundleID: item.bundleIdentifier,
                        appURL: item.appURL,
                        displayName: item.displayName,
                        localizedName: running?.localizedName
                    )
                    if var info = updated[item.bundleIdentifier] {
                        info.badgeLabel = badge
                        updated[item.bundleIdentifier] = info
                    }
                }
                self.runtimeInfo = updated
            }
        }
    }

    private func loadInitialState() {
        if let saved = persistence.load() {
            self.settings = saved.settings
            if self.settings.isExpandedIslandVertical {
                self.settings.islandCustomWidth = 0
            } else {
                self.settings.islandCustomHeight = 0
            }
            L10n.setLanguage(self.settings.language)
            let filtered = saved.apps.filter {
                $0.existsOnDisk && !Self.excludedBundleIDs.contains($0.bundleIdentifier)
            }
            self.apps = filtered
            self.appUsageCounts = saved.appUsageCounts
            self.appLastUsedTimestamps = saved.appLastUsedTimestamps
            self.pinnedScreenID = saved.pinnedScreenID
            self.customDockOriginQuartz = saved.customDockOriginQuartz?.cgPoint
            if let lastID = saved.lastActiveBundleID, !Self.excludedBundleIDs.contains(lastID) {
                self.activeBundleID = lastID
            } else {
                self.activeBundleID = nil
            }
            if filtered.count != saved.apps.count {
                scheduleSave()
            }
        } else {
            // Manual curation: start clean and let user pick the exact apps they want
            L10n.setLanguage(self.settings.language)
            self.apps = []
            scheduleSave()
        }
    }

    public func setHotkeysSuspended(_ suspended: Bool) {
        hotkeysSuspended = suspended
        if suspended {
            hotkeyManager.unregisterAll()
        } else {
            applyHotkeys()
        }
    }

    private func applyHotkeys() {
        guard !hotkeysSuspended else { return }
        hotkeyManager.configure(
            toggleShortcut: settings.effectiveToggleShortcut,
            moveScreenShortcut: settings.effectiveMoveScreenShortcut,
            radialShortcut: settings.activeRadialKeyboardShortcut,
            splitRingShortcut: settings.activeSplitRingShortcut,
            numberModifiers: settings.effectiveNumberSwitchModifiers
        ) { [weak self] action in
            Task { @MainActor in
                guard let self = self else { return }
                switch action {
                case .toggleStage:
                    self.toggleStageVisibility()
                case .moveToNextScreen:
                    self.moveStageToNextScreen()
                case .radialTriggerPressed:
                    self.onRadialKeyboardTriggerPressed?()
                case .radialTriggerReleased:
                    self.onRadialKeyboardTriggerReleased?()
                case .splitRingPressed:
                    self.onSplitRingHotkeyPressed?()
                case .splitRingReleased:
                    self.onSplitRingHotkeyReleased?()
                case .switchToSlot(let idx):
                    self.switchToSlot(idx)
                }
            }
        }
    }

    private func prewarmSnapshotsIfAuthorized() {
        guard WindowSnapshotCache.isScreenCaptureAuthorized,
              settings.windowPopAnimationStyle != .off
        else { return }
        for item in apps {
            guard let running = AXWindowController.runningApp(bundleIdentifier: item.bundleIdentifier),
                  !running.isHidden
            else { continue }
            let fallback = isAccessibilityTrusted
                ? AXWindowController.primaryWindow(for: running.processIdentifier).flatMap { AXWindowController.frame(of: $0) }
                : nil
            snapshotCache.captureAsync(
                bundleID: item.bundleIdentifier,
                pid: running.processIdentifier,
                fallbackFrameQuartz: fallback
            )
        }
    }

    private func startTimers() {
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshRuntimeInfo()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.prewarmSnapshotsIfAuthorized()
        }
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let config = PersistedStageConfig(
                apps: self.apps,
                pinnedScreenID: self.pinnedScreenID,
                customDockOriginQuartz: self.customDockOriginQuartz.map { CodablePoint($0) },
                lastActiveBundleID: self.activeBundleID,
                settings: self.settings,
                appUsageCounts: self.appUsageCounts,
                appLastUsedTimestamps: self.appLastUsedTimestamps
            )
            self.persistence.save(config)
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }
}
