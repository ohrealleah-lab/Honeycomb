using System.Collections.Generic;

namespace SoliBee.Core.Models;

/// <summary>A tool the player can buy to catch more bees per click.</summary>
public sealed record BeekeeperTool(string Id, decimal Cost, int BeesPerClick);

/// <summary>
/// An upgrade sold in the Beekeeper's Shop. Its cost can mix resources. <see cref="Needs"/>
/// names what must come first: <see cref="BeekeeperUpgrades.NeedsWorkbench"/>,
/// <see cref="BeekeeperUpgrades.NeedsWaxCatcher"/>, <see cref="BeekeeperUpgrades.NeedsRepellent"/>,
/// or another upgrade's id. What it does is looked up by id in the engine.
/// </summary>
public sealed record BeekeeperUpgrade(string Id, decimal Beebits, decimal Wax, decimal Sage, string Needs);

/// <summary>A plant a seed grows into. <see cref="SeedAtTrade"/> is the Hippie trade that gives its seed;
/// <see cref="Specialty"/> is the job it gives the hive (<see cref="BeekeeperSpecialties"/>) and
/// <see cref="Strength"/> how much: pollen a minute for foraging, a honey multiplier for guarding.
/// Several plants of one specialty add up (pollen) or multiply (honey), so new plants are just
/// new entries (spec 014, FR-502).</summary>
public sealed record BeekeeperPlant(string Id, long SeedAtTrade, string Specialty, decimal Strength);
// Cut in stage 6 (spec 014): plants attracted counts of bees.
// public sealed record BeekeeperPlant(string Id, long SeedAtTrade, string Bee, decimal BeesPerMinute);

public static class BeekeeperPlants
{
    public const string Wildflowers = "wildflowers";
    public const string Bramble = "bramble";
}

/// <summary>Kinds of bee besides the honeybees.</summary>
public static class BeekeeperBees
{
    public const string Honey = "honeybees";
    // Cut in stage 6 (spec 014): plants give specialties, not counts of bees.
    // public const string Forager = "forager";
    // public const string Guard = "guard";
}

/// <summary>The jobs a plant can give the hive (spec 014). Derived from the sprouted plants, never saved.</summary>
public static class BeekeeperSpecialties
{
    /// <summary>A steady trickle of pollen.</summary>
    public const string Foraging = "foraging";
    /// <summary>"The hive feels safe": every honeybee makes more honey.</summary>
    public const string Guarding = "guarding";
}

/// <summary>Upgrade ids and the "needs" names that are not upgrades.</summary>
public static class BeekeeperUpgrades
{
    public const string BiggerCombs1 = "bigger_combs_1";
    public const string BiggerCombs2 = "bigger_combs_2";
    public const string BetterWaxCatcher = "better_wax_catcher";
    public const string StrongerCandles = "stronger_candles";

    // Stage 3
    public const string Practice = "practice";
    public const string MorePractice = "more_practice";
    public const string Smoker = "smoker";

    public const string NeedsWorkbench = "workbench";
    public const string NeedsWaxCatcher = "wax_catcher";
    public const string NeedsRepellent = "repellent";
    public const string NeedsVacuum = "vacuum_owned";
}

/// <summary>
/// Every Beekeeper tuning number, in one place (spec FR-002). Nothing else in the game
/// hard-codes these. Values marked "approved" were checked with
/// Beekeeper/tools/simulate_first_hour.py and approved by Leah; change them only with her say-so.
/// </summary>
public sealed class BeekeeperConfig
{
    // --- Honey and wax -------------------------------------------------------
    public decimal HoneyPerBeePerSecond { get; init; } = 0.01m;
    public decimal HoneyPerWax { get; init; } = 50m;
    public int WaxCatcherMultiplier { get; init; } = 2;

    // --- Honey storage (combs) ----------------------------------------------
    public decimal StartingStorage { get; init; } = 200m;   // approved by Leah 2026-11-06 for the first build; revisit after play-testing
    public decimal StoragePerComb { get; init; } = 200m;    // approved by Leah 2026-11-06 for the first build; revisit after play-testing
    public decimal CombBaseWaxCost { get; init; } = 50m;
    public decimal CombCostGrowth { get; init; } = 1.25m;

    // --- Catching ------------------------------------------------------------
    public double StingChance { get; init; } = 0.20;
    public int BareHandsBees { get; init; } = 1;

    /// <summary>Bought in this order. Index 0 is level 1 (Gloves); level 0 is Bare Hands.</summary>
    public IReadOnlyList<BeekeeperTool> Tools { get; init; } = new[]
    {
        new BeekeeperTool("gloves", 15m, 2),
        new BeekeeperTool("net", 75m, 5),
        new BeekeeperTool("vacuum", 250m, 10),
        // Stage 3 (spec 011): names Leah's, numbers placeholders.
        new BeekeeperTool("lure", 1_000m, 25),
        new BeekeeperTool("cart", 4_000m, 60),
        new BeekeeperTool("whistle", 15_000m, 150),
    };

    /// <summary>Each catch also brings in this share of the bees already in the hive,
    /// rounded down (Leah: 0.1%). Stings catch nothing.</summary>
    public decimal CatchSliceShare { get; init; } = 0.001m;

