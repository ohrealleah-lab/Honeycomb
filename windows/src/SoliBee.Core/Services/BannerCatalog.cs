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
}
