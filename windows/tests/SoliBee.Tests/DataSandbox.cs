using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.Json;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Tests;

// Same idea as SharedStatsFileTests, widened to the whole data folder: these tests save
// stats, options, themes and decks for real, so every .json/.txt file under
// AppPaths.DataDirectory is copied at the start and put back afterwards (files a test
// created are deleted). The in-memory shared settings (SettingsService's cached
// GameOptions) and the face-art list are restored too, so No Stress Mode, Honey Mode or a
// theme a test switched on can't leak into the next test.
public class DataSandbox : IDisposable
{
    private static readonly FieldInfo SettingsCache =
        typeof(SettingsService).GetField("_cache", BindingFlags.NonPublic | BindingFlags.Static)!;

    private readonly Dictionary<string, byte[]> _files;
    private readonly GameOptions _liveOptions;
    private readonly string _liveOptionsJson;
    private readonly List<CustomFaceArt> _faceArts;

    public DataSandbox()
    {
        _files = DataFiles().ToDictionary(f => f, File.ReadAllBytes);
        _liveOptions = SettingsService.LoadOptions();
        _liveOptionsJson = JsonSerializer.Serialize(_liveOptions);
        _faceArts = FaceCardArtService.GetAllArts().ToList();

        // Every test starts from the same shared settings: English, Honey Mode on (so
        // banners actually fire), No Stress Mode off.
        Options.Language = SoliBee.Core.Localization.AppLanguage.English;
        Options.HoneyMode = true;
        Options.IsNoStressMode = false;
    }

    // The app-wide GameOptions every view model shares.
    public GameOptions Options => SettingsService.LoadOptions();

    // Simulates a relaunch for SettingsService: forget the cached options so the next
    // LoadOptions() reads settings.json again.
    public static void ForgetCachedSettings() => SettingsCache.SetValue(null, null);

    public void Dispose()
    {
        foreach (var f in DataFiles())
            if (!_files.ContainsKey(f)) File.Delete(f);
        foreach (var (path, bytes) in _files)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllBytes(path, bytes);
        }

        // Put the original values back into the same shared instance (view models from
        // other tests may still hold it), then make it the cached one again.
        var original = JsonSerializer.Deserialize<GameOptions>(_liveOptionsJson)!;
        foreach (var p in typeof(GameOptions).GetProperties().Where(p => p.CanRead && p.CanWrite))
            p.SetValue(_liveOptions, p.GetValue(original));
        SettingsCache.SetValue(null, _liveOptions);

        // ReplaceAll saves config.json, so restore that file once more afterwards.
        FaceCardArtService.ReplaceAll(_faceArts);
        var config = Path.Combine(FaceCardArtService.ArtDirectory, "config.json");
        if (_files.TryGetValue(config, out var cfg)) File.WriteAllBytes(config, cfg);
        else if (File.Exists(config)) File.Delete(config);
    }

    private static IEnumerable<string> DataFiles()
    {
        if (!Directory.Exists(AppPaths.DataDirectory)) return Enumerable.Empty<string>();
        return Directory.EnumerateFiles(AppPaths.DataDirectory, "*", SearchOption.AllDirectories)
            .Where(f => f.EndsWith(".json") || f.EndsWith(".txt") || f.EndsWith(".tmp"))
            .ToList();
    }

    // Deletes one data file (e.g. to start from "never played"); Dispose puts it back.
    public static void Delete(string fileName)
    {
        var path = Path.Combine(AppPaths.DataDirectory, fileName);
        if (File.Exists(path)) File.Delete(path);
    }

    public static void Write(string fileName, string contents)
    {
        Directory.CreateDirectory(AppPaths.DataDirectory);
        File.WriteAllText(Path.Combine(AppPaths.DataDirectory, fileName), contents);
    }

    public static string Read(string fileName) => File.ReadAllText(Path.Combine(AppPaths.DataDirectory, fileName));
}

// Small builders shared by the gameplay suites.
public static class Cards
{
    private static int _next;

    public static Card C(CardSuit suit, int rank, bool up = true) =>
        new($"t{System.Threading.Interlocked.Increment(ref _next)}_{suit}_{rank}", suit, rank, up);

    // rank `from` down to `through`, one suit, face up (a Spider run, K→A when 13..1).
    public static List<Card> Run(CardSuit suit, int from, int through) =>
        Enumerable.Range(through, from - through + 1).Reverse().Select(r => C(suit, r)).ToList();

    // Ace up to `through`, one suit (a foundation's contents).
    public static List<Card> Ascending(CardSuit suit, int through) =>
        Enumerable.Range(1, through).Select(r => C(suit, r)).ToList();
}

public static class Reflect
{
    public static T Get<T>(object target, string field) =>
        (T)target.GetType().GetField(field, BindingFlags.NonPublic | BindingFlags.Instance)!.GetValue(target)!;

    public static void Set(object target, string field, object? value) =>
        target.GetType().GetField(field, BindingFlags.NonPublic | BindingFlags.Instance)!.SetValue(target, value);

    public static object? Call(object target, string method, params object?[] args) =>
        target.GetType().GetMethod(method, BindingFlags.NonPublic | BindingFlags.Instance)!.Invoke(target, args);
}
