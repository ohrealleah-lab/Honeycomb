package com.leah.honeycomb.honeycomb

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
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

// Cross-platform parity for the Honeycomb AI and Hint searches. The positions in
// shared/Honeycomb/TestVectors/honeycomb_ai_vectors.json and their expected results are
// generated from the Mac (Swift) HoneycombAI — the source of truth — by
// mac/SoliBeeTests/HoneycombAIVectorTests.swift. Compares Medium's best capture count and
// full tie set, and the Hard/Ultra Hard/Hint root minimax scores (see that file for why
// the minimax tie set itself isn't compared).
class HoneycombAIVectorTests {

    private fun vectorsFile(): File {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val f = File(dir, "shared/Honeycomb/TestVectors/honeycomb_ai_vectors.json")
            if (f.exists()) return f
            dir = dir.parentFile
        }
        error("honeycomb_ai_vectors.json not found above ${File("").absolutePath}")
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

    private fun data(o: JsonObject): HoneycombCardData {
        val id = o["id"]!!.jsonPrimitive.int
        return HoneycombCardData(id = id, name = "V$id", stars = 3,
            stats = o["stats"]!!.jsonArray.map { it.jsonPrimitive.int },
            suit = o["suit"]!!.jsonPrimitive.content)
    }

    private fun evaluate(c: JsonObject): JsonObject {
        val rules = c["rules"]!!.jsonArray.map { rule(it.jsonPrimitive.content) }
        val suits = c["ascensionSuits"]!!.jsonArray.map { it.jsonPrimitive.content }.toSet()
        // Built by re-placing each card with captures skipped, so Ascension/Descension
        // modifiers come out exactly as live play (and the Swift generator) computes them.
        val board = HoneycombBoard().apply { ascensionDescensionSuits = suits }
        c["board"]!!.jsonArray.forEachIndexed { i, e ->
            if (e is JsonObject) {
                val card = HoneycombCard(data(e), if (e["owner"]!!.jsonPrimitive.content == "player") CardOwner.Player else CardOwner.Opponent)
                card.isFaceDown = e["faceDown"]!!.jsonPrimitive.boolean
                board.placeCard(card, i, rules, skipCaptures = true)
            }
        }
        val aiHand = c["aiHand"]!!.jsonArray.map { data(it.jsonObject) }
        val playerHand = c["playerHand"]!!.jsonArray.map { data(it.jsonObject) }
        val empties = board.cells.indices.filter { board.cells[it].card == null }

        val greedy = HoneycombAI.greedySearch(board, aiHand, aiHand.indices.toList(), empties, rules)
        val hard = HoneycombAI.minimaxSearch(board, aiHand, playerHand, aiHand.indices.toList(), empties, rules, 5, false)
        val ultra = HoneycombAI.minimaxSearch(board, aiHand, playerHand, aiHand.indices.toList(), empties, rules, 6, true)
        val hint = HoneycombAI.hintSearchScore(board, playerHand, aiHand, playerHand.indices.toList(), empties, rules)

        val moves = greedy.second.sortedWith(compareBy({ it.first }, { it.second }))
        return JsonObject(mapOf(
            "mediumScore" to JsonPrimitive(greedy.first),
            "mediumMoves" to JsonArray(moves.map { JsonArray(listOf(JsonPrimitive(it.first), JsonPrimitive(it.second))) }),
            "hardScore" to JsonPrimitive(hard.first),
            "ultraHardScore" to JsonPrimitive(ultra.first),
            "hintScore" to JsonPrimitive(hint)
        ))
    }

    @Test
    fun aiMatchesMacVectors() {
        val cases = Json.parseToJsonElement(vectorsFile().readText()).jsonObject["cases"]!!.jsonArray.map { it.jsonObject }
        if (cases.size < 50) fail("only ${cases.size} AI vectors loaded — file truncated?")
        val failures = mutableListOf<String>()
        for (c in cases) {
            val expected = c["expect"]!!.jsonObject
            val actual = evaluate(c)
            val diff = expected.keys.filter { expected[it] != actual[it] }
            if (diff.isNotEmpty()) {
                failures += "${c["name"]!!.jsonPrimitive.content} rules=${c["rules"]} " +
                    diff.joinToString("; ") { "$it expected=${expected[it]} actual=${actual[it]}" }
            }
        }
        if (failures.isNotEmpty()) {
            fail("${failures.size}/${cases.size} AI vectors diverge from Mac:\n" + failures.take(15).joinToString("\n"))
        }
    }
}
