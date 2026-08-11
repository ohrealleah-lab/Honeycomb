using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;

namespace SoliBee.Core.Services;

// Runtime companion to the generated BannerId enum (SoliBee.Core/Models/BannerId.cs)
// — loads HoneycombBannerCatalog.json (also generated, from the same spreadsheet
// run) and decides what text should actually show when a given banner fires.
// Mirrors the Swift port's BannerCatalog (shared/Honeycomb/Models/BannerCatalog.swift).
//
// Reads the catalog as a plain file next to the executable (Assets/, copied via
// the <Content> item in SoliBee.Desktop.csproj — same treatment as the WAV files
// SoundService plays) rather than through Avalonia's AssetLoader/avares:// — Core
// has no Avalonia dependency (matches the whole point of the Core/Desktop split),
// and the trigger logic that needs to fire banners (HoneycombViewModel) lives here
// in Core, not in Desktop.
//
// This only knows about *content*: which messages exist for an id, and
// whether/how the 20% gate + fallback applies. It has no opinion on *when* a
// trigger's condition becomes true (that's each call site's own gameplay
// logic) or on achievement/milestone "fire exactly once" guards (the exact
// crossing condition differs per milestone — total wins vs. first launch —
// so that's the caller's responsibility too, not something this can know).
public class BannerDefinition
{
    public string Id { get; set; } = "";
    public string Category { get; set; } = "";
    public string Trigger { get; set; } = "";
    public string Type { get; set; } = "";       // "ambiance" | "repeatableFlavor" | "achievement"
    public string Location { get; set; } = "";   // "toast" | "loading" | "winBanner" | "loseBanner" | "rulesBanner"
    public bool Gated { get; set; }
    public double? GateChance { get; set; }
    public string? Fallback { get; set; }
    public List<string> Messages { get; set; } = new();
    // Same length/order as Messages, one Spanish translation per English
    // message — "" for a message not yet translated. Fallback is NOT
    // translated (see tools/generate_banner_catalog.py) — it stays English
    // regardless of language.
    public List<string> MessagesEs { get; set; } = new();
}

public enum BannerFireKind { Message, Fallback, None }

// What BannerCatalog.Fire(...) decided should actually show.
public readonly struct BannerFireResult
{
    public BannerFireKind Kind { get; }
    public string? Text { get; }

    private BannerFireResult(BannerFireKind kind, string? text)
    {
        Kind = kind;
        Text = text;
    }

    public static BannerFireResult Message(string text) => new(BannerFireKind.Message, text);
    public static BannerFireResult Fallback(string text) => new(BannerFireKind.Fallback, text);
    public static readonly BannerFireResult None = new(BannerFireKind.None, null);
}

public static class BannerCatalog
{
    // Sentinel a Fallback string can equal for rulesBanner-location entries —
    // there's no single literal fallback text for those (it depends on which
    // rule is active), so the catalog can't bake it in; the caller
    // substitutes the rule's own existing display name instead.
    public const string RuleNameSentinel = "$RULE_NAME";

    private static readonly Random _random = new();
    private static Dictionary<BannerId, BannerDefinition>? _entries;

    private static Dictionary<BannerId, BannerDefinition> Entries => _entries ??= Load();

