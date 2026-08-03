using System;
using System.Collections.Generic;
using System.Linq;

namespace SoliBee.Core.Models;

public static class HoneycombAI
{
    // Placeholder for a hand slot whose real contents haven't been revealed to the
    // searching side (see BuildSimulatedHand) — mirrors the Swift port's genericCard
    // in HoneycombAI.computeMove/computeHint (shared/Honeycomb/Models/HoneycombAI.swift).
    private static HoneycombCardData UnknownCardData => new()
    {
        Id = -1,
        Name = "Unknown",
        Stars = 3,
        Stats = new[] { 6, 6, 6, 6 },
        Suit = "-"
    };

    // Pads `hand` with `unknownCount` generic placeholder cards owned by `owner` so the
    // search can look ahead through slots it doesn't have real data for, without ever
    // reading the real (hidden) card underneath. Returns `hand` unchanged when there's
    // nothing to pad, matching the Swift port's simulatedPlayerDeck/simulatedOpponentDeck.
    private static List<HoneycombCard> BuildSimulatedHand(List<HoneycombCard> hand, int unknownCount, int owner)
    {
        if (unknownCount <= 0) return hand;

        var simulated = new List<HoneycombCard>(hand);
        for (int i = 0; i < unknownCount; i++)
            simulated.Add(new HoneycombCard(UnknownCardData, owner));
        return simulated;
    }

    public static (int HandIndex, int CellIndex) FindMove(
        HoneycombBoard board,
        List<HoneycombCard> aiHand,
        List<HoneycombCard> playerHand,
        int unknownPlayerCardCount,
        HashSet<HoneycombRule> rules,
        HoneycombDifficulty difficulty,
        int aiOwner,
        int playerOwner,
        int? mandatedHandIndex)
    {
        if (difficulty == HoneycombDifficulty.Easy)
        {
            var emptyCells = new List<int>();
            for (int i = 0; i < 9; i++)
                if (board.Cells[i].IsEmpty) emptyCells.Add(i);

            int cell = emptyCells[Random.Shared.Next(emptyCells.Count)];
            int handIdx = mandatedHandIndex ?? Random.Shared.Next(aiHand.Count);
            return (handIdx, cell);
        }

        if (difficulty == HoneycombDifficulty.Medium)
        {
            return FindGreedyMove(board, aiHand, rules, aiOwner, mandatedHandIndex);
        }

        var simulatedPlayerHand = BuildSimulatedHand(playerHand, unknownPlayerCardCount, playerOwner);

        // Hard: 5 plies (was 2) — mirrors the Swift port's computeMove lookaheadPlies.
        // Only safe now that unknown cards are simulated above rather than truncating
        // the player's ply outright, so the deeper search doesn't "cheat" by exhausting
        // hidden hand slots the AI was never shown.
        int depth = difficulty == HoneycombDifficulty.Hard ? 5 : 6;
        bool useFallenAceWeight = difficulty == HoneycombDifficulty.UltraHard;

        return FindMinimaxMove(board, aiHand, simulatedPlayerHand, rules, depth, useFallenAceWeight, aiOwner, playerOwner, mandatedHandIndex);
    }

    private static (int, int) FindGreedyMove(HoneycombBoard board, List<HoneycombCard> hand, HashSet<HoneycombRule> rules, int owner, int? mandatedHandIndex)
    {
        int bestScore = -1;
        var bestMoves = new List<(int, int)>();
        var handIndices = mandatedHandIndex.HasValue ? new[] { mandatedHandIndex.Value } : Enumerable.Range(0, hand.Count).ToArray();

        for (int i = 0; i < 9; i++)
        {
            if (!board.Cells[i].IsEmpty) continue;

            foreach (var hIdx in handIndices)
            {
                if (hIdx >= hand.Count) continue;

                var simBoard = board.Clone();
                var card = hand[hIdx].Clone();
                int ownerBefore = 0;
                for (int c = 0; c < 9; c++)
                    if (!simBoard.Cells[c].IsEmpty && simBoard.Cells[c].Card!.Owner == owner) ownerBefore++;

                simBoard.PlaceCard(card, i, rules);

                int ownerAfter = 0;
                for (int c = 0; c < 9; c++)
                    if (!simBoard.Cells[c].IsEmpty && simBoard.Cells[c].Card!.Owner == owner) ownerAfter++;

                int captures = ownerAfter - ownerBefore - 1;

                if (captures > bestScore)
                {
                    bestScore = captures;
                    bestMoves.Clear();
                    bestMoves.Add((hIdx, i));
                }
                else if (captures == bestScore)
                {
                    bestMoves.Add((hIdx, i));
                }
            }
        }

        return bestMoves[Random.Shared.Next(bestMoves.Count)];
    }

