using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Services;

// Themes: the built-in presets, saving/loading, "a deleted preset stays deleted", applying
// a theme to the live settings, and cleaning theme references when a custom background /
// card back / face art is deleted. DataSandbox puts themes.json and the face-art list back.
public class ThemeServiceTests : DataSandbox
{
    private static readonly Guid DefaultId = new("b0001111-0000-0000-0000-000000000006");
    private static readonly Guid DesertId = new("b0001111-0000-0000-0000-000000000003");

    private static SoliBeeTheme Custom(string name, string cardBack = "Solibee", string? background = null) =>
        new() { Name = name, CardBackTheme = cardBack, FeltColor = FeltColorTheme.Crimson, BackgroundName = background };

    private static string TombstoneFile => Path.Combine(AppPaths.DataDirectory, "deleted_default_themes.json");

    // ---- Built-in presets ----

    [Fact]
    public void DefaultThemes_AreTheEightPresets_WithUniqueIdsAndNames()
    {
        Assert.Equal(new[] { "Default", "Honey", "Sunset", "Moogle", "Pareidolic 2", "Desert", "Forest", "OceanSky" },
            ThemeService.DefaultThemes.Select(t => t.Name));
        Assert.Equal(8, ThemeService.DefaultThemes.Select(t => t.Id).Distinct().Count());
    }

    [Fact]
    public void DefaultPreset_IsTheSolibeeBackOnFeltGreen()
    {
        var d = ThemeService.DefaultThemes[0];
        Assert.Equal(DefaultId, d.Id);
        Assert.Equal("Solibee", d.CardBackTheme);
        Assert.Equal(FeltColorTheme.FeltGreen, d.FeltColor);
    }

    // ---- Load / save ----

    [Fact]
    public void LoadThemes_WithNoFile_GivesTheEightPresets()
    {
        Delete("themes.json");
        Assert.Equal(8, ThemeService.LoadThemes().Count);
    }

    [Fact]
    public void SavedThemes_SurviveAndComeBackInOrder()
    {
        ThemeService.SaveThemes(new List<SoliBeeTheme> { Custom("Alpha"), Custom("Beta", "Forest") });

        var loaded = ThemeService.LoadThemes();

        Assert.Equal(new[] { "Alpha", "Beta" }, loaded.Select(t => t.Name));
        Assert.Equal("Forest", loaded[1].CardBackTheme);
        Assert.Equal(FeltColorTheme.Crimson, loaded[0].FeltColor);
    }

    [Fact]
    public void AddTheme_AppendsToTheSavedList()
    {
        ThemeService.SaveThemes(new List<SoliBeeTheme> { Custom("Alpha") });
        ThemeService.AddTheme(Custom("Beta"));

        Assert.Equal(new[] { "Alpha", "Beta" }, ThemeService.LoadThemes().Select(t => t.Name));
    }

    [Fact]
    public void ThemeFromAnOlderVersion_MissingNewFields_StillLoadsWithDefaults()
    {
        var id = Guid.NewGuid();
        Write("themes.json", $"[{{\"Id\":\"{id}\",\"Name\":\"Old\",\"CardBackTheme\":\"Solibee\",\"FeltColor\":1}}]");

        var t = Assert.Single(ThemeService.LoadThemes());

        Assert.Equal(id, t.Id);
        Assert.Equal("Old", t.Name);
        Assert.Equal(FeltColorTheme.Crimson, t.FeltColor);
        Assert.Equal(1.0, t.CardBackScale);
        Assert.Equal("#592673", t.CustomFeltColorHex);
        Assert.Null(t.BackgroundName);
        Assert.Null(t.ThemeTextRed);
        Assert.Empty(t.FaceArts);
    }

    [Theory]
    [InlineData("")]
    [InlineData("garbage")]
    [InlineData("null")]
    public void BrokenOrEmptyThemesFile_FallsBackToThePresets(string contents)
    {
        Write("themes.json", contents);
        Assert.Equal(8, ThemeService.LoadThemes().Count);
    }

    // ---- Update / rename / delete ----

