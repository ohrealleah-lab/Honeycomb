using System;
using System.IO;
using System.Reflection;
using System.Text.Json;
using SoliBee.Core.Models;

namespace SoliBee.Core.Services;

public static class SettingsService
{
    private static GameOptions? _cache;

    private static readonly string FallbackDirectory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "SoliBee"
    );
    private static readonly string FallbackFilePath = Path.Combine(FallbackDirectory, "settings.json");

    private static object? GetLocalSettings()
    {
        try
        {
            var appDataType = Type.GetType("Windows.Storage.ApplicationData, Windows, Version=255.255.255.255, Culture=neutral, PublicKeyToken=null, ContentType=WindowsRuntime");
            if (appDataType == null) return null;
            var currentProp = appDataType.GetProperty("Current", BindingFlags.Public | BindingFlags.Static);
            if (currentProp == null) return null;
            var currentInstance = currentProp.GetValue(null);
            if (currentInstance == null) return null;
            var localSettingsProp = currentInstance.GetType().GetProperty("LocalSettings", BindingFlags.Public | BindingFlags.Instance);
            if (localSettingsProp == null) return null;
            return localSettingsProp.GetValue(currentInstance);
        }
        catch
        {
            return null;
        }
    }

    private static object? GetValue(string key)
    {
        var localSettings = GetLocalSettings();
        if (localSettings == null) return null;
        try
        {
            var valuesProp = localSettings.GetType().GetProperty("Values", BindingFlags.Public | BindingFlags.Instance);
            if (valuesProp == null) return null;
            var values = valuesProp.GetValue(localSettings);
            if (values == null) return null;
            
            // Try IDictionary interface indexer
            var itemProp = values.GetType().GetProperty("Item", new[] { typeof(string) });
            if (itemProp != null)
            {
                return itemProp.GetValue(values, new object[] { key });
            }

            var lookupMethod = values.GetType().GetMethod("Lookup", new[] { typeof(string) });
            if (lookupMethod != null)
            {
                return lookupMethod.Invoke(values, new object[] { key });
            }
        }
        catch
        {
            // Ignore and fallback
        }
        return null;
    }

    private static void SetValue(string key, object value)
    {
        var localSettings = GetLocalSettings();
        if (localSettings == null) return;
        try
        {
            var valuesProp = localSettings.GetType().GetProperty("Values", BindingFlags.Public | BindingFlags.Instance);
            if (valuesProp == null) return;
            var values = valuesProp.GetValue(localSettings);
            if (values == null) return;

            // Try IDictionary interface indexer
            var itemProp = values.GetType().GetProperty("Item", new[] { typeof(string) });
            if (itemProp != null)
            {
                itemProp.SetValue(values, value, new object[] { key });
                return;
            }

            var insertMethod = values.GetType().GetMethod("Insert", new[] { typeof(string), typeof(object) });
            if (insertMethod != null)
            {
                insertMethod.Invoke(values, new object[] { key, value });
            }
        }
        catch
        {
            // Ignore
        }
    }

    private static void RemoveValue(string key)
    {
        var localSettings = GetLocalSettings();
        if (localSettings == null) return;
        try
        {
            var valuesProp = localSettings.GetType().GetProperty("Values", BindingFlags.Public | BindingFlags.Instance);
            if (valuesProp == null) return;
            var values = valuesProp.GetValue(localSettings);
            if (values == null) return;
            var removeMethod = values.GetType().GetMethod("Remove", new[] { typeof(string) });
            removeMethod?.Invoke(values, new object[] { key });
        }
        catch { }
    }

    public static GameOptions LoadOptions()
    {
        if (_cache != null) return _cache;

        var options = new GameOptions();
        var localSettings = GetLocalSettings();

        if (localSettings != null)
        {
            try
            {
                if (GetValue("FeltColor") is string feltColorStr && Enum.TryParse<FeltColorTheme>(feltColorStr, out var feltColor))
                    options.FeltColor = feltColor;
                
                if (GetValue("CardBackTheme") is string cardBack)
                    options.CardBackTheme = cardBack;

                if (GetValue("IsNoStressMode") is bool isNoStress)
                    options.IsNoStressMode = isNoStress;

                if (GetValue("IsSoundEnabled") is bool isSound)
                    options.IsSoundEnabled = isSound;

                if (GetValue("IsVegasScoring") is bool isVegas)
                    options.IsVegasScoring = isVegas;

                if (GetValue("IsDrawConstraintsEnabled") is bool isDrawC)
                    options.IsDrawConstraintsEnabled = isDrawC;

                if (GetValue("CustomFeltColorRevision") is int rev)
                    options.CustomFeltColorRevision = rev;

                if (GetValue("CustomFeltColorHex") is string hex)
                    options.CustomFeltColorHex = hex;

                if (GetValue("CustomCardBacksJson") is string jsonStr)
                {
                    try
                    {
                        options.CustomCardBacks = JsonSerializer.Deserialize<List<CustomCardBack>>(jsonStr) ?? new();
                    }
                    catch {}
                }

                if (GetValue("CardBackScale") is double scale)
                    options.CardBackScale = scale;

                if (GetValue("CardBackOffsetX") is double offsetX)
                    options.CardBackOffsetX = offsetX;

                if (GetValue("CardBackOffsetY") is double offsetY)
                    options.CardBackOffsetY = offsetY;

                if (GetValue("IsVignetteEnabled") is bool isVignette)
                    options.IsVignetteEnabled = isVignette;
                if (GetValue("IsStatusBarVisible") is bool isStatusBar)
                    options.IsStatusBarVisible = isStatusBar;

                if (GetValue("HideHintButton") is bool hideHint)
                    options.HideHintButton = hideHint;

                if (GetValue("HideZoomControls") is bool hideZoom)
                    options.HideZoomControls = hideZoom;

                if (GetValue("FreecellDeckCount") is int freecellDeck)
                    options.FreecellDeckCount = freecellDeck;

                if (GetValue("SpiderSuitCount") is int spiderSuits)
                    options.SpiderSuitCount = spiderSuits;

                if (GetValue("HasAppliedDefaultTheme") is bool hat) options.HasAppliedDefaultTheme = hat;
                if (GetValue("LastGameMode") is string lgm) options.LastGameMode = lgm;

                if (GetValue("KlondikeZoom")   is double kz)  options.KlondikeZoom   = kz;
                if (GetValue("FreecellZoom")    is double bz)  options.FreecellZoom    = bz;
                if (GetValue("SpiderZoom")     is double spz) options.SpiderZoom     = spz;
                if (GetValue("VideoPokerZoom") is double vpz) options.VideoPokerZoom = vpz;
                if (GetValue("VignetteScale")  is double vsc) options.VignetteScale  = vsc;

                if (GetValue("KlondikeDefaultZoom")   is double kdz)  options.KlondikeDefaultZoom   = kdz;
                if (GetValue("FreecellDefaultZoom")    is double bdz)  options.FreecellDefaultZoom    = bdz;
                if (GetValue("SpiderDefaultZoom")     is double sdz) options.SpiderDefaultZoom     = sdz;
                if (GetValue("VideoPokerDefaultZoom") is double vdz) options.VideoPokerDefaultZoom = vdz;
                if (GetValue("BlackjackDefaultZoom")  is double jdz) options.BlackjackDefaultZoom  = jdz;

                if (GetValue("KlondikeWidth")       is double klW)  options.KlondikeWidth       = klW;
                if (GetValue("KlondikeHeight")      is double klH)  options.KlondikeHeight      = klH;
                if (GetValue("KlondikeMaximized")   is bool   klM)  options.KlondikeMaximized   = klM;
                if (GetValue("FreecellWidth")        is double bcW)  options.FreecellWidth        = bcW;
                if (GetValue("FreecellHeight")       is double bcH)  options.FreecellHeight       = bcH;
                if (GetValue("FreecellMaximized")    is bool   bcM)  options.FreecellMaximized    = bcM;
                if (GetValue("SpiderWidth")         is double spW)  options.SpiderWidth         = spW;
                if (GetValue("SpiderHeight")        is double spH)  options.SpiderHeight        = spH;
                if (GetValue("SpiderMaximized")     is bool   spM)  options.SpiderMaximized     = spM;
                if (GetValue("VideoPokerWidth")     is double vpW)  options.VideoPokerWidth     = vpW;
                if (GetValue("VideoPokerHeight")    is double vpH)  options.VideoPokerHeight    = vpH;
                if (GetValue("VideoPokerMaximized") is bool   vpM)  options.VideoPokerMaximized = vpM;
                if (GetValue("BlackjackZoom")      is double bjz)  options.BlackjackZoom      = bjz;
                if (GetValue("BlackjackWidth")     is double bjW)  options.BlackjackWidth     = bjW;
                if (GetValue("BlackjackHeight")    is double bjH)  options.BlackjackHeight    = bjH;
                if (GetValue("BlackjackMaximized") is bool   bjM)  options.BlackjackMaximized = bjM;

                if (GetValue("ThemeFaceBackNormal")  is string t1) options.ThemeFaceBackNormal  = t1;
                if (GetValue("ThemeFaceBorderNormal") is string t3) options.ThemeFaceBorderNormal = t3;
                if (GetValue("ThemeTextRed")          is string t6) options.ThemeTextRed          = t6;
                if (GetValue("ThemeTextBlackNormal")  is string t8) options.ThemeTextBlackNormal  = t8;

                if (GetValue("BackgroundName") is string bgName) options.BackgroundName = bgName;
                if (GetValue("BackgroundScale") is double bgScale) options.BackgroundScale = bgScale;
                if (GetValue("BackgroundOffsetX") is double bgOffX) options.BackgroundOffsetX = bgOffX;
                if (GetValue("BackgroundOffsetY") is double bgOffY) options.BackgroundOffsetY = bgOffY;

                if (GetValue("CustomBackgroundsJson") is string cbgJsonStr)
                {
                    try
                    {
                        options.CustomBackgrounds = JsonSerializer.Deserialize<List<CustomBackground>>(cbgJsonStr) ?? new();
                    }
                    catch (JsonException ex)
                    {
                        System.Diagnostics.Debug.WriteLine($"[SettingsService] Failed to deserialize CustomBackgroundsJson: {ex.Message}");
                    }
                }

                _cache = options;
                return options;
            }
            catch
            {
                // Fall through to fallback
            }
        }

        // Fallback file-based settings for testing/macOS
        try
        {
            if (File.Exists(FallbackFilePath))
            {
                var json = File.ReadAllText(FallbackFilePath);
                var loaded = JsonSerializer.Deserialize<GameOptions>(json);
                if (loaded != null) { _cache = loaded; return loaded; }
            }
        }
        catch
        {
            // Keep default options
        }

        _cache = options;
        return options;
    }

    public static void SaveOptions(GameOptions options)
    {
        _cache = options;

        var localSettings = GetLocalSettings();
        if (localSettings != null)
        {
            try
            {
                SetValue("FeltColor", options.FeltColor.ToString());
                SetValue("CardBackTheme", options.CardBackTheme);
                SetValue("IsNoStressMode", options.IsNoStressMode);
                SetValue("IsSoundEnabled", options.IsSoundEnabled);
                SetValue("IsVegasScoring", options.IsVegasScoring);
                SetValue("IsDrawConstraintsEnabled", options.IsDrawConstraintsEnabled);
                SetValue("CustomFeltColorRevision", options.CustomFeltColorRevision);
                SetValue("CustomFeltColorHex", options.CustomFeltColorHex);
                SetValue("CardBackScale", options.CardBackScale);
                SetValue("CardBackOffsetX", options.CardBackOffsetX);
                SetValue("CardBackOffsetY", options.CardBackOffsetY);
                SetValue("IsVignetteEnabled", options.IsVignetteEnabled);
                SetValue("IsStatusBarVisible", options.IsStatusBarVisible);
                SetValue("HideHintButton", options.HideHintButton);
                SetValue("HideZoomControls", options.HideZoomControls);
                SetValue("FreecellDeckCount", options.FreecellDeckCount);
                SetValue("SpiderSuitCount", options.SpiderSuitCount);

                SetValue("HasAppliedDefaultTheme", options.HasAppliedDefaultTheme);
                SetValue("LastGameMode", options.LastGameMode);

                SetValue("KlondikeZoom",   options.KlondikeZoom);
                SetValue("FreecellZoom",    options.FreecellZoom);
                SetValue("SpiderZoom",     options.SpiderZoom);
                SetValue("VideoPokerZoom", options.VideoPokerZoom);
                SetValue("VignetteScale",  options.VignetteScale);

                SetValue("KlondikeDefaultZoom",   options.KlondikeDefaultZoom);
                SetValue("FreecellDefaultZoom",    options.FreecellDefaultZoom);
                SetValue("SpiderDefaultZoom",     options.SpiderDefaultZoom);
                SetValue("VideoPokerDefaultZoom", options.VideoPokerDefaultZoom);
                SetValue("BlackjackDefaultZoom",  options.BlackjackDefaultZoom);

                SetValue("KlondikeWidth",       options.KlondikeWidth);
                SetValue("KlondikeHeight",      options.KlondikeHeight);
                SetValue("KlondikeMaximized",   options.KlondikeMaximized);
                SetValue("FreecellWidth",        options.FreecellWidth);
                SetValue("FreecellHeight",       options.FreecellHeight);
                SetValue("FreecellMaximized",    options.FreecellMaximized);
                SetValue("SpiderWidth",         options.SpiderWidth);
                SetValue("SpiderHeight",        options.SpiderHeight);
                SetValue("SpiderMaximized",     options.SpiderMaximized);
                SetValue("VideoPokerWidth",     options.VideoPokerWidth);
                SetValue("VideoPokerHeight",    options.VideoPokerHeight);
                SetValue("VideoPokerMaximized", options.VideoPokerMaximized);
                SetValue("BlackjackZoom",      options.BlackjackZoom);
                SetValue("BlackjackWidth",     options.BlackjackWidth);
                SetValue("BlackjackHeight",    options.BlackjackHeight);
                SetValue("BlackjackMaximized", options.BlackjackMaximized);

                void WriteOrClear(string k, string? v) { if (v != null) SetValue(k, v); else RemoveValue(k); }
                WriteOrClear("ThemeFaceBackNormal",  options.ThemeFaceBackNormal);
                WriteOrClear("ThemeFaceBorderNormal",options.ThemeFaceBorderNormal);
                WriteOrClear("ThemeTextRed",         options.ThemeTextRed);
                WriteOrClear("ThemeTextBlackNormal", options.ThemeTextBlackNormal);
                WriteOrClear("BackgroundName",       options.BackgroundName);

                SetValue("BackgroundScale",   options.BackgroundScale);
                SetValue("BackgroundOffsetX", options.BackgroundOffsetX);
                SetValue("BackgroundOffsetY", options.BackgroundOffsetY);

                try
                {
                    var jsonStr = JsonSerializer.Serialize(options.CustomCardBacks);
                    SetValue("CustomCardBacksJson", jsonStr);
                }
                catch {}

                try
                {
                    var cbgJsonStr = JsonSerializer.Serialize(options.CustomBackgrounds);
                    SetValue("CustomBackgroundsJson", cbgJsonStr);
                }
                catch (JsonException ex)
                {
                    System.Diagnostics.Debug.WriteLine($"[SettingsService] Failed to serialize CustomBackgrounds: {ex.Message}");
                }

                return;
            }
            catch
            {
                // Fall through to fallback
            }
        }

        // Fallback file-based settings
        try
        {
            if (!Directory.Exists(FallbackDirectory))
            {
                Directory.CreateDirectory(FallbackDirectory);
            }
            var json = JsonSerializer.Serialize(options, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(FallbackFilePath, json);
        }
        catch
        {
            // Ignore
        }
    }
}
