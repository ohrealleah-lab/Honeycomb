using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json.Nodes;
using Xunit;
using SoliBee.Core.Models;

namespace SoliBee.Tests.Core;

// Cross-platform parity for the Honeycomb AI and Hint searches. The positions in
// shared/Honeycomb/TestVectors/honeycomb_ai_vectors.json and their expected results are
// generated from the Mac (Swift) HoneycombAI — the source of truth — by
// mac/SoliBeeTests/HoneycombAIVectorTests.swift. Compares Medium's best capture count and
// full tie set, and the Hard/Ultra Hard/Hint root minimax scores (see that file for why
// the minimax tie set itself isn't compared). Hint is checked at Mac's 6 plies.
public class HoneycombAIVectorTests
{
    private const int Player = 1;
    private const int Opponent = -1;

    private static string VectorsPath()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null)
        {
            var f = Path.Combine(dir.FullName, "shared", "Honeycomb", "TestVectors", "honeycomb_ai_vectors.json");
            if (File.Exists(f)) return f;
            dir = dir.Parent;
        }
        throw new FileNotFoundException("honeycomb_ai_vectors.json not found above " + AppContext.BaseDirectory);
    }

    private static HoneycombRule Rule(string s) => s switch
    {
        "ascension" => HoneycombRule.Ascension,
        "descension" => HoneycombRule.Descension,
        "same" => HoneycombRule.Same,
        "plus" => HoneycombRule.Plus,
        "fallenAce" => HoneycombRule.FallenAce,
        "reverse" => HoneycombRule.Reverse,
        _ => throw new ArgumentException("unknown rule " + s)
    };

    private static HoneycombCardData Data(JsonObject o)
    {
        int id = o["id"]!.GetValue<int>();
        return new HoneycombCardData
        {
            Id = id, Name = "V" + id, Stars = 3,
            Stats = o["stats"]!.AsArray().Select(n => n!.GetValue<int>()).ToArray(),
            Suit = o["suit"]!.GetValue<string>()
        };
    }

    private static JsonObject Evaluate(JsonObject c)
    {
        var rules = new HashSet<HoneycombRule>(c["rules"]!.AsArray().Select(n => Rule(n!.GetValue<string>())));
        // Built by re-placing each card with captures skipped, so Ascension/Descension
        // modifiers come out exactly as live play (and the Swift generator) computes them.
        var board = new HoneycombBoard
        {
            AscensionDescensionSuits = c["ascensionSuits"]!.AsArray().Select(n => n!.GetValue<string>()).ToList()
        };
        var cells = c["board"]!.AsArray();
        for (int i = 0; i < 9; i++)
        {
            if (cells[i] is not JsonObject co) continue;
            var card = new HoneycombCard(Data(co), co["owner"]!.GetValue<string>() == "player" ? Player : Opponent)
            {
                IsFaceDown = co["faceDown"]!.GetValue<bool>()
            };
            board.PlaceCard(card, i, rules, skipCaptures: true);
        }
        var aiHand = c["aiHand"]!.AsArray().Select(n => new HoneycombCard(Data(n!.AsObject()), Opponent)).ToList();
        var playerHand = c["playerHand"]!.AsArray().Select(n => new HoneycombCard(Data(n!.AsObject()), Player)).ToList();

        var greedy = HoneycombAI.GreedySearch(board, aiHand, rules, Opponent, null);
        var hard = HoneycombAI.MinimaxSearch(board, aiHand, playerHand, rules, 5, false, Opponent, Player, null);
        var ultra = HoneycombAI.MinimaxSearch(board, aiHand, playerHand, rules, 6, true, Opponent, Player, null);
        var hint = HoneycombAI.MinimaxSearch(board, playerHand, aiHand, rules, 6, true, Player, Opponent, null);

        var moves = greedy.Moves.OrderBy(m => m.HandIndex).ThenBy(m => m.CellIndex)
            .Select(m => (JsonNode)new JsonArray(JsonValue.Create(m.HandIndex), JsonValue.Create(m.CellIndex))).ToArray();
        return new JsonObject
        {
            ["mediumScore"] = greedy.Score,
            ["mediumMoves"] = new JsonArray(moves),
            ["hardScore"] = hard.Score,
            ["ultraHardScore"] = ultra.Score,
            ["hintScore"] = hint.Score,
        };
    }

    [Fact]
    public void AiMatchesMacVectors()
    {
        var cases = JsonNode.Parse(File.ReadAllText(VectorsPath()))!["cases"]!.AsArray().Select(n => n!.AsObject()).ToList();
        Assert.True(cases.Count >= 50, $"only {cases.Count} AI vectors loaded — file truncated?");
        var failures = new List<string>();
        foreach (var c in cases)
        {
            var expected = c["expect"]!.AsObject();
            var actual = Evaluate(c);
            var diff = expected.Select(kv => kv.Key).Where(k => !JsonNode.DeepEquals(expected[k], actual[k])).ToList();
            if (diff.Count > 0)
                failures.Add($"{c["name"]} rules={c["rules"]!.ToJsonString()} " +
                    string.Join("; ", diff.Select(k => $"{k} expected={expected[k]?.ToJsonString()} actual={actual[k]?.ToJsonString()}")));
        }
        Assert.True(failures.Count == 0, $"{failures.Count}/{cases.Count} AI vectors diverge from Mac:\n" + string.Join("\n", failures.Take(15)));
    }
}
