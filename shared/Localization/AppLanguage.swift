import Foundation

// Persisted on AppCoordinator.language — see that file for the didSet/UserDefaults
// pattern shared by every other app-wide setting.
public enum AppLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"

    // Deliberately not localized by L() itself — this is the label for the language
    // picker's own options, so each one always reads in its own language regardless
    // of which language is currently active (mirrors language_english/language_spanish
    // in the spreadsheet, kept Translate=FALSE for the same reason).
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        }
    }
}