    [Fact]
    public void UpdateTheme_OverwritesFromLiveSettings_KeepingIdAndName()
    {
        var t = Custom("Mine");
        ThemeService.SaveThemes(new List<SoliBeeTheme> { t });
        Options.CardBackTheme = "Forest";
        Options.FeltColor = FeltColorTheme.Charcoal;
        Options.ThemeTextRed = "#FF112233";

        Assert.True(ThemeService.UpdateTheme(t.Id, Options));

        var saved = Assert.Single(ThemeService.LoadThemes());
        Assert.Equal(t.Id, saved.Id);
        Assert.Equal("Mine", saved.Name);
        Assert.Equal("Forest", saved.CardBackTheme);
        Assert.Equal(FeltColorTheme.Charcoal, saved.FeltColor);
        Assert.Equal("#FF112233", saved.ThemeTextRed);
    }

    [Fact]
    public void UpdateTheme_UnknownId_ReturnsFalse_AndChangesNothing()
    {
        ThemeService.SaveThemes(new List<SoliBeeTheme> { Custom("Mine") });
        Options.CardBackTheme = "Forest";

        Assert.False(ThemeService.UpdateTheme(Guid.NewGuid(), Options));

        Assert.Equal("Solibee", Assert.Single(ThemeService.LoadThemes()).CardBackTheme);
    }

    [Fact]
    public void UpdateTheme_WorksOnABuiltInPreset_InPlace()
    {
        ThemeService.SaveThemes(new List<SoliBeeTheme>(ThemeService.DefaultThemes));
        Options.CardBackTheme = "Forest";

        Assert.True(ThemeService.UpdateTheme(DesertId, Options));

        var desert = ThemeService.LoadThemes().Single(t => t.Id == DesertId);
        Assert.Equal("Desert", desert.Name);
        Assert.Equal("Forest", desert.CardBackTheme);
    }

    [Fact]
    public void RenameTheme_ChangesOnlyThatThemesName_AndKeepsItSaved()
    {
        var a = Custom("Alpha"); var b = Custom("Beta");
        ThemeService.SaveThemes(new List<SoliBeeTheme> { a, b });

        ThemeService.RenameTheme(a.Id, "Gamma");

        Assert.Equal(new[] { "Gamma", "Beta" }, ThemeService.LoadThemes().Select(t => t.Name));
    }

    [Fact]
    public void RenameTheme_UnknownId_DoesNothing()
    {
        ThemeService.SaveThemes(new List<SoliBeeTheme> { Custom("Alpha") });
        ThemeService.RenameTheme(Guid.NewGuid(), "Nope");
        Assert.Equal("Alpha", Assert.Single(ThemeService.LoadThemes()).Name);
    }

    [Fact]
    public void DeleteTheme_RemovesACustomTheme_WithoutRecordingItAsADeletedPreset()
    {
        var a = Custom("Alpha"); var b = Custom("Beta");
        ThemeService.SaveThemes(new List<SoliBeeTheme> { a, b });

        ThemeService.DeleteTheme(a.Id);

        Assert.Equal(new[] { "Beta" }, ThemeService.LoadThemes().Select(t => t.Name));
        Assert.False(File.Exists(TombstoneFile));
    }

    [Fact]
    public void DeleteTheme_UnknownId_DoesNothing()
    {
        ThemeService.SaveThemes(new List<SoliBeeTheme> { Custom("Alpha") });
        ThemeService.DeleteTheme(Guid.NewGuid());
        Assert.Single(ThemeService.LoadThemes());
    }

    // ---- Presets: first-run list and "deleted stays deleted" ----

    [Fact]
    public void Merge_WithNoSavedList_SavesAllFivePresets()
    {
        Delete("themes.json");
        ThemeService.MergeInDefaultThemes();

        var saved = ThemeService.LoadThemes();
        Assert.Equal(ThemeService.DefaultThemes.Select(t => t.Id), saved.Select(t => t.Id));
    }

    [Fact]
    public void Merge_AddsOnlyMissingPresets_AndKeepsUserThemes()
    {
        var mine = Custom("Mine");
        ThemeService.SaveThemes(new List<SoliBeeTheme> { mine });

        ThemeService.MergeInDefaultThemes();

        var saved = ThemeService.LoadThemes();
        Assert.Equal(9, saved.Count);
        Assert.Equal(mine.Id, saved[0].Id);
        Assert.All(ThemeService.DefaultThemes, p => Assert.Contains(saved, t => t.Id == p.Id));
    }

