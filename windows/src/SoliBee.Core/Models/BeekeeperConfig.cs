using System.Collections.Generic;

namespace SoliBee.Core.Models;

/// <summary>A tool the player can buy to catch more bees per click.</summary>
public sealed record BeekeeperTool(string Id, decimal Cost, int BeesPerClick);

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
    };

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

    public static BeekeeperConfig Default { get; } = new();
}
