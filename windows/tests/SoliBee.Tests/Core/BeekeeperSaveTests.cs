using System;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

public class BeekeeperSaveTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-save-tests-" + Guid.NewGuid().ToString("N"));
    private string PathFor(string name = "beekeeper.json") => Path.Combine(_dir, name);

    public void Dispose()
    {
        try { if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true); } catch { }
    }

    private static readonly DateTime Now = new(2026, 11, 6, 12, 0, 0, DateTimeKind.Utc);

    private static BeekeeperState BusyState() => new()
    {
        Bees = 1234567.5m,
        Honey = 187.37m,
        WaxProgress = 12.34m,
        Wax = 61m,
        Beebits = 99m,
        ToolLevel = 2,
        HasWaxCatcher = true,
        Combs = 3,
        BearName = "Baloo",
        Trades = 42,
        HoneyRevealed = true, BearRevealed = true, BeebitsRevealed = true,
        WaxRevealed = true, ShopRevealed = true, CombsRevealed = true,
        StorageFullAnnounced = true,
        Log =
        {
            new BeekeeperLogEntry { Key = BeekeeperEvents.BearArrives, Text = "Baloo" },
            new BeekeeperLogEntry { Key = BeekeeperEvents.CombBuilt, Value = 200m },
        },
    };

    [Fact]
    public void SaveThenLoad_RestoresEverything()
    {
        var path = PathFor();
        var original = BusyState();
        Assert.True(BeekeeperSaveService.Save(original, path, Now));

        var loaded = BeekeeperSaveService.Load(path);
        Assert.NotNull(loaded);
        Assert.Equal(1234567.5m, loaded!.Bees);
        Assert.Equal(187.37m, loaded.Honey);              // fractions survive
        Assert.Equal(12.34m, loaded.WaxProgress);
        Assert.Equal(61m, loaded.Wax);
        Assert.Equal(99m, loaded.Beebits);
        Assert.Equal(2, loaded.ToolLevel);
        Assert.True(loaded.HasWaxCatcher);
        Assert.Equal(3, loaded.Combs);
        Assert.Equal("Baloo", loaded.BearName);
        Assert.Equal(42, loaded.Trades);
        Assert.True(loaded.HoneyRevealed && loaded.BearRevealed && loaded.BeebitsRevealed
                    && loaded.WaxRevealed && loaded.ShopRevealed && loaded.CombsRevealed);
        Assert.True(loaded.StorageFullAnnounced);
        Assert.Equal(2, loaded.Log.Count);
        Assert.Equal(BeekeeperEvents.BearArrives, loaded.Log[0].Key);
        Assert.Equal("Baloo", loaded.Log[0].Text);
        Assert.Equal(200m, loaded.Log[1].Value);
        Assert.Equal(Now, loaded.SavedAtUtc);
    }

    [Fact]
    public void MissingFile_MeansNewGame()
    {
        Assert.Null(BeekeeperSaveService.Load(PathFor("nothing-here.json")));
    }

    [Theory]
    [InlineData("")]
    [InlineData("this is not json")]
    [InlineData("{ \"Bees\": ")]
    [InlineData("null")]
    public void DamagedFile_MeansNewGame_AndIsMovedAside(string contents)
    {
        var path = PathFor();
        Directory.CreateDirectory(_dir);
        File.WriteAllText(path, contents);

        Assert.Null(BeekeeperSaveService.Load(path));
        Assert.False(File.Exists(path));                       // won't be overwritten silently
        Assert.True(File.Exists(path + ".unreadable"));
        Assert.Equal(contents, File.ReadAllText(path + ".unreadable"));
    }

    [Fact]
    public void NewerVersion_FallsBackSafely_AndKeepsTheFile()
    {
        var path = PathFor();
        Directory.CreateDirectory(_dir);
        File.WriteAllText(path, "{\"Version\": 99, \"Bees\": 5}");

        Assert.Null(BeekeeperSaveService.Load(path));
        Assert.True(File.Exists(path + ".unreadable"));
    }

    [Theory]
    [InlineData("{\"Bees\": -5}")]
    [InlineData("{\"Honey\": -1}")]
    [InlineData("{\"Combs\": -1}")]
    [InlineData("{\"ToolLevel\": 9}")]
    [InlineData("{\"ToolLevel\": -1}")]
    public void NonsenseNumbers_AreRefused(string json)
    {
        var path = PathFor();
        Directory.CreateDirectory(_dir);
        File.WriteAllText(path, json);
        Assert.Null(BeekeeperSaveService.Load(path));
    }

    [Fact]
    public void SaveWritesTheTime_AndTheCurrentVersion()
    {
        var path = PathFor();
        var state = new BeekeeperState { Version = 0 };
        BeekeeperSaveService.Save(state, path, Now);
        Assert.Equal(Now, state.SavedAtUtc);
        Assert.Equal(BeekeeperSaveService.CurrentVersion, state.Version);
    }

    [Fact]
    public void SaveLeavesNoTemporaryFilesBehind()
    {
        var path = PathFor();
        BeekeeperSaveService.Save(BusyState(), path, Now);
        BeekeeperSaveService.Save(BusyState(), path, Now.AddSeconds(5));
        Assert.Single(Directory.GetFiles(_dir));
    }

    [Fact]
    public void LogIsTrimmedToFifty_KeepingTheNewest()
    {
        var state = new BeekeeperState();
        for (int i = 0; i < 80; i++)
            state.Log.Add(new BeekeeperLogEntry { Key = "line", Value = i }); // index 0 = newest
        var path = PathFor();
        BeekeeperSaveService.Save(state, path, Now);

        var loaded = BeekeeperSaveService.Load(path)!;
        Assert.Equal(BeekeeperSaveService.MaxLogEntries, loaded.Log.Count);
        Assert.Equal(0m, loaded.Log.First().Value);
        Assert.Equal(49m, loaded.Log.Last().Value);
    }

    [Fact]
    public void SecondsSinceSaved_IsPositiveNormally_ZeroWithNoTime_AndNegativeIfTheClockWentBack()
    {
        var state = new BeekeeperState { SavedAtUtc = Now };
        Assert.Equal(7200m, BeekeeperSaveService.SecondsSinceSaved(state, Now.AddHours(2)));
        Assert.Equal(0m, BeekeeperSaveService.SecondsSinceSaved(new BeekeeperState(), Now));
        Assert.True(BeekeeperSaveService.SecondsSinceSaved(state, Now.AddHours(-3)) < 0m);
    }

    [Fact]
    public void ReopeningTwoHoursLater_CreditsExactlyTwoHours()
    {
        var path = PathFor();
        var cfg = new BeekeeperConfig { StartingStorage = 1_000_000m };
        BeekeeperSaveService.Save(new BeekeeperState { Bees = 100m, BearName = "Bruno" }, path, Now);

        var loaded = BeekeeperSaveService.Load(path)!;
        var engine = new BeekeeperEngine(cfg, loaded);
        var gap = BeekeeperSaveService.SecondsSinceSaved(loaded, Now.AddHours(2));
        Assert.True(engine.IsAway(gap));
        engine.AdvanceAway(gap);

        Assert.Equal(7200m, loaded.Honey);
    }

    [Fact]
    public void ClockSetBackwards_CreditsNothing()
    {
        var path = PathFor();
        BeekeeperSaveService.Save(new BeekeeperState { Bees = 100m }, path, Now);

        var loaded = BeekeeperSaveService.Load(path)!;
        var engine = new BeekeeperEngine(state: loaded);
        engine.AdvanceAway(BeekeeperSaveService.SecondsSinceSaved(loaded, Now.AddDays(-2)));

        Assert.Equal(0m, loaded.Honey);
    }
}
