using System.Collections.Generic;
using SoliBee.Core.Localization;

namespace SoliBee.Core.Models;

// Display-only translations for HoneycombRule.DisplayName() / .GetExplanation() and
// HoneycombDifficulty.DisplayName() — all stay English at the source (DisplayName()
// is the persisted/business-logic source of truth, see HoneycombTypes.cs's doc
// comment; ViewModel-constructed banner text keeps using DisplayName() directly,
// untouched). Lives in Core (not Desktop) because HoneycombViewModel (Core) needs it
// too, not just the View layer. Mirrors the Mac port's HoneycombRuleLocalization.swift
// (shared/Honeycomb/Models/).
public static class HoneycombRuleLocalization
{
    public static string LocalizedRuleName(HoneycombRule rule, AppLanguage language) => rule switch
    {
        HoneycombRule.Ascension   => Strings.Get(StringKey.RuleNamePollination, language),
        HoneycombRule.Descension  => Strings.Get(StringKey.RuleNameSmokedOut, language),
        HoneycombRule.Same        => Strings.Get(StringKey.RuleNameSymmetry, language),
        HoneycombRule.Plus        => Strings.Get(StringKey.RuleNameMathBee, language),
        HoneycombRule.FallenAce   => Strings.Get(StringKey.RuleNameQueensFall, language),
        HoneycombRule.Reverse     => Strings.Get(StringKey.RuleNameInversion, language),
        HoneycombRule.AllOpen     => Strings.Get(StringKey.RuleNameClearSkies, language),
        HoneycombRule.ThreeOpen   => Strings.Get(StringKey.RuleNameScoutingParty, language),
        HoneycombRule.Swap        => Strings.Get(StringKey.RuleNameNectarExchange, language),
        HoneycombRule.Order       => Strings.Get(StringKey.RuleNameHierarchy, language),
        HoneycombRule.Chaos       => Strings.Get(StringKey.RuleNameFrenzy, language),
        HoneycombRule.BombShelter => Strings.Get(StringKey.RuleNameCappedBrood, language),
        HoneycombRule.SuddenDeath => Strings.Get(StringKey.RuleNameSwarmToTheDeath, language),
        _ => rule.DisplayName(),
    };

    // The dynamic (activeSuits non-empty) Ascension/Descension wording isn't covered
    // by a translation yet, so it falls through to GetExplanation() as-is.
    public static string LocalizedRuleExplanation(HoneycombRule rule, HashSet<string>? activeSuits, AppLanguage language) => rule switch
    {
        HoneycombRule.Same        => Strings.Get(StringKey.RuleExplanationSame, language),
        HoneycombRule.Plus        => Strings.Get(StringKey.RuleExplanationPlus, language),
        HoneycombRule.FallenAce   => Strings.Get(StringKey.RuleExplanationFallenAce, language),
        HoneycombRule.Reverse     => Strings.Get(StringKey.RuleExplanationReverse, language),
        HoneycombRule.Order       => Strings.Get(StringKey.RuleExplanationOrder, language),
        HoneycombRule.Chaos       => Strings.Get(StringKey.RuleExplanationChaos, language),
        HoneycombRule.AllOpen     => Strings.Get(StringKey.RuleExplanationAllOpen, language),
        HoneycombRule.ThreeOpen   => Strings.Get(StringKey.RuleExplanationThreeOpen, language),
        HoneycombRule.BombShelter => Strings.Get(StringKey.RuleExplanationBombShelter, language),
        HoneycombRule.SuddenDeath => Strings.Get(StringKey.RuleExplanationSuddenDeath, language),
        HoneycombRule.Swap        => Strings.Get(StringKey.RuleExplanationSwap, language),
        HoneycombRule.Ascension when activeSuits == null || activeSuits.Count == 0 => Strings.Get(StringKey.RuleExplanationAscensionGeneric, language),
        HoneycombRule.Descension when activeSuits == null || activeSuits.Count == 0 => Strings.Get(StringKey.RuleExplanationDescensionGeneric, language),
        _ => rule.GetExplanation(activeSuits),
    };

    public static string LocalizedDifficultyName(HoneycombDifficulty difficulty, AppLanguage language) => difficulty switch
    {
        HoneycombDifficulty.Easy      => Strings.Get(StringKey.StatBabyBee, language),
        HoneycombDifficulty.Medium    => Strings.Get(StringKey.StatHoneyBee, language),
        HoneycombDifficulty.Hard      => Strings.Get(StringKey.StatQueenBee, language),
        HoneycombDifficulty.UltraHard => Strings.Get(StringKey.StatKillerBee, language),
        _ => difficulty.DisplayName(),
    };
}
