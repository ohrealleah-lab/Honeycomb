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
/// <remarks>Since stage 7 (spec 015) a price can also be paper and propolis; both default to 0, so older entries are unchanged.</remarks>
public sealed record BeekeeperUpgrade(string Id, decimal Beebits, decimal Wax, decimal Sage, string Needs,
    decimal Paper = 0m, decimal Propolis = 0m);

/// <summary>A plant a seed grows into. <see cref="SeedAtTrade"/> is the Hippie trade that gives its seed;
/// <see cref="Specialty"/> is the job it gives the hive (<see cref="BeekeeperSpecialties"/>) and
/// <see cref="Strength"/> how much: pollen a minute for foraging, a honey multiplier for guarding.
/// Several plants of one specialty add up (pollen) or multiply (honey), so new plants are just
/// new entries (spec 014, FR-502). Since stage 7 (spec 015, FR-602) a plant also says who gives its
/// seed (<see cref="Giver"/>: the Hippies or the wasps, at <see cref="SeedAtTrade"/> of their trades)
/// and how long it takes to sprout. <see cref="Strength"/>: pollen a minute (foraging), a honey
/// multiplier (guarding), a laying multiplier (nursing) or propolis a minute (resin).</summary>
public sealed record BeekeeperPlant(string Id, long SeedAtTrade, string Specialty, decimal Strength,
    decimal GrowSeconds = 600m, string Giver = BeekeeperGivers.Hippies);
// Cut in stage 6 (spec 014): plants attracted counts of bees.
// public sealed record BeekeeperPlant(string Id, long SeedAtTrade, string Bee, decimal BeesPerMinute);

public static class BeekeeperPlants
{
    public const string Wildflowers = "wildflowers";
    public const string Bramble = "bramble";
    // Stage 7 (spec 015)
    public const string Willow = "willow";
    public const string Poplar = "poplar";
    public const string Clover = "clover";
}

/// <summary>Who hands out a plant's seed (spec 015).</summary>
public static class BeekeeperGivers
{
    public const string Hippies = "hippies";
    public const string Wasps = "wasps";
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
    /// <summary>"The hive feels safe": the combs make more honey (since stage 7.5; before, every honeybee did).</summary>
    public const string Guarding = "guarding";
    /// <summary>Stage 7: the queen lays faster (a multiplier on her rate).</summary>
    public const string Nursing = "nursing";
    /// <summary>Stage 7: the bees gather propolis (a steady amount a minute).</summary>
    public const string Resin = "resin";
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

    // Stage 7 (spec 015)
    public const string Notebook = "notebook";
    public const string ThirdBed = "third_bed";
    public const string PropolisSeal = "propolis_seal";

    public const string NeedsPaper = "paper_revealed";
    public const string NeedsGardenAndPaper = "garden_and_paper";
    public const string NeedsPropolis = "propolis_revealed";

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
    // Cut in stage 7.5 (spec 016): bees made the honey and wax followed it.
    // public decimal HoneyPerBeePerSecond { get; init; } = 0.01m;
    // public decimal HoneyPerWax { get; init; } = 50m;
    /// <summary>Stage 7.5 (spec 016): the Wax-Catcher multiplies the wax rate by this (×2);
    /// the Better Wax-Catcher by <see cref="BetterWaxCatcherBonus"/> on top (×3).</summary>
    public int WaxCatcherMultiplier { get; init; } = 2;

    // ===== Stage 7.5 (spec 016): combs make the honey, free bees make the wax. All placeholders (Bee).
    /// <summary>Honey a second from each comb, however many bees live in it.</summary>
    public decimal HoneyPerCombPerSecond { get; init; } = 0.2m;
    /// <summary>The tiny wax drip that runs from the start of the game, bees or not.</summary>
    public decimal WaxBasePerSecond { get; init; } = 0.005m;
    /// <summary>Wax a second from each free bee (bees not living in a comb).</summary>
    public decimal WaxPerFreeBeePerSecond { get; init; } = 0.0001m;
    /// <summary>Wax first seen at this much (whole wax): the Wax row comes.</summary>
    public decimal WaxRevealWax { get; init; } = 1m;

    // --- Honey and wax caps (combs). The starting caps include the starter comb.
    public decimal StartingHoneyCap { get; init; } = 200m;
    public decimal HoneyCapPerComb { get; init; } = 300m;
    /// <summary>Small on purpose: a price above it is a wall (spec 016).</summary>
    public decimal StartingWaxCap { get; init; } = 20m;
    public decimal WaxCapPerComb { get; init; } = 2m;

    // --- Comb prices: floor(base × growth^n), n = combs bought (the starter doesn't count).
    public decimal CombBaseBeeCost { get; init; } = 20m;
    public decimal CombBeeCostGrowth { get; init; } = 1.4m;
    public decimal CombBaseWaxCost { get; init; } = 10m;
    public decimal CombCostGrowth { get; init; } = 1.25m;

