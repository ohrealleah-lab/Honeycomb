using System;
using System.Collections.Generic;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

/// <summary>When wasps may come (spec 010): only while Beekeeper is watched by an active
/// player with No Stress Mode off; an approaching wasp leaves if the player steps away.</summary>
public class BeekeeperWaspViewModelTests
{
    private sealed class SeqRandom : IRandomSource
    {
        private readonly Queue<double> _d;
        public SeqRandom(params double[] values) => _d = new Queue<double>(values);
        public double NextDouble() => _d.Count > 0 ? _d.Dequeue() : 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private sealed class Clock
    {
        public DateTime Now { get; set; } = new(2026, 11, 7, 12, 0, 0, DateTimeKind.Utc);
        public void Advance(double seconds) => Now = Now.AddSeconds(seconds);
        public Func<DateTime> Func => () => Now;
    }

    private sealed class Hive
    {
        public readonly Clock Clock = new();
        public bool NoStress;
        public readonly BeekeeperViewModel Vm;

        // dice: the first value sets when the first wasp comes (0.0 = after 4 minutes).
        public Hive(double firstWaspDie = 0.0, params double[] more)
        {
            var state = new BeekeeperState
            {
                Bees = 1000m, Honey = 500m, Combs = 2, WorkbenchRevealed = true, BearName = "Bruno",
                HoneyRevealed = true, RepellentCandles = 1m, RepellentUnlocked = true,
            };
            Vm = new BeekeeperViewModel(isHeadless: true, config: new BeekeeperConfig { StartingStorage = 1_000_000m },
                rng: new SeqRandom(new[] { firstWaspDie }.Concat(more).ToArray()), clock: Clock.Func,
                persist: false, initialState: state, noStressMode: () => NoStress);
            Vm.IsWatched = true;
        }

        /// <summary>One-second ticks; <paramref name="active"/> = the player clicks every tick.</summary>
        public void Play(int seconds, bool active = true)
        {
            for (int i = 0; i < seconds; i++)
            {
                Clock.Advance(1);
                if (active) Vm.NoteActivity();
                Vm.Tick();
            }
        }

        public bool Logged(string key) => Vm.Log.Any(e => e.Key == key);
    }

    [Fact]
    public void AWatchedActivePlayer_GetsAWaspAfterFourMinutes()
    {
        var h = new Hive();
        h.Play(239);
        Assert.False(h.Vm.WaspApproaching);
        h.Play(1);
        Assert.True(h.Vm.WaspApproaching);
        Assert.True(h.Logged(BeekeeperEvents.WaspArrives));
    }

    [Fact]
    public void NoWasps_WhileBeekeeperIsNotOnScreen()
    {
        var h = new Hive();
        h.Vm.IsWatched = false;
        h.Play(1000);
        Assert.False(h.Vm.WaspApproaching);
    }

    [Fact]
    public void AnIdlePlayer_StopsCountingAfterFiveMinutes()
    {
        var h = new Hive(firstWaspDie: 0.99);   // about 8 minutes of wasp time needed
        h.Play(2000, active: false);           // only the first 5 minutes count
        Assert.False(h.Vm.WaspApproaching);
        h.Play(200);                           // active again: 300 + 200 > 477.6
        Assert.True(h.Vm.WaspApproaching);
    }

    [Fact]
    public void NoStressMode_NoLongerKeepsWaspsAway()
    {
        // Stage 6 (spec 014): No Stress Mode no longer applies to Beekeeper.
        var h = new Hive { NoStress = true };
        h.Play(240);
        Assert.True(h.Vm.WaspApproaching);
    }

    // Cut in stage 6 (spec 014): No Stress Mode kept wasps away.
    // public void NoStressMode_KeepsWaspsAway()
    // {
    //     var h = new Hive { NoStress = true };
    //     h.Play(1000);
    //     Assert.False(h.Vm.WaspApproaching);
    // }

    [Fact]
    public void NoStressMode_LetsAWaspAlreadyHerePlayOut()
    {
        var h = new Hive();
        h.Play(240);
        Assert.True(h.Vm.WaspApproaching);
        h.NoStress = true;
        h.Play(60);
        Assert.True(h.Logged(BeekeeperEvents.WaspRaid));
        Assert.Equal(1000m, h.Vm.Bees);   // stage 6: raids take only honey
    }

    [Fact]
    public void LeavingBeekeeper_SendsAnApproachingWaspAway()
    {
        var h = new Hive();
        h.Play(240);
        h.Vm.IsWatched = false;
        h.Play(1);
        Assert.False(h.Vm.WaspApproaching);
        Assert.True(h.Logged(BeekeeperEvents.WaspLeft));
        Assert.Equal(1000m, h.Vm.Bees);
    }

    [Fact]
    public void AComputerThatSlept_SendsTheWaspAway_AndTheSleepIsNotWaspTime()
    {
        var h = new Hive();
        h.Play(240);
        h.Clock.Advance(1800);   // asleep for 30 minutes
        h.Vm.NoteActivity();
        h.Vm.Tick();
        Assert.False(h.Vm.WaspApproaching);
        Assert.True(h.Logged(BeekeeperEvents.WaspLeft));
        Assert.Equal(1000m, h.Vm.Bees);

        var fresh = new Hive();
        fresh.Clock.Advance(1800);
        fresh.Vm.NoteActivity();
        fresh.Vm.Tick();
        Assert.False(fresh.Vm.WaspApproaching);   // 30 minutes of sleep brought no wasp
    }

    [Fact]
    public void ThrowBribeAndLight_WorkThroughTheCommands()
    {
        var h = new Hive(0.0, 0.0, 0.0);   // wasp after 4 min; the throw hits; next wasp after 4 min
        h.Play(240);
        h.Vm.ThrowShoeCommand.Execute(null);
        Assert.True(h.Logged(BeekeeperEvents.ShoeHit));

        h.Play(240);
        Assert.True(h.Vm.WaspApproaching);
        Assert.True(h.Vm.BribeCommand.CanExecute(null));
        h.Vm.BribeCommand.Execute(null);
        Assert.True(h.Logged(BeekeeperEvents.Bribe));
        Assert.Equal(1000m, h.Vm.Bees);

        h.Vm.LightRepellentCommand.Execute(null);
        Assert.True(h.Vm.RepellentSecondsLeft > 0m);
        h.Play(600);
        Assert.False(h.Vm.WaspApproaching);   // the candle keeps them off
    }
}
