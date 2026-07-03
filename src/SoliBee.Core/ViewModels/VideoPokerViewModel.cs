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

    private List<Card> _deck = new();

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
    public string ResultText      => State.Phase == VideoPokerPhase.Result && State.LastPayout > 0
                                        ? $"★  {State.LastHandName}  +{State.LastPayout}  ★"
                                        : "";
    public bool   HasWin          => State.Phase == VideoPokerPhase.Result && State.LastPayout > 0;
    public bool   ShowNoWin       => State.Phase == VideoPokerPhase.Result && State.LastPayout == 0 && State.Hand.Count > 0;
    public bool   CanUndo         => false;
    public bool   IsDealing       => State.Phase == VideoPokerPhase.Deal || State.Phase == VideoPokerPhase.Result;
    public bool   IsHolding       => State.Phase == VideoPokerPhase.Holding;
    public bool   NeedsRebuy      => State.SessionCredits < State.CurrentBet;
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
        State.CurrentBet     = Math.Clamp(Options.BetPerHand, 1, 5);

        // Sync shared visual settings from global options at startup
        var shared = SettingsService.LoadOptions();
        Options.IsFinalFantasyMode  = shared.IsFinalFantasyMode;
        Options.CardBackTheme       = shared.CardBackTheme;
        Options.IsSoundEnabled      = shared.IsSoundEnabled;
        Options.FeltColor           = shared.FeltColor.ToString();
        Options.CustomFeltColorHex  = shared.CustomFeltColorHex;
        Options.IsVignetteEnabled   = shared.IsVignetteEnabled;

        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (_, m) =>
        {
            Options.IsFinalFantasyMode  = m.Options.IsFinalFantasyMode;
            Options.CardBackTheme       = m.Options.CardBackTheme;
            Options.IsSoundEnabled      = m.Options.IsSoundEnabled;
            Options.FeltColor           = m.Options.FeltColor.ToString();
            Options.CustomFeltColorHex  = m.Options.CustomFeltColorHex;
            Options.IsVignetteEnabled   = m.Options.IsVignetteEnabled;
            OnPropertyChanged(nameof(Options));
        });
    }

    // ── Game actions ──────────────────────────────────────────────────────────

    public void Deal()
    {
        if (State.SessionCredits < State.CurrentBet) return;
        State.SessionCredits  -= State.CurrentBet;
        State.HeldSlots        = new bool[5];
        State.WinningCardMask  = new bool[5];
        State.Phase            = VideoPokerPhase.Holding;

        BuildAndShuffleDeck();
        State.Hand = _deck.Take(5).Select(c => c with { IsFaceUp = true }).ToList();
        _deck = _deck.Skip(5).ToList();

        Stats.TotalHands++;
        Stats.TotalCreditsWagered += State.CurrentBet;

        NotifyStateChanged();
    }

    public void Draw()
    {
        if (State.Phase != VideoPokerPhase.Holding) return;

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
        State.SessionCredits += payout;
        State.WinningCardMask = payout > 0
            ? GetWinningCardMask(State.Hand, entry!.Rank, Options.Variant == VideoPokerVariant.DeucesWild)
            : new bool[5];
        State.Phase           = VideoPokerPhase.Result;

        if (payout > 0)
        {
            Stats.WinningHands++;
            Stats.TotalCreditsWon += payout;
            var key = entry!.HandName;
            Stats.HandCounts[key] = Stats.HandCounts.GetValueOrDefault(key) + 1;
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
        Deal();
    }

    public void IncreaseBet()
    {
        if (State.Phase == VideoPokerPhase.Holding) return;
        State.CurrentBet = Math.Min(5, State.CurrentBet + 1);
        NotifyStateChanged();
    }

    public void DecreaseBet()
    {
        if (State.Phase == VideoPokerPhase.Holding) return;
        State.CurrentBet = Math.Max(1, State.CurrentBet - 1);
        NotifyStateChanged();
    }

    public void Rebuy()
    {
        State.SessionCredits += Options.StartingCredits;
        NotifyStateChanged();
    }

    public void SetVariant(VideoPokerVariant variant)
    {
        Options.Variant = variant;
        SaveOptions();
        StartNewGame();
    }

    public void StartNewGame()
    {
        State = new VideoPokerState
        {
            SessionCredits = Options.StartingCredits,
            CurrentBet     = Math.Clamp(Options.BetPerHand, 1, 5),
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
        else // wildCount == 3
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
        OnPropertyChanged(nameof(ResultText));
        OnPropertyChanged(nameof(HasWin));
        OnPropertyChanged(nameof(ShowNoWin));
        OnPropertyChanged(nameof(IsDealing));
        OnPropertyChanged(nameof(IsHolding));
        OnPropertyChanged(nameof(NeedsRebuy));
        OnPropertyChanged(nameof(DealDrawLabel));
        OnPropertyChanged(nameof(WinningHandName));
        OnPropertyChanged(nameof(Stats));
    }
}
