using System;
using System.Collections.Generic;

namespace SoliBee.Core.Models;

public struct SplitMix64
{
    private ulong _state;
    public SplitMix64(ulong seed) { _state = seed; }
    public ulong Next()
    {
        unchecked
        {
            _state += 0x9E3779B97F4A7C15UL;
            ulong z = _state;
            z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
            z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
            return z ^ (z >> 31);
        }
    }
}

public static class RandomExtensions
{
    // Lemire's method matching Swift's Int.random(in: range, using: &rng)
    public static int NextInt(ref SplitMix64 rng, int min, int max)
    {
        ulong bound = (ulong)(max - min + 1);
        ulong x = rng.Next();
        ulong m = Math.BigMul(x, bound, out ulong low);
        
        if (low < bound)
        {
            ulong t = (0UL - bound) % bound;
            while (low < t)
            {
                x = rng.Next();
                m = Math.BigMul(x, bound, out low);
            }
        }
        return min + (int)m;
    }
}

public static class HoneycombCardGenerator
{
    private static readonly string[] Suits = { "S", "H", "D", "C" };
    private static readonly string[] SuitNames = { "Spade", "Heart", "Diamond", "Club" };
    
    private class TierDef
    {
        public int Stars { get; init; }
        public int MinStat { get; init; }
        public int MaxStat { get; init; }
        public int MinBudget { get; init; }
        public int MaxBudget { get; init; }
        public int Count { get; init; }
    }

    private static readonly TierDef[] Tiers = new TierDef[]
    {
        new TierDef { Stars = 1, MinStat = 1, MaxStat = 7, MinBudget = 12, MaxBudget = 15, Count = 26 },
        new TierDef { Stars = 2, MinStat = 1, MaxStat = 7, MinBudget = 16, MaxBudget = 21, Count = 36 },
        new TierDef { Stars = 3, MinStat = 1, MaxStat = 8, MinBudget = 20, MaxBudget = 25, Count = 41 },
        new TierDef { Stars = 4, MinStat = 1, MaxStat = 9, MinBudget = 24, MaxBudget = 28, Count = 21 },
        new TierDef { Stars = 5, MinStat = 1, MaxStat = 10, MinBudget = 25, MaxBudget = 30, Count = 14 }
    };

    public static List<HoneycombCardData> GenerateAllCards(ulong seed)
    {
        var rng = new SplitMix64(seed);
        var cards = new List<HoneycombCardData>(552);
        int globalId = 1;

        for (int suitIdx = 0; suitIdx < Suits.Length; suitIdx++)
        {
            var suitCode = Suits[suitIdx];
            var suitName = SuitNames[suitIdx];
            var seenCombos = new HashSet<(int, int, int, int)>();
            int suitCardCount = 1;

            foreach (var tier in Tiers)
            {
                for (int i = 0; i < tier.Count; i++)
                {
                    int[] stats = new int[4];
                    while (true)
                    {
                        stats[0] = RandomExtensions.NextInt(ref rng, tier.MinStat, tier.MaxStat);
                        stats[1] = RandomExtensions.NextInt(ref rng, tier.MinStat, tier.MaxStat);
                        stats[2] = RandomExtensions.NextInt(ref rng, tier.MinStat, tier.MaxStat);
                        stats[3] = RandomExtensions.NextInt(ref rng, tier.MinStat, tier.MaxStat);
                        
                        int sum = stats[0] + stats[1] + stats[2] + stats[3];
                        if (sum >= tier.MinBudget && sum <= tier.MaxBudget)
                        {
                            var combo = (stats[0], stats[1], stats[2], stats[3]);
                            if (seenCombos.Add(combo))
                            {
                                break;
                            }
                        }
                    }

                    cards.Add(new HoneycombCardData
                    {
                        Id = globalId++,
                        Name = $"{suitName} {suitCardCount++}",
                        Stars = tier.Stars,
                        Stats = stats,
                        Suit = suitCode
                    });
                }
            }
        }
        return cards;
    }
}
