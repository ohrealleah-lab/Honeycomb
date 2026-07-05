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

    // Freecell used to inherit Klondike's shared Vegas-mode flag and record stats under
    // "vegas_1deck"/"vegas_2deck" keys, even though Freecell never actually had its own
    // Vegas scoring. Now that FreecellViewModel.ModeKey always resolves to "standard_*",
    // those old buckets would otherwise sit unreachable in the stats file forever — fold
    // their totals into the standard bucket instead of losing the play history.
    public static void MigrateFreecellVegasStats(GameStatistics stats)
    {
        foreach (var deckSuffix in new[] { "1deck", "2deck" })
        {
            string vegasKey = $"vegas_{deckSuffix}";
            if (!stats.FreecellStatsByMode.TryGetValue(vegasKey, out var vegas)) continue;

            string standardKey = $"standard_{deckSuffix}";
            if (!stats.FreecellStatsByMode.TryGetValue(standardKey, out var standard))
            {
                standard = new ModeStats();
                stats.FreecellStatsByMode[standardKey] = standard;
            }

            standard.GamesPlayed     += vegas.GamesPlayed;
            standard.GamesWon        += vegas.GamesWon;
            standard.LongestStreak   = Math.Max(standard.LongestStreak, vegas.LongestStreak);
            standard.HighScore       = Math.Max(standard.HighScore, vegas.HighScore);
            standard.TotalWinSeconds += vegas.TotalWinSeconds;
            if (vegas.ShortestWinSeconds > 0 &&
                (standard.ShortestWinSeconds == 0 || vegas.ShortestWinSeconds < standard.ShortestWinSeconds))
                standard.ShortestWinSeconds = vegas.ShortestWinSeconds;

            stats.FreecellStatsByMode.Remove(vegasKey);
        }
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
