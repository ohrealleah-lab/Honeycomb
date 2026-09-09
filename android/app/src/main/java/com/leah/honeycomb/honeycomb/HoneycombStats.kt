package com.leah.honeycomb.honeycomb

import kotlinx.serialization.Serializable

// Ported 1:1 from shared/Honeycomb/Models/HoneycombStats.swift.
@Serializable
data class HoneycombStats(
    val gamesPlayed: Int = 0,
    val matchesWon: Int = 0,
    val matchesLost: Int = 0,
    val matchesDrawn: Int = 0,
    val cardsCaptured: Int = 0,

    val currentWinStreak: Int = 0,
    val longestWinStreak: Int = 0,
    val flawlessVictories: Int = 0,
    val samePlusTriggers: Int = 0,
    val ultraHardWins: Int = 0,
    val timesStartedOver: Int = 0,
    val easyWins: Int = 0,
    val mediumWins: Int = 0,
    val hardWins: Int = 0,
    val cardsStolen: Int = 0,
    val fallenAces: Int = 0,
    val suddenDeathCount: Int = 0
) {
    // Win % of decisive games (draws excluded from the denominator) — matches
    // HoneycombStats.swift's winRate, the single shared source Mac/iOS both read.
    val winRate: Double
        get() {
            val decisiveGames = gamesPlayed - matchesDrawn
            return if (decisiveGames > 0) matchesWon.toDouble() / decisiveGames.toDouble() else 0.0
        }

    fun recordGame(
        won: Boolean,
        drawn: Boolean,
        captures: Int,
        sessionCombos: Int,
        flawless: Boolean,
        difficulty: HoneycombDifficulty? = null,
        fallenAceCaptures: Int = 0
    ): HoneycombStats {
        var result = copy(
            gamesPlayed = gamesPlayed + 1,
            cardsCaptured = cardsCaptured + captures,
            samePlusTriggers = samePlusTriggers + sessionCombos,
            fallenAces = fallenAces + fallenAceCaptures
        )

        result = when {
            drawn -> result.copy(matchesDrawn = result.matchesDrawn + 1, currentWinStreak = 0)
            won -> {
                val newStreak = result.currentWinStreak + 1
                var won = result.copy(
                    matchesWon = result.matchesWon + 1,
                    currentWinStreak = newStreak,
                    longestWinStreak = maxOf(result.longestWinStreak, newStreak),
                    flawlessVictories = result.flawlessVictories + if (flawless) 1 else 0
                )
                won = when (difficulty) {
                    HoneycombDifficulty.Easy -> won.copy(easyWins = won.easyWins + 1)
                    HoneycombDifficulty.Medium -> won.copy(mediumWins = won.mediumWins + 1)
                    HoneycombDifficulty.Hard -> won.copy(hardWins = won.hardWins + 1)
                    HoneycombDifficulty.UltraHard -> won.copy(ultraHardWins = won.ultraHardWins + 1)
                    null -> won
                }
                won
            }
            else -> result.copy(matchesLost = result.matchesLost + 1, currentWinStreak = 0)
        }

        return result
    }
}
