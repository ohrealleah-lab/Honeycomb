using System.Collections.Generic;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;
using static SoliBee.Tests.Cards;

namespace SoliBee.Tests.ViewModels;

// Desktop Video Poker round flow on fixed hands (ported from Mac's VideoPokerGameplayTests):
// bets and credits, holds and the draw, payouts, streaks, free play (No Stress), rebuy and
// the out-of-credits toast, banners, and what survives a relaunch.
public class VideoPokerGameplayTests : DataSandbox
{
    // A fresh install: no saved Video Poker options or stats.
    private static VideoPokerViewModel Fresh()
    {
        Delete("videopoker_options.json");
        Delete("videopoker_stats.json");
        return new VideoPokerViewModel();
    }

    // Runs the real Deal() (so credits/stats are charged), then swaps in known cards.
    // `deck` is drawn from the front.
    private static void Dealt(VideoPokerViewModel vm, List<Card> hand, List<Card>? deck = null)
    {
        vm.Deal();
        vm.State.Hand = hand;
        Reflect.Set(vm, "_deck", deck ?? new List<Card>());
    }

    private static void HoldAllAndDraw(VideoPokerViewModel vm) { vm.HoldAll(); vm.Draw(); }

    private static int Queued(VideoPokerViewModel vm) => Reflect.Get<Queue<string>>(vm, "_bannerQueue").Count;

    private static int Drain(VideoPokerViewModel vm)
    {
        int n = Queued(vm);
        for (int i = 0; i < n; i++) vm.AdvanceBannerQueue();
        return n;
    }

    private static List<Card> JacksPair() =>
        new() { C(CardSuit.Hearts, 11), C(CardSuit.Spades, 11), C(CardSuit.Clubs, 2), C(CardSuit.Diamonds, 5), C(CardSuit.Clubs, 9) };

    private static List<Card> Nothing() =>
        new() { C(CardSuit.Hearts, 2), C(CardSuit.Spades, 5), C(CardSuit.Diamonds, 9), C(CardSuit.Clubs, 3), C(CardSuit.Hearts, 7) };

    private static List<Card> RoyalHearts() =>
        new() { C(CardSuit.Hearts, 1), C(CardSuit.Hearts, 13), C(CardSuit.Hearts, 12), C(CardSuit.Hearts, 11), C(CardSuit.Hearts, 10) };

    [Fact]
    public void Deal_ChargesTheBetAndShowsFiveCards()
    {
        var vm = Fresh();
        Assert.Equal(100, vm.State.SessionCredits);
        Assert.Equal(1, vm.State.CurrentBet);
        Assert.Equal(VideoPokerPhase.Deal, vm.State.Phase);
        Assert.True(vm.IsDealing && !vm.IsHolding && vm.CanDeal);

        vm.IncreaseBet(); vm.IncreaseBet();
        vm.Deal();

        Assert.Equal(VideoPokerPhase.Holding, vm.State.Phase);
        Assert.Equal(5, vm.State.Hand.Count);
        Assert.All(vm.State.Hand, c => Assert.True(c.IsFaceUp));
        Assert.All(vm.State.HeldSlots, h => Assert.False(h));
        var deck = Reflect.Get<List<Card>>(vm, "_deck");
        Assert.Equal(47, deck.Count);
        Assert.Equal(52, vm.State.Hand.Concat(deck).Select(c => (c.Suit, c.Rank)).Distinct().Count());

        Assert.Equal(97, vm.State.SessionCredits);
        Assert.Equal("$97", vm.ScoreDisplay);
        Assert.Equal("97", vm.CreditDisplay);
        Assert.Equal("3", vm.BetDisplay);
        Assert.Equal(3, vm.Stats.TotalCreditsWagered);
        Assert.Equal(1, vm.Stats.TotalHands);
        Assert.Equal("1", vm.HandsDisplay);
        Assert.NotEqual(Fresh().DealDrawLabel, vm.DealDrawLabel); // "Draw" mid-hand, "Deal" otherwise

        // The Deal/Draw button mid-hand draws; it never deals (and charges) a second hand.
        // Nothing is held, so the draw replaces all five cards — from an empty deck, so the
        // hand stays "nothing" (the dealt deck is shuffled, and a random draw can win).
        vm.State.Hand = Nothing();
        Reflect.Set(vm, "_deck", new List<Card>());
        vm.DealOrDraw();
        Assert.Equal(VideoPokerPhase.Result, vm.State.Phase);
        Assert.Equal(97, vm.State.SessionCredits);
        Assert.Equal(1, vm.Stats.TotalHands);
    }

