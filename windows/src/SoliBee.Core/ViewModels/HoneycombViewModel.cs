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
    
    public event Action<string>? OnFlashBanner;

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
        var selected = new List<HoneycombRule>();
        for (int slot = 0; slot < 2; slot++)
        {
            if (pool.Count == 0) break;

            bool mustPick = slot == 0 && normalBanned;
            double stopProbability = slot == 0 ? stopProbabilityFirst : stopProbabilitySecond;
            if (!mustPick && Random.Shared.NextDouble() < stopProbability) break;

            int idx = Random.Shared.Next(pool.Count);
            var r = pool[idx];
            selected.Add(r);
            pool.RemoveAt(idx);

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

    public void StartNewMatch()
    {
        State.Phase = HoneycombPhase.Playing;
        State.UndoStack.Clear();
        State.ActiveRules = DetermineActiveRules();
        State.HasStolenThisMatch = false;
        State.CardsCapturedThisMatch = 0;
        State.IsSuddenDeath = false;

        State.Board = new HoneycombBoard();

        if (State.ActiveRules.Contains(HoneycombRule.Ascension) || State.ActiveRules.Contains(HoneycombRule.Descension))
        {
            State.Board.AscensionDescensionSuits = new[] { "S", "H", "D", "C" }.OrderBy(x => Random.Shared.Next()).Take(1).ToList();
        }

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
        var name = System.Text.RegularExpressions.Regex.Replace(rule.ToString(), "(\\B[A-Z])", " $1");
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
        return deck;
    }

    // Wires up a given opponent card pool as this match's OpponentHand: rolls a fresh
    // Swap trade (if active) and fresh All Open/Three Open reveal picks against it.
    // Shared by StartNewMatch() (a newly-rolled pool) and RematchGame() (the frozen
    // pool from the last genuinely-new match) — either way, this is what makes each
    // call a fresh roll of who trades with whom and what gets revealed. Returns the
    // swapped card ids (player, opponent) if a Swap trade happened.
    private (Guid PlayerCardId, Guid OpponentCardId)? ApplyOpponentDeck(List<HoneycombCardData> deck)
    {
        State.OpponentHand = deck.Select(d => new HoneycombCard(d, -1)).ToList();

        State.PlayerRevealedIds.Clear();
        State.OpponentRevealedIds.Clear();

        // Swap is resolved before the All Open/Three Open reveal below, so that reveal
        // picks from the hands as they'll actually look once the trade lands — not from
        // the pre-swap hands, which could pick a card that's about to be traded away and
        // leave the card that trades in undiscovered (and, with Three Open, silently
        // short a hand to 2 visible cards instead of 3).
        (Guid PlayerCardId, Guid OpponentCardId)? swapIds = null;
        if (State.ActiveRules.Contains(HoneycombRule.Swap))
        {
            int pIdx = Random.Shared.Next(State.PlayerHand.Count);
            int oIdx = Random.Shared.Next(State.OpponentHand.Count);

            var pCard = State.PlayerHand[pIdx];
            var oCard = State.OpponentHand[oIdx];

            pCard.Owner = -1;
            oCard.Owner = 1;

            State.PlayerHand[pIdx] = oCard;
            State.OpponentHand[oIdx] = pCard;

            // Identity-preserving trade: oCard now sits in the player's hand and pCard
            // in the opponent's, so these two ids are what the highlight below tracks —
            // the same two cards, just relocated.
            swapIds = (pCard.UniqueInstanceId, oCard.UniqueInstanceId);
        }

        if (State.ActiveRules.Contains(HoneycombRule.AllOpen))
        {
            foreach (var c in State.PlayerHand) State.PlayerRevealedIds.Add(c.UniqueInstanceId);
            foreach (var c in State.OpponentHand) State.OpponentRevealedIds.Add(c.UniqueInstanceId);
        }
        else if (State.ActiveRules.Contains(HoneycombRule.ThreeOpen))
        {
            var pRand = State.PlayerHand.OrderBy(x => Random.Shared.Next()).Take(3).ToList();
            var oRand = State.OpponentHand.OrderBy(x => Random.Shared.Next()).Take(3).ToList();
            foreach (var c in pRand) State.PlayerRevealedIds.Add(c.UniqueInstanceId);
            foreach (var c in oRand) State.OpponentRevealedIds.Add(c.UniqueInstanceId);
        }

        // The swapped card always stays visible in its new hand, regardless of whether
        // Three Open's random pick landed on it — the player already knows exactly what
        // it is (it just came from their own hand a moment ago), so there's nothing left
        // to hide, and the AI is in the same position for the card it received.
        if (swapIds.HasValue)
        {
            State.OpponentRevealedIds.Add(swapIds.Value.PlayerCardId);
            State.PlayerRevealedIds.Add(swapIds.Value.OpponentCardId);
        }

        return swapIds;
    }

    // Shared tail between StartNewMatch() and RematchGame() — decides who moves first,
    // flashes the opening banner (folding in "Swap!" if this match opened with a
    // trade), stages the swap highlight, and kicks off StartTurn().
    private void FinishMatchSetup((Guid PlayerCardId, Guid OpponentCardId)? swapIds)
    {
        State.PlayerChaosIndex = null;
        State.OpponentChaosIndex = null;

        int starter = Random.Shared.Next(2) == 0 ? 1 : -1;
        if (s_consecutiveStarters >= 3)
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
        OnFlashBanner?.Invoke(string.Join("\n", bannerLines));

        int generation = ++_matchGeneration;
        if (swapIds.HasValue)
        {
            State.SwapHighlightIds = new HashSet<Guid> { swapIds.Value.PlayerCardId, swapIds.Value.OpponentCardId };
            ClearSwapHighlightAfterBanner(generation);
        }

        StartTurn();
    }

    // Clears the traded-card highlight once the (now single, 2s) start-of-match banner
    // has finished, rather than leaving it up indefinitely or timing it independently.
    private async void ClearSwapHighlightAfterBanner(int generation)
    {
        if (!_isHeadless) await Task.Delay(2000);
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

    private async void RunAITurn()
    {
        _isAnimating = true;
        NotifyStateChanged();
        
        if (!_isHeadless) await Task.Delay(2500); // UI pace beat
        
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
        // never-revealed card is still sitting in hand. That would let the search below
        // use that card's real stats once !isMaximizing hits it (see Minimax's
        // playerHasHiddenCards cutoff) — an unintended AI advantage.
        bool playerHasHiddenCards = State.PlayerHand.Any(c => !State.PlayerRevealedIds.Contains(c.UniqueInstanceId));
        var move = HoneycombAI.FindMove(State.Board, State.OpponentHand, State.PlayerHand, playerHasHiddenCards, new HashSet<HoneycombRule>(State.ActiveRules), Options.Difficulty, -1, 1, State.OpponentChaosIndex);
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

        State.Phase = HoneycombPhase.Playing;
        State.UndoStack.Clear();
        State.ActiveRules = new List<HoneycombRule>(_rematchActiveRules);
        State.HasStolenThisMatch = false;
        State.CardsCapturedThisMatch = 0;
        State.IsSuddenDeath = false;

        State.Board = new HoneycombBoard();
        State.Board.AscensionDescensionSuits = new List<string>(_rematchAscensionDescensionSuits);

        State.PlayerHand = BuildPlayerHand();
        State.PlayerStartingDeck = State.PlayerHand.Select(c => c.Clone()).ToList();

        var swapIds = ApplyOpponentDeck(_rematchOpponentDeck);
        FinishMatchSetup(swapIds);
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

        if (State.Board.LastSameTriggered && State.Board.LastPlusTriggered)
            OnFlashBanner?.Invoke("SAME & PLUS!");
        else if (State.Board.LastSameTriggered)
            OnFlashBanner?.Invoke("SAME!");
        else if (State.Board.LastPlusTriggered)
            OnFlashBanner?.Invoke("PLUS!");

        if (State.Board.LastComboFlipCount > 0)
            OnFlashBanner?.Invoke($"COMBO x{State.Board.LastComboFlipCount}!");

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
                OnFlashBanner?.Invoke("Bomb Shelter Revealed!");
            }
        }
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
            await Task.Delay(1000);
        }

        if (secondCell != -1)
        {
            State.Board.RevealFaceDownCard(secondCell, new HashSet<HoneycombRule>(State.ActiveRules));
            NotifyStateChanged();
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

        if (State.PlayerScore == State.OpponentScore)
        {
            TriggerSuddenDeathAsync();
            return;
        }

        bool won = State.PlayerScore > State.OpponentScore;
        bool drawn = false;
        bool flawless = State.OpponentScore == 0;
        
        Stats.RecordGame(won, drawn, State.CardsCapturedThisMatch, State.Board.SessionSamePlusTriggers, flawless, Options.Difficulty, State.Board.SessionFallenAceCaptures);
        SaveStats();

        State.Phase = HoneycombPhase.Result;
        _isAnimating = false;
        NotifyStateChanged();
    }

    private async void TriggerSuddenDeathAsync()
    {
        _isAnimating = true;
        NotifyStateChanged();

        // Give enough time for the final card placement and any combo animations to fully resolve
        if (!_isHeadless) await Task.Delay(2500);

        OnFlashBanner?.Invoke("Sudden Death!");
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
        // Whether any of the opponent's real cards remain unrevealed — knownOpponent above
        // is only the subset the player has actually seen, so treating that subset as the
        // opponent's whole hand (via a hardcoded false here) let the search look ahead
        // several plies as if it knew the opponent could only ever play those few cards.
        bool opponentHasHiddenCards = State.OpponentHand.Any(c => !State.OpponentRevealedIds.Contains(c.UniqueInstanceId));

        var move = HoneycombAI.FindMove(State.Board, State.PlayerHand, knownOpponent, opponentHasHiddenCards, new HashSet<HoneycombRule>(State.ActiveRules), HoneycombDifficulty.UltraHard, 1, -1, null);
        
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

    public void NotifyOptionsChanged() => OnPropertyChanged(nameof(Options));

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
