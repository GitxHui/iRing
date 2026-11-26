import Foundation

public final class PersistenceStore {
    public let configURL: URL

    public init(directoryURL: URL? = nil) {
        let baseDir: URL
        if let dir = directoryURL {
            baseDir = dir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            baseDir = appSupport.appendingPathComponent("AIStage", isDirectory: true)
        }
        self.configURL = baseDir.appendingPathComponent("config.json")
    }

    public func load() -> PersistedStageConfig? {
        guard FileManager.default.fileExists(atPath: configURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            return try decoder.decode(PersistedStageConfig.self, from: data)
        } catch {
            NSLog("[AIStage] Failed to load config: \(error.localizedDescription)")
            return nil
        }
    }

    public func save(_ config: PersistedStageConfig) {
        do {
            let dir = configURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL, options: [.atomic])
        } catch {
            NSLog("[AIStage] Failed to save config: \(error.localizedDescription)")
        }
    }
}
