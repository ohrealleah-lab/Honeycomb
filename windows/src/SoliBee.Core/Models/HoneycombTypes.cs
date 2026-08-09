using System.Linq;

namespace SoliBee.Core.Models;

public enum HoneycombRule
{
    Ascension, Descension, Same, Plus, FallenAce, Reverse, AllOpen, ThreeOpen, Swap, Order, Chaos, BombShelter, SuddenDeath
}

public static class HoneycombRuleWeights
{
    // Roulette draw weight — approximates real Triple Triad (FFXIV) NPC rule
    // frequencies so combo-enabling rules (Same/Plus) come up often and restrictive
    // ones (Reverse/Order/Descension) stay rare, instead of every rule having an
    // equal ~8.3% shot. Bomb Shelter has no FFXIV equivalent — tiered as Medium
    // alongside the other moderate-impact rules. Sudden Death is FFXIV's rarest rule
    // (2.2%) but is deliberately weighted High here — a product decision, not a
    // data-fidelity call, now that it's opt-in rather than automatic. Mirrors
    // HoneycombRule.weight in the Swift port (shared/Honeycomb/Models/HoneycombBoard.swift).
    public static int Weight(this HoneycombRule rule) => rule switch
    {
        HoneycombRule.Plus or HoneycombRule.Same or HoneycombRule.SuddenDeath => 30,
        HoneycombRule.Swap or HoneycombRule.Chaos or HoneycombRule.ThreeOpen or HoneycombRule.BombShelter => 15,
        HoneycombRule.Ascension or HoneycombRule.AllOpen or HoneycombRule.FallenAce => 8,
        HoneycombRule.Descension or HoneycombRule.Reverse or HoneycombRule.Order => 3,
        _ => 1
    };

    // User-facing name (bee-themed re-skin) — deliberately separate from the enum's own
    // name/ToString(), which stays the original identifier forever since it's the
    // persistence identity (ManualRules/BannedRules are saved by enum name) and the
    // roulette pool's ban-list matching key. Every UI surface that shows a rule name to
    // the player (rules picker, ban list, banners/toasts, help guide) should read
    // DisplayName(), never the enum name directly. Mirrors HoneycombRule.displayName in
    // the Swift port (shared/Honeycomb/Models/HoneycombBoard.swift).
    public static string DisplayName(this HoneycombRule rule) => rule switch
    {
        HoneycombRule.BombShelter => "Capped Brood",
        HoneycombRule.Ascension => "Pollination",
        HoneycombRule.Descension => "Smoked Out",
        HoneycombRule.Same => "Symmetry",
        HoneycombRule.Plus => "Math Bee",
        HoneycombRule.FallenAce => "Queen's Fall",
        HoneycombRule.Reverse => "Inversion",
        HoneycombRule.AllOpen => "Clear Skies",
        HoneycombRule.ThreeOpen => "Scouting Party",
        HoneycombRule.Swap => "Nectar Exchange",
        HoneycombRule.Order => "Hierarchy",
        HoneycombRule.Chaos => "Frenzy",
        HoneycombRule.SuddenDeath => "Swarm to the Death",
        _ => rule.ToString()
    };

    // Mirrors HoneycombRule.explanation in the Swift port.
    public static string GetExplanation(this HoneycombRule rule, System.Collections.Generic.HashSet<string>? activeSuits = null) => rule switch
    {
        HoneycombRule.Ascension => activeSuits != null && activeSuits.Count > 0
            ? $"Grants +1 to stats for all {string.Join(" and ", activeSuits.OrderBy(s => s).Select(HoneycombCardData.SuitDisplayName))} cards placed on the board."
            : "Grants +1 to stats for cards matching randomly selected suits placed on the board.",
        HoneycombRule.Descension => activeSuits != null && activeSuits.Count > 0
            ? $"Inflicts -1 to stats for all {string.Join(" and ", activeSuits.OrderBy(s => s).Select(HoneycombCardData.SuitDisplayName))} cards placed on the board."
            : "Inflicts -1 to stats for cards matching randomly selected suits placed on the board.",
        HoneycombRule.Same => "If 2+ touching neighbor stats match your card's facing stats, all matching neighbors are captured simultaneously.",
        HoneycombRule.Plus => "If the sum of (your stat + neighbor's stat) equals the same total across 2+ neighbors, all involved cards are captured.",
        HoneycombRule.BombShelter => "Each player's first card played remains face-down for 3 turns before flipping automatically.",
        HoneycombRule.Swap => "One card from each player's hand is randomly swapped at the start of the match.",
        HoneycombRule.AllOpen => "Both players' hands are completely visible.",
        HoneycombRule.ThreeOpen => "Three random cards in the opponent's hand are visible.",
        HoneycombRule.Order => "Cards must be played in the exact order they were drawn.",
        HoneycombRule.Chaos => "Cards are randomly selected and forced to be played each turn.",
        HoneycombRule.Reverse => "Lower stats capture higher stats.",
        HoneycombRule.FallenAce => "A stat of A (10) can be captured by a stat of 1. If Inversion is also active, this flips: a stat of A captures a stat of 1 instead.",
        HoneycombRule.SuddenDeath => "If the match ends in a draw, the cards currently owned by each player become their new hand and the match restarts immediately.",
        _ => ""
    };
}

public enum HoneycombDifficulty
{
    Easy, Medium, Hard, UltraHard
}

public static class HoneycombDifficultyExtensions
{
    // Matches the ComboBoxItem Content values in HoneycombRulesView.axaml and the
    // Swift port's HoneycombDifficulty.displayName — used wherever the opponent's
    // difficulty needs to show as a name rather than the raw enum value (e.g. the
    // toolbar's opponent score label).
    public static string DisplayName(this HoneycombDifficulty difficulty) => difficulty switch
    {
        HoneycombDifficulty.Easy => "Baby Bee",
        HoneycombDifficulty.Medium => "Honey Bee",
        HoneycombDifficulty.Hard => "Queen Bee",
        HoneycombDifficulty.UltraHard => "Killer Bee",
        _ => difficulty.ToString()
    };
}
