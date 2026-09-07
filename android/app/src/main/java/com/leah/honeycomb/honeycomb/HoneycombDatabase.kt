package com.leah.honeycomb.honeycomb

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlin.math.max
import kotlin.math.pow
import kotlin.random.Random

class HoneycombDatabase(private val dataStore: DataStore<Preferences>) {
    var allCards: List<HoneycombCardData> = emptyList()
        private set

    private val seedKey = stringPreferencesKey("honeycomb_card_seed")

    init {
        val seed = runBlocking { loadOrCreateSeed() }
        allCards = HoneycombCardGenerator.generateAllCards(seed)
    }

    private suspend fun loadOrCreateSeed(): Long {
        val prefs = dataStore.data.first()
        val stored = prefs[seedKey]
        if (stored != null) {
            return stored.toLongOrNull() ?: generateAndSaveSeed()
        }
        return generateAndSaveSeed()
    }

    private suspend fun generateAndSaveSeed(): Long {
        val seed = Random.nextLong()
        dataStore.edit { it[seedKey] = seed.toString() }
        return seed
    }

    suspend fun reseed() {
        val newSeed = generateAndSaveSeed()
        allCards = HoneycombCardGenerator.generateAllCards(newSeed)
    }

    fun card(id: Int): HoneycombCardData? {
        return allCards.firstOrNull { it.id == id }
    }

    fun randomCards(stars: Int, count: Int): List<HoneycombCardData> {
        val pool = allCards.filter { it.stars == stars }
        if (pool.isEmpty()) return emptyList()
        return pool.shuffled().take(count)
    }

    fun rulesAwareCards(stars: Int, count: Int, preferLowStats: Boolean): List<HoneycombCardData> {
        val pool = allCards.filter { it.stars == stars }
        if (pool.isEmpty()) return emptyList()

        fun specializationScore(stats: List<Int>): Double {
            val total = stats.sum().toDouble()
            val mean = total / stats.size
            val variance = stats.fold(0.0) { acc, stat -> acc + (stat - mean).pow(2) } / stats.size
            return total + variance
        }

        val scored = pool.map { Pair(it, specializationScore(it.stats)) }
        val minScore = scored.minOfOrNull { it.second } ?: 0.0
        val maxScore = scored.maxOfOrNull { it.second } ?: 0.0
        val scoreRange = max(maxScore - minScore, 0.0001)

        fun suitabilityWeight(score: Double): Double {
            val normalized = (score - minScore) / scoreRange
            val favored = if (preferLowStats) (1.0 - normalized) else normalized
            return 0.2 + favored
        }

        val remaining = scored.toMutableList()
        val edgeCounts = IntArray(4) { 0 }

        fun dominantEdge(card: HoneycombCardData): Int {
            return card.stats.indices.maxByOrNull { card.stats[it] } ?: 0
        }

        val result = mutableListOf<HoneycombCardData>()
        for (i in 0 until count) {
            if (remaining.isEmpty()) {
                result.add(pool.random())
                continue
            }
            val weights = remaining.map { suitabilityWeight(it.second) / (edgeCounts[dominantEdge(it.first)] + 1) }
            val totalWeight = weights.sum()
            var r = Random.nextDouble(0.0, totalWeight)
            var chosenIndex = remaining.size - 1
            for ((index, weight) in weights.withIndex()) {
                if (r < weight) {
                    chosenIndex = index
                    break
                }
                r -= weight
            }
            val chosen = remaining.removeAt(chosenIndex).first
            edgeCounts[dominantEdge(chosen)]++
            result.add(chosen)
        }
        return result
    }
}
