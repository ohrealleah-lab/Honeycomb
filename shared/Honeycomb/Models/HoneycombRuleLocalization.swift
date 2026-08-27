import Foundation

// Display-only translations for HoneycombRule.rawValue / .explanation() and
// HoneycombDifficulty.displayName — all three stay English at the source (rawValue
// is persisted/compared elsewhere — bannedRules is a Set<String> of exact rawValues,
// and HoneycombViewModel interpolates rawValue/displayName directly into banner
// text), so those stay untouched. Takes `language` directly (not an AppCoordinator)
// so it's callable from both View code (pass coordinator.language) and ViewModel
// code, which doesn't hold an AppCoordinator reference (same reasoning as
// BannerCatalog.currentLanguage). Factored out here rather than duplicated per call
// site so they can't drift out of sync as rules are added or re-translated.
public func honeycombLocalizedRuleName(_ ruleName: String, language: AppLanguage) -> String {
    switch ruleName {
    case "Normal Mode":                       return L(.normalModeBanItem, language: language)
    case HoneycombRule.ascension.rawValue:    return L(.ruleNamePollination, language: language)
    case HoneycombRule.descension.rawValue:   return L(.ruleNameSmokedOut, language: language)
    case HoneycombRule.same.rawValue:         return L(.ruleNameSymmetry, language: language)
    case HoneycombRule.plus.rawValue:         return L(.ruleNameMathBee, language: language)
    case HoneycombRule.fallenAce.rawValue:    return L(.ruleNameQueensFall, language: language)
    case HoneycombRule.reverse.rawValue:      return L(.ruleNameInversion, language: language)
    case HoneycombRule.allOpen.rawValue:      return L(.ruleNameClearSkies, language: language)
    case HoneycombRule.threeOpen.rawValue:    return L(.ruleNameScoutingParty, language: language)
    case HoneycombRule.swap.rawValue:         return L(.ruleNameNectarExchange, language: language)
    case HoneycombRule.order.rawValue:        return L(.ruleNameHierarchy, language: language)
    case HoneycombRule.chaos.rawValue:        return L(.ruleNameFrenzy, language: language)
    case HoneycombRule.bombShelter.rawValue:  return L(.ruleNameCappedBrood, language: language)
    case HoneycombRule.suddenDeath.rawValue:  return L(.ruleNameSwarmToTheDeath, language: language)
    default: return ruleName
    }
}

// The dynamic (activeSuits non-empty) Ascension/Descension wording — with a specific
// suit list interpolated into the English sentence — isn't covered by a translation
// yet, so those two cases fall through to explanation(activeSuits:) as-is whenever
// suits are actually active; the generic (no-suits-yet) wording is translated.
public func honeycombLocalizedRuleExplanation(
    _ rule: HoneycombRule, activeSuits: Set<String> = [], language: AppLanguage
) -> String {
    switch rule {
    case .same:        return L(.ruleExplanationSame, language: language)
    case .plus:        return L(.ruleExplanationPlus, language: language)
    case .fallenAce:   return L(.ruleExplanationFallenAce, language: language)
    case .reverse:     return L(.ruleExplanationReverse, language: language)
    case .order:       return L(.ruleExplanationOrder, language: language)
    case .chaos:       return L(.ruleExplanationChaos, language: language)
    case .allOpen:     return L(.ruleExplanationAllOpen, language: language)
    case .threeOpen:   return L(.ruleExplanationThreeOpen, language: language)
    case .bombShelter: return L(.ruleExplanationBombShelter, language: language)
    case .suddenDeath: return L(.ruleExplanationSuddenDeath, language: language)
    case .swap:        return L(.ruleExplanationSwap, language: language)
    case .ascension:
        guard activeSuits.isEmpty else { return rule.explanation(activeSuits: activeSuits) }
        return L(.ruleExplanationAscensionGeneric, language: language)
    case .descension:
        guard activeSuits.isEmpty else { return rule.explanation(activeSuits: activeSuits) }
        return L(.ruleExplanationDescensionGeneric, language: language)
    }
}

public func honeycombLocalizedDifficultyName(_ difficulty: HoneycombDifficulty, language: AppLanguage) -> String {
    switch difficulty {
    case .easy:      return L(.statBabyBee, language: language)
    case .medium:    return L(.statHoneyBee, language: language)
    case .hard:      return L(.statQueenBee, language: language)
    case .ultraHard: return L(.statKillerBee, language: language)
    }
}

// The player's own hand-area label, opposite the opponent's difficulty-tier name
// (honeycombLocalizedDifficultyName above) — shows a rank tied to the player's
// lifetime card-collection progress (HoneycombProfileManager.shared.unlockedCardIds)
// instead of a static "Player" for everyone. totalCards should be
// HoneycombDatabase.shared.allCards.count, read live rather than hardcoded, so this
// never drifts out of sync if the generated collection's size ever changes.
// cardsCollected >= totalCards is checked before the 500+ band specifically so a
// player who has genuinely unlocked every card gets the distinct completionist title
// (Apiarist) rather than being folded into the same "500+" band as someone who's
// merely close (Hive Monarch).
public func honeycombLocalizedPlayerRankName(cardsCollected: Int, totalCards: Int, language: AppLanguage) -> String {
    if totalCards > 0 && cardsCollected >= totalCards {
        return L(.rankApiarist, language: language)
    }
    switch cardsCollected {
    case 500...:    return L(.rankHiveMonarch, language: language)
    case 400..<500: return L(.rankSwarmLeader, language: language)
    case 300..<400: return L(.rankRoyalAttendant, language: language)
    case 200..<300: return L(.rankCombArchitect, language: language)
    case 150..<200: return L(.rankWaggleDancer, language: language)
    case 100..<150: return L(.rankGuardBee, language: language)
    case 50..<100:  return L(.rankWorkerBee, language: language)
    case 20..<50:   return L(.rankScoutBee, language: language)
    case 10..<20:   return L(.rankNurseBee, language: language)
    default:        return L(.playerLabel, language: language)
    }
}
