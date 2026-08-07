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
    // [0, 1) double, used for weighted-value/symmetry/template rolls below.
    public double NextDouble() => (Next() >> 11) * (1.0 / (1UL << 53));
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

    // valueWeights/symmetryChance/templateShapes/templateShare all come from analyzing
    // the real FFXIV Triple Triad card set (tools/FFXIV_Triple_Triad_Cards.xlsx) against
    // this generator: the budget bands already matched the real per-star sum ranges
    // exactly, but real cards weren't uniformly random within that budget — they lean on
    // a favored value (7), are more lopsided (variance) than uniform sampling produces,
    // occasionally mirror Top/Bottom and Right/Left, and reuse a handful of "template"
    // stat-shapes across many different cards far more than chance would predict. These
    // four fields close each of those gaps. Mirrors the Swift port's Tier struct.
    private class TierDef
    {
        public int Stars { get; init; }
        public int MinStat { get; init; }
        public int MaxStat { get; init; }
        public int MinBudget { get; init; }
        public int MaxBudget { get; init; }
        public int Count { get; init; }
        // One weight per value from MinStat..MaxStat (index 0 == MinStat).
        public double[] ValueWeights { get; init; } = Array.Empty<double>();
        public double SymmetryChance { get; init; }
        public double TemplateShare { get; init; }
        public int[][] TemplateShapes { get; init; } = Array.Empty<int[]>();
    }

    private static readonly TierDef[] Tiers = new TierDef[]
    {
        new TierDef
        {
            Stars = 1, MinStat = 1, MaxStat = 7, MinBudget = 12, MaxBudget = 15, Count = 26,
            ValueWeights = new double[] { 18, 21, 17, 19, 11, 7, 7 },
            SymmetryChance = 0.038, TemplateShare = 0.15,
            TemplateShapes = new int[][]
            {
                new[] {1,1,4,7}, new[] {2,2,5,5}, new[] {1,1,5,6}, new[] {2,2,2,7}, new[] {1,2,3,7},
                new[] {3,3,3,4}, new[] {2,3,4,5}, new[] {2,2,4,6}, new[] {2,3,4,4}, new[] {2,3,3,4},
            }
        },
        new TierDef
        {
            Stars = 2, MinStat = 1, MaxStat = 7, MinBudget = 16, MaxBudget = 21, Count = 36,
            ValueWeights = new double[] { 5, 11, 13, 16, 17, 19, 20 },
            SymmetryChance = 0.052, TemplateShare = 0.15,
            TemplateShapes = new int[][]
            {
                new[] {1,3,7,7}, new[] {2,3,6,7}, new[] {1,6,7,7}, new[] {2,4,6,7}, new[] {2,2,7,7},
                new[] {3,3,6,7}, new[] {3,5,5,6}, new[] {2,6,6,6}, new[] {3,5,5,7}, new[] {3,4,6,6},
            }
        },
        new TierDef
        {
            Stars = 3, MinStat = 1, MaxStat = 8, MinBudget = 20, MaxBudget = 25, Count = 41,
            ValueWeights = new double[] { 8, 6, 8, 12, 9, 18, 21, 19 },
            SymmetryChance = 0.018, TemplateShare = 0.15,
            TemplateShapes = new int[][]
            {
                new[] {1,6,7,8}, new[] {4,4,7,8}, new[] {2,4,7,8}, new[] {1,6,7,7}, new[] {2,3,7,8},
                new[] {1,4,8,8}, new[] {3,3,7,8}, new[] {1,4,7,8}, new[] {3,5,6,8}, new[] {2,5,7,8},
            }
        },
        new TierDef
        {
            Stars = 4, MinStat = 1, MaxStat = 9, MinBudget = 24, MaxBudget = 28, Count = 21,
            ValueWeights = new double[] { 7, 4, 4, 5, 9, 10, 18, 22, 21 },
            SymmetryChance = 0.051, TemplateShare = 0.15,
            TemplateShapes = new int[][]
            {
                new[] {1,7,8,9}, new[] {4,6,6,8}, new[] {6,7,7,8}, new[] {1,8,8,8}, new[] {4,4,8,9},
                new[] {2,5,9,9}, new[] {1,5,9,9}, new[] {5,6,6,7}, new[] {6,6,8,8}, new[] {6,6,7,9},
            }
        },
        new TierDef
        {
            Stars = 5, MinStat = 1, MaxStat = 10, MinBudget = 25, MaxBudget = 30, Count = 14,
            ValueWeights = new double[] { 6, 4, 4, 6, 8, 10, 10, 11, 15, 26 },
            SymmetryChance = 0.014, TemplateShare = 0.15,
            TemplateShapes = new int[][]
            {
                new[] {1,7,8,9}, new[] {1,7,9,10}, new[] {2,5,10,10}, new[] {6,7,7,8}, new[] {1,8,8,8},
                new[] {4,4,8,9}, new[] {2,5,9,9}, new[] {4,6,8,10}, new[] {6,6,8,8}, new[] {6,7,7,10},
            }
        },
    };

    private static int WeightedValue(TierDef tier, ref SplitMix64 rng)
    {
        double total = 0;
        foreach (var w in tier.ValueWeights) total += w;
        double r = rng.NextDouble() * total;
        double cumulative = 0;
        for (int i = 0; i < tier.ValueWeights.Length; i++)
        {
            cumulative += tier.ValueWeights[i];
            if (r < cumulative) return tier.MinStat + i;
        }
        return tier.MaxStat;
    }

    private static int[] Shuffled(int[] source, ref SplitMix64 rng)
    {
        var arr = (int[])source.Clone();
        for (int i = arr.Length - 1; i > 0; i--)
        {
            int j = RandomExtensions.NextInt(ref rng, 0, i);
            (arr[i], arr[j]) = (arr[j], arr[i]);
        }
        return arr;
    }

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
                        if (tier.TemplateShapes.Length > 0 && rng.NextDouble() < tier.TemplateShare)
                        {
                            int idx = RandomExtensions.NextInt(ref rng, 0, tier.TemplateShapes.Length - 1);
                            stats = Shuffled(tier.TemplateShapes[idx], ref rng);
                        }
                        else if (rng.NextDouble() < tier.SymmetryChance)
                        {
                            int a = WeightedValue(tier, ref rng);
                            int b = WeightedValue(tier, ref rng);
                            stats = new[] { a, b, a, b };
                        }
                        else
                        {
                            stats[0] = WeightedValue(tier, ref rng);
                            stats[1] = WeightedValue(tier, ref rng);
                            stats[2] = WeightedValue(tier, ref rng);
                            stats[3] = WeightedValue(tier, ref rng);
                        }

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
