using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

public partial class BlackjackViewModel : ObservableObject
{
    [ObservableProperty] private BlackjackState      _state   = new();
    [ObservableProperty] private BlackjackOptions    _options = new();
    [ObservableProperty] private BlackjackStatistics _stats   = new();

    // FIFO queue of banner texts (milestones, loading flavor) — mirrors the Honeycomb
    // port's BannerQueue/EnqueueBanner/AdvanceBannerQueue.
    private readonly Queue<string> _bannerQueue = new();
    public event Action<string>? OnFlashBanner;

    private void EnqueueBanner(string text)
    {
        _bannerQueue.Enqueue(text);
        if (_bannerQueue.Count == 1) OnFlashBanner?.Invoke(text);
    }

    // Flat passthroughs for the bee watermark's RenderTransform bindings (BlackjackView.axaml).
    // A binding path like "Options.BlackjackWatermarkScale" only refreshes when its OWN
    // property-changed notification fires; raising OnPropertyChanged(nameof(Options)) on
    // rapid-fire ticks (dragging the calibration sliders) doesn't reliably force Avalonia to
    // re-walk the nested path every time. Binding directly to these VM-level properties, with
    // their own explicit OnPropertyChanged call in the OptionsChangedMessage handler below,
    // sidesteps that.
    public double BlackjackWatermarkScale   => Options.BlackjackWatermarkScale;
    public double BlackjackWatermarkOffsetX => Options.BlackjackWatermarkOffsetX;
    public double BlackjackWatermarkOffsetY => Options.BlackjackWatermarkOffsetY;

    public void AdvanceBannerQueue()
    {
        if (_bannerQueue.Count == 0) return;
        _bannerQueue.Dequeue();
        if (_bannerQueue.Count > 0) OnFlashBanner?.Invoke(_bannerQueue.Peek());
    }

    // Fires the "out of credits" toast at the same Credits <= 10 threshold CanRebuy
    // uses, and only after an outright round loss (not a win/push — a split round can
    // win one hand while losing another, or a double-down can win back more than it
    // cost, so being low on credits alone doesn't mean the player is actually stuck).
    // Public and called from the view, deliberately NOT from SettleAndFinish itself —
    // the view times this call to fire once its own win/lose result banner has finished
    // fading out, so the toast reads as landing alongside the Rebuy button rather than
    // stacking on top of the result banner while it's still up. 20% flavor ("Busy as a
    // bee, broke as a beekeeper.") / 80% the plain "Out of Credits!" toast, per the
    // catalog entry's gate.
    public void CheckOutOfCredits()
    {
        if (Options.IsNoStressMode || State.Credits > 10) return;
        bool roundWon  = State.PlayerHands.Any(h => h.Result is BlackjackHandResult.Won or BlackjackHandResult.Blackjack);
        bool roundLost = State.PlayerHands.Any(h => h.Result == BlackjackHandResult.Lost);
        if (!roundLost || roundWon) return;
        var result = BannerCatalog.Fire(BannerId.GameplayPlayerRunsOutOfCreditsVideoPokerBlackjack);
        var text = result.Kind == BannerFireKind.Message
            ? result.Text!
            : Strings.Get(StringKey.OutOfCreditsToast, SettingsService.LoadOptions().Language);
        EnqueueBanner(text);
    }

    // Fires once, exactly on crossing a threshold — checked against the value BEFORE
    // this round's wins were added, since a split round can win multiple hands at
    // once and jump straight past a threshold (e.g. 9 -> 11), skipping "== 10" entirely.
    private void CheckWinMilestones(int previousHandsWon)
    {
        var thresholds = new (int Threshold, BannerId Id)[]
        {
            (10, BannerId.MilestonesPlayerReaches10TotalWins),
            (100, BannerId.MilestonesPlayerReaches100TotalWins),
            (1000, BannerId.MilestonesPlayerReaches1000TotalWins),
        };
        foreach (var (threshold, id) in thresholds)
        {
            if (previousHandsWon >= threshold || Stats.HandsWon < threshold) continue;
            var result = BannerCatalog.Fire(id);
            if (result.Kind == BannerFireKind.Message) EnqueueBanner(result.Text!);
        }
    }

    // Fires once per app session, the first time this game's view actually appears
    // (called from BlackjackView's Loaded handler — a "loading" banner belongs to
    // a screen transition, not a gameplay action, so switching to this game for the
    // first time this session fires it; switching back to it later doesn't).
    private bool _hasFiredLoadingBannerThisSession;

    // Ambiance/Idle nudge: fires if a full minute passes with no action. Re-armed via
    // a generation-token so an already-scheduled check from before the last action
    // sees a mismatch and silently no-ops instead of firing late. Mirrors the
    // Honeycomb port's ScheduleIdleCheck — called from Deal().
    private int _idleCheckGeneration = 0;
    private const int IdleToastDelayMs = 60000;

    public async void ScheduleIdleActionCheck()
    {
        if (TestMode.IsHeadless) return;
        _idleCheckGeneration++;
        var generation = _idleCheckGeneration;
        await Task.Delay(IdleToastDelayMs);
        if (_idleCheckGeneration != generation) return;
        var result = BannerCatalog.Fire(BannerId.IdleActionNoActionTakenForOneMinute);
        if (result.Kind == BannerFireKind.Message) EnqueueBanner(result.Text!);
    }