    [Fact]
    public void Deal_IsRefusedWithoutEnoughCredits()
    {
        var vm = Fresh();
        for (int i = 0; i < 2; i++) vm.IncreaseBet(); // bet 3
        vm.State.SessionCredits = 2;

        Assert.False(vm.CanDeal);
        vm.DealOrDraw();

        Assert.Equal(VideoPokerPhase.Deal, vm.State.Phase);
        Assert.Equal(2, vm.State.SessionCredits);
        Assert.Equal(0, vm.Stats.TotalHands);
    }

    [Fact]
    public void HoldingAndDrawing_ReplacesOnlyUnheldCardsAndPaysTheTable()
    {
        var vm = Fresh();
        vm.IncreaseBet(); vm.IncreaseBet(); // 3 coins
        Dealt(vm, JacksPair(), new() { C(CardSuit.Clubs, 13), C(CardSuit.Hearts, 3), C(CardSuit.Diamonds, 8), C(CardSuit.Spades, 4) });

        vm.ToggleHold(0); vm.ToggleHold(1); vm.ToggleHold(4);
        vm.ToggleHold(4);   // tapping a held card releases it
        vm.ToggleHold(7);   // out of range: ignored
        vm.ToggleHold(-1);
        Assert.Equal(new[] { true, true, false, false, false }, vm.State.HeldSlots);

        vm.DealOrDraw();

        Assert.Equal(new[] { 11, 11, 13, 3, 8 }, vm.State.Hand.Select(c => c.Rank));
        Assert.Equal(VideoPokerPhase.Result, vm.State.Phase);
        Assert.Equal("Jacks or Better", vm.State.LastHandName);
        Assert.Equal("Jacks or Better", vm.WinningHandName);
        Assert.Equal(3, vm.State.LastPayout);
        Assert.Equal(100, vm.State.SessionCredits);   // 97 + 3
        Assert.True(vm.HasWin);
        Assert.False(vm.ShowNoWin);
        Assert.Contains("+3", vm.ResultText);
        Assert.Equal(new[] { true, true, false, false, false }, vm.State.WinningCardMask);
        Assert.Equal(1, vm.Stats.WinningHands);
        Assert.Equal(1, vm.Stats.CurrentStreak);
        Assert.Equal(3, vm.Stats.TotalCreditsWon);
        Assert.Equal(3, vm.Stats.BiggestPay);
        Assert.Equal(1, vm.Stats.HandCounts["Jacks or Better"]);

        // Holds are locked after the draw, and drawing twice pays nothing extra.
        vm.ToggleHold(2);
        vm.HoldAll();
        Assert.Equal(new[] { true, true, false, false, false }, vm.State.HeldSlots);
        vm.Draw();
        Assert.Equal(100, vm.State.SessionCredits);
    }

    [Fact]
    public void HoldAllAndClearHolds_OnlyWorkMidHand()
    {
        var vm = Fresh();
        vm.HoldAll();
        Assert.All(vm.State.HeldSlots, h => Assert.False(h));
        vm.Deal();
        vm.HoldAll();
        Assert.All(vm.State.HeldSlots, h => Assert.True(h));
        vm.ClearHolds();
        Assert.All(vm.State.HeldSlots, h => Assert.False(h));
        vm.HoldAll();
        vm.Draw();
        vm.ClearHolds();
        Assert.All(vm.State.HeldSlots, h => Assert.True(h)); // nothing changes after the draw
    }

