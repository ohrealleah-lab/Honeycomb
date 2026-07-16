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
    // Session-scoped (not persisted) — starts at 0 each time the player buys in and
    // counts hands played since then, distinct from Stats.HandsPlayed's lifetime total.
    private int _sessionHandsPlayed         = 0;
    // Snapshotted once at Deal() and reused for the rest of that hand (DoubleDown, Split,
    // ApplyPayout) instead of re-reading the live, player-alterable Options.IsNoStressMode —
    // Preferences broadcasts settings changes immediately, so a live re-read let a player
    // flip No Stress Mode mid-hand (after seeing their cards, before payout) to either skip
    // the bet deduction while still collecting a real payout, or vice versa.
    private bool _handFreePlay              = false;

    // Streak is stored in Stats (persisted) — this alias keeps existing UI bindings working.
    public int ConsecutiveWins => Stats.CurrentStreak;

    // ── Computed properties ───────────────────────────────────────────────────

    public BlackjackHand? ActiveHand =>
        State.Phase == BlackjackPhase.Playing && State.ActiveHandIndex < State.PlayerHands.Count
        ? State.PlayerHands[State.ActiveHandIndex]
        : null;

    public bool CanHit    => ActiveHand is { } h && !h.IsComplete;
    public bool CanStand  => ActiveHand is { } h && !h.IsComplete;
    // No Stress Mode's free play has no real credits to check against — Double/Split
    // behave as if the player always has enough. Reads the hand-frozen _handFreePlay
    // snapshot, not the live Options.IsNoStressMode — DoubleDown()/Split() already gate
    // on that same snapshot, so this must match or the button can enable/disable out of
    // sync with what actually happens when it's clicked.
    public bool CanDouble => ActiveHand is { } h && h.Cards.Count == 2 && !h.IsComplete
                             && (_handFreePlay || State.Credits >= h.Bet)
                             && h.ComputeValue().Value is 9 or 10 or 11;
    public bool CanSplit  => !State.IsSplit
                             && ActiveHand is { } h && h.Cards.Count == 2 && !h.IsComplete
                             && h.Cards[0].Rank == h.Cards[1].Rank
                             && (_handFreePlay || State.Credits >= h.Bet);
    public bool CanDeal        => State.Phase is BlackjackPhase.Betting or BlackjackPhase.Result;
    public bool IsPlaying      => State.Phase == BlackjackPhase.Playing;
    public bool CanChangeBet   => State.Phase is BlackjackPhase.Betting or BlackjackPhase.Result;
    public bool CanRebuy       => CanChangeBet && !Options.IsNoStressMode && State.Credits < State.CurrentBet;
    public bool CanUndo        => false;

    public string CreditDisplay => State.Credits.ToString();
    public string BetDisplay    => State.CurrentBet.ToString();
    public string HandsDisplay  => _sessionHandsPlayed.ToString();

    // ── Constructor ───────────────────────────────────────────────────────────

    public BlackjackViewModel()
    {
        Options = LoadOptions();
        Stats   = LoadStatistics();
        State.Credits    = Options.StartingCredits;
        State.CurrentBet = Math.Max(1, Math.Min(Options.BetPerHand, State.Credits));

        // Sync felt color and shared visual settings from global options at startup
        var shared = SettingsService.LoadOptions();
        Options.CardBackTheme      = shared.CardBackTheme;
        Options.IsSoundEnabled     = shared.IsSoundEnabled;
        Options.FeltColor          = shared.FeltColor.ToString();
        Options.CustomFeltColorHex = shared.CustomFeltColorHex;
        Options.IsVignetteEnabled  = shared.IsVignetteEnabled;
        Options.IsNoStressMode     = shared.IsNoStressMode;

        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (_, m) =>
        {
            Options.CardBackTheme      = m.Options.CardBackTheme;
            Options.IsSoundEnabled     = m.Options.IsSoundEnabled;
            Options.FeltColor          = m.Options.FeltColor.ToString();
            Options.CustomFeltColorHex = m.Options.CustomFeltColorHex;
            Options.IsVignetteEnabled  = m.Options.IsVignetteEnabled;
            Options.IsNoStressMode     = m.Options.IsNoStressMode;
            OnPropertyChanged(nameof(Options));
            NotifyStateChanged();
        });
    }

    // ── Game actions ──────────────────────────────────────────────────────────

    public void Deal()
    {
        bool freePlay = Options.IsNoStressMode;
        if (!freePlay && State.Credits < State.CurrentBet) return;
        _handFreePlay = freePlay;

        _deck    = BuildAndShuffleDeck();
        _deckIdx = 0;
        _creditsBeforeDeal = State.Credits;
        if (!freePlay) State.Credits -= State.CurrentBet;

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

        // Stats.HandsPlayed is incremented per resulting hand (in ApplyPayout), not here —
        // a split round produces 2 resulting hands from 1 round, and HandsWon/Lost/Pushed
        // are already tallied per resulting hand, so counting HandsPlayed per round instead
        // would let win-rate (HandsWon/HandsPlayed) mathematically exceed 100%.
        _sessionHandsPlayed++;
        if (!freePlay) Stats.TotalCreditsWagered += State.CurrentBet;

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
        bool freePlay = _handFreePlay;
        var hand = ActiveHand;
        if (hand == null || hand.Cards.Count != 2 || (!freePlay && State.Credits < hand.Bet)) return;
        if (!freePlay)
        {
            State.Credits -= hand.Bet;
            Stats.TotalCreditsWagered += hand.Bet;
        }
        hand.Bet *= 2;
        hand.IsDoubled = true;
        hand.Cards.Add(DrawCard(faceUp: true));
        AdvanceHand();
    }

    public void Split()
    {
        bool freePlay = _handFreePlay;
        var hand = ActiveHand;
        if (hand == null || hand.Cards.Count != 2 || (!freePlay && State.Credits < hand.Bet) || State.IsSplit) return;

        bool splitAces = hand.Cards[0].Rank == 1;

        if (!freePlay)
        {
            State.Credits -= hand.Bet;
            Stats.TotalCreditsWagered += hand.Bet;
        }

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
            if (ActiveHand != null && ActiveHand.IsComplete)
                AdvanceHand();
            else
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

        // A hand that was dealt (bet already taken) but abandoned mid-play — by switching
        // away before Hit/Stand resolved it — never reaches ApplyPayout, which is now the
        // only place Stats.HandsPlayed increments. Count it here so it isn't silently
        // dropped from the lifetime total, one increment per still-unresolved resulting
        // hand (matching split rounds, which can abandon 2 hands from 1 round).
        int abandonedHands = State.PlayerHands.Count(h => h.Result == BlackjackHandResult.Pending);
        if (abandonedHands > 0)
        {
            Stats.HandsPlayed += abandonedHands;
            SaveStatistics();
        }

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
        Stats.CurrentStreak = 0;
        _sessionHandsPlayed = 0;
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
            if (ActiveHand != null && ActiveHand.IsComplete)
                AdvanceHand();
            else
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
        if (roundWon && !roundLost)
        {
            Stats.CurrentStreak++;
            if (Stats.CurrentStreak > Stats.LongestStreak)
                Stats.LongestStreak = Stats.CurrentStreak;
        }
        else if (roundLost)
        {
            Stats.CurrentStreak = 0;
        }

        State.Phase         = BlackjackPhase.Result;
        Options.BetPerHand  = State.CurrentBet;
        SaveOptions();
        SaveStatistics();
        NotifyStateChanged();
    }

    private void ApplyPayout(BlackjackHand hand)
    {
        // No Stress Mode's free play still shows the win/loss/streak, but never
        // touches credits or the money-based stats — only hand-count stats count.
        // Uses the flag snapshotted at Deal(), not a live re-read, so switching No Stress
        // Mode after seeing the hand can't change whether this payout is real money.
        bool freePlay = _handFreePlay;

        Stats.HandsPlayed++;

        switch (hand.Result)
        {
            case BlackjackHandResult.Blackjack:
                int bjReturn = hand.Bet + hand.Bet * 3;  // 3:1 payout (bet returned + 3x bet profit)
                Stats.HandsWon++;
                Stats.Blackjacks++;
                if (!freePlay)
                {
                    State.Credits += bjReturn;
                    Stats.TotalCreditsWon += bjReturn;
                    if (bjReturn > Stats.BiggestPay) Stats.BiggestPay = bjReturn;
                }
                break;
            case BlackjackHandResult.Won:
                int wonReturn = hand.Bet * 2;
                Stats.HandsWon++;
                if (!freePlay)
                {
                    State.Credits += wonReturn;
                    Stats.TotalCreditsWon += wonReturn;
                    if (wonReturn > Stats.BiggestPay) Stats.BiggestPay = wonReturn;
                }
                break;
            case BlackjackHandResult.Push:
                if (!freePlay) State.Credits += hand.Bet;
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
