using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace SoliBee.Core.Models;

public class HoneycombDatabase
{
    public static HoneycombDatabase Shared { get; } = new HoneycombDatabase();

    public ulong CurrentSeed { get; private set; }
    public IReadOnlyList<HoneycombCardData> AllCards { get; private set; } = Array.Empty<HoneycombCardData>();

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
                        if (!string.IsNullOrEmpty(path))
                        {
                            return path;
                        }
                    }
                }
            }
        }
        catch { }

        var fallbackDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SoliBee");
        return fallbackDir;
    }

    private static string DataDir => GetLocalFolderPath();
    private static string SeedPath => Path.Combine(DataDir, "honeycomb_seed.json");

    private HoneycombDatabase()
    {
        LoadOrGenerateSeed();
    }

    private void LoadOrGenerateSeed()
    {
        ulong seed;
        bool loaded = false;
        try
        {
            if (File.Exists(SeedPath))
            {
                var text = File.ReadAllText(SeedPath);
                if (ulong.TryParse(text.Trim(), out seed))
                {
                    CurrentSeed = seed;
                    loaded = true;
                }
            }
        }
        catch { }

        if (!loaded)
        {
            seed = (ulong)Random.Shared.NextInt64();
            CurrentSeed = seed;
            PersistSeed();
        }

        AllCards = HoneycombCardGenerator.GenerateAllCards(CurrentSeed);
    }

    private void PersistSeed()
    {
        try
        {
            Directory.CreateDirectory(DataDir);
            File.WriteAllText(SeedPath, CurrentSeed.ToString());
        }
        catch { }
    }

    public void Reseed()
    {
        CurrentSeed = (ulong)Random.Shared.NextInt64();
        PersistSeed();
        AllCards = HoneycombCardGenerator.GenerateAllCards(CurrentSeed);
    }

    public HoneycombCardData? Card(int id)
    {
        return AllCards.FirstOrDefault(c => c.Id == id);
    }

    public List<HoneycombCardData> RandomCards(int stars, int count)
    {
        var tierPool = AllCards.Where(c => c.Stars == stars).ToList();
        var result = new List<HoneycombCardData>(count);
        for (int i = 0; i < count; i++)
        {
            result.Add(tierPool[Random.Shared.Next(tierPool.Count)]);
        }
        return result;
    }

    public List<HoneycombCardData> RulesAwareCards(int stars, int count, bool preferLowStats)
    {
        var tierPool = AllCards.Where(c => c.Stars == stars).ToList();

        var scoredPool = tierPool.Select(c =>
        {
            double mean = c.Stats.Average();
            double variance = c.Stats.Average(s => Math.Pow(s - mean, 2));
            double score = c.Stats.Sum() + variance;
            return (Card: c, Score: score);
        }).ToList();

        double minScore = scoredPool.Count > 0 ? scoredPool.Min(x => x.Score) : 0;
        double maxScore = scoredPool.Count > 0 ? scoredPool.Max(x => x.Score) : 0;
        double scoreRange = Math.Max(maxScore - minScore, 0.0001);

        // Every card in the tier stays eligible (weighted, not hard-cutoff) so no
        // card is permanently unreachable — a strict top-slice cutoff here previously
        // meant the bottom ~60% of every tier could never appear as an opponent card.
        // Well-suited cards are still far more likely to be drawn thanks to the floor
        // below keeping the weight spread wide.
        double SuitabilityWeight(double score)
        {
            double normalized = (score - minScore) / scoreRange;
            double favored = preferLowStats ? (1 - normalized) : normalized;
            return 0.2 + favored;
        }

        var candidates = scoredPool.ToList();

        var result = new List<HoneycombCardData>();
        int[] edgeCounts = new int[4];

        for (int i = 0; i < count; i++)
        {
            if (candidates.Count == 0)
            {
                var pick = tierPool[Random.Shared.Next(tierPool.Count)];
                result.Add(pick);
                continue;
            }

            double[] weights = new double[candidates.Count];
            double totalWeight = 0;
            for (int j = 0; j < candidates.Count; j++)
            {
                int domEdge = DominantEdge(candidates[j].Card);
                weights[j] = SuitabilityWeight(candidates[j].Score) / (edgeCounts[domEdge] + 1);
                totalWeight += weights[j];
            }

            double r = Random.Shared.NextDouble() * totalWeight;
            double cumulative = 0;
            int pickIndex = candidates.Count - 1;
            for (int j = 0; j < candidates.Count; j++)
            {
                cumulative += weights[j];
                if (r <= cumulative)
                {
                    pickIndex = j;
                    break;
                }
            }

            var selected = candidates[pickIndex].Card;
            result.Add(selected);
            edgeCounts[DominantEdge(selected)]++;
            candidates.RemoveAt(pickIndex);
        }

        return result;
    }

    private static int DominantEdge(HoneycombCardData card)
    {
        int maxIndex = 0;
        int maxVal = card.Stats[0];
        for (int i = 1; i < 4; i++)
        {
            if (card.Stats[i] > maxVal)
            {
                maxVal = card.Stats[i];
                maxIndex = i;
            }
        }
        return maxIndex;
    }
}
