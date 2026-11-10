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
    /// <summary>8 = stage 7.5 (spec 016, FR-714). A file older than this is not loaded: it goes the
    /// same way as a too-new or damaged one (moved aside, a new game starts), with no conversion.</summary>
    public const int CurrentVersion = 8;
    // Cut in stage 7.5 (spec 016): older files loaded, new fields at zero, older seeds converted.
    // public const int CurrentVersion = 7;

    /// <summary>The story log keeps this many lines, newest first.</summary>
    public const int MaxLogEntries = 50;

    public static string SaveFilePath => Path.Combine(AppPaths.DataDirectory, "beekeeper.json");

    public static BeekeeperState? Load() => Load(SaveFilePath);

    public static bool Save(BeekeeperState state, DateTime utcNow) => Save(state, SaveFilePath, utcNow);

    public static BeekeeperState? Load(string path) => Load(path, out _);

    /// <summary>As <see cref="Load(string)"/>, but <paramref name="keepFile"/> is true when a file
    /// exists that could not be read or moved aside (locked by another program, say). The caller
    /// must then not save over it: starting a new game and autosaving would destroy the real hive.</summary>
    public static BeekeeperState? Load(string path, out bool keepFile)
    {
        keepFile = false;
        string json;
        try
        {
            if (!File.Exists(path)) return null;
            json = ReadWithRetries(path);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            keepFile = true;
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

        // Stage 7.5 (spec 016): an older version is set aside like an unreadable file.
        if (state is null || state.Version != CurrentVersion || !LooksSane(state))
        // Cut in stage 7.5: if (state is null || state.Version > CurrentVersion || !LooksSane(state))
        {
            if (!MoveAside(path)) keepFile = true;
            return null;
        }
        state.Log.RemoveAll(entry => entry is null || entry.Key is null);   // the story log reads every entry's key
        return state;
    }

    // A scanner or backup tool may hold the file for a moment at launch: try a few times.
    private static string ReadWithRetries(string path)
    {
        for (int attempt = 0; ; attempt++)
        {
            try { return File.ReadAllText(path); }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                if (attempt >= 4) throw;
                System.Threading.Thread.Sleep(150);
            }
        }
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

    /// <summary>No real hive holds this much of anything. Refusing bigger numbers leaves the maths
    /// room to work without overflowing.</summary>
    private const decimal MaxAmount = 1e24m;

    /// <summary>Combs cost so much by the 300th that no real hive gets near this.</summary>
    private const int MaxCombs = 100_000;

    // Guards against a hand-edited or damaged file that parses but makes no sense.
    private static bool LooksSane(BeekeeperState s)
    {
        int maxTool = BeekeeperConfig.Default.Tools.Count;
        // Cut in stage 7.5 (spec 016): WaxProgress, GrowSecondsLeft, ForagerBees, GuardBees and
        // AgreementHoneyProgress (no longer saved).
        decimal[] amounts =
        {
            s.Honey, s.Wax, s.Beebits, s.BeeswaxCandles, s.RepellentCandles, s.Sage,
            s.RepellentSecondsLeft, s.NextWaspInSeconds, s.WaspCountdown,
            s.Pollen, s.BeeBread, s.Paper,
            s.Propolis, s.BeeBoostCandles, s.SagePropolisCandles,
        };
        return amounts.All(v => v <= MaxAmount) && s.Combs <= MaxCombs
            && s.Bees >= 0m && s.Bees <= BeekeeperConfig.Default.MaxBees && s.Honey >= 0m && s.Wax >= 0m && s.Beebits >= 0m
            // Stage 7.5: the starter comb is always there; capacity levels are never negative.
            && s.Combs >= 1 && s.HoneySupers >= 0 && s.WaxTrays >= 0
            && s.HoneySupers <= MaxCombs && s.WaxTrays <= MaxCombs
            && s.Trades >= 0
            && s.ToolLevel >= 0 && s.ToolLevel <= maxTool
            && s.Log is not null
            && s.BeeswaxCandles >= 0m && s.RepellentCandles >= 0m && s.CandlesCrafted >= 0
            && s.Sage >= 0m && s.HippieTrades >= 0
            && s.RepellentSecondsLeft >= 0m && s.NextWaspInSeconds >= 0m
            && s.Upgrades is not null
            && s.CalmMeter >= 0 && s.CalmSecondsLeft >= 0m
            && s.Plants is not null
            && s.Pollen >= 0m && s.BeeBread >= 0m
            && s.BribesTotal >= 0 && s.WaspTrades >= 0 && s.Paper >= 0m
            // Stage 7: no negative amounts or times. (Too many beds and unknown plant ids are
            // trimmed by the engine instead, so one odd entry never costs the whole hive.)
            && s.SeedsInHand is not null && s.SeedsGivenIds is not null && s.Beds is not null
            && s.Beds.All(b => b is not null && b.SecondsLeft >= 0m)
            && s.Propolis >= 0m && s.BeeBoostCandles >= 0m && s.SagePropolisCandles >= 0m
            && s.BeeBoostSecondsLeft >= 0m && s.SagePropolisSecondsLeft >= 0m;
    }

    // Every damaged file keeps its own backup: .unreadable, then .unreadable2, .unreadable3…
    private static bool MoveAside(string path)
    {
        string target = path + ".unreadable";
        for (int n = 2; File.Exists(target); n++) target = path + ".unreadable" + n;
        try { File.Move(path, target); return true; }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { return false; }
    }
}