    [Fact]
    public void Merge_GivesAnExistingPlayerOnlyTheNewPresets_AndLeavesTheirOldOnesAlone()
    {
        // A player from before Honey/Sunset/Moogle existed: the original five presets,
        // saved with their old look (marked here by an "Old" card back).
        var oldIds = new[] { "000000000006", "000000000001", "000000000003", "000000000004", "000000000005" }
            .Select(s => new Guid("b0001111-0000-0000-0000-" + s)).ToList();
        ThemeService.SaveThemes(oldIds.Select(id => new SoliBeeTheme { Id = id, Name = "Old " + id, CardBackTheme = "Old" }).ToList());

        ThemeService.MergeInDefaultThemes();

        var saved = ThemeService.LoadThemes();
        Assert.Equal(8, saved.Count);
        Assert.All(saved.Where(t => oldIds.Contains(t.Id)), t => Assert.Equal("Old", t.CardBackTheme));
        Assert.Equal(new[] { "Honey", "Sunset", "Moogle" }, saved.Skip(5).Select(t => t.Name));
    }

    [Fact]
    public void Merge_NeverOverwritesAPresetThePlayerCustomised()
    {
        var customised = new SoliBeeTheme { Id = DesertId, Name = "My Desert", CardBackTheme = "Forest", FeltColor = FeltColorTheme.Charcoal };
        ThemeService.SaveThemes(new List<SoliBeeTheme> { customised });

        ThemeService.MergeInDefaultThemes();

        var desert = ThemeService.LoadThemes().Single(t => t.Id == DesertId);
        Assert.Equal("My Desert", desert.Name);
        Assert.Equal("Forest", desert.CardBackTheme);
        Assert.Equal(FeltColorTheme.Charcoal, desert.FeltColor);
    }

    [Fact]
    public void Merge_TreatsAThemeThatMerelySharesAPresetsName_AsADifferentTheme()
    {
        var lookalike = Custom("Desert");
        ThemeService.SaveThemes(new List<SoliBeeTheme> { lookalike });

        ThemeService.MergeInDefaultThemes();

        var saved = ThemeService.LoadThemes();
        Assert.Equal(lookalike.Id, saved.Single(t => t.Name == "Desert" && t.CardBackTheme == "Solibee").Id);
        // The real Desert preset is added next to it, and the lookalike is untouched.
        Assert.Equal(2, saved.Count(t => t.Name == "Desert"));
        Assert.Equal(FeltColorTheme.Crimson, saved.Single(t => t.Id == lookalike.Id).FeltColor);
    }

    [Fact]
    public void DeletedPreset_StaysDeleted_AfterMerge()
    {
        ThemeService.SaveThemes(new List<SoliBeeTheme>(ThemeService.DefaultThemes));

        ThemeService.DeleteTheme(DesertId);
        Assert.DoesNotContain(ThemeService.LoadThemes(), t => t.Id == DesertId);

        ThemeService.MergeInDefaultThemes();
        ThemeService.MergeInDefaultThemes();

        var saved = ThemeService.LoadThemes();
        Assert.DoesNotContain(saved, t => t.Id == DesertId);
        Assert.Equal(7, saved.Count);
    }

    [Fact]
    public void DeletingAPresetTwice_IsRecordedOnce()
    {
        ThemeService.SaveThemes(new List<SoliBeeTheme>(ThemeService.DefaultThemes));

        ThemeService.DeleteTheme(DesertId);
        ThemeService.DeleteTheme(DesertId);

        var ids = System.Text.Json.JsonSerializer.Deserialize<List<Guid>>(File.ReadAllText(TombstoneFile))!;
        Assert.Equal(new[] { DesertId }, ids);
    }

    [Fact]
    public void DeletedPresets_AreRememberedAcrossLaunches_ForEveryPreset()
    {
        var mine = Custom("Mine");
        ThemeService.SaveThemes(new List<SoliBeeTheme>(ThemeService.DefaultThemes) { mine });
        foreach (var p in ThemeService.DefaultThemes) ThemeService.DeleteTheme(p.Id);

        ThemeService.MergeInDefaultThemes();

        Assert.Equal(mine.Id, Assert.Single(ThemeService.LoadThemes()).Id);
    }

