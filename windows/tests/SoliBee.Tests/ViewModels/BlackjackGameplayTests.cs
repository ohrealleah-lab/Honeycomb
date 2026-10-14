using System.Collections.Generic;
using System.Linq;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;
using static SoliBee.Tests.Cards;

namespace SoliBee.Tests.ViewModels;

// Desktop Blackjack round flow on fixed hands and shoes (ported from Mac's
// BlackjackGameplayTests): payouts, the dealer's rules, double, split, split aces,
// free play (No Stress), bets, rebuy and the out-of-credits toast, banners and what
// survives a relaunch.
public class BlackjackGameplayTests : DataSandbox
{
    // A fresh install: no saved Blackjack options or stats.
    private static BlackjackViewModel Fresh()
    {
        Delete("blackjack_options.json");
        Delete("blackjack_stats.json");
        return new BlackjackViewModel();
    }

    // A round already in progress, as just after Deal(): the bet is already off the
    // credits. `shoe` is dealt from the front.
    private static void Round(BlackjackViewModel vm, List<List<Card>> player, List<Card> dealer,
                              List<Card>? shoe = null, int bet = 10, int credits = 90)
    {
        vm.State.Phase = BlackjackPhase.Playing;
        vm.State.Credits = credits;
        vm.State.CurrentBet = bet;
        vm.State.IsSplit = false;
        vm.State.ActiveHandIndex = 0;
        vm.State.PlayerHands = player.Select(cards => new BlackjackHand { Cards = cards, Bet = bet }).ToList();
        vm.State.DealerHand = new BlackjackHand { Cards = dealer };
        Reflect.Set(vm, "_deck", shoe ?? new List<Card>());
        Reflect.Set(vm, "_deckIdx", 0);
        Reflect.Set(vm, "_handFreePlay", false);
        Reflect.Set(vm, "_creditsBeforeDeal", credits + bet);
    }

    private static List<Card> L(params Card[] cards) => cards.ToList();
    private static List<List<Card>> Hand(params Card[] cards) => new() { cards.ToList() };
    private static Card Hole(CardSuit suit, int rank) => C(suit, rank, up: false);

    private static int Queued(BlackjackViewModel vm) => Reflect.Get<Queue<string>>(vm, "_bannerQueue").Count;

    private static int Drain(BlackjackViewModel vm)
    {
        int n = Queued(vm);
        for (int i = 0; i < n; i++) vm.AdvanceBannerQueue();
        return n;
    }

