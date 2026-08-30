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
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), AppDataMigration.FolderName);

    private static readonly string _themesPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        AppDataMigration.FolderName, "themes.json");

    // Tombstone of default-preset Ids the user has explicitly deleted, so
    // MergeInDefaultThemes doesn't resurrect them on the next launch.
    private static readonly string _deletedDefaultsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        AppDataMigration.FolderName, "deleted_default_themes.json");

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
            CardBackTheme  = "Solibee",
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

    // Shared JSON-file load/save shape, used by the theme store below and the tombstone
    // store further down — factored out so an error-handling change (like the
    // load-failure guard MergeInDefaultThemes relies on) only has to be made once
    // instead of once per file this service reads and writes.
    private static (T Value, bool LoadFailed) LoadJson<T>(string path, Func<T> makeFallback, Func<T, bool>? isValid = null)
    {
        if (File.Exists(path))
        {
            try
            {
                var json   = File.ReadAllText(path);
                var loaded = JsonSerializer.Deserialize<T>(json);
                if (loaded != null && (isValid?.Invoke(loaded) ?? true)) return (loaded, false);
            }
            catch { return (makeFallback(), true); }
        }
        return (makeFallback(), false);
    }

    private static bool SaveJson<T>(string path, T value)
    {
        try
        {
            if (!Directory.Exists(_dataDir)) Directory.CreateDirectory(_dataDir);
            File.WriteAllText(path, JsonSerializer.Serialize(value, _jsonOpts));
            return true;
        }
        catch { return false; }
    }

    private static (List<SoliBeeTheme> Themes, bool LoadFailed) LoadThemesCore() =>
        LoadJson(_themesPath, () => new List<SoliBeeTheme>(DefaultThemes), loaded => loaded.Count > 0);

    public static List<SoliBeeTheme> LoadThemes() => LoadThemesCore().Themes;

    public static void SaveThemes(List<SoliBeeTheme> themes) => SaveJson(_themesPath, themes);

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
    // else the user saved (a legacy "Dingwall" theme, or their own custom themes) — and
    // never overwrites a preset that's already in the saved list, even to refresh its
    // definition, since UpdateTheme lets a user customize a default preset in place
    // (face art, felt color, rename) and this runs on every launch; only missing presets
    // get added.
    public static void MergeInDefaultThemes()
    {
        var (themes, loadFailed) = LoadThemesCore();
        // A transient read/parse failure of themes.json falls back to just the 5 in-code
        // presets — persisting that back would permanently erase every custom theme over
        // a failure that might not recur. Skip saving and try again next launch instead.
        if (loadFailed) return;

        var deletedIds = LoadDeletedDefaultThemeIds();

        bool changed = false;
        foreach (var preset in DefaultThemes)
        {
            if (deletedIds.Contains(preset.Id)) continue;
            if (themes.FindIndex(t => t.Id == preset.Id) >= 0) continue;

            themes.Add(ClonePreset(preset));
            changed = true;
        }

        if (changed) SaveThemes(themes);
    }

    private static List<Guid> LoadDeletedDefaultThemeIds() =>
        LoadJson(_deletedDefaultsPath, () => new List<Guid>()).Value;

    private static bool SaveDeletedDefaultThemeIds(List<Guid> ids) => SaveJson(_deletedDefaultsPath, ids);

    // JSON round-trip instead of a hand-listed field copy — SoliBeeTheme has no
    // exhaustiveness check (plain mutable class, not a record), so a manual copy would
    // silently drop any field added later instead of failing to compile.
    private static SoliBeeTheme ClonePreset(SoliBeeTheme preset) =>
        JsonSerializer.Deserialize<SoliBeeTheme>(JsonSerializer.Serialize(preset, _jsonOpts), _jsonOpts)!;

    // Overwrites the saved theme with the given id using the current live settings,
    // keeping that theme's existing id and name unchanged. Works on default presets
    // too — no special-casing based on theme origin, same as DeleteTheme.
    // Returns false when `id` doesn't match any saved theme (e.g. it was deleted out
    // from under an in-memory GameOptions still pointing at it) — callers that live-save
    // on every edit (PreferencesView's FaceCardArtChangedMessage hook) should treat a
    // false return as "there's no active theme to save into anymore" and clear
    // options.ActiveThemeId, rather than silently retrying this same no-op on every
    // future edit until a theme switch discards whatever wasn't actually being saved.
    public static bool UpdateTheme(Guid id, GameOptions options)
    {
        var themes = LoadThemes();
        int idx = themes.FindIndex(t => t.Id == id);
        if (idx < 0) return false;

        var updated = SnapshotFromOptions(themes[idx].Name, options);
        updated.Id = id;
        themes[idx] = updated;
        SaveThemes(themes);
        return true;
    }

    public static void RenameTheme(Guid id, string newName)
    {
        var themes = LoadThemes();
        int idx = themes.FindIndex(t => t.Id == id);
        if (idx < 0) return;

        themes[idx].Name = newName;
        SaveThemes(themes);
    }

    public static void DeleteTheme(Guid id)
    {
        // If this is a built-in default preset, record the tombstone BEFORE removing it
        // from themes.json (two separate files, no way to write them atomically together)
        // — if the tombstone write itself fails, abort instead of still removing it from
        // themes.json, so the safe failure mode stays "still shows in the list" rather
        // than "looks deleted but silently resurrected on the next launch" (since
        // MergeInDefaultThemes checks the tombstone first).
        if (DefaultThemes.Any(p => p.Id == id))
        {
            var deletedIds = LoadDeletedDefaultThemeIds();
            if (!deletedIds.Contains(id))
            {
                deletedIds.Add(id);
                if (!SaveDeletedDefaultThemeIds(deletedIds)) return;
            }
        }

        var themes = LoadThemes();
        themes.RemoveAll(t => t.Id == id);
        SaveThemes(themes);
    }

    // Deletion of a custom background/card back/face art always succeeds immediately —
    // any saved theme that references the deleted asset gets that one field patched back
    // to a default (background/card back) or that entry removed from FaceArts (face art),
    // rather than the deletion being blocked. These three are called from each manager's
    // remove path, right alongside the actual file deletion.
    public static void ClearBackgroundReferences(string name)
    {
        var themes = LoadThemes();
        bool changed = false;
        foreach (var theme in themes)
        {
            if (theme.BackgroundName == name)
            {
                theme.BackgroundName = null;
                changed = true;
            }
        }
        if (changed) SaveThemes(themes);
    }

    public static void ClearCardBackReferences(string name, string fallback)
    {
        var themes = LoadThemes();
        bool changed = false;
        foreach (var theme in themes)
        {
            if (theme.CardBackTheme == name)
            {
                theme.CardBackTheme = fallback;
                changed = true;
            }
        }
        if (changed) SaveThemes(themes);
    }

    public static void ClearFaceArtReferences(string relativePath)
    {
        var themes = LoadThemes();
        bool changed = false;
        foreach (var theme in themes)
        {
            int removed = theme.FaceArts.RemoveAll(a => a.RelativePath == relativePath);
            if (removed > 0) changed = true;
        }
        if (changed) SaveThemes(themes);
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
            ThemeHintHighlight = options.ThemeHintHighlight,
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

     public static GameOptions ApplyTheme(SoliBeeTheme theme, GameOptions options)
     {
        options.ActiveThemeId = theme.Id;
        options.CardBackTheme = theme.CardBackTheme;
        options.CardBackScale = theme.CardBackScale;
        options.CardBackOffsetX = theme.CardBackOffsetX;
        options.CardBackOffsetY = theme.CardBackOffsetY;
        options.FeltColor = theme.FeltColor;
        options.CustomFeltColorHex = theme.CustomFeltColorHex;
        // Unlike card backs (bundled assets always exist) or face art (restored from the
        // theme's own snapshot two lines below), a background is neither bundled nor
        // snapshotted — it's just a name pointing at whatever's currently in
        // options.CustomBackgrounds. If that entry is gone (deleted out from under this
        // theme by some path other than the normal UI block, or the two stores desynced),
        // silently drop the name rather than leaving a dangling reference that the
        // Preferences combo box can't select and that a later delete could mismatch.
        bool backgroundStillExists = !string.IsNullOrEmpty(theme.BackgroundName) &&
            options.CustomBackgrounds.Exists(b => b.Name == theme.BackgroundName);
        options.BackgroundName = backgroundStillExists ? theme.BackgroundName : null;
        options.BackgroundScale = theme.BackgroundScale;
        options.BackgroundOffsetX = theme.BackgroundOffsetX;
        options.BackgroundOffsetY = theme.BackgroundOffsetY;
        options.ThemeFaceBackNormal = theme.ThemeFaceBackNormal;
        options.ThemeFaceBorderNormal = theme.ThemeFaceBorderNormal;
        options.ThemeTextRed = theme.ThemeTextRed;
        options.ThemeTextBlackNormal = theme.ThemeTextBlackNormal;
        options.ThemeCardShadow = theme.ThemeCardShadow;
        options.ThemeHintHighlight = theme.ThemeHintHighlight;
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
