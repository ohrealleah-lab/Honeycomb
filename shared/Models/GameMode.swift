import Foundation

public enum GameMode: String, Codable, CaseIterable, Identifiable {
    case klondike = "Klondike Solitaire"
    case beecell = "Freecell"
    case spider = "Spider Solitaire"
    case videoPoker = "Video Poker"
    case blackjack  = "Video Blackjack"
    case honeycomb  = "Honeycomb"

    public var id: String { self.rawValue }

    // Shown in the Game Selection dropdown. Distinct from `rawValue` so the persisted
    // "last selected game" UserDefaults value (keyed off rawValue) isn't disturbed by a
    // label-only rename.
    public var displayName: String {
        switch self {
        case .klondike:   return "Klondike Solibee"
        case .beecell:    return "Beecell"
        case .spider:     return "Spider Solibee"
        case .videoPoker: return rawValue
        case .blackjack:  return rawValue
        case .honeycomb:  return "Honeycomb"
        }
    }

    // Localized display name — displayName above stays English at the source (used
    // elsewhere e.g. debug/logging); this only swaps in a translation for display.
    // .videoPoker/.blackjack reuse the Help Guide's title keys (identical English
    // text, deduped onto one key during the xlsx merge); .honeycomb reuses appName.
    // Mirrors mac/src/Views/GameUIStyles.swift's own (private, Mac-only) equivalent —
    // shared here so iOS doesn't need its own separate copy.
    public func localizedDisplayName(language: AppLanguage) -> String {
        switch self {
        case .klondike:   return L(.gamemodeKlondikeDisplay, language: language)
        case .beecell:    return L(.gamemodeBeecellDisplay, language: language)
        case .spider:     return L(.gamemodeSpiderDisplay, language: language)
        case .videoPoker: return L(.helpVideopokerTitle, language: language)
        case .blackjack:  return L(.helpBlackjackTitle, language: language)
        case .honeycomb:  return L(.appName, language: language)
        }
    }
}
