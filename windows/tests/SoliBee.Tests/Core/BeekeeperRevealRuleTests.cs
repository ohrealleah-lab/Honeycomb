using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.Core;

/// <summary>Which Hive rows show is decided in the engine (specs 009 to 015); the view model only reads it.</summary>
public class BeekeeperRevealRuleTests
{
    private static BeekeeperEngine Make(BeekeeperState s) => new(state: s);

    private static BeekeeperState Base() => new() { BearName = "B", HoneyRevealed = true };

    [Fact]
    public void PaperRow_StaysOnceSeen_EvenAfterSpendingAllPaper_WithNoWaspTrades()
    {
        // "+20 paper" from the debug menu, then the Notebook (20 paper) is bought.
        var e = Make(Base());
        e.DebugGivePaper(20m);
        e.State.Paper -= 20m;
        Assert.True(e.PaperSeen);
        Assert.True(e.PaperShown);
    }

    [Fact]
    public void PaperRow_IsHiddenUntilPaperIsSeen()
    {
        Assert.False(Make(Base()).PaperShown);
        Assert.True(Make(Base().With(s => s.WaspTrades = 1)).PaperShown);
    }

    [Fact]
    public void PollenRow_ShowsWhenForagingStarts_NotOnlyAtTheFirstWholePollen()
    {
        var e = Make(Base().With(s => s.Plants.Add(BeekeeperPlants.Wildflowers)));
        Assert.False(e.State.PollenRevealed);
        Assert.True(e.PollenShown);
        Assert.False(Make(Base()).PollenShown);
    }

    [Fact]
    public void PropolisRow_ShowsWithResin_OrAnyPropolis_OrOnceRevealed()
    {
        Assert.False(Make(Base()).PropolisShown);
        Assert.True(Make(Base().With(s => s.Plants.Add(BeekeeperPlants.Poplar))).PropolisShown);
        Assert.True(Make(Base().With(s => s.Propolis = 0.5m)).PropolisShown);
        Assert.True(Make(Base().With(s => s.PropolisRevealed = true)).PropolisShown);
    }

    [Fact]
    public void RepellentRow_NeedsAFirstCandle_AndRetiresWithTheEmissary()
    {
        var unlocked = Make(Base().With(s => s.RepellentUnlocked = true));
        Assert.True(unlocked.RepellentShown);
        Assert.False(unlocked.RepellentCandlesRowShown);   // unlocked is not crafted
        unlocked.State.RepellentCrafted = true;
        Assert.True(unlocked.RepellentCandlesRowShown);
        unlocked.State.EmissaryCome = true;
        Assert.False(unlocked.RepellentShown);
        Assert.False(unlocked.RepellentCandlesRowShown);
    }

    [Fact]
    public void BeeswaxRow_FollowsTheFirstCandleCrafted()
    {
        Assert.False(Make(Base()).BeeswaxCandlesShown);
        Assert.True(Make(Base().With(s => s.CandlesCrafted = 1)).BeeswaxCandlesShown);
    }

    [Fact]
    public void PropolisCandleRows_ShowWithTheirRecipes_OrWhileHeld()
    {
        Assert.False(Make(Base()).BeeBoostCandlesShown);
        Assert.True(Make(Base().With(s => s.BeeBoostCandles = 1m)).BeeBoostCandlesShown);
        Assert.True(Make(Base().With(s => s.SagePropolisCandles = 1m)).SagePropolisCandlesShown);
        var recipes = Make(Base().With(s => { s.WorkbenchRevealed = true; s.Plants.Add(BeekeeperPlants.Poplar); }));
        Assert.True(recipes.BeeBoostCandlesShown);
        Assert.True(recipes.SagePropolisCandlesShown);
    }

    [Fact]
    public void TheHiveCard_ReadsTheEngineRules()
    {
        var vm = new BeekeeperViewModel(isHeadless: true, persist: false, initialState: Base().With(s =>
        {
            s.Plants.Add(BeekeeperPlants.Wildflowers);
            s.PaperRevealed = true;
        }));
        bool Shown(string id) => vm.HiveGroups.SelectMany(g => g.Rows).First(r => r.Id == id).Visible;
        Assert.True(Shown(BeekeeperHiveRows.Pollen));
        Assert.True(Shown(BeekeeperHiveRows.Paper));
        Assert.False(Shown(BeekeeperHiveRows.Propolis));
    }
}

internal static class StateExtensions
{
    public static BeekeeperState With(this BeekeeperState s, System.Action<BeekeeperState> change)
    {
        change(s);
        return s;
    }
}