    public decimal WaxCatcherCost { get; init; } = 150m;

    // --- Trading -------------------------------------------------------------
    public decimal HoneyPerBeebit { get; init; } = 10m;
    public IReadOnlyList<string> BearNames { get; init; } = new[]
    {
        "Barnaby", "Billy", "Berenstein", "Bruno", "Baloo", "Buster", "Bartholomew",
    };

    // --- When things appear --------------------------------------------------
    public decimal BearRevealHoney { get; init; } = 10m;
    public decimal ShopRevealBeebits { get; init; } = 15m;
    public decimal CombsRevealWax { get; init; } = 50m;

    // --- Time away (offline earnings) ---------------------------------------
    /// <summary>Longest stretch that is paid: 3 days.</summary>
    public decimal OfflineCapSeconds { get; init; } = 3m * 24m * 60m * 60m;
    /// <summary>Share of normal production earned while away (Leah confirmed 100%).</summary>
    public decimal OfflineRate { get; init; } = 1m;
    /// <summary>A gap longer than this many seconds counts as time away.</summary>
    public decimal AwayThresholdSeconds { get; init; } = 2m;

    // ===== Stage 2 (spec 010). Everything below is a placeholder to be tuned later
    // (Leah, 2026-11-07), except where marked as Leah's number.

    // --- The Workbench and candles ------------------------------------------
    /// <summary>The Workbench opens with this many combs (Leah).</summary>
    public int WorkbenchCombs { get; init; } = 2;
    /// <summary>Wax for a beeswax candle (Leah).</summary>
    public decimal BeeswaxCandleWax { get; init; } = 10m;
    public decimal RepellentCandleWax { get; init; } = 10m;
    public decimal RepellentCandleSage { get; init; } = 1m;
    /// <summary>How long a repellent candle keeps wasps away, in seconds of wasp time (Leah: 15 min).</summary>
    public decimal RepellentBurnSeconds { get; init; } = 15m * 60m;

    // --- The Hippies ---------------------------------------------------------
    /// <summary>They arrive once this many candles of any kind have been crafted (Leah).</summary>
    public long HippiesRevealCandles { get; init; } = 5;
    /// <summary>Beeswax candles per sage (Leah: 1 sage per 10 candles).</summary>
    public decimal CandlesPerSage { get; init; } = 10m;

    // --- Wasps ---------------------------------------------------------------
    /// <summary>Wasp time between wasps: random between these (Leah: 4 to 8 minutes).</summary>
    public decimal WaspMinSeconds { get; init; } = 4m * 60m;
    public decimal WaspMaxSeconds { get; init; } = 8m * 60m;
    /// <summary>Time to respond once a wasp arrives (Leah: 1 minute).</summary>
    public decimal WaspCountdownSeconds { get; init; } = 60m;
    /// <summary>Chance a thrown shoe hits (Leah: 40% miss).</summary>
    public double ShoeHitChance { get; init; } = 0.60;
    /// <summary>A raid takes this many seconds' worth of honey production (Leah: 3 minutes).</summary>
    public decimal RaidHoneySeconds { get; init; } = 3m * 60m;
    // Cut in stage 6 (spec 014): raids take only honey, never bees.
    // /// <summary>Share of the bees that fly off in a raid (Leah: 15%).</summary>
    // public decimal RaidBeeShare { get; init; } = 0.15m;
    /// <summary>Share of stored honey a bribe costs (Leah: 25%).</summary>
    public decimal BribeHoneyShare { get; init; } = 0.25m;
    /// <summary>No click or key for this long and the player counts as idle: no wasps.</summary>
    public decimal IdleSeconds { get; init; } = 5m * 60m;

    // --- Upgrades (sold in the Beekeeper's Shop) -----------------------------
    public decimal BiggerCombs1Multiplier { get; init; } = 1.5m;   // Leah: +50%
    public decimal BiggerCombs2Multiplier { get; init; } = 2m;     // Leah: +100%
    public decimal BetterWaxCatcherBonus { get; init; } = 1.5m;    // Leah: 50% more effective
    public decimal StrongerCandlesBonus { get; init; } = 1.5m;

    /// <summary>In the order the Shop lists them.</summary>
    public IReadOnlyList<BeekeeperUpgrade> Upgrades { get; init; } = new[]
    {
        new BeekeeperUpgrade(BeekeeperUpgrades.BiggerCombs1, 300m, 100m, 0m, BeekeeperUpgrades.NeedsWorkbench),
        new BeekeeperUpgrade(BeekeeperUpgrades.BiggerCombs2, 800m, 250m, 2m, BeekeeperUpgrades.BiggerCombs1),
        new BeekeeperUpgrade(BeekeeperUpgrades.BetterWaxCatcher, 400m, 0m, 1m, BeekeeperUpgrades.NeedsWaxCatcher),
        new BeekeeperUpgrade(BeekeeperUpgrades.StrongerCandles, 200m, 50m, 2m, BeekeeperUpgrades.NeedsRepellent),
        // Stage 3 (spec 011)
        new BeekeeperUpgrade(BeekeeperUpgrades.Practice, 600m, 50m, 0m, BeekeeperUpgrades.NeedsVacuum),
        new BeekeeperUpgrade(BeekeeperUpgrades.MorePractice, 2_500m, 200m, 3m, BeekeeperUpgrades.Practice),
        new BeekeeperUpgrade(BeekeeperUpgrades.Smoker, 500m, 50m, 0m, BeekeeperUpgrades.NeedsVacuum),
    };