    // --- Capacity upgrades: bought again and again, for Beebits only, at The Workbench.
    public decimal HoneySuperCapacity { get; init; } = 1_000m;
    public decimal HoneySuperBaseCost { get; init; } = 75m;
    public decimal HoneySuperCostGrowth { get; init; } = 1.5m;
    public decimal WaxTrayCapacity { get; init; } = 8m;
    public decimal WaxTrayBaseCost { get; init; } = 100m;
    public decimal WaxTrayCostGrowth { get; init; } = 1.6m;

    // Cut in stage 7.5 (spec 016): honey storage only, no starter comb.
    // public decimal StartingStorage { get; init; } = 200m;   // approved by Leah 2026-11-06 for the first build; revisit after play-testing
    // public decimal StoragePerComb { get; init; } = 200m;    // approved by Leah 2026-11-06 for the first build; revisit after play-testing
    // public decimal CombBaseWaxCost { get; init; } = 50m;

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

    /// <summary>The most bees a hive can hold. Keeps (bees × 3 days) inside what a decimal can
    /// hold, so time away can never overflow; a save above it is refused as damaged.</summary>
    public decimal MaxBees { get; init; } = 1e20m;

    public decimal WaxCatcherCost { get; init; } = 150m;

    // --- Trading -------------------------------------------------------------
    public decimal HoneyPerBeebit { get; init; } = 10m;
    /// <summary>Stage 7.5 (spec 016): honey per Beebit under the bear's trade agreement (a better rate).</summary>
    public decimal BetterHoneyPerBeebit { get; init; } = 8m;
    public IReadOnlyList<string> BearNames { get; init; } = new[]
    {
        "Barnaby", "Billy", "Berenstein", "Bruno", "Baloo", "Buster", "Bartholomew",
    };

    // --- When things appear --------------------------------------------------
    public decimal BearRevealHoney { get; init; } = 10m;
    public decimal ShopRevealBeebits { get; init; } = 15m;
    /// <summary>Stage 7.5 (spec 016): was 50. Comes before a comb can be paid for.</summary>
    public decimal CombsRevealWax { get; init; } = 5m;

    // --- Time away (offline earnings) ---------------------------------------
    /// <summary>Longest stretch that is paid: 3 days.</summary>
    public decimal OfflineCapSeconds { get; init; } = 3m * 24m * 60m * 60m;
    /// <summary>Share of normal production earned while away (Leah confirmed 100%).
    /// Note: below 1 this scales the whole away stretch, so garden beds and the sage-propolis
    /// candle also run slower while away, not only earnings. Fine at 1; fix before tuning below it
    /// (review 2026-11-08, left as is on purpose).</summary>
    public decimal OfflineRate { get; init; } = 1m;
    /// <summary>A gap longer than this many seconds counts as time away.</summary>
    public decimal AwayThresholdSeconds { get; init; } = 2m;

    // ===== Stage 2 (spec 010). Everything below is a placeholder to be tuned later
    // (Leah, 2026-11-07), except where marked as Leah's number.

    // --- The Workbench and candles ------------------------------------------
    /// <summary>The Workbench opens with this many combs, the starter counted (stage 7.5, spec 016:
    /// was 2 built; now 3 counting the starter, so it opens at the same point).</summary>
    public int WorkbenchCombs { get; init; } = 3;
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
    // Stage 7.5 (spec 016): Bigger Combs and the Propolis Seal grow both caps, honey and wax.
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
        // Stage 7 (spec 015): paper and propolis join the prices (all placeholders).
        new BeekeeperUpgrade(BeekeeperUpgrades.Notebook, 100m, 0m, 0m, BeekeeperUpgrades.NeedsPaper, Paper: 20m),
        // Off the Shop (Leah, 2026-11-10): extra beds become a technology bought after a swarm (stage 11, not built yet).
        // A save that already owns the Third Bed keeps its extra bed.
        // new BeekeeperUpgrade(BeekeeperUpgrades.ThirdBed, 1_500m, 200m, 0m, BeekeeperUpgrades.NeedsGardenAndPaper, Paper: 10m),
        new BeekeeperUpgrade(BeekeeperUpgrades.PropolisSeal, 1_000m, 150m, 0m, BeekeeperUpgrades.NeedsPropolis, Propolis: 30m),
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

