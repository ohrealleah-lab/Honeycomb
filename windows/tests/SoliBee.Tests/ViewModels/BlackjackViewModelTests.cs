using System.Reflection;
using Xunit;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;

namespace SoliBee.Tests.ViewModels;

public class BlackjackViewModelTests
{
    // ── Payout: blackjack now pays 3:1 instead of 3:2 ──────────────────────────

    [Fact]
    public void TestBlackjackPaysThreeToOne()
    {
        var vm = new BlackjackViewModel();
        vm.Options.IsNoStressMode = false; // pin against whatever's actually persisted on disk
        vm.State.Phase          = BlackjackPhase.Playing;
        vm.State.Credits        = 100;
        vm.State.ActiveHandIndex = 0;

        var hand = new BlackjackHand { Bet = 10, Result = BlackjackHandResult.Blackjack };
        hand.Cards.Add(new Card("p1", CardSuit.Spades, 1, true));
        hand.Cards.Add(new Card("p2", CardSuit.Spades, 13, true));
        vm.State.PlayerHands = new() { hand };

        // Dealer already at 17 (non-blackjack) so DealerPlay's draw loop is a no-op.
        var dealerHand = new BlackjackHand();
        dealerHand.Cards.Add(new Card("d1", CardSuit.Hearts, 10, true));
        dealerHand.Cards.Add(new Card("d2", CardSuit.Hearts, 7, true));
        vm.State.DealerHand = dealerHand;

        vm.Stand(); // AdvanceHand -> DealerPlay -> SettleAndFinish -> ApplyPayout

        Assert.Equal(140, vm.State.Credits); // 100 + (10 back + 30 profit)
    }

    [Fact]
    public void TestRegularWinStillPaysOneToOne()
    {
        var vm = new BlackjackViewModel();
        vm.Options.IsNoStressMode = false;
        vm.State.Phase           = BlackjackPhase.Playing;
        vm.State.Credits         = 100;
        vm.State.ActiveHandIndex = 0;

        var hand = new BlackjackHand { Bet = 10, Result = BlackjackHandResult.Won };
        hand.Cards.Add(new Card("p1", CardSuit.Spades, 10, true));
        hand.Cards.Add(new Card("p2", CardSuit.Spades, 9, true));
        vm.State.PlayerHands = new() { hand };

        var dealerHand = new BlackjackHand();
        dealerHand.Cards.Add(new Card("d1", CardSuit.Hearts, 10, true));
        dealerHand.Cards.Add(new Card("d2", CardSuit.Hearts, 7, true));
        vm.State.DealerHand = dealerHand;

        vm.Stand();

        Assert.Equal(120, vm.State.Credits); // 100 + (10 back + 10 profit), unaffected by the BJ payout change
    }

    [Fact]
    public void TestPushReturnsOriginalBetOnly()
    {
        var vm = new BlackjackViewModel();
        vm.Options.IsNoStressMode = false;
        vm.State.Phase           = BlackjackPhase.Playing;
        vm.State.Credits         = 100;
        vm.State.ActiveHandIndex = 0;

        var hand = new BlackjackHand { Bet = 10, Result = BlackjackHandResult.Push };
        hand.Cards.Add(new Card("p1", CardSuit.Spades, 1, true));
        hand.Cards.Add(new Card("p2", CardSuit.Spades, 13, true));
        vm.State.PlayerHands = new() { hand };

        var dealerHand = new BlackjackHand();
        dealerHand.Cards.Add(new Card("d1", CardSuit.Hearts, 1, true));
        dealerHand.Cards.Add(new Card("d2", CardSuit.Hearts, 13, true));
        vm.State.DealerHand = dealerHand;

        vm.Stand();

        Assert.Equal(110, vm.State.Credits); // just the bet back, no profit
    }

    // ── Chip betting: replace-on-default vs. add ───────────────────────────────

    [Fact]
    public void TestNonOneChipReplacesBetWhenBetIsDefault()
    {
        var vm = new BlackjackViewModel();
        vm.State.Phase      = BlackjackPhase.Betting;
        vm.State.Credits    = 1000;
        vm.State.CurrentBet = 1;

        vm.AddToBet(10);
        Assert.Equal(10, vm.State.CurrentBet); // replaced, not 11

        vm.AddToBet(10);
        Assert.Equal(20, vm.State.CurrentBet); // additive now that bet isn't 1
    }

    [Fact]
    public void TestOneChipAlwaysAddsEvenWhenBetIsDefault()
    {
        var vm = new BlackjackViewModel();
        vm.State.Phase      = BlackjackPhase.Betting;
        vm.State.Credits    = 1000;
        vm.State.CurrentBet = 1;

        vm.AddToBet(1);
        Assert.Equal(2, vm.State.CurrentBet);

        vm.AddToBet(1);
        Assert.Equal(3, vm.State.CurrentBet);
    }

