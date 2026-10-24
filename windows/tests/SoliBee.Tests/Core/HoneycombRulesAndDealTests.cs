using System;
using System.Collections.Generic;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.Core;

// Honeycomb rule choices and how a match is dealt (Mac: HoneycombRulesAndDealTests), plus the
// "take a card from the opponent" rules. The roulette and the deck rolls are random, so those
// tests roll many times and check that a rule of the game is NEVER broken (a banned rule never
// appears, a pair that can't coexist never coexists) rather than asserting any one random
// result. The private rolling methods are called directly, so thousands of rolls stay quick.
public class HoneycombRulesAndDealTests : DataSandbox
{
    private readonly HashSet<int> _unlockedAtStart;

    public HoneycombRulesAndDealTests()
    {
        // The card bank is an in-memory singleton as well as a file — put it back afterwards.
        _unlockedAtStart = HoneycombProfileManager.Shared.UnlockedCardIds.ToHashSet();
    }

    public new void Dispose()
    {
        var bank = HoneycombProfileManager.Shared.UnlockedCardIds;
        bank.Clear();
        foreach (var id in _unlockedAtStart) bank.Add(id);
        base.Dispose();
    }

    private static HoneycombViewModel NewVm(HoneycombDifficulty difficulty = HoneycombDifficulty.Easy,
        IEnumerable<HoneycombRule>? manual = null, bool forceNormal = false, IEnumerable<string>? banned = null)
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        var o = new HoneycombOptions { Difficulty = difficulty, ForceNormalRules = forceNormal };
        if (manual != null) foreach (var r in manual) o.ManualRules.Add(r);
        if (banned != null) foreach (var b in banned) o.BannedRules.Add(b);
        vm.Options = o;
        vm.State.MatchDifficulty = difficulty;
        return vm;
    }

    private static List<HoneycombRule> Roll(HoneycombViewModel vm) =>
        (List<HoneycombRule>)Reflect.Call(vm, "DetermineActiveRules")!;

    private static List<HoneycombCardData> RollDeck(HoneycombViewModel vm) =>
        (List<HoneycombCardData>)Reflect.Call(vm, "RollOpponentDeck")!;

    private static HoneycombCardData CardOfStars(int stars, int skip = 0) =>
        HoneycombDatabase.Shared.AllCards.Where(c => c.Stars == stars).Skip(skip).First();

    // ---- Rules picked on the Rules screen ----

    [Fact]
    public void ForcedNormalMode_PlaysNoRules()
    {
        foreach (var difficulty in Enum.GetValues<HoneycombDifficulty>())
        {
            var vm = NewVm(difficulty, manual: new[] { HoneycombRule.Plus, HoneycombRule.Same }, forceNormal: true);
            for (int i = 0; i < 50; i++) Assert.Empty(Roll(vm));
        }
    }

    [Fact]
    public void PickedRules_AreExactlyTheRulesPlayed()
    {
        var picked = new[] { HoneycombRule.Plus, HoneycombRule.Reverse, HoneycombRule.Order };
        var vm = NewVm(HoneycombDifficulty.Medium, manual: picked);
        for (int i = 0; i < 20; i++) Assert.Equal(picked.ToHashSet(), Roll(vm).ToHashSet());
    }

    // ---- The roulette ----

    [Theory]
    [InlineData(HoneycombDifficulty.Easy, 2)]
    [InlineData(HoneycombDifficulty.Medium, 2)]
    [InlineData(HoneycombDifficulty.Hard, 4)]
    [InlineData(HoneycombDifficulty.UltraHard, 4)]
    public void Roulette_NeverBreaksBans_Exclusives_OrDifficultyLimits(HoneycombDifficulty difficulty, int maxRules)
    {
        var banned = new[] { HoneycombRule.Swap.ToString(), HoneycombRule.SuddenDeath.ToString() };
        var vm = NewVm(difficulty, banned: banned);
        bool sawRules = false;
        for (int i = 0; i < 2000; i++)
        {
            var rules = Roll(vm);
            var set = rules.ToHashSet();
            Assert.Equal(set.Count, rules.Count);   // no rule twice
            Assert.DoesNotContain(HoneycombRule.Swap, set);
            Assert.DoesNotContain(HoneycombRule.SuddenDeath, set);
            Assert.False(set.Contains(HoneycombRule.Ascension) && set.Contains(HoneycombRule.Descension));
            Assert.False(set.Contains(HoneycombRule.Order) && set.Contains(HoneycombRule.Chaos));
            Assert.False(set.Contains(HoneycombRule.AllOpen) && set.Contains(HoneycombRule.ThreeOpen));
            Assert.False(set.Contains(HoneycombRule.BombShelter) && (set.Contains(HoneycombRule.AllOpen) || set.Contains(HoneycombRule.ThreeOpen)));
            Assert.True(rules.Count <= maxRules, $"{difficulty} rolled {rules.Count} rules");
            if (difficulty == HoneycombDifficulty.Easy)
                Assert.False(set.Overlaps(new[] { HoneycombRule.Ascension, HoneycombRule.Descension, HoneycombRule.FallenAce }));
            if (rules.Count > 0) sawRules = true;
        }
        Assert.True(sawRules);
    }

    [Theory]
    [InlineData(HoneycombDifficulty.Easy)]
    [InlineData(HoneycombDifficulty.Medium)]
    [InlineData(HoneycombDifficulty.Hard)]
    [InlineData(HoneycombDifficulty.UltraHard)]
    public void BanningNormalMode_AlwaysRollsAtLeastOneRule(HoneycombDifficulty difficulty)
    {
        var vm = NewVm(difficulty, banned: new[] { "Normal Mode" });
        for (int i = 0; i < 2000; i++) Assert.NotEmpty(Roll(vm));
    }

    [Fact]
    public void Roulette_WithOneRuleLeft_OnlyUsesThatRule()
    {
        var others = Enum.GetValues<HoneycombRule>().Where(r => r != HoneycombRule.Plus).Select(r => r.ToString()).ToList();
        var vm = NewVm(HoneycombDifficulty.Hard, banned: others);
        bool sawPlus = false;
        for (int i = 0; i < 500; i++)
        {
            var rules = Roll(vm);
            Assert.True(rules.Count <= 1 && rules.All(r => r == HoneycombRule.Plus));
            if (rules.Count == 1) sawPlus = true;
        }
        Assert.True(sawPlus);
    }

    [Fact]
    public void Roulette_AllRulesAreReachable_WhenNothingIsBanned()
    {
        var vm = NewVm(HoneycombDifficulty.UltraHard);
        var seen = new HashSet<HoneycombRule>();
        for (int i = 0; i < 4000; i++) foreach (var r in Roll(vm)) seen.Add(r);
        Assert.Equal(Enum.GetValues<HoneycombRule>().ToHashSet(), seen);
    }

    [Fact]
    public void RuleWeights_MakeComboRulesCommonAndRestrictiveOnesRare()
    {
        Assert.True(HoneycombRule.Plus.Weight() > HoneycombRule.Swap.Weight());
        Assert.True(HoneycombRule.Swap.Weight() > HoneycombRule.Ascension.Weight());
        Assert.True(HoneycombRule.Ascension.Weight() > HoneycombRule.Reverse.Weight());
        Assert.All(Enum.GetValues<HoneycombRule>(), r => Assert.True(r.Weight() > 0));
    }

    [Fact]
    public void EveryRule_HasANameAndAnExplanation()
    {
        foreach (var r in Enum.GetValues<HoneycombRule>())
        {
            Assert.False(string.IsNullOrWhiteSpace(r.DisplayName()));
            Assert.False(string.IsNullOrWhiteSpace(r.GetExplanation()));
        }
        Assert.Contains("Hearts", HoneycombRule.Ascension.GetExplanation(new HashSet<string> { "H" }));
        Assert.Contains("Spades", HoneycombRule.Descension.GetExplanation(new HashSet<string> { "S" }));
        Assert.Equal("Pollination", HoneycombRule.Ascension.DisplayName());
    }

    // ---- The opponent's deck ----

    private static List<int> Stars(HoneycombViewModel vm) => RollDeck(vm).Select(c => c.Stars).OrderBy(s => s).ToList();

    [Fact]
    public void OpponentDeck_StarsPerDifficulty()
    {
        void Check(HoneycombDifficulty d, HoneycombRule[] rules, params int[][] allowed)
        {
            var vm = NewVm(d);
            vm.State.ActiveRules = rules.ToList();
            for (int i = 0; i < 300; i++)
            {
                var stars = Stars(vm);
                Assert.Contains(allowed, a => a.SequenceEqual(stars));
            }
        }
        var none = Array.Empty<HoneycombRule>();
        Check(HoneycombDifficulty.Easy, none, new[] { 1, 1, 1, 2, 2 }, new[] { 1, 1, 1, 2, 3 });
        Check(HoneycombDifficulty.Medium, none, new[] { 2, 2, 2, 2, 3 }, new[] { 2, 2, 2, 2, 4 });
        Check(HoneycombDifficulty.Hard, none, new[] { 3, 3, 3, 4, 5 });
        Check(HoneycombDifficulty.UltraHard, none, new[] { 3, 3, 4, 5, 5 });
        // Under Inversion (low stats win) the strong tiers are the LOW ones.
        var reverse = new[] { HoneycombRule.Reverse };
        Check(HoneycombDifficulty.Easy, reverse, new[] { 1, 1, 1, 2, 2 }, new[] { 1, 1, 1, 2, 3 });
        Check(HoneycombDifficulty.Medium, reverse, new[] { 2, 2, 2, 2, 3 }, new[] { 2, 2, 2, 2, 4 });
        Check(HoneycombDifficulty.Hard, reverse, new[] { 1, 1, 2, 2, 2 });
        Check(HoneycombDifficulty.UltraHard, reverse, new[] { 1, 1, 1, 1, 1 });
    }

    [Theory]
    [InlineData(HoneycombDifficulty.Easy)]
    [InlineData(HoneycombDifficulty.Medium)]
    [InlineData(HoneycombDifficulty.Hard)]
    [InlineData(HoneycombDifficulty.UltraHard)]
    public void OpponentDeck_HasFiveDifferentCards(HoneycombDifficulty difficulty)
    {
        var vm = NewVm(difficulty);
        vm.State.ActiveRules = new List<HoneycombRule>();
        for (int i = 0; i < 1500; i++)
        {
            var deck = RollDeck(vm);
            Assert.Equal(5, deck.Count);
            Assert.Equal(5, deck.Select(c => c.Id).Distinct().Count());
        }
    }

    [Fact]
    public void UltraHard_WithPollination_GuaranteesThreeCardsOfThePollinationSuit()
    {
        var vm = NewVm(HoneycombDifficulty.UltraHard);
        vm.State.ActiveRules = new List<HoneycombRule> { HoneycombRule.Ascension };
        vm.State.Board.AscensionDescensionSuits = new List<string> { "H" };
        for (int i = 0; i < 300; i++)
            Assert.True(RollDeck(vm).Count(c => c.Suit == "H") >= 3);

        // Smoked Out is a penalty, so the AI isn't given extra cards of that suit.
        vm.State.ActiveRules = new List<HoneycombRule> { HoneycombRule.Descension };
        int enough = 0;
        for (int i = 0; i < 300; i++) if (RollDeck(vm).Count(c => c.Suit == "H") >= 3) enough++;
        Assert.True(enough < 300);
    }

    [Fact]
    public void FavorNewCards_AlwaysLeavesTheOpponentWithSomethingYouDontOwn()
    {
        // Own every 1★–3★ card except one 1★, so a deck of only owned cards is a real possibility.
        var db = HoneycombDatabase.Shared;
        var missing = CardOfStars(1);
        var bank = HoneycombProfileManager.Shared.UnlockedCardIds;
        bank.Clear();
        foreach (var c in db.AllCards.Where(c => c.Stars <= 3 && c.Id != missing.Id)) bank.Add(c.Id);

        var vm = NewVm(HoneycombDifficulty.Easy);
        vm.State.ActiveRules = new List<HoneycombRule>();
        vm.State.NoStressModeThisMatch = false;
        for (int i = 0; i < 400; i++)
            Assert.Contains(RollDeck(vm), c => !bank.Contains(c.Id));
    }

    [Fact]
    public void NoStressMode_SkipsFavorNewCards()
    {
        var db = HoneycombDatabase.Shared;
        var bank = HoneycombProfileManager.Shared.UnlockedCardIds;
        foreach (var c in db.AllCards.Where(c => c.Stars <= 3)) bank.Add(c.Id);   // everything the Easy deck uses
        var vm = NewVm(HoneycombDifficulty.Easy);
        vm.State.ActiveRules = new List<HoneycombRule>();
        vm.State.NoStressModeThisMatch = true;
        Assert.Equal(5, RollDeck(vm).Count);   // no stealing in No Stress, so nothing is swapped in
    }

    [Fact]
    public void NoStressMode_DealsThePlayerTheStrongDeck()
    {
        var vm = NewVm();
        vm.State.NoStressModeThisMatch = true;
        for (int i = 0; i < 20; i++)
        {
            var hand = (List<HoneycombCard>)Reflect.Call(vm, "BuildPlayerHand")!;
            Assert.Equal(new[] { 3, 3, 3, 4, 5 }, hand.Select(c => c.Data.Stars).OrderBy(s => s));
            Assert.All(hand, c => Assert.Equal(1, c.Owner));
        }
    }

    // ---- Starting a match ----

    [Fact]
    public void StartNewMatch_UsesThePickedRules_AndLocksTheDifficulty()
    {
        var vm = NewVm(HoneycombDifficulty.Easy, manual: new[] { HoneycombRule.Plus, HoneycombRule.Order });
        vm.StartNewMatch();
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);
        Assert.Equal(HoneycombPhase.Playing, vm.State.Phase);
        Assert.Equal(new[] { HoneycombRule.Order, HoneycombRule.Plus }.ToHashSet(), vm.State.ActiveRules.ToHashSet());
        Assert.Equal(HoneycombDifficulty.Easy, vm.State.MatchDifficulty);

        // Changing the picker mid-match doesn't change the match; the next match uses it.
        vm.Options.Difficulty = HoneycombDifficulty.Medium;
        Assert.Equal(HoneycombDifficulty.Easy, vm.State.MatchDifficulty);
        vm.StartNewMatch();
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);
        Assert.Equal(HoneycombDifficulty.Medium, vm.State.MatchDifficulty);
    }

    [Fact]
    public void StartNewMatch_WithForcedNormal_PlaysNoRules_AndNoAscensionSuit()
    {
        var vm = NewVm(forceNormal: true);
        vm.StartNewMatch();
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);
        Assert.Empty(vm.State.ActiveRules);
        Assert.Empty(vm.State.Board.AscensionDescensionSuits);
    }

    [Fact]
    public void StartNewMatch_WithPollination_PicksExactlyOneRealSuit()
    {
        var vm = NewVm(manual: new[] { HoneycombRule.Ascension, HoneycombRule.Same });
        for (int i = 0; i < 10; i++)
        {
            vm.StartNewMatch();
            HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);
            var suits = vm.State.Board.AscensionDescensionSuits;
            Assert.Single(suits);
            Assert.Contains(suits[0], new[] { "S", "H", "D", "C" });
        }
    }

    [Fact]
    public void ADealtMatch_GivesBothSidesFiveCards_AndTheOpponentsAreDifferent()
    {
        var vm = NewVm(forceNormal: true);
        vm.StartNewMatch();
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);
        var all = vm.State.Board.Cells.Where(c => c.Card != null).Select(c => c.Card!).ToList();
        Assert.Equal(10, vm.State.PlayerHand.Count + vm.State.OpponentHand.Count + all.Count);   // five each, in hand or on the board
        Assert.Equal(5, vm.State.PlayerStartingDeck.Count);
        var opponentCards = vm.State.OpponentHand.Concat(all.Where(c => c.OriginalOwner == -1)).ToList();
        Assert.Equal(5, opponentCards.Select(c => c.Data.Id).Distinct().Count());
    }

    // ---- Taking a card from the opponent ----

    private static HoneycombCard Placed(HoneycombViewModel vm, int cell, HoneycombCardData data, int owner, int originalOwner)
    {
        var card = new HoneycombCard(data, owner) { OriginalOwner = originalOwner };
        vm.State.Board.Cells[cell].Card = card;
        return card;
    }

    private static HoneycombViewModel WinningMatch(out HoneycombCard stealable, out HoneycombCard mine)
    {
        var vm = NewVm();
        HoneycombProfileManager.Shared.UnlockedCardIds.Clear();
        stealable = Placed(vm, 0, CardOfStars(2), owner: 1, originalOwner: -1);   // the opponent's, captured by me
        mine = Placed(vm, 1, CardOfStars(1), owner: 1, originalOwner: 1);
        vm.State.PlayerScore = 6;
        vm.State.OpponentScore = 3;
        return vm;
    }

    [Fact]
    public void StealEligibility_NeedsAnOpponentCardYouCapturedAndDontOwn()
    {
        var vm = WinningMatch(out var stealable, out var mine);
        Assert.True(vm.IsStealEligible(stealable));
        Assert.False(vm.IsStealEligible(mine));                                   // your own card
        var notCaptured = new HoneycombCard(CardOfStars(2, 1), -1) { OriginalOwner = -1 };
        Assert.False(vm.IsStealEligible(notCaptured));                            // still the opponent's on the board

        HoneycombProfileManager.Shared.UnlockedCardIds.Add(stealable.Data.Id);
        Assert.False(vm.IsStealEligible(stealable));                              // you already own it
    }

    [Fact]
    public void Steal_RequestConfirmAndCancel()
    {
        var vm = WinningMatch(out var stealable, out _);
        vm.RequestSteal(0);
        Assert.NotNull(vm.PendingSteal);
        Assert.Equal(0, vm.PendingSteal!.BoardIndex);
        Assert.Equal(stealable.Data.Name, vm.PendingSteal.CardName);

        vm.CancelPendingSteal();
        Assert.Null(vm.PendingSteal);
        Assert.DoesNotContain(stealable.Data.Id, HoneycombProfileManager.Shared.UnlockedCardIds);

        var stolenBefore = vm.Stats.CardsStolen;
        vm.RequestSteal(0);
        vm.ConfirmPendingSteal();
        Assert.Null(vm.PendingSteal);
        Assert.Contains(stealable.Data.Id, HoneycombProfileManager.Shared.UnlockedCardIds);
        Assert.Equal(stolenBefore + 1, vm.Stats.CardsStolen);
        Assert.True(vm.State.HasStolenThisMatch);

        // One steal per match.
        var second = Placed(vm, 2, CardOfStars(2, 2), owner: 1, originalOwner: -1);
        vm.RequestSteal(2);
        Assert.Null(vm.PendingSteal);
        Assert.DoesNotContain(second.Data.Id, HoneycombProfileManager.Shared.UnlockedCardIds);
    }

    [Fact]
    public void Steal_IsRefused_WhenYouDidntWin_InNoStress_OrForTheWrongCard()
    {
        var vm = WinningMatch(out _, out _);
        vm.State.PlayerScore = 4; vm.State.OpponentScore = 4;
        vm.RequestSteal(0);
        Assert.Null(vm.PendingSteal);                       // a draw isn't a win

        vm.State.PlayerScore = 6; vm.State.OpponentScore = 3;
        vm.RequestSteal(1);
        Assert.Null(vm.PendingSteal);                       // your own card
        vm.RequestSteal(5);
        Assert.Null(vm.PendingSteal);                       // an empty cell

        vm.State.NoStressModeThisMatch = true;
        vm.RequestSteal(0);
        Assert.Null(vm.PendingSteal);                       // no stealing in No Stress Mode
    }

    [Fact]
    public void ConfirmingASteal_AfterTheScoreChanges_DoesNothing()
    {
        var vm = WinningMatch(out var stealable, out _);
        vm.RequestSteal(0);
        vm.State.OpponentScore = 9;
        vm.ConfirmPendingSteal();
        Assert.DoesNotContain(stealable.Data.Id, HoneycombProfileManager.Shared.UnlockedCardIds);
        Assert.False(vm.State.HasStolenThisMatch);
        Assert.Null(vm.PendingSteal);
    }

    [Fact]
    public void OpponentCardsRemaining_CountsTheFrozenDeckNotYetInTheBank()
    {
        var vm = NewVm();
        Assert.Equal(0, vm.OpponentCardsRemainingCount());
        Assert.False(vm.HasObtainedAllOpponentCards());

        var deck = new List<HoneycombCardData> { CardOfStars(2), CardOfStars(2, 1), CardOfStars(3) };
        Reflect.Set(vm, "_rematchOpponentDeck", deck);
        var bank = HoneycombProfileManager.Shared.UnlockedCardIds;
        foreach (var c in deck) bank.Remove(c.Id);
        Assert.Equal(3, vm.OpponentCardsRemainingCount());
        Assert.False(vm.HasObtainedAllOpponentCards());

        bank.Add(deck[0].Id);
        Assert.Equal(2, vm.OpponentCardsRemainingCount());
        bank.Add(deck[1].Id); bank.Add(deck[2].Id);
        Assert.Equal(0, vm.OpponentCardsRemainingCount());
        Assert.True(vm.HasObtainedAllOpponentCards());
    }

    [Fact]
    public void StealProtection_TurnsOnAfterTwoRematchWinsWithNothingToSteal_AndStaysOn()
    {
        var vm = NewVm();
        HoneycombProfileManager.Shared.UnlockedCardIds.Clear();
        // Only cards the player already owns are on the board, so nothing is stealable.
        var owned = CardOfStars(2);
        HoneycombProfileManager.Shared.UnlockedCardIds.Add(owned.Id);
        Placed(vm, 0, owned, owner: 1, originalOwner: -1);

        Reflect.Set(vm, "_isRematchMatch", false);
        Reflect.Call(vm, "ApplyStealProtection");
        Reflect.Call(vm, "ApplyStealProtection");
        Assert.False(vm.State.StealProtectionActive);        // only counts within a rematch chain

        Reflect.Set(vm, "_isRematchMatch", true);
        Reflect.Call(vm, "ApplyStealProtection");
        Assert.False(vm.State.StealProtectionActive);        // one such win isn't enough
        Reflect.Call(vm, "ApplyStealProtection");
        Assert.True(vm.State.StealProtectionActive);         // two in a row is

        // With protection on, any not-yet-owned card on the board becomes stealable.
        var unowned = Placed(vm, 1, CardOfStars(3), owner: -1, originalOwner: -1);
        Assert.True(vm.IsStealEligible(unowned));
        Reflect.Call(vm, "ApplyStealProtection");
        Assert.True(vm.State.StealProtectionActive);         // sticky
    }

    [Fact]
    public void StealProtection_ResetsItsCount_WhenARoundHadSomethingToSteal()
    {
        var vm = NewVm();
        HoneycombProfileManager.Shared.UnlockedCardIds.Clear();
        Reflect.Set(vm, "_isRematchMatch", true);
        var owned = CardOfStars(2);
        HoneycombProfileManager.Shared.UnlockedCardIds.Add(owned.Id);
        Placed(vm, 0, owned, owner: 1, originalOwner: -1);
        Reflect.Call(vm, "ApplyStealProtection");            // 1 win with nothing to steal

        Placed(vm, 1, CardOfStars(3), owner: 1, originalOwner: -1);   // now there is something
        Reflect.Call(vm, "ApplyStealProtection");
        Assert.False(vm.State.StealProtectionActive);

        vm.State.Board.Cells[1].Card = null;                 // and none again: counting starts over
        Reflect.Call(vm, "ApplyStealProtection");
        Assert.False(vm.State.StealProtectionActive);
        Reflect.Call(vm, "ApplyStealProtection");
        Assert.True(vm.State.StealProtectionActive);
    }
}
