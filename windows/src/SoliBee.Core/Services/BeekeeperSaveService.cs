using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using SoliBee.Core.Models;

namespace SoliBee.Core.Services;

/// <summary>
/// Loads and saves a Beekeeper game (spec FR-004). Writes go through <see cref="AtomicFile"/>
/// so a crash mid-save can't leave half a file. A missing, damaged or too-new save never
/// crashes the game: <see cref="Load(string)"/> returns null (start a new game), and a file
/// that couldn't be read is moved aside rather than silently overwritten by the next autosave.
/// </summary>
public static class BeekeeperSaveService
{
    /// <summary>7 = stage 7. Older files still load: the new fields start at zero, and the engine
    /// turns an older file's seeds into named seeds and a bed.</summary>
    public const int CurrentVersion = 7;

    /// <summary>The story log keeps this many lines, newest first.</summary>
    public const int MaxLogEntries = 50;

    public static string SaveFilePath => Path.Combine(AppPaths.DataDirectory, "beekeeper.json");

    public static BeekeeperState? Load() => Load(SaveFilePath);

    public static bool Save(BeekeeperState state, DateTime utcNow) => Save(state, SaveFilePath, utcNow);

    public static BeekeeperState? Load(string path)
    {
        string json;
        try
        {
            if (!File.Exists(path)) return null;
            json = File.ReadAllText(path);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return null;
        }

        BeekeeperState? state = null;
        try
        {
            state = JsonSerializer.Deserialize<BeekeeperState>(json);
        }
        catch (JsonException)
        {
            // fall through: treated as unreadable below
        }

        if (state is null || state.Version > CurrentVersion || !LooksSane(state))
        {
            MoveAside(path);
            return null;
        }
        return state;
    }

    public static bool Save(BeekeeperState state, string path, DateTime utcNow)
    {
        try
        {
            state.Version = CurrentVersion;
            state.SavedAtUtc = utcNow;
            if (state.Log.Count > MaxLogEntries)
                state.Log = state.Log.Take(MaxLogEntries).ToList(); // newest first, so keep the front

            AtomicFile.WriteAllText(path, JsonSerializer.Serialize(state));
            return true;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return false;
        }
    }

    /// <summary>
    /// Seconds between the save and now. Zero when the save has no time. Negative when the
    /// clock went backwards; the engine credits nothing for a negative gap.
    /// </summary>
    public static decimal SecondsSinceSaved(BeekeeperState state, DateTime utcNow)
    {
        if (state.SavedAtUtc is not { } saved) return 0m;
        return (decimal)(utcNow - saved).TotalSeconds;
    }

    // Guards against a hand-edited or damaged file that parses but makes no sense.
    private static bool LooksSane(BeekeeperState s)
    {
        int maxTool = BeekeeperConfig.Default.Tools.Count;
        return s.Bees >= 0m && s.Honey >= 0m && s.Wax >= 0m && s.WaxProgress >= 0m && s.Beebits >= 0m
            && s.Combs >= 0 && s.Trades >= 0
            && s.ToolLevel >= 0 && s.ToolLevel <= maxTool
            && s.Log is not null
            && s.BeeswaxCandles >= 0m && s.RepellentCandles >= 0m && s.CandlesCrafted >= 0
            && s.Sage >= 0m && s.HippieTrades >= 0
            && s.RepellentSecondsLeft >= 0m && s.NextWaspInSeconds >= 0m
            && s.Upgrades is not null
            && s.CalmMeter >= 0 && s.CalmSecondsLeft >= 0m
            && s.SeedsGiven >= 0 && s.Seeds >= 0 && s.SeedsPlanted >= 0 && s.GrowSecondsLeft >= 0m
            && s.Plants is not null
            && s.ForagerBees >= 0m && s.GuardBees >= 0m && s.Pollen >= 0m && s.BeeBread >= 0m
            && s.AgreementHoneyProgress >= 0m
            && s.BribesTotal >= 0 && s.WaspTrades >= 0 && s.Paper >= 0m
            // Stage 7: no negative amounts or times. (Too many beds and unknown plant ids are
            // trimmed by the engine instead, so one odd entry never costs the whole hive.)
            && s.SeedsInHand is not null && s.SeedsGivenIds is not null && s.Beds is not null
            && s.Beds.All(b => b is not null && b.SecondsLeft >= 0m)
            && s.Propolis >= 0m && s.BeeBoostCandles >= 0m && s.SagePropolisCandles >= 0m
            && s.BeeBoostSecondsLeft >= 0m && s.SagePropolisSecondsLeft >= 0m;
    }

    private static void MoveAside(string path)
    {
        try { File.Move(path, path + ".unreadable", overwrite: true); }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { }
    }
}
