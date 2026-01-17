import AppKit

enum Language: String, CaseIterable {
    case english = "English"
    case spanish = "Spanish"
    case polish = "Polish"
    case russian = "Russian"
    case french = "French"
    case italian = "Italian"
    case german = "German"
    case portuguese = "Portuguese"
    case chinese = "Chinese"
    case japanese = "Japanese"
    case korean = "Korean"
    case arabic = "Arabic"
    case hindi = "Hindi"
    case dutch = "Dutch"
    case swedish = "Swedish"
    case turkish = "Turkish"
    case ukrainian = "Ukrainian"

    var code: String {
        switch self {
        case .english: return "en"
        case .spanish: return "es"
        case .polish: return "pl"
        case .russian: return "ru"
        case .french: return "fr"
        case .italian: return "it"
        case .german: return "de"
        case .portuguese: return "pt"
        case .chinese: return "zh"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .arabic: return "ar"
        case .hindi: return "hi"
        case .dutch: return "nl"
        case .swedish: return "sv"
        case .turkish: return "tr"
        case .ukrainian: return "uk"
        }
    }

    var nativeName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .polish: return "Polski"
        case .russian: return "Русский"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .german: return "Deutsch"
        case .portuguese: return "Português"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .arabic: return "العربية"
        case .hindi: return "हिन्दी"
        case .dutch: return "Nederlands"
        case .swedish: return "Svenska"
        case .turkish: return "Türkçe"
        case .ukrainian: return "Українська"
        }
    }
}

enum AppConfig {
    static let panelSize = NSSize(width: 460, height: 84)
    static let visibleLines: CGFloat = 3
    static let bottomPadding: CGFloat = 10
    static let topDeadArea: CGFloat = 40
    static let pauseForBlankLine: TimeInterval = 1.2
    static let displayCharLimit: Int = 220

    // Translation settings
    static var targetLanguage: Language = .polish
}
