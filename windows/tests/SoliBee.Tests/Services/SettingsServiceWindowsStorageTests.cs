using System;
using System.Collections.Generic;
using System.IO;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Services;

// On a real Windows install SettingsService keeps settings in Windows' own per-app storage
// (ApplicationData.Current.LocalSettings) and only uses settings.json as a fallback — so the
// file-based tests never touch the code real players actually run. These tests stand in a fake
// of that storage (a plain dictionary behind a `Values` property) so that path is exercised on
// any machine: every saved setting comes back after a "relaunch", and wrong or missing values
// fall back safely.
public class SettingsServiceWindowsStorageTests : DataSandbox, IDisposable
{
    private sealed class FakeLocalSettings
    {
        public Dictionary<string, object> Values { get; } = new();
    }

    private readonly FakeLocalSettings _storage = new();

    public SettingsServiceWindowsStorageTests() => SettingsService.LocalSettingsOverride = () => _storage;

    public new void Dispose()
    {
        SettingsService.LocalSettingsOverride = null;
        base.Dispose();
    }

    private static GameOptions Relaunch()
    {
        ForgetCachedSettings();
        return SettingsService.LoadOptions();
    }

    private static string SettingsFile => Path.Combine(AppPaths.DataDirectory, "settings.json");

    [Fact]
    public void Saving_GoesToWindowsStorage_NotTheFile()
    {
        Delete("settings.json");
        var o = Options;
        o.IsNoStressMode = true;
        SettingsService.SaveOptions(o);

        Assert.Equal(true, _storage.Values["IsNoStressMode"]);
        Assert.False(File.Exists(SettingsFile));
    }

