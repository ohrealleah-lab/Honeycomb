using System.IO;
using System.Linq;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Services;

// Saved settings: changes survive a relaunch, files from older versions (missing fields)
// still load, and a broken file falls back to defaults instead of crashing. "Relaunch" =
// forget the cached options so the next LoadOptions() reads settings.json again.
public class SettingsServiceTests : DataSandbox
{
    private static GameOptions Relaunch()
    {
        ForgetCachedSettings();
        return SettingsService.LoadOptions();
    }

    [Fact]
    public void FreshInstall_HasTheDocumentedDefaults()
    {
        Delete("settings.json");
        var o = Relaunch();

        Assert.True(o.IsSoundEnabled);
        Assert.False(o.IsNoStressMode);
        Assert.True(o.HoneyMode);
        Assert.False(o.ManuallyDismissBanners);
        Assert.False(o.HideHintButton);
        Assert.False(o.HideBee);
        Assert.True(o.IsStatusBarVisible);
        Assert.True(o.IsVignetteEnabled);
        Assert.Equal(AppLanguage.English, o.Language);
        Assert.Equal(FeltColorTheme.FeltGreen, o.FeltColor);
        Assert.Equal("Vulpera", o.CardBackTheme);
        Assert.Equal(1, o.FreecellDeckCount);
        Assert.Equal(1, o.SpiderSuitCount);
        Assert.False(o.HasAppliedDefaultTheme);
        Assert.Null(o.ActiveThemeId);
    }

    [Fact]
    public void Load_IsCached_SoEveryCallerSharesOneObject()
    {
        Assert.Same(SettingsService.LoadOptions(), SettingsService.LoadOptions());
    }

    [Fact]
    public void EverySharedSetting_SurvivesARelaunch()
    {
        var o = Options;
        o.IsSoundEnabled = false;
        o.IsNoStressMode = true;
        o.HoneyMode = false;
        o.ManuallyDismissBanners = true;
        o.HideHintButton = true;
        o.HideBee = true;
        o.IsVignetteEnabled = false;
        o.IsStatusBarVisible = false;
        o.IsAlwaysOnTop = true;
        o.IsVegasScoring = true;
        o.IsDrawConstraintsEnabled = true;
        o.Language = AppLanguage.Spanish;
        o.FreecellDeckCount = 2;
        o.SpiderSuitCount = 4;
        o.LastGameMode = "Spider";
        o.HoneycombActiveDeckIndex = 3;
        SettingsService.SaveOptions(o);

        var again = Relaunch();

        Assert.NotSame(o, again);
        Assert.False(again.IsSoundEnabled);
        Assert.True(again.IsNoStressMode);
        Assert.False(again.HoneyMode);
        Assert.True(again.ManuallyDismissBanners);
        Assert.True(again.HideHintButton);
        Assert.True(again.HideBee);
        Assert.False(again.IsVignetteEnabled);
        Assert.False(again.IsStatusBarVisible);
        Assert.True(again.IsAlwaysOnTop);
        Assert.True(again.IsVegasScoring);
        Assert.True(again.IsDrawConstraintsEnabled);
        Assert.Equal(AppLanguage.Spanish, again.Language);
        Assert.Equal(2, again.FreecellDeckCount);
        Assert.Equal(4, again.SpiderSuitCount);
        Assert.Equal("Spider", again.LastGameMode);
        Assert.Equal(3, again.HoneycombActiveDeckIndex);
    }

    [Fact]
    public void LookSettings_SurviveARelaunch()
    {
        var o = Options;
        o.FeltColor = FeltColorTheme.Custom;
        o.CustomFeltColorHex = "#123456";
        o.CardBackTheme = "Forest";
        o.CardBackScale = 1.5;
        o.CardBackOffsetX = 4;
        o.CardBackOffsetY = -6;
        o.BackgroundName = "Beach";
        o.BackgroundScale = 2;
        o.ThemeTextRed = "#FFAA0000";
        o.ThemeToolbarButton = "#FF00FF00";
        o.CustomBackgrounds.Add(new CustomBackground { Name = "Beach" });
        o.CustomCardBacks.Add(new CustomCardBack { Name = "Mine" });
        o.ActiveThemeId = System.Guid.NewGuid();
        SettingsService.SaveOptions(o);

        var again = Relaunch();

        Assert.Equal(FeltColorTheme.Custom, again.FeltColor);
        Assert.Equal("#123456", again.CustomFeltColorHex);
        Assert.Equal("Forest", again.CardBackTheme);
        Assert.Equal(1.5, again.CardBackScale);
        Assert.Equal(4, again.CardBackOffsetX);
        Assert.Equal(-6, again.CardBackOffsetY);
        Assert.Equal("Beach", again.BackgroundName);
        Assert.Equal(2, again.BackgroundScale);
        Assert.Equal("#FFAA0000", again.ThemeTextRed);
        Assert.Equal("#FF00FF00", again.ThemeToolbarButton);
        Assert.Equal("Beach", Assert.Single(again.CustomBackgrounds).Name);
        Assert.Equal("Mine", Assert.Single(again.CustomCardBacks).Name);
        Assert.Equal(o.ActiveThemeId, again.ActiveThemeId);
    }

