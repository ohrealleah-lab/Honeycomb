using System;
using System.Collections.Generic;
using System.Linq;

namespace SoliBee.Core.Models;

public static class HoneycombAI
{
    public static (int HandIndex, int CellIndex) FindMove(
        HoneycombBoard board,
        List<HoneycombCard> aiHand,
        List<HoneycombCard> playerHand,
        bool playerHasHiddenCards,
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

        int depth = difficulty == HoneycombDifficulty.Hard ? 2 : 6;
        bool useFallenAceWeight = difficulty == HoneycombDifficulty.UltraHard;

        return FindMinimaxMove(board, aiHand, playerHand, playerHasHiddenCards, rules, depth, useFallenAceWeight, aiOwner, playerOwner, mandatedHandIndex);
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

    private static (int, int) FindMinimaxMove(HoneycombBoard board, List<HoneycombCard> aiHand, List<HoneycombCard> playerHand, bool playerHasHiddenCards, HashSet<HoneycombRule> rules, int depth, bool useFallenAceWeight, int aiOwner, int playerOwner, int? mandatedHandIndex)
    {
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
            int score = Minimax(move.BoardAfter, move.HandAfter, playerHand, playerHasHiddenCards, rules, depth - 1, int.MinValue, int.MaxValue, false, useFallenAceWeight, aiOwner, playerOwner, null);

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

    private static int Minimax(HoneycombBoard board, List<HoneycombCard> aiHand, List<HoneycombCard> playerHand, bool playerHasHiddenCards, HashSet<HoneycombRule> rules, int depth, int alpha, int beta, bool isMaximizing, bool useFallenAceWeight, int aiOwner, int playerOwner, int? mandatedHandIndex)
    {
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

        if (!isMaximizing && playerHasHiddenCards)
        {
            return EvaluateBoard(board, rules, useFallenAceWeight, aiOwner, playerOwner);
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

        if (isMaximizing)
        {
            int maxEval = int.MinValue;
            foreach (var move in orderedMoves)
            {
                int eval = Minimax(move.BoardAfter, move.HandAfter, playerHand, playerHasHiddenCards, rules, depth - 1, alpha, beta, false, useFallenAceWeight, aiOwner, playerOwner, null);
                if (eval > maxEval) maxEval = eval;
                if (eval > alpha) alpha = eval;
                if (beta <= alpha) break;
            }
            return maxEval;
        }
        else
        {
            int minEval = int.MaxValue;
            foreach (var move in orderedMoves)
            {
                int eval = Minimax(move.BoardAfter, aiHand, move.HandAfter, playerHasHiddenCards, rules, depth - 1, alpha, beta, true, useFallenAceWeight, aiOwner, playerOwner, null);
                if (eval < minEval) minEval = eval;
                if (eval < beta) beta = eval;
                if (beta <= alpha) break;
            }
            return minEval;
        }
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
