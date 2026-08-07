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

public partial class VideoPokerViewModel : ObservableObject
{
    [ObservableProperty] private VideoPokerState _state = new();
    [ObservableProperty] private VideoPokerOptions _options = new();
    [ObservableProperty] private VideoPokerStatistics _stats = new();

    // The player's actual chosen bet, independent of State.CurrentBet — Deal() clamps
    // CurrentBet down to whatever credits remain when they're short (it also doubles as
    // "amount wagered this hand" for Draw()'s payout math, so it can't just track the
    // player's preference directly). Restoring CurrentBet from this once credits recover
    // (rebuy, or a win) is what makes that clamp temporary instead of a permanent,
    // unannounced bet reduction the player has to notice and manually undo.
    private int _preferredBet = 1;

    public bool IsBetBoardVisible => !Options.IsNoStressMode && !Options.HideBetBoard;

    // FIFO queue of banner texts (milestones, loading flavor) — mirrors the Honeycomb
    // port's BannerQueue/EnqueueBanner/AdvanceBannerQueue.
    private readonly Queue<string> _bannerQueue = new();
    public event Action<string>? OnFlashBanner;

    private void EnqueueBanner(string text)
    {
        _bannerQueue.Enqueue(text);
        if (_bannerQueue.Count == 1) OnFlashBanner?.Invoke(text);
    }

    public void AdvanceBannerQueue()
    {
        if (_bannerQueue.Count == 0) return;
        _bannerQueue.Dequeue();
        if (_bannerQueue.Count > 0) OnFlashBanner?.Invoke(_bannerQueue.Peek());
    }

    // Fires once, exactly on crossing a threshold — checked against the value BEFORE
    // this draw's win was added.
    private void CheckWinMilestones(int previousWinningHands)
    {
        var thresholds = new (int Threshold, BannerId Id)[]
        {
            (10, BannerId.MilestonesPlayerReaches10TotalWins),
            (100, BannerId.MilestonesPlayerReaches100TotalWins),
            (1000, BannerId.MilestonesPlayerReaches1000TotalWins),
        };
        foreach (var (threshold, id) in thresholds)
        {
            if (previousWinningHands >= threshold || Stats.WinningHands < threshold) continue;
            var result = BannerCatalog.Fire(id);
            if (result.Kind == BannerFireKind.Message) EnqueueBanner(result.Text!);
        }
    }

    // Fires once per app session, the first time this game's view actually appears
    // (called from VideoPokerView's Loaded handler — a "loading" banner belongs to
    // a screen transition, not a gameplay action, so switching to this game for the
    // first time this session fires it; switching back to it later doesn't).
    private bool _hasFiredLoadingBannerThisSession;

    public void CheckLoadingBanner()
    {
        if (_hasFiredLoadingBannerThisSession) return;
        _hasFiredLoadingBannerThisSession = true;
        var result = BannerCatalog.Fire(BannerCatalog.LoadingBannerId());
        if (result.Kind == BannerFireKind.Message) EnqueueBanner(result.Text!);
    }

    private List<Card> _deck = new();
    // Session-scoped (not persisted) — starts at 0 each time the player buys in and
    // counts hands played since then, distinct from Stats.TotalHands's lifetime total.
    private int _sessionHandsPlayed = 0;

    // ── Pay tables ────────────────────────────────────────────────────────────

    private static readonly VideoPokerPayEntry[] JoBTable =
    {
        new("Royal Flush",     PokerHandRank.RoyalFlush,    VideoPokerQualifier.NoWild,         new[]{250,250,250,250,800}),
        new("Straight Flush",  PokerHandRank.StraightFlush, VideoPokerQualifier.None,           new[]{50, 50, 50, 50, 50 }),
        new("Four of a Kind",  PokerHandRank.FourOfAKind,   VideoPokerQualifier.None,           new[]{25, 25, 25, 25, 25 }),
        new("Full House",      PokerHandRank.FullHouse,     VideoPokerQualifier.None,           new[]{9,  9,  9,  9,  9  }),
        new("Flush",           PokerHandRank.Flush,         VideoPokerQualifier.None,           new[]{6,  6,  6,  6,  6  }),
        new("Straight",        PokerHandRank.Straight,      VideoPokerQualifier.None,           new[]{4,  4,  4,  4,  4  }),
        new("Three of a Kind", PokerHandRank.ThreeOfAKind,  VideoPokerQualifier.None,           new[]{3,  3,  3,  3,  3  }),
        new("Two Pair",        PokerHandRank.TwoPair,       VideoPokerQualifier.None,           new[]{2,  2,  2,  2,  2  }),
        new("Jacks or Better", PokerHandRank.OnePair,       VideoPokerQualifier.JacksOrBetter,  new[]{1,  1,  1,  1,  1  }),
    };

