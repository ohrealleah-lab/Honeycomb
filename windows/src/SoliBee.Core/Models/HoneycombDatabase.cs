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

    private static readonly string DataDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SoliBee");
    private static readonly string SeedPath = Path.Combine(DataDir, "honeycomb_seed.json");

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
        });

        if (preferLowStats)
            scoredPool = scoredPool.OrderBy(x => x.Score);
        else
            scoredPool = scoredPool.OrderByDescending(x => x.Score);

        var sortedPool = scoredPool.Select(x => x.Card).ToList();
        int candidateCount = Math.Max(count, (int)Math.Ceiling(sortedPool.Count * 0.4));
        var candidates = sortedPool.Take(candidateCount).ToList();
        
        var result = new List<HoneycombCardData>();
        int[] edgeCounts = new int[4];

        for (int i = 0; i < count; i++)
        {
            if (candidates.Count == 0)
            {
                var pick = sortedPool[Random.Shared.Next(candidateCount)];
                result.Add(pick);
                continue;
            }

            double[] weights = new double[candidates.Count];
            double totalWeight = 0;
            for (int j = 0; j < candidates.Count; j++)
            {
                int domEdge = DominantEdge(candidates[j]);
                weights[j] = 1.0 / (edgeCounts[domEdge] + 1);
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

            var selected = candidates[pickIndex];
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