    [Fact]
    public void Merge_WithABrokenThemesFile_LeavesTheFileAloneInsteadOfWipingIt()
    {
        Write("themes.json", "{ this is not valid");

        ThemeService.MergeInDefaultThemes();

        Assert.Equal("{ this is not valid", Read("themes.json"));
    }

    // ---- Snapshot / apply ----

    [Fact]
    public void Snapshot_CapturesTheLiveLookSettings()
    {
        var o = Options;
        o.CardBackTheme = "Forest"; o.CardBackScale = 1.25; o.CardBackOffsetX = 3; o.CardBackOffsetY = -4;
        o.FeltColor = FeltColorTheme.Custom; o.CustomFeltColorHex = "#010203";
        o.BackgroundName = "Beach"; o.BackgroundScale = 2; o.BackgroundOffsetX = 5; o.BackgroundOffsetY = 6;
        o.ThemeFaceBackNormal = "#1"; o.ThemeFaceBorderNormal = "#2"; o.ThemeTextRed = "#3"; o.ThemeTextBlackNormal = "#4";
        o.ThemeCardShadow = "#5"; o.ThemeHintHighlight = "#6"; o.ThemeToolbarButton = "#7";

        var t = ThemeService.SnapshotFromOptions("Snap", o);

        Assert.Equal("Snap", t.Name);
        Assert.Equal("Forest", t.CardBackTheme);
        Assert.Equal(1.25, t.CardBackScale);
        Assert.Equal(3, t.CardBackOffsetX);
        Assert.Equal(-4, t.CardBackOffsetY);
        Assert.Equal(FeltColorTheme.Custom, t.FeltColor);
        Assert.Equal("#010203", t.CustomFeltColorHex);
        Assert.Equal("Beach", t.BackgroundName);
        Assert.Equal(2, t.BackgroundScale);
        Assert.Equal(5, t.BackgroundOffsetX);
        Assert.Equal(6, t.BackgroundOffsetY);
        Assert.Equal(new[] { "#1", "#2", "#3", "#4", "#5", "#6", "#7" },
            new[] { t.ThemeFaceBackNormal, t.ThemeFaceBorderNormal, t.ThemeTextRed, t.ThemeTextBlackNormal, t.ThemeCardShadow, t.ThemeHintHighlight, t.ThemeToolbarButton });
    }

    [Fact]
    public void Snapshot_IncludesTheCurrentFaceArt()
    {
        FaceCardArtService.ReplaceAll(new[]
        {
            new CustomFaceArt { Slot = FaceCardSlot.BlackKing, RelativePath = "k.png", Scale = 1.5, OffsetX = 2, OffsetY = -3, IsEnabled = true },
        });

        var art = Assert.Single(ThemeService.SnapshotFromOptions("S", Options).FaceArts);

        Assert.Equal("BlackKing", art.Slot);
        Assert.Equal("k.png", art.RelativePath);
        Assert.Equal(1.5, art.Scale);
        Assert.Equal(2, art.OffsetX);
        Assert.Equal(-3, art.OffsetY);
    }

    [Fact]
    public void ApplyTheme_CopiesTheThemeOntoTheLiveSettings()
    {
        var t = new SoliBeeTheme
        {
            Name = "T", CardBackTheme = "Forest", CardBackScale = 1.3, CardBackOffsetX = 7, CardBackOffsetY = 8,
            FeltColor = FeltColorTheme.Custom, CustomFeltColorHex = "#ABCDEF",
            BackgroundScale = 2.5, BackgroundOffsetX = 9, BackgroundOffsetY = 10,
            ThemeTextRed = "#R", ThemeTextBlackNormal = "#B", ThemeToolbarButton = "#T",
        };
        int revision = Options.CustomFeltColorRevision;

        var result = ThemeService.ApplyTheme(t, Options);

        Assert.Same(Options, result);
        Assert.Equal(t.Id, Options.ActiveThemeId);
        Assert.Equal("Forest", Options.CardBackTheme);
        Assert.Equal(1.3, Options.CardBackScale);
        Assert.Equal(7, Options.CardBackOffsetX);
        Assert.Equal(8, Options.CardBackOffsetY);
        Assert.Equal(FeltColorTheme.Custom, Options.FeltColor);
        Assert.Equal("#ABCDEF", Options.CustomFeltColorHex);
        Assert.Equal(2.5, Options.BackgroundScale);
        Assert.Equal("#R", Options.ThemeTextRed);
        Assert.Equal("#B", Options.ThemeTextBlackNormal);
        Assert.Equal("#T", Options.ThemeToolbarButton);
        Assert.Null(Options.ThemeFaceBackNormal);
        Assert.Equal(revision + 1, Options.CustomFeltColorRevision);
    }

