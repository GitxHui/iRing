import AppKit
import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit

/// Silent LRU cache of recent per-app window snapshots captured via ScreenCaptureKit.
/// Used to render zero-latency Metal window pop-out animations when switching apps.
@MainActor
public final class WindowSnapshotCache {
    public struct Snapshot {
        public let image: CGImage
        public let frameQuartz: CGRect
        public let capturedAt: Date
        public let bundleID: String
    }

    private var cache: [String: Snapshot] = [:]
    private var lruOrder: [String] = []
    private var inFlightBundleIDs: Set<String> = []
    private let maxEntries = 12

    public init() {}

    /// Returns whether Screen Recording permission is currently granted without triggering any prompt.
    nonisolated public static var isScreenCaptureAuthorized: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Explicitly prompts macOS for Screen Recording permission (only invoked from user action).
    @discardableResult
    nonisolated public static func requestScreenCaptureAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    public func cachedSnapshot(for bundleID: String) -> Snapshot? {
        cache[bundleID]
    }

    public func invalidate(bundleID: String) {
        cache.removeValue(forKey: bundleID)
        lruOrder.removeAll { $0 == bundleID }
    }

    /// Asynchronously captures the frontmost main window of `pid` if Screen Recording is already authorized.
    /// Never shows an OS permission prompt when unauthorized.
    public func captureAsync(bundleID: String, pid: pid_t, fallbackFrameQuartz: CGRect? = nil) {
        guard Self.isScreenCaptureAuthorized else { return }
        guard pid > 0, !inFlightBundleIDs.contains(bundleID) else { return }

        inFlightBundleIDs.insert(bundleID)

        Task { @MainActor [weak self] in
            defer { self?.inFlightBundleIDs.remove(bundleID) }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                let candidates = content.windows.filter { win in
                    win.owningApplication?.processID == pid
                        && win.isOnScreen
                        && win.windowLayer == 0
                        && win.frame.width >= 80
                        && win.frame.height >= 80
                }
                guard let targetWindow = candidates.max(by: {
                    ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height)
                }) else {
                    return
                }

                let primaryHeight = DisplayGeometry.primaryScreenHeight()
                let targetAppKit = DisplayGeometry.quartzToAppKit(targetWindow.frame, primaryHeight: primaryHeight)
                let matchedScreen = NSScreen.screens.first(where: { $0.frame.intersects(targetAppKit) })
                let scale = Double(matchedScreen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0)

                let pixelWidth = max(160, min(3840, Int((targetWindow.frame.width * scale).rounded())))
                let pixelHeight = max(120, min(2400, Int((targetWindow.frame.height * scale).rounded())))

                let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
                let config = SCStreamConfiguration()
                config.width = pixelWidth
                config.height = pixelHeight
                config.showsCursor = false

                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                guard let self else { return }
                let snap = Snapshot(
                    image: cgImage,
                    frameQuartz: fallbackFrameQuartz ?? targetWindow.frame,
                    capturedAt: Date(),
                    bundleID: bundleID
                )
                self.store(snap)
            } catch {
                // Silent degradation: never interrupt window switching if ScreenCaptureKit fails.
            }
        }
    }

    private func store(_ snapshot: Snapshot) {
        cache[snapshot.bundleID] = snapshot
        lruOrder.removeAll { $0 == snapshot.bundleID }
        lruOrder.append(snapshot.bundleID)
        while lruOrder.count > maxEntries {
            let evicted = lruOrder.removeFirst()
            cache.removeValue(forKey: evicted)
        }
    }
}
