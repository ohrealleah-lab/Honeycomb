using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

public record HoneycombPendingSteal(int BoardIndex, string CardName);

public partial class HoneycombViewModel : ObservableObject
{
    [ObservableProperty] private HoneycombState _state = new();
    [ObservableProperty] private HoneycombOptions _options = new();
    [ObservableProperty] private HoneycombStats _stats = new();

    private static int s_consecutiveStarters = 0;
    private static int s_lastStarter = 0;

    private bool _isAnimating = false;
    private bool _isHeadless = false;
    private int _matchGeneration = 0;

    // Rematch snapshot: freeze the opponent's card pool (pre-Swap) + this match's rules
    // — this becomes the baseline every future RematchGame() replays, until the next
    // real StartNewMatch() rolls a fresh one. Freezing the pool (not a resolved/swapped
    // hand) lets each rematch roll its own independent Swap trade against the same
    // cards — a different pairing each time, same underlying deck.
    private List<HoneycombCardData>? _rematchOpponentDeck;
    private List<HoneycombRule> _rematchActiveRules = new();
    private List<string> _rematchAscensionDescensionSuits = new();

    [ObservableProperty] private HoneycombPendingSteal? _pendingSteal;

    public (int handIndex, int cellIndex)? ActiveHint { get; private set; }
    
    public bool IsPlaying => State.Phase == HoneycombPhase.Playing;
    public bool CanUndo => State.UndoStack.Count > 0 && IsPlaying && State.CurrentTurn == 1 && !_isAnimating;

    // Flat properties mirroring State.PlayerScore/OpponentScore, with their own
    // explicit OnPropertyChanged in NotifyStateChanged — the toolbar's nested
    // "State.PlayerScore" binding wasn't refreshing on every move like the
    // solitaire toolbar's flat ScoreDisplay/TimeDisplay properties do.
    public int PlayerScoreDisplay => State.PlayerScore;
    public int OpponentScoreDisplay => State.OpponentScore;

    // The toolbar's "Opponent" label reads the opponent's actual difficulty name (e.g.
    // "Baby Bee") instead of the literal word "Opponent" — matches the Swift port.
    public string OpponentNameDisplay => Options.Difficulty.DisplayName();
    
    public event Action<string>? OnFlashBanner;

    // FIFO queue of banner texts — mirrors the Swift port's bannerQueue/enqueueBanner/
    // advanceBannerQueue (shared/Honeycomb/ViewModels/HoneycombViewModel.swift).
    // Without this, a second banner firing moments after an earlier one (e.g. a Bomb
    // Shelter reveal a beat after an ordinary placement's own capture) would silently
    // overwrite it via OnFlashBanner before it had been on screen long enough to read.
    private readonly Queue<string> _bannerQueue = new();

    private void EnqueueBanner(string text)
    {
        _bannerQueue.Enqueue(text);
        // Only fire OnFlashBanner when this becomes the front of the queue — if
        // something is already showing, the view picks this one up on its own via
        // AdvanceBannerQueue once the current banner's dismiss timer fires, instead of
        // interrupting it.
        if (_bannerQueue.Count == 1)
        {
            OnFlashBanner?.Invoke(text);
        }
    }

    // Called by the view once the currently-shown banner's own dismiss timer/fade
    // completes, revealing whatever's queued behind it.
    public void AdvanceBannerQueue()
    {
        if (_bannerQueue.Count == 0) return;
        _bannerQueue.Dequeue();
        if (_bannerQueue.Count > 0)
        {
            OnFlashBanner?.Invoke(_bannerQueue.Peek());
        }
    }

    private void ClearBannerQueue()
    {
        _bannerQueue.Clear();
    }