    [Fact]
    public void EverySetting_SurvivesARelaunch_ThroughWindowsStorage()
    {
        var o = Options;
        o.IsSoundEnabled = false;
        o.IsNoStressMode = true;
        o.HoneyMode = false;
        o.HideBee = true;
        o.HideHintButton = true;
        o.IsVignetteEnabled = false;
        o.IsStatusBarVisible = false;
        o.IsAlwaysOnTop = true;
        o.IsVegasScoring = true;
        o.IsDrawConstraintsEnabled = true;
        o.Language = AppLanguage.Spanish;
        o.FreecellDeckCount = 2;
        o.SpiderSuitCount = 4;
        o.LastGameMode = "Blackjack";
        o.HoneycombActiveDeckIndex = 2;
        o.HasAppliedDefaultTheme = true;
        o.FeltColor = FeltColorTheme.Custom;
        o.CustomFeltColorHex = "#123456";
        o.CustomFeltColorRevision = 7;
        o.CardBackTheme = "Forest";
        o.CardBackScale = 1.25;
        o.CardBackOffsetX = 3.5;
        o.CardBackOffsetY = -2.5;
        o.VignetteScale = 0.8;
        o.BackgroundName = "Beach";
        o.BackgroundScale = 1.7;
        o.BackgroundOffsetX = 11;
        o.BackgroundOffsetY = -12;
        o.ThemeFaceBackNormal = "#FF111111";
        o.ThemeFaceBorderNormal = "#FF222222";
        o.ThemeTextRed = "#FF333333";
        o.ThemeTextBlackNormal = "#FF444444";
        o.CustomBackgrounds.Add(new CustomBackground { Name = "Beach" });
        o.CustomCardBacks.Add(new CustomCardBack { Name = "Mine" });
        o.KlondikeWatermarkScale = 1.1; o.FreecellWatermarkScale = 1.2; o.SpiderWatermarkScale = 1.3;
        o.VideoPokerWatermarkScale = 1400; o.BlackjackWatermarkScale = 1500; o.HoneycombWatermarkScale = 1.6;
        o.KlondikeWatermarkOffsetX = -1; o.KlondikeWatermarkOffsetY = -2;
        o.FreecellWatermarkOffsetX = -3; o.FreecellWatermarkOffsetY = -4;
        o.SpiderWatermarkOffsetX = -5; o.SpiderWatermarkOffsetY = -6;
        o.VideoPokerWatermarkOffsetX = -7; o.VideoPokerWatermarkOffsetY = -8;
        o.BlackjackWatermarkOffsetX = -9; o.BlackjackWatermarkOffsetY = -10;
        o.HoneycombWatermarkOffsetX = -11; o.HoneycombWatermarkOffsetY = -12;
        o.KlondikeWidth = 801; o.KlondikeHeight = 601; o.KlondikeMaximized = true;
        o.FreecellWidth = 802; o.FreecellHeight = 602; o.FreecellMaximized = true;
        o.SpiderWidth = 803; o.SpiderHeight = 603; o.SpiderMaximized = true;
        o.VideoPokerWidth = 804; o.VideoPokerHeight = 604; o.VideoPokerMaximized = true;
        o.BlackjackWidth = 805; o.BlackjackHeight = 605; o.BlackjackMaximized = true;
        SettingsService.SaveOptions(o);

        var a = Relaunch();

        Assert.NotSame(o, a);
        Assert.False(a.IsSoundEnabled);
        Assert.True(a.IsNoStressMode);
        Assert.False(a.HoneyMode);
        Assert.True(a.HideBee);
        Assert.True(a.HideHintButton);
        Assert.False(a.IsVignetteEnabled);
        Assert.False(a.IsStatusBarVisible);
        Assert.True(a.IsAlwaysOnTop);
        Assert.True(a.IsVegasScoring);
        Assert.True(a.IsDrawConstraintsEnabled);
        Assert.Equal(AppLanguage.Spanish, a.Language);
        Assert.Equal(2, a.FreecellDeckCount);
        Assert.Equal(4, a.SpiderSuitCount);
        Assert.Equal("Blackjack", a.LastGameMode);
        Assert.Equal(2, a.HoneycombActiveDeckIndex);
        Assert.True(a.HasAppliedDefaultTheme);
        Assert.Equal(FeltColorTheme.Custom, a.FeltColor);
        Assert.Equal("#123456", a.CustomFeltColorHex);
        Assert.Equal(7, a.CustomFeltColorRevision);
        Assert.Equal("Forest", a.CardBackTheme);
        Assert.Equal(1.25, a.CardBackScale);
        Assert.Equal(3.5, a.CardBackOffsetX);
        Assert.Equal(-2.5, a.CardBackOffsetY);
        Assert.Equal(0.8, a.VignetteScale);
        Assert.Equal("Beach", a.BackgroundName);
        Assert.Equal(1.7, a.BackgroundScale);
        Assert.Equal(11, a.BackgroundOffsetX);
        Assert.Equal(-12, a.BackgroundOffsetY);
        Assert.Equal("#FF111111", a.ThemeFaceBackNormal);
        Assert.Equal("#FF222222", a.ThemeFaceBorderNormal);
        Assert.Equal("#FF333333", a.ThemeTextRed);
        Assert.Equal("#FF444444", a.ThemeTextBlackNormal);
        Assert.Equal("Beach", Assert.Single(a.CustomBackgrounds).Name);
        Assert.Equal("Mine", Assert.Single(a.CustomCardBacks).Name);
        Assert.Equal((1.1, 1.2, 1.3, 1400.0, 1500.0, 1.6),
            (a.KlondikeWatermarkScale, a.FreecellWatermarkScale, a.SpiderWatermarkScale,
             a.VideoPokerWatermarkScale, a.BlackjackWatermarkScale, a.HoneycombWatermarkScale));
        Assert.Equal(new[] { -1.0, -2, -3, -4, -5, -6, -7, -8, -9, -10, -11, -12 },
            new[] { a.KlondikeWatermarkOffsetX, a.KlondikeWatermarkOffsetY, a.FreecellWatermarkOffsetX, a.FreecellWatermarkOffsetY,
                    a.SpiderWatermarkOffsetX, a.SpiderWatermarkOffsetY, a.VideoPokerWatermarkOffsetX, a.VideoPokerWatermarkOffsetY,
                    a.BlackjackWatermarkOffsetX, a.BlackjackWatermarkOffsetY, a.HoneycombWatermarkOffsetX, a.HoneycombWatermarkOffsetY });
        Assert.Equal((801.0, 601.0, true), (a.KlondikeWidth, a.KlondikeHeight, a.KlondikeMaximized));
        Assert.Equal((802.0, 602.0, true), (a.FreecellWidth, a.FreecellHeight, a.FreecellMaximized));
        Assert.Equal((803.0, 603.0, true), (a.SpiderWidth, a.SpiderHeight, a.SpiderMaximized));
        Assert.Equal((804.0, 604.0, true), (a.VideoPokerWidth, a.VideoPokerHeight, a.VideoPokerMaximized));
        Assert.Equal((805.0, 605.0, true), (a.BlackjackWidth, a.BlackjackHeight, a.BlackjackMaximized));
    }

    [Fact]
    public void ClearingAThemeColour_RemovesItFromStorage_SoItStaysCleared()
    {
        var o = Options;
        o.ThemeTextRed = "#FF333333";
        o.BackgroundName = "Beach";
        SettingsService.SaveOptions(o);
        Assert.True(_storage.Values.ContainsKey("ThemeTextRed"));
        Assert.True(_storage.Values.ContainsKey("BackgroundName"));

        o.ThemeTextRed = null;
        o.BackgroundName = null;
        SettingsService.SaveOptions(o);

        Assert.False(_storage.Values.ContainsKey("ThemeTextRed"));
        Assert.False(_storage.Values.ContainsKey("BackgroundName"));
        var a = Relaunch();
        Assert.Null(a.ThemeTextRed);
        Assert.Null(a.BackgroundName);
    }

