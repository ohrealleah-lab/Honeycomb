using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

public partial class BlackjackViewModel : ObservableObject
{
    [ObservableProperty] private BlackjackState      _state   = new();
    [ObservableProperty] private BlackjackOptions    _options = new();
    [ObservableProperty] private BlackjackStatistics _stats   = new();

    private List<Card> _deck                = new();
    private int _deckIdx                    = 0;
    private static readonly Random _rng    = new();
    private int _creditsBeforeDeal          = 0;

    public int ConsecutiveWins { get; private set; } = 0;

    // ── Computed properties ───────────────────────────────────────────────────

    public BlackjackHand? ActiveHand =>
        State.Phase == BlackjackPhase.Playing && State.ActiveHandIndex < State.PlayerHands.Count
        ? State.PlayerHands[State.ActiveHandIndex]
        : null;

    public bool CanHit    => ActiveHand is { } h && !h.IsComplete;
    public bool CanStand  => ActiveHand is { } h && !h.IsComplete;
    public bool CanDouble => ActiveHand is { } h && h.Cards.Count == 2 && !h.IsComplete && State.Credits >= h.Bet
                             && h.ComputeValue().Value is 9 or 10 or 11;
    public bool CanSplit  => !State.IsSplit
                             && ActiveHand is { } h && h.Cards.Count == 2 && !h.IsComplete
                             && h.Cards[0].Rank == h.Cards[1].Rank
                             && State.Credits >= h.Bet;
    public bool CanDeal        => State.Phase is BlackjackPhase.Betting or BlackjackPhase.Result;
    public bool IsPlaying      => State.Phase == BlackjackPhase.Playing;
    public bool CanChangeBet   => State.Phase is BlackjackPhase.Betting or BlackjackPhase.Result;
    public bool CanRebuy       => CanChangeBet && State.Credits < State.CurrentBet;
    public bool CanUndo        => false;

    public string CreditDisplay => State.Credits.ToString();
    public string BetDisplay    => State.CurrentBet.ToString();
    public string HandsDisplay  => Stats.HandsPlayed.ToString();

    // ── Constructor ───────────────────────────────────────────────────────────