    // --- Stage 3: catching and the Smoker (spec 011) -------------------------
    public decimal PracticeMultiplier { get; init; } = 1.5m;       // +50% (placeholder)
    public decimal MorePracticeMultiplier { get; init; } = 2m;     // +100% (placeholder)
    /// <summary>Clicks to fill the Smoker's calm meter (Leah: 15).</summary>
    public int CalmMeterClicks { get; init; } = 15;
    /// <summary>How long the bees stay calm after a puff (Leah: 2 minutes).</summary>
    public decimal CalmSeconds { get; init; } = 2m * 60m;
    /// <summary>Calm time a Catch Bee click adds back while the bees are calm, up to
    /// <see cref="CalmSeconds"/> (Leah: a click refills it fully; lower this to soften).</summary>
    public decimal CalmCatchRefillSeconds { get; init; } = 2m * 60m;
    /// <summary>Honey while calm (Leah: ×2).</summary>
    public decimal CalmHoneyMultiplier { get; init; } = 2m;

    // ===== Stage 4 (spec 012): the Garden. All placeholders, accepted by Leah 2026-11-07.

    /// <summary>In the order the Hippies hand out seeds: the Nth seed planted grows the Nth plant.
    /// New plants are new entries here plus their effect in the engine (FR-302).</summary>
    public IReadOnlyList<BeekeeperPlant> Plants { get; init; } = new[]
    {
        // Stage 6 (spec 014): foraging 3 pollen a minute (beats the queen's 2); guarding +25% honey.
        new BeekeeperPlant(BeekeeperPlants.Wildflowers, 5, BeekeeperSpecialties.Foraging, 3m),
        new BeekeeperPlant(BeekeeperPlants.Bramble, 10, BeekeeperSpecialties.Guarding, 1.25m),
        // Cut in stage 6 (spec 014): forager and guard bees a minute.
        // new BeekeeperPlant(BeekeeperPlants.Wildflowers, 5, BeekeeperBees.Forager, 1m),
        // new BeekeeperPlant(BeekeeperPlants.Bramble, 10, BeekeeperBees.Guard, 1m),
    };

    /// <summary>How long a planted seed takes to sprout (Leah: 10 minutes).</summary>
    public decimal GrowSeconds { get; init; } = 10m * 60m;
    // Cut in stage 6 (spec 014): pollen comes from the foraging specialty (the plant's Strength).
    // /// <summary>Every this many forager bees bring back 1 pollen a minute.</summary>
    // public decimal ForagersPerPollenPerMinute { get; init; } = 10m;
    public decimal BeeBreadPollen { get; init; } = 10m;
    public decimal BeeBreadHoney { get; init; } = 10m;
    public decimal WoodenHiveWax { get; init; } = 200m;
    public decimal WoodenHiveBeeBread { get; init; } = 10m;
    /// <summary>Honey from every honeybee in a wooden hive (+25%).</summary>
    public decimal WoodenHiveHoneyMultiplier { get; init; } = 1.25m;

    // ===== Stage 5 (spec 013): the queen, the brood and the trade agreement. All placeholders.

    /// <summary>Bees the queen raises a minute, per hive step: index 0 is the skep (no room
    /// for brood), 1 the wooden hive. Later hives (the meadow apiary) add entries here.</summary>
    public IReadOnlyList<decimal> QueenBeesPerMinute { get; init; } = new[] { 0m, 20m };
    /// <summary>Bees raised for every 1 bee bread the brood eats.</summary>
    public decimal BeesPerBeeBread { get; init; } = 100m;
    /// <summary>The slice of the hive a click brings in is never more than this many times
    /// the bees the tool catches (after Practice).</summary>
    public decimal SliceCapMultiple { get; init; } = 10m;
    /// <summary>The bear offers the trade agreement on this trade (Sell All counts as one).</summary>
    public long AgreementTrades { get; init; } = 100;
    /// <summary>Honey that doesn't fit, per Beebit, under the agreement (Leah: half price).</summary>
    public decimal AgreementHoneyPerBeebit { get; init; } = 20m;

    // ===== Stage 6 (spec 014): specialties and the wasp emissary. All placeholders.
    // (The specialties' strengths are on the plants above.)

    /// <summary>On this bribe in total the log hints that the wasp is taking notes.</summary>
    public long BribesForHint { get; init; } = 3;
    /// <summary>On this bribe in total the wasp nest sends its emissary: raids end for good.</summary>
    public long BribesForEmissary { get; init; } = 5;
    /// <summary>Honey the wasps want for 1 paper.</summary>
    public decimal HoneyPerPaper { get; init; } = 50m;

    public static BeekeeperConfig Default { get; } = new();
}
