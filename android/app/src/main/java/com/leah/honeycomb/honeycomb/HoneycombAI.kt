package com.leah.honeycomb.honeycomb

import kotlin.math.max
import kotlin.math.min

@kotlinx.serialization.Serializable
enum class HoneycombDifficulty {
    Easy, Medium, Hard, UltraHard
}

object HoneycombAI {
    fun computeMove(
        difficulty: HoneycombDifficulty,
        board: HoneycombBoard,
        opponentDeck: List<HoneycombCardData>,
        playerDeck: List<HoneycombCardData>,
        unknownPlayerCardCount: Int = 0,
        eligibleHands: List<Int>,
        empties: List<Int>,
        rules: List<HoneycombRule>
    ): Pair<Int, Int>? {
        val simulatedPlayerDeck = playerDeck.toMutableList()
        val genericCard = HoneycombCardData(id = -1, name = "Unknown", stars = 3, stats = listOf(6, 6, 6, 6), suit = "-")
        for (i in 0 until unknownPlayerCardCount) {
            simulatedPlayerDeck.add(genericCard)
        }

        return when (difficulty) {
            HoneycombDifficulty.Easy -> {
                if (Math.random() > 0.5) {
                    greedyMove(board, opponentDeck, eligibleHands, empties, rules)
                } else {
                    randomMove(eligibleHands, empties)
                }
            }
            HoneycombDifficulty.Medium -> greedyMove(board, opponentDeck, eligibleHands, empties, rules)
            HoneycombDifficulty.Hard -> minimaxMove(board, opponentDeck, simulatedPlayerDeck, 0, eligibleHands, empties, rules, 5, false)
            HoneycombDifficulty.UltraHard -> minimaxMove(board, opponentDeck, simulatedPlayerDeck, 0, eligibleHands, empties, rules, 6, true)
        }
    }

    enum class TTFlag { Exact, LowerBound, UpperBound }

    data class TTEntry(val value: Int, val flag: TTFlag)

    data class CardState(val dataId: Int, val owner: CardOwner, val isFaceDown: Boolean)
    
    data class TTKey(
        val cells: List<CardState?>,
        val maximizingOpponent: Boolean,
        val depth: Int,
        val opponentDeckIds: List<Int>,
        val playerDeckIds: List<Int>
    )

    private fun mirroredOwnership(board: HoneycombBoard): HoneycombBoard {
        val mirrored = board.copy(cells = board.cells.map { it.copy() })
        for (i in mirrored.cells.indices) {
            val card = mirrored.cells[i].card ?: continue
            val newCard = card.copy(owner = if (card.owner == CardOwner.Player) CardOwner.Opponent else CardOwner.Player)
            mirrored.cells[i].card = newCard
        }
        return mirrored
    }

    fun computeHint(
        board: HoneycombBoard,
        playerDeck: List<HoneycombCardData>,
        opponentDeck: List<HoneycombCardData>,
        unknownOpponentCardCount: Int,
        eligibleHands: List<Int>,
        empties: List<Int>,
        rules: List<HoneycombRule>
    ): Pair<Int, Int>? {
        val simulatedOpponentDeck = opponentDeck.toMutableList()
        val genericCard = HoneycombCardData(id = -1, name = "Unknown", stars = 3, stats = listOf(6, 6, 6, 6), suit = "-")
        for (i in 0 until unknownOpponentCardCount) {
            simulatedOpponentDeck.add(genericCard)
        }

        return minimaxMove(
            board = mirroredOwnership(board),
            opponentDeck = playerDeck,
            playerDeck = simulatedOpponentDeck,
            unknownPlayerCardCount = 0,
            eligibleHands = eligibleHands,
            empties = empties,
            rules = rules,
            lookaheadPlies = 6,
            weighFallenAce = true
        )
    }

    private fun randomMove(eligibleHands: List<Int>, empties: List<Int>): Pair<Int, Int>? {
        if (empties.isEmpty() || eligibleHands.isEmpty()) return null
        return Pair(eligibleHands.random(), empties.random())
    }