    [Fact]
    public void Payouts_TwoPairAndRoyalFlushAtMaxBet()
    {
        var tp = Fresh();
        tp.IncreaseBet();
        Dealt(tp, new() { C(CardSuit.Hearts, 5), C(CardSuit.Spades, 5), C(CardSuit.Clubs, 9), C(CardSuit.Diamonds, 9), C(CardSuit.Clubs, 2) },
              new() { C(CardSuit.Hearts, 13) });
        for (int i = 0; i < 4; i++) tp.ToggleHold(i);
        tp.Draw();
        Assert.Equal("Two Pair", tp.State.LastHandName);
        Assert.Equal(4, tp.State.LastPayout);
        Assert.Equal(new[] { true, true, true, true, false }, tp.State.WinningCardMask);

        var royal = Fresh();
        royal.BetMax(); // 5 coins, deals straight away
        royal.State.Hand = RoyalHearts();
        HoldAllAndDraw(royal);
        Assert.Equal("Royal Flush", royal.State.LastHandName);
        Assert.Equal(4000, royal.State.LastPayout);
        Assert.Equal(95 + 4000, royal.State.SessionCredits);
        Assert.Equal(1, royal.Stats.RoyalFlushCount);
        Assert.Equal(4000, royal.Stats.BiggestPay);
        Assert.All(royal.State.WinningCardMask, m => Assert.True(m));

        var idle = Fresh();
        idle.Draw();
        Assert.Equal(VideoPokerPhase.Deal, idle.State.Phase);
    }

    [Fact]
    public void WinningCardsAreHighlighted()
    {
        bool[] MaskFor(List<Card> hand, VideoPokerVariant variant = VideoPokerVariant.JacksOrBetter)
        {
            var vm = Fresh();
            vm.SetVariant(variant);
            Dealt(vm, hand);
            HoldAllAndDraw(vm);
            Assert.True(vm.State.LastPayout > 0);
            return vm.State.WinningCardMask;
        }

        Assert.Equal(new[] { true, true, true, true, false },
            MaskFor(new() { C(CardSuit.Hearts, 7), C(CardSuit.Spades, 7), C(CardSuit.Clubs, 7), C(CardSuit.Diamonds, 7), C(CardSuit.Clubs, 9) }));
        Assert.Equal(new[] { false, true, true, true, false },
            MaskFor(new() { C(CardSuit.Hearts, 4), C(CardSuit.Spades, 7), C(CardSuit.Clubs, 7), C(CardSuit.Diamonds, 7), C(CardSuit.Clubs, 9) }));
        Assert.Equal(new[] { true, true, true, true, true },
            MaskFor(new() { C(CardSuit.Hearts, 4), C(CardSuit.Spades, 4), C(CardSuit.Clubs, 7), C(CardSuit.Diamonds, 7), C(CardSuit.Hearts, 7) }));
        Assert.Equal(new[] { true, true, true, true, true },
            MaskFor(new() { C(CardSuit.Hearts, 4), C(CardSuit.Spades, 5), C(CardSuit.Clubs, 6), C(CardSuit.Diamonds, 7), C(CardSuit.Hearts, 8) }));
        // Deuces Wild: with a wild card in the hand every card lights up.
        Assert.Equal(new[] { true, true, true, true, true },
            MaskFor(new() { C(CardSuit.Hearts, 2), C(CardSuit.Spades, 9), C(CardSuit.Clubs, 9), C(CardSuit.Diamonds, 4), C(CardSuit.Hearts, 6) },
                    VideoPokerVariant.DeucesWild));
    }

