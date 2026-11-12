using System.Collections.Generic;
using SoliBee.Core.Models;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Bee, 2026-11-12: honey pots, beeswax candles and bee bread left The Workbench. Each is introduced by a
/// story card whose button makes the first one; then the Hive row gets +1 / +10 / +100 links (+1000 when a whole
/// 1000 can be paid for).</summary>
public class BeekeeperCraftLinkTests
{
    private sealed class FakeRandom : IRandomSource
    {
        public double NextDouble() => 0.99;
        public int Next(int maxExclusive) => 0;
    }

    // The older cards are done, so only the craft cards can show.
    private static BeekeeperState Base() => new()
    {
        StartingJarsGiven = true, ClayJars = 3m, ToolLevel = 1, HoneyRevealed = true, WorkbenchRevealed = true,
        StoriesDone = new List<string> { BeekeeperStories.Opening, BeekeeperStories.Ouch, BeekeeperStories.Gloves, BeekeeperStories.Smoker },
    };

    private static BeekeeperEngine Make(BeekeeperState s) => new(new BeekeeperConfig(), s, new FakeRandom());

    [Fact]
    public void PotHoneyCard_ComesAtFiftyHoney_NotBefore()
    {
        var s = Base(); s.Honey = 49m;
        var e = Make(s);
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);

        s = Base(); s.Honey = 50m;
        e = Make(s);
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.PotHoney, e.StoryHere);
    }

    [Fact]
    public void PotHoneyCardButton_PotsOne_ClosesTheCardForGood_AndOpensTheLinks()
    {
        var s = Base(); s.Honey = 50m;
        var e = Make(s);
        e.AdvanceStoryTime(1m);
        Assert.False(e.CraftLinksOpen(BeekeeperStories.PotHoney));

        var r = e.CraftFromStory();
        Assert.True(r.Done);
        Assert.Equal(1m, s.PottedHoney);
        Assert.Null(e.StoryHere);
        Assert.True(e.CraftLinksOpen(BeekeeperStories.PotHoney));

        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);   // once and never again
    }

    [Fact]
    public void CandleCard_ComesWhenWaxMakesThreeCandles()
    {
        var s = Base(); s.WaxRevealed = true;
        var probe = Make(s);
        decimal one = probe.BeeswaxCandleWaxNow;

        s = Base(); s.WaxRevealed = true; s.Wax = one * 2m;
        var e = Make(s);
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);

        s = Base(); s.WaxRevealed = true; s.Wax = one * 3m;
        e = Make(s);
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.Candle, e.StoryHere);
        Assert.True(e.CraftFromStory().Done);
        Assert.Equal(1m, s.BeeswaxCandles);
        Assert.True(e.CraftLinksOpen(BeekeeperStories.Candle));
    }

    [Fact]
    public void BeeBreadCard_MakesTheFirstBeeBread()
    {
        var s = Base(); s.PollenRevealed = true; s.Pollen = 10m; s.Honey = 1m;
        var e = Make(s);
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.BeeBread, e.StoryHere);
        Assert.True(e.CraftFromStory().Done);
        Assert.Equal(1m, s.BeeBread);
        Assert.True(e.CraftLinksOpen(BeekeeperStories.BeeBread));
    }

    [Fact]
    public void ACardLeavesByItself_WhenTheFirstOneCantBeMadeAnyMore()
    {
        var s = Base(); s.PollenRevealed = true; s.Pollen = 10m; s.Honey = 1m;
        var e = Make(s);
        e.AdvanceStoryTime(1m);
        Assert.Equal(BeekeeperStories.BeeBread, e.StoryHere);
        s.Pollen = 0m;
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);
        Assert.False(e.CraftLinksOpen(BeekeeperStories.BeeBread));   // not done, so it can come back
    }

    [Fact]
    public void TheThirdLink_IsAHundred_UnlessAWholeThousandCanBePaid()
    {
        var cfg = new BeekeeperConfig();
        var s = Base(); s.PollenRevealed = true; s.Pollen = cfg.BeeBreadPollen * 1000m - 10m; s.Honey = cfg.BeeBreadHoney * 1000m;
        var e = Make(s);
        Assert.Equal(cfg.CraftLinkBig, e.CraftBigStep(BeekeeperStories.BeeBread));

        s.Pollen = cfg.BeeBreadPollen * 1000m;
        Assert.Equal(cfg.CraftLinkHuge, e.CraftBigStep(BeekeeperStories.BeeBread));
    }

    [Fact]
    public void CraftTimes_MakesTheBatch()
    {
        var s = Base(); s.PollenRevealed = true; s.Pollen = 100m; s.Honey = 10m;
        var e = Make(s);
        Assert.True(e.CraftTimes(BeekeeperStories.BeeBread, 10).Done);
        Assert.Equal(10m, s.BeeBread);
        Assert.Equal(0m, s.Pollen);
        Assert.False(e.CraftTimes(BeekeeperStories.BeeBread, 1).Done);   // none left
    }

    [Fact]
    public void ASaveThatAlreadyMadeThem_HasTheLinks_AndNeverSeesTheCards()
    {
        var s = Base(); s.PottedHoneyRevealed = true; s.BeeBreadRevealed = true; s.CandlesCrafted = 4; s.Honey = 50m;
        var e = Make(s);
        Assert.True(e.CraftLinksOpen(BeekeeperStories.PotHoney));
        Assert.True(e.CraftLinksOpen(BeekeeperStories.BeeBread));
        Assert.True(e.CraftLinksOpen(BeekeeperStories.Candle));
        e.AdvanceStoryTime(1m);
        Assert.Null(e.StoryHere);
    }
}