    private fun greedyMove(board: HoneycombBoard, opponentDeck: List<HoneycombCardData>, eligibleHands: List<Int>, empties: List<Int>, rules: List<HoneycombRule>): Pair<Int, Int>? {
        if (empties.isEmpty() || eligibleHands.isEmpty()) return null

        var bestScore = -1
        var bestMoves = mutableListOf<Pair<Int, Int>>()
        for (h in eligibleHands) {
            val cardData = opponentDeck[h]
            for (b in empties) {
                val simBoard = board.copy(cells = board.cells.map { it.copy(card = it.card?.copy()) })
                val score = simBoard.placeCard(HoneycombCard(data = cardData, owner = CardOwner.Opponent), b, rules).size
                if (score > bestScore) {
                    bestScore = score
                    bestMoves = mutableListOf(Pair(h, b))
                } else if (score == bestScore) {
                    bestMoves.add(Pair(h, b))
                }
            }
        }
        return bestMoves.randomOrNull()
    }

    private fun minimaxMove(
        board: HoneycombBoard,
        opponentDeck: List<HoneycombCardData>,
        playerDeck: List<HoneycombCardData>,
        unknownPlayerCardCount: Int,
        eligibleHands: List<Int>,
        empties: List<Int>,
        rules: List<HoneycombRule>,
        lookaheadPlies: Int,
        weighFallenAce: Boolean
    ): Pair<Int, Int>? {
        if (empties.isEmpty() || eligibleHands.isEmpty()) return null

        var bestScore = Int.MIN_VALUE
        data class MoveCandidate(val h: Int, val b: Int, val captures: Int)
        var bestMoves = mutableListOf<MoveCandidate>()
        var alpha = Int.MIN_VALUE

        val candidates = orderedCandidates(opponentDeck, eligibleHands, empties, board, CardOwner.Opponent, rules)
        val tt = mutableMapOf<TTKey, TTEntry>()

        for (candidate in candidates) {
            val remainingOpponentDeck = opponentDeck.toMutableList()
            remainingOpponentDeck.removeAt(candidate.h)

            val score = minimaxScore(
                board = candidate.board,
                opponentDeck = remainingOpponentDeck,
                playerDeck = playerDeck,
                unknownPlayerCardCount = unknownPlayerCardCount,
                maximizingOpponent = false,
                depth = lookaheadPlies - 1,
                alpha = alpha,
                beta = Int.MAX_VALUE,
                rules = rules,
                weighFallenAce = weighFallenAce,
                tt = tt
            )

            if (score > bestScore) {
                bestScore = score
                bestMoves = mutableListOf(MoveCandidate(candidate.h, candidate.b, candidate.captures))
                alpha = max(alpha, bestScore)
            } else if (score == bestScore) {
                bestMoves.add(MoveCandidate(candidate.h, candidate.b, candidate.captures))
            }
        }
        val maxCaptures = bestMoves.maxOfOrNull { it.captures } ?: 0
        val mostAggressive = bestMoves.filter { it.captures == maxCaptures }
        return mostAggressive.randomOrNull()?.let { Pair(it.h, it.b) }
    }

    data class OrderedCandidate(val h: Int, val b: Int, val captures: Int, val board: HoneycombBoard)

    private fun orderedCandidates(
        deck: List<HoneycombCardData>,
        handIndices: List<Int>,
        empties: List<Int>,
        board: HoneycombBoard,
        owner: CardOwner,
        rules: List<HoneycombRule>
    ): List<OrderedCandidate> {
        val candidates = mutableListOf<OrderedCandidate>()
        for (h in handIndices) {
            val cardData = deck[h]
            for (b in empties) {
                val simBoard = board.copy(cells = board.cells.map { it.copy(card = it.card?.copy()) })
                val captures = simBoard.placeCard(HoneycombCard(data = cardData, owner = owner), b, rules).size
                candidates.add(OrderedCandidate(h, b, captures, simBoard))
            }
        }
        return candidates.sortedByDescending { it.captures }
    }

    private const val terminalScoreUnit = 1000

