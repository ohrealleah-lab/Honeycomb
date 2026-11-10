using System;
using System.IO;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

// How Beekeeper plugs into AppCoordinator: opened on demand, remembered as the last game,
// kept alive (and working) while another game is on screen, and switched off for the
// card-game features it doesn't have (Undo, statistics, the idle nudge).
public class BeekeeperCoordinatorTests : DataSandbox
{
    private const string LastModeFile = "last_mode.txt";

    private sealed class Clock
    {
        public DateTime Now { get; set; } = new(2026, 11, 6, 12, 0, 0, DateTimeKind.Utc);
        public Func<DateTime> Func => () => Now;
    }

    private AppCoordinator Fresh(Clock? clock = null)
    {
        Delete(LastModeFile);
        Delete("stats.json");
        Delete("beekeeper.json");
        return new AppCoordinator((clock ?? new Clock()).Func);
    }

    [Fact]
    public void Beekeeper_IsNotCreatedUntilItIsOpened()
    {
        var c = Fresh();
        Assert.False(c.BeekeeperStarted);
        c.SwitchToBeekeeper();
        Assert.True(c.BeekeeperStarted);
        Assert.Same(c.BeekeeperViewModel, c.ActiveViewModel);
    }

    [Fact]
    public void Beekeeper_IsRememberedAsTheLastGame()
    {
        var c = Fresh();
        c.SwitchToBeekeeper();
        Assert.Equal("Beekeeper", Read(LastModeFile));

        var relaunched = new AppCoordinator(new Clock().Func);
        Assert.IsType<BeekeeperViewModel>(relaunched.ActiveViewModel);
    }

    [Fact]
    public void SwitchingAway_LeavesTheSameHiveInPlace_AndItKeepsWorking()
    {
        var clock = new Clock();
        var c = Fresh(clock);
        c.SwitchToBeekeeper();
        var hive = c.BeekeeperViewModel;
        hive.State.HoneyRevealed = true;        // stage 7.5: 5 combs make 1 honey a second
        hive.State.Combs = 5;
        hive.State.BearName = "Bruno";

        c.SwitchToGame();                       // off to Klondike
        c.SwitchToHoneycomb();                  // and on to Honeycomb
        Assert.Same(hive, c.BeekeeperViewModel);
        Assert.NotSame(hive, c.ActiveViewModel);

        clock.Now = clock.Now.AddSeconds(1);
        hive.Tick();                            // what its timer does every second
        Assert.Equal(1m, hive.Honey);

        c.SwitchToBeekeeper();                  // back again: same hive, not a new one
        Assert.Same(hive, c.ActiveViewModel);
        Assert.Equal(1m, hive.Honey);
    }

    [Fact]
    public void ASharedSettingsChange_DoesNotDisturbTheHive()
    {
        var clock = new Clock();
        var c = Fresh(clock);
        c.SwitchToBeekeeper();
        c.BeekeeperViewModel.State.Bees = 10m;
        c.SwitchToGame();

        var copy = SettingsService.LoadOptions().Clone();
        WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(copy));

        Assert.Equal(10m, c.BeekeeperViewModel.Bees);
    }

    [Fact]
    public void Beekeeper_HasNoUndo_NoStatsReset_AndNoIdleNudge()
    {
        var c = Fresh();
        c.SwitchToBeekeeper();
        Assert.False(c.CanUndo);
        c.Undo();                               // does nothing, doesn't crash
        c.ResetStatistics();                    // likewise
        Assert.False(c.BeekeeperViewModel is IIdleActionChecking);
        Assert.False(c.CanUndo);
    }

    [Fact]
    public void SaveBeekeeper_WritesTheGame_OnlyWhenItWasOpened()
    {
        var c = Fresh();
        c.SaveBeekeeper();                      // never opened: nothing to save
        Assert.False(File.Exists(BeekeeperSaveService.SaveFilePath));

        c.SwitchToBeekeeper();
        c.BeekeeperViewModel.State.Bees = 42m;
        c.SaveBeekeeper();
        Assert.Equal(42m, BeekeeperSaveService.Load()!.Bees);
    }

    [Fact]
    public void OpeningBeekeeperLate_CreditsTheTimeSinceItWasLastSaved()
    {
        var clock = new Clock();
        var first = Fresh(clock);
        first.SwitchToBeekeeper();
        first.BeekeeperViewModel.State.HoneyRevealed = true;   // stage 7.5: 5 combs, 1 honey a second
        first.BeekeeperViewModel.State.Combs = 5;
        first.BeekeeperViewModel.State.BearName = "Bruno";
        first.SaveBeekeeper();                  // saved "now"

        clock.Now = clock.Now.AddHours(1);      // the app stays open on another game for an hour
        var second = new AppCoordinator(clock.Func);
        second.SwitchToBeekeeper();
        // An hour of 5 combs would make 3,600 honey, but storage holds only 1,400.
        Assert.Equal(1400m, second.BeekeeperViewModel.Honey);
    }
}