    private static readonly VideoPokerPayEntry[] DeucesTable =
    {
        new("Natural Royal",  PokerHandRank.RoyalFlush,    VideoPokerQualifier.NoWild,        new[]{250,250,250,250,800}),
        new("Four Deuces",    PokerHandRank.FourOfAKind,   VideoPokerQualifier.FourDeuces,    new[]{200,200,200,200,200}),
        new("Wild Royal",     PokerHandRank.RoyalFlush,    VideoPokerQualifier.RequiresWild,  new[]{25, 25, 25, 25, 25 }),
        new("Five of a Kind", PokerHandRank.FiveOfAKind,   VideoPokerQualifier.RequiresWild,  new[]{15, 15, 15, 15, 15 }),
        new("Straight Flush", PokerHandRank.StraightFlush, VideoPokerQualifier.None,          new[]{9,  9,  9,  9,  9  }),
        new("Four of a Kind", PokerHandRank.FourOfAKind,   VideoPokerQualifier.None,          new[]{5,  5,  5,  5,  5  }),
        new("Full House",     PokerHandRank.FullHouse,     VideoPokerQualifier.None,          new[]{3,  3,  3,  3,  3  }),
        new("Flush",          PokerHandRank.Flush,         VideoPokerQualifier.None,          new[]{2,  2,  2,  2,  2  }),
        new("Straight",       PokerHandRank.Straight,      VideoPokerQualifier.None,          new[]{2,  2,  2,  2,  2  }),
        new("Three of a Kind",PokerHandRank.ThreeOfAKind,  VideoPokerQualifier.None,          new[]{1,  1,  1,  1,  1  }),
    };

    private static readonly VideoPokerPayEntry[] BonusTable =
    {
        new("Royal Flush",    PokerHandRank.RoyalFlush,    VideoPokerQualifier.NoWild,     new[]{250,250,250,250,800}),
        new("Straight Flush", PokerHandRank.StraightFlush, VideoPokerQualifier.None,       new[]{50, 50, 50, 50, 50 }),
        new("Four Aces",      PokerHandRank.FourOfAKind,   VideoPokerQualifier.BonusAces,  new[]{80, 80, 80, 80, 80 }),
        new("Four 2s-4s",     PokerHandRank.FourOfAKind,   VideoPokerQualifier.Bonus234s,  new[]{40, 40, 40, 40, 40 }),
        new("Four of a Kind", PokerHandRank.FourOfAKind,   VideoPokerQualifier.None,       new[]{25, 25, 25, 25, 25 }),
        new("Full House",     PokerHandRank.FullHouse,     VideoPokerQualifier.None,       new[]{8,  8,  8,  8,  8  }),
        new("Flush",          PokerHandRank.Flush,         VideoPokerQualifier.None,       new[]{5,  5,  5,  5,  5  }),
        new("Straight",       PokerHandRank.Straight,      VideoPokerQualifier.None,       new[]{4,  4,  4,  4,  4  }),
        new("Three of a Kind",PokerHandRank.ThreeOfAKind,  VideoPokerQualifier.None,       new[]{3,  3,  3,  3,  3  }),
        new("Two Pair",       PokerHandRank.TwoPair,       VideoPokerQualifier.None,       new[]{2,  2,  2,  2,  2  }),
        new("Jacks or Better",PokerHandRank.OnePair,       VideoPokerQualifier.JacksOrBetter, new[]{1, 1, 1, 1, 1  }),
    };

