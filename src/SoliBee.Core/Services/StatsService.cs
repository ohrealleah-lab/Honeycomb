using System;
using System.IO;
using System.Reflection;
using System.Text.Json;
using SoliBee.Core.Models;

namespace SoliBee.Core.Services;

public static class StatsService
{
    private static string GetLocalFolderPath()
    {
        try
        {
            var appDataType = Type.GetType("Windows.Storage.ApplicationData, Windows, Version=255.255.255.255, Culture=neutral, PublicKeyToken=null, ContentType=WindowsRuntime");
            if (appDataType != null)
            {
                var currentProp = appDataType.GetProperty("Current", BindingFlags.Public | BindingFlags.Static);
                var currentInstance = currentProp?.GetValue(null);
                if (currentInstance != null)
                {
                    var localFolderProp = currentInstance.GetType().GetProperty("LocalFolder", BindingFlags.Public | BindingFlags.Instance);
                    var localFolderInstance = localFolderProp?.GetValue(currentInstance);
                    if (localFolderInstance != null)
                    {
                        var pathProp = localFolderInstance.GetType().GetProperty("Path", BindingFlags.Public | BindingFlags.Instance);
                        var path = pathProp?.GetValue(localFolderInstance) as string;
                        if (!string.IsNullOrEmpty(path))
                        {
                            return path;
                        }
                    }
                }
            }
        }
        catch
        {
            // Ignore and fallback
        }

        var fallbackDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SoliBee");
        if (!Directory.Exists(fallbackDir))
        {
            Directory.CreateDirectory(fallbackDir);
        }
        return fallbackDir;
    }

    public static string StatsFilePath => Path.Combine(GetLocalFolderPath(), "stats.json");

    public static GameStatistics LoadStats()
    {
        try
        {
            var filePath = StatsFilePath;
            if (File.Exists(filePath))
            {
                var json = File.ReadAllText(filePath);
                var stats = JsonSerializer.Deserialize<GameStatistics>(json);
                if (stats != null) return stats;
            }
        }
        catch
        {
            // Return defaults
        }
        return new GameStatistics();
    }

    public static void SaveStats(GameStatistics stats)
    {
        try
        {
            var filePath = StatsFilePath;
            var directory = Path.GetDirectoryName(filePath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }
            var json = JsonSerializer.Serialize(stats, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(filePath, json);
        }
        catch
        {
            // Ignore
        }
    }
}