    [Theory]
    [InlineData(5)]
    [InlineData(25)]
    public void TestOtherChipsReplaceBetWhenBetIsDefault(int chip)
    {
        var vm = new BlackjackViewModel();
        vm.State.Phase      = BlackjackPhase.Betting;
        vm.State.Credits    = 1000;
        vm.State.CurrentBet = 1;

        vm.AddToBet(chip);
        Assert.Equal(chip, vm.State.CurrentBet);
    }

    [Fact]
    public void TestChipReplacementClampsToSessionCredits()
    {
        var vm = new BlackjackViewModel();
        vm.State.Phase      = BlackjackPhase.Betting;
        vm.State.Credits    = 8;
        vm.State.CurrentBet = 1;

        vm.AddToBet(10);
        Assert.Equal(8, vm.State.CurrentBet);
    }

    [Fact]
    public void TestChipAdditionClampsToSessionCredits()
    {
        var vm = new BlackjackViewModel();
        vm.State.Phase      = BlackjackPhase.Betting;
        vm.State.Credits    = 15;
        vm.State.CurrentBet = 10;

        vm.AddToBet(10); // would be 20, clamps to 15
        Assert.Equal(15, vm.State.CurrentBet);
    }

    [Fact]
    public void TestAddToBetIsNoOpMidHand()
    {
        var vm = new BlackjackViewModel();
        vm.State.Phase      = BlackjackPhase.Playing;
        vm.State.Credits    = 1000;
        vm.State.CurrentBet = 1;

        vm.AddToBet(10);
        Assert.Equal(1, vm.State.CurrentBet);
    }

    [Fact]
    public void TestDoubleBetDoublesRegardlessOfCurrentBet()
    {
        var vm = new BlackjackViewModel();
        vm.State.Phase      = BlackjackPhase.Betting;
        vm.State.Credits    = 1000;
        vm.State.CurrentBet = 5;

        vm.DoubleBet();
        Assert.Equal(10, vm.State.CurrentBet);
    }

    [Fact]
    public void TestDoubleBetClampsToSessionCredits()
    {
        var vm = new BlackjackViewModel();
        vm.State.Phase      = BlackjackPhase.Betting;
        vm.State.Credits    = 15;
        vm.State.CurrentBet = 10;

        vm.DoubleBet();
        Assert.Equal(15, vm.State.CurrentBet);
    }

    [Fact]
    public void TestClearBetResetsToOne()
    {
        var vm = new BlackjackViewModel();
        vm.State.Phase      = BlackjackPhase.Betting;
        vm.State.Credits    = 1000;
        vm.State.CurrentBet = 25;

        vm.ClearBet();
        Assert.Equal(1, vm.State.CurrentBet);
    }

    // ── CanRebuy ────────────────────────────────────────────────────────────────

    [Fact]
    public void TestCanRebuyOnlyWhenLowOnCreditsInBettingOrResultPhase()
    {
        var vm = new BlackjackViewModel();
        vm.Options.IsNoStressMode = false;

        // CanRebuy is a flat "you're running low" gas light (Credits <= 10),
        // deliberately not bet-relative — see the comment above CanRebuy in
        // BlackjackViewModel: it's an early warning, not "can't afford this bet."
        vm.State.Phase      = BlackjackPhase.Betting;
        vm.State.Credits    = 5;
        vm.State.CurrentBet = 10;
        Assert.True(vm.CanRebuy);

        vm.State.Credits = 10;
        Assert.True(vm.CanRebuy); // still at the threshold, regardless of the bet

        vm.State.Credits = 11;
        Assert.False(vm.CanRebuy); // just above the threshold

        vm.State.Credits = 5;
        vm.State.Phase   = BlackjackPhase.Result;
        Assert.True(vm.CanRebuy);

        vm.State.Phase = BlackjackPhase.Playing;
        Assert.False(vm.CanRebuy); // never offered mid-hand

        vm.State.Phase = BlackjackPhase.DealerTurn;
        Assert.False(vm.CanRebuy); // never offered mid-hand
    }

    // ── No Stress Mode: free play bypasses credits entirely ────────────────────

    [Fact]
    public void TestFreePlayDealBypassesCreditCheck()
    {
        var vm = new BlackjackViewModel();
        vm.Options.IsNoStressMode = true;
        vm.State.Phase      = BlackjackPhase.Betting;
        vm.State.Credits    = 0;
        vm.State.CurrentBet = 50;

        vm.Deal();

        // Not asserting Phase == Playing specifically — a freshly shuffled deck can
        // occasionally deal a natural blackjack, which auto-resolves straight to
        // Result. Either way, Deal() must have proceeded past the credit gate instead
        // of bailing out and leaving the phase at Betting.
        Assert.NotEqual(BlackjackPhase.Betting, vm.State.Phase);
        Assert.Equal(0, vm.State.Credits); // never deducted
    }

