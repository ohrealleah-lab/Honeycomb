package com.leah.honeycomb.honeycomb

import com.leah.honeycomb.AppLanguage
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.Strings

// Display-only translations for HoneycombRule.displayName / explanation() and
// HoneycombDifficulty.displayName, which stay English at the source (they're also
// used as banner-catalog tokens, same as Mac). Mirrors the Swift port's
// HoneycombRuleLocalization.swift — use these for anything the player reads.

fun HoneycombRule.localizedName(language: AppLanguage): String = Strings.get(
    when (this) {
        HoneycombRule.Ascension -> StringKey.RuleNamePollination
        HoneycombRule.Descension -> StringKey.RuleNameSmokedOut
        HoneycombRule.Same -> StringKey.RuleNameSymmetry
        HoneycombRule.Plus -> StringKey.RuleNameMathBee
        HoneycombRule.FallenAce -> StringKey.RuleNameQueensFall
        HoneycombRule.Reverse -> StringKey.RuleNameInversion
        HoneycombRule.AllOpen -> StringKey.RuleNameClearSkies
        HoneycombRule.ThreeOpen -> StringKey.RuleNameScoutingParty
        HoneycombRule.Swap -> StringKey.RuleNameNectarExchange
        HoneycombRule.Order -> StringKey.RuleNameHierarchy
        HoneycombRule.Chaos -> StringKey.RuleNameFrenzy
        HoneycombRule.BombShelter -> StringKey.RuleNameCappedBrood
        HoneycombRule.SuddenDeath -> StringKey.RuleNameSwarmToTheDeath
    },
    language
)

// Like Swift, the suit-specific Ascension/Descension wording isn't translated yet —
// with suits active those two fall back to the English explanation(activeSuits).
fun HoneycombRule.localizedExplanation(activeSuits: Set<String> = emptySet(), language: AppLanguage): String {
    val key = when (this) {
        HoneycombRule.Same -> StringKey.RuleExplanationSame
        HoneycombRule.Plus -> StringKey.RuleExplanationPlus
        HoneycombRule.FallenAce -> StringKey.RuleExplanationFallenAce
        HoneycombRule.Reverse -> StringKey.RuleExplanationReverse
        HoneycombRule.Order -> StringKey.RuleExplanationOrder
        HoneycombRule.Chaos -> StringKey.RuleExplanationChaos
        HoneycombRule.AllOpen -> StringKey.RuleExplanationAllOpen
        HoneycombRule.ThreeOpen -> StringKey.RuleExplanationThreeOpen
        HoneycombRule.BombShelter -> StringKey.RuleExplanationBombShelter
        HoneycombRule.SuddenDeath -> StringKey.RuleExplanationSuddenDeath
        HoneycombRule.Swap -> StringKey.RuleExplanationSwap
        HoneycombRule.Ascension ->
            if (activeSuits.isEmpty()) StringKey.RuleExplanationAscensionGeneric else return explanation(activeSuits)
        HoneycombRule.Descension ->
            if (activeSuits.isEmpty()) StringKey.RuleExplanationDescensionGeneric else return explanation(activeSuits)
    }
    return Strings.get(key, language)
}

fun HoneycombDifficulty.localizedName(language: AppLanguage): String = Strings.get(
    when (this) {
        HoneycombDifficulty.Easy -> StringKey.StatBabyBee
        HoneycombDifficulty.Medium -> StringKey.StatHoneyBee
        HoneycombDifficulty.Hard -> StringKey.StatQueenBee
        HoneycombDifficulty.UltraHard -> StringKey.StatKillerBee
    },
    language
)