    private fun minimaxScore(
        board: HoneycombBoard,
        opponentDeck: List<HoneycombCardData>,
        playerDeck: List<HoneycombCardData>,
        unknownPlayerCardCount: Int,
        maximizingOpponent: Boolean,
        depth: Int,
        alpha: Int,
        beta: Int,
        rules: List<HoneycombRule>,
        weighFallenAce: Boolean,
        tt: MutableMap<TTKey, TTEntry>
    ): Int {
        val ttKey = TTKey(
            cells = board.cells.map { cell ->
                cell.card?.let { CardState(it.data.id, it.owner, it.isFaceDown) }
            },
            maximizingOpponent = maximizingOpponent,
            depth = depth,
            opponentDeckIds = opponentDeck.map { it.id }.sorted(),
            playerDeckIds = playerDeck.map { it.id }.sorted()
        )
        tt[ttKey]?.let { entry ->
            if (entry.flag == TTFlag.Exact) return entry.value
            if (entry.flag == TTFlag.LowerBound && entry.value >= beta) return entry.value
            if (entry.flag == TTFlag.UpperBound && entry.value <= alpha) return entry.value
        }

        val originalAlpha = alpha
        if (board.isFull) {
            val margin = board.opponentScore - board.playerScore
            return margin * terminalScoreUnit
        }

        val empties = board.cells.mapIndexedNotNull { index, cell -> if (cell.card == null) index else null }
        val activeDeck = if (maximizingOpponent) opponentDeck else playerDeck

        if (!maximizingOpponent && unknownPlayerCardCount > 0) {
            return positionalEvaluation(board, opponentDeck, playerDeck, rules, weighFallenAce)
        }

        if (depth <= 0 || empties.isEmpty() || activeDeck.isEmpty()) {
            return positionalEvaluation(board, opponentDeck, playerDeck, rules, weighFallenAce)
        }

        var currentAlpha = alpha
        var currentBeta = beta
        val owner = if (maximizingOpponent) CardOwner.Opponent else CardOwner.Player
        val candidates = orderedCandidates(activeDeck, activeDeck.indices.toList(), empties, board, owner, rules)

        var best: Int
        if (maximizingOpponent) {
            best = Int.MIN_VALUE
            for (candidate in candidates) {
                val remaining = opponentDeck.toMutableList().apply { removeAt(candidate.h) }
                val score = minimaxScore(candidate.board, remaining, playerDeck, unknownPlayerCardCount, false, depth - 1, currentAlpha, currentBeta, rules, weighFallenAce, tt)
                best = max(best, score)
                currentAlpha = max(currentAlpha, best)
                if (currentBeta <= currentAlpha) break
            }
        } else {
            best = Int.MAX_VALUE
            for (candidate in candidates) {
                val remaining = playerDeck.toMutableList().apply { removeAt(candidate.h) }
                val score = minimaxScore(candidate.board, opponentDeck, remaining, unknownPlayerCardCount, true, depth - 1, currentAlpha, currentBeta, rules, weighFallenAce, tt)
                best = min(best, score)
                currentBeta = min(currentBeta, best)
                if (currentBeta <= currentAlpha) break
            }
        }

        val flag = if (best <= originalAlpha) TTFlag.UpperBound else if (best >= currentBeta) TTFlag.LowerBound else TTFlag.Exact
        tt[ttKey] = TTEntry(best, flag)
        return best
    }

    private fun neighborIndex(index: Int, direction: Int): Int? {
        val row = index / 3
        val col = index % 3
        return when (direction) {
            0 -> if (row > 0) index - 3 else null
            1 -> if (col < 2) index + 1 else null
            2 -> if (row < 2) index + 3 else null
            3 -> if (col > 0) index - 1 else null
            else -> null
        }
    }

    private fun exposureValue(stat: Int, reverse: Boolean, fallenAce: Boolean): Int {
        val effectiveStrength = if (reverse) (11 - stat) else stat
        var value = effectiveStrength - 5
        val fallenAceVulnerableStat = if (reverse) 1 else 10
        if (fallenAce && stat == fallenAceVulnerableStat) value -= 3
        val fallenAceProtectedStat = if (reverse) 10 else 1
        if (fallenAce && stat == fallenAceProtectedStat) value += 3
        return value
    }