    [Fact]
    public void TestFreePlayStillTracksWinsAndStreaksButNotCredits()
    {
        var vm = new BlackjackViewModel();
        vm.Options.IsNoStressMode = true;
        vm.State.Phase           = BlackjackPhase.Playing;
        vm.State.Credits         = 100;
        vm.State.ActiveHandIndex = 0;
        int handsWonBefore = vm.Stats.HandsWon;
        int streakBefore = vm.ConsecutiveWins;

        // Free play is driven by a private snapshot taken at Deal() time (see
        // BlackjackViewModel's _handFreePlay comment) rather than a live read of
        // Options.IsNoStressMode, so scripting a hand directly like this test does
        // has to prime that snapshot by hand.
        SetHandFreePlay(vm, true);

        var hand = new BlackjackHand { Bet = 10, Result = BlackjackHandResult.Won };
        hand.Cards.Add(new Card("p1", CardSuit.Spades, 10, true));
        hand.Cards.Add(new Card("p2", CardSuit.Spades, 9, true));
        vm.State.PlayerHands = new() { hand };

        var dealerHand = new BlackjackHand();
        dealerHand.Cards.Add(new Card("d1", CardSuit.Hearts, 10, true));
        dealerHand.Cards.Add(new Card("d2", CardSuit.Hearts, 7, true));
        vm.State.DealerHand = dealerHand;

        vm.Stand();

        Assert.Equal(100, vm.State.Credits);                // no credits earned
        Assert.Equal(handsWonBefore + 1, vm.Stats.HandsWon);  // win still tracked
        Assert.Equal(streakBefore + 1, vm.ConsecutiveWins);   // streak still tracked
    }

    [Fact]
    public void TestFreePlayCanRebuyIsAlwaysFalse()
    {
        var vm = new BlackjackViewModel();
        vm.Options.IsNoStressMode = true;
        vm.State.Phase      = BlackjackPhase.Betting;
        vm.State.Credits    = 0;
        vm.State.CurrentBet = 50;

        Assert.False(vm.CanRebuy);
    }

    [Fact]
    public void TestFreePlayDoubleAndSplitIgnoreCreditRequirement()
    {
        var vm = new BlackjackViewModel();
        vm.Options.IsNoStressMode = true;
        vm.State.Phase           = BlackjackPhase.Playing;
        vm.State.Credits         = 0;
        vm.State.ActiveHandIndex = 0;

        // See TestFreePlayStillTracksWinsAndStreaksButNotCredits — CanDouble/CanSplit
        // read this same private snapshot, not the live Options flag.
        SetHandFreePlay(vm, true);

        var hand = new BlackjackHand { Bet = 10 };
        hand.Cards.Add(new Card("p1", CardSuit.Spades, 5, true));
        hand.Cards.Add(new Card("p2", CardSuit.Hearts, 5, true));
        vm.State.PlayerHands = new() { hand };
        vm.State.DealerHand  = new BlackjackHand();
        vm.State.DealerHand.Cards.Add(new Card("d1", CardSuit.Clubs, 9, true));
        vm.State.DealerHand.Cards.Add(new Card("d2", CardSuit.Clubs, 2, false));

        Assert.True(vm.CanDouble); // hand totals 10 — normally needs Credits >= Bet
        Assert.True(vm.CanSplit);  // same rank — normally needs Credits >= Bet
    }

    // ── Dealer-turn re-entrancy guard ───────────────────────────────────────────

    [Fact]
    public void TestDealerTurnIsNoOpUnlessPhaseIsPlaying()
    {
        var vm = new BlackjackViewModel();
        vm.State.Phase = BlackjackPhase.Betting;
        int dealerCardsBefore = vm.State.DealerHand.Cards.Count;

        var dealerPlay = typeof(BlackjackViewModel).GetMethod(
            "DealerPlay", BindingFlags.NonPublic | BindingFlags.Instance);
        dealerPlay!.Invoke(vm, null);

        Assert.Equal(BlackjackPhase.Betting, vm.State.Phase);
        Assert.Equal(dealerCardsBefore, vm.State.DealerHand.Cards.Count);
    }

    // BlackjackViewModel snapshots No Stress Mode into a private field at Deal()
    // time, deliberately not re-reading the live Options flag (see its own comment)
    // — tests that script a hand directly without calling Deal() have to set that
    // snapshot by hand to exercise free-play behavior.
    private static void SetHandFreePlay(BlackjackViewModel vm, bool value)
    {
        typeof(BlackjackViewModel)
            .GetField("_handFreePlay", BindingFlags.NonPublic | BindingFlags.Instance)!
            .SetValue(vm, value);
    }
}
