using System;
using System.IO;
using System.Linq;
using System.Text.Json;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Live play and time away must agree, and a damaged save must never break the game.</summary>
public class BeekeeperHardeningTests : IDisposable
{
    private sealed class FixedRandom : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    private static readonly BeekeeperConfig Roomy = new() { StartingStorage = 1e18m };

    private readonly string _dir = Path.Combine(Path.GetTempPath(), "beekeeper-hardening-" + Guid.NewGuid().ToString("N"));

    public BeekeeperHardeningTests() => Directory.CreateDirectory(_dir);

    public void Dispose()
    {
        try { Directory.Delete(_dir, recursive: true); } catch { }
    }

    private static BeekeeperEngine Queen(decimal bees, decimal bread) => new(Roomy, new BeekeeperState
    {
        Bees = bees, HoneyRevealed = true, HasWoodenHive = true, QueenSettled = true, BeeBread = bread,
    }, new FixedRandom());

    private static BeekeeperEngine With(BeekeeperState state) => new(null, state, new FixedRandom());

    private string SaveToFile(BeekeeperState state)
    {
        string path = Path.Combine(_dir, "beekeeper.json");
        File.WriteAllText(path, JsonSerializer.Serialize(state));
        return path;
    }

    // ------------------------------------------------------------------ live equals away

    [Theory]
    [InlineData(1900, 1, 400)]
    [InlineData(1000, 1, 300)]
    [InlineData(1000, 1000, 3600)]
    [InlineData(0, 10, 3000)]
    public void SecondBySecond_EndsExactlyWhereOneLongStretchDoes(int bees, int bread, int seconds)
    {
        var live = Queen(bees, bread);
        var away = Queen(bees, bread);

        for (int i = 0; i < seconds; i++) live.Advance(1m);
        away.AdvanceAway(seconds);

        Assert.Equal(away.State.Bees, live.State.Bees);
        Assert.Equal(away.State.BeeBread, live.State.BeeBread);
        Assert.Equal(away.State.Honey, live.State.Honey);
        Assert.Equal(away.State.Wax, live.State.Wax);
        Assert.Equal(away.State.WaxProgress, live.State.WaxProgress);
        Assert.Equal(away.BeesPerCatch, live.BeesPerCatch);
    }

    [Fact]
    public void ThePantryRunsOut_OnTheExactSecond()
    {
        var e = Queen(1000m, 1m);   // 1 bee bread feeds 100 bees: 300 s at 20 a minute

        for (int i = 0; i < 299; i++)
            Assert.DoesNotContain(e.Advance(1m).Events, x => x.Key == BeekeeperEvents.PantryEmpty);

        Assert.Contains(e.Advance(1m).Events, x => x.Key == BeekeeperEvents.PantryEmpty);
        Assert.Equal(0m, e.State.BeeBread);
    }

    // ------------------------------------------------------------------ the welcome-back line

    [Fact]
    public void WelcomeBack_UnderOneHoney_IsTheNothingLine()
    {
        var e = With(new BeekeeperState { Bees = 1m, HoneyRevealed = true });

        var keys = e.AdvanceAway(2.5m).WelcomeBack.Select(x => x.Key).ToList();

        Assert.Contains(BeekeeperEvents.WelcomeBackNothing, keys);
        Assert.DoesNotContain(BeekeeperEvents.WelcomeBack, keys);
    }

    [Fact]
    public void WelcomeBack_OneWholeHoney_IsTheHoneyLine()
    {
        var e = With(new BeekeeperState { Bees = 1m, HoneyRevealed = true });

        Assert.Contains(e.AdvanceAway(100m).WelcomeBack, x => x.Key == BeekeeperEvents.WelcomeBack && x.Value == 1m);
    }

    // ------------------------------------------------------------------ absurd numbers

    [Theory]
    [InlineData("Wax")]
    [InlineData("WaxProgress")]
    [InlineData("Beebits")]
    [InlineData("BeeBread")]
    [InlineData("Pollen")]
    [InlineData("Propolis")]
    [InlineData("AgreementHoneyProgress")]
    public void AnAbsurdAmount_IsRefusedAndKeptAside(string field)
    {
        var state = new BeekeeperState { Bees = 10m };
        typeof(BeekeeperState).GetProperty(field)!.SetValue(state, decimal.MaxValue);
        string path = SaveToFile(state);

        Assert.Null(BeekeeperSaveService.Load(path));
        Assert.True(File.Exists(path + ".unreadable"));
    }

    [Fact]
    public void AbsurdCombs_AreRefused()
    {
        Assert.Null(BeekeeperSaveService.Load(SaveToFile(new BeekeeperState { Combs = int.MaxValue })));
    }

