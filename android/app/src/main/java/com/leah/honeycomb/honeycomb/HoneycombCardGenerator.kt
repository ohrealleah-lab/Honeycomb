package com.leah.honeycomb.honeycomb

import kotlin.random.Random

object HoneycombCardGenerator {
    private data class Tier(
        val stars: Int,
        val valueRange: IntRange,
        val budget: IntRange,
        val countPerSuit: Int,
        val valueWeights: List<Double>,
        val symmetryChance: Double,
        val templateShare: Double,
        val templateShapes: List<List<Int>>
    )

    private val tiers = listOf(
        Tier(stars = 1, valueRange = 1..7, budget = 12..15, countPerSuit = 26,
             valueWeights = listOf(18.0, 21.0, 17.0, 19.0, 11.0, 7.0, 7.0), symmetryChance = 0.038, templateShare = 0.15,
             templateShapes = listOf(listOf(1, 1, 4, 7), listOf(2, 2, 5, 5), listOf(1, 1, 5, 6), listOf(2, 2, 2, 7), listOf(1, 2, 3, 7),
                                     listOf(3, 3, 3, 4), listOf(2, 3, 4, 5), listOf(2, 2, 4, 6), listOf(2, 3, 4, 4), listOf(2, 3, 3, 4))),
        Tier(stars = 2, valueRange = 1..7, budget = 16..21, countPerSuit = 36,
             valueWeights = listOf(5.0, 11.0, 13.0, 16.0, 17.0, 19.0, 20.0), symmetryChance = 0.052, templateShare = 0.15,
             templateShapes = listOf(listOf(1, 3, 7, 7), listOf(2, 3, 6, 7), listOf(1, 6, 7, 7), listOf(2, 4, 6, 7), listOf(2, 2, 7, 7),
                                     listOf(3, 3, 6, 7), listOf(3, 5, 5, 6), listOf(2, 6, 6, 6), listOf(3, 5, 5, 7), listOf(3, 4, 6, 6))),
        Tier(stars = 3, valueRange = 1..8, budget = 20..25, countPerSuit = 41,
             valueWeights = listOf(8.0, 6.0, 8.0, 12.0, 9.0, 18.0, 21.0, 19.0), symmetryChance = 0.018, templateShare = 0.15,
             templateShapes = listOf(listOf(1, 6, 7, 8), listOf(4, 4, 7, 8), listOf(2, 4, 7, 8), listOf(1, 6, 7, 7), listOf(2, 3, 7, 8),
                                     listOf(1, 4, 8, 8), listOf(3, 3, 7, 8), listOf(1, 4, 7, 8), listOf(3, 5, 6, 8), listOf(2, 5, 7, 8))),
        Tier(stars = 4, valueRange = 1..9, budget = 24..28, countPerSuit = 21,
             valueWeights = listOf(7.0, 4.0, 4.0, 5.0, 9.0, 10.0, 18.0, 22.0, 21.0), symmetryChance = 0.051, templateShare = 0.15,
             templateShapes = listOf(listOf(1, 7, 8, 9), listOf(4, 6, 6, 8), listOf(6, 7, 7, 8), listOf(1, 8, 8, 8), listOf(4, 4, 8, 9),
                                     listOf(2, 5, 9, 9), listOf(1, 5, 9, 9), listOf(5, 6, 6, 7), listOf(6, 6, 8, 8), listOf(6, 6, 7, 9))),
        Tier(stars = 5, valueRange = 1..10, budget = 25..30, countPerSuit = 14,
             valueWeights = listOf(6.0, 4.0, 4.0, 6.0, 8.0, 10.0, 10.0, 11.0, 15.0, 26.0), symmetryChance = 0.014, templateShare = 0.15,
             templateShapes = listOf(listOf(1, 7, 8, 9), listOf(1, 7, 9, 10), listOf(2, 5, 10, 10), listOf(6, 7, 7, 8), listOf(1, 8, 8, 8),
                                     listOf(4, 4, 8, 9), listOf(2, 5, 9, 9), listOf(4, 6, 8, 10), listOf(6, 6, 8, 8), listOf(6, 7, 7, 10)))
    )

    private val suits = listOf("S", "H", "D", "C")

    private fun weightedValue(tier: Tier, rng: Random): Int {
        val total = tier.valueWeights.sum()
        val r = rng.nextDouble(0.0, total)
        var cumulative = 0.0
        for ((i, w) in tier.valueWeights.withIndex()) {
            cumulative += w
            if (r < cumulative) return tier.valueRange.first + i
        }
        return tier.valueRange.last
    }

    fun generateAllCards(seed: Long): List<HoneycombCardData> {
        val rng = Random(seed)
        val allCards = mutableListOf<HoneycombCardData>()
        var nextId = 1

        for (suit in suits) {
            val seenCombos = mutableSetOf<List<Int>>()
            var suitIndex = 1

            for (tier in tiers) {
                for (i in 0 until tier.countPerSuit) {
                    var stats: List<Int>
                    do {
                        stats = if (tier.templateShapes.isNotEmpty() && rng.nextDouble() < tier.templateShare) {
                            tier.templateShapes.random(rng).shuffled(rng)
                        } else if (rng.nextDouble() < tier.symmetryChance) {
                            val a = weightedValue(tier, rng)
                            val b = weightedValue(tier, rng)
                            listOf(a, b, a, b)
                        } else {
                            (0 until 4).map { weightedValue(tier, rng) }
                        }
                    } while (stats.sum() !in tier.budget || !seenCombos.add(stats))

                    allCards.add(
                        HoneycombCardData(
                            id = nextId,
                            name = "${suitSingular(suit)} $suitIndex",
                            stars = tier.stars,
                            stats = stats,
                            suit = suit
                        )
                    )
                    nextId++
                    suitIndex++
                }
            }
        }
        return allCards
    }

    private fun suitSingular(suit: String): String = when (suit) {
        "S" -> "Spade"
        "H" -> "Heart"
        "D" -> "Diamond"
        "C" -> "Club"
        else -> suit
    }
}
