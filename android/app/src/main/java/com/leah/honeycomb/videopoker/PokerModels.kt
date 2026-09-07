package com.leah.honeycomb.videopoker

import com.leah.honeycomb.Card
import com.leah.honeycomb.Suit
import kotlinx.serialization.Serializable

enum class PokerHandRank {
    HighCard,
    OnePair,
    TwoPair,
    ThreeOfAKind,
    Straight,
    Flush,
    FullHouse,
    FourOfAKind,
    StraightFlush,
    RoyalFlush;
}

data class PokerHandResult(
    val rank: PokerHandRank,
    val kickers: List<Int>
) : Comparable<PokerHandResult> {
    override fun compareTo(other: PokerHandResult): Int {
        if (this.rank != other.rank) return this.rank.compareTo(other.rank)
        for (i in 0 until minOf(this.kickers.size, other.kickers.size)) {
            if (this.kickers[i] != other.kickers[i]) {
                return this.kickers[i].compareTo(other.kickers[i])
            }
        }
        return this.kickers.size.compareTo(other.kickers.size)
    }
}

object PokerHandEvaluator {
    fun evaluate(five: List<Card>): PokerHandResult {
        require(five.size == 5) { "evaluate requires exactly 5 cards" }
        
        val ranks = five.map { if (it.rank == 1) 14 else it.rank }.sortedDescending()
        val suits = five.map { it.suit }
        val isFlush = suits.toSet().size == 1
        
        val isStraight: Boolean
        val straightHighCard: Int
        
        if (ranks == listOf(14, 5, 4, 3, 2)) {
            isStraight = true
            straightHighCard = 5
        } else {
            isStraight = (ranks[0] - ranks[4] == 4) && ranks.toSet().size == 5
            straightHighCard = ranks[0]
        }
        
        val freq = mutableMapOf<Int, Int>()
        for (r in ranks) {
            freq[r] = freq.getOrDefault(r, 0) + 1
        }
        
        val groups = freq.entries.sortedWith(Comparator { a, b ->
            if (a.value != b.value) b.value.compareTo(a.value)
            else b.key.compareTo(a.key)
        })
        val groupCounts = groups.map { it.value }
        
        if (isFlush && isStraight) {
            if (straightHighCard == 14) return PokerHandResult(PokerHandRank.RoyalFlush, listOf(straightHighCard))
            return PokerHandResult(PokerHandRank.StraightFlush, listOf(straightHighCard))
        }
        
        if (groupCounts == listOf(5)) {
            return PokerHandResult(PokerHandRank.FourOfAKind, listOf(groups[0].key, 15))
        }
        
        if (groupCounts == listOf(4, 1)) {
            return PokerHandResult(PokerHandRank.FourOfAKind, listOf(groups[0].key, groups[1].key))
        }
        
        if (groupCounts == listOf(3, 2)) {
            return PokerHandResult(PokerHandRank.FullHouse, listOf(groups[0].key, groups[1].key))
        }
        
        if (isFlush) {
            return PokerHandResult(PokerHandRank.Flush, ranks)
        }
        
        if (isStraight) {
            return PokerHandResult(PokerHandRank.Straight, listOf(straightHighCard))
        }
        
        if (groupCounts == listOf(3, 1, 1)) {
            val trio = groups[0].key
            val kicks = listOf(groups[1].key, groups[2].key).sortedDescending()
            return PokerHandResult(PokerHandRank.ThreeOfAKind, listOf(trio) + kicks)
        }
        
        if (groupCounts == listOf(2, 2, 1)) {
            return PokerHandResult(PokerHandRank.TwoPair, listOf(groups[0].key, groups[1].key, groups[2].key))
        }
        
        if (groupCounts == listOf(2, 1, 1, 1)) {
            val pair = groups[0].key
            val kicks = listOf(groups[1].key, groups[2].key, groups[3].key).sortedDescending()
            return PokerHandResult(PokerHandRank.OnePair, listOf(pair) + kicks)
        }
        
        return PokerHandResult(PokerHandRank.HighCard, ranks)
    }
    
    fun evaluateWithDeuces(five: List<Card>): PokerHandResult {
        val wilds = five.filter { it.rank == 2 }
        val naturals = five.filter { it.rank != 2 }
        val wildCount = wilds.size
        
        if (wildCount == 0 || wildCount >= 4) return evaluate(five)
        
        val shareSuit = naturals.isNotEmpty() && naturals.map { it.suit }.toSet().size == 1
        val candidateSuit = if (shareSuit) naturals[0].suit else Suit.Spades
        
        var best = PokerHandResult(PokerHandRank.HighCard, emptyList())
        
        fun fill(remaining: Int, current: List<Card>) {
            if (remaining == 0) {
                val result = evaluate(current)
                if (result > best) best = result
                return
            }
            for (rank in 1..13) {
                val sub = Card(suit = candidateSuit, rank = rank, faceUp = true)
                fill(remaining - 1, current + sub)
            }
        }
        
        fill(wildCount, naturals)
        return best
    }
}