    private static Dictionary<BannerId, BannerDefinition> Load()
    {
        var result = new Dictionary<BannerId, BannerDefinition>();
        try
        {
            var path = Path.Combine(AppContext.BaseDirectory, "Assets", "HoneycombBannerCatalog.json");
            if (!File.Exists(path)) return result;

            var json = File.ReadAllText(path);
            var doc = JsonSerializer.Deserialize<CatalogDocument>(json, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            });
            if (doc?.Banners == null) return result;

            foreach (var entry in doc.Banners)
            {
                BannerId id;
                try { id = BannerIdExtensions.Parse(entry.Id); }
                catch (KeyNotFoundException)
                {
                    // Catalog has an id with no matching BannerId case — regenerate via
                    // tools/generate_banner_catalog.py. Skip rather than crash.
                    continue;
                }
                result[id] = entry;
            }
        }
        catch
        {
            // Missing/corrupt bundled catalog — check the <Content Include="Assets/
            // HoneycombBannerCatalog.json"> item in SoliBee.Desktop.csproj and that
            // the file actually sits in Assets/.
        }
        return result;
    }

    private class CatalogDocument
    {
        [JsonPropertyName("banners")]
        public List<BannerDefinition>? Banners { get; set; }
    }

    public static BannerDefinition? Definition(BannerId id) =>
        Entries.TryGetValue(id, out var def) ? def : null;

    // Decides what should show for `id` firing right now. `tokens` fills in
    // any `{PlaceholderName}` markers in the chosen text (e.g.
    // {"OpponentName": "Baby Bee"}, {"ComboCount": "4"}).
    // Decides what should show for `id` firing right now. With Honey Mode off, every
    // non-Achievement banner is either forced to its plain fallback (gated entries —
    // e.g. Combo x4+ always reads "HIVE MIND x4!" instead of occasionally rolling
    // flavor) or suppressed entirely (ungated entries — Loading, Idle/Ambiance, and
    // most Gameplay/Rule-Specific toasts have no plain-text equivalent to fall back
    // to). Every Fire() call site already discards a Fallback's own text in favor of
    // its own existingDefaultText (see BannerCatalogText in each ViewModel), so
    // returning Fallback("") here is safe — the actual string is never read. Reads
    // SettingsService.LoadOptions() fresh each call (no caching, same as every other
    // settings read in this codebase) rather than a pushed/cached flag, since
    // ViewModels don't hold an AppCoordinator reference. Mirrors the Swift port's
    // BannerCatalog.fire/honeyModeEnabled.
    public static BannerFireResult Fire(BannerId id, Dictionary<string, string>? tokens = null)
    {
        if (!Entries.TryGetValue(id, out var def)) return BannerFireResult.None;

        if (def.Type != "achievement" && !SettingsService.LoadOptions().HoneyMode)
        {
            return def.Gated ? BannerFireResult.Fallback("") : BannerFireResult.None;
        }

        if (def.Gated && def.GateChance.HasValue && _random.NextDouble() >= def.GateChance.Value)
        {
            if (def.Fallback == null) return BannerFireResult.None;
            return BannerFireResult.Fallback(Substitute(def.Fallback, tokens));
        }

        var message = PickMessage(def);
        if (message == null) return BannerFireResult.None;
        return BannerFireResult.Message(Substitute(message, tokens));
    }

    // English: any message in the pool. Spanish: only messages that actually have
    // a translation ("" means the translator explicitly marked it "No
    // Translation," or it hasn't been translated yet) — if none of this entry's
    // messages are translated, the entry has nothing eligible to show in Spanish
    // and the banner is suppressed for that fire (per product decision: don't
    // show English filler in an otherwise-Spanish session). Mirrors the Swift
    // port's BannerCatalog.pickMessage. Reads SettingsService fresh, same as the
    // HoneyMode check above, rather than a cached flag.
    private static string? PickMessage(BannerDefinition def)
    {
        if (SettingsService.LoadOptions().Language != AppLanguage.Spanish)
        {
            if (def.Messages.Count == 0) return null;
            return def.Messages[_random.Next(def.Messages.Count)];
        }
        var eligible = def.MessagesEs.Where(m => !string.IsNullOrEmpty(m)).ToList();
        if (eligible.Count == 0) return null;
        return eligible[_random.Next(eligible.Count)];
    }

    private static string Substitute(string text, Dictionary<string, string>? tokens)
    {
        if (tokens == null || tokens.Count == 0) return text;
        foreach (var (key, value) in tokens)
        {
            text = text.Replace("{" + key + "}", value);
        }
        return text;
    }

    // Whether ANY game's loading banner has fired yet this app session — not
    // per-game (each ViewModel has its own one-shot flag for that); this one is
    // shared across every game so we can tell "app launch" (the very first
    // loading banner shown this session, whichever game happens to load first)
    // from a later game switch.
    private static bool _hasFiredAnyLoadingBannerThisSession;

    // Lunisolar/lunar holidays (Holi, Rosh Hashanah, Diwali, Eid al-Fitr, Hanukkah)
    // don't fall on a fixed Gregorian date, so — unlike the month/day checks above —
    // they need a real per-year lookup. No formula shortcut exists for these, so this
    // is a flat 20-year table (2025-2045) keyed "YYYY-M-D", one entry per year per
    // holiday — each holiday is a multi-day observance in real life, but only its
    // first day is listed here, since that's the one day the banner should show.
    private static readonly Dictionary<string, BannerId> FloatingHolidayDates = BuildFloatingHolidayDates();

    private static Dictionary<string, BannerId> BuildFloatingHolidayDates()
    {
        var dates = new Dictionary<string, BannerId>();
        string[] holi = { "2025-3-14", "2026-3-3", "2027-3-22", "2028-3-11", "2029-3-29",
                           "2030-3-19", "2031-3-8", "2032-3-25", "2033-3-15", "2034-3-4",
                           "2035-3-22", "2036-3-12", "2037-3-1", "2038-3-19", "2039-3-8",
                           "2040-3-26", "2041-3-15", "2042-3-5", "2043-3-23", "2044-3-12",
                           "2045-3-1" };
        string[] roshHashanah = { "2025-9-23", "2026-9-12", "2027-10-2", "2028-9-21", "2029-9-10",
                                   "2030-9-28", "2031-9-18", "2032-9-6", "2033-9-24", "2034-9-14",
                                   "2035-10-4", "2036-9-22", "2037-9-10", "2038-9-30", "2039-9-19",
                                   "2040-9-8", "2041-9-26", "2042-9-15", "2043-10-5", "2044-9-22",
                                   "2045-9-12" };
        string[] diwali = { "2025-10-20", "2026-11-8", "2027-10-29", "2028-10-17", "2029-11-5",
                             "2030-10-26", "2031-11-14", "2032-11-2", "2033-10-22", "2034-11-10",
                             "2035-10-30", "2036-10-19", "2037-11-7", "2038-10-28", "2039-11-15",
                             "2040-11-4", "2041-10-24", "2042-11-12", "2043-10-31", "2044-10-20",
                             "2045-11-9" };
        string[] eidAlFitr = { "2025-3-30", "2026-3-19", "2027-3-9", "2028-2-26", "2029-2-14",
                                "2030-2-3", "2031-1-24", "2032-1-13", "2033-1-2", "2033-12-22",
                                "2034-12-11", "2035-11-30", "2036-11-18", "2037-11-8", "2038-10-29",
                                "2039-10-18", "2040-10-6", "2041-9-26", "2042-9-15", "2043-9-4",
                                "2044-8-24", "2045-8-13" };
        string[] hanukkah = { "2025-12-15", "2026-12-5", "2027-12-25", "2028-12-13", "2029-12-2",
                               "2030-12-21", "2031-12-10", "2032-11-28", "2033-12-17", "2034-12-7",
                               "2035-12-26", "2036-12-14", "2037-12-3", "2038-12-22", "2039-12-12",
                               "2040-11-30", "2041-12-18", "2042-12-8", "2043-12-27", "2044-12-15",
                               "2045-12-4" };
        foreach (var d in holi) dates[d] = BannerId.LoadingGameLoadsOnHoli;
        foreach (var d in roshHashanah) dates[d] = BannerId.LoadingGameLoadsOnRoshHashanah;
        foreach (var d in diwali) dates[d] = BannerId.LoadingGameLoadsOnDiwali;
        foreach (var d in eidAlFitr) dates[d] = BannerId.LoadingGameLoadsOnEidAlFitr;
        foreach (var d in hanukkah) dates[d] = BannerId.LoadingGameLoadsOnHanukkah;
        return dates;
    }

    // Decides which "loading" banner (checked once per game, per app session — each
    // ViewModel guards this with its own one-shot flag) fits right now. Time-of-day
    // windows and the one-year-anniversary check only apply at app launch — they're
    // tied to "the moment you opened the app," not to switching games afterward — so
    // on any later game switch this falls straight to holiday > generic. Shared across
    // every game (not Honeycomb-specific) since "is it Halloween" and "has this install
    // been played for a year" don't depend on which game asked.
    public static BannerId LoadingBannerId()
    {
        bool isAppLaunch = !_hasFiredAnyLoadingBannerThisSession;
        _hasFiredAnyLoadingBannerThisSession = true;
        _lastLoadingBannerWasAppLaunch = isAppLaunch;

        if (isAppLaunch && FirstPlayedTracker.ShouldShowOneYearBanner()) return BannerId.LoadingFirstLaunchAfterPlayingForOneYear;

        var now = DateTime.Now;
        if (now.Month == 5 && now.Day == 20) return BannerId.LoadingGameLoadsOnMay20thWorldBeeDay;
        if (now.Month == 1 && now.Day == 1) return BannerId.LoadingGameLoadsOnNewYearsDayJan1;
        if (now.Month == 10 && now.Day == 31) return BannerId.LoadingGameLoadsOnHalloweenOct31;
        if (now.Month == 2 && now.Day == 14) return BannerId.LoadingGameLoadsOnValentinesDayFeb14;
        if (now.Month == 4 && now.Day == 1) return BannerId.LoadingPlayingOnAprilFoolsDayApr1;
        if (now.Month == 4 && now.Day == 22) return BannerId.LoadingGameLoadsOnEarthDayApr22;
        if (now.Month == 8 && now.Day == 15) return BannerId.LoadingGameLoadsOnNationalHoneyDayAug15;
        if (now.Month == 3 && now.Day == 14) return BannerId.LoadingGameLoadsOnPiDayMar14;
        if (now.Month == 12 && now.Day == 31) return BannerId.LoadingGameLoadsOnNewYearsEveDec31;
        if (now.Month == 12 && now.Day == 25) return BannerId.LoadingGameLoadsOnChristmasDec25;
        if (FloatingHolidayDates.TryGetValue($"{now.Year}-{now.Month}-{now.Day}", out var floatingId)) return floatingId;

        if (isAppLaunch)
        {
            int minutesFromMidnight = now.Hour * 60 + now.Minute;
            if (Math.Abs(minutesFromMidnight - 720) <= 1) return BannerId.LoadingMatchStartsWithinAMinuteOfLocalNoon;
            if (now.Hour < 5) return BannerId.LoadingMatchStartsBetween1200AmAnd500AmLocalTime;
            if (now.Hour >= 5 && now.Hour < 8) return BannerId.LoadingMatchStartsBetween500AmAnd800AmLocalTime;
            if (now.Hour >= 8 && now.Hour < 12) return BannerId.LoadingMatchStartsBetween800AmAnd1200PmLocalTime;
            if (now.Hour >= 12 && now.Hour < 14) return BannerId.LoadingMatchStartsBetween1200PmAnd200PmLocalTime;
            if (now.Hour >= 14 && now.Hour < 17) return BannerId.LoadingMatchStartsBetween200PmAnd500PmLocalTime;
            if (now.Hour >= 17 && now.Hour < 21) return BannerId.LoadingMatchStartsBetween500PmAnd900PmLocalTime;
            if (now.Hour >= 21) return BannerId.LoadingMatchStartsBetween900PmAndMidnightLocalTime;
        }
        return BannerId.LoadingOnGameLoad;
    }

    // Set by LoadingBannerId() right before its caller enqueues the resulting banner —
    // every Loading-category catalog entry is ungated (see HoneycombBannerCatalog.json,
    // always BannerFireKind.Message), so a LoadingBannerId() call is always immediately
    // followed by that banner actually being flashed. Windows' Avalonia UI has a
    // noticeable startup cost that macOS's native AppKit path doesn't, so by the time the
    // very first frame is even on screen a chunk of the loading banner's normal on-screen
    // duration has already elapsed unseen — this lets the flash call for specifically the
    // app-launch banner (never a later game-switch one) use a longer duration to
    // compensate. Consumed (reset to false) by the read itself so it can only ever apply
    // to the one flash it was set for, not some later unrelated banner.
    private static bool _lastLoadingBannerWasAppLaunch;

    public static bool ConsumeAppLaunchLoadingFlag()
    {
        bool wasAppLaunch = _lastLoadingBannerWasAppLaunch;
        _lastLoadingBannerWasAppLaunch = false;
        return wasAppLaunch;
    }
}