    public void CheckLoadingBanner()
    {
        if (_hasFiredLoadingBannerThisSession) return;
        _hasFiredLoadingBannerThisSession = true;
        var result = BannerCatalog.Fire(BannerCatalog.LoadingBannerId());
        if (result.Kind == BannerFireKind.Message) EnqueueBanner(result.Text!);
    }

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
    // Shown as an early low-credits warning (10, not "can no longer afford the current
    // bet") so the player sees Buy In before they're actually stuck — not a hard block,
    // since Deal stays visible/usable alongside it as long as they can still afford
    // something (see DealButton.IsVisible in BlackjackView.axaml.cs).
    public bool CanRebuy       => CanChangeBet && !Options.IsNoStressMode && State.Credits <= 10;
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
        Options.HideBee            = shared.HideBee;
        Options.BlackjackWatermarkScale = shared.BlackjackWatermarkScale;
        Options.BlackjackWatermarkOffsetX = shared.BlackjackWatermarkOffsetX;
        Options.BlackjackWatermarkOffsetY = shared.BlackjackWatermarkOffsetY;

        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (_, m) =>
        {
            Options.CardBackTheme      = m.Options.CardBackTheme;
            Options.IsSoundEnabled     = m.Options.IsSoundEnabled;
            Options.FeltColor          = m.Options.FeltColor.ToString();
            Options.CustomFeltColorHex = m.Options.CustomFeltColorHex;
            Options.IsVignetteEnabled  = m.Options.IsVignetteEnabled;
            Options.IsNoStressMode     = m.Options.IsNoStressMode;
            Options.HideBee            = m.Options.HideBee;
            Options.BlackjackWatermarkScale = m.Options.BlackjackWatermarkScale;
            Options.BlackjackWatermarkOffsetX = m.Options.BlackjackWatermarkOffsetX;
            Options.BlackjackWatermarkOffsetY = m.Options.BlackjackWatermarkOffsetY;
            OnPropertyChanged(nameof(Options));
            OnPropertyChanged(nameof(BlackjackWatermarkScale));
            OnPropertyChanged(nameof(BlackjackWatermarkOffsetX));
            OnPropertyChanged(nameof(BlackjackWatermarkOffsetY));
            NotifyStateChanged();
        });
    }

    // ── Game actions ──────────────────────────────────────────────────────────

    public void Deal()
    {
        bool freePlay = Options.IsNoStressMode;
        if (!freePlay && State.Credits < State.CurrentBet) return;
        _handFreePlay = freePlay;

        // Stats.HandsPlayed only increments later, per resulting hand (in
        // ApplyPayout) — checking it here, before any of that, is still this game's
        // equivalent of "is this the very first hand ever."
        if (Stats.HandsPlayed == 0)
        {
            var firstLaunchResult = BannerCatalog.Fire(BannerId.MilestonesFirstLaunchEver);
            if (firstLaunchResult.Kind == BannerFireKind.Message) EnqueueBanner(firstLaunchResult.Text!);
        }

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
        ScheduleIdleActionCheck();

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

    // Called when switching back to Blackjack. Like Video Poker, if a round is already
    // over (Result phase), returning clears the board for a new hand so you don't have
    // to dismiss the old banner. Mid-hand games (Playing phase) are preserved.
    public void ResetIfRoundOver()
    {
        if (State.Phase == BlackjackPhase.Result)
        {
            State = new BlackjackState
            {
                Credits    = State.Credits,
                CurrentBet = State.CurrentBet,
                Phase      = BlackjackPhase.Betting,
            };
        }
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
        // Captured before the per-hand loop below (which can win multiple split
        // hands in one round) so CheckWinMilestones can catch a threshold crossed
        // partway through, not just landed on exactly.
        int previousHandsWon = Stats.HandsWon;

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
        CheckWinMilestones(previousHandsWon);

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
                // 3:1 payout (bet returned + 3x bet profit) — always a whole number for
                // any integer bet, unlike the old 3:2 payout, which needed half-up
                // rounding to avoid shortchanging the player on odd bets.
                int bjReturn = hand.Bet * 4;
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
                if (!freePlay)
                {
                    State.Credits += hand.Bet;
                    // Counts toward Total Paid (a push returns the stake, which is a real
                    // credit movement worth reflecting in RTP), but deliberately not toward
                    // BiggestPay — a push is a returned stake, not a winning payout.
                    Stats.TotalCreditsWon += hand.Bet;
                }
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

    private static readonly string DataDir        = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), AppDataMigration.FolderName);
    private static readonly string OptionsPath    = Path.Combine(DataDir, "blackjack_options.json");
    private static readonly string StatisticsPath = Path.Combine(DataDir, "blackjack_stats.json");

    public void SaveOptions()
    {
        try { Directory.CreateDirectory(DataDir); File.WriteAllText(OptionsPath, JsonSerializer.Serialize(Options, new JsonSerializerOptions { WriteIndented = true })); }
        catch { }
        // Options is the same live instance Preferences edits directly (single consumer,
        // no cross-ViewModel broadcast needed) — notify so the view refreshes immediately.
        OnPropertyChanged(nameof(Options));
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
