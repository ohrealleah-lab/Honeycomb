using System.Collections.Generic;
using System.Linq;

namespace SoliBee.Core.Models;

public static class PokerHandEvaluator
{
    public static PokerHandResult Evaluate(Card[] cards)
    {
        if (cards.Length != 5)
            return new PokerHandResult(PokerHandRank.HighCard);

        var ranks = cards.Select(c => c.Rank).ToArray();
        var suits = cards.Select(c => c.Suit).ToArray();

        var freq = new Dictionary<int, int>();
        foreach (var r in ranks)
            freq[r] = freq.GetValueOrDefault(r) + 1;

        var groups = freq.Values.OrderByDescending(v => v).ToArray();
        var byFreq = freq.OrderByDescending(kv => kv.Value).ThenByDescending(kv => kv.Key == 1 ? 14 : kv.Key).ToArray();

        // Five of a kind (Deuces Wild substitution only)
        if (groups[0] == 5)
            return new PokerHandResult(PokerHandRank.FiveOfAKind, QuadRank: byFreq[0].Key);

        bool isFlush = suits.All(s => s == suits[0]);

        bool isStraight = false;
        bool isRoyal = false;

        if (freq.Count == 5)
        {
            var sorted = ranks.OrderBy(r => r).ToArray();

            // Ace-high straight: A-K-Q-J-10
            if (sorted[0] == 1 && sorted[1] == 10 && sorted[2] == 11 && sorted[3] == 12 && sorted[4] == 13)
            {
                isStraight = true;
                if (isFlush) isRoyal = true;
            }
            // Normal or wheel (A-2-3-4-5 has sorted[4]-sorted[0]=4 too)
            else if (sorted[4] - sorted[0] == 4)
            {
                isStraight = true;
            }
        }

        if (isRoyal)     return new PokerHandResult(PokerHandRank.RoyalFlush);
        if (isStraight && isFlush) return new PokerHandResult(PokerHandRank.StraightFlush);
        if (groups[0] == 4)
            return new PokerHandResult(PokerHandRank.FourOfAKind, QuadRank: byFreq[0].Key);
        if (groups[0] == 3 && groups.Length > 1 && groups[1] == 2)
            return new PokerHandResult(PokerHandRank.FullHouse);
        if (isFlush)     return new PokerHandResult(PokerHandRank.Flush);
        if (isStraight)  return new PokerHandResult(PokerHandRank.Straight);
        if (groups[0] == 3)
            return new PokerHandResult(PokerHandRank.ThreeOfAKind);
        if (groups[0] == 2 && groups.Length > 1 && groups[1] == 2)
        {
            // Highest pair rank (ace counts high for display)
            int hi = byFreq.Where(kv => kv.Value == 2).Max(kv => kv.Key == 1 ? 14 : kv.Key);
            return new PokerHandResult(PokerHandRank.TwoPair, PairRank: hi == 14 ? 1 : hi);
        }
        if (groups[0] == 2)
        {
            int pairRank = byFreq.First(kv => kv.Value == 2).Key;
            return new PokerHandResult(PokerHandRank.OnePair, PairRank: pairRank);
        }
        return new PokerHandResult(PokerHandRank.HighCard);
    }
}
