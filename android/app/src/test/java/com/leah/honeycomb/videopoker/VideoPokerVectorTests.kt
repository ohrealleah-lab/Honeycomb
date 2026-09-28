package com.leah.honeycomb.videopoker

import com.leah.honeycomb.Card
import com.leah.honeycomb.Suit
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.fail
import org.junit.Test
import java.io.File

// Cross-platform parity for Video Poker hand scoring. The hands and expected
// (name, payout) at bet 1 and bet 5 for every variant in
// shared/VideoPoker/TestVectors/videopoker_hand_vectors.json are generated from Mac's
// VideoPokerViewModel.scoreHand (mac/SoliBeeTests/VideoPokerVectorTests.swift).
class VideoPokerVectorTests {

    private fun vectorsFile(): File {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val f = File(dir, "shared/VideoPoker/TestVectors/videopoker_hand_vectors.json")
            if (f.exists()) return f
            dir = dir.parentFile
        }
        error("videopoker_hand_vectors.json not found above ${File("").absolutePath}")
    }

    private val variants = mapOf(
        "jacksOrBetter" to VideoPokerVariant.JacksOrBetter,
        "deucesWild" to VideoPokerVariant.DeucesWild,
        "bonusPoker" to VideoPokerVariant.BonusPoker
    )

    private fun card(code: String): Card {
        val suit = when (code.last()) {
            'S' -> Suit.Spades; 'H' -> Suit.Hearts; 'D' -> Suit.Diamonds; 'C' -> Suit.Clubs
            else -> error("bad suit in $code")
        }
        return Card(suit = suit, rank = code.dropLast(1).toInt(), faceUp = true)
    }

    @Test
    fun scoringMatchesMacVectors() {
        val cases = Json.parseToJsonElement(vectorsFile().readText()).jsonObject["cases"]!!.jsonArray
        if (cases.size < 1000) fail("only ${cases.size} video poker vectors loaded — file truncated?")
        val failures = mutableListOf<String>()
        for (c in cases) {
            val obj = c.jsonObject
            val hand = obj["hand"]!!.jsonArray.map { card(it.jsonPrimitive.content) }
            val expect = obj["expect"]!!.jsonObject
            for ((key, variant) in variants) {
                val e = expect[key]!!.jsonArray
                val one = VideoPokerScoring.scoreHand(hand, variant, 1)
                val five = VideoPokerScoring.scoreHand(hand, variant, 5)
                val expected = listOf(e[0].jsonPrimitive.content, e[1].jsonPrimitive.int, e[2].jsonPrimitive.content, e[3].jsonPrimitive.int)
                val actual = listOf(one.first, one.second, five.first, five.second)
                if (expected != actual) failures += "${obj["hand"]} $key expected=$expected actual=$actual"
            }
        }
        if (failures.isNotEmpty()) {
            fail("${failures.size} video poker scorings diverge from Mac:\n" + failures.take(20).joinToString("\n"))
        }
    }
}
