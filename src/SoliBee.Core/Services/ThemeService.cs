using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using SoliBee.Core.Models;

namespace SoliBee.Core.Services;

public static class ThemeService
{
    private static readonly string _dataDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SoliBee");

    private static readonly string _themesPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "SoliBee", "themes.json");

    // Tombstone of default-preset Ids the user has explicitly deleted, so
    // MergeInDefaultThemes doesn't resurrect them on the next launch.
    private static readonly string _deletedDefaultsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "SoliBee", "deleted_default_themes.json");

    private static readonly JsonSerializerOptions _jsonOpts = new() { WriteIndented = true };

    // "Dingwall"/"Colorblind" were removed from the preset lineup (no longer in this
    // array), but LoadThemes() never purges a saved theme just because it's missing
    // from here — so existing users who already saved one of those keep it untouched.
    public static readonly IReadOnlyList<SoliBeeTheme> DefaultThemes = new List<SoliBeeTheme>
    {
        // Index 0 — applied by ApplyDefaultThemeIfNeeded on a fresh install (see below).
        new SoliBeeTheme
        {
            Id             = new Guid("b0001111-0000-0000-0000-000000000006"),
            Name           = "Default",
            CardBackTheme  = "Moogle",
            FeltColor      = FeltColorTheme.FeltGreen,
        },
        new SoliBeeTheme
        {
            Id             = new Guid("b0001111-0000-0000-0000-000000000001"),
            Name           = "Pareidolic 2",
            CardBackTheme  = "Pareidolic 2",
            FeltColor      = FeltColorTheme.Custom,
            CustomFeltColorHex = "#9796CF",   // R:0.5926 G:0.5882 B:0.8116
        },
        new SoliBeeTheme
        {
            Id             = new Guid("b0001111-0000-0000-0000-000000000003"),
            Name           = "Desert",
            CardBackTheme  = "Vulpera",
            FeltColor      = FeltColorTheme.Desert,
        },
        new SoliBeeTheme
        {
            Id             = new Guid("b0001111-0000-0000-0000-000000000004"),
            Name           = "Forest",
            CardBackTheme  = "Forest",
            FeltColor      = FeltColorTheme.Custom,
            CustomFeltColorHex   = "#857A74", // R:0.5212 G:0.4770 B:0.4560
            ThemeFaceBackNormal  = "#FFE6CFAC",
            ThemeFaceBorderNormal = "#D9000000",
            ThemeTextBlackNormal = "#FFB53026", // Black suits (Spades/Clubs)
            ThemeTextRed         = "#FFC61C1A", // Red suits (Hearts/Diamonds)
            ThemeCardShadow      = "#26000000",
        },
        new SoliBeeTheme
        {
            Id             = new Guid("b0001111-0000-0000-0000-000000000005"),
            Name           = "OceanSky",
            CardBackTheme  = "Pareidolic",
            FeltColor      = FeltColorTheme.Custom,
            CustomFeltColorHex   = "#96F5F7", // R:0.5867 G:0.9626 B:0.9703
            ThemeFaceBackNormal  = "#FFE1FDFE",
            ThemeFaceBorderNormal = "#D9000000",
            ThemeTextBlackNormal = "#FF424242", // Black suits (Spades/Clubs)
            ThemeTextRed         = "#FFC05491", // Red suits (Hearts/Diamonds)
            ThemeCardShadow      = "#26000000",
        },
    }.AsReadOnly();

    public static List<SoliBeeTheme> LoadThemes()
    {
        if (File.Exists(_themesPath))
        {
            try
            {
                var json   = File.ReadAllText(_themesPath);
                var loaded = JsonSerializer.Deserialize<List<SoliBeeTheme>>(json);
                if (loaded != null && loaded.Count > 0) return loaded;
            }
            catch { }
        }
        return new List<SoliBeeTheme>(DefaultThemes);
    }

    public static void SaveThemes(List<SoliBeeTheme> themes)
    {
        try
        {
            if (!Directory.Exists(_dataDir)) Directory.CreateDirectory(_dataDir);
            File.WriteAllText(_themesPath, JsonSerializer.Serialize(themes, _jsonOpts));
        }
        catch { }
    }

    public static void AddTheme(SoliBeeTheme theme)
    {
        var themes = LoadThemes();
        themes.Add(theme);
        SaveThemes(themes);
    }

    // Called on every launch to keep the saved themes list converged with the current
    // preset definitions. Matches by the preset's fixed Id (not by name) — a saved theme
    // is only ever treated as "this preset" if it really is that preset, so a user's own
    // custom theme that merely happens to share a preset's name (e.g. "Desert") is never
    // touched, and a preset the user explicitly deleted (tracked in the tombstone file)
    // stays deleted instead of silently reappearing. Never removes or touches anything
    // else the user saved (a legacy "Dingwall" theme, or their own custom themes).
    public static void MergeInDefaultThemes()
    {
        var themes     = LoadThemes();
        var deletedIds = LoadDeletedDefaultThemeIds();

        foreach (var preset in DefaultThemes)
        {
            if (deletedIds.Contains(preset.Id)) continue;

            int idx = themes.FindIndex(t => t.Id == preset.Id);
            if (idx >= 0)
                themes[idx] = ClonePreset(preset);
            else
                themes.Add(ClonePreset(preset));
        }

        SaveThemes(themes);
    }

    private static List<Guid> LoadDeletedDefaultThemeIds()
    {
        if (File.Exists(_deletedDefaultsPath))
        {
            try
            {
                var json    = File.ReadAllText(_deletedDefaultsPath);
                var loaded  = JsonSerializer.Deserialize<List<Guid>>(json);
                if (loaded != null) return loaded;
            }
            catch { }
        }
        return new List<Guid>();
    }

    private static void SaveDeletedDefaultThemeIds(List<Guid> ids)
    {
        try
        {
            if (!Directory.Exists(_dataDir)) Directory.CreateDirectory(_dataDir);
            File.WriteAllText(_deletedDefaultsPath, JsonSerializer.Serialize(ids, _jsonOpts));
        }
        catch { }
    }

    // JSON round-trip instead of a hand-listed field copy — SoliBeeTheme has no
    // exhaustiveness check (plain mutable class, not a record), so a manual copy would
    // silently drop any field added later instead of failing to compile.
    private static SoliBeeTheme ClonePreset(SoliBeeTheme preset) =>
        JsonSerializer.Deserialize<SoliBeeTheme>(JsonSerializer.Serialize(preset, _jsonOpts), _jsonOpts)!;

    public static void DeleteTheme(Guid id)
    {
        // If this is a built-in default preset, record the tombstone BEFORE removing it
        // from themes.json (two separate files, no way to write them atomically together)
        // — if the process dies between the two writes, this ordering means the safe
        // failure mode is "still shows in the list" rather than "silently resurrected
        // with reset values", since MergeInDefaultThemes checks the tombstone first.
        if (DefaultThemes.Any(p => p.Id == id))
        {
            var deletedIds = LoadDeletedDefaultThemeIds();
            if (!deletedIds.Contains(id))
            {
                deletedIds.Add(id);
                SaveDeletedDefaultThemeIds(deletedIds);
            }
        }

        var themes = LoadThemes();
        themes.RemoveAll(t => t.Id == id);
        SaveThemes(themes);
    }

    public static SoliBeeTheme SnapshotFromOptions(string name, GameOptions options)
    {
        var theme = new SoliBeeTheme
        {
            Name = name,
            CardBackTheme = options.CardBackTheme,
            CardBackScale = options.CardBackScale,
            CardBackOffsetX = options.CardBackOffsetX,
            CardBackOffsetY = options.CardBackOffsetY,
            FeltColor = options.FeltColor,
            CustomFeltColorHex = options.CustomFeltColorHex,
            BackgroundName = options.BackgroundName,
            BackgroundScale = options.BackgroundScale,
            BackgroundOffsetX = options.BackgroundOffsetX,
            BackgroundOffsetY = options.BackgroundOffsetY,
            ThemeFaceBackNormal = options.ThemeFaceBackNormal,
            ThemeFaceBorderNormal = options.ThemeFaceBorderNormal,
            ThemeTextRed = options.ThemeTextRed,
            ThemeTextBlackNormal = options.ThemeTextBlackNormal,
            ThemeCardShadow = options.ThemeCardShadow,
        };

        foreach (var art in FaceCardArtService.GetAllArts())
        {
            theme.FaceArts.Add(new FaceArtSnapshot
            {
                Slot = art.Slot.ToString(),
                RelativePath = art.RelativePath,
                Scale = art.Scale,
                OffsetX = art.OffsetX,
                OffsetY = art.OffsetY,
                IsEnabled = art.IsEnabled,
            });
        }

        return theme;
     }

     // Compares live options against a saved theme's own snapshot (ignoring Id, which
     // callers set to match before calling) to detect edits made since it was applied/saved.
     public static bool CurrentMatchesTheme(GameOptions options, SoliBeeTheme theme)
     {
        var current = SnapshotFromOptions(theme.Name, options);
        current.Id = theme.Id;
        return JsonSerializer.Serialize(current, _jsonOpts) == JsonSerializer.Serialize(theme, _jsonOpts);
     }

     public static GameOptions ApplyTheme(SoliBeeTheme theme, GameOptions options)
     {
        options.ActiveThemeId = theme.Id;
        options.CardBackTheme = theme.CardBackTheme;
        options.CardBackScale = theme.CardBackScale;
        options.CardBackOffsetX = theme.CardBackOffsetX;
        options.CardBackOffsetY = theme.CardBackOffsetY;
        options.FeltColor = theme.FeltColor;
        options.CustomFeltColorHex = theme.CustomFeltColorHex;
        options.BackgroundName = theme.BackgroundName;
        options.BackgroundScale = theme.BackgroundScale;
        options.BackgroundOffsetX = theme.BackgroundOffsetX;
        options.BackgroundOffsetY = theme.BackgroundOffsetY;
        options.ThemeFaceBackNormal = theme.ThemeFaceBackNormal;
        options.ThemeFaceBorderNormal = theme.ThemeFaceBorderNormal;
        options.ThemeTextRed = theme.ThemeTextRed;
        options.ThemeTextBlackNormal = theme.ThemeTextBlackNormal;
        options.ThemeCardShadow = theme.ThemeCardShadow;
        options.CustomFeltColorRevision++;

        // Restore face arts without deleting files on disk
        var artDir = FaceCardArtService.ArtDirectory;
        var reconstructed = new List<CustomFaceArt>();

        foreach (var snap in theme.FaceArts)
        {
            if (!Enum.TryParse<FaceCardSlot>(snap.Slot, out var slot)) continue;
            if (!PathSafety.IsSafeFileName(snap.RelativePath)) continue;
            var fullPath = Path.Combine(artDir, snap.RelativePath);
            if (!File.Exists(fullPath)) continue; // prune silently if file is missing

            reconstructed.Add(new CustomFaceArt
            {
                Slot = slot,
                RelativePath = snap.RelativePath,
                Scale = snap.Scale,
                OffsetX = snap.OffsetX,
                OffsetY = snap.OffsetY,
                IsEnabled = snap.IsEnabled,
            });
        }

        FaceCardArtService.ReplaceAll(reconstructed);

        return options;
    }

    public static bool ApplyDefaultThemeIfNeeded(GameOptions options)
    {
        if (options.HasAppliedDefaultTheme) return false;

        options.HasAppliedDefaultTheme = true;

        // Only override visuals if the user hasn't changed anything from factory defaults —
        // a fresh install lands here and gets DefaultThemes[0] ("Default": Moogle + Felt Green).
        bool isFactoryFelt = options.FeltColor == FeltColorTheme.FeltGreen;
        bool isFactoryBack = options.CardBackTheme == "Vulpera";
        if (isFactoryFelt && isFactoryBack)
            ApplyTheme(DefaultThemes[0], options);

        // Populate the themes list so PreferencesView shows defaults on first open
        if (!File.Exists(_themesPath))
            SaveThemes(new List<SoliBeeTheme>(DefaultThemes));

        return true;
    }
}