    [Fact]
    public void EmptyStorage_LoadsTheDefaults()
    {
        var a = Relaunch();
        Assert.True(a.IsSoundEnabled);
        Assert.False(a.IsNoStressMode);
        Assert.True(a.HoneyMode);
        Assert.Equal(AppLanguage.English, a.Language);
        Assert.Equal(FeltColorTheme.FeltGreen, a.FeltColor);
        Assert.Equal(1, a.SpiderSuitCount);
    }

    [Fact]
    public void AValueOfTheWrongType_IsIgnored_AndTheRestStillLoad()
    {
        _storage.Values["IsSoundEnabled"] = "no";            // should be true/false
        _storage.Values["SpiderSuitCount"] = "four";         // should be a number
        _storage.Values["CardBackScale"] = 3;                // an int where a decimal is expected
        _storage.Values["FeltColor"] = "NotAColour";         // not a real felt colour
        _storage.Values["Language"] = "Klingon";             // not a real language
        _storage.Values["IsNoStressMode"] = true;            // a good one
        _storage.Values["CardBackTheme"] = "Forest";         // a good one

        var a = Relaunch();

        Assert.True(a.IsSoundEnabled);                       // default kept
        Assert.Equal(1, a.SpiderSuitCount);
        Assert.Equal(1.0, a.CardBackScale);
        Assert.Equal(FeltColorTheme.FeltGreen, a.FeltColor);
        Assert.Equal(AppLanguage.English, a.Language);
        Assert.True(a.IsNoStressMode);
        Assert.Equal("Forest", a.CardBackTheme);
    }

    [Fact]
    public void DamagedCustomListJson_LoadsAsEmptyLists_WithoutLosingOtherSettings()
    {
        _storage.Values["CustomCardBacksJson"] = "{ not json";
        _storage.Values["CustomBackgroundsJson"] = "[1, 2,";
        _storage.Values["IsNoStressMode"] = true;

        var a = Relaunch();

        Assert.Empty(a.CustomCardBacks);
        Assert.Empty(a.CustomBackgrounds);
        Assert.True(a.IsNoStressMode);
    }

    [Fact]
    public void WindowsStorage_WinsOverAnOldSettingsFile()
    {
        Write("settings.json", "{\"IsNoStressMode\":true,\"CardBackTheme\":\"FromFile\"}");
        _storage.Values["CardBackTheme"] = "FromStorage";

        var a = Relaunch();

        Assert.Equal("FromStorage", a.CardBackTheme);
        Assert.False(a.IsNoStressMode);   // storage is the source of truth once it exists; the file isn't merged in
    }

    [Fact]
    public void HoneycombOptions_SurviveARelaunch_ThroughWindowsStorage()
    {
        Delete("honeycomb_settings.json");
        var o = new HoneycombOptions { ForceNormalRules = true, Difficulty = HoneycombDifficulty.Hard, HideHintButton = true };
        o.ManualRules.Add(HoneycombRule.Same);
        o.BannedRules.Add("Plus");
        SettingsService.SaveHoneycombOptions(o);

        Assert.Contains("\"Hard\"", (string)_storage.Values["HoneycombOptionsJson"]);
        Assert.False(File.Exists(Path.Combine(AppPaths.DataDirectory, "honeycomb_settings.json")));

        var a = SettingsService.LoadHoneycombOptions();
        Assert.True(a.ForceNormalRules);
        Assert.Equal(HoneycombDifficulty.Hard, a.Difficulty);
        Assert.True(a.HideHintButton);
        Assert.Contains(HoneycombRule.Same, a.ManualRules);
        Assert.Contains("Plus", a.BannedRules);
    }

    [Fact]
    public void HoneycombOptions_DamagedStorageValue_FallsBackToTheFile()
    {
        _storage.Values["HoneycombOptionsJson"] = "garbage";
        Write("honeycomb_settings.json", "{\"Difficulty\":\"Medium\"}");

        var a = SettingsService.LoadHoneycombOptions();

        Assert.Equal(HoneycombDifficulty.Medium, a.Difficulty);
    }

    [Fact]
    public void HoneycombOptions_EmptyStorage_LoadsDefaults()
    {
        Delete("honeycomb_settings.json");
        var a = SettingsService.LoadHoneycombOptions();
        Assert.Equal(HoneycombDifficulty.Easy, a.Difficulty);
        Assert.False(a.ForceNormalRules);
    }
}