    public BlackjackViewModel()
    {
        Options = LoadOptions();
        Stats   = LoadStatistics();
        State.Credits    = Options.StartingCredits;
        State.CurrentBet = Math.Max(1, Math.Min(Options.BetPerHand, State.Credits));

        // Sync felt color and shared visual settings from global options at startup
        var shared = SettingsService.LoadOptions();
        Options.IsFinalFantasyMode = shared.IsFinalFantasyMode;
        Options.CardBackTheme      = shared.CardBackTheme;
        Options.IsSoundEnabled     = shared.IsSoundEnabled;
        Options.FeltColor          = shared.FeltColor.ToString();
        Options.CustomFeltColorHex = shared.CustomFeltColorHex;
        Options.IsVignetteEnabled  = shared.IsVignetteEnabled;

        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (_, m) =>
        {
            Options.IsFinalFantasyMode = m.Options.IsFinalFantasyMode;
            Options.CardBackTheme      = m.Options.CardBackTheme;
            Options.IsSoundEnabled     = m.Options.IsSoundEnabled;
            Options.FeltColor          = m.Options.FeltColor.ToString();
            Options.CustomFeltColorHex = m.Options.CustomFeltColorHex;
            Options.IsVignetteEnabled  = m.Options.IsVignetteEnabled;
            OnPropertyChanged(nameof(Options));
        });
    }

    // ── Game actions ──────────────────────────────────────────────────────────

    public void Deal()
    {
        if (State.Credits < State.CurrentBet) return;

        _deck    = BuildAndShuffleDeck();
        _deckIdx = 0;
        _creditsBeforeDeal = State.Credits;
        State.Credits -= State.CurrentBet;

        var playerHand = new BlackjackHand { Bet = State.CurrentBet };
        var dealerHand = new BlackjackHand();

        playerHand.Cards.Add(DrawCard(faceUp: true));
        dealerHand.Cards.Add(DrawCard(faceUp: true));
        playerHand.Cards.Add(DrawCard(faceUp: true));
        dealerHand.Cards.Add(DrawCard(faceUp: false)); // hole card

        State = new BlackjackState
        {
            Phase           = BlackjackPhase.Playing,
            PlayerHands     = new() { playerHand },
            DealerHand      = dealerHand,
            ActiveHandIndex = 0,
            Credits         = State.Credits,
            CurrentBet      = State.CurrentBet,
        };

        Stats.HandsPlayed++;
        Stats.TotalCreditsWagered += State.CurrentBet;

        // Dealer blackjack — push if player also has a natural, otherwise player loses
        if (dealerHand.IsBlackjack)
        {
            FlipHoleCard();
            playerHand.Result = playerHand.IsBlackjack
                ? BlackjackHandResult.Push
                : BlackjackHandResult.Lost;
            SettleAndFinish();
            return;
        }

        // Natural blackjack — auto-resolve (dealer confirmed no BJ above)
        if (playerHand.IsBlackjack)
        {
            FlipHoleCard();
            playerHand.Result = BlackjackHandResult.Blackjack;
            SettleAndFinish();
            return;
        }

        NotifyStateChanged();
    }

    public void Hit()
    {
        var hand = ActiveHand;
        if (hand == null || hand.IsComplete) return;
        hand.Cards.Add(DrawCard(faceUp: true));
        if (hand.IsBust || hand.ComputeValue().Value == 21) AdvanceHand();
        else NotifyStateChanged();
    }

    public void Stand()
    {
        if (ActiveHand == null) return;
        ActiveHand.IsStood = true;
        AdvanceHand();
    }

    public void DoubleDown()
    {
        var hand = ActiveHand;
        if (hand == null || hand.Cards.Count != 2 || State.Credits < hand.Bet) return;
        State.Credits -= hand.Bet;
        Stats.TotalCreditsWagered += hand.Bet;
        hand.Bet *= 2;
        hand.IsDoubled = true;
        hand.Cards.Add(DrawCard(faceUp: true));
        AdvanceHand();
    }

    public void Split()
    {
        var hand = ActiveHand;
        if (hand == null || hand.Cards.Count != 2 || State.Credits < hand.Bet || State.IsSplit) return;

        bool splitAces = hand.Cards[0].Rank == 1;

        State.Credits -= hand.Bet;
        Stats.TotalCreditsWagered += hand.Bet;

        var hand2 = new BlackjackHand { Bet = hand.Bet, FromSplit = true };
        hand2.Cards.Add(hand.Cards[1]);
        hand.Cards.RemoveAt(1);
        hand.FromSplit = true;

        hand.Cards.Add(DrawCard(faceUp: true));
        hand2.Cards.Add(DrawCard(faceUp: true));

        State.PlayerHands.Add(hand2);
        State.IsSplit        = true;
        State.ActiveHandIndex = 0;

        if (splitAces)
        {
            // Standard rules: split aces receive exactly one card each, then auto-stand
            hand.IsStood  = true;
            hand2.IsStood = true;
            DealerPlay();
        }
        else
        {
            NotifyStateChanged();
        }
    }

    // Chip buttons (1/5/10/25): while the bet is still at the round's default of 1,
    // clicking a chip other than "1" replaces the bet with that chip's value instead
    // of adding to it — so the first click always sets a clean number instead of
    // starting from "1 + chip". Once the bet has moved off 1 (however it got there),
    // every chip click just adds normally.
    public void AddToBet(int amount)
    {
        if (!CanChangeBet) return;
        if (amount != 1 && State.CurrentBet == 1)
            State.CurrentBet = Math.Max(1, Math.Min(amount, State.Credits));
        else
            State.CurrentBet = Math.Max(1, Math.Min(State.CurrentBet + amount, State.Credits));
        NotifyStateChanged();
    }

    public void DoubleBet()
    {
        if (!CanChangeBet) return;
        State.CurrentBet = Math.Max(1, Math.Min(State.CurrentBet * 2, State.Credits));
        NotifyStateChanged();
    }

    public void ClearBet()
    {
        if (!CanChangeBet) return;
        State.CurrentBet = 1;
        NotifyStateChanged();
    }

    public void Rebuy()
    {
        State.Credits += Options.StartingCredits;
        Stats.Rebuys++;
        SaveStatistics();
        NotifyStateChanged();
    }

    // Called when switching back to Blackjack — clears stale cards without resetting credits.
    public void PrepareForResume()
    {
        if (State.Phase == BlackjackPhase.Betting) return;
        State = new BlackjackState
        {
            Credits    = State.Credits,
            CurrentBet = State.CurrentBet,
            Phase      = BlackjackPhase.Betting,
        };
    }

    public void StartNewGame()
    {
        Options.BetPerHand = State.CurrentBet;
        SaveOptions();
        ConsecutiveWins = 0;
        State = new BlackjackState
        {
            Credits    = Options.StartingCredits,
            CurrentBet = Math.Max(1, Math.Min(Options.BetPerHand, Options.StartingCredits)),
            Phase      = BlackjackPhase.Betting,
        };
    }

    // ── Internal logic ────────────────────────────────────────────────────────

    private void AdvanceHand()
    {
        int next = State.ActiveHandIndex + 1;
        if (next < State.PlayerHands.Count)
        {
            State.ActiveHandIndex = next;
            NotifyStateChanged();
            return;
        }

        // All player hands complete — check if all bust to skip dealer draw
        if (State.PlayerHands.All(h => h.IsBust))
        {
            FlipHoleCard();
            SettleAndFinish();
        }
        else
        {
            DealerPlay();
        }
    }

    private void DealerPlay()
    {
        // Guards against a delayed/async auto-resolve callback firing after the phase
        // has already moved on, which would otherwise re-run the dealer's turn twice.
        if (State.Phase != BlackjackPhase.Playing) return;
        State.Phase = BlackjackPhase.DealerTurn;
        FlipHoleCard();

        // Stands on all 17s, hard and soft (per spec)
        while (State.DealerHand.ComputeValue().Value < 17)
            State.DealerHand.Cards.Add(DrawCard(faceUp: true));

        SettleAndFinish();
    }

    private void FlipHoleCard()
    {
        var cards = State.DealerHand.Cards;
        for (int i = 0; i < cards.Count; i++)
            if (!cards[i].IsFaceUp) cards[i] = cards[i] with { IsFaceUp = true };
    }

    private void SettleAndFinish()
    {
        var (dealerValue, _) = State.DealerHand.ComputeValue();
        bool dealerBust = dealerValue > 21;

        foreach (var hand in State.PlayerHands)
        {
            if (hand.Result != BlackjackHandResult.Pending)
            {
                ApplyPayout(hand);
                continue;
            }

            var (pv, _) = hand.ComputeValue();
            hand.Result = hand.IsBust                    ? BlackjackHandResult.Lost
                        : dealerBust || pv > dealerValue ? BlackjackHandResult.Won
                        : pv == dealerValue              ? BlackjackHandResult.Push
                                                         : BlackjackHandResult.Lost;
            ApplyPayout(hand);
        }

        State.LastNetResult = State.Credits - _creditsBeforeDeal;

        bool roundWon  = State.PlayerHands.Any(h => h.Result is BlackjackHandResult.Won or BlackjackHandResult.Blackjack);
        bool roundLost = State.PlayerHands.Any(h => h.Result == BlackjackHandResult.Lost);
        if (roundWon && !roundLost) ConsecutiveWins++;
        else if (roundLost)        ConsecutiveWins = 0;

        State.Phase         = BlackjackPhase.Result;
        Options.BetPerHand  = State.CurrentBet;
        SaveOptions();
        SaveStatistics();
        NotifyStateChanged();
    }

    private void ApplyPayout(BlackjackHand hand)
    {
        switch (hand.Result)
        {
            case BlackjackHandResult.Blackjack:
                int bjReturn = hand.Bet + hand.Bet * 3;  // 3:1 payout (bet returned + 3x bet profit)
                State.Credits += bjReturn;
                Stats.HandsWon++;
                Stats.Blackjacks++;
                Stats.TotalCreditsWon += bjReturn;
                if (bjReturn > Stats.BiggestPay) Stats.BiggestPay = bjReturn;
                break;
            case BlackjackHandResult.Won:
                int wonReturn = hand.Bet * 2;
                State.Credits += wonReturn;
                Stats.HandsWon++;
                Stats.TotalCreditsWon += wonReturn;
                if (wonReturn > Stats.BiggestPay) Stats.BiggestPay = wonReturn;
                break;
            case BlackjackHandResult.Push:
                State.Credits += hand.Bet;
                Stats.HandsPushed++;
                break;
            case BlackjackHandResult.Lost:
                Stats.HandsLost++;
                break;
        }
    }

    // ── Deck ──────────────────────────────────────────────────────────────────

    private static List<Card> BuildAndShuffleDeck()
    {
        var deck = (from suit in Enum.GetValues<CardSuit>()
                    from rank in Enumerable.Range(1, 13)
                    select new Card($"{suit}_{rank}", suit, rank, true)).ToList();
        for (int i = deck.Count - 1; i > 0; i--)
        {
            int j = _rng.Next(i + 1);
            (deck[i], deck[j]) = (deck[j], deck[i]);
        }
        return deck;
    }

    private Card DrawCard(bool faceUp)
    {
        // Defensive fallback — should be unreachable under current rules (a single
        // fresh 52-card deck per deal, at most one split allowing 2 player hands, and
        // forced-stand at 21 bound total cards drawn well under 52 by the pigeonhole
        // principle: only 4 cards of each rank exist). Reshuffle a fresh deck instead of
        // throwing if that invariant is ever broken by a future rule change.
        if (_deckIdx >= _deck.Count)
        {
            _deck    = BuildAndShuffleDeck();
            _deckIdx = 0;
        }

        var card = _deck[_deckIdx++];
        return card with { IsFaceUp = faceUp };
    }

    // ── Persistence ───────────────────────────────────────────────────────────

    private static readonly string DataDir        = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SoliBee");
    private static readonly string OptionsPath    = Path.Combine(DataDir, "blackjack_options.json");
    private static readonly string StatisticsPath = Path.Combine(DataDir, "blackjack_stats.json");

    public void SaveOptions()
    {
        try { Directory.CreateDirectory(DataDir); File.WriteAllText(OptionsPath, JsonSerializer.Serialize(Options, new JsonSerializerOptions { WriteIndented = true })); }
        catch { }
    }

    private static BlackjackOptions LoadOptions()
    {
        try { if (File.Exists(OptionsPath)) { var o = JsonSerializer.Deserialize<BlackjackOptions>(File.ReadAllText(OptionsPath)); if (o != null) return o; } }
        catch { }
        return new BlackjackOptions();
    }

    private void SaveStatistics()
    {
        try { Directory.CreateDirectory(DataDir); File.WriteAllText(StatisticsPath, JsonSerializer.Serialize(Stats, new JsonSerializerOptions { WriteIndented = true })); }
        catch { }
    }

    public void ResetStats()
    {
        Stats = new BlackjackStatistics();
        SaveStatistics();
    }

    private static BlackjackStatistics LoadStatistics()
    {
        try { if (File.Exists(StatisticsPath)) { var s = JsonSerializer.Deserialize<BlackjackStatistics>(File.ReadAllText(StatisticsPath)); if (s != null) return s; } }
        catch { }
        return new BlackjackStatistics();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private void NotifyStateChanged()
    {
        OnPropertyChanged(nameof(State));
        OnPropertyChanged(nameof(ActiveHand));
        OnPropertyChanged(nameof(CanHit));
        OnPropertyChanged(nameof(CanStand));
        OnPropertyChanged(nameof(CanDouble));
        OnPropertyChanged(nameof(CanSplit));
        OnPropertyChanged(nameof(CanDeal));
        OnPropertyChanged(nameof(IsPlaying));
        OnPropertyChanged(nameof(CanChangeBet));
        OnPropertyChanged(nameof(CanRebuy));
        OnPropertyChanged(nameof(CreditDisplay));
        OnPropertyChanged(nameof(BetDisplay));
        OnPropertyChanged(nameof(HandsDisplay));
        OnPropertyChanged(nameof(Stats));
        OnPropertyChanged(nameof(ConsecutiveWins));
    }
}
