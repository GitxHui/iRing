import AppKit
import ApplicationServices
import Foundation

/// Smoothly interpolates `AXUIElement` window frames on the main thread (Rectangle / Loop style)
/// with per-PID cancellation and Electron / Chromium `AXEnhancedUserInterface` mitigation.
@MainActor
public final class WindowFrameAnimator {
    private struct ActiveAnimation {
        let timer: DispatchSourceTimer
        let pid: pid_t
        let restoredEnhancedUI: Bool
        let completion: ((Bool) -> Void)?
    }

    private var activeAnimations: [pid_t: ActiveAnimation] = [:]

    public init() {}

    /// Cubic ease-out frame interpolation between `start` and `end`.
    nonisolated public static func interpolatedFrame(from start: CGRect, to end: CGRect, progress rawProgress: Double) -> CGRect {
        let t = min(1.0, max(0.0, rawProgress))
        let eased = 1.0 - pow(1.0 - t, 3.0)
        return CGRect(
            x: start.origin.x + (end.origin.x - start.origin.x) * eased,
            y: start.origin.y + (end.origin.y - start.origin.y) * eased,
            width: start.size.width + (end.size.width - start.size.width) * eased,
            height: start.size.height + (end.size.height - start.size.height) * eased
        )
    }

    /// Detects Chromium / Electron apps whose accessibility bridge stalls under 60Hz AX updates.
    nonisolated public static func isChromiumOrElectron(app: NSRunningApplication?) -> Bool {
        guard let app else { return false }
        if let bid = app.bundleIdentifier?.lowercased() {
            let knownPrefixesOrTokens = [
                "com.google.chrome",
                "company.thebrowser.browser",
                "com.microsoft.edgemac",
                "com.brave.browser",
                "com.operasoftware",
                "com.vivaldi.vivaldi",
                "com.microsoft.vscode",
                "com.exafunction.windsurf",
                "com.todesktop.",
                "com.electron.",
                "com.figma.desktop",
                "com.tinyspeck.slackmacgap",
                "com.hnc.discord",
                "md.obsidian",
                "com.openai.chat",
                "com.anthropic.claudefordesktop",
                "notion.id",
                "com.cursor."
            ]
            if knownPrefixesOrTokens.contains(where: { bid.contains($0) }) {
                return true
            }
        }
        if let url = app.bundleURL {
            let electronFramework = url
                .appendingPathComponent("Contents/Frameworks/Electron Framework.framework")
            if FileManager.default.fileExists(atPath: electronFramework.path) {
                return true
            }
        }
        return false
    }

    public func cancel(pid: pid_t) {
        guard let active = activeAnimations.removeValue(forKey: pid) else { return }
        active.timer.cancel()
        if active.restoredEnhancedUI {
            let axApp = AXUIElementCreateApplication(pid)
            AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
        active.completion?(false)
    }

    public func cancelAll() {
        for pid in Array(activeAnimations.keys) {
            cancel(pid: pid)
        }
    }

    /// Smoothly animates `window` to `targetFrameQuartz` when on the same display and delta >= 6pt.
    /// Automatically degrades to direct snap for cross-display moves, tiny deltas, or zero duration.
    public func animate(
        window: AXUIElement,
        pid: pid_t,
        runningApp: NSRunningApplication?,
        to targetFrameQuartz: CGRect,
        duration: Double,
        completion: ((Bool) -> Void)? = nil
    ) {
        cancel(pid: pid)

        let targetRounded = targetFrameQuartz.integral
        guard duration > 0.02, let startFrame = AXWindowController.frame(of: window) else {
            AXWindowController.setFrame(targetRounded, of: window, pid: pid)
            completion?(true)
            return
        }

        let delta = max(
            abs(startFrame.origin.x - targetRounded.origin.x),
            abs(startFrame.origin.y - targetRounded.origin.y),
            abs(startFrame.size.width - targetRounded.size.width),
            abs(startFrame.size.height - targetRounded.size.height)
        )
        if delta < 6.0 {
            AXWindowController.setFrame(targetRounded, of: window, pid: pid)
            completion?(true)
            return
        }

        let screens = DisplayGeometry.allScreens()
        let srcScreenID = DisplayGeometry.screen(containingQuartzRect: startFrame, screens: screens)?.id
        let dstScreenID = DisplayGeometry.screen(containingQuartzRect: targetRounded, screens: screens)?.id
        if let srcScreenID, let dstScreenID, srcScreenID != dstScreenID {
            AXWindowController.setFrame(targetRounded, of: window, pid: pid)
            completion?(true)
            return
        }

        let axApp = AXUIElementCreateApplication(pid)
        var enhancedRef: CFTypeRef?
        var disabledEnhanced = false
        if AXUIElementCopyAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, &enhancedRef) == .success,
           let enabled = enhancedRef as? Bool, enabled {
            AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
            disabledEnhanced = true
        }

        let isChromium = Self.isChromiumOrElectron(app: runningApp)
        let interval = isChromium ? (1.0 / 30.0) : (1.0 / 60.0)
        let startTime = Date()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(1.0, elapsed / duration)
            let currentTarget = Self.interpolatedFrame(from: startFrame, to: targetRounded, progress: progress).integral

            if progress >= 1.0 {
                self.finish(pid: pid, window: window, finalFrame: targetRounded)
                return
            }

            Self.applyDirectAXFrame(currentTarget, to: window)
        }

        activeAnimations[pid] = ActiveAnimation(
            timer: timer,
            pid: pid,
            restoredEnhancedUI: disabledEnhanced,
            completion: completion
        )
        timer.resume()
    }

    private func finish(pid: pid_t, window: AXUIElement, finalFrame: CGRect) {
        guard let active = activeAnimations.removeValue(forKey: pid) else { return }
        active.timer.cancel()
        _ = AXWindowController.setFrame(finalFrame, of: window, pid: nil)
        if active.restoredEnhancedUI {
            let axApp = AXUIElementCreateApplication(pid)
            AXUIElementSetAttributeValue(axApp, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
        active.completion?(true)
    }

    private static func applyDirectAXFrame(_ frame: CGRect, to window: AXUIElement) {
        var sz = frame.size
        var pt = frame.origin
        if let axSize = AXValueCreate(.cgSize, &sz) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)
        }
        if let axPos = AXValueCreate(.cgPoint, &pt) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axPos)
        }
    }
}