    [Fact]
    public void LosingHand_EndsTheStreakButKeepsTheBest()
    {
        var vm = Fresh();
        void Play(List<Card> hand) { Dealt(vm, hand); HoldAllAndDraw(vm); }

        Play(JacksPair());
        Play(new() { C(CardSuit.Hearts, 12), C(CardSuit.Spades, 12), C(CardSuit.Clubs, 2), C(CardSuit.Diamonds, 5), C(CardSuit.Clubs, 9) });
        Assert.Equal(2, vm.Stats.CurrentStreak);
        Assert.Equal(2, vm.Stats.LongestStreak);

        Play(new() { C(CardSuit.Hearts, 10), C(CardSuit.Spades, 10), C(CardSuit.Clubs, 2), C(CardSuit.Diamonds, 5), C(CardSuit.Clubs, 9) });
        Assert.Equal(0, vm.State.LastPayout);     // a pair of tens doesn't pay
        Assert.True(vm.ShowNoWin);
        Assert.False(vm.HasWin);
        Assert.Equal("", vm.ResultText);
        Assert.All(vm.State.WinningCardMask, m => Assert.False(m));
        Assert.Equal(0, vm.Stats.CurrentStreak);
        Assert.Equal(2, vm.Stats.LongestStreak);
        Assert.Equal(100 - 3 + 2, vm.State.SessionCredits);
        Assert.Equal(3, vm.Stats.TotalHands);
        Assert.Equal(2, vm.Stats.WinningHands);
    }

    [Fact]
    public void BetControls_StayBetweenOneAndFiveAndLockMidHand()
    {
        var vm = Fresh();
        vm.DecreaseBet();
        Assert.Equal(1, vm.State.CurrentBet);
        for (int i = 0; i < 7; i++) vm.IncreaseBet();
        Assert.Equal(5, vm.State.CurrentBet);
        vm.DecreaseBet();
        Assert.Equal(4, vm.State.CurrentBet);

        vm.BetMax();
        Assert.Equal(5, vm.State.CurrentBet);
        Assert.Equal(VideoPokerPhase.Holding, vm.State.Phase);
        Assert.Equal(95, vm.State.SessionCredits);
        vm.IncreaseBet(); vm.DecreaseBet(); vm.BetMax();
        Assert.Equal(5, vm.State.CurrentBet);
        Assert.Equal(95, vm.State.SessionCredits);

        // Max Bet is limited by the credits you have; with none it can't deal.
        var poor = Fresh();
        poor.State.SessionCredits = 3;
        poor.BetMax();
        Assert.Equal(3, poor.State.CurrentBet);
        Assert.Equal(0, poor.State.SessionCredits);

        var none = Fresh();
        none.State.SessionCredits = 0;
        none.BetMax();
        Assert.Equal(VideoPokerPhase.Deal, none.State.Phase);
    }

    [Fact]
    public void FreePlay_IsLockedInForTheWholeHand()
    {
        // Dealt free (No Stress on), then No Stress switched off: still free for that hand.
        var free = Fresh();
        free.Options.IsNoStressMode = true;
        free.State.SessionCredits = 0;
        Assert.True(free.CanDeal);
        Assert.False(free.NeedsRebuy);
        free.Deal();
        Assert.Equal(VideoPokerPhase.Holding, free.State.Phase);
        Assert.Equal(0, free.State.SessionCredits);
        Assert.Equal(0, free.Stats.TotalCreditsWagered);

        free.State.Hand = RoyalHearts();
        free.Options.IsNoStressMode = false;
        HoldAllAndDraw(free);
        Assert.Equal(0, free.State.SessionCredits);   // no credits for a free hand
        Assert.Equal(0, free.Stats.TotalCreditsWon);
        Assert.Equal(0, free.Stats.BiggestPay);
        Assert.Equal(1, free.Stats.WinningHands);     // but the win still counts
        Assert.Equal(1, free.Stats.RoyalFlushCount);

        // Dealt for credits, then No Stress switched on: that hand still pays.
        var paid = Fresh();
        paid.Deal();
        paid.State.Hand = JacksPair();
        paid.Options.IsNoStressMode = true;
        HoldAllAndDraw(paid);
        Assert.Equal(100, paid.State.SessionCredits);
        Assert.Equal(1, paid.Stats.TotalCreditsWon);
    }

