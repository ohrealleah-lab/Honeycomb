using System;
using System.IO;
using System.Text.Json;

namespace SoliBee.Core.Services;

// Anchors this install's first-ever play date, purely for the "first launch after
// playing for a year" loading banner (HoneycombViewModel.LoadingBannerId). Kept in its
// own tiny file rather than folded into StatsService's stats.json — unlike the win-count
// milestones, this anchor deliberately survives a stats reset ("a year since you
// started playing" isn't something resetting your win count should undo).
public static class FirstPlayedTracker
{
    private class FirstPlayedData
    {
        public DateTime FirstPlayedUtc { get; set; }
        public bool HasShownOneYearBanner { get; set; }
    }

    private static string FilePath =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), AppDataMigration.FolderName, "first_played.json");

    private static FirstPlayedData Load()
    {
        try
        {
            if (File.Exists(FilePath))
            {
                var json = File.ReadAllText(FilePath);
                var data = JsonSerializer.Deserialize<FirstPlayedData>(json);
                if (data != null) return data;
            }
        }
        catch
        {
            // Fall through to a fresh anchor below.
        }
        var fresh = new FirstPlayedData { FirstPlayedUtc = DateTime.UtcNow, HasShownOneYearBanner = false };
        Save(fresh);
        return fresh;
    }

    private static void Save(FirstPlayedData data)
    {
        try
        {
            var dir = Path.GetDirectoryName(FilePath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir)) Directory.CreateDirectory(dir);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(data));
        }
        catch
        {
            // Best-effort — a missed write just means this anchors again next launch.
        }
    }

    // Returns true (once) the first time this is called after a full year has passed
    // since the anchor was created — never again after that, until the file is deleted.
    public static bool ShouldShowOneYearBanner()
    {
        var data = Load();
        if (data.HasShownOneYearBanner) return false;
        if (DateTime.UtcNow - data.FirstPlayedUtc < TimeSpan.FromDays(365)) return false;
        data.HasShownOneYearBanner = true;
        Save(data);
        return true;
    }
}
