using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

public class BeekeeperViewModelTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-vm-tests-" + Guid.NewGuid().ToString("N"));
    private string SavePath => Path.Combine(_dir, "beekeeper.json");

    public void Dispose()
    {
        try { if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true); } catch { }
    }

    private sealed class SeqRandom : IRandomSource
    {
        private readonly Queue<double> _d;
        public SeqRandom(params double[] values) => _d = new Queue<double>(values);
        public double NextDouble() => _d.Count > 0 ? _d.Dequeue() : 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private sealed class Clock
    {
        public DateTime Now { get; set; } = new(2026, 11, 6, 12, 0, 0, DateTimeKind.Utc);
        public void Advance(double seconds) => Now = Now.AddSeconds(seconds);
        public Func<DateTime> Func => () => Now;
    }

    private static readonly BeekeeperConfig BigStorage = new() { StartingStorage = 1_000_000_000m };

    private BeekeeperViewModel Make(Clock clock, BeekeeperState? state = null, BeekeeperConfig? config = null,
                                    bool persist = false, IRandomSource? rng = null)
        => new(isHeadless: true, config: config, rng: rng ?? new SeqRandom(), clock: clock.Func,
               persist: persist, savePath: SavePath, initialState: state);

    private static bool Logged(BeekeeperViewModel vm, string key) => vm.Log.Any(e => e.Key == key);

    // ============================================================ starting and clicking

    [Fact]
    public void BrandNewGame_LogsNewGame_AndStartsEmpty()
    {
        var vm = Make(new Clock());
        Assert.Equal(0m, vm.Bees);
        Assert.Single(vm.Log);
        Assert.Equal(BeekeeperEvents.NewGame, vm.Log[0].Key);
        Assert.False(string.IsNullOrEmpty(vm.BearName));
    }

    [Fact]
    public void Catch_AddsBees_RecordsThePopup_AndLogsTheFirstBee()
    {
        var vm = Make(new Clock());
        vm.CatchCommand.Execute(null);
        Assert.Equal(1m, vm.Bees);
        Assert.False(vm.LastCatch!.Stung);
        Assert.Equal(1, vm.CatchSerial);
        Assert.True(Logged(vm, BeekeeperEvents.FirstBee));
        Assert.True(vm.HoneyRevealed);

        vm.CatchCommand.Execute(null);
        Assert.Equal(2, vm.CatchSerial);
    }

    [Fact]
    public void AStingShowsAPopup_ButIsNotWrittenToTheLog()
    {
        var vm = Make(new Clock(), rng: new SeqRandom(0.0));
        vm.CatchCommand.Execute(null);
        Assert.True(vm.LastCatch!.Stung);
        Assert.Equal(0m, vm.Bees);
        Assert.False(Logged(vm, BeekeeperEvents.Sting));
    }

    // ============================================================ time

    [Fact]
    public void ATickAboutASecondLater_MakesHoney()
    {
        var clock = new Clock();
        var vm = Make(clock, new BeekeeperState { Bees = 100m, BearName = "Bruno" });
        clock.Advance(1);
        vm.Tick();
        Assert.Equal(1m, vm.Honey);
    }

    [Fact]
    public void LeftoverFractionsOfASecond_AreCarriedForward()
    {
        var clock = new Clock();
        var vm = Make(clock, new BeekeeperState { Bees = 100m, BearName = "Bruno" });

        clock.Advance(0.6); vm.Tick();
        Assert.Equal(0m, vm.Honey);          // not a whole second yet
        clock.Advance(0.6); vm.Tick();
        Assert.Equal(1m, vm.Honey);          // 1.2 s -> 1 s paid, 0.2 carried
        clock.Advance(0.8); vm.Tick();
        Assert.Equal(2m, vm.Honey);          // 0.2 + 0.8 = 1.0 s
    }

    [Fact]
    public void AGapOverTwoSeconds_IsCreditedAsTimeAway_Quietly()
    {
        var clock = new Clock();
        var vm = Make(clock, new BeekeeperState { Bees = 100m, BearName = "Bruno" }, BigStorage);
        clock.Advance(7200);
        vm.Tick();
        Assert.Equal(7200m, vm.Honey);
        // The app stayed open (sleep, a slow start), so no "While you were away" line.
        Assert.False(Logged(vm, BeekeeperEvents.WelcomeBack));
        Assert.False(Logged(vm, BeekeeperEvents.WelcomeBackNothing));
    }

    [Fact]
    public void TenDaysAway_PaysOnlyThreeDays()
    {
        var clock = new Clock();
        var vm = Make(clock, new BeekeeperState { Bees = 100m, BearName = "Bruno" }, BigStorage);
        clock.Advance(10 * 24 * 3600);
        vm.Tick();
        Assert.Equal(100m * 0.01m * 259_200m, vm.Honey);
    }

    [Fact]
    public void AClockSetBackwards_PaysNothing_AndTheNextTickStillWorks()
    {
        var clock = new Clock();
        var vm = Make(clock, new BeekeeperState { Bees = 100m, BearName = "Bruno" }, BigStorage);
        clock.Advance(-3 * 3600);
        vm.Tick();
        Assert.Equal(0m, vm.Honey);

        clock.Advance(1);
        vm.Tick();
        Assert.Equal(1m, vm.Honey);
    }

    [Fact]
    public void WhenStorageFills_TheLogSaysSoOnce()
    {
        var clock = new Clock();
        var vm = Make(clock, new BeekeeperState { Bees = 100000m, Honey = 199m, BearName = "Bruno" });
        for (int i = 0; i < 5; i++) { clock.Advance(1); vm.Tick(); }
        Assert.Equal(1, vm.Log.Count(e => e.Key == BeekeeperEvents.StorageFull));
        Assert.True(vm.StorageIsFull);
    }

    // ============================================================ the log

    [Fact]
    public void Log_IsNewestFirst_AndCappedAtFifty()
    {
        var clock = new Clock();
        var vm = Make(clock, new BeekeeperState { Honey = 10_000m, BearName = "Bruno" }, BigStorage);
        for (int i = 0; i < 60; i++) vm.SellTenCommand.Execute(null);

        Assert.Equal(BeekeeperSaveService.MaxLogEntries, vm.Log.Count);
        Assert.Equal(BeekeeperEvents.Sale, vm.Log[0].Key);
        Assert.Equal("Bruno", vm.Log[0].Text);
    }

    // ============================================================ buttons

    [Fact]
    public void SellButtons_AreOffUntilThereIsTenHoney_AndTellTheScreenWhenThatChanges()
    {
        var clock = new Clock();
        var vm = Make(clock, new BeekeeperState { Bees = 1000m, BearName = "Bruno" }); // 10 honey/s
        int changes = 0;
        vm.SellTenCommand.CanExecuteChanged += (_, _) => changes++;

        Assert.False(vm.SellTenCommand.CanExecute(null));
        clock.Advance(1); vm.Tick();
        Assert.True(vm.SellTenCommand.CanExecute(null));
        Assert.True(vm.SellAllCommand.CanExecute(null));
        Assert.True(changes > 0);
    }

    [Fact]
    public void Selling_BuyingAndBuilding_GoThroughTheEngineAndTheLog()
    {
        var clock = new Clock();
        var vm = Make(clock, new BeekeeperState { Honey = 150m, Wax = 100m, BearName = "Bruno" });

        vm.SellAllCommand.Execute(null);
        Assert.Equal(15m, vm.Beebits);
        Assert.True(vm.ShopRevealed);
        Assert.True(Logged(vm, BeekeeperEvents.ShopOpened));

        vm.BuyNextToolCommand.Execute(null);
        Assert.Equal(1, vm.ToolLevel);
        Assert.Equal(2, vm.BeesPerClick);

        vm.BuildCombCommand.Execute(null);
        Assert.Equal(1, vm.Combs);
        Assert.Equal(400m, vm.HoneyStorage);
        Assert.True(Logged(vm, BeekeeperEvents.CombBuilt));
    }

    [Fact]
    public void RefusedActions_DoNotWriteToTheLog()
    {
        var vm = Make(new Clock(), new BeekeeperState { Honey = 3m, BearName = "Bruno" });
        int before = vm.Log.Count;
        vm.SellAll();                       // called directly, not through the disabled button
        vm.BuildComb();
        Assert.Equal(before, vm.Log.Count);
    }

    [Fact]
    public void PropertyChanged_IsRaisedOnTick()
    {
        var clock = new Clock();
        var vm = Make(clock, new BeekeeperState { Bees = 100m, BearName = "Bruno" });
        int raised = 0;
        vm.PropertyChanged += (_, _) => raised++;
        clock.Advance(1);
        vm.Tick();
        Assert.True(raised > 0);
    }

    // ============================================================ new game

    [Fact]
    public void NewGame_AsksOnlyWhenThereAreBees()
    {
        var vm = Make(new Clock());
        Assert.False(vm.NewGameNeedsConfirmation);
        vm.CatchCommand.Execute(null);
        Assert.True(vm.NewGameNeedsConfirmation);
    }

    [Fact]
    public void StartNewGame_ResetsTheHive_AndLogsAFreshStart()
    {
        var vm = Make(new Clock(), new BeekeeperState { Bees = 50m, Combs = 2, BearName = "Bruno", Log = { new BeekeeperLogEntry { Key = "old" } } });
        vm.StartNewGame();
        Assert.Equal(0m, vm.Bees);
        Assert.Equal(0, vm.Combs);
        Assert.Single(vm.Log);
        Assert.Equal(BeekeeperEvents.NewGame, vm.Log[0].Key);
    }

    // ============================================================ saving

    [Fact]
    public void AutosavesEveryFiveSeconds_NotBefore()
    {
        var clock = new Clock();
        var vm = Make(clock, new BeekeeperState { Bees = 100m, BearName = "Bruno" }, persist: true);
        for (int i = 0; i < 4; i++) { clock.Advance(1); vm.Tick(); }
        Assert.False(File.Exists(SavePath));

        clock.Advance(1); vm.Tick();
        Assert.True(File.Exists(SavePath));
        Assert.Equal(5m, BeekeeperSaveService.Load(SavePath)!.Honey);
    }

    [Fact]
    public void Dispose_SavesTheGame()
    {
        var clock = new Clock();
        var vm = Make(clock, new BeekeeperState { Bees = 7m, BearName = "Bruno" }, persist: true);
        vm.Dispose();
        Assert.Equal(7m, BeekeeperSaveService.Load(SavePath)!.Bees);
    }

    [Fact]
    public void Reopening_TwoHoursLater_CreditsTwoHours_AndWelcomesThePlayerBack()
    {
        var clock = new Clock();
        var first = Make(clock, new BeekeeperState { Bees = 100m, BearName = "Bruno" }, BigStorage, persist: true);
        first.Dispose();                                   // saved at "now"

        clock.Advance(7200);
        var second = Make(clock, config: BigStorage, persist: true);
        Assert.Equal(100m, second.Bees);
        Assert.Equal(7200m, second.Honey);
        Assert.Contains(second.Log, e => e.Key == BeekeeperEvents.WelcomeBack);
    }

    [Fact]
    public void ReopeningRightAway_CreditsNothingExtra()
    {
        var clock = new Clock();
        var first = Make(clock, new BeekeeperState { Bees = 100m, BearName = "Bruno" }, BigStorage, persist: true);
        first.Dispose();

        clock.Advance(1);
        var second = Make(clock, config: BigStorage, persist: true);
        Assert.Equal(0m, second.Honey);
        Assert.False(Logged(second, BeekeeperEvents.WelcomeBack));
    }

    [Fact]
    public void ADamagedSave_StartsANewGame()
    {
        Directory.CreateDirectory(_dir);
        File.WriteAllText(SavePath, "not json at all");
        var vm = Make(new Clock(), persist: true);
        Assert.Equal(0m, vm.Bees);
        Assert.Equal(BeekeeperEvents.NewGame, vm.Log[0].Key);
    }
}