    // Board-cell state used as part of a transposition-table key — mirrors Swift's
    // TTKey.CardState (shared/Honeycomb/Models/HoneycombAI.swift).
    private readonly struct BoardCellState : IEquatable<BoardCellState>
    {
        private readonly bool _isEmpty;
        private readonly int _dataId;
        private readonly int _owner;
        private readonly bool _isFaceDown;

        public BoardCellState(HoneycombCard? card)
        {
            _isEmpty = card == null;
            _dataId = card?.Data.Id ?? 0;
            _owner = card?.Owner ?? 0;
            _isFaceDown = card?.IsFaceDown ?? false;
        }

        public bool Equals(BoardCellState other) =>
            _isEmpty == other._isEmpty && _dataId == other._dataId && _owner == other._owner && _isFaceDown == other._isFaceDown;
        public override bool Equals(object? obj) => obj is BoardCellState other && Equals(other);
        public override int GetHashCode() => HashCode.Combine(_isEmpty, _dataId, _owner, _isFaceDown);
    }

    private enum TTFlag { Exact, LowerBound, UpperBound }

    private readonly record struct TTEntry(int Value, TTFlag Flag);

    // Transposition-table key. Board-cell state and whose ply it is alone are NOT
    // enough — remaining search depth and each side's still-unplayed hand must be part
    // of the key too, otherwise a shallower search's cached value could be reused for a
    // deeper search of the same board layout, and two move sequences reaching an
    // identical layout with different remaining hands would incorrectly share a cached
    // score. Hand order doesn't affect which moves are available, so signatures are
    // built from sorted card ids for a stable key. Mirrors the (fixed) Swift TTKey.
    private readonly struct TTKey : IEquatable<TTKey>
    {
        private readonly BoardCellState[] _cells;
        private readonly bool _isMaximizing;
        private readonly int _depth;
        private readonly string _aiHandSignature;
        private readonly string _playerHandSignature;

        public TTKey(HoneycombBoard board, bool isMaximizing, int depth, List<HoneycombCard> aiHand, List<HoneycombCard> playerHand)
        {
            _cells = new BoardCellState[9];
            for (int i = 0; i < 9; i++) _cells[i] = new BoardCellState(board.Cells[i].Card);
            _isMaximizing = isMaximizing;
            _depth = depth;
            _aiHandSignature = string.Join(",", aiHand.Select(c => c.Data.Id).OrderBy(id => id));
            _playerHandSignature = string.Join(",", playerHand.Select(c => c.Data.Id).OrderBy(id => id));
        }

        public bool Equals(TTKey other)
        {
            if (_isMaximizing != other._isMaximizing || _depth != other._depth) return false;
            if (_aiHandSignature != other._aiHandSignature || _playerHandSignature != other._playerHandSignature) return false;
            for (int i = 0; i < 9; i++)
                if (!_cells[i].Equals(other._cells[i])) return false;
            return true;
        }

        public override bool Equals(object? obj) => obj is TTKey other && Equals(other);

        public override int GetHashCode()
        {
            var hash = new HashCode();
            hash.Add(_isMaximizing);
            hash.Add(_depth);
            hash.Add(_aiHandSignature);
            hash.Add(_playerHandSignature);
            foreach (var cell in _cells) hash.Add(cell);
            return hash.ToHashCode();
        }
    }

