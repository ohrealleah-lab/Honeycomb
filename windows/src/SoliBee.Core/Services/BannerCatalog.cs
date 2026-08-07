using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
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
    public static BannerFireResult Fire(BannerId id, Dictionary<string, string>? tokens = null)
    {
        if (!Entries.TryGetValue(id, out var def)) return BannerFireResult.None;

        if (def.Gated && def.GateChance.HasValue && _random.NextDouble() >= def.GateChance.Value)
        {
            if (def.Fallback == null) return BannerFireResult.None;
            return BannerFireResult.Fallback(Substitute(def.Fallback, tokens));
        }

        if (def.Messages.Count == 0) return BannerFireResult.None;
        var message = def.Messages[_random.Next(def.Messages.Count)];
        return BannerFireResult.Message(Substitute(message, tokens));
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

        if (isAppLaunch && FirstPlayedTracker.ShouldShowOneYearBanner()) return BannerId.LoadingFirstLaunchAfterPlayingForOneYear;

        var now = DateTime.Now;
        if (now.Month == 5 && now.Day == 20) return BannerId.LoadingGameLoadsOnMay20thWorldBeeDay;
        if (now.Month == 1 && now.Day == 1) return BannerId.LoadingGameLoadsOnNewYearsDayJan1;
        if (now.Month == 10 && now.Day == 31) return BannerId.LoadingGameLoadsOnHalloweenOct31;
        if (now.Month == 2 && now.Day == 14) return BannerId.LoadingGameLoadsOnValentinesDayFeb14;
        if (now.Month == 4 && now.Day == 1) return BannerId.LoadingPlayingOnAprilFoolsDayApr1;

        if (isAppLaunch)
        {
            int minutesFromMidnight = now.Hour * 60 + now.Minute;
            if (Math.Abs(minutesFromMidnight - 720) <= 1) return BannerId.LoadingMatchStartsWithinAMinuteOfLocalNoon;
            if (now.Hour < 4) return BannerId.LoadingMatchStartsBetween1200AmAnd400AmLocalTime;
            if (now.Hour >= 5 && now.Hour < 8) return BannerId.LoadingMatchStartsBetween500AmAnd800AmLocalTime;
            if (now.Hour >= 8 && now.Hour < 12) return BannerId.LoadingMatchStartsBetween800AmAnd1200PmLocalTime;
            if (now.Hour >= 12 && now.Hour < 14) return BannerId.LoadingMatchStartsBetween1200PmAnd200PmLocalTime;
            if (now.Hour >= 14 && now.Hour < 17) return BannerId.LoadingMatchStartsBetween200PmAnd500PmLocalTime;
            if (now.Hour >= 17 && now.Hour < 21) return BannerId.LoadingMatchStartsBetween500PmAnd900PmLocalTime;
            if (now.Hour >= 21) return BannerId.LoadingMatchStartsBetween900PmAndMidnightLocalTime;
        }
        return BannerId.LoadingOnGameLoad;
    }
}