    private fun positionalEvaluation(board: HoneycombBoard, opponentDeck: List<HoneycombCardData>, playerDeck: List<HoneycombCardData>, rules: List<HoneycombRule>, weighFallenAce: Boolean): Int {
        val reverse = rules.contains(HoneycombRule.Reverse)
        val fallenAce = weighFallenAce && rules.contains(HoneycombRule.FallenAce)
        var score = 0
        for ((idx, cell) in board.cells.withIndex()) {
            val card = cell.card ?: continue
            if (card.isFaceDown && card.originalOwner == CardOwner.Player) continue
            var cardScore = 10
            for (direction in 0 until 4) {
                val neighbor = neighborIndex(idx, direction)
                if (neighbor != null && board.cells[neighbor].card == null) {
                    cardScore += exposureValue(card.stat(direction), reverse, fallenAce)
                }
            }
            score += if (card.owner == CardOwner.Opponent) cardScore else -cardScore
        }
        score += comboPotential(board, opponentDeck, playerDeck, rules)
        return score
    }

    private fun comboPotential(board: HoneycombBoard, opponentDeck: List<HoneycombCardData>, playerDeck: List<HoneycombCardData>, rules: List<HoneycombRule>): Int {
        if (!rules.contains(HoneycombRule.Same) && !rules.contains(HoneycombRule.Plus)) return 0
        var score = 0
        val empties = board.cells.mapIndexedNotNull { index, cell -> if (cell.card == null) index else null }
        
        for (emptyIdx in empties) {
            data class NeighborInfo(val direction: Int, val owner: CardOwner, val stat: Int)
            val neighbors = mutableListOf<NeighborInfo>()
            for (direction in 0 until 4) {
                val neighborIdx = neighborIndex(emptyIdx, direction)
                if (neighborIdx != null) {
                    val card = board.cells[neighborIdx].card
                    if (card != null && !card.isFaceDown) {
                        val towardEmptyDirection = (direction + 2) % 4
                        neighbors.add(NeighborInfo(direction, card.owner, card.stat(towardEmptyDirection)))
                    }
                }
            }

            if (neighbors.size < 2) continue

            for (targetOwner in listOf(CardOwner.Player, CardOwner.Opponent)) {
                val attackerDeck = if (targetOwner == CardOwner.Player) opponentDeck else playerDeck
                var hasSame = false
                var hasPlus = false

                for (cardData in attackerDeck) {
                    var modifier = 0
                    if (board.ascensionDescensionSuits.contains(cardData.suit)) {
                        val count = board.cells.mapNotNull { it.card }.count { !it.isFaceDown && it.data.suit == cardData.suit } + 1
                        if (rules.contains(HoneycombRule.Ascension)) modifier = count
                        else if (rules.contains(HoneycombRule.Descension)) modifier = -count
                    }

                    if (rules.contains(HoneycombRule.Same)) {
                        val matches = neighbors.filter { n ->
                            val attackerStat = min(10, max(1, cardData.stats[n.direction] + modifier))
                            attackerStat == n.stat
                        }
                        if (matches.size >= 2 && matches.any { it.owner == targetOwner }) hasSame = true
                    }

                    if (rules.contains(HoneycombRule.Plus)) {
                        val sumGroups = mutableMapOf<Int, MutableList<NeighborInfo>>()
                        for (n in neighbors) {
                            val attackerStat = min(10, max(1, cardData.stats[n.direction] + modifier))
                            val sum = attackerStat + n.stat
                            sumGroups.getOrPut(sum) { mutableListOf() }.add(n)
                        }
                        if (sumGroups.values.any { it.size >= 2 && it.any { info -> info.owner == targetOwner } }) {
                            hasPlus = true
                        }
                    }
                    if (hasSame && hasPlus) break
                }

                if (hasSame || hasPlus) {
                    val weight = (if (hasSame) 6 else 0) + (if (hasPlus) 3 else 0)
                    score += if (targetOwner == CardOwner.Player) weight else -weight
                }
            }
        }
        return score
    }
}