    public HoneycombViewModel(bool isHeadless = false)
    {
        _isHeadless = isHeadless;
        Options = SettingsService.LoadHoneycombOptions();
        Stats = LoadStats();
        
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (_, m) =>
        {
            Options = SettingsService.LoadHoneycombOptions();
            NotifyStateChanged();
        });
    }

    // Bad-luck protection for Roulette: a plain independent roll can land on the exact
    // same result (same rule set AND same Ascension/Descension suit) several matches in
    // a row, which reads as "broken" even though it's just an unlucky draw. Re-rolling
    // whenever a draw exactly repeats the previous match's result — up to a small retry
    // cap, so a heavily-restricted pool (few unbanned rules) can't loop forever — makes
    // back-to-back identical rolls impossible without meaningfully changing each rule's
    // long-run odds.
    private string? _lastRouletteSignature;
    private const int MaxRouletteRerolls = 5;

    private static string RouletteSignature(List<HoneycombRule> rules, List<string> suits)
    {
        var ruleNames = string.Join(",", rules.Select(r => r.ToString()).OrderBy(s => s));
        var suitNames = string.Join(",", suits.OrderBy(s => s));
        return $"{ruleNames}|{suitNames}";
    }

    private List<HoneycombRule> DetermineActiveRules()
    {
        if (Options.ForceNormalRules) return new List<HoneycombRule>();

        if (Options.ManualRules != null && Options.ManualRules.Count > 0)
        {
            return Options.ManualRules.ToList();
        }

        var pool = Enum.GetValues<HoneycombRule>().ToList();
        
        // Remove banned rules from pool
        if (Options.BannedRules != null)
        {
            pool.RemoveAll(r => Options.BannedRules.Contains(r.ToString()));
        }
        
        
        if (Options.Difficulty == HoneycombDifficulty.Easy)
        {
            pool.Remove(HoneycombRule.Ascension);
            pool.Remove(HoneycombRule.Descension);
            pool.Remove(HoneycombRule.FallenAce);
        }

        // If Normal Mode is banned, force at least 1 rule
        bool normalBanned = Options.BannedRules != null && Options.BannedRules.Contains("Normal Mode");

        // "Stop here" is a flat probability at EVERY draw, fully decoupled from how
        // much exclusivity has shrunk the pool (an earlier scaled-stopWeight attempt
        // inflated "stop" after big exclusivity removals and made solo-rule odds
        // WORSE, not better — see git history). Draw 1 uses 1/(originalPoolSize+1) so
        // Normal stays roughly as rare as any single rule (~7.7% for the default
        // 12-rule pool). Draw 2 uses a distinct, deliberately solved probability so
        // that "exactly one rule" lands at a full 1/3 overall, rather than being
        // capped near Normal's rate: with a single shared stop-probability p,
        // P(exactly 1 rule) = (1-p)*p can never exceed p, so Normal necessarily
        // out-paced single-rule matches. Solving
        // (1 - stopProbabilityFirst) * stopProbabilitySecond = 1/3 removes that
        // ceiling while leaving Normal's rate untouched.
        int originalPoolSize = pool.Count;
        double stopProbabilityFirst = 1.0 / (originalPoolSize + 1);
        double targetSingleRuleRate = 1.0 / 3.0;
        double stopProbabilitySecond = targetSingleRuleRate / (1.0 - stopProbabilityFirst);
        
        int maxSlots = 2;
        bool forceMustPickAll = false;
        
        if (Options.Difficulty == HoneycombDifficulty.UltraHard)
        {
            double roll = Random.Shared.NextDouble();
            if (roll < 0.25) maxSlots = 4;
            else if (roll < 0.70) maxSlots = 3;
            else if (roll < 0.95) maxSlots = 2;
            else if (roll < 0.99) maxSlots = 1;
            else maxSlots = 0;
            
            if (maxSlots == 0 && normalBanned) maxSlots = 1;
            forceMustPickAll = true;
        }
        else if (Options.Difficulty == HoneycombDifficulty.Hard)
        {
            double hardRoll = Random.Shared.NextDouble();
            if (hardRoll < 0.01)
            {
                maxSlots = 4;
                forceMustPickAll = true;
            }
            else if (hardRoll < 0.26)
            {
                maxSlots = 3;
                forceMustPickAll = true;
            }
        }
        
        var selected = new List<HoneycombRule>();
        for (int slot = 0; slot < maxSlots; slot++)
        {
            if (pool.Count == 0) break;

            bool mustPick = (slot == 0 && normalBanned) || forceMustPickAll;
            double stopProbability = slot == 0 ? stopProbabilityFirst : stopProbabilitySecond;
            if (!mustPick && Random.Shared.NextDouble() < stopProbability) break;

            var r = WeightedRandomRule(pool);
            selected.Add(r);
            pool.Remove(r);

            if (r == HoneycombRule.Ascension) pool.Remove(HoneycombRule.Descension);
            else if (r == HoneycombRule.Descension) pool.Remove(HoneycombRule.Ascension);
            else if (r == HoneycombRule.Order) pool.Remove(HoneycombRule.Chaos);
            else if (r == HoneycombRule.Chaos) pool.Remove(HoneycombRule.Order);
            // Bomb Shelter's hidden card doesn't work when All Open/Three Open reveals
            // every card anyway, so they're mutually exclusive in both directions.
            else if (r == HoneycombRule.AllOpen) { pool.Remove(HoneycombRule.ThreeOpen); pool.Remove(HoneycombRule.BombShelter); }
            else if (r == HoneycombRule.ThreeOpen) { pool.Remove(HoneycombRule.AllOpen); pool.Remove(HoneycombRule.BombShelter); }
            else if (r == HoneycombRule.BombShelter) { pool.Remove(HoneycombRule.AllOpen); pool.Remove(HoneycombRule.ThreeOpen); }
        }
        return selected;
    }

    // Weighted draw from `pool` using each rule's HoneycombRuleWeights.Weight() — every
    // weight is a positive int and callers only invoke this on a non-empty pool
    // (guarded above), so totalWeight is always > 0 and Random.Shared.Next(totalWeight)
    // can't throw. The trailing fallback is unreachable (the loop always finds a rule
    // before randomValue can go negative past the last element) but keeps this total.
    private static HoneycombRule WeightedRandomRule(List<HoneycombRule> pool)
    {
        int totalWeight = pool.Sum(r => r.Weight());
        int randomValue = Random.Shared.Next(totalWeight);
        foreach (var rule in pool)
        {
            randomValue -= rule.Weight();
            if (randomValue < 0) return rule;
        }
        return pool[^1];
    }

    public void StartNewMatch()
    {
        _isAnimating = false;
        ActiveHint = null;
        PendingSteal = null;
        State.Phase = HoneycombPhase.Playing;
        State.UndoStack.Clear();
        State.HasStolenThisMatch = false;
        State.CardsCapturedThisMatch = 0;
        State.IsSuddenDeath = false;
        State.ShowPostGamePrompt = false;

        // Roulette (no forced/manual rules) gets bad-luck protection against repeating
        // the exact same rule set + suit as last match; forced/manual rules are
        // deterministic already, so there's nothing to protect against.
        bool isRoulette = !Options.ForceNormalRules && (Options.ManualRules == null || Options.ManualRules.Count == 0);

        List<HoneycombRule> rules = new();
        List<string> suits = new();
        for (int attempt = 0; attempt < MaxRouletteRerolls; attempt++)
        {
            rules = DetermineActiveRules();
            suits = (rules.Contains(HoneycombRule.Ascension) || rules.Contains(HoneycombRule.Descension))
                ? new[] { "S", "H", "D", "C" }.OrderBy(x => Random.Shared.Next()).Take(1).ToList()
                : new List<string>();

            if (!isRoulette || RouletteSignature(rules, suits) != _lastRouletteSignature) break;
            // Otherwise keep re-rolling; the loop's final attempt is accepted
            // unconditionally rather than looping forever.
        }

        State.ActiveRules = rules;
        if (isRoulette) _lastRouletteSignature = RouletteSignature(rules, suits);

        State.Board = new HoneycombBoard();
        State.Board.AscensionDescensionSuits = suits;

        State.PlayerHand = BuildPlayerHand();
        State.PlayerStartingDeck = State.PlayerHand.Select(c => c.Clone()).ToList();

        var deck = RollOpponentDeck();
        // Freeze the opponent's card pool (pre-Swap) + this match's rules — this
        // becomes the baseline every future RematchGame() replays, until the next real
        // StartNewMatch() rolls a fresh one.
        _rematchOpponentDeck = deck;
        _rematchActiveRules = new List<HoneycombRule>(State.ActiveRules);
        _rematchAscensionDescensionSuits = new List<string>(State.Board.AscensionDescensionSuits);

        var swapIds = ApplyOpponentDeck(deck);
        FinishMatchSetup(swapIds);
    }

    // Display text for one active rule in the "First Move" banner: just the (spaced)
    // rule name, except Ascension/Descension which also name the affected suit(s) —
    // e.g. "Swap", "Ascension: Hearts". No trailing punctuation; the banner's own "!"
    // belongs only after "First Move: Player/Opponent".
    private string FormatRuleForBanner(HoneycombRule rule)
    {
        var name = rule.DisplayName();
        if (rule == HoneycombRule.Ascension || rule == HoneycombRule.Descension)
        {
            var suitNames = State.Board.AscensionDescensionSuits.Select(HoneycombCardData.SuitDisplayName);
            return $"{name}: {string.Join(", ", suitNames)}";
        }
        return name;
    }

    private List<HoneycombCard> BuildPlayerHand()
    {
        var globalOpts = SettingsService.LoadOptions();
        List<int> playerIds;
        if (globalOpts.IsNoStressMode)
        {
            playerIds = new List<int>();
            playerIds.AddRange(HoneycombDatabase.Shared.RandomCards(5, 1).Select(c => c.Id));
            playerIds.AddRange(HoneycombDatabase.Shared.RandomCards(4, 1).Select(c => c.Id));
            playerIds.AddRange(HoneycombDatabase.Shared.RandomCards(3, 3).Select(c => c.Id));
        }
        else
        {
            int deckIdx = globalOpts.HoneycombActiveDeckIndex;
            var decks = HoneycombProfileManager.Shared.SavedDecks;
            if (deckIdx >= 0 && deckIdx < decks.Count && decks[deckIdx].CardIds.Count == 5)
                playerIds = decks[deckIdx].CardIds.ToList();
            else
                playerIds = HoneycombProfileManager.ComputeStartOverDeck(null);
        }
        return playerIds.Select(id => new HoneycombCard(HoneycombDatabase.Shared.Card(id)!, 1)).ToList();
    }

    // Rolls a brand-new opponent card pool for a genuinely-new match. Only called from
    // StartNewMatch() — RematchGame() reuses the frozen pool from _rematchOpponentDeck
    // instead, via ApplyOpponentDeck(), so repeated rematches keep facing the same
    // underlying 5 cards.
    private List<HoneycombCardData> RollOpponentDeck()
    {
        bool reverse = State.ActiveRules.Contains(HoneycombRule.Reverse);
        var comp = new List<(int stars, int count)>();
        if (!reverse)
        {
            if (Options.Difficulty == HoneycombDifficulty.Easy) { comp.Add((1, 4)); comp.Add((2, 1)); }
            else if (Options.Difficulty == HoneycombDifficulty.Medium)
            {
                comp.Add((2, 4));
                // Honey Bee: a 20% chance of a 4★ card instead of the usual 3★, so its
                // deck isn't entirely predictable at this difficulty.
                comp.Add(Random.Shared.NextDouble() < 0.2 ? (4, 1) : (3, 1));
            }
            else if (Options.Difficulty == HoneycombDifficulty.Hard) { comp.Add((3, 3)); comp.Add((4, 1)); comp.Add((5, 1)); }
            else { comp.Add((3, 2)); comp.Add((4, 1)); comp.Add((5, 2)); }
        }
        else
        {
            if (Options.Difficulty == HoneycombDifficulty.Easy) { comp.Add((3, 3)); comp.Add((4, 1)); comp.Add((5, 1)); }
            else if (Options.Difficulty == HoneycombDifficulty.Medium)
            {
                comp.Add((2, 4));
                // Honey Bee: a 20% chance of a 4★ card instead of the usual 3★, so its
                // deck isn't entirely predictable at this difficulty.
                comp.Add(Random.Shared.NextDouble() < 0.2 ? (4, 1) : (3, 1));
            }
            else if (Options.Difficulty == HoneycombDifficulty.Hard) { comp.Add((1, 2)); comp.Add((2, 3)); }
            else { comp.Add((1, 5)); }
        }

        var deck = new List<HoneycombCardData>();
        foreach (var (stars, count) in comp)
        {
            deck.AddRange(HoneycombDatabase.Shared.RulesAwareCards(stars, count, reverse));
        }

        // Composition always assembles in the same fixed star-tier order (e.g. Ultra
        // Hard is always [3,3,4,5,5]), which — combined with the Order rule always
        // mandating hand-index 0 — made the AI's entire play sequence 100% predictable
        // every match: a player could always count on 2 weak opens followed by a
        // guaranteed 5-star, 5-star finish. Shuffle unconditionally (not just when
        // Order is active) so tier position never leaks information, regardless of
        // which rules end up active this match.
        deck = deck.OrderBy(_ => Random.Shared.Next()).ToList();

        return EnsureAscensionCoverage(deck);
    }

    // Ultra Hard only: a player can stack their own deck with cards of the rolled
    // Ascension suit(s) to farm the +1-per-suit-card-on-board bonus, while the
    // opponent's deck is otherwise assembled with no awareness of which suits are
    // even in play. Guarantees at least 3 of the opponent's 5 cards match an active
    // Ascension suit so the AI can benefit from the same bonus the player is
    // exploiting, rather than the player getting the mode's biggest lever for free.
    // Descension is deliberately left alone — it's a penalty, so forcing more
    // Descension-suited cards into the AI's hand would only hurt it, not balance
    // anything. Mirrors the Swift port's ensureAscensionCoverage
    // (shared/Honeycomb/ViewModels/HoneycombViewModel.swift).
    private List<HoneycombCardData> EnsureAscensionCoverage(List<HoneycombCardData> deck)
    {
        var suits = State.Board.AscensionDescensionSuits;
        if (Options.Difficulty != HoneycombDifficulty.UltraHard ||
            !State.ActiveRules.Contains(HoneycombRule.Ascension) ||
            suits.Count == 0)
        {
            return deck;
        }

        var result = new List<HoneycombCardData>(deck);
        int matchingCount = result.Count(c => suits.Contains(c.Suit));
        if (matchingCount >= 3) return result;

        var db = HoneycombDatabase.Shared;
        // Swap the deck's lowest-star non-matching cards first, so the deck's overall
        // power level (its highest-star cards) stays intact where possible.
        var nonMatchingIndices = Enumerable.Range(0, result.Count)
            .Where(i => !suits.Contains(result[i].Suit))
            .OrderBy(i => result[i].Stars)
            .ToList();

        foreach (var idx in nonMatchingIndices)
        {
            if (matchingCount >= 3) break;

            int tier = result[idx].Stars;
            var usedIds = new HashSet<int>(result.Select(c => c.Id));
            var candidates = db.AllCards.Where(c => c.Stars == tier && suits.Contains(c.Suit) && !usedIds.Contains(c.Id)).ToList();
            if (candidates.Count == 0) continue;

            result[idx] = candidates[Random.Shared.Next(candidates.Count)];
            matchingCount++;
        }

        return result;
    }

    // A computed-but-not-yet-applied Swap trade. FinishMatchSetup stages this instead
    // of applying it immediately: highlight the two real cards first, wait for the
    // "First Move" banner to fully clear, then flip them into their swapped homes —
    // rather than the trade having silently already happened by the very first frame.
    private readonly record struct PendingSwap(
        Guid PlayerCardId, Guid OpponentCardId, int PlayerIndex, int OpponentIndex,
        HoneycombCard PlayerCard, HoneycombCard OpponentCard);

    // Purely computes the trade — PlayerHand/OpponentHand aren't touched here; see
    // ApplySwap for when it's actually applied.
    private PendingSwap? ComputeSwapIfNeeded()
    {
        if (!State.ActiveRules.Contains(HoneycombRule.Swap) || State.PlayerHand.Count == 0 || State.OpponentHand.Count == 0)
            return null;

        int pIdx = Random.Shared.Next(State.PlayerHand.Count);
        int oIdx = Random.Shared.Next(State.OpponentHand.Count);
        var pCard = State.PlayerHand[pIdx];
        var oCard = State.OpponentHand[oIdx];

        // Identity-preserving trade: pCard/oCard keep their UniqueInstanceId wherever
        // they end up, so the highlight (and later the flip animation) can track them
        // as the same two cards relocating, whichever hand currently holds them.
        return new PendingSwap(pCard.UniqueInstanceId, oCard.UniqueInstanceId, pIdx, oIdx, pCard, oCard);
    }

    // Actually performs the trade computed by ComputeSwapIfNeeded — called once the
    // "First Move" banner has cleared (see StageSwapAnimation).
    private void ApplySwap(PendingSwap swap)
    {
        swap.PlayerCard.Owner = -1;
        swap.OpponentCard.Owner = 1;
        State.PlayerHand[swap.PlayerIndex] = swap.OpponentCard;
        State.OpponentHand[swap.OpponentIndex] = swap.PlayerCard;
    }

    // Wires up a given opponent card pool as this match's OpponentHand: rolls a fresh
    // Swap trade (if active) and fresh All Open/Three Open reveal picks against it.
    // Shared by StartNewMatch() (a newly-rolled pool) and RematchGame() (the frozen
    // pool from the last genuinely-new match) — either way, this is what makes each
    // call a fresh roll of who trades with whom and what gets revealed. Returns the
    // pending swap (not yet applied) if a Swap trade would happen.
    private PendingSwap? ApplyOpponentDeck(List<HoneycombCardData> deck)
    {
        State.OpponentHand = deck.Select(d => new HoneycombCard(d, -1)).ToList();

        State.PlayerRevealedIds.Clear();
        State.OpponentRevealedIds.Clear();

        // Swap is resolved (but not applied — see ApplySwap) before the All Open/Three
        // Open reveal below, so that reveal picks from the hands as they'll actually
        // look once the trade lands — not from the pre-swap hands, which could pick a
        // card that's about to be traded away and leave the card that trades in
        // undiscovered (and, with Three Open, silently short a hand to 2 visible cards
        // instead of 3).
        var swap = ComputeSwapIfNeeded();

        var eventualOpponentIds = State.OpponentHand.Select(c => c.UniqueInstanceId).ToList();
        if (swap.HasValue) eventualOpponentIds[swap.Value.OpponentIndex] = swap.Value.PlayerCardId;

        var eventualPlayerIds = State.PlayerHand.Select(c => c.UniqueInstanceId).ToList();
        if (swap.HasValue) eventualPlayerIds[swap.Value.PlayerIndex] = swap.Value.OpponentCardId;

        if (State.ActiveRules.Contains(HoneycombRule.AllOpen))
        {
            foreach (var id in eventualOpponentIds) State.OpponentRevealedIds.Add(id);
            foreach (var id in eventualPlayerIds) State.PlayerRevealedIds.Add(id);
        }
        else if (State.ActiveRules.Contains(HoneycombRule.ThreeOpen))
        {
            foreach (var id in eventualOpponentIds.OrderBy(_ => Random.Shared.Next()).Take(3)) State.OpponentRevealedIds.Add(id);
            foreach (var id in eventualPlayerIds.OrderBy(_ => Random.Shared.Next()).Take(3)) State.PlayerRevealedIds.Add(id);
        }

        if (swap.HasValue)
        {
            // Whether each slot ended up visible (All Open, or Three Open's random
            // pick landed on it) — checked BEFORE the unconditional adds below,
            // since those would otherwise always make this true.
            bool opponentSlotVisible = State.OpponentRevealedIds.Contains(swap.Value.PlayerCardId);
            bool playerSlotVisible = State.PlayerRevealedIds.Contains(swap.Value.OpponentCardId);

            // The swapped card always stays visible in its new hand, regardless of whether
            // Three Open's random pick landed on it — the player already knows exactly what
            // it is (it just came from their own hand a moment ago), so there's nothing left
            // to hide, and the AI is in the same position for the card it received.
            State.OpponentRevealedIds.Add(swap.Value.PlayerCardId);
            State.PlayerRevealedIds.Add(swap.Value.OpponentCardId);

            // If a slot is visible, the CURRENT pre-swap card sitting there is
            // visible too for the whole window before the trade actually lands —
            // only its eventual (post-swap) id was registered above, so without
            // this the card about to be swapped away incorrectly rendered as
            // hidden/face-down until the trade completed.
            if (opponentSlotVisible) State.OpponentRevealedIds.Add(swap.Value.OpponentCard.UniqueInstanceId);
            if (playerSlotVisible) State.PlayerRevealedIds.Add(swap.Value.PlayerCard.UniqueInstanceId);
        }

        return swap;
    }

    // Shared tail between StartNewMatch() and RematchGame() — decides who moves first,
    // flashes the opening banner (folding in "Swap!" if this match opened with a
    // trade), stages the swap highlight, and kicks off StartTurn(). `forceAlternateStarter`
    // is passed by RematchGame(): unlike a genuinely new match (a fresh coin toss, just
    // with bad-luck protection against a long same-side streak), a rematch of the same
    // match should always hand the opening move to whoever didn't have it last time, so
    // replaying repeatedly can't keep favoring one side.
    private void FinishMatchSetup(PendingSwap? swap, bool forceAlternateStarter = false)
    {
        State.PlayerChaosIndex = null;
        State.OpponentChaosIndex = null;

        int starter = Random.Shared.Next(2) == 0 ? 1 : -1;
        if (forceAlternateStarter || s_consecutiveStarters >= 3)
        {
            starter = s_lastStarter == 1 ? -1 : 1;
        }

        if (starter == s_lastStarter) s_consecutiveStarters++;
        else
        {
            s_lastStarter = starter;
            s_consecutiveStarters = 1;
        }

        State.CurrentTurn = starter;

        string starterName = starter == 1 ? "Player" : "Opponent";
        // A single combined banner instead of separate flashes at match start — every
        // active rule (up to 2) gets its own line below "First Move", in the same font,
        // rather than only Swap riding along while Ascension/Descension/etc. got their
        // own separate (and immediately-overwritten) flash.
        var bannerLines = new List<string> { $"First Move: {starterName}!" };
        foreach (var rule in State.ActiveRules)
        {
            bannerLines.Add(FormatRuleForBanner(rule));
        }
        // A brand new match starting — any banner still queued from the previous one
        // (e.g. a match ended mid-combo-sequence) is no longer relevant.
        ClearBannerQueue();
        EnqueueBanner(string.Join("\n", bannerLines));

        int generation = ++_matchGeneration;
        if (swap.HasValue)
        {
            // Highlight the two real, not-yet-swapped cards right away, in sync with
            // the "First Move" banner, so the player sees exactly which two are about
            // to trade before anything moves. _isAnimating blocks player input (see
            // PlayCard's guard) and StartTurn's own AI-trigger check below, until
            // ReleaseFirstMoveAfterSwap clears it once the trade has actually landed.
            State.SwapHighlightIds = new HashSet<Guid> { swap.Value.PlayerCardId, swap.Value.OpponentCardId };
            _isAnimating = true;
            StageSwapAnimation(swap.Value, generation);
        }

        StartTurn();

        if (swap.HasValue)
        {
            ReleaseFirstMoveAfterSwap(generation);
        }
    }

    // The initial deal-flip's own total runtime: 10 hand slots (5 player, then 5
    // opponent — see HoneycombView.Refresh, which awaits each slot's RenderCard/
    // PlayRevealAnimation in turn rather than animating them in parallel) x
    // PlayRevealAnimation's ~224ms each (two 7-step loops at 16ms/step).
    private const int DealFlipTotalMs = 2240;
    // Deliberate pause after the deal-flip finishes before the Nectar Exchange trade
    // starts, so the two animations never visually overlap.
    private const int SwapPostDealDelayMs = 500;
    // How long the Nectar Exchange slide itself takes once it starts, matching the
    // Swift port's withAnimation(.easeInOut(duration: 0.9)) — see
    // HoneycombView.PlaySwapSlideAnimation.
    private const int SwapSlideDurationMs = 900;

    // Swap trade's real landing time — the deal-flip's own runtime plus the
    // deliberate post-deal pause (matching StageSwapAnimation's delay below) plus the
    // slide animation's own duration. The first move — player input or the AI's
    // opening move — waits until here instead of stepping on the trade mid-animation.
    // StartTurn() already ran above and skipped its own AI-trigger (blocked by
    // _isAnimating), so this explicitly resumes it once the wait is over — calling
    // RunAITurn(skipPacingDelay: true) rather than stacking its normal 2.5s "thinking"
    // pause on top of this wait.
    private async void ReleaseFirstMoveAfterSwap(int generation)
    {
        if (!_isHeadless) await Task.Delay(DealFlipTotalMs + SwapPostDealDelayMs + SwapSlideDurationMs);
        if (generation != _matchGeneration || !IsPlaying) return;

        _isAnimating = false;
        if (State.CurrentTurn == -1)
        {
            RunAITurn(skipPacingDelay: true);
        }
        else
        {
            NotifyStateChanged();
        }
    }

    // Fires once the trade actually lands (ApplySwap runs), so the view can play a
    // slide animation crossing the two affected hand slots instead of them silently
    // appearing already-swapped. Passes the two pre-swap card objects (their Data
    // never changes, only Owner — ApplySwap already flipped that to each card's new
    // holder) plus the fixed slot indices each ends up occupying, so the view doesn't
    // need to re-derive any of this by searching hand arrays after the fact.
    public event Action<HoneycombCard, HoneycombCard, int, int>? OnSwapLanded;

    // Applies the trade only once the initial deal-flip has fully finished playing out
    // *plus* a deliberate SwapPostDealDelayMs pause — it used to apply instantly at
    // match setup (stepping on the "First Move" banner), then later just matched the
    // banner's own 2.0s runtime, which itself landed mid-deal-flip once the deal-flip
    // animation was added. Keeps the highlight up through the slide animation
    // afterward before clearing it.
    private async void StageSwapAnimation(PendingSwap swap, int generation)
    {
        if (!_isHeadless) await Task.Delay(DealFlipTotalMs + SwapPostDealDelayMs);
        if (generation != _matchGeneration || !IsPlaying) return;

        ApplySwap(swap);
        NotifyStateChanged();
        OnSwapLanded?.Invoke(swap.PlayerCard, swap.OpponentCard, swap.PlayerIndex, swap.OpponentIndex);

        // 50% slower than the original 0.8s post-swap highlight hold.
        if (!_isHeadless) await Task.Delay(1200);
        if (generation != _matchGeneration || !IsPlaying) return;

        State.SwapHighlightIds.Clear();
        NotifyStateChanged();
    }

    private void StartTurn()
    {
        if (!IsPlaying) return;

        ActiveHint = null;

        if (State.ActiveRules.Contains(HoneycombRule.Chaos))
        {
            if (State.CurrentTurn == 1)
                State.PlayerChaosIndex = State.PlayerHand.Count > 0 ? Random.Shared.Next(State.PlayerHand.Count) : null;
            else
                State.OpponentChaosIndex = State.OpponentHand.Count > 0 ? Random.Shared.Next(State.OpponentHand.Count) : null;
        }

        NotifyStateChanged();

        if (State.CurrentTurn == -1 && !_isAnimating)
        {
            RunAITurn();
        }
    }

    private async void RunAITurn(bool skipPacingDelay = false)
    {
        _isAnimating = true;
        NotifyStateChanged();

        if (!_isHeadless && !skipPacingDelay) await Task.Delay(2500); // UI pace beat
        
        if (!IsPlaying || State.CurrentTurn != -1)
        {
            _isAnimating = false;
            NotifyStateChanged();
            return;
        }

        // Identity-based, not a count comparison — PlayerRevealedIds only grows (it never
        // drops an id once a card's been revealed, even after that card is played), so
        // comparing counts against the player's current (shrinking) hand size can go
        // stale and read false once enough revealed cards have been played, even while a
        // never-revealed card is still sitting in hand. Only the visible subset's real
        // data is passed to the search; unrevealed slots are counted but never exposed,
        // then simulated as generic placeholder cards inside HoneycombAI.FindMove — an
        // unintended AI advantage otherwise.
        var visiblePlayerCards = State.PlayerHand.Where(c => State.PlayerRevealedIds.Contains(c.UniqueInstanceId)).ToList();
        int unknownPlayerCardCount = State.PlayerHand.Count - visiblePlayerCards.Count;
        var move = HoneycombAI.FindMove(State.Board, State.OpponentHand, visiblePlayerCards, unknownPlayerCardCount, new HashSet<HoneycombRule>(State.ActiveRules), Options.Difficulty, -1, 1, State.OpponentChaosIndex);
        if (move.HandIndex >= 0)
        {
            ExecutePlacement(move.HandIndex, move.CellIndex);
        }
        else
        {
            // Fallback if AI has no move
            _isAnimating = false;
            NotifyStateChanged();
        }
    }

    public void InitializeGame() => StartNewMatch();

    public void RestartGame() => StartNewMatch();

    public void QuitMatch()
    {
        _matchGeneration++;
        _isAnimating = false;
        ActiveHint = null;
        PendingSteal = null;
        State = new HoneycombState();
        NotifyStateChanged();
    }

    // Rematch: start a new match reusing the same opponent card pool + rules from the
    // just-finished match. If Swap is active, a fresh trade is rolled against this same
    // pool each time (a different pairing, same underlying 5 cards), and All
    // Open/Three Open reveal picks re-roll too. Repeated rematches keep drawing from
    // the same opponent pool until StartNewMatch() rolls a fresh one, which is what
    // lets a player steal their way through an opponent's whole card pool.
    public void RematchGame()
    {
        // Use the snapshot if available; if not, fall back to a new game (shouldn't happen in normal play)
        if (_rematchOpponentDeck == null)
        {
            StartNewMatch();
            return;
        }

        // Defensive reset, mirroring StartNewMatch() — a previous match quit (or
        // otherwise interrupted) while this was true (e.g. mid-Swap-animation-wait)
        // would otherwise leave it stuck true, permanently blocking PlayCard.
        _isAnimating = false;
        State.Phase = HoneycombPhase.Playing;
        State.UndoStack.Clear();
        State.ActiveRules = new List<HoneycombRule>(_rematchActiveRules);
        State.HasStolenThisMatch = false;
        State.CardsCapturedThisMatch = 0;
        State.IsSuddenDeath = false;
        State.ShowPostGamePrompt = false;

        State.Board = new HoneycombBoard();
        State.Board.AscensionDescensionSuits = new List<string>(_rematchAscensionDescensionSuits);

        State.PlayerHand = BuildPlayerHand();
        State.PlayerStartingDeck = State.PlayerHand.Select(c => c.Clone()).ToList();

        var swapIds = ApplyOpponentDeck(_rematchOpponentDeck);
        FinishMatchSetup(swapIds, forceAlternateStarter: true);
    }

    public void Undo()
    {
        if (!CanUndo) return;
        var snap = State.UndoStack.Pop();
        
        State.Board = snap.Board;
        State.PlayerHand = snap.PlayerHand;
        State.OpponentHand = snap.OpponentHand;
        State.PlayerRevealedIds = snap.PlayerRevealedIds;
        State.OpponentRevealedIds = snap.OpponentRevealedIds;
        State.CurrentTurn = snap.CurrentTurn;
        State.CardsCapturedThisMatch = snap.CardsCapturedThisMatch;
        State.PlayerChaosIndex = snap.PlayerChaosIndex;
        State.OpponentChaosIndex = snap.OpponentChaosIndex;

        ActiveHint = null;
        ClearBannerQueue();
        NotifyStateChanged();
    }

    private void PushSnapshot()
    {
        var snap = new HoneycombSnapshot
        {
            Board = State.Board.Clone(),
            PlayerHand = State.PlayerHand.Select(c => c.Clone()).ToList(),
            OpponentHand = State.OpponentHand.Select(c => c.Clone()).ToList(),
            PlayerRevealedIds = new HashSet<Guid>(State.PlayerRevealedIds),
            OpponentRevealedIds = new HashSet<Guid>(State.OpponentRevealedIds),
            CurrentTurn = State.CurrentTurn,
            CardsCapturedThisMatch = State.CardsCapturedThisMatch,
            PlayerChaosIndex = State.PlayerChaosIndex,
            OpponentChaosIndex = State.OpponentChaosIndex
        };
        State.UndoStack.Push(snap);
    }

    public void PlayCard(int handIndex, int cellIndex)
    {
        if (!IsPlaying || State.CurrentTurn != 1 || _isAnimating) return;
        if (handIndex < 0 || handIndex >= State.PlayerHand.Count) return;
        
        if (State.ActiveRules.Contains(HoneycombRule.Order) && handIndex != 0) return;
        if (State.ActiveRules.Contains(HoneycombRule.Chaos) && State.PlayerChaosIndex.HasValue && handIndex != State.PlayerChaosIndex.Value) return;

        PushSnapshot();
        ExecutePlacement(handIndex, cellIndex);
    }

    private void ExecutePlacement(int handIndex, int cellIndex)
    {
        var hand = State.CurrentTurn == 1 ? State.PlayerHand : State.OpponentHand;
        var card = hand[handIndex];

        var preBoard = State.Board.Clone();
        int preScore = State.CurrentTurn == 1 ? CountPlayerCards(preBoard, hand) : CountOpponentCards(preBoard, hand);

        if (!State.Board.Cells[cellIndex].IsEmpty)
        {
            _isAnimating = false;
            NotifyStateChanged();
            return;
        }

        bool isBombShelterFirstCard = State.ActiveRules.Contains(HoneycombRule.BombShelter) && hand.Count == 5;
        if (isBombShelterFirstCard)
        {
            card.IsFaceDown = true;
            card.BombShelterTurnsRemaining = 3;
        }

        // Resolve the placement (and any captures) on a clone rather than State.Board
        // directly, so Point Highlights can show an intermediate ("placed, not yet
        // captured") board first without the real, fully-resolved result leaking
        // through early.
        var workingBoard = State.Board.Clone();
        var flipped = workingBoard.PlaceCard(card, cellIndex, new HashSet<HoneycombRule>(State.ActiveRules), skipCaptures: isBombShelterFirstCard);
        hand.RemoveAt(handIndex);

        // Only the directly-placed card's own captures get highlighted — secondary
        // combo/chain flips (a captured card immediately flipping its own neighbors)
        // just flip along with everything else below, no separate highlight cycle.
        // Naturally empty for a Bomb Shelter first card, since skipCaptures leaves
        // `flipped` empty too.
        var directStatIndices = new HashSet<int>();
        foreach (var n in preBoard.GetNeighbors(cellIndex))
        {
            if (flipped.Contains(n.Index)) directStatIndices.Add(n.AttackerEdge);
        }

        _isAnimating = true;
        if (Options.ShowPointHighlights && directStatIndices.Count > 0 && !_isHeadless)
        {
            var intermediateBoard = preBoard.Clone();
            intermediateBoard.PlaceCard(card, cellIndex, new HashSet<HoneycombRule>(State.ActiveRules), skipCaptures: true);
            State.Board = intermediateBoard;
            State.PointHighlightCellIndex = cellIndex;
            State.PointHighlightStatIndices = directStatIndices;
            NotifyStateChanged();

            FinishPlacementAfterHighlight(workingBoard, cellIndex, hand, preScore, _matchGeneration);
        }
        else
        {
            State.Board = workingBoard;
            FinishPlacementTail(cellIndex, hand, preScore);
        }
    }

    private async void FinishPlacementAfterHighlight(HoneycombBoard workingBoard, int cellIndex, List<HoneycombCard> hand, int preScore, int generation)
    {
        await Task.Delay(500);

        // Quit Match resets State to a fresh pre-match HoneycombState (Phase back to
        // PreMatch) without touching _isAnimating, and doesn't bump _matchGeneration
        // either — so on its own, neither check alone catches every case. If a new
        // match had already started instead, IsPlaying is true again but the
        // generation differs; that new match manages its own _isAnimating, so leave
        // it alone. Only clear _isAnimating here when nothing else could legitimately
        // be relying on it (i.e. we're genuinely back at a non-Playing phase),
        // otherwise an abandoned match's stuck _isAnimating=true would silently block
        // PlayCard/AI turns in whatever match follows it.
        if (generation != _matchGeneration || !IsPlaying)
        {
            if (!IsPlaying) _isAnimating = false;
            return;
        }

        State.PointHighlightCellIndex = null;
        State.PointHighlightStatIndices = new HashSet<int>();
        State.Board = workingBoard;
        FinishPlacementTail(cellIndex, hand, preScore);
    }

    private void FinishPlacementTail(int cellIndex, List<HoneycombCard> hand, int preScore)
    {
        // Ticks down any other still-hidden Bomb Shelter card(s) already on the board —
        // this play counts as one of their 3 turns, whether or not this play was itself
        // a Bomb Shelter placement.
        AdvanceBombShelterTimers(justPlacedCellIndex: cellIndex);

        // Chaos's locked-card index is only re-rolled in StartTurn when it becomes this
        // side's turn again — left stale here, it would keep pointing at whatever index
        // the just-played card's removal shifted into, highlighting the wrong card (and
        // rejecting plays against it) for the rest of the opponent's turn instead of
        // clearing until StartTurn recomputes it fresh.
        if (State.ActiveRules.Contains(HoneycombRule.Chaos))
        {
            if (State.CurrentTurn == 1) State.PlayerChaosIndex = null;
            else State.OpponentChaosIndex = null;
        }

        // A single combined banner for everything this placement's own capture just
        // did, instead of separate SAME/PLUS and COMBO flashes — two back-to-back
        // OnFlashBanner calls used to mean the second silently overwrote the first
        // before it had ever been seen. Also reuses ComboBannerText (already shared
        // with the Bomb Shelter reveal paths below) instead of a second, narrower
        // inline check, which previously dropped Fallen Ace entirely for an ordinary
        // placement. Mirrors the Swift port's flashRuleBannerIfNeeded.
        var bannerParts = new List<string>();
        string placedSuit = State.Board.Cells[cellIndex].Card!.Data.Suit;
        // Skip Ascension/Descension on the game's last move (the one that fills the
        // board) — the win/lose overlay appears shortly after (see
        // ShowPostGamePromptAfterDelay) and a suit banner flashing at the same moment
        // just clutters that transition. Same/Plus/Fallen Ace/Combo still show, since
        // those describe what the final move itself actually did.
        if (!IsBoardFull() && State.Board.AscensionDescensionSuits.Contains(placedSuit))
        {
            if (State.ActiveRules.Contains(HoneycombRule.Ascension))
                bannerParts.Add($"{HoneycombRule.Ascension.DisplayName()}!");
            else if (State.ActiveRules.Contains(HoneycombRule.Descension))
                bannerParts.Add($"{HoneycombRule.Descension.DisplayName()}!");
        }
        var placementComboText = ComboBannerText(State.Board);
        if (placementComboText != null) bannerParts.Add(placementComboText);
        if (bannerParts.Count > 0) EnqueueBanner(string.Join(" ", bannerParts));

        int postScore = State.CurrentTurn == 1 ? CountPlayerCards(State.Board, hand) : CountOpponentCards(State.Board, hand);
        // Count all captures (both player and opponent moves), not just player captures
        State.CardsCapturedThisMatch += Math.Max(0, postScore - preScore); // preScore already includes the card placed from hand

        if (IsBoardFull())
        {
            if (State.ActiveRules.Contains(HoneycombRule.BombShelter))
            {
                _ = RevealBombSheltersAndSettleAsync();
            }
            else
            {
                SettleMatch();
            }
        }
        else
        {
            State.CurrentTurn = State.CurrentTurn == 1 ? -1 : 1;
            _isAnimating = false;
            StartTurn();
        }
    }

    // Same/Plus/Fallen Ace/Combo only ever describe what the board's last capture
    // resolution actually did, independent of whether that resolution came from a normal
    // placement (FinishPlacementTail) or a Bomb Shelter reveal flipping a hidden card on
    // its own (AdvanceBombShelterTimers/RevealBombSheltersAndSettleAsync) — both paths run
    // the same capture-resolution logic, so both need to surface it the same way.
    private static string? ComboBannerText(HoneycombBoard board)
    {
        var parts = new List<string>();
        var sameName = HoneycombRule.Same.DisplayName().ToUpperInvariant();
        var plusName = HoneycombRule.Plus.DisplayName().ToUpperInvariant();
        if (board.LastSameTriggered && board.LastPlusTriggered) parts.Add($"{sameName} & {plusName}!");
        else if (board.LastSameTriggered) parts.Add($"{sameName}!");
        else if (board.LastPlusTriggered) parts.Add($"{plusName}!");
        if (board.LastFallenAceTriggered) parts.Add($"{HoneycombRule.FallenAce.DisplayName()}!");
        if (board.LastComboFlipCount > 0) parts.Add($"COMBO x{board.LastComboFlipCount}!");
        return parts.Count == 0 ? null : string.Join(" ", parts);
    }

    // Bomb Shelter: the hidden card flips on its own 3 turns after it was played,
    // rather than waiting for the match to end — a timed landmine the opponent has to
    // play around, instead of a secret that's only relevant at the final score.
    private void AdvanceBombShelterTimers(int justPlacedCellIndex)
    {
        for (int i = 0; i < 9; i++)
        {
            if (i == justPlacedCellIndex) continue;

            var cell = State.Board.Cells[i];
            if (cell.IsEmpty || !cell.Card!.IsFaceDown || !cell.Card.BombShelterTurnsRemaining.HasValue) continue;

            cell.Card.BombShelterTurnsRemaining--;
            if (cell.Card.BombShelterTurnsRemaining <= 0)
            {
                cell.Card.BombShelterTurnsRemaining = null;
                State.Board.RevealFaceDownCard(i, new HashSet<HoneycombRule>(State.ActiveRules));
                var comboText = ComboBannerText(State.Board);
                var revealedText = $"{HoneycombRule.BombShelter.DisplayName()} Revealed!";
                var bannerText = comboText == null ? revealedText : $"{revealedText} {comboText}";
                // The reveal itself is committed above so the eventual NotifyStateChanged
                // later in FinishPlacementTail's flow picks it up and plays
                // HoneycombCardView's reveal flip — but the banner text is delayed a beat
                // so it doesn't land before the player has had a chance to see that flip.
                FlashBannerAfterRevealDelay(bannerText, _matchGeneration);
            }
        }
    }

    // Gives a Bomb Shelter reveal's own flip animation a moment to actually be seen
    // (HoneycombCardView.PlayRevealAnimation) before its "Revealed!" banner lands —
    // mirrors the Swift port's 0.5s pause for the same reason (finishPlacement's
    // revealBombShelters). Guarded by _matchGeneration so a match that's moved on
    // (New Game/Surrender/a fresh match) during the delay can't flash a stale banner.
    private async void FlashBannerAfterRevealDelay(string text, int generation)
    {
        if (!_isHeadless) await Task.Delay(500);
        if (generation != _matchGeneration) return;
        EnqueueBanner(text);
    }

    private async Task RevealBombSheltersAndSettleAsync()
    {
        _isAnimating = true;
        NotifyStateChanged();

        await Task.Delay(1000);

        int starter = State.PlayerHand.Count == 0 ? 1 : -1;
        
        int starterCell = -1;
        int secondCell = -1;
        
        for (int i=0; i<9; i++)
        {
            if (!State.Board.Cells[i].IsEmpty && State.Board.Cells[i].Card!.IsFaceDown)
            {
                if (State.Board.Cells[i].Card!.OriginalOwner == starter) starterCell = i;
                else secondCell = i;
            }
        }

        if (starterCell != -1)
        {
            State.Board.RevealFaceDownCard(starterCell, new HashSet<HoneycombRule>(State.ActiveRules));
            NotifyStateChanged();
            var comboText = ComboBannerText(State.Board);
            // Let the reveal flip (HoneycombCardView.PlayRevealAnimation, kicked off by
            // NotifyStateChanged above) actually be seen before its banner lands.
            if (comboText != null)
            {
                if (!_isHeadless) await Task.Delay(500);
                EnqueueBanner(comboText);
            }
            await Task.Delay(1000);
        }

        if (secondCell != -1)
        {
            State.Board.RevealFaceDownCard(secondCell, new HashSet<HoneycombRule>(State.ActiveRules));
            NotifyStateChanged();
            var comboText = ComboBannerText(State.Board);
            if (comboText != null)
            {
                if (!_isHeadless) await Task.Delay(500);
                EnqueueBanner(comboText);
            }
            await Task.Delay(1000);
        }

        _isAnimating = false;
        SettleMatch();
    }

    private bool IsBoardFull()
    {
        for (int i=0; i<9; i++) if (State.Board.Cells[i].IsEmpty) return false;
        return true;
    }

    private int CountPlayerCards(HoneycombBoard board, List<HoneycombCard> hand)
    {
        int total = hand.Count;
        for (int i=0; i<9; i++)
            if (!board.Cells[i].IsEmpty && board.Cells[i].Card!.Owner == 1) total++;
        return total;
    }
    private int CountOpponentCards(HoneycombBoard board, List<HoneycombCard> hand)
    {
        int total = hand.Count;
        for (int i=0; i<9; i++)
            if (!board.Cells[i].IsEmpty && board.Cells[i].Card!.Owner == -1) total++;
        return total;
    }

    private void SettleMatch()
    {
        State.PlayerScore = CountPlayerCards(State.Board, State.PlayerHand);
        State.OpponentScore = CountOpponentCards(State.Board, State.OpponentHand);

        if (State.PlayerScore == State.OpponentScore && State.ActiveRules.Contains(HoneycombRule.SuddenDeath))
        {
            TriggerSuddenDeathAsync();
            return;
        }

        bool won = State.PlayerScore > State.OpponentScore;
        // Sudden Death is now an opt-in Rule (Triple Triad-style) rather than automatic
        // on every tie — when it isn't active, a tie is a final result like a win/loss,
        // not a continuation, so it's recorded as a draw here instead of looping into
        // TriggerSuddenDeathAsync above.
        bool drawn = State.PlayerScore == State.OpponentScore;
        bool flawless = State.OpponentScore == 0;

        Stats.RecordGame(won, drawn, State.CardsCapturedThisMatch, State.Board.SessionSamePlusTriggers, flawless, Options.Difficulty, State.Board.SessionFallenAceCaptures);
        SaveStats();

        State.Phase = HoneycombPhase.Result;
        _isAnimating = false;
        NotifyStateChanged();

        ShowPostGamePromptAfterDelay(_matchGeneration);
    }

    // Matches Video Poker/Blackjack's own result-banner pacing (see
    // VideoPokerView/BlackjackView's _resultShowTimer, 1.5s) — a beat between the
    // result being decided (Phase already flipped to Result above) and the win/lose
    // overlay actually covering the board, so the player sees the final board fully
    // settle first. HoneycombView also holds the overlay back further on its own
    // (gated on its own "banner still showing" state) until any Combo/Same/Plus/
    // Ascension/Descension banner currently on screen finishes.
    private async void ShowPostGamePromptAfterDelay(int generation)
    {
        if (!_isHeadless) await Task.Delay(1500);
        if (generation != _matchGeneration) return;

        State.ShowPostGamePrompt = true;
        NotifyStateChanged();
    }

    private async void TriggerSuddenDeathAsync()
    {
        _isAnimating = true;
        NotifyStateChanged();

        // Give enough time for the final card placement and any combo animations to fully resolve
        if (!_isHeadless) await Task.Delay(2500);

        EnqueueBanner($"{HoneycombRule.SuddenDeath.DisplayName()}!");
        State.IsSuddenDeath = true;
        Stats.SuddenDeathCount++;
        SaveStats();

        var pHand = new List<HoneycombCard>(State.PlayerHand);
        var oHand = new List<HoneycombCard>(State.OpponentHand);
        for (int i=0; i<9; i++)
        {
            var c = State.Board.Cells[i].Card;
            if (c != null)
            {
                c.Modifier = 0;
                if (c.Owner == 1) pHand.Add(c);
                else oHand.Add(c);
            }
        }
        State.PlayerHand = pHand;
        State.OpponentHand = oHand;

        var suits = State.Board.AscensionDescensionSuits;
        State.Board = new HoneycombBoard();
        State.Board.AscensionDescensionSuits = suits;
        
        State.UndoStack.Clear();
        State.CurrentTurn = State.CurrentTurn == 1 ? -1 : 1; // flip who starts
        
        _isAnimating = false;
        NotifyStateChanged();

        StartTurn();
    }

    public void FindHint()
    {
        if (!IsPlaying || State.CurrentTurn != 1 || _isAnimating || State.PlayerHand.Count == 0) return;
        
        var knownOpponent = State.OpponentHand.Where(c => State.OpponentRevealedIds.Contains(c.UniqueInstanceId)).ToList();
        // How many of the opponent's real cards remain unrevealed — knownOpponent above
        // is only the subset the player has actually seen; treating that subset as the
        // opponent's whole hand would let the search look ahead several plies as if it
        // knew the opponent could only ever play those few cards, so the remainder is
        // simulated as generic placeholder cards inside HoneycombAI.FindMove instead.
        int unknownOpponentCardCount = State.OpponentHand.Count - knownOpponent.Count;

        var move = HoneycombAI.FindMove(State.Board, State.PlayerHand, knownOpponent, unknownOpponentCardCount, new HashSet<HoneycombRule>(State.ActiveRules), HoneycombDifficulty.UltraHard, 1, -1, null);
        
        if (move.HandIndex < 0)
        {
            var emptyCells = new List<int>();
            for (int i = 0; i < 9; i++)
            {
                if (State.Board.Cells[i].IsEmpty) emptyCells.Add(i);
            }

            if (emptyCells.Count > 0)
            {
                int cIdx = emptyCells[Random.Shared.Next(emptyCells.Count)];
                int hIdx = Random.Shared.Next(State.PlayerHand.Count);

                if (State.ActiveRules.Contains(HoneycombRule.Order)) hIdx = 0;
                else if (State.ActiveRules.Contains(HoneycombRule.Chaos) && State.PlayerChaosIndex.HasValue) hIdx = State.PlayerChaosIndex.Value;

                move = (hIdx, cIdx);
            }
        }

        if (move.HandIndex >= 0)
        {
            ActiveHint = move;
            NotifyStateChanged();
        }
    }

    private static string GetLocalFolderPath()
    {
        try
        {
            var appDataType = Type.GetType("Windows.Storage.ApplicationData, Windows, Version=255.255.255.255, Culture=neutral, PublicKeyToken=null, ContentType=WindowsRuntime");
            if (appDataType != null)
            {
                var currentProp = appDataType.GetProperty("Current", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static);
                var currentInstance = currentProp?.GetValue(null);
                if (currentInstance != null)
                {
                    var localFolderProp = currentInstance.GetType().GetProperty("LocalFolder", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance);
                    var localFolderInstance = localFolderProp?.GetValue(currentInstance);
                    if (localFolderInstance != null)
                    {
                        var pathProp = localFolderInstance.GetType().GetProperty("Path", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance);
                        var path = pathProp?.GetValue(localFolderInstance) as string;
                        if (!string.IsNullOrEmpty(path)) return path;
                    }
                }
            }
        }
        catch { }
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SoliBee");
    }

    private static string DataDir => GetLocalFolderPath();
    private static string OptionsPath => Path.Combine(DataDir, "honeycomb_options.json");
    private static string StatisticsPath => Path.Combine(DataDir, "honeycomb_stats.json");

    public void SaveOptions()
    {
        SettingsService.SaveHoneycombOptions(Options);
    }

    private void SaveStats()
    {
        try { Directory.CreateDirectory(DataDir); File.WriteAllText(StatisticsPath, JsonSerializer.Serialize(Stats, new JsonSerializerOptions { WriteIndented = true })); }
        catch { }
    }

    public static HoneycombStats LoadStats()
    {
        try { if (File.Exists(StatisticsPath)) { var s = JsonSerializer.Deserialize<HoneycombStats>(File.ReadAllText(StatisticsPath)); if (s != null) return s; } }
        catch { }
        return new HoneycombStats();
    }

    public void NotifyOptionsChanged()
    {
        OnPropertyChanged(nameof(Options));
        OnPropertyChanged(nameof(OpponentNameDisplay));
    }

    private void NotifyStateChanged()
    {
        if (State != null)
        {
            State.PlayerScore = CountPlayerCards(State.Board, State.PlayerHand);
            State.OpponentScore = CountOpponentCards(State.Board, State.OpponentHand);
        }
        OnPropertyChanged(nameof(State));
        OnPropertyChanged(nameof(IsPlaying));
        OnPropertyChanged(nameof(CanUndo));
        OnPropertyChanged(nameof(ActiveHint));
        OnPropertyChanged(nameof(PlayerScoreDisplay));
        OnPropertyChanged(nameof(OpponentScoreDisplay));
    }

    public void ResetStats()
    {
        Stats = new HoneycombStats();
        SaveStats();
    }

    // Steal no longer touches the active deck/hand at all — the stolen card unlocks
    // straight into the card bank, so there's nothing left to validate against deck
    // composition (the old 5★/4★ caps only ever existed to keep a 5-card deck legal).
    public void RequestSteal(int boardIndex)
    {
        if (State.HasStolenThisMatch) return;
        if (State.PlayerScore <= State.OpponentScore) return; // Must win to steal
        var incoming = State.Board.Cells[boardIndex].Card;
        if (incoming == null || incoming.OriginalOwner != -1 || incoming.Owner != 1) return;
        if (HoneycombProfileManager.Shared.UnlockedCardIds.Contains(incoming.Data.Id)) return;

        PendingSteal = new HoneycombPendingSteal(boardIndex, incoming.Data.Name);
    }

    public void CancelPendingSteal()
    {
        PendingSteal = null;
    }

    public void ConfirmPendingSteal()
    {
        if (PendingSteal == null) return;
        var steal = PendingSteal;
        PendingSteal = null;

        var incoming = State.Board.Cells[steal.BoardIndex].Card;
        if (incoming == null || incoming.OriginalOwner != -1) return;

        HoneycombProfileManager.Shared.UnlockCard(incoming.Data.Id);
        Stats.CardsStolen++;
        SaveStats();
        State.HasStolenThisMatch = true;
        NotifyStateChanged();
    }
}