    public VideoPokerPayEntry[] CurrentTable => Options.Variant switch
    {
        VideoPokerVariant.DeucesWild => DeucesTable,
        VideoPokerVariant.BonusPoker => BonusTable,
        _                            => JoBTable,
    };

    // ── Display properties ────────────────────────────────────────────────────

    public string ScoreDisplay    => $"${State.SessionCredits}";
    public string CreditDisplay   => State.SessionCredits.ToString();
    public string BetDisplay      => State.CurrentBet.ToString();
    public string HandsDisplay    => _sessionHandsPlayed.ToString();
    // No Stress Mode's free play still announces the winning hand, just without a
    // credit amount attached (no credits are ever earned in free play).
    public string ResultText      => State.Phase == VideoPokerPhase.Result && State.LastPayout > 0
                                        ? Options.IsNoStressMode
                                            ? $"★  {State.LastHandName}  ★"
                                            : $"★  {State.LastHandName}  +{State.LastPayout}  ★"
                                        : "";
    public bool   HasWin          => State.Phase == VideoPokerPhase.Result && State.LastPayout > 0;
    public bool   ShowNoWin       => State.Phase == VideoPokerPhase.Result && State.LastPayout == 0 && State.Hand.Count > 0;
    public bool   CanUndo         => false;
    public bool   IsDealing       => State.Phase == VideoPokerPhase.Deal || State.Phase == VideoPokerPhase.Result;
    public bool   IsHolding       => State.Phase == VideoPokerPhase.Holding;

    // Matches Mac: Draw never costs new credits (the bet was already taken at Deal), but
    // starting a fresh Deal requires covering the current bet unless in free play.
    public bool   CanDeal         => IsHolding || Options.IsNoStressMode || State.SessionCredits >= State.CurrentBet;
    // Early low-credits warning (10, not "can't afford the current bet") — Deal/Draw
    // stays visible alongside it (RebuyButton doesn't hide it in the XAML), so this
    // isn't a hard block, just a heads-up before the player actually runs out.
    public bool   NeedsRebuy      => !Options.IsNoStressMode && State.SessionCredits <= 10;
    public string DealDrawLabel   => IsHolding ? "Draw  [D]" : "Deal  [D]";
    public string VariantName     => Options.Variant switch
    {
        VideoPokerVariant.DeucesWild => "DEUCES WILD",
        VideoPokerVariant.BonusPoker => "BONUS POKER",
        _                            => "JACKS OR BETTER",
    };
    public string WinningHandName => State.Phase == VideoPokerPhase.Result ? State.LastHandName : "";

