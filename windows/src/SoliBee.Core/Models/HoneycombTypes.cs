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
        HoneycombRule.BombShelter => "Hive Swarm",
        HoneycombRule.Ascension => "Pollination",
        HoneycombRule.Descension => "Smoked Out",
        HoneycombRule.Same => "Symmetry",
        HoneycombRule.Plus => "Nectar Math",
        HoneycombRule.FallenAce => "Queen's Fall",
        HoneycombRule.Reverse => "Inversion",
        HoneycombRule.AllOpen => "Clear Skies",
        HoneycombRule.ThreeOpen => "Scouting Party",
        HoneycombRule.Swap => "Nectar Exchange",
        HoneycombRule.Order => "Hierarchy",
        HoneycombRule.Chaos => "Swarm Frenzy",
        HoneycombRule.SuddenDeath => "Swarm to the Death",
        _ => rule.ToString()
    };
}

public enum HoneycombDifficulty
{
    Easy, Medium, Hard, UltraHard
}
