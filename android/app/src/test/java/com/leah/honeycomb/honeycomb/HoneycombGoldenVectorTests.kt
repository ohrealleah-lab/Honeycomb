package com.leah.honeycomb.honeycomb

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.fail
import org.junit.Test
import java.io.File

// Cross-platform parity for HoneycombBoard's capture engine. The vectors in
// shared/Honeycomb/TestVectors/honeycomb_capture_vectors.json are generated from the
// Mac (Swift) engine — the source of truth — by mac/SoliBeeTests/HoneycombGoldenVectorTests.swift.
// Each case is a board + one placement (or Capped Brood reveal) with the exact outcome
// Mac produces; this replays every case against the Android engine. A failure here
// means Android's rules have drifted from Mac's.
class HoneycombGoldenVectorTests {

    private fun vectorsFile(): File {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val f = File(dir, "shared/Honeycomb/TestVectors/honeycomb_capture_vectors.json")
            if (f.exists()) return f
            dir = dir.parentFile
        }
        error("honeycomb_capture_vectors.json not found above ${File("").absolutePath}")
    }

    private fun rule(s: String): HoneycombRule = when (s) {
        "ascension" -> HoneycombRule.Ascension
        "descension" -> HoneycombRule.Descension
        "same" -> HoneycombRule.Same
        "plus" -> HoneycombRule.Plus
        "fallenAce" -> HoneycombRule.FallenAce
        "reverse" -> HoneycombRule.Reverse
        else -> error("unknown rule $s")
    }

    private fun card(o: JsonObject): HoneycombCard {
        val id = o["id"]!!.jsonPrimitive.int
        val c = HoneycombCard(
            data = HoneycombCardData(
                id = id, name = "V$id", stars = 3,
                stats = o["stats"]!!.jsonArray.map { it.jsonPrimitive.int },
                suit = o["suit"]!!.jsonPrimitive.content
            ),
            owner = if (o["owner"]!!.jsonPrimitive.content == "player") CardOwner.Player else CardOwner.Opponent
        )
        c.isFaceDown = o["faceDown"]!!.jsonPrimitive.boolean
        return c
    }

    private fun replay(c: JsonObject): JsonObject {
        val rules = c["rules"]!!.jsonArray.map { rule(it.jsonPrimitive.content) }
        val board = HoneycombBoard()
        board.ascensionDescensionSuits = c["ascensionSuits"]!!.jsonArray.map { it.jsonPrimitive.content }.toSet()
        c["board"]!!.jsonArray.forEachIndexed { i, e ->
            if (e is JsonObject) board.cells[i].card = card(e)
        }
        val op = c["op"]!!.jsonObject
        val index = op["index"]!!.jsonPrimitive.int
        val flips = if (op["kind"]!!.jsonPrimitive.content == "reveal") {
            board.revealFaceDownCard(index, rules)
        } else {
            board.placeCard(card(op["card"]!!.jsonObject), index, rules)
        }
        fun cellsOf(f: (HoneycombCard) -> JsonElement) =
            JsonArray(board.cells.map { cell -> cell.card?.let(f) ?: JsonNull })
        return JsonObject(mapOf(
            "owners" to cellsOf { JsonPrimitive(if (it.owner == CardOwner.Player) "player" else "opponent") },
            "modifiers" to cellsOf { JsonPrimitive(it.modifier) },
            "faceDown" to cellsOf { JsonPrimitive(it.isFaceDown) },
            "flips" to JsonArray(flips.sorted().map { JsonPrimitive(it) }),
            "sameTriggered" to JsonPrimitive(board.lastSameTriggered),
            "plusTriggered" to JsonPrimitive(board.lastPlusTriggered),
            "fallenAceTriggered" to JsonPrimitive(board.lastFallenAceTriggered),
            "comboFlipCount" to JsonPrimitive(board.lastComboFlipCount),
            "samePlusTriggers" to JsonPrimitive(board.sessionSamePlusTriggers),
            "fallenAceCaptures" to JsonPrimitive(board.sessionFallenAceCaptures)
        ))
    }

    @Test
    fun captureEngineMatchesMacVectors() {
        val root = Json.parseToJsonElement(vectorsFile().readText()).jsonObject
        val cases = root["cases"]!!.jsonArray.map { it.jsonObject }
        if (cases.size < 100) fail("only ${cases.size} capture vectors loaded — file truncated?")
        val failures = mutableListOf<String>()
        for (c in cases) {
            val expected = c["expect"]!!.jsonObject
            val actual = replay(c)
            val diffKeys = expected.keys.filter { expected[it] != actual[it] }
            if (diffKeys.isNotEmpty()) {
                failures += "${c["name"]!!.jsonPrimitive.content} rules=${c["rules"]} differs in $diffKeys: " +
                    diffKeys.joinToString("; ") { "$it expected=${expected[it]} actual=${actual[it]}" }
            }
        }
        if (failures.isNotEmpty()) {
            fail("${failures.size}/${cases.size} capture vectors diverge from Mac:\n" + failures.take(15).joinToString("\n"))
        }
    }
}
