using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using SoliBee.Core.Models;

namespace SoliBee.Core.Services;

public static class FaceCardArtService
{
    private static readonly string _artDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "SoliBee", "FaceCardArt");

    private static readonly string _configPath;
    private static List<CustomFaceArt> _arts = new();
    private static bool _loaded;

    static FaceCardArtService()
    {
        _configPath = Path.Combine(_artDir, "config.json");
    }

    private static void EnsureLoaded()
    {
        if (_loaded) return;
        _loaded = true;
        EnsureDir();
        if (!File.Exists(_configPath)) return;
        try
        {
            var json = File.ReadAllText(_configPath);
            _arts = JsonSerializer.Deserialize<List<CustomFaceArt>>(json) ?? new();
        }
        catch { _arts = new(); }
    }

    private static void EnsureDir()
    {
        if (!Directory.Exists(_artDir)) Directory.CreateDirectory(_artDir);
    }

    private static void Save()
    {
        EnsureDir();
        File.WriteAllText(_configPath, JsonSerializer.Serialize(_arts,
            new JsonSerializerOptions { WriteIndented = true }));
    }

    public static CustomFaceArt? GetArt(FaceCardSlot slot)
    {
        EnsureLoaded();
        return _arts.Find(a => a.Slot == slot);
    }

    public static CustomFaceArt? GetEnabledArt(FaceCardSlot slot)
    {
        EnsureLoaded();
        return _arts.Find(a => a.Slot == slot && a.IsEnabled);
    }

    public static void Add(CustomFaceArt art)
    {
        EnsureLoaded();
        _arts.RemoveAll(a => a.Slot == art.Slot);
        _arts.Add(art);
        Save();
    }

    public static void Update(CustomFaceArt art)
    {
        EnsureLoaded();
        var idx = _arts.FindIndex(a => a.Id == art.Id);
        if (idx >= 0) _arts[idx] = art;
        else { _arts.RemoveAll(a => a.Slot == art.Slot); _arts.Add(art); }
        Save();
    }

    public static void Remove(FaceCardSlot slot)
    {
        EnsureLoaded();
        var art = _arts.Find(a => a.Slot == slot);
        if (art != null)
        {
            try
            {
                var p = GetFullPath(art);
                if (File.Exists(p)) File.Delete(p);
            }
            catch { }
            _arts.Remove(art);
        }
        Save();
    }

    public static void SetEnabled(bool enabled, FaceCardSlot slot)
    {
        EnsureLoaded();
        var art = _arts.Find(a => a.Slot == slot);
        if (art != null) { art.IsEnabled = enabled; Save(); }
    }

    public static IReadOnlyList<CustomFaceArt> GetAllArts()
    {
        EnsureLoaded();
        return _arts.AsReadOnly();
    }

    public static string GetFullPath(CustomFaceArt art) =>
        Path.Combine(_artDir, art.RelativePath);

    public static bool IsGif(CustomFaceArt art) =>
        art.RelativePath.EndsWith(".gif", StringComparison.OrdinalIgnoreCase);

    public static string ArtDirectory => _artDir;
}