    /// <summary>Every plant: who gives its seed and when, how long it takes to sprout, what it does.
    /// New plants are new entries here plus their effect in the engine (FR-302). Since stage 7 seeds
    /// are known by name and the player picks which to plant; the order here is the order of
    /// display, and of the old "Nth seed is the Nth plant" rule that older saves are converted
    /// with (wildflowers, then bramble, must stay first).</summary>
    public IReadOnlyList<BeekeeperPlant> Plants { get; init; } = new[]
    {
        // Stage 6 (spec 014): foraging 3 pollen a minute (beats the queen's 2); guarding +25% honey.
        new BeekeeperPlant(BeekeeperPlants.Wildflowers, 5, BeekeeperSpecialties.Foraging, 3m, 10m * 60m),
        // Seed trades spaced from 5 to 100 (Leah, 2026-11-10; placeholders): 5, 30, 60, 100. One seed per plant, once.
        // (Was 5, 10, 20, 35.)
        new BeekeeperPlant(BeekeeperPlants.Bramble, 30, BeekeeperSpecialties.Guarding, 1.25m, 10m * 60m),
        // Stage 7 (spec 015), placeholders, each slower than the last:
        // the willow (1 hour): nursing, the queen lays 50% faster;
        new BeekeeperPlant(BeekeeperPlants.Willow, 60, BeekeeperSpecialties.Nursing, 1.5m, 60m * 60m),
        // the poplar (6 hours; seed from the wasps' 10th trade): resin, 1 propolis a minute;
        new BeekeeperPlant(BeekeeperPlants.Poplar, 10, BeekeeperSpecialties.Resin, 1m, 6m * 3600m, BeekeeperGivers.Wasps),
        // clover (12 hours, overnight): 3 more pollen a minute.
        new BeekeeperPlant(BeekeeperPlants.Clover, 100, BeekeeperSpecialties.Foraging, 3m, 12m * 3600m),
        // Cut in stage 6 (spec 014): forager and guard bees a minute.
        // new BeekeeperPlant(BeekeeperPlants.Wildflowers, 5, BeekeeperBees.Forager, 1m),
        // new BeekeeperPlant(BeekeeperPlants.Bramble, 10, BeekeeperBees.Guard, 1m),
    };

    // Cut in stage 7 (spec 015): every plant has its own grow time (on the plant).
    // /// <summary>How long a planted seed takes to sprout (Leah: 10 minutes).</summary>
    // public decimal GrowSeconds { get; init; } = 10m * 60m;
    // Cut in stage 6 (spec 014): pollen comes from the foraging specialty (the plant's Strength).
    // /// <summary>Every this many forager bees bring back 1 pollen a minute.</summary>
    // public decimal ForagersPerPollenPerMinute { get; init; } = 10m;
    public decimal BeeBreadPollen { get; init; } = 10m;
    public decimal BeeBreadHoney { get; init; } = 10m;
    public decimal WoodenHiveWax { get; init; } = 200m;
    public decimal WoodenHiveBeeBread { get; init; } = 10m;
    /// <summary>Honey from the combs in a wooden hive (+25%; before stage 7.5, from every honeybee).</summary>
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
    /// <summary>The bear offers the trade agreement on this trade (Sell All counts as one).
    /// Stage 7.5 (spec 016): was 100; the agreement is now a better selling rate.</summary>
    public long AgreementTrades { get; init; } = 25;
    // Cut in stage 7.5 (spec 016): the bear no longer takes the overflow; see BetterHoneyPerBeebit.
    // /// <summary>Honey that doesn't fit, per Beebit, under the agreement (Leah: half price).</summary>
    // public decimal AgreementHoneyPerBeebit { get; init; } = 20m;

    // ===== Stage 6 (spec 014): specialties and the wasp emissary. All placeholders.
    // (The specialties' strengths are on the plants above.)

    /// <summary>On this bribe in total the log hints that the wasp is taking notes.</summary>
    public long BribesForHint { get; init; } = 3;
    /// <summary>On this bribe in total the wasp nest sends its emissary: raids end for good.</summary>
    public long BribesForEmissary { get; init; } = 5;
    /// <summary>Honey the wasps want for 1 paper.</summary>
    public decimal HoneyPerPaper { get; init; } = 50m;

    // ===== Stage 7 (spec 015): seeds, the poplar and propolis. All placeholders.

    /// <summary>Garden beds at the start: two seeds can grow at once. The Third Bed upgrade adds one.</summary>
    public int StartingBeds { get; init; } = 1;   // was 2 (Leah, 2026-11-10)
    public int ThirdBedBeds { get; init; } = 1;
    /// <summary>The Propolis Seal multiplies storage by this (+25%), on top of Bigger Combs
    /// (honey and, since stage 7.5, wax).</summary>
    public decimal PropolisSealStorageMultiplier { get; init; } = 1.25m;

    // --- The bee-boost candle (wax and propolis): live play only, like calm.
    public decimal BeeBoostCandleWax { get; init; } = 20m;
    public decimal BeeBoostCandlePropolis { get; init; } = 2m;
    /// <summary>Honey while a bee-boost candle burns (+20%).</summary>
    public decimal BeeBoostHoneyMultiplier { get; init; } = 1.2m;
    public decimal BeeBoostBurnSeconds { get; init; } = 10m * 60m;
    public decimal BeeBoostCapSeconds { get; init; } = 60m * 60m;

    // --- The sage-propolis candle (wax, sage and propolis): burns while the app is closed too.
    public decimal SagePropolisCandleWax { get; init; } = 20m;
    public decimal SagePropolisCandleSage { get; init; } = 1m;
    public decimal SagePropolisCandlePropolis { get; init; } = 5m;
    /// <summary>Honey while a sage-propolis candle burns (+10%).</summary>
    public decimal SagePropolisHoneyMultiplier { get; init; } = 1.1m;
    public decimal SagePropolisBurnSeconds { get; init; } = 4m * 3600m;
    public decimal SagePropolisCapSeconds { get; init; } = 24m * 3600m;

    public static BeekeeperConfig Default { get; } = new();
}