    private static (int, int) FindMinimaxMove(HoneycombBoard board, List<HoneycombCard> aiHand, List<HoneycombCard> playerHand, HashSet<HoneycombRule> rules, int depth, bool useFallenAceWeight, int aiOwner, int playerOwner, int? mandatedHandIndex)
    {
        var tt = new Dictionary<TTKey, TTEntry>();
        var bestMoves = new List<(int, int)>();
        int bestScore = int.MinValue;
        int maxCaptures = -1;

        if (rules.Contains(HoneycombRule.Order)) mandatedHandIndex = 0;
        var handIndices = mandatedHandIndex.HasValue ? new[] { mandatedHandIndex.Value } : Enumerable.Range(0, aiHand.Count).ToArray();
        var orderedMoves = new List<(int HIdx, int CIdx, int Captures, HoneycombBoard BoardAfter, List<HoneycombCard> HandAfter)>();

        for (int i = 0; i < 9; i++)
        {
            if (!board.Cells[i].IsEmpty) continue;

            foreach (var hIdx in handIndices)
            {
                if (hIdx >= aiHand.Count) continue;

                var simBoard = board.Clone();
                var card = aiHand[hIdx].Clone();
                int ownerBefore = 0;
                for (int c = 0; c < 9; c++)
                    if (!simBoard.Cells[c].IsEmpty && simBoard.Cells[c].Card!.Owner == aiOwner) ownerBefore++;

                simBoard.PlaceCard(card, i, rules);

                int ownerAfter = 0;
                for (int c = 0; c < 9; c++)
                    if (!simBoard.Cells[c].IsEmpty && simBoard.Cells[c].Card!.Owner == aiOwner) ownerAfter++;

                var simHand = new List<HoneycombCard>(aiHand);
                simHand.RemoveAt(hIdx);

                orderedMoves.Add((hIdx, i, ownerAfter - ownerBefore - 1, simBoard, simHand));
            }
        }

        orderedMoves.Sort((a, b) => b.Captures.CompareTo(a.Captures));

        foreach (var move in orderedMoves)
        {
            int score = Minimax(move.BoardAfter, move.HandAfter, playerHand, rules, depth - 1, int.MinValue, int.MaxValue, false, useFallenAceWeight, aiOwner, playerOwner, null, tt);

            if (score > bestScore)
            {
                bestScore = score;
                maxCaptures = move.Captures;
                bestMoves.Clear();
                bestMoves.Add((move.HIdx, move.CIdx));
            }
            else if (score == bestScore)
            {
                if (move.Captures > maxCaptures)
                {
                    maxCaptures = move.Captures;
                    bestMoves.Clear();
                    bestMoves.Add((move.HIdx, move.CIdx));
                }
                else if (move.Captures == maxCaptures)
                {
                    bestMoves.Add((move.HIdx, move.CIdx));
                }
            }
        }

        return bestMoves[Random.Shared.Next(bestMoves.Count)];
    }

