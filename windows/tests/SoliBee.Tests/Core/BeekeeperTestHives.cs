using SoliBee.Core.Models;

namespace SoliBee.Tests.Core;

/// <summary>
/// Shared hives for the Beekeeper tests (stage 7.5, spec 016). Since stage 7.5 the combs make the
/// honey (0.2 a second each), and only once the first bee has been caught, so a test that wants
/// honey starts a hive with combs instead of giving it bees.
/// </summary>
internal static class BeekeeperTestHives
{
    /// <summary>The older tests compare exact honey with thousands of free bees about, so the shared
    /// configs have the free bees' honey bonus off here. The bonus's
    /// own tests build their own config.</summary>
    [System.Runtime.CompilerServices.ModuleInitializer]
    internal static void TurnOffFreeBeeBonusInTheSharedDefault() => BeekeeperConfig.StartingFreeBeeHoneyBonusPer100 = 0m;

    /// <summary>A hive whose first bee has been caught, with <paramref name="combs"/> combs (the
    /// starter counted) and no free bees. 5 combs make 1 honey a second.</summary>
    public static BeekeeperState Started(int combs = 1) => new() { HoneyRevealed = true, Combs = combs };

    /// <summary>Combs for <paramref name="honeyPerSecond"/> honey a second at the default 0.2 a comb.</summary>
    public static int CombsFor(decimal honeyPerSecond) => (int)(honeyPerSecond / BeekeeperConfig.Default.HoneyPerCombPerSecond);

    /// <summary>A config whose caps never get in the way.</summary>
    public static BeekeeperConfig BigCaps() => new() { StartingHoneyCap = 1_000_000_000m, StartingWaxCap = 1_000_000_000m };

    /// <summary>Stage 9: a config with no bloom calendar, for the older rule tests (a hive with plants
    /// would otherwise start on crocus, which doubles nursing's bonus).</summary>
    public static BeekeeperConfig NoBlooms() => new() { Blooms = System.Array.Empty<BeekeeperBloom>() };
}
