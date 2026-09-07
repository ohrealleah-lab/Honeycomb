package com.leah.honeycomb.honeycomb

import com.leah.honeycomb.AppLanguage
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
enum class HoneycombRule(val weight: Int) {
    Ascension(8),
    Descension(3),
    Same(30),
    Plus(30),
    FallenAce(8),
    Reverse(3),
    AllOpen(8),
    ThreeOpen(15),
    Swap(15),
    Order(3),
    Chaos(15),
    BombShelter(15),
    SuddenDeath(30);
    
    val displayName: String
        get() = when (this) {
            Ascension -> "Pollination"
            Descension -> "Smoked Out"
            Same -> "Symmetry"
            Plus -> "Math Bee"
            FallenAce -> "Queen's Fall"
            Reverse -> "Inversion"
            AllOpen -> "Clear Skies"
            ThreeOpen -> "Scouting Party"
            Swap -> "Nectar Exchange"
            Order -> "Hierarchy"
            Chaos -> "Frenzy"
            BombShelter -> "Capped Brood"
            SuddenDeath -> "Swarm to the Death"
        }
        
    fun explanation(activeSuits: Set<String> = emptySet()): String {
        return when (this) {
            Same -> "If 2+ touching neighbor stats match your card's facing stats, all matching neighbors are captured simultaneously."
            Plus -> "If the sum of (your stat + neighbor's stat) equals the same total across 2+ neighbors, all involved cards are captured."
            FallenAce -> "A card with a stat of 1 attacking a 10 (\"A\") always captures it! If Inversion is also active, this flips: a 10 (\"A\") captures a 1 instead."
            Reverse -> "Inverts all comparisons—lower stats beat higher stats."
            Ascension -> {
                if (activeSuits.isEmpty()) "Grants +1 to stats for all cards matching randomly selected suits as more of that suit enter the board."
                else {
                    val suitNames = activeSuits.sorted().joinToString(" and ") { HoneycombCardData.suitDisplayName(it) }
                    "Grants +1 to stats for all $suitNames cards as more of that suit enter the board."
                }
            }
            Descension -> {
                if (activeSuits.isEmpty()) "Inflicts -1 to stats for all cards matching randomly selected suits as more of that suit enter the board."
                else {
                    val suitNames = activeSuits.sorted().joinToString(" and ") { HoneycombCardData.suitDisplayName(it) }
                    "Inflicts -1 to stats for all $suitNames cards as more of that suit enter the board."
                }
            }
            Order -> "Forces you to play cards in exact deck sequence."
            Chaos -> "Randomly mandates which card must be played each turn."
            AllOpen -> "Both players' hands are completely visible."
            ThreeOpen -> "Three randomly selected cards from each player's hand are visible."
            BombShelter -> "Each player's first card played remains face-down for 3 turns before flipping automatically."
            SuddenDeath -> "If the match ends in a draw, a rematch begins immediately."
            Swap -> "Before the match, one card from your hand is randomly swapped with one of the opponent's."
        }
    }
}

@Serializable
data class HoneycombCardData(
    val id: Int,
    val name: String,
    val stars: Int,
    val stats: List<Int>, // 0: Top, 1: Right, 2: Bottom, 3: Left
    val suit: String
) {
    companion object {
        fun suitDisplayName(code: String): String = when (code) {
            "S" -> "Spades"
            "H" -> "Hearts"
            "D" -> "Diamonds"
            "C" -> "Clubs"
            else -> code
        }
        
        fun localizedSuitName(code: String, language: AppLanguage): String = when (code) {
            "S" -> if (language == AppLanguage.Spanish) "Picas" else "Spades"
            "H" -> if (language == AppLanguage.Spanish) "Corazones" else "Hearts"
            "D" -> if (language == AppLanguage.Spanish) "Diamantes" else "Diamonds"
            "C" -> if (language == AppLanguage.Spanish) "Tréboles" else "Clubs"
            else -> code
        }
    }
}

enum class CardOwner {
    Player,
    Opponent
}

