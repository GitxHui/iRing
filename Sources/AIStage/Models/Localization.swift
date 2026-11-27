import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case zhHans = "zh_hans"
    case en = "en"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system: return L10n.t("跟随系统", "Follow System")
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AppLanguage(rawValue: raw) ?? .system
    }
}

public enum ResolvedAppLanguage: String, Equatable, Sendable {
    case zhHans
    case en
}

public enum L10n {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _currentLanguage: AppLanguage = .zhHans

    public static var currentLanguage: AppLanguage {
        lock.lock()
        defer { lock.unlock() }
        return _currentLanguage
    }

    public static func setLanguage(_ language: AppLanguage) {
        lock.lock()
        _currentLanguage = language
        lock.unlock()
    }

    public static func resolve(
        _ language: AppLanguage,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> ResolvedAppLanguage {
        switch language {
        case .zhHans:
            return .zhHans
        case .en:
            return .en
        case .system:
            if let first = preferredLanguages.first?.lowercased(), first.hasPrefix("zh") {
                return .zhHans
            }
            return .en
        }
    }

    public static var isEnglish: Bool {
        resolve(currentLanguage) == .en
    }

    public static func t(_ zh: String, _ en: String) -> String {
        isEnglish ? en : zh
    }

    public static func t(_ zh: String, _ en: String, language: AppLanguage) -> String {
        resolve(language) == .en ? en : zh
    }
}
