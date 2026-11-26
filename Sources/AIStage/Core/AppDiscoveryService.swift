import AppKit
import Darwin
import Foundation

public final class AppDiscoveryService {
    /// Priority-ordered known mainstream AI desktop apps on macOS.
    private static let knownBundleIDs: [(bundleID: String, preferredName: String)] = [
        ("com.openai.codex", "ChatGPT"),
        ("com.openai.chat", "ChatGPT"),
        ("com.anthropic.claudefordesktop", "Claude"),
        ("com.google.GeminiMacOS", "Gemini"),
        ("com.bot.pc.doubao", "豆包"),
        ("com.tencent.yuanbao", "元宝"),
        ("com.anysphere.sand", "Grok Bot"),
        ("ai.perplexity.mac", "Perplexity"),
        ("com.moonshot.kimi", "Kimi"),
        ("com.deepseek.chat", "DeepSeek"),
        ("com.kangfenmao.CherryStudio", "Cherry Studio"),
        ("xyz.chatboxapp.app", "Chatbox"),
        ("com.todesktop.230313mzl4w4u92", "Cursor"),
        ("com.codeium.windsurf", "Windsurf"),
        ("com.trae.app", "Trae")
    ]

    private static let keywordHints = [
        "chatgpt", "claude", "gemini", "doubao", "豆包", "yuanbao", "元宝",
        "grok", "perplexity", "kimi", "deepseek", "cherry studio", "chatbox",
        "cursor", "poe", "monica", "ollama", "lm studio", "jan"
    ]

    private var iconCache: [String: NSImage] = [:]

    public init() {}

    /// Discover installed AI desktop apps from `/Applications` and `~/Applications`.
    public func discoverInstalledAIApps() -> [StageAppItem] {
        let allApps = scanAllInstalledApps()
        var byBundleID: [String: StageAppItem] = [:]
        for item in allApps {
            if byBundleID[item.bundleIdentifier] == nil {
                byBundleID[item.bundleIdentifier] = item
            }
        }

        var result: [StageAppItem] = []
        var seen: Set<String> = []

        // 1. Add known AI apps in curated priority order
        for known in Self.knownBundleIDs {
            if var found = byBundleID[known.bundleID], !seen.contains(found.bundleIdentifier) {
                if found.displayName.isEmpty {
                    found.displayName = known.preferredName
                }
                result.append(found)
                seen.insert(found.bundleIdentifier)
            }
        }

        // 2. Add any additional installed apps matching AI name/bundle hints (excluding browsers & iRing itself by default)
        let excludedKeywords = ["browser", "chrome", "safari", "edge", "firefox", "aistage", "iring", "ide", "antigravity"]
        for item in allApps {
            guard !seen.contains(item.bundleIdentifier) else { continue }
            let lowerName = item.displayName.lowercased()
            let lowerBID = item.bundleIdentifier.lowercased()
            if excludedKeywords.contains(where: { lowerName.contains($0) || lowerBID.contains($0) }) {
                continue
            }
            if Self.keywordHints.contains(where: { lowerName.contains($0) || lowerBID.contains($0) }) {
                result.append(item)
                seen.insert(item.bundleIdentifier)
            }
        }

        return result
    }

    /// Scan all `.app` bundles inside `/Applications` and `~/Applications`.
    public func scanAllInstalledApps() -> [StageAppItem] {
        let searchRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        var items: [StageAppItem] = []
        var seen: Set<String> = []

        for root in searchRoots {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents {
                if url.pathExtension == "app" {
                    if let item = appItem(from: url), !seen.contains(item.bundleIdentifier) {
                        items.append(item)
                        seen.insert(item.bundleIdentifier)
                    }
                } else if url.lastPathComponent.hasSuffix(".localized") {
                    // Check PWA subdirectories like Chrome Apps / Edge Apps
                    if let sub = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                        for subURL in sub where subURL.pathExtension == "app" {
                            if let item = appItem(from: subURL), !seen.contains(item.bundleIdentifier) {
                                items.append(item)
                                seen.insert(item.bundleIdentifier)
                            }
                        }
                    }
                }
            }
        }

        return items.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public func appItem(from appURL: URL) -> StageAppItem? {
        guard let bundle = Bundle(url: appURL),
              let bundleID = bundle.bundleIdentifier,
              !bundleID.isEmpty
        else { return nil }

        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? appURL.deletingPathExtension().lastPathComponent

        return StageAppItem(
            bundleIdentifier: bundleID,
            displayName: displayName,
            appPath: appURL.path
        )
    }

    /// Cached crisp Retina application icon.
    public func icon(for item: StageAppItem) -> NSImage {
        if let cached = iconCache[item.appPath] {
            return cached
        }
        let img = NSWorkspace.shared.icon(forFile: item.appPath)
        img.size = NSSize(width: 64, height: 64)
        iconCache[item.appPath] = img
        return img
    }

    /// Sample resident/physical memory usage in MB for a PID (including child helper processes if desired).
    public static func memoryUsageMB(for pid: pid_t) -> Int {
        var rusage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &rusage) { ptr -> Int32 in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rptr in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, rptr)
            }
        }
        guard result == 0 else { return 0 }
        let bytes = rusage.ri_phys_footprint
        return Int(bytes / (1024 * 1024))
    }
}