@Serializable
data class HoneycombCard(
    val data: HoneycombCardData,
    var owner: CardOwner,
    val originalOwner: CardOwner = owner,
    val id: String = UUID.randomUUID().toString(),
    var modifier: Int = 0,
    var isFaceDown: Boolean = false,
    var bombShelterTurnsRemaining: Int? = null
) {
    fun stat(index: Int): Int {
        val v = data.stats[index] + modifier
        return Math.min(10, Math.max(1, v))
    }
}

@Serializable
data class HoneycombCell(
    val id: String = UUID.randomUUID().toString(),
    var card: HoneycombCard? = null
)

@Serializable
data class HoneycombBoard(
    var cells: List<HoneycombCell> = List(9) { HoneycombCell() },
    var sessionSamePlusTriggers: Int = 0,
    var sessionFallenAceCaptures: Int = 0,
    var lastSameTriggered: Boolean = false,
    var lastPlusTriggered: Boolean = false,
    var lastFallenAceTriggered: Boolean = false,
    var lastComboFlipCount: Int = 0,
    var ascensionDescensionSuits: Set<String> = emptySet()
) {
    val rows = 3
    val cols = 3

    val isFull: Boolean
        get() = !cells.any { it.card == null }

    val playerScore: Int
        get() = cells.count { it.card?.owner == CardOwner.Player }

    val opponentScore: Int
        get() = cells.count { it.card?.owner == CardOwner.Opponent }

    fun placeCard(card: HoneycombCard, index: Int, rules: List<HoneycombRule>, skipCaptures: Boolean = false): List<Int> {
        if (index !in 0 until 9 || cells[index].card != null) return emptyList()

        cells[index].card = card
        lastSameTriggered = false
        lastPlusTriggered = false
        lastFallenAceTriggered = false
        lastComboFlipCount = 0

        updateModifiers(rules)

        if (skipCaptures) return emptyList()
        return resolveCaptures(index, rules, false)
    }

    fun revealFaceDownCard(index: Int, rules: List<HoneycombRule>): List<Int> {
        val card = cells.getOrNull(index)?.card
        if (card == null || !card.isFaceDown) return emptyList()

        card.isFaceDown = false
        lastSameTriggered = false
        lastPlusTriggered = false
        lastFallenAceTriggered = false
        lastComboFlipCount = 0

        updateModifiers(rules)
        return resolveCaptures(index, rules, false)
    }

    private fun suitCount(suit: String): Int {
        return cells.mapNotNull { it.card }.count { !it.isFaceDown && it.data.suit == suit }
    }

    private fun updateModifiers(rules: List<HoneycombRule>) {
        for (i in cells.indices) {
            val card = cells[i].card ?: continue
            card.modifier = 0
            if (card.isFaceDown) continue

            if (ascensionDescensionSuits.contains(card.data.suit)) {
                if (rules.contains(HoneycombRule.Ascension)) {
                    card.modifier = suitCount(card.data.suit)
                } else if (rules.contains(HoneycombRule.Descension)) {
                    card.modifier = -suitCount(card.data.suit)
                }
            }
        }
    }

    private fun resolveCaptures(index: Int, rules: List<HoneycombRule>, isCombo: Boolean): List<Int> {
        val attacker = cells[index].card ?: return emptyList()
        val row = index / cols
        val col = index % cols
        val flippedIndices = mutableListOf<Int>()
        val comboQueue = mutableListOf<Int>()

        val reverse = rules.contains(HoneycombRule.Reverse)
        val fallenAce = rules.contains(HoneycombRule.FallenAce)

        fun isFallenAceWin(aStat: Int, tStat: Int): Boolean {
            if (!fallenAce) return false
            if (!reverse && aStat == 1 && tStat == 10) return true
            if (reverse && aStat == 10 && tStat == 1) return true
            return false
        }

        fun isFallenAceBlockedLoss(aStat: Int, tStat: Int): Boolean {
            if (!fallenAce) return false
            if (!reverse && aStat == 10 && tStat == 1) return true
            if (reverse && aStat == 1 && tStat == 10) return true
            return false
        }

        fun canCapture(aStat: Int, tStat: Int): Boolean {
            if (isFallenAceWin(aStat, tStat)) return true
            if (isFallenAceBlockedLoss(aStat, tStat)) return false
            return if (reverse) aStat < tStat else aStat > tStat
        }

        data class Neighbor(val dir: Int, val idx: Int, val aStat: Int, val tStat: Int, val enemy: Boolean)
        val neighbors = mutableListOf<Neighbor>()

        if (row > 0) { // Top
            val tIdx = index - cols
            val tCard = cells[tIdx].card
            if (tCard != null && !tCard.isFaceDown) {
                neighbors.add(Neighbor(0, tIdx, attacker.stat(0), tCard.stat(2), tCard.owner != attacker.owner))
            }
        }
        if (col < cols - 1) { // Right
            val tIdx = index + 1
            val tCard = cells[tIdx].card
            if (tCard != null && !tCard.isFaceDown) {
                neighbors.add(Neighbor(1, tIdx, attacker.stat(1), tCard.stat(3), tCard.owner != attacker.owner))
            }
        }
        if (row < rows - 1) { // Bottom
            val tIdx = index + cols
            val tCard = cells[tIdx].card
            if (tCard != null && !tCard.isFaceDown) {
                neighbors.add(Neighbor(2, tIdx, attacker.stat(2), tCard.stat(0), tCard.owner != attacker.owner))
            }
        }
        if (col > 0) { // Left
            val tIdx = index - 1
            val tCard = cells[tIdx].card
            if (tCard != null && !tCard.isFaceDown) {
                neighbors.add(Neighbor(3, tIdx, attacker.stat(3), tCard.stat(1), tCard.owner != attacker.owner))
            }
        }

        if (!isCombo) {
            val sameMatches = mutableListOf<Int>()
            val plusSums = mutableMapOf<Int, MutableList<Int>>()

            for (n in neighbors) {
                if (rules.contains(HoneycombRule.Same)) {
                    if (n.aStat == n.tStat) sameMatches.add(n.idx)
                }
                if (rules.contains(HoneycombRule.Plus)) {
                    val sum = n.aStat + n.tStat
                    plusSums.getOrPut(sum) { mutableListOf() }.add(n.idx)
                }
            }

            val triggers = mutableSetOf<Int>()
            var sameActuallyFlips = false
            if (sameMatches.size >= 2) {
                triggers.addAll(sameMatches)
                sameActuallyFlips = sameMatches.any { cells[it].card?.owner != attacker.owner }
            }

            var plusActuallyFlips = false
            for (indices in plusSums.values) {
                if (indices.size >= 2) {
                    triggers.addAll(indices)
                    if (indices.any { cells[it].card?.owner != attacker.owner }) {
                        plusActuallyFlips = true
                    }
                }
            }

            lastSameTriggered = sameActuallyFlips
            lastPlusTriggered = plusActuallyFlips

            if (sameActuallyFlips || plusActuallyFlips) {
                sessionSamePlusTriggers++
            }

            for (idx in triggers) {
                val c = cells[idx].card
                if (c != null && c.owner != attacker.owner) {
                    c.owner = attacker.owner
                    flippedIndices.add(idx)
                    comboQueue.add(idx)
                }
            }
        }

        for (n in neighbors) {
            if (n.enemy && !flippedIndices.contains(n.idx)) {
                if (canCapture(n.aStat, n.tStat)) {
                    val viaFallenAceRule = isFallenAceWin(n.aStat, n.tStat)
                    if (viaFallenAceRule) lastFallenAceTriggered = true

                    val baseAStat = attacker.data.stats[n.dir]
                    val tCard = cells[n.idx].card!!
                    val baseTStat = tCard.data.stats[(n.dir + 2) % 4]

                    if ((baseAStat == 1 && baseTStat == 10) || viaFallenAceRule) {
                        sessionFallenAceCaptures++
                    }

                    tCard.owner = attacker.owner
                    flippedIndices.add(n.idx)

                    if (isCombo) {
                        comboQueue.add(n.idx)
                        lastComboFlipCount++
                    }
                }
            }
        }

        for (comboIdx in comboQueue) {
            val comboFlips = resolveCaptures(comboIdx, rules, true)
            flippedIndices.addAll(comboFlips)
        }

        return flippedIndices
    }
}
