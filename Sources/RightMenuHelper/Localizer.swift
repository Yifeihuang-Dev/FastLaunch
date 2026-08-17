import Foundation

/// 语言偏好
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zh
    case en

    var id: String { rawValue }

    /// 设置界面中显示的选项名（用英文显示，避免歧义）
    var displayName: String {
        switch self {
        case .system: return "跟随系统 / System"
        case .zh: return "简体中文"
        case .en: return "English"
        }
    }
}

/// 轻量本地化：支持"跟随系统"或手动指定中/英文
final class Localizer {
    static let languageChanged = Notification.Name("Localizer.languageChanged")
    static let preferenceKey = "appLanguage"

    static var current: AppLanguage {
        get {
            let raw = UserDefaults.standard.string(forKey: preferenceKey) ?? AppLanguage.en.rawValue
            return AppLanguage(rawValue: raw) ?? .en
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferenceKey)
            NotificationCenter.default.post(name: languageChanged, object: nil)
        }
    }

    /// 当前是否使用英文
    static var isEnglish: Bool {
        switch current {
        case .system:
            let first = Locale.preferredLanguages.first?.lowercased() ?? ""
            return !(first.hasPrefix("zh"))
        case .zh:
            return false
        case .en:
            return true
        }
    }

    /// 根据当前语言返回文本
    static func t(_ zh: String, _ en: String) -> String {
        isEnglish ? en : zh
    }
}