    [Fact]
    public void WindowSizes_AreRememberedPerGame()
    {
        var o = Options;
        o.KlondikeWidth = 801; o.KlondikeMaximized = true;
        o.SpiderHeight = 902;
        o.BlackjackWidth = 703;
        o.HoneycombMaximized = true;
        SettingsService.SaveOptions(o);

        var again = Relaunch();

        Assert.Equal(801, again.KlondikeWidth);
        Assert.True(again.KlondikeMaximized);
        Assert.Equal(902, again.SpiderHeight);
        Assert.Equal(703, again.BlackjackWidth);
        Assert.True(again.HoneycombMaximized);
        Assert.False(again.FreecellMaximized);
    }

    [Fact]
    public void ChangingASettingTwice_KeepsTheLatestValue()
    {
        Options.Language = AppLanguage.Spanish;
        SettingsService.SaveOptions(Options);
        Options.Language = AppLanguage.English;
        SettingsService.SaveOptions(Options);

        Assert.Equal(AppLanguage.English, Relaunch().Language);
    }

    [Fact]
    public void Save_LeavesNoTemporaryFilesBehind()
    {
        SettingsService.SaveOptions(Options);
        SettingsService.SaveOptions(Options);

        Assert.True(File.Exists(Path.Combine(AppPaths.DataDirectory, "settings.json")));
        Assert.Empty(Directory.GetFiles(AppPaths.DataDirectory, "*.tmp"));
    }

    // A save from an older version that didn't know about newer settings.
    [Fact]
    public void OldSave_WithMissingFields_KeepsWhatItHasAndDefaultsTheRest()
    {
        Write("settings.json", "{\"IsNoStressMode\":true,\"CardBackTheme\":\"Forest\"}");
        var o = Relaunch();

        Assert.True(o.IsNoStressMode);
        Assert.Equal("Forest", o.CardBackTheme);
        Assert.True(o.HoneyMode);
        Assert.True(o.IsSoundEnabled);
        Assert.False(o.ManuallyDismissBanners);
        Assert.Equal(FeltColorTheme.FeltGreen, o.FeltColor);
        Assert.Equal(1, o.SpiderSuitCount);
    }

    [Fact]
    public void EmptyObject_LoadsAsDefaults()
    {
        Write("settings.json", "{}");
        var o = Relaunch();

        Assert.True(o.IsSoundEnabled);
        Assert.False(o.IsNoStressMode);
        Assert.Equal(AppLanguage.English, o.Language);
    }

    [Theory]
    [InlineData("")]
    [InlineData("not json at all")]
    [InlineData("{\"IsNoStressMode\":tru")]
    [InlineData("null")]
    [InlineData("[1,2,3]")]
    public void BrokenFile_FallsBackToDefaults_AndDoesNotThrow(string contents)
    {
        Write("settings.json", contents);
        var o = Relaunch();

        Assert.NotNull(o);
        Assert.True(o.IsSoundEnabled);
        Assert.False(o.IsNoStressMode);
        Assert.True(o.HoneyMode);
    }

    [Fact]
    public void BrokenFile_IsReplacedByTheNextSave()
    {
        Write("settings.json", "garbage");
        var o = Relaunch();
        o.IsNoStressMode = true;
        SettingsService.SaveOptions(o);

        Assert.True(Relaunch().IsNoStressMode);
    }

    // ---- Honeycomb's own settings file ----

    [Fact]
    public void HoneycombOptions_DefaultWhenNeverSaved()
    {
        Delete("honeycomb_settings.json");
        var o = SettingsService.LoadHoneycombOptions();

        Assert.False(o.ForceNormalRules);
        Assert.Empty(o.ManualRules);
        Assert.Equal(HoneycombDifficulty.Easy, o.Difficulty);
        Assert.Empty(o.BannedRules);
        Assert.False(o.HideHintButton);
    }

    [Fact]
    public void HoneycombOptions_SurviveARelaunch()
    {
        var o = new HoneycombOptions
        {
            ForceNormalRules = true,
            Difficulty = HoneycombDifficulty.Hard,
            HideHintButton = true,
        };
        o.ManualRules.Add(HoneycombRule.Same);
        o.BannedRules.Add("Plus");
        SettingsService.SaveHoneycombOptions(o);

        var again = SettingsService.LoadHoneycombOptions();

        Assert.True(again.ForceNormalRules);
        Assert.Equal(HoneycombDifficulty.Hard, again.Difficulty);
        Assert.True(again.HideHintButton);
        Assert.Contains(HoneycombRule.Same, again.ManualRules);
        Assert.Contains("Plus", again.BannedRules);
    }

    // The difficulty is stored by name, so a file written by an older version still loads.
    [Fact]
    public void HoneycombOptions_DifficultyIsStoredByName()
    {
        SettingsService.SaveHoneycombOptions(new HoneycombOptions { Difficulty = HoneycombDifficulty.Medium });
        Assert.Contains("\"Medium\"", Read("honeycomb_settings.json"));

        Write("honeycomb_settings.json", "{\"Difficulty\":\"Hard\",\"ForceNormalRules\":true}");
        var o = SettingsService.LoadHoneycombOptions();
        Assert.Equal(HoneycombDifficulty.Hard, o.Difficulty);
        Assert.True(o.ForceNormalRules);
        Assert.False(o.HideHintButton);
    }

    [Theory]
    [InlineData("")]
    [InlineData("nope")]
    [InlineData("{\"Difficulty\":\"Impossible\"}")]
    public void HoneycombOptions_BrokenFile_FallsBackToDefaults(string contents)
    {
        Write("honeycomb_settings.json", contents);
        var o = SettingsService.LoadHoneycombOptions();

        Assert.Equal(HoneycombDifficulty.Easy, o.Difficulty);
        Assert.False(o.ForceNormalRules);
    }
}