    public VideoPokerViewModel()
    {
        Options = LoadOptions();
        Stats   = LoadStatistics();
        State.SessionCredits = Options.StartingCredits;
        _preferredBet        = Math.Clamp(Options.BetPerHand, 1, 5);
        State.CurrentBet     = _preferredBet;

        // Sync shared visual settings from global options at startup
        var shared = SettingsService.LoadOptions();
        Options.CardBackTheme       = shared.CardBackTheme;
        Options.IsSoundEnabled      = shared.IsSoundEnabled;
        Options.FeltColor           = shared.FeltColor.ToString();
        Options.CustomFeltColorHex  = shared.CustomFeltColorHex;
        Options.IsVignetteEnabled   = shared.IsVignetteEnabled;
        Options.IsNoStressMode      = shared.IsNoStressMode;

        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (_, m) =>
        {
            Options.CardBackTheme       = m.Options.CardBackTheme;
            Options.IsSoundEnabled      = m.Options.IsSoundEnabled;
            Options.FeltColor           = m.Options.FeltColor.ToString();
            Options.CustomFeltColorHex  = m.Options.CustomFeltColorHex;
            Options.IsVignetteEnabled   = m.Options.IsVignetteEnabled;
            Options.IsNoStressMode      = m.Options.IsNoStressMode;
            OnPropertyChanged(nameof(Options));
            NotifyStateChanged();
        });
    }

    // ── Game actions ──────────────────────────────────────────────────────────

    public void Deal()
    {
        bool freePlay = Options.IsNoStressMode;
        if (!freePlay)
        {
            // Credits have recovered (rebuy, or carried winnings) enough to cover what
            // the player actually wants to bet — restore it instead of leaving CurrentBet
            // stuck at whatever a previous low-credit hand left it at.
            if (State.SessionCredits >= _preferredBet) State.CurrentBet = _preferredBet;
            // Matches Mac: refuse to deal (no auto-clamp, no partial-bet hand) when
            // credits can't cover the current bet — the player must lower the bet or
            // rebuy first, rather than a hand silently getting dealt for less than the
            // bet shown on screen.
            if (State.SessionCredits < State.CurrentBet) return;
        }
        // Stats.TotalHands only grows via the increment below, so checking it here,
        // before that increment, is this game's equivalent of "is this the very
        // first hand ever."
        if (Stats.TotalHands == 0)
        {
            var firstLaunchResult = BannerCatalog.Fire(BannerId.MilestonesFirstLaunchEver);
            if (firstLaunchResult.Kind == BannerFireKind.Message) EnqueueBanner(firstLaunchResult.Text!);
        }

        if (!freePlay) State.SessionCredits -= State.CurrentBet;
        State.HeldSlots        = new bool[5];
        State.WinningCardMask  = new bool[5];
        State.Phase            = VideoPokerPhase.Holding;
        State.ResultBannerShown = false;

        BuildAndShuffleDeck();
        State.Hand = _deck.Take(5).Select(c => c with { IsFaceUp = true }).ToList();
        _deck = _deck.Skip(5).ToList();

        Stats.TotalHands++;
        _sessionHandsPlayed++;
        if (!freePlay) Stats.TotalCreditsWagered += State.CurrentBet;

        NotifyStateChanged();
    }

    public void Draw()
    {
        if (State.Phase != VideoPokerPhase.Holding) return;
        bool freePlay = Options.IsNoStressMode;

        int drawIdx  = 0;
        var drawPile = _deck.ToList();
        for (int i = 0; i < 5; i++)
        {
            if (!State.HeldSlots[i] && drawIdx < drawPile.Count)
                State.Hand[i] = drawPile[drawIdx++] with { IsFaceUp = true };
        }

        var (entry, payout) = EvaluateHand(State.Hand.ToArray());
        State.LastPayout      = payout;
        State.LastHandName    = entry?.HandName ?? "";
        if (!freePlay) State.SessionCredits += payout;
        State.WinningCardMask = payout > 0
            ? GetWinningCardMask(State.Hand, entry!.Rank, Options.Variant == VideoPokerVariant.DeucesWild)
            : new bool[5];
        State.Phase           = VideoPokerPhase.Result;

        // No Stress Mode's free play still tracks/shows wins and hand frequency
        // (streaks, "winning hand" display), but never touches money-based stats.
        if (payout > 0)
        {
            int previousWinningHands = Stats.WinningHands;
            Stats.WinningHands++;
            Stats.CurrentStreak++;
            if (Stats.CurrentStreak > Stats.LongestStreak)
                Stats.LongestStreak = Stats.CurrentStreak;
            if (!freePlay)
            {
                Stats.TotalCreditsWon += payout;
                if (payout > Stats.BiggestPay) Stats.BiggestPay = payout;
            }
            var key = entry!.HandName;
            Stats.HandCounts[key] = Stats.HandCounts.GetValueOrDefault(key) + 1;
            if (entry.Rank == PokerHandRank.RoyalFlush) Stats.RoyalFlushCount++;
            CheckWinMilestones(previousWinningHands);
        }
        else
        {
            Stats.CurrentStreak = 0;
        }

        SaveStatistics();
        NotifyStateChanged();
    }

    public void DealOrDraw()
    {
        if (IsHolding) Draw();
        else           Deal();
    }

    public void ToggleHold(int index)
    {
        if (State.Phase != VideoPokerPhase.Holding || index < 0 || index >= 5) return;
        State.HeldSlots[index] = !State.HeldSlots[index];
        NotifyStateChanged();
    }

    public void HoldAll()
    {
        if (State.Phase != VideoPokerPhase.Holding) return;
        for (int i = 0; i < 5; i++) State.HeldSlots[i] = true;
        NotifyStateChanged();
    }

    public void ClearHolds()
    {
        if (State.Phase != VideoPokerPhase.Holding) return;
        State.HeldSlots = new bool[5];
        NotifyStateChanged();
    }

    public void BetMax()
    {
        if (State.Phase == VideoPokerPhase.Holding) return;
        State.CurrentBet = Math.Min(5, Math.Max(1, State.SessionCredits));
        _preferredBet = State.CurrentBet;
        Deal();
    }

    public void IncreaseBet()
    {
        if (State.Phase == VideoPokerPhase.Holding) return;
        State.CurrentBet = Math.Min(5, State.CurrentBet + 1);
        _preferredBet = State.CurrentBet;
        NotifyStateChanged();
    }

    public void DecreaseBet()
    {
        if (State.Phase == VideoPokerPhase.Holding) return;
        State.CurrentBet = Math.Max(1, State.CurrentBet - 1);
        _preferredBet = State.CurrentBet;
        NotifyStateChanged();
    }

    public void Rebuy()
    {
        State.SessionCredits += Options.StartingCredits;
        if (State.SessionCredits >= _preferredBet) State.CurrentBet = _preferredBet;
        Stats.Rebuys++;
        SaveStatistics();
        NotifyStateChanged();
    }

    public void SetVariant(VideoPokerVariant variant)
    {
        Options.Variant = variant;
        SaveOptions();
        // Only clears the current hand's on-screen display — matches Mac's
        // resetHandDisplay(), which deliberately never touches sessionCredits. A variant
        // switch shouldn't reset the player's balance back to the starting amount.
        ResetHandDisplay();
    }

    // Clears the current hand's on-screen state (cards, holds, payout, banner) without
    // touching credits, bet, or hands-played.
    private void ResetHandDisplay()
    {
        State.Phase           = VideoPokerPhase.Deal;
        State.Hand             = new List<Card>();
        State.HeldSlots         = new bool[5];
        State.WinningCardMask   = new bool[5];
        State.LastPayout        = 0;
        State.LastHandName      = "";
        State.ResultBannerShown = false;
        NotifyStateChanged();
    }

    // Clears a finished hand's win/no-win display before the game becomes visible
    // again, so switching away while its result banner is still up and back doesn't
    // replay it — MainWindow recreates VideoPokerView on every game switch, so it has
    // no memory of already having shown the banner. Credits/bet are untouched.
    public void ResetIfRoundOver()
    {
        if (State.Phase != VideoPokerPhase.Result) return;
        ResetHandDisplay();
    }

    public void StartNewGame()
    {
        _sessionHandsPlayed = 0;
        _preferredBet = Math.Clamp(Options.BetPerHand, 1, 5);
        State = new VideoPokerState
        {
            SessionCredits = Options.StartingCredits,
            CurrentBet     = _preferredBet,
        };
        NotifyStateChanged();
    }

    // ── Hand evaluation ───────────────────────────────────────────────────────

    public (VideoPokerPayEntry? Entry, int Payout) EvaluateHand(Card[] hand)
    {
        bool isDeucesWild = Options.Variant == VideoPokerVariant.DeucesWild;
        int wildCount     = isDeucesWild ? hand.Count(c => c.Rank == 2) : 0;
        bool usedWild     = wildCount > 0;

        // Four Deuces is a special named hand — detect before normal ranking
        if (isDeucesWild && wildCount == 4)
        {
            var fdEntry = CurrentTable.FirstOrDefault(e => e.Qualifier == VideoPokerQualifier.FourDeuces);
            if (fdEntry != null) return (fdEntry, fdEntry.Payout(State.CurrentBet));
        }

        PokerHandResult result = wildCount > 0
            ? EvaluateWithWilds(hand, wildCount)
            : PokerHandEvaluator.Evaluate(hand);

        foreach (var entry in CurrentTable)
        {
            if (result.Rank != entry.Rank) continue;
            if (!QualifierMatches(entry.Qualifier, result, wildCount, usedWild)) continue;
            return (entry, entry.Payout(State.CurrentBet));
        }
        return (null, 0);
    }

    private bool QualifierMatches(
        VideoPokerQualifier q, PokerHandResult result, int wildCount, bool usedWild) => q switch
    {
        VideoPokerQualifier.None          => true,
        VideoPokerQualifier.NoWild        => !usedWild,
        VideoPokerQualifier.RequiresWild  => usedWild,
        VideoPokerQualifier.FourDeuces    => wildCount == 4,
        VideoPokerQualifier.JacksOrBetter => result.PairRank >= 11 || result.PairRank == 1,
        VideoPokerQualifier.BonusAces     => result.QuadRank == 1,
        VideoPokerQualifier.Bonus234s     => result.QuadRank is >= 2 and <= 4,
        _                                 => true,
    };

    // Brute-force best wild substitution using virtual (rank,suit) cards.
    // Duplicate rank picks are allowed so FiveOfAKind is reachable.
    private static PokerHandResult EvaluateWithWilds(Card[] hand, int wildCount)
    {
        var naturals = hand.Where(c => c.Rank != 2).ToArray();

        var subs = (
            from rank in Enumerable.Range(1, 13)
            from suit in Enum.GetValues<CardSuit>()
            select new Card($"v_{rank}_{suit}", suit, rank, true)
        ).ToArray(); // 52 virtual substitutes

        PokerHandResult best = new(PokerHandRank.HighCard);

        void TryUpdate(PokerHandResult r)
        {
            if (r.Rank > best.Rank ||
               (r.Rank == best.Rank && r.QuadRank > best.QuadRank))
                best = r;
        }

        if (wildCount == 1)
        {
            foreach (var s in subs)
                TryUpdate(PokerHandEvaluator.Evaluate(naturals.Append(s).ToArray()));
        }
        else if (wildCount == 2)
        {
            for (int i = 0; i < subs.Length; i++)
            for (int j = 0; j < subs.Length; j++)
            {
                if (i == j) continue;
                TryUpdate(PokerHandEvaluator.Evaluate(
                    naturals.Concat(new[] { subs[i], subs[j] }).ToArray()));
            }
        }
        else if (wildCount == 3)
        {
            for (int i = 0; i < subs.Length; i++)
            for (int j = 0; j < subs.Length; j++)
            {
                if (j == i) continue;
                for (int k = 0; k < subs.Length; k++)
                {
                    if (k == i || k == j) continue;
                    TryUpdate(PokerHandEvaluator.Evaluate(
                        naturals.Concat(new[] { subs[i], subs[j], subs[k] }).ToArray()));
                }
            }
        }
        else if (wildCount == 4)
        {
            // Not currently reachable in live play — EvaluateHand's caller intercepts
            // wildCount == 4 for the "Four Deuces" named hand before calling here — but
            // this must still substitute all 4 wilds (not fall through to the 3-wild
            // branch above), which previously produced a 4-card hand that
            // PokerHandEvaluator.Evaluate silently scored as HighCard.
            for (int i = 0; i < subs.Length; i++)
            for (int j = 0; j < subs.Length; j++)
            {
                if (j == i) continue;
                for (int k = 0; k < subs.Length; k++)
                {
                    if (k == i || k == j) continue;
                    for (int l = 0; l < subs.Length; l++)
                    {
                        if (l == i || l == j || l == k) continue;
                        TryUpdate(PokerHandEvaluator.Evaluate(
                            naturals.Concat(new[] { subs[i], subs[j], subs[k], subs[l] }).ToArray()));
                    }
                }
            }
        }

        return best;
    }

    // ── Deck ──────────────────────────────────────────────────────────────────

    private void BuildAndShuffleDeck()
    {
        _deck = (from suit in Enum.GetValues<CardSuit>()
                 from rank in Enumerable.Range(1, 13)
                 select new Card($"{suit}_{rank}", suit, rank, false)).ToList();

        var rng = new Random();
        for (int i = _deck.Count - 1; i > 0; i--)
        {
            int j = rng.Next(i + 1);
            (_deck[i], _deck[j]) = (_deck[j], _deck[i]);
        }
    }

    // ── Persistence ───────────────────────────────────────────────────────────

    private static readonly string DataDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SoliBee");

    private static readonly string OptionsPath    = Path.Combine(DataDir, "videopoker_options.json");
    private static readonly string StatisticsPath = Path.Combine(DataDir, "videopoker_stats.json");

    public void SaveOptions()
    {
        try
        {
            Directory.CreateDirectory(DataDir);
            File.WriteAllText(OptionsPath,
                JsonSerializer.Serialize(Options, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { }
        // Options is the same live instance Preferences edits directly (single consumer,
        // no cross-ViewModel broadcast needed) — notify so the view refreshes immediately.
        OnPropertyChanged(nameof(Options));
        OnPropertyChanged(nameof(IsBetBoardVisible));
    }

    private static VideoPokerOptions LoadOptions()
    {
        try
        {
            if (File.Exists(OptionsPath))
            {
                var o = JsonSerializer.Deserialize<VideoPokerOptions>(File.ReadAllText(OptionsPath));
                if (o != null) return o;
            }
        }
        catch { }
        return new VideoPokerOptions();
    }

    private void SaveStatistics()
    {
        try
        {
            Directory.CreateDirectory(DataDir);
            File.WriteAllText(StatisticsPath,
                JsonSerializer.Serialize(Stats, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { }
    }

    public void ResetStats()
    {
        Stats = new VideoPokerStatistics();
        SaveStatistics();
    }

    private static VideoPokerStatistics LoadStatistics()
    {
        try
        {
            if (File.Exists(StatisticsPath))
            {
                var s = JsonSerializer.Deserialize<VideoPokerStatistics>(File.ReadAllText(StatisticsPath));
                if (s != null) return s;
            }
        }
        catch { }
        return new VideoPokerStatistics();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static bool[] GetWinningCardMask(List<Card> hand, PokerHandRank rank, bool isDeucesWild)
    {
        var mask = new bool[5];
        var h    = hand.ToArray();

        // When wilds are involved, trace-back is ambiguous — light all cards
        if (isDeucesWild && h.Any(c => c.Rank == 2))
        {
            for (int i = 0; i < 5; i++) mask[i] = true;
            return mask;
        }

        switch (rank)
        {
            case PokerHandRank.RoyalFlush:
            case PokerHandRank.StraightFlush:
            case PokerHandRank.Straight:
            case PokerHandRank.Flush:
            case PokerHandRank.FullHouse:
            case PokerHandRank.FiveOfAKind:
                for (int i = 0; i < 5; i++) mask[i] = true;
                break;

            case PokerHandRank.FourOfAKind:
            {
                int r = h.GroupBy(c => c.Rank).First(g => g.Count() == 4).Key;
                for (int i = 0; i < 5; i++) mask[i] = h[i].Rank == r;
                break;
            }
            case PokerHandRank.ThreeOfAKind:
            {
                int r = h.GroupBy(c => c.Rank).First(g => g.Count() == 3).Key;
                for (int i = 0; i < 5; i++) mask[i] = h[i].Rank == r;
                break;
            }
            case PokerHandRank.TwoPair:
            {
                var pairs = h.GroupBy(c => c.Rank).Where(g => g.Count() == 2).Select(g => g.Key).ToHashSet();
                for (int i = 0; i < 5; i++) mask[i] = pairs.Contains(h[i].Rank);
                break;
            }
            case PokerHandRank.OnePair:
            {
                int r = h.GroupBy(c => c.Rank).First(g => g.Count() == 2).Key;
                for (int i = 0; i < 5; i++) mask[i] = h[i].Rank == r;
                break;
            }
        }
        return mask;
    }

    private void NotifyStateChanged()
    {
        OnPropertyChanged(nameof(State));
        OnPropertyChanged(nameof(ScoreDisplay));
        OnPropertyChanged(nameof(CreditDisplay));
        OnPropertyChanged(nameof(BetDisplay));
        OnPropertyChanged(nameof(HandsDisplay));
        OnPropertyChanged(nameof(ResultText));
        OnPropertyChanged(nameof(HasWin));
        OnPropertyChanged(nameof(ShowNoWin));
        OnPropertyChanged(nameof(IsDealing));
        OnPropertyChanged(nameof(IsHolding));
        OnPropertyChanged(nameof(CanDeal));
        OnPropertyChanged(nameof(NeedsRebuy));
        OnPropertyChanged(nameof(DealDrawLabel));
        OnPropertyChanged(nameof(WinningHandName));
        OnPropertyChanged(nameof(Stats));
    }
}