    [Fact]
    public void ApplyTheme_KeepsItsBackground_OnlyWhileThatBackgroundStillExists()
    {
        var t = Custom("T", background: "Beach");

        Options.CustomBackgrounds.Clear();
        ThemeService.ApplyTheme(t, Options);
        Assert.Null(Options.BackgroundName);

        Options.CustomBackgrounds.Add(new CustomBackground { Name = "Beach" });
        ThemeService.ApplyTheme(t, Options);
        Assert.Equal("Beach", Options.BackgroundName);
    }

    [Fact]
    public void ApplyTheme_RestoresFaceArt_AndSkipsMissingFilesBadSlotsAndUnsafePaths()
    {
        Directory.CreateDirectory(FaceCardArtService.ArtDirectory);
        var real = Path.Combine(FaceCardArtService.ArtDirectory, "theme_test_king.png");
        File.WriteAllBytes(real, new byte[] { 1 });
        try
        {
            var t = Custom("T");
            t.FaceArts.Add(new FaceArtSnapshot { Slot = "BlackKing", RelativePath = "theme_test_king.png", Scale = 1.4, OffsetX = 1, OffsetY = 2, IsEnabled = true });
            t.FaceArts.Add(new FaceArtSnapshot { Slot = "RedQueen", RelativePath = "theme_test_gone.png" });
            t.FaceArts.Add(new FaceArtSnapshot { Slot = "NotASlot", RelativePath = "theme_test_king.png" });
            t.FaceArts.Add(new FaceArtSnapshot { Slot = "RedJack", RelativePath = "../theme_test_king.png" });

            ThemeService.ApplyTheme(t, Options);

            var art = Assert.Single(FaceCardArtService.GetAllArts());
            Assert.Equal(FaceCardSlot.BlackKing, art.Slot);
            Assert.Equal(1.4, art.Scale);
            Assert.Equal(1, art.OffsetX);
            Assert.Equal(2, art.OffsetY);
            Assert.True(File.Exists(real));
        }
        finally { File.Delete(real); }
    }

    [Fact]
    public void ApplyTheme_WithNoFaceArt_ClearsTheCurrentFaceArt()
    {
        FaceCardArtService.ReplaceAll(new[] { new CustomFaceArt { Slot = FaceCardSlot.RedAce, RelativePath = "a.png" } });

        ThemeService.ApplyTheme(Custom("T"), Options);

        Assert.Empty(FaceCardArtService.GetAllArts());
    }

    [Fact]
    public void SnapshotThenApply_RoundTripsTheLook()
    {
        Options.CardBackTheme = "Forest";
        Options.FeltColor = FeltColorTheme.Desert;
        Options.ThemeTextRed = "#FF010101";
        var snap = ThemeService.SnapshotFromOptions("Round", Options);

        Options.CardBackTheme = "Vulpera";
        Options.FeltColor = FeltColorTheme.FeltGreen;
        Options.ThemeTextRed = null;
        ThemeService.ApplyTheme(snap, Options);

        Assert.Equal("Forest", Options.CardBackTheme);
        Assert.Equal(FeltColorTheme.Desert, Options.FeltColor);
        Assert.Equal("#FF010101", Options.ThemeTextRed);
    }

    // ---- First launch ----

    [Fact]
    public void FirstLaunch_OnFactorySettings_AppliesTheDefaultTheme_AndSavesThePresetList()
    {
        Delete("themes.json");
        Options.HasAppliedDefaultTheme = false;
        Options.FeltColor = FeltColorTheme.FeltGreen;
        Options.CardBackTheme = "Vulpera";

        Assert.True(ThemeService.ApplyDefaultThemeIfNeeded(Options));

        Assert.True(Options.HasAppliedDefaultTheme);
        Assert.Equal("Solibee", Options.CardBackTheme);
        Assert.Equal(DefaultId, Options.ActiveThemeId);
        Assert.Equal(8, ThemeService.LoadThemes().Count);
        Assert.True(File.Exists(Path.Combine(AppPaths.DataDirectory, "themes.json")));
    }