    [Fact]
    public void Rebuy_OnlyWhenLowAndBetweenHands_AndNeverTwice()
    {
        var vm = Fresh();
        vm.State.SessionCredits = 50;
        Assert.False(vm.NeedsRebuy);
        vm.Rebuy();
        Assert.Equal(50, vm.State.SessionCredits);

        vm.State.SessionCredits = 10;
        Assert.True(vm.NeedsRebuy);
        vm.Rebuy();
        Assert.Equal(110, vm.State.SessionCredits);
        Assert.Equal(1, vm.Stats.Rebuys);
        vm.Rebuy();   // a double-click can't rebuy twice
        Assert.Equal(110, vm.State.SessionCredits);
        Assert.Equal(1, vm.Stats.Rebuys);

        vm.State.SessionCredits = 5;
        vm.Deal();
        vm.Rebuy();   // not mid-hand
        Assert.Equal(4, vm.State.SessionCredits);
        vm.State.Hand = Nothing();
        HoldAllAndDraw(vm);
        Assert.Equal(4, vm.State.SessionCredits);
        Assert.True(vm.NeedsRebuy);

        // Free play never offers a rebuy.
        vm.Options.IsNoStressMode = true;
        Assert.False(vm.NeedsRebuy);
        vm.Rebuy();
        Assert.Equal(4, vm.State.SessionCredits);
    }

    [Fact]
    public void Rebuy_PersistsTheRebuyCount()
    {
        var vm = Fresh();
        vm.State.SessionCredits = 3;
        vm.Rebuy();
        Assert.Equal(1, new VideoPokerViewModel().Stats.Rebuys);
    }

    [Fact]
    public void OutOfCreditsToast_OnlyAfterALosingHandAtTenOrFewerCredits()
    {
        var vm = Fresh();
        vm.State.SessionCredits = 5;
        Dealt(vm, Nothing());
        HoldAllAndDraw(vm);
        Drain(vm);

        string? shown = null;
        vm.OnFlashBanner += t => shown = t;
        vm.CheckOutOfCredits();
        Assert.Equal(1, Drain(vm));
        Assert.False(string.IsNullOrEmpty(shown));

        vm.State.SessionCredits = 11;
        vm.CheckOutOfCredits();
        Assert.Equal(0, Drain(vm));

        vm.State.SessionCredits = 4;
        vm.State.LastPayout = 5;   // a winning hand that still leaves you low
        vm.CheckOutOfCredits();
        Assert.Equal(0, Drain(vm));

        vm.State.LastPayout = 0;
        vm.Options.IsNoStressMode = true;
        vm.CheckOutOfCredits();
        Assert.Equal(0, Drain(vm));
    }

    [Fact]
    public void NewGame_ResetsTheSession_AndAbandoningADealtHandBreaksTheStreak()
    {
        var vm = Fresh();
        vm.Options.StartingCredits = 250;
        vm.Options.BetPerHand = 2;
        vm.StartNewGame();
        Assert.Equal(250, vm.State.SessionCredits);
        Assert.Equal(2, vm.State.CurrentBet);
        Assert.Equal(VideoPokerPhase.Deal, vm.State.Phase);

        vm.Stats.CurrentStreak = 4;
        vm.Stats.LongestStreak = 4;
        vm.StartNewGame();
        Assert.Equal(4, vm.Stats.CurrentStreak);   // between hands: kept

        vm.Deal();
        Assert.Equal("1", vm.HandsDisplay);
        vm.StartNewGame();
        Assert.Equal(0, vm.Stats.CurrentStreak);   // dealt but not drawn: broken
        Assert.Equal(4, vm.Stats.LongestStreak);
        Assert.Equal("0", vm.HandsDisplay);
        Assert.False(vm.CanUndo);
    }

