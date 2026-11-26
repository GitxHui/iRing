import AppKit
import ApplicationServices
import CoreGraphics

/// Encapsulates macOS Accessibility (`AXUIElement` & `AXObserver`) window control and observation.
public final class AXWindowController {

    public struct ObservedWindowEvent {
        public let pid: pid_t
        public let notification: String
        public let frameQuartz: CGRect?
    }

    private var activeObserver: AXObserver?
    private var observedElement: AXUIElement?
    private var observedPID: pid_t?
    private var onWindowEvent: ((ObservedWindowEvent) -> Void)?

    public init() {}

    deinit {
        stopObserving()
    }

    // MARK: - Trust

    public static func isAccessibilityTrusted(promptIfNeeded: Bool = false) -> Bool {
        if promptIfNeeded {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            let options = [key: true] as CFDictionary
            if AXIsProcessTrustedWithOptions(options) {
                return true
            }
        } else if AXIsProcessTrusted() {
            return true
        }

        // Fallback real probe: on some macOS builds AXIsProcessTrusted() caches stale false
        // briefly after toggling System Settings; verify with a harmless read-only AX query.
        let probeCandidates = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        for app in probeCandidates.prefix(3) {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var val: CFTypeRef?
            let err = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &val)
            if err == .success {
                return true
            }
            if err == .apiDisabled {
                return false
            }
        }
        return false
    }

    // MARK: - macOS Dock Unread Notification Badges (AXStatusLabel)

    public struct DockBadgeSnapshot {
        public let byBundleID: [String: String]
        public let byAppPath: [String: String]
        public let byTitleLower: [String: String]

        public init(
            byBundleID: [String: String] = [:],
            byAppPath: [String: String] = [:],
            byTitleLower: [String: String] = [:]
        ) {
            self.byBundleID = byBundleID
            self.byAppPath = byAppPath
            self.byTitleLower = byTitleLower
        }

        public func badge(
            forBundleID bundleID: String,
            appURL: URL,
            displayName: String,
            localizedName: String? = nil
        ) -> String? {
            if let hit = byBundleID[bundleID.lowercased()] {
                return hit
            }
            let stdPath = appURL.standardizedFileURL.path
            if let hit = byAppPath[stdPath] {
                return hit
            }
            let realPath = appURL.resolvingSymlinksInPath().standardizedFileURL.path
            if let hit = byAppPath[realPath] {
                return hit
            }
            if let hit = byTitleLower[displayName.lowercased()] {
                return hit
            }
            if let loc = localizedName?.lowercased(), let hit = byTitleLower[loc] {
                return hit
            }
            let fileBase = appURL.deletingPathExtension().lastPathComponent.lowercased()
            return byTitleLower[fileBase]
        }
    }

    public static func normalizedBadgeLabel(from raw: Any?) -> String? {
        guard let raw else { return nil }
        let str: String
        if let s = raw as? String {
            str = s
        } else if let attr = raw as? NSAttributedString {
            str = attr.string
        } else if let num = raw as? NSNumber {
            if num.doubleValue <= 0 { return nil }
            str = num.stringValue
        } else {
            return nil
        }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "0" else { return nil }
        return trimmed
    }

    public static func readDockBadges() -> DockBadgeSnapshot {
        var byBundleID: [String: String] = [:]
        var byPath: [String: String] = [:]
        var byTitle: [String: String] = [:]

        guard let dockApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else {
            return DockBadgeSnapshot(byBundleID: byBundleID, byAppPath: byPath, byTitleLower: byTitle)
        }

        var runningBundleByPath: [String: String] = [:]
        var runningBundleByTitle: [String: String] = [:]
        for app in NSWorkspace.shared.runningApplications {
            guard let bid = app.bundleIdentifier?.lowercased() else { continue }
            if let url = app.bundleURL {
                runningBundleByPath[url.standardizedFileURL.path] = bid
                runningBundleByPath[url.resolvingSymlinksInPath().standardizedFileURL.path] = bid
            }
            if let name = app.localizedName?.lowercased(), !name.isEmpty {
                runningBundleByTitle[name] = bid
            }
        }

        let axDock = AXUIElementCreateApplication(dockApp.processIdentifier)
        var dockItems: [AXUIElement] = []
        collectDockBadgeElements(from: axDock, depth: 0, maxDepth: 3, into: &dockItems)

        for item in dockItems {
            var badgeRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(item, "AXStatusLabel" as CFString, &badgeRef) == .success,
                  let badge = normalizedBadgeLabel(from: badgeRef)
            else { continue }

            var resolvedBundleID: String?
            var urlRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(item, kAXURLAttribute as CFString, &urlRef) == .success,
               let url = urlRef as? URL {
                let std = url.standardizedFileURL.path
                let real = url.resolvingSymlinksInPath().standardizedFileURL.path
                byPath[std] = badge
                byPath[real] = badge
                resolvedBundleID = Bundle(url: url)?.bundleIdentifier?.lowercased()
                    ?? runningBundleByPath[std]
                    ?? runningBundleByPath[real]
            }

            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef) == .success,
               let title = titleRef as? String, !title.isEmpty {
                let lower = title.lowercased()
                byTitle[lower] = badge
                if resolvedBundleID == nil {
                    resolvedBundleID = runningBundleByTitle[lower]
                }
            }

            if let resolvedBundleID {
                byBundleID[resolvedBundleID] = badge
            }
        }

        return DockBadgeSnapshot(byBundleID: byBundleID, byAppPath: byPath, byTitleLower: byTitle)
    }

    private static func collectDockBadgeElements(
        from element: AXUIElement,
        depth: Int,
        maxDepth: Int,
        into results: inout [AXUIElement]
    ) {
        if depth > maxDepth { return }
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement]
        else { return }

        for child in children {
            var roleRef: CFTypeRef?
            let hasRole = AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef) == .success
            if hasRole, (roleRef as? String) == "AXDockItem" {
                results.append(child)
            } else {
                collectDockBadgeElements(from: child, depth: depth + 1, maxDepth: maxDepth, into: &results)
            }
        }
    }

    // MARK: - Running App Lookup

    public static func runningApp(bundleIdentifier: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleIdentifier && $0.activationPolicy == .regular
        } ?? NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated
        }
    }

    // MARK: - Window Inspection & Control

    public static func primaryWindow(for pid: pid_t) -> AXUIElement? {
        let axApp = AXUIElementCreateApplication(pid)

        // 1. Prefer focused or main window if it looks like a real standard window
        for attr in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            if let win = copyElementAttribute(axApp, attr as CFString),
               isCandidateMainWindow(win) {
                return win
            }
        }

        // 2. Fallback to the largest standard window in kAXWindowsAttribute
        guard let windows = copyWindows(axApp), !windows.isEmpty else {
            return nil
        }

        let standardCandidates = windows.filter { isCandidateMainWindow($0) }
        if let largest = standardCandidates.max(by: { windowArea($0) < windowArea($1) }) {
            return largest
        }

        // 3. Final fallback: any visible window with reasonable size
        return windows.first {
            if let frame = frame(of: $0) {
                return frame.width >= 260 && frame.height >= 200
            }
            return false
        } ?? windows.first
    }

    public static func windowTitle(of window: AXUIElement) -> String {
        var val: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &val) == .success,
           let title = val as? String {
            return title
        }
        return ""
    }

    public static func frame(of window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posVal = posRef, let sizeVal = sizeRef
        else { return nil }

        var pt = CGPoint.zero
        var sz = CGSize.zero
        guard AXValueGetValue(posVal as! AXValue, .cgPoint, &pt),
              AXValueGetValue(sizeVal as! AXValue, .cgSize, &sz)
        else { return nil }

        return CGRect(origin: pt, size: sz)
    }

    public static func isMinimized(_ window: AXUIElement) -> Bool {
        var val: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &val) == .success,
           let b = val as? Bool {
            return b
        }
        return false
    }

    public static func isFullScreen(_ window: AXUIElement) -> Bool {
        var val: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &val) == .success,
           let b = val as? Bool {
            return b
        }
        return false
    }

    public static func unminimizeIfNeeded(_ window: AXUIElement) {
        if isMinimized(window) {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
    }

    /// Set only position (used during 60Hz live dock-drag for minimal overhead).
    @discardableResult
    public static func setPosition(_ origin: CGPoint, of window: AXUIElement) -> Bool {
        var pt = CGPoint(x: round(origin.x), y: round(origin.y))
        guard let axPos = AXValueCreate(.cgPoint, &pt) else { return false }
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPos) == .success
    }

    /// Set frame with AeroSpace-style `AXEnhancedUserInterface` bypass and safe cross-display transfer.
    @discardableResult
    public static func setFrame(
        _ target: CGRect,
        of window: AXUIElement,
        pid: pid_t? = nil,
        tolerance: CGFloat = 1.5
    ) -> Bool {
        let rounded = target.integral
        let current = frame(of: window)
        if let current = current {
            let sameOrigin = abs(current.origin.x - rounded.origin.x) <= tolerance
                && abs(current.origin.y - rounded.origin.y) <= tolerance
            let sameSize = abs(current.size.width - rounded.size.width) <= tolerance
                && abs(current.size.height - rounded.size.height) <= tolerance
            if sameOrigin && sameSize {
                return true
            }
        }

        // AeroSpace technique: temporarily disable AXEnhancedUserInterface on Chromium/Electron apps
        // so the OS snaps position & size in a single instant frame instead of animating/stuttering.
        var axApp: AXUIElement?
        var wasEnhanced = false
        if let pid = pid {
            let appEl = AXUIElementCreateApplication(pid)
            var enhancedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appEl, "AXEnhancedUserInterface" as CFString, &enhancedRef) == .success,
               let enabled = enhancedRef as? Bool, enabled {
                axApp = appEl
                wasEnhanced = true
                AXUIElementSetAttributeValue(appEl, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
            }
        }
        defer {
            if wasEnhanced, let axApp = axApp {
                AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            }
        }

        var pt = rounded.origin
        var sz = rounded.size
        guard let axPos = AXValueCreate(.cgPoint, &pt),
              let axSize = AXValueCreate(.cgSize, &sz)
        else { return false }

        let screens = DisplayGeometry.allScreens()
        let srcScreenID = current.flatMap { DisplayGeometry.screen(containingQuartzRect: $0, screens: screens)?.id }
        let dstScreen = DisplayGeometry.screen(containingQuartzRect: rounded, screens: screens)
        let dstScreenID = dstScreen?.id
        let isCrossDisplay = (srcScreenID != nil && dstScreenID != nil && srcScreenID != dstScreenID)

        let posErr: AXError
        let sizeErr: AXError

        if isCrossDisplay, let current = current {
            // Cross-display transfer: shrink first so the window fits cleanly inside BOTH displays,
            // move origin to the target display, then expand to target size.
            var safeSz = CGSize(
                width: max(320, min(current.width, rounded.width) - 4),
                height: max(240, min(current.height, rounded.height) - 4)
            )
            if let axSafeSize = AXValueCreate(.cgSize, &safeSz) {
                _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSafeSize)
            }
            posErr = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPos)
            sizeErr = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)

            // Two-step bounce fallback if macOS clamped the window at the previous monitor's boundary
            if let dstScreen = dstScreen, let midCheck = frame(of: window) {
                let midCenter = CGPoint(x: midCheck.midX, y: midCheck.midY)
                if !dstScreen.frameQuartz.contains(midCenter) {
                    var interiorPt = CGPoint(
                        x: dstScreen.visibleFrameQuartz.minX + 40,
                        y: dstScreen.visibleFrameQuartz.minY + 40
                    )
                    if let axInterior = AXValueCreate(.cgPoint, &interiorPt) {
                        _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axInterior)
                    }
                    _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPos)
                    _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
                }
            }
        } else {
            sizeErr = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
            posErr = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPos)
        }

        if let after = frame(of: window),
           abs(after.origin.x - rounded.origin.x) > tolerance
            || abs(after.origin.y - rounded.origin.y) > tolerance
            || abs(after.size.width - rounded.size.width) > tolerance
            || abs(after.size.height - rounded.size.height) > tolerance {
            _ = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
            _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPos)
        }

        return posErr == .success || sizeErr == .success
    }

    public static func raise(_ window: AXUIElement) {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    /// Reliably bring a target application and its primary window to the foreground on macOS 14–26.
    @MainActor
    public static func activateApplication(_ app: NSRunningApplication, window: AXUIElement? = nil, appURL: URL? = nil) {
        if app.isHidden {
            app.unhide()
        }
        if let window = window {
            unminimizeIfNeeded(window)
            raise(window)
        }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let axErr = AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)

        NSApplication.shared.yieldActivation(to: app)
        let ok = app.activate(options: [.activateAllWindows])

        if (!ok || axErr != .success || !app.isActive), let url = appURL {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            cfg.hidesOthers = false
            NSWorkspace.shared.openApplication(at: url, configuration: cfg, completionHandler: nil)
        }
    }

    /// Find the topmost on-screen CGWindowNumber belonging to `pid` (used for Smart Z-Order ordering).
    public static func topmostWindowNumber(for pid: pid_t) -> Int? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for info in list {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let winNum = info[kCGWindowNumber as String] as? Int
            else { continue }
            if let bounds = info[kCGWindowBounds as String] as? [String: Any],
               let w = bounds["Width"] as? Double,
               let h = bounds["Height"] as? Double,
               w >= 120 && h >= 120 {
                return winNum
            }
        }
        return nil
    }

    /// Return Quartz frames for all standard on-screen windows belonging to `pid` across all monitors.
    public static func onScreenWindowFramesQuartz(for pid: pid_t) -> [CGRect] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var frames: [CGRect] = []
        for info in list {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { continue }
            if let alpha = info[kCGWindowAlpha as String] as? Double, alpha <= 0.01 {
                continue
            }
            if let bounds = info[kCGWindowBounds as String] as? [String: Any],
               let x = bounds["X"] as? Double,
               let y = bounds["Y"] as? Double,
               let w = bounds["Width"] as? Double,
               let h = bounds["Height"] as? Double,
               w >= 120 && h >= 120 {
                frames.append(CGRect(x: x, y: y, width: w, height: h))
            }
        }
        return frames
    }

    /// Walks front-to-back on-screen windows to find the top real application window under `point` (Quartz).
    /// Returns `nil` when the cursor is over empty desktop / Finder wallpaper.
    public static func windowOwnerAtQuartzPoint(
        _ point: CGPoint,
        excludingPID: pid_t = ProcessInfo.processInfo.processIdentifier
    ) -> (pid: pid_t, bundleID: String?, frameQuartz: CGRect)? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let excludedBundles: Set<String> = [
            "com.apple.dock",
            "com.apple.controlcenter",
            "com.apple.systemuiserver",
            "com.apple.notificationcenterui",
            "com.apple.WindowManager",
            "com.iring.mac",
            "com.aistage.mac"
        ]
        let screens = DisplayGeometry.allScreens()

        for info in list {
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pidVal = info[kCGWindowOwnerPID as String] as? Int32,
                  pidVal != excludingPID
            else { continue }

            if let alpha = info[kCGWindowAlpha as String] as? Double, alpha <= 0.01 {
                continue
            }
            guard let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? Double,
                  let y = bounds["Y"] as? Double,
                  let w = bounds["Width"] as? Double,
                  let h = bounds["Height"] as? Double,
                  w >= 120 && h >= 120
            else { continue }

            let rect = CGRect(x: x, y: y, width: w, height: h)
            guard rect.contains(point) else { continue }

            guard let app = NSRunningApplication(processIdentifier: pidVal),
                  app.activationPolicy == .regular
            else { continue }

            let bid = app.bundleIdentifier
            if let bid, excludedBundles.contains(bid) {
                continue
            }
            // Skip Finder's full-screen desktop canvas window when user points at blank desktop
            if bid == "com.apple.finder" {
                let matchingScreen = DisplayGeometry.screen(containingQuartzPoint: point, screens: screens)
                if let scr = matchingScreen, rect.width >= scr.frameQuartz.width - 2 && rect.height >= scr.frameQuartz.height - 2 {
                    continue
                }
            }

            return (pid: pidVal, bundleID: bid, frameQuartz: rect)
        }
        return nil
    }

    // MARK: - AXObserver (Bidirectional Sync)

    public func observe(pid: pid_t, window: AXUIElement, handler: @escaping (ObservedWindowEvent) -> Void) {
        stopObserving()

        var observer: AXObserver?
        let callback: AXObserverCallback = { _, element, notification, refcon in
            guard let refcon = refcon else { return }
            let controller = Unmanaged<AXWindowController>.fromOpaque(refcon).takeUnretainedValue()
            let notifName = notification as String
            let currentFrame = AXWindowController.frame(of: element)
            let targetPID = controller.observedPID ?? 0
            DispatchQueue.main.async {
                controller.onWindowEvent?(ObservedWindowEvent(
                    pid: targetPID,
                    notification: notifName,
                    frameQuartz: currentFrame
                ))
            }
        }

        guard AXObserverCreate(pid, callback, &observer) == .success, let obs = observer else {
            return
        }

        self.activeObserver = obs
        self.observedElement = window
        self.observedPID = pid
        self.onWindowEvent = handler

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let notifications = [
            kAXMovedNotification,
            kAXResizedNotification,
            kAXUIElementDestroyedNotification
        ]
        for notif in notifications {
            AXObserverAddNotification(obs, window, notif as CFString, refcon)
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
    }

    public func stopObserving() {
        if let obs = activeObserver {
            if let elem = observedElement {
                AXObserverRemoveNotification(obs, elem, kAXMovedNotification as CFString)
                AXObserverRemoveNotification(obs, elem, kAXResizedNotification as CFString)
                AXObserverRemoveNotification(obs, elem, kAXUIElementDestroyedNotification as CFString)
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        }
        activeObserver = nil
        observedElement = nil
        observedPID = nil
        onWindowEvent = nil
    }

    // MARK: - Private Helpers

    private static func copyElementAttribute(_ element: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        var val: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &val) == .success,
              let unwrapped = val
        else { return nil }
        return (unwrapped as! AXUIElement)
    }

    private static func copyWindows(_ appElement: AXUIElement) -> [AXUIElement]? {
        var val: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &val) == .success,
              let wins = val as? [AXUIElement]
        else { return nil }
        return wins
    }

    private static func isCandidateMainWindow(_ window: AXUIElement) -> Bool {
        var roleRef: CFTypeRef?
        var subroleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef)
        AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef)

        let role = roleRef as? String ?? ""
        let subrole = subroleRef as? String ?? ""
        if role != kAXWindowRole as String {
            return false
        }
        if !subrole.isEmpty && subrole != kAXStandardWindowSubrole as String {
            return false
        }
        if let f = frame(of: window) {
            return f.width >= 300 && f.height >= 200
        }
        return true
    }

    private static func windowArea(_ window: AXUIElement) -> CGFloat {
        guard let f = frame(of: window) else { return 0 }
        return f.width * f.height
    }
}