    [Fact]
    public void FirstLaunch_WhenThePlayerAlreadyChangedTheLook_KeepsTheirChoices()
    {
        Options.HasAppliedDefaultTheme = false;
        Options.FeltColor = FeltColorTheme.Crimson;
        Options.CardBackTheme = "Vulpera";

        Assert.True(ThemeService.ApplyDefaultThemeIfNeeded(Options));

        Assert.True(Options.HasAppliedDefaultTheme);
        Assert.Equal(FeltColorTheme.Crimson, Options.FeltColor);
        Assert.Equal("Vulpera", Options.CardBackTheme);
        Assert.Null(Options.ActiveThemeId);

        Options.HasAppliedDefaultTheme = false;
        Options.FeltColor = FeltColorTheme.FeltGreen;
        Options.CardBackTheme = "Forest";
        ThemeService.ApplyDefaultThemeIfNeeded(Options);
        Assert.Equal("Forest", Options.CardBackTheme);
    }

    [Fact]
    public void FirstLaunch_RunsOnlyOnce()
    {
        Options.HasAppliedDefaultTheme = true;
        Options.CardBackTheme = "Vulpera";

        Assert.False(ThemeService.ApplyDefaultThemeIfNeeded(Options));
        Assert.Equal("Vulpera", Options.CardBackTheme);
    }

    [Fact]
    public void FirstLaunch_DoesNotReplaceAnExistingThemeList()
    {
        ThemeService.SaveThemes(new List<SoliBeeTheme> { Custom("Mine") });
        Options.HasAppliedDefaultTheme = false;

        ThemeService.ApplyDefaultThemeIfNeeded(Options);

        Assert.Equal("Mine", Assert.Single(ThemeService.LoadThemes()).Name);
    }

    // ---- Deleting a background / card back / face art cleans up saved themes ----

    [Fact]
    public void DeletingABackground_ClearsItFromOnlyTheThemesThatUsedIt()
    {
        var a = Custom("A", background: "Beach"); var b = Custom("B", background: "Mountain");
        ThemeService.SaveThemes(new List<SoliBeeTheme> { a, b });

        ThemeService.ClearBackgroundReferences("Beach");

        var saved = ThemeService.LoadThemes();
        Assert.Null(saved[0].BackgroundName);
        Assert.Equal("Mountain", saved[1].BackgroundName);
    }

    [Fact]
    public void DeletingACardBack_ResetsThoseThemesToTheFallbackBack()
    {
        var a = Custom("A", "MyBack"); var b = Custom("B", "Forest");
        ThemeService.SaveThemes(new List<SoliBeeTheme> { a, b });

        ThemeService.ClearCardBackReferences("MyBack", "Solibee");

        var saved = ThemeService.LoadThemes();
        Assert.Equal("Solibee", saved[0].CardBackTheme);
        Assert.Equal("Forest", saved[1].CardBackTheme);
    }

    [Fact]
    public void DeletingFaceArt_RemovesItFromEveryThemeThatUsedIt()
    {
        var ace = new FaceArtSnapshot { Slot = "BlackAce", RelativePath = "ace.png" };
        var king = new FaceArtSnapshot { Slot = "RedKing", RelativePath = "king.png" };
        var a = Custom("A"); a.FaceArts.AddRange(new[] { ace, king });
        var b = Custom("B"); b.FaceArts.Add(ace);
        ThemeService.SaveThemes(new List<SoliBeeTheme> { a, b });

        ThemeService.ClearFaceArtReferences("ace.png");

        var saved = ThemeService.LoadThemes();
        Assert.Equal("king.png", Assert.Single(saved[0].FaceArts).RelativePath);
        Assert.Empty(saved[1].FaceArts);
    }

    [Fact]
    public void ClearingAnAssetNothingUses_LeavesTheSavedFileUntouched()
    {
        var a = Custom("A", "Forest", "Beach");
        ThemeService.SaveThemes(new List<SoliBeeTheme> { a });
        var before = Read("themes.json");

        ThemeService.ClearBackgroundReferences("Nowhere");
        ThemeService.ClearCardBackReferences("Nowhere", "Solibee");
        ThemeService.ClearFaceArtReferences("nowhere.png");

        Assert.Equal(before, Read("themes.json"));
    }
}