    [Fact]
    public void ResetIfRoundOver_ClearsAFinishedHandButKeepsCredits()
    {
        var vm = Fresh();
        Dealt(vm, JacksPair());
        HoldAllAndDraw(vm);
        Assert.Equal(VideoPokerPhase.Result, vm.State.Phase);

        vm.ResetIfRoundOver();
        Assert.Equal(VideoPokerPhase.Deal, vm.State.Phase);
        Assert.Empty(vm.State.Hand);
        Assert.Equal(0, vm.State.LastPayout);
        Assert.Equal("", vm.State.LastHandName);
        Assert.Equal("", vm.WinningHandName);
        Assert.Equal(100, vm.State.SessionCredits);

        vm.Deal();
        vm.ResetIfRoundOver();   // mid-hand: nothing to clear
        Assert.Equal(VideoPokerPhase.Holding, vm.State.Phase);
    }

    [Fact]
    public void SwitchingVariant_ClearsTheHandButNotTheCredits()
    {
        var vm = Fresh();
        Dealt(vm, JacksPair());
        HoldAllAndDraw(vm);

        vm.SetVariant(VideoPokerVariant.DeucesWild);
        Assert.Equal(VideoPokerPhase.Deal, vm.State.Phase);
        Assert.Empty(vm.State.Hand);
        Assert.Equal(100, vm.State.SessionCredits);
        Assert.Equal("DEUCES WILD", vm.VariantName);
        Assert.Equal(10, vm.CurrentTable.Length);
        Assert.Equal(VideoPokerVariant.DeucesWild, new VideoPokerViewModel().Options.Variant);

        vm.SetVariant(VideoPokerVariant.BonusPoker);
        Assert.Equal("BONUS POKER", vm.VariantName);
        Assert.Equal(11, vm.CurrentTable.Length);
        vm.SetVariant(VideoPokerVariant.JacksOrBetter);
        Assert.Equal("JACKS OR BETTER", vm.VariantName);
        Assert.Equal(9, vm.CurrentTable.Length);
    }

    [Fact]
    public void Banners_FirstHandWelcome_LoadingOnce_TenthWinMilestoneOnce()
    {
        var vm = Fresh();
        Assert.Equal(0, Queued(vm));
        vm.Deal();
        Assert.Equal(1, Drain(vm));   // the very first hand shows the welcome banner
        vm.State.Hand = Nothing();
        HoldAllAndDraw(vm);
        vm.Deal();
        Assert.Equal(0, Drain(vm));   // only once

        vm.CheckLoadingBanner();
        Drain(vm);
        vm.CheckLoadingBanner();
        Assert.Equal(0, Drain(vm));   // loading banner once per session

        // The 10th winning hand shows the milestone, exactly once.
        vm.Stats.WinningHands = 9;
        vm.State.Hand = JacksPair();
        HoldAllAndDraw(vm);
        Assert.Equal(1, Queued(vm));

        var replayed = new List<string>();
        vm.OnFlashBanner += replayed.Add;
        vm.ReplayCurrentBanner();
        Assert.Single(replayed);      // re-announced when the board comes back
        Assert.Equal(1, Drain(vm));
        vm.ReplayCurrentBanner();
        vm.AdvanceBannerQueue();      // empty queue: harmless
        Assert.Single(replayed);

        Dealt(vm, JacksPair());
        HoldAllAndDraw(vm);
        Assert.Equal(0, Drain(vm));   // 11th win doesn't repeat it

        vm.ScheduleIdleActionCheck();
        vm.CancelIdleActionCheck();
    }

    [Fact]
    public void OptionsAndStats_SurviveARelaunch()
    {
        var vm = Fresh();
        vm.Options.Variant = VideoPokerVariant.BonusPoker;
        vm.Options.StartingCredits = 500;
        vm.Options.BetPerHand = 4;
        vm.SaveOptions();
        Dealt(vm, JacksPair());
        HoldAllAndDraw(vm);   // a finished hand saves the stats

        var again = new VideoPokerViewModel();
        Assert.Equal(VideoPokerVariant.BonusPoker, again.Options.Variant);
        Assert.Equal(500, again.State.SessionCredits);   // a new session starts from the chosen credits
        Assert.Equal(4, again.State.CurrentBet);
        Assert.Equal(1, again.Stats.WinningHands);
        Assert.Equal(1, again.Stats.TotalHands);

        again.ResetStats();
        Assert.Equal(0, again.Stats.WinningHands);
        Assert.Equal(0, new VideoPokerViewModel().Stats.WinningHands);
    }

