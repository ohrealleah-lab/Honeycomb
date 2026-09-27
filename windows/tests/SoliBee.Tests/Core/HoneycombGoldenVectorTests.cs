using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using Xunit;
using SoliBee.Core.Models;

namespace SoliBee.Tests.Core;

// Cross-platform parity for HoneycombBoard's capture engine. The vectors in
// shared/Honeycomb/TestVectors/honeycomb_capture_vectors.json are generated from the
// Mac (Swift) engine — the source of truth — by mac/SoliBeeTests/HoneycombGoldenVectorTests.swift.
// Each case is a board + one placement (or Capped Brood reveal) with the exact outcome
// Mac produces; this replays every case against the Windows engine. A failure here
// means Windows' rules have drifted from Mac's.
public class HoneycombGoldenVectorTests
{
    private static string VectorsPath()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null)
        {
            var f = Path.Combine(dir.FullName, "shared", "Honeycomb", "TestVectors", "honeycomb_capture_vectors.json");
            if (File.Exists(f)) return f;
            dir = dir.Parent;
        }
        throw new FileNotFoundException("honeycomb_capture_vectors.json not found above " + AppContext.BaseDirectory);
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

    private static HoneycombCard Card(JsonObject o)
    {
        int id = o["id"]!.GetValue<int>();
        var data = new HoneycombCardData
        {
            Id = id,
            Name = "V" + id,
            Stars = 3,
            Stats = o["stats"]!.AsArray().Select(n => n!.GetValue<int>()).ToArray(),
            Suit = o["suit"]!.GetValue<string>()
        };
        return new HoneycombCard(data, o["owner"]!.GetValue<string>() == "player" ? 1 : -1)
        {
            IsFaceDown = o["faceDown"]!.GetValue<bool>()
        };
    }

    private static JsonObject Replay(JsonObject c)
    {
        var rules = new HashSet<HoneycombRule>(c["rules"]!.AsArray().Select(n => Rule(n!.GetValue<string>())));
        var board = new HoneycombBoard
        {
            AscensionDescensionSuits = c["ascensionSuits"]!.AsArray().Select(n => n!.GetValue<string>()).ToList()
        };
        var cells = c["board"]!.AsArray();
        for (int i = 0; i < 9; i++)
            if (cells[i] is JsonObject co) board.Cells[i].Card = Card(co);

        var op = c["op"]!.AsObject();
        int index = op["index"]!.GetValue<int>();
        var flips = op["kind"]!.GetValue<string>() == "reveal"
            ? board.RevealFaceDownCard(index, rules)
            : board.PlaceCard(Card(op["card"]!.AsObject()), index, rules);

        JsonArray CellsOf(Func<HoneycombCard, JsonNode> f) =>
            new(board.Cells.Select(cell => cell.Card == null ? null : f(cell.Card)).ToArray());

        return new JsonObject
        {
            ["owners"] = CellsOf(card => JsonValue.Create(card.Owner == 1 ? "player" : "opponent")!),
            ["modifiers"] = CellsOf(card => JsonValue.Create(card.Modifier)),
            ["faceDown"] = CellsOf(card => JsonValue.Create(card.IsFaceDown)),
            ["flips"] = new JsonArray(flips.OrderBy(x => x).Select(x => (JsonNode)JsonValue.Create(x)).ToArray()),
            ["sameTriggered"] = board.LastSameTriggered,
            ["plusTriggered"] = board.LastPlusTriggered,
            ["fallenAceTriggered"] = board.LastFallenAceTriggered,
            ["comboFlipCount"] = board.LastComboFlipCount,
            ["samePlusTriggers"] = board.SessionSamePlusTriggers,
            ["fallenAceCaptures"] = board.SessionFallenAceCaptures,
        };
    }

    [Fact]
    public void CaptureEngineMatchesMacVectors()
    {
        var root = JsonNode.Parse(File.ReadAllText(VectorsPath()))!.AsObject();
        var cases = root["cases"]!.AsArray().Select(n => n!.AsObject()).ToList();
        Assert.True(cases.Count >= 100, $"only {cases.Count} capture vectors loaded — file truncated?");

        var failures = new List<string>();
        foreach (var c in cases)
        {
            var expected = c["expect"]!.AsObject();
            var actual = Replay(c);
            var diffKeys = expected.Select(kv => kv.Key)
                .Where(k => !JsonNode.DeepEquals(expected[k], actual[k]))
                .ToList();
            if (diffKeys.Count > 0)
            {
                failures.Add($"{c["name"]} rules={c["rules"]!.ToJsonString()} differs in [{string.Join(", ", diffKeys)}]: " +
                    string.Join("; ", diffKeys.Select(k => $"{k} expected={expected[k]?.ToJsonString()} actual={actual[k]?.ToJsonString()}")));
            }
        }
        Assert.True(failures.Count == 0,
            $"{failures.Count}/{cases.Count} capture vectors diverge from Mac:\n" + string.Join("\n", failures.Take(15)));
    }
}