    [Fact]
    public void TheLargestAcceptedAmounts_SurviveAFullAwayStretch()
    {
        var loaded = BeekeeperSaveService.Load(SaveToFile(new BeekeeperState
        {
            Bees = 1e20m, Wax = 1e24m, WaxProgress = 1e24m, Beebits = 1e24m, Pollen = 1e24m, Propolis = 1e24m,
            BeeBread = 1e24m, AgreementHoneyProgress = 1e24m, HasTradeAgreement = true,
            HasWoodenHive = true, QueenSettled = true, Plants = { BeekeeperPlants.Wildflowers },
        }));
        Assert.NotNull(loaded);

        var e = With(loaded!);
        e.AdvanceAway(259200m);
        e.Advance(1m);
        _ = e.PantrySecondsLeft;
    }

    [Fact]
    public void EveryDamagedFile_KeepsItsOwnBackup()
    {
        string path = Path.Combine(_dir, "beekeeper.json");

        File.WriteAllText(path, "{ first");
        BeekeeperSaveService.Load(path);
        File.WriteAllText(path, "{ second");
        BeekeeperSaveService.Load(path);

        Assert.Equal("{ first", File.ReadAllText(path + ".unreadable"));
        Assert.Equal("{ second", File.ReadAllText(path + ".unreadable2"));
    }

    [Fact]
    public void AnEmptyLogLine_IsDropped()
    {
        string path = Path.Combine(_dir, "beekeeper.json");
        var json = JsonSerializer.Serialize(new BeekeeperState { Bees = 5m })
            .Replace("\"Log\":[]", "\"Log\":[null,{\"Key\":null},{\"Key\":\"sting\"}]");
        File.WriteAllText(path, json);

        var loaded = BeekeeperSaveService.Load(path);

        Assert.Equal(BeekeeperEvents.Sting, Assert.Single(loaded!.Log).Key);
    }

    // ------------------------------------------------------------------ odd lists and timers

    [Fact]
    public void ADuplicatedPlant_CountsOnce()
    {
        var e = With(new BeekeeperState
        {
            Plants = Enumerable.Repeat(BeekeeperPlants.Bramble, 400).ToList(),
            Bees = 1000m, HoneyRevealed = true,
        });

        Assert.Single(e.State.Plants);
        Assert.Equal(e.Config.Plants.Single(p => p.Id == BeekeeperPlants.Bramble).Strength, e.GuardingMultiplier);
        e.AdvanceAway(3600m);
    }

    [Fact]
    public void APlantLivesInOnePlaceOnly()
    {
        var e = With(new BeekeeperState
        {
            Plants = { BeekeeperPlants.Wildflowers },
            Beds =
            {
                new BeekeeperBed { PlantId = BeekeeperPlants.Wildflowers, SecondsLeft = 5m },
                new BeekeeperBed { PlantId = BeekeeperPlants.Bramble, SecondsLeft = 5m },
                new BeekeeperBed { PlantId = BeekeeperPlants.Bramble, SecondsLeft = 9m },
            },
            SeedsInHand = { BeekeeperPlants.Wildflowers, BeekeeperPlants.Bramble },
        });

        Assert.Equal(BeekeeperPlants.Bramble, Assert.Single(e.State.Beds).PlantId);
        Assert.Empty(e.State.SeedsInHand);
    }

    [Fact]
    public void SeedsFromExtraBeds_GoBackInHand()
    {
        var plants = BeekeeperConfig.Default.Plants.Take(5).Select(p => p.Id).ToList();
        var state = new BeekeeperState { SeedsGivenIds = plants.ToList() };
        state.Beds.AddRange(plants.Select(id => new BeekeeperBed { PlantId = id, SecondsLeft = 5m }));

        var e = With(state);

        Assert.Equal(plants.Take(2), e.State.Beds.Select(b => b.PlantId));
        Assert.Equal(plants.Skip(2), e.State.SeedsInHand);
    }

    [Fact]
    public void TimersLongerThanPossible_AreCutToTheirLimit()
    {
        var config = BeekeeperConfig.Default;
        var plant = config.Plants[0];

        var e = With(new BeekeeperState
        {
            CalmSecondsLeft = 1e27m, BeeBoostSecondsLeft = 1e27m, SagePropolisSecondsLeft = 1e27m,
            Beds = { new BeekeeperBed { PlantId = plant.Id, SecondsLeft = 1e27m } },
        });

        Assert.Equal(config.CalmSeconds, e.State.CalmSecondsLeft);
        Assert.Equal(config.BeeBoostCapSeconds, e.State.BeeBoostSecondsLeft);
        Assert.Equal(config.SagePropolisCapSeconds, e.State.SagePropolisSecondsLeft);
        Assert.Equal(plant.GrowSeconds, Assert.Single(e.State.Beds).SecondsLeft);
    }
}