    [Fact]
    public void OldOrBrokenSaves_FallBackToDefaults()
    {
        Write("videopoker_options.json", "{\"Variant\":1}");
        Write("videopoker_stats.json", "{\"WinningHands\":3}");
        var old = new VideoPokerViewModel();
        Assert.Equal(VideoPokerVariant.DeucesWild, old.Options.Variant);
        Assert.Equal(100, old.Options.StartingCredits);
        Assert.Equal(1, old.Options.BetPerHand);
        Assert.Equal(3, old.Stats.WinningHands);
        Assert.Equal(0, old.Stats.LongestStreak);
        Assert.NotNull(old.Stats.HandCounts);

        Write("videopoker_options.json", "{\"BetPerHand\":9}");
        Assert.Equal(5, new VideoPokerViewModel().State.CurrentBet);   // an out-of-range bet is clamped

        Write("videopoker_options.json", "not json");
        Write("videopoker_stats.json", "{");
        var broken = new VideoPokerViewModel();
        Assert.Equal(VideoPokerVariant.JacksOrBetter, broken.Options.Variant);
        Assert.Equal(100, broken.State.SessionCredits);
        Assert.Equal(0, broken.Stats.TotalHands);
    }

    [Fact]
    public void PayTables_PerVariant()
    {
        Assert.Equal(9, VideoPokerViewModel.TableFor(VideoPokerVariant.JacksOrBetter).Length);
        Assert.Equal("Royal Flush", VideoPokerViewModel.TableFor(VideoPokerVariant.JacksOrBetter)[0].HandName);
        Assert.Equal(10, VideoPokerViewModel.TableFor(VideoPokerVariant.DeucesWild).Length);
        Assert.Equal(11, VideoPokerViewModel.TableFor(VideoPokerVariant.BonusPoker).Length);

        var fourAces = new[] { C(CardSuit.Hearts, 1), C(CardSuit.Spades, 1), C(CardSuit.Clubs, 1), C(CardSuit.Diamonds, 1), C(CardSuit.Clubs, 9) };
        var bonus = VideoPokerViewModel.ScoreHand(fourAces, VideoPokerVariant.BonusPoker, 2);
        Assert.Equal("Four Aces", bonus.Entry!.HandName);
        Assert.Equal(160, bonus.Payout);

        var fourDeuces = new[] { C(CardSuit.Hearts, 2), C(CardSuit.Spades, 2), C(CardSuit.Clubs, 2), C(CardSuit.Diamonds, 2), C(CardSuit.Clubs, 9) };
        var deuces = VideoPokerViewModel.ScoreHand(fourDeuces, VideoPokerVariant.DeucesWild, 1);
        Assert.Equal("Four Deuces", deuces.Entry!.HandName);
        Assert.Equal(200, deuces.Payout);

        // Bets outside 1–5 pay nothing.
        Assert.Equal(0, VideoPokerViewModel.TableFor(VideoPokerVariant.JacksOrBetter)[0].Payout(6));
    }

    [Fact]
    public void Watermark_FollowsHideBee()
    {
        var vm = Fresh();
        vm.Options.HideBee = false;
        Assert.Equal(0.15, vm.WatermarkOpacity);
        vm.Options.HideBee = true;
        Assert.True(vm.HideBee);
        Assert.Equal(0.0, vm.WatermarkOpacity);
        Assert.Equal(vm.Options.VideoPokerWatermarkScale, vm.VideoPokerWatermarkScale);
        Assert.Equal(vm.Options.VideoPokerWatermarkOffsetX, vm.VideoPokerWatermarkOffsetX);
        Assert.Equal(vm.Options.VideoPokerWatermarkOffsetY, vm.VideoPokerWatermarkOffsetY);
    }
}