    private static int Minimax(HoneycombBoard board, List<HoneycombCard> aiHand, List<HoneycombCard> playerHand, HashSet<HoneycombRule> rules, int depth, int alpha, int beta, bool isMaximizing, bool useFallenAceWeight, int aiOwner, int playerOwner, int? mandatedHandIndex, Dictionary<TTKey, TTEntry> tt)
    {
        var ttKey = new TTKey(board, isMaximizing, depth, aiHand, playerHand);
        if (tt.TryGetValue(ttKey, out var cached))
        {
            if (cached.Flag == TTFlag.Exact) return cached.Value;
            if (cached.Flag == TTFlag.LowerBound && cached.Value >= beta) return cached.Value;
            if (cached.Flag == TTFlag.UpperBound && cached.Value <= alpha) return cached.Value;
        }
        int originalAlpha = alpha;

        int emptyCount = 0;
        int aiCardsOnBoard = 0;
        int playerCardsOnBoard = 0;
        for (int i = 0; i < 9; i++)
        {
            if (board.Cells[i].IsEmpty) emptyCount++;
            else
            {
                if (board.Cells[i].Card!.Owner == aiOwner) aiCardsOnBoard++;
                else if (board.Cells[i].Card!.Owner == playerOwner) playerCardsOnBoard++;
            }
        }

        if (emptyCount == 0)
        {
            int aiTotal = aiCardsOnBoard + aiHand.Count;
            int playerTotal = playerCardsOnBoard + playerHand.Count;
            return (aiTotal - playerTotal) * 1000;
        }

        if (depth == 0 || (isMaximizing && aiHand.Count == 0) || (!isMaximizing && playerHand.Count == 0))
        {
            return EvaluateBoard(board, rules, useFallenAceWeight, aiOwner, playerOwner);
        }

        var activeHand = isMaximizing ? aiHand : playerHand;
        var activeOwner = isMaximizing ? aiOwner : playerOwner;
        if (rules.Contains(HoneycombRule.Order)) mandatedHandIndex = 0;
        var handIndices = mandatedHandIndex.HasValue ? new[] { mandatedHandIndex.Value } : Enumerable.Range(0, activeHand.Count).ToArray();

        var orderedMoves = new List<(int HIdx, int CIdx, int Captures, HoneycombBoard BoardAfter, List<HoneycombCard> HandAfter)>();

        for (int i = 0; i < 9; i++)
        {
            if (!board.Cells[i].IsEmpty) continue;

            foreach (var hIdx in handIndices)
            {
                if (hIdx >= activeHand.Count) continue;

                var simBoard = board.Clone();
                var card = activeHand[hIdx].Clone();
                int ownerBefore = 0;
                for (int c = 0; c < 9; c++)
                    if (!simBoard.Cells[c].IsEmpty && simBoard.Cells[c].Card!.Owner == activeOwner) ownerBefore++;

                simBoard.PlaceCard(card, i, rules);

                int ownerAfter = 0;
                for (int c = 0; c < 9; c++)
                    if (!simBoard.Cells[c].IsEmpty && simBoard.Cells[c].Card!.Owner == activeOwner) ownerAfter++;

                var simHand = new List<HoneycombCard>(activeHand);
                simHand.RemoveAt(hIdx);

                orderedMoves.Add((hIdx, i, ownerAfter - ownerBefore - 1, simBoard, simHand));
            }
        }

        orderedMoves.Sort((a, b) => b.Captures.CompareTo(a.Captures));

        int best;
        if (isMaximizing)
        {
            best = int.MinValue;
            foreach (var move in orderedMoves)
            {
                int eval = Minimax(move.BoardAfter, move.HandAfter, playerHand, rules, depth - 1, alpha, beta, false, useFallenAceWeight, aiOwner, playerOwner, null, tt);
                if (eval > best) best = eval;
                if (eval > alpha) alpha = eval;
                if (beta <= alpha) break;
            }
        }
        else
        {
            best = int.MaxValue;
            foreach (var move in orderedMoves)
            {
                int eval = Minimax(move.BoardAfter, aiHand, move.HandAfter, rules, depth - 1, alpha, beta, true, useFallenAceWeight, aiOwner, playerOwner, null, tt);
                if (eval < best) best = eval;
                if (eval < beta) beta = eval;
                if (beta <= alpha) break;
            }
        }

        TTFlag flag;
        if (best <= originalAlpha) flag = TTFlag.UpperBound;
        else if (best >= beta) flag = TTFlag.LowerBound;
        else flag = TTFlag.Exact;
        tt[ttKey] = new TTEntry(best, flag);

        return best;
    }

