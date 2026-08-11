import Foundation

// Display-only translation for a poker hand name — VideoPokerPayEntry.handName and
// GameState.lastHandName stay English (they're compared directly for pay-table row
// highlighting on both Mac and iOS), this only swaps in translated text at the point
// of rendering. Shared so Mac's VideoPokerView.swift and iOS's VideoPokerTouchView.swift
// can't drift out of sync.
public func localizedHandName(_ handName: String, language: AppLanguage) -> String {
    switch handName {
    case "Royal Flush":          return L(.handRoyalFlush, language: language)
    case "High Card":            return L(.handHighCard, language: language)
    case "One Pair":             return L(.handOnePair, language: language)
    case "Two Pair":             return L(.handTwoPair, language: language)
    case "Three of a Kind":      return L(.handThreeOfAKind, language: language)
    case "Straight Flush":       return L(.handStraightFlush, language: language)
    case "Four of a Kind":       return L(.handFourOfAKind, language: language)
    case "Full House":           return L(.handFullHouse, language: language)
    case "Five of a Kind":       return L(.handFiveOfAKind, language: language)
    case "Four Aces":            return L(.handFourAces, language: language)
    case "Four 2s–4s":           return L(.handFour2s4s, language: language)
    case "Four Deuces":          return L(.handFourDeuces, language: language)
    case "Natural Royal Flush":  return L(.handNaturalRoyalFlush, language: language)
    case "Wild Royal Flush":     return L(.handWildRoyalFlush, language: language)
    case "No Win":               return L(.handNoWin, language: language)
    default:                     return handName
    }
}

// Display-only translation for a variant name — VideoPokerVariant.rawValue is
// Codable-persisted, so it stays English; this only swaps in translated text at the
// point of rendering. Shared so Mac's VideoPokerView.swift and iOS's
// VideoPokerTouchView.swift can't drift out of sync.
public func localizedVariantName(_ variant: VideoPokerVariant, language: AppLanguage) -> String {
    switch variant {
    case .jacksOrBetter: return L(.variantJacksOrBetter, language: language)
    case .deucesWild:    return L(.variantDeucesWild, language: language)
    case .bonusPoker:    return L(.variantBonusPoker, language: language)
    }
}
