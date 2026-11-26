import AppKit
import Foundation

public struct StageAppItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String { bundleIdentifier }
    public let bundleIdentifier: String
    public var displayName: String
    public var appPath: String

    public init(bundleIdentifier: String, displayName: String, appPath: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.appPath = appPath
    }

    public var appURL: URL {
        URL(fileURLWithPath: appPath)
    }

    public var existsOnDisk: Bool {
        FileManager.default.fileExists(atPath: appPath)
    }
}

public struct AppRuntimeInfo: Equatable, Sendable {
    public var isRunning: Bool = false
    public var pid: pid_t? = nil
    public var memoryMB: Int = 0
    public var windowTitle: String = ""
    public var badgeLabel: String? = nil

    public init(
        isRunning: Bool = false,
        pid: pid_t? = nil,
        memoryMB: Int = 0,
        windowTitle: String = "",
        badgeLabel: String? = nil
    ) {
        self.isRunning = isRunning
        self.pid = pid
        self.memoryMB = memoryMB
        self.windowTitle = windowTitle
        self.badgeLabel = badgeLabel
    }
}
