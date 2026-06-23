using System;
using System.IO;
using System.Reflection;
using System.Text.Json;
using SoliBee.Core.Models;

namespace SoliBee.Core.Services;

public static class SettingsService
{
    private static readonly string FallbackDirectory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "SoliBee"
    );
    private static readonly string FallbackFilePath = Path.Combine(FallbackDirectory, "settings.json");

    private static object GetLocalSettings()
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

    private static object GetValue(string key)
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

    public static GameOptions LoadOptions()
    {
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

                if (GetValue("IsTimed") is bool isTimed)
                    options.IsTimed = isTimed;

                if (GetValue("IsSoundEnabled") is bool isSound)
                    options.IsSoundEnabled = isSound;

                if (GetValue("IsVegasScoring") is bool isVegas)
                    options.IsVegasScoring = isVegas;

                if (GetValue("IsDrawConstraintsEnabled") is bool isDrawC)
                    options.IsDrawConstraintsEnabled = isDrawC;

                if (GetValue("CustomFeltColorRevision") is int rev)
                    options.CustomFeltColorRevision = rev;

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
                if (loaded != null) return loaded;
            }
        }
        catch
        {
            // Keep default options
        }

        return options;
    }

    public static void SaveOptions(GameOptions options)
    {
        var localSettings = GetLocalSettings();
        if (localSettings != null)
        {
            try
            {
                SetValue("FeltColor", options.FeltColor.ToString());
                SetValue("CardBackTheme", options.CardBackTheme);
                SetValue("IsTimed", options.IsTimed);
                SetValue("IsSoundEnabled", options.IsSoundEnabled);
                SetValue("IsVegasScoring", options.IsVegasScoring);
                SetValue("IsDrawConstraintsEnabled", options.IsDrawConstraintsEnabled);
                SetValue("CustomFeltColorRevision", options.CustomFeltColorRevision);
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
