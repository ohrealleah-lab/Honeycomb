using System.Linq;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

/// <summary>Finished values the screen reads, so the view does no rules or percentage maths.</summary>
public class BeekeeperScreenValuesTests
{
    private static BeekeeperViewModel Make(BeekeeperState s) =>
        new(isHeadless: true, persist: false, initialState: s);

    [Fact]
    public void StorageIsFull_FollowsTheEnginesRule()
    {
        var vm = Make(new BeekeeperState { BearName = "B", Honey = 199m, HoneyRevealed = true });
        Assert.False(vm.Engine.IsStorageFull);
        Assert.False(vm.StorageIsFull);
        vm.State.Honey = 200m;
        Assert.True(vm.Engine.IsStorageFull);
        Assert.True(vm.StorageIsFull);
        // The Propolis Seal makes more room, so the same honey is no longer full.
        vm.State.Upgrades.Add(BeekeeperUpgrades.PropolisSeal);
        Assert.False(vm.StorageIsFull);
    }

    [Fact]
    public void CalmBar_ShowsTheMeterThenTheCalmTimeLeft()
    {
        var vm = Make(new BeekeeperState { BearName = "B", CalmMeter = 5 });
        Assert.Equal(5m / 15m, vm.CalmBarFraction);
        vm.State.CalmSecondsLeft = 60m;
        Assert.Equal(0.5m, vm.CalmBarFraction);
    }

    [Fact]
    public void BonusPercents_ComeFromTheConfig()
    {
        var vm = Make(new BeekeeperState { BearName = "B" });
        Assert.Equal(25m, vm.WoodenHiveBonusPercent);
        Assert.Equal(20m, vm.BeeBoostBonusPercent);
        Assert.Equal(10m, vm.SagePropolisBonusPercent);
    }

    [Fact]
    public void UpgradeBlurbPercents_FollowTheConfig()
    {
        var vm = Make(new BeekeeperState { BearName = "B" });
        Assert.Equal(50m, vm.UpgradeBonusPercent(BeekeeperUpgrades.BiggerCombs1));
        Assert.Equal(100m, vm.UpgradeBonusPercent(BeekeeperUpgrades.BiggerCombs2));
        Assert.Equal(50m, vm.UpgradeBonusPercent(BeekeeperUpgrades.BetterWaxCatcher));
        Assert.Equal(25m, vm.UpgradeBonusPercent(BeekeeperUpgrades.PropolisSeal));
        Assert.Null(vm.UpgradeBonusPercent(BeekeeperUpgrades.Smoker));   // "double honey" has no number

        var tuned = new BeekeeperViewModel(isHeadless: true, persist: false,
            config: new BeekeeperConfig { PracticeMultiplier = 1.75m, StrongerCandlesBonus = 2m },
            initialState: new BeekeeperState { BearName = "B" });
        Assert.Equal(75m, tuned.UpgradeBonusPercent(BeekeeperUpgrades.Practice));
        Assert.Equal(100m, tuned.UpgradeBonusPercent(BeekeeperUpgrades.StrongerCandles));
    }

    [Theory]
    [InlineData(StringKey.BeekeeperSellHint)]
    [InlineData(StringKey.BeekeeperHippiesRate)]
    [InlineData(StringKey.BeekeeperUpgradeBiggerCombs1Blurb)]
    [InlineData(StringKey.BeekeeperUpgradeBiggerCombs2Blurb)]
    [InlineData(StringKey.BeekeeperUpgradeBetterWaxCatcherBlurb)]
    [InlineData(StringKey.BeekeeperUpgradeStrongerCandlesBlurb)]
    [InlineData(StringKey.BeekeeperUpgradePracticeBlurb)]
    [InlineData(StringKey.BeekeeperUpgradeMorePracticeBlurb)]
    [InlineData(StringKey.BeekeeperUpgradePropolisSealBlurb)]
    public void TheNumberedWords_TakeTheirNumberFromTheCaller(StringKey key)
    {
        Assert.Contains("%@", Strings.Get(key, AppLanguage.English));
        Assert.Contains("%@", Strings.Get(key, AppLanguage.Spanish));
    }

    [Fact]
    public void BedRows_CoverTheOwnedBeds()
    {
        var vm = Make(new BeekeeperState { BearName = "B" });
        Assert.Equal(1, vm.BedRowCount);
        vm.State.Upgrades.Add(BeekeeperUpgrades.ThirdBed);   // only an old save owns this now
        Assert.Equal(2, vm.BedRowCount);
    }
}
