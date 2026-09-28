using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json.Nodes;
using Xunit;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;

namespace SoliBee.Tests.Core;

// Cross-platform parity for Video Poker hand scoring. The hands and expected
// (name, payout) at bet 1 and bet 5 for every variant in
// shared/VideoPoker/TestVectors/videopoker_hand_vectors.json are generated from Mac's
// VideoPokerViewModel.scoreHand (mac/SoliBeeTests/VideoPokerVectorTests.swift).
public class VideoPokerVectorTests
{
    private static string VectorsPath()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null)
        {
            var f = Path.Combine(dir.FullName, "shared", "VideoPoker", "TestVectors", "videopoker_hand_vectors.json");
            if (File.Exists(f)) return f;
            dir = dir.Parent;
        }
        throw new FileNotFoundException("videopoker_hand_vectors.json not found above " + AppContext.BaseDirectory);
    }

    private static readonly Dictionary<string, VideoPokerVariant> Variants = new()
    {
        ["jacksOrBetter"] = VideoPokerVariant.JacksOrBetter,
        ["deucesWild"] = VideoPokerVariant.DeucesWild,
        ["bonusPoker"] = VideoPokerVariant.BonusPoker,
    };

    private static Card ToCard(string code)
    {
        var suit = code[^1] switch
        {
            'S' => CardSuit.Spades, 'H' => CardSuit.Hearts, 'D' => CardSuit.Diamonds, 'C' => CardSuit.Clubs,
            _ => throw new ArgumentException(code)
        };
        return new Card(code, suit, int.Parse(code[..^1]), true);
    }

    // Windows' Deuces Wild table keeps the short internal names "Natural Royal"/"Wild
    // Royal" (they're also the HandCounts stats keys, so renaming would split players'
    // history); VideoPokerView localizes both to the same "Natural/Wild Royal Flush"
    // text Mac shows, so they're the same hand for parity purposes.
    private static string Canonical(string? name) => name switch
    {
        null => "No Win",
        "Natural Royal" => "Natural Royal Flush",
        "Wild Royal" => "Wild Royal Flush",
        _ => name,
    };

    [Fact]
    public void ScoringMatchesMacVectors()
    {
        var cases = JsonNode.Parse(File.ReadAllText(VectorsPath()))!["cases"]!.AsArray();
        Assert.True(cases.Count >= 1000, $"only {cases.Count} video poker vectors loaded — file truncated?");
        var failures = new List<string>();
        foreach (var c in cases)
        {
            var hand = c!["hand"]!.AsArray().Select(n => ToCard(n!.GetValue<string>())).ToArray();
            foreach (var (key, variant) in Variants)
            {
                var e = c["expect"]![key]!.AsArray();
                var one = VideoPokerViewModel.ScoreHand(hand, variant, 1);
                var five = VideoPokerViewModel.ScoreHand(hand, variant, 5);
                string expected = $"{e[0]}/{e[1]}/{e[2]}/{e[3]}";
                string actual = $"{Canonical(one.Entry?.HandName)}/{one.Payout}/{Canonical(five.Entry?.HandName)}/{five.Payout}";
                if (expected != actual)
                    failures.Add($"{c["hand"]!.ToJsonString()} {key} expected={expected} actual={actual}");
            }
        }
        Assert.True(failures.Count == 0, $"{failures.Count} video poker scorings diverge from Mac:\n" + string.Join("\n", failures.Take(25)));
    }
}