    // 20 against the dealer's 18: a plain win.
    private static void WinningRound(BlackjackViewModel vm, int bet = 10, int credits = 90) =>
        Round(vm, Hand(C(CardSuit.Hearts, 10), C(CardSuit.Spades, 10)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 8)), bet: bet, credits: credits);

    // 18 against the dealer's 20: a loss.
    private static void LosingRound(BlackjackViewModel vm, int bet = 10, int credits = 90) =>
        Round(vm, Hand(C(CardSuit.Hearts, 10), C(CardSuit.Spades, 8)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 10)), bet: bet, credits: credits);

    [Fact]
    public void Deal_StartsARoundAndChargesTheBet()
    {
        var vm = Fresh();
        Assert.Equal(100, vm.State.Credits);
        Assert.Equal(1, vm.State.CurrentBet);
        Assert.Equal(BlackjackPhase.Betting, vm.State.Phase);
        Assert.True(vm.CanDeal && vm.CanChangeBet && !vm.IsPlaying);
        Assert.Null(vm.ActiveHand);

        vm.Deal();

        Assert.Single(vm.State.PlayerHands);
        Assert.Equal(2, vm.State.PlayerHands[0].Cards.Count);
        Assert.Equal(2, vm.State.DealerHand.Cards.Count);
        Assert.Equal(4, Reflect.Get<int>(vm, "_deckIdx"));   // 48 cards left in the shoe
        Assert.Equal(1, vm.Stats.HandsPlayed);
        Assert.Equal(1, vm.Stats.TotalCreditsWagered);
        Assert.Equal("1", vm.HandsDisplay);
        if (vm.State.Phase == BlackjackPhase.Playing)   // (a dealt natural settles at once)
        {
            Assert.Equal(99, vm.State.Credits);
            Assert.True(vm.State.DealerHand.Cards[0].IsFaceUp);
            Assert.False(vm.State.DealerHand.Cards[1].IsFaceUp);   // the hole card
            Assert.False(vm.CanDeal);                              // no second deal mid-round
            Assert.False(vm.CanChangeBet);
            Assert.Same(vm.State.PlayerHands[0], vm.ActiveHand);
        }
    }

    [Fact]
    public void Deal_IsRefusedWithoutEnoughCredits()
    {
        var vm = Fresh();
        vm.State.Credits = 5;
        vm.State.CurrentBet = 10;
        vm.Deal();
        Assert.Equal(BlackjackPhase.Betting, vm.State.Phase);
        Assert.Equal(5, vm.State.Credits);
        Assert.Equal(0, vm.Stats.HandsPlayed);
    }

    [Fact]
    public void Payouts_WinLossPushAndBust()
    {
        var vm = Fresh();
        WinningRound(vm);
        vm.Stand();
        Assert.Equal(BlackjackPhase.Result, vm.State.Phase);
        Assert.Equal(BlackjackHandResult.Won, vm.State.PlayerHands[0].Result);
        Assert.Equal(110, vm.State.Credits);
        Assert.Equal(10, vm.State.LastNetResult);
        Assert.Equal(1, vm.Stats.HandsWon);
        Assert.Equal(1, vm.ConsecutiveWins);
        Assert.Equal(20, vm.Stats.TotalCreditsWon);
        Assert.Equal(20, vm.Stats.BiggestPay);
        Assert.All(vm.State.DealerHand.Cards, c => Assert.True(c.IsFaceUp));

        vm = Fresh();
        vm.Stats.CurrentStreak = 3;
        vm.Stats.LongestStreak = 3;
        LosingRound(vm);
        vm.Stand();
        Assert.Equal(BlackjackHandResult.Lost, vm.State.PlayerHands[0].Result);
        Assert.Equal(90, vm.State.Credits);
        Assert.Equal(-10, vm.State.LastNetResult);
        Assert.Equal(1, vm.Stats.HandsLost);
        Assert.Equal(0, vm.Stats.CurrentStreak);
        Assert.Equal(3, vm.Stats.LongestStreak);

        vm = Fresh();
        vm.Stats.CurrentStreak = 3;
        Round(vm, Hand(C(CardSuit.Hearts, 10), C(CardSuit.Spades, 8)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 8)));
        vm.Stand();
        Assert.Equal(BlackjackHandResult.Push, vm.State.PlayerHands[0].Result);
        Assert.Equal(100, vm.State.Credits);
        Assert.Equal(0, vm.State.LastNetResult);
        Assert.Equal(1, vm.Stats.HandsPushed);
        Assert.Equal(3, vm.Stats.CurrentStreak);   // a push leaves the streak alone
        Assert.Equal(0, vm.Stats.BiggestPay);      // and isn't a "biggest payout"

        // Bust: the round ends without the dealer drawing.
        vm = Fresh();
        Round(vm, Hand(C(CardSuit.Hearts, 10), C(CardSuit.Spades, 6)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 5)),
              L(C(CardSuit.Diamonds, 13), C(CardSuit.Hearts, 9)));
        vm.Hit();
        Assert.Equal(BlackjackPhase.Result, vm.State.Phase);
        Assert.Equal(BlackjackHandResult.Lost, vm.State.PlayerHands[0].Result);
        Assert.Equal(2, vm.State.DealerHand.Cards.Count);
        Assert.All(vm.State.DealerHand.Cards, c => Assert.True(c.IsFaceUp));
        Assert.Equal(90, vm.State.Credits);
        Assert.Equal(1, vm.Stats.HandsLost);

        // A small total still wins when the dealer busts.
        vm = Fresh();
        Round(vm, Hand(C(CardSuit.Hearts, 10), C(CardSuit.Spades, 2)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 6)), L(C(CardSuit.Hearts, 13)));
        vm.Stand();
        Assert.Equal(3, vm.State.DealerHand.Cards.Count);
        Assert.Equal(BlackjackHandResult.Won, vm.State.PlayerHands[0].Result);
        Assert.Equal(110, vm.State.Credits);
    }

    [Fact]
    public void Dealer_DrawsTo17_AndStandsOnSoft17()
    {
        var vm = Fresh();
        Round(vm, Hand(C(CardSuit.Hearts, 10), C(CardSuit.Spades, 9)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 6)), L(C(CardSuit.Hearts, 2)));
        vm.Stand();
        Assert.Equal(3, vm.State.DealerHand.Cards.Count);
        Assert.Equal(18, vm.State.DealerHand.ComputeValue().Value);
        Assert.Equal(BlackjackHandResult.Won, vm.State.PlayerHands[0].Result);

        vm = Fresh();
        Round(vm, Hand(C(CardSuit.Hearts, 10), C(CardSuit.Spades, 8)), L(C(CardSuit.Clubs, 1), Hole(CardSuit.Diamonds, 6)), L(C(CardSuit.Hearts, 9)));
        vm.Stand();
        Assert.Equal(2, vm.State.DealerHand.Cards.Count);   // soft 17: stands
        Assert.Equal(BlackjackHandResult.Won, vm.State.PlayerHands[0].Result);
    }

    [Fact]
    public void HitAndStand_AutoStandOn21_AndDoNothingOutsideARound()
    {
        var vm = Fresh();
        vm.Hit();
        vm.Stand();
        Assert.Equal(BlackjackPhase.Betting, vm.State.Phase);
        Assert.False(vm.CanHit || vm.CanStand || vm.CanDouble || vm.CanSplit);

        Round(vm, Hand(C(CardSuit.Hearts, 5), C(CardSuit.Spades, 6)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 7)), L(C(CardSuit.Diamonds, 10)));
        vm.Hit();
        Assert.Equal(BlackjackPhase.Result, vm.State.Phase);   // 21 stands by itself
        Assert.Equal(21, vm.State.PlayerHands[0].ComputeValue().Value);
        Assert.Equal(BlackjackHandResult.Won, vm.State.PlayerHands[0].Result);

        var more = Fresh();
        Round(more, Hand(C(CardSuit.Hearts, 2), C(CardSuit.Spades, 3)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 7)),
              L(C(CardSuit.Clubs, 4), C(CardSuit.Diamonds, 9)));
        Assert.True(more.CanHit && more.CanStand);
        more.Hit();
        Assert.Equal(BlackjackPhase.Playing, more.State.Phase);
        Assert.Equal(9, more.State.PlayerHands[0].ComputeValue().Value);
        more.Hit();
        Assert.Equal(18, more.State.PlayerHands[0].ComputeValue().Value);
        more.Stand();
        Assert.Equal(BlackjackHandResult.Won, more.State.PlayerHands[0].Result);
    }

    [Fact]
    public void DoubleDown_DoublesTheBet_TakesOneCard_AndPlaysOutTheDealer()
    {
        var vm = Fresh();
        Round(vm, Hand(C(CardSuit.Hearts, 5), C(CardSuit.Spades, 6)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 8)), L(C(CardSuit.Diamonds, 9)));
        Assert.True(vm.CanDouble);
        vm.DoubleDown();
        var hand = vm.State.PlayerHands[0];
        Assert.True(hand.IsDoubled);
        Assert.Equal(20, hand.Bet);
        Assert.Equal(3, hand.Cards.Count);
        Assert.Equal(BlackjackPhase.Result, vm.State.Phase);
        Assert.Equal(80 + 40, vm.State.Credits);
        Assert.Equal(20, vm.State.LastNetResult);
        Assert.Equal(10, vm.Stats.TotalCreditsWagered);   // the extra stake

        bool Can(List<Card> cards, int credits = 90)
        {
            var v = Fresh();
            Round(v, new() { cards }, L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 8)), credits: credits);
            return v.CanDouble;
        }
        Assert.True(Can(L(C(CardSuit.Hearts, 4), C(CardSuit.Spades, 5))));     // 9
        Assert.True(Can(L(C(CardSuit.Hearts, 4), C(CardSuit.Spades, 6))));     // 10
        Assert.False(Can(L(C(CardSuit.Hearts, 4), C(CardSuit.Spades, 3))));    // 7
        Assert.False(Can(L(C(CardSuit.Hearts, 10), C(CardSuit.Spades, 2))));   // 12
        Assert.False(Can(L(C(CardSuit.Hearts, 2), C(CardSuit.Spades, 3), C(CardSuit.Clubs, 4))));   // three cards
        Assert.False(Can(L(C(CardSuit.Hearts, 5), C(CardSuit.Spades, 6)), credits: 5));             // can't cover it

        var idle = Fresh();
        idle.DoubleDown();
        Assert.Equal(BlackjackPhase.Betting, idle.State.Phase);
        Assert.Empty(idle.State.PlayerHands[0].Cards);
    }

    [Fact]
    public void Split_CostsASecondBet_DealsEachHandOneCard_AndOnlyOnce()
    {
        var vm = Fresh();
        Round(vm, Hand(C(CardSuit.Hearts, 8), C(CardSuit.Spades, 8)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 7)),
              L(C(CardSuit.Clubs, 9), C(CardSuit.Diamonds, 3)));
        Assert.True(vm.CanSplit);
        vm.Split();

        Assert.Equal(2, vm.State.PlayerHands.Count);
        Assert.Equal(80, vm.State.Credits);
        Assert.Equal(10, vm.Stats.TotalCreditsWagered);
        Assert.Equal(1, vm.Stats.HandsPlayed);   // the second hand counts as a hand played
        Assert.Equal(new[] { 8, 9 }, vm.State.PlayerHands[0].Cards.Select(c => c.Rank));
        Assert.Equal(new[] { 8, 3 }, vm.State.PlayerHands[1].Cards.Select(c => c.Rank));
        Assert.Equal(0, vm.State.ActiveHandIndex);
        Assert.False(vm.CanSplit);
        vm.Split();
        Assert.Equal(2, vm.State.PlayerHands.Count);
        Assert.Equal(80, vm.State.Credits);

        vm.Stand();
        Assert.Equal(1, vm.State.ActiveHandIndex);
        Assert.Equal(BlackjackPhase.Playing, vm.State.Phase);
        vm.Stand();
        Assert.Equal(BlackjackPhase.Result, vm.State.Phase);
        Assert.Equal(BlackjackHandResult.Push, vm.State.PlayerHands[0].Result);   // 17 v 17
        Assert.Equal(BlackjackHandResult.Lost, vm.State.PlayerHands[1].Result);   // 11 v 17
        Assert.Equal(90, vm.State.Credits);
        Assert.Equal(-10, vm.State.LastNetResult);
        Assert.Equal(1, vm.Stats.HandsPushed);
        Assert.Equal(1, vm.Stats.HandsLost);
        Assert.Equal(0, vm.Stats.CurrentStreak);
    }

    [Fact]
    public void Split_NeedsAPairOfTheSameRankAndEnoughCredits()
    {
        var ten = Fresh();
        Round(ten, Hand(C(CardSuit.Hearts, 10), C(CardSuit.Spades, 13)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 7)));
        Assert.False(ten.CanSplit);   // 10 and K are not a pair

        var poor = Fresh();
        Round(poor, Hand(C(CardSuit.Hearts, 8), C(CardSuit.Spades, 8)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 7)), credits: 5);
        Assert.False(poor.CanSplit);
        poor.Split();
        Assert.Single(poor.State.PlayerHands);
        Assert.Equal(5, poor.State.Credits);
    }

    [Fact]
    public void Split_AHandDealtTo21IsSkipped_AndA21AfterASplitIsAPlainWin()
    {
        var vm = Fresh();
        Round(vm, Hand(C(CardSuit.Hearts, 10), C(CardSuit.Spades, 10)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 7)),
              L(C(CardSuit.Diamonds, 1), C(CardSuit.Clubs, 8)));
        vm.Split();   // hand 1 = 10 + A = 21, hand 2 = 10 + 8 = 18
        Assert.Equal(1, vm.State.ActiveHandIndex);
        Assert.Equal(BlackjackPhase.Playing, vm.State.Phase);
        vm.Stand();
        Assert.Equal(BlackjackPhase.Result, vm.State.Phase);
        Assert.All(vm.State.PlayerHands, h => Assert.Equal(BlackjackHandResult.Won, h.Result));
        Assert.Equal(0, vm.Stats.Blackjacks);       // a split 21 is not a blackjack
        Assert.Equal(80 + 20 + 20, vm.State.Credits); // both paid 1:1
    }

    [Fact]
    public void SplitAces_GetOneCardEach_AndPayOneToOne()
    {
        var vm = Fresh();
        Round(vm, Hand(C(CardSuit.Hearts, 1), C(CardSuit.Spades, 1)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 8)),
              L(C(CardSuit.Clubs, 5), C(CardSuit.Diamonds, 13)));
        vm.Split();

        Assert.Equal(2, vm.State.PlayerHands.Count);
        Assert.All(vm.State.PlayerHands, h => Assert.Equal(2, h.Cards.Count));
        Assert.Equal(BlackjackPhase.Result, vm.State.Phase);   // resolves with no further action
        Assert.Equal(16, vm.State.PlayerHands[0].ComputeValue().Value);
        Assert.Equal(BlackjackHandResult.Lost, vm.State.PlayerHands[0].Result);
        Assert.Equal(21, vm.State.PlayerHands[1].ComputeValue().Value);
        Assert.Equal(BlackjackHandResult.Won, vm.State.PlayerHands[1].Result);
        Assert.Equal(80 + 20, vm.State.Credits);
        Assert.Equal(0, vm.Stats.Blackjacks);
    }

    [Fact]
    public void FreePlay_IsLockedInForTheWholeHand()
    {
        var vm = Fresh();
        vm.Options.IsNoStressMode = true;
        Assert.False(vm.CanRebuy);
        vm.State.Credits = 0;
        vm.State.CurrentBet = 10;
        vm.Deal();
        Assert.Equal(0, vm.State.Credits);
        Assert.Equal(0, vm.Stats.TotalCreditsWagered);
        int wonBefore = vm.Stats.HandsWon;   // (the random deal may have been a natural)

        // No Stress switched off mid-hand: the hand stays free.
        vm.Options.IsNoStressMode = false;
        vm.State.Phase = BlackjackPhase.Playing;
        vm.State.PlayerHands = new() { new BlackjackHand { Cards = L(C(CardSuit.Hearts, 10), C(CardSuit.Spades, 10)), Bet = 10 } };
        vm.State.DealerHand = new BlackjackHand { Cards = L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 8)) };
        vm.State.ActiveHandIndex = 0;
        vm.Stand();
        Assert.Equal(BlackjackHandResult.Won, vm.State.PlayerHands[0].Result);
        Assert.Equal(0, vm.State.Credits);
        Assert.Equal(0, vm.Stats.TotalCreditsWon);
        Assert.Equal(wonBefore + 1, vm.Stats.HandsWon);   // still counts

        // After the hand the live setting applies: paid play, and at 0 credits a rebuy.
        Assert.True(vm.CanRebuy);
        vm.Options.IsNoStressMode = true;
        Assert.False(vm.CanRebuy);
    }

    [Fact]
    public void BetControls_DoubleClearAndLockDuringARound()
    {
        var vm = Fresh();
        vm.DoubleBet();
        Assert.Equal(2, vm.State.CurrentBet);
        vm.DoubleBet(); vm.DoubleBet();
        Assert.Equal(8, vm.State.CurrentBet);
        vm.State.Credits = 5;
        vm.DoubleBet();
        Assert.Equal(5, vm.State.CurrentBet);   // never past your credits
        vm.ClearBet();
        Assert.Equal(1, vm.State.CurrentBet);
        Assert.Equal("1", vm.BetDisplay);
        Assert.Equal("5", vm.CreditDisplay);

        vm.State.Phase = BlackjackPhase.Playing;
        vm.DoubleBet(); vm.AddToBet(5); vm.ClearBet();
        Assert.Equal(1, vm.State.CurrentBet);
    }

    // After a round the bet stays if it's still affordable, otherwise it falls back to 1
    // so the next Deal isn't silently refused (Mac parity). Free play never resets it.
    [Fact]
    public void Bet_FallsBackToOneWhenItCanNoLongerBeAfforded()
    {
        var vm = Fresh();
        LosingRound(vm, bet: 50, credits: 8);
        vm.Stand();
        Assert.Equal(8, vm.State.Credits);
        Assert.Equal(1, vm.State.CurrentBet);
        Assert.Equal(1, vm.Options.BetPerHand);

        var kept = Fresh();
        WinningRound(kept, bet: 10, credits: 90);
        kept.Stand();
        Assert.Equal(10, kept.State.CurrentBet);   // still affordable: kept

        var free = Fresh();
        LosingRound(free, bet: 50, credits: 8);
        Reflect.Set(free, "_handFreePlay", true);
        free.Stand();
        Assert.Equal(50, free.State.CurrentBet);
    }

    [Fact]
    public void OutOfCreditsToast_AfterALostRoundAtTenOrFewer_AndRebuyOnce()
    {
        var vm = Fresh();
        LosingRound(vm, bet: 2, credits: 8);
        vm.Stand();
        Drain(vm);
        vm.CheckOutOfCredits();
        Assert.Equal(1, Drain(vm));
        Assert.True(vm.CanRebuy);

        vm.Rebuy();
        Assert.Equal(108, vm.State.Credits);
        Assert.Equal(1, vm.Stats.Rebuys);
        vm.Rebuy();
        Assert.Equal(1, vm.Stats.Rebuys);   // no double rebuy
        Assert.Equal(1, new BlackjackViewModel().Stats.Rebuys);   // saved
        vm.CheckOutOfCredits();
        Assert.Equal(0, Drain(vm));

        var won = Fresh();
        WinningRound(won, credits: 0);
        won.Stand();
        won.State.Credits = 5;
        Drain(won);
        won.CheckOutOfCredits();
        Assert.Equal(0, Drain(won));   // a winning round never shows it

        var split = Fresh();
        Round(split, Hand(C(CardSuit.Hearts, 8), C(CardSuit.Spades, 8)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 7)),
              L(C(CardSuit.Diamonds, 10), C(CardSuit.Clubs, 2)), bet: 4, credits: 6);
        split.Split();   // 8+10 = 18 and 8+2 = 10
        split.Stand(); split.Stand();
        Assert.Equal(BlackjackHandResult.Won, split.State.PlayerHands[0].Result);
        Assert.Equal(BlackjackHandResult.Lost, split.State.PlayerHands[1].Result);
        split.State.Credits = 3;
        Drain(split);
        split.CheckOutOfCredits();
        Assert.Equal(0, Drain(split));   // a round with a win in it isn't "running out"

        var free = Fresh();
        LosingRound(free, credits: 3);
        free.Stand();
        free.Options.IsNoStressMode = true;
        Drain(free);
        free.CheckOutOfCredits();
        Assert.Equal(0, Drain(free));
        free.Rebuy();
        Assert.Equal(0, free.Stats.Rebuys);
    }

    [Fact]
    public void ResetIfRoundOver_ClearsAFinishedRoundButKeepsCredits()
    {
        var vm = Fresh();
        WinningRound(vm);
        vm.Stand();
        Assert.Equal(BlackjackPhase.Result, vm.State.Phase);
        vm.ResetIfRoundOver();
        Assert.Equal(BlackjackPhase.Betting, vm.State.Phase);
        Assert.Empty(vm.State.DealerHand.Cards);
        Assert.All(vm.State.PlayerHands, h => Assert.Empty(h.Cards));
        Assert.Equal(0, vm.State.LastNetResult);
        Assert.Equal(110, vm.State.Credits);
        Assert.False(vm.CanUndo);

        Round(vm, Hand(C(CardSuit.Hearts, 2), C(CardSuit.Spades, 3)), L(C(CardSuit.Clubs, 10), Hole(CardSuit.Diamonds, 7)));
        vm.ResetIfRoundOver();   // mid-round: untouched
        Assert.Equal(BlackjackPhase.Playing, vm.State.Phase);
    }

    [Fact]
    public void NewGame_ResetsTheTableAndTheStreak()
    {
        var vm = Fresh();
        vm.Options.StartingCredits = 300;
        vm.Stats.CurrentStreak = 5;
        vm.StartNewGame();
        Assert.Equal(300, vm.State.Credits);
        Assert.Equal(BlackjackPhase.Betting, vm.State.Phase);
        Assert.Equal(0, vm.Stats.CurrentStreak);
        Assert.Equal("0", vm.HandsDisplay);
    }

    [Fact]
    public void Banners_FirstHandWelcome_LoadingOnce_TenthWonHandOnce()
    {
        var vm = Fresh();
        Assert.Equal(0, Queued(vm));
        vm.Deal();
        Assert.Equal(1, Drain(vm));
        vm.CheckLoadingBanner();
        Drain(vm);
        vm.CheckLoadingBanner();
        Assert.Equal(0, Drain(vm));

        vm.Stats.HandsWon = 9;
        WinningRound(vm);
        vm.Stand();
        Assert.Equal(1, Queued(vm));
        var replayed = new List<string>();
        vm.OnFlashBanner += replayed.Add;
        vm.ReplayCurrentBanner();
        Assert.Single(replayed);
        Assert.Equal(1, Drain(vm));

        WinningRound(vm);
        vm.Stand();
        Assert.Equal(0, Drain(vm));
        vm.ScheduleIdleActionCheck();
        vm.CancelIdleActionCheck();
    }

    [Fact]
    public void OptionsAndStats_SurviveARelaunch_AndOldSavesDecode()
    {
        var vm = Fresh();
        vm.Options.StartingCredits = 750;
        vm.SaveOptions();
        WinningRound(vm);
        vm.Stand();   // a finished round saves the stats

        var again = new BlackjackViewModel();
        Assert.Equal(750, again.State.Credits);
        Assert.Equal(1, again.Stats.HandsWon);
        Assert.Equal(0, again.Stats.Blackjacks);
        again.ResetStats();
        Assert.Equal(0, new BlackjackViewModel().Stats.HandsWon);

        Write("blackjack_options.json", "{}");
        Write("blackjack_stats.json", "{\"HandsWon\":2}");
        var old = new BlackjackViewModel();
        Assert.Equal(100, old.Options.StartingCredits);
        Assert.Equal(100, old.State.Credits);
        Assert.Equal(2, old.Stats.HandsWon);
        Assert.Equal(0, old.Stats.HandsPushed);

        Write("blackjack_options.json", "garbage");
        Write("blackjack_stats.json", "[");
        var broken = new BlackjackViewModel();
        Assert.Equal(100, broken.State.Credits);
        Assert.Equal(0, broken.Stats.HandsPlayed);
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
        Assert.Equal(vm.Options.BlackjackWatermarkScale, vm.BlackjackWatermarkScale);
        Assert.Equal(vm.Options.BlackjackWatermarkOffsetX, vm.BlackjackWatermarkOffsetX);
        Assert.Equal(vm.Options.BlackjackWatermarkOffsetY, vm.BlackjackWatermarkOffsetY);
    }
}