    private static int EvaluateBoard(HoneycombBoard board, HashSet<HoneycombRule> rules, bool useFallenAceWeight, int aiOwner, int playerOwner)
    {
        int score = 0;
        bool reverse = rules.Contains(HoneycombRule.Reverse);
        bool fallenAce = rules.Contains(HoneycombRule.FallenAce);

        for (int i = 0; i < 9; i++)
        {
            if (board.Cells[i].IsEmpty) continue;

            var card = board.Cells[i].Card!;
            if (card.IsFaceDown && card.OriginalOwner == playerOwner) continue; // Ignore player's face down card (treated as empty/unknown)

            int cardScore = 10;
            
            int row = i / 3;
            int col = i % 3;

            if (row > 0 && board.Cells[i - 3].IsEmpty)
                cardScore += ExposureValue(card.Stat(0), reverse, fallenAce, useFallenAceWeight);
            if (col < 2 && board.Cells[i + 1].IsEmpty)
                cardScore += ExposureValue(card.Stat(1), reverse, fallenAce, useFallenAceWeight);
            if (row < 2 && board.Cells[i + 3].IsEmpty)
                cardScore += ExposureValue(card.Stat(2), reverse, fallenAce, useFallenAceWeight);
            if (col > 0 && board.Cells[i - 1].IsEmpty)
                cardScore += ExposureValue(card.Stat(3), reverse, fallenAce, useFallenAceWeight);

            if (card.Owner == aiOwner)
                score += cardScore;
            else if (card.Owner == playerOwner)
                score -= cardScore;
        }

        score += ComboPotential(board, rules, aiOwner, playerOwner);
        return score;
    }

    private static int ExposureValue(int stat, bool reverse, bool fallenAce, bool useFallenAceWeight)
    {
        int effectiveStrength = reverse ? (11 - stat) : stat;
        int value = effectiveStrength - 5;
        int fallenAceVulnerableStat = reverse ? 1 : 10;
        if (useFallenAceWeight && fallenAce && stat == fallenAceVulnerableStat)
            value -= 3;
        return value;
    }

    private static int ComboPotential(HoneycombBoard board, HashSet<HoneycombRule> rules, int aiOwner, int playerOwner)
    {
        if (!rules.Contains(HoneycombRule.Same) && !rules.Contains(HoneycombRule.Plus))
            return 0;

        int score = 0;
        for (int i = 0; i < 9; i++)
        {
            if (!board.Cells[i].IsEmpty) continue;

            var neighbors = new List<(int Owner, int FacingStat)>();
            int row = i / 3;
            int col = i % 3;

            if (row > 0 && !board.Cells[i - 3].IsEmpty && !board.Cells[i - 3].Card!.IsFaceDown) 
                neighbors.Add((board.Cells[i - 3].Card!.Owner, board.Cells[i - 3].Card!.Stat(2)));
            if (col < 2 && !board.Cells[i + 1].IsEmpty && !board.Cells[i + 1].Card!.IsFaceDown) 
                neighbors.Add((board.Cells[i + 1].Card!.Owner, board.Cells[i + 1].Card!.Stat(3)));
            if (row < 2 && !board.Cells[i + 3].IsEmpty && !board.Cells[i + 3].Card!.IsFaceDown) 
                neighbors.Add((board.Cells[i + 3].Card!.Owner, board.Cells[i + 3].Card!.Stat(0)));
            if (col > 0 && !board.Cells[i - 1].IsEmpty && !board.Cells[i - 1].Card!.IsFaceDown) 
                neighbors.Add((board.Cells[i - 1].Card!.Owner, board.Cells[i - 1].Card!.Stat(1)));

            foreach (var owner in new[] { aiOwner, playerOwner })
            {
                var ownerStats = neighbors.Where(n => n.Owner == owner).Select(n => n.FacingStat).ToList();
                if (ownerStats.Count >= 2)
                {
                    int sameMatches = 0;
                    if (rules.Contains(HoneycombRule.Same))
                    {
                        for (int a = 0; a < ownerStats.Count; a++)
                        for (int b = a + 1; b < ownerStats.Count; b++)
                            if (ownerStats[a] == ownerStats[b])
                                sameMatches++;
                    }
                    
                    int plusMatches = 0;
                    if (rules.Contains(HoneycombRule.Plus))
                    {
                        plusMatches = (ownerStats.Count * (ownerStats.Count - 1)) / 2;
                    }

                    int weight = 6 * sameMatches + 3 * plusMatches;
                    if (owner == playerOwner) // AI can exploit player's cards
                        score += weight;
                    else
                        score -= weight;
                }
            }
        }
        return score;
    }
}
