package com.leah.honeycomb.honeycomb
import kotlinx.serialization.Serializable

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.leah.honeycomb.SharedGameOptions
import com.leah.honeycomb.PreferencesHelper
import com.leah.honeycomb.BannerCatalog
import com.leah.honeycomb.BannerFireResult
import com.leah.honeycomb.BannerId
import com.leah.honeycomb.BannerQueue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

@kotlinx.serialization.Serializable
data class HoneycombOptions(
    val difficulty: HoneycombDifficulty = HoneycombDifficulty.Easy,
    val activeDeckIndex: Int = 0,
    val selectedRules: Set<HoneycombRule> = emptySet(),
    val forceNormalMode: Boolean = false,
    val bannedRules: Set<String> = emptySet()
)

@Serializable
data class PendingSteal(
    val boardIndex: Int,
    val cardName: String
)

@Serializable
data class HoneycombState(
    val board: HoneycombBoard = HoneycombBoard(),
    val playerHand: List<HoneycombCard> = emptyList(),
    val playerStartingDeck: List<HoneycombCard> = emptyList(),
    val opponentHand: List<HoneycombCard> = emptyList(),
    val openOpponentCardIds: Set<String> = emptySet(),
    val openPlayerCardIds: Set<String> = emptySet(),
    val activeRules: List<HoneycombRule> = emptyList(),
    val ascensionDescensionSuits: Set<String> = emptySet(),
    val gameState: HoneycombGameState = HoneycombGameState.Setup,
    val isPlayerTurn: Boolean = true,
    val showPostGamePrompt: Boolean = false,
    val matchOutcome: HoneycombMatchOutcome = HoneycombMatchOutcome.None,
    val matchResult: String = "",
    val matchResultFlavorText: String? = null,
    val pendingSteal: PendingSteal? = null,
    val chaosPlayerIndex: Int? = null,
    val chaosOpponentIndex: Int? = null,
    val showSuddenDeathBanner: Boolean = false,
    // Transient capture-feedback state — which card(s) just directly caused a capture
    // (pop animation) and which of the attacker's stats won it (gold flash). Cleared
    // shortly after being set; not part of undo snapshots. Mirrors iOS's
    // captureAttackerIds/pointHighlight in shared/Honeycomb/ViewModels/HoneycombViewModel.swift.
    val captureAttackerIds: Set<String> = emptySet(),
    val pointHighlightCardId: String? = null,
    val pointHighlightStatIndices: Set<Int> = emptySet(),
    // Which two cards (by id) just traded hands under the Nectar Exchange (Swap) rule —
    // highlighted with the same pop/border treatment as a capture. Simplified stand-in
    // for iOS's 3-beat lift/fly/land matchedGeometryEffect choreography (swapAnimationPhase
    // in shared/Honeycomb/ViewModels/HoneycombViewModel.swift): a real, working "something
    // changed here" cue, not a byte-faithful port of that animation.
    val swapHighlightCardIds: Set<String> = emptySet(),
    // No Stress Mode as it was when this match was dealt — locked for the whole match
    // (deck composition and steal eligibility both read this, never the live toggle),
    // so flipping the global setting mid-match only takes effect at the next deal.
    // Persisted with the rest of the state so a restored match keeps its lock.
    val noStressModeThisMatch: Boolean = false,
    // Opponent difficulty this match was dealt at, locked like noStressModeThisMatch —
    // options.difficulty is editable mid-match, and reading it live let a player face
    // Easy's AI/deck then switch to Ultra Hard before the last card so the win recorded
    // as an Ultra Hard win. AI, stats, banners and the on-screen opponent name use this;
    // a Rematch keeps it (same opponent deck). Mirrors Swift's matchDifficulty.
    val matchDifficulty: HoneycombDifficulty = HoneycombDifficulty.Easy
) {
    val mandatedPlayerHandIndex: Int?
        get() {
            if (activeRules.contains(HoneycombRule.Order) && playerHand.isNotEmpty()) return 0
            if (activeRules.contains(HoneycombRule.Chaos)) return chaosPlayerIndex
            return null
        }
    val mandatedOpponentHandIndex: Int?
        get() {
            if (activeRules.contains(HoneycombRule.Order) && opponentHand.isNotEmpty()) return 0
            if (activeRules.contains(HoneycombRule.Chaos)) return chaosOpponentIndex
            return null
        }
}

// Match bookkeeping the ViewModel keeps outside HoneycombState, saved next to it so a
// match restored after the app was closed keeps its capture count (stats), Steal
// Protection, rematch chain and rematch opponent — all were silently lost before.
@kotlinx.serialization.Serializable
private data class HoneycombMatchExtras(
    val sessionCardsCaptured: Int = 0,
    val hasStolenThisMatch: Boolean = false,
    val isRematchMatch: Boolean = false,
    val consecutiveNoStealWins: Int = 0,
    val stealProtectionActive: Boolean = false,
    val consecutiveRematchWins: Int = 0,
    val consecutiveRematchLosses: Int = 0,
    val rematchOpponentDeck: List<HoneycombCardData> = emptyList(),
    val rematchActiveRules: List<HoneycombRule> = emptyList(),
    val rematchAscensionDescensionSuits: Set<String> = emptySet()
)

@OptIn(kotlinx.coroutines.FlowPreview::class)
class HoneycombViewModel(
    val sharedOptions: SharedGameOptions,
    val database: HoneycombDatabase,
    val profileManager: HoneycombProfileManager,
    private val dataStore: androidx.datastore.core.DataStore<androidx.datastore.preferences.core.Preferences>,
    private val bannerCatalog: BannerCatalog,
    private val appLanguage: kotlinx.coroutines.flow.StateFlow<com.leah.honeycomb.AppLanguage> = kotlinx.coroutines.flow.MutableStateFlow(com.leah.honeycomb.AppLanguage.English)
) : ViewModel(), com.leah.honeycomb.IdleActionChecking {

    private val _state = MutableStateFlow(HoneycombState())
    val state: StateFlow<HoneycombState> = _state.asStateFlow()

    private val _options = MutableStateFlow(loadOptions())
    val options: StateFlow<HoneycombOptions> = _options.asStateFlow()

    fun updateOptions(newOptions: HoneycombOptions) {
        _options.value = newOptions
        saveOptions(newOptions)
    }

    private fun loadOptions(): HoneycombOptions =
        PreferencesHelper.getObjectSync(dataStore, "honeycomb_options", HoneycombOptions.serializer(), HoneycombOptions())

    private fun saveOptions(options: HoneycombOptions) {
        PreferencesHelper.saveObjectAsync(dataStore, "honeycomb_options", HoneycombOptions.serializer(), options)
    }

    // Bad-luck protection for Roulette (see rollRouletteOnce below): re-rolling a draw
    // that exactly repeats the previous match's result, up to a small retry cap.
    private var lastRouletteSignature: String? = null

    private fun rouletteSignature(rules: List<HoneycombRule>, suits: Set<String>): String {
        val ruleNames = rules.map { it.name }.sorted().joinToString(",")
        val suitNames = suits.sorted().joinToString(",")
        return "$ruleNames|$suitNames"
    }

    // Weighted draw from `pool` using each rule's HoneycombRule.weight.
    private fun weightedRandomRule(pool: List<HoneycombRule>): HoneycombRule {
        val totalWeight = pool.sumOf { it.weight }
        var randomValue = (0 until totalWeight).random()
        for (rule in pool) {
            randomValue -= rule.weight
            if (randomValue < 0) return rule
        }
        return pool.last()
    }

    // One independent roulette draw — rule set plus (if applicable) Ascension/Descension
    // suit. Ported from Swift's rollRouletteOnce(): a flat per-draw stop probability
    // (not scaled by how much exclusivity has shrunk the pool), a difficulty-scaled slot
    // count (Hard/UltraHard can roll extra rules), and mutual-exclusivity pool-pruning
    // as each rule is drawn.
    private fun rollRouletteOnce(opts: HoneycombOptions): Pair<List<HoneycombRule>, Set<String>> {
        var pool = HoneycombRule.entries.toMutableList()
        pool.removeAll { opts.bannedRules.contains(it.name) }

        if (opts.difficulty == HoneycombDifficulty.Easy) {
            pool.removeAll { it == HoneycombRule.Ascension || it == HoneycombRule.Descension || it == HoneycombRule.FallenAce }
        }

        val normalBanned = opts.bannedRules.contains("Normal Mode")

        val originalPoolSize = pool.size
        val stopProbabilityFirst = 1.0 / (originalPoolSize + 1)
        val targetSingleRuleRate = 1.0 / 3.0
        val stopProbabilitySecond = targetSingleRuleRate / (1.0 - stopProbabilityFirst)

        var maxSlots = 2
        var forceMustPickAll = false

        if (opts.difficulty == HoneycombDifficulty.UltraHard) {
            val roll = Math.random()
            maxSlots = when {
                roll < 0.25 -> 4
                roll < 0.70 -> 3
                roll < 0.95 -> 2
                roll < 0.99 -> 1
                else -> 0
            }
            if (maxSlots == 0 && normalBanned) maxSlots = 1
            forceMustPickAll = true
        } else if (opts.difficulty == HoneycombDifficulty.Hard) {
            val hardRoll = Math.random()
            if (hardRoll < 0.01) {
                maxSlots = 4
                forceMustPickAll = true
            } else if (hardRoll < 0.26) {
                maxSlots = 3
                forceMustPickAll = true
            }
        }

        val rules = mutableListOf<HoneycombRule>()
        for (slot in 0 until maxSlots) {
            if (pool.isEmpty()) break
            val mustPick = (slot == 0 && normalBanned) || forceMustPickAll
            val stopProbability = if (slot == 0) stopProbabilityFirst else stopProbabilitySecond
            if (!mustPick && Math.random() < stopProbability) break

            val randomRule = weightedRandomRule(pool)
            rules.add(randomRule)
            pool.removeAll { it == randomRule }
            if (randomRule == HoneycombRule.Ascension) pool.removeAll { it == HoneycombRule.Descension }
            if (randomRule == HoneycombRule.Descension) pool.removeAll { it == HoneycombRule.Ascension }
            if (randomRule == HoneycombRule.Order) pool.removeAll { it == HoneycombRule.Chaos }
            if (randomRule == HoneycombRule.Chaos) pool.removeAll { it == HoneycombRule.Order }
            if (randomRule == HoneycombRule.AllOpen) pool.removeAll { it == HoneycombRule.ThreeOpen }
            if (randomRule == HoneycombRule.ThreeOpen) pool.removeAll { it == HoneycombRule.AllOpen }
            if (randomRule == HoneycombRule.AllOpen || randomRule == HoneycombRule.ThreeOpen) {
                pool.removeAll { it == HoneycombRule.BombShelter }
            }
            if (randomRule == HoneycombRule.BombShelter) {
                pool.removeAll { it == HoneycombRule.AllOpen || it == HoneycombRule.ThreeOpen }
            }
        }

        val suits = if (rules.contains(HoneycombRule.Ascension) || rules.contains(HoneycombRule.Descension)) {
            setOf(listOf("S", "H", "D", "C").random())
        } else {
            emptySet()
        }
        return Pair(rules, suits)
    }

    private var rematchOpponentDeck: List<HoneycombCardData> = emptyList()
    val canRematch: Boolean get() = rematchOpponentDeck.isNotEmpty()
    private var rematchActiveRules: List<HoneycombRule> = emptyList()
    private var rematchAscensionDescensionSuits: Set<String> = emptySet()

    private var isRematchMatch: Boolean = false
    private var consecutiveNoStealWins: Int = 0
    var stealProtectionActive: Boolean = false
        private set
    private val _statistics = MutableStateFlow(
        PreferencesHelper.getObjectSync(dataStore, "honeycomb_statistics", HoneycombStats.serializer(), HoneycombStats())
    )
    val statistics: StateFlow<HoneycombStats> = _statistics.asStateFlow()

    private fun updateStatistics(transform: (HoneycombStats) -> HoneycombStats) {
        val newStats = transform(_statistics.value)
        _statistics.value = newStats
        PreferencesHelper.saveObjectAsync(dataStore, "honeycomb_statistics", HoneycombStats.serializer(), newStats)
    }

    // Cumulative capture-flip count for the current match — mirrors Swift's
    // sessionCardsCaptured, incremented by each placeCard() call's flip count and reset
    // at the start of every new match/rematch.
    private var sessionCardsCaptured: Int = 0

    private var hasStolenThisMatch: Boolean = false
    private var starterStreak: Int = 0
    private var lastMatchStarterWasPlayer: Boolean? = null

    private var aiMoveGeneration: Int = 0

    // "N rematch wins/losses in a row against the same opponent" — reset by
    // startNewGame() (a fresh opponent) but NOT by rematch(), so these persist across
    // an entire rematch chain. Mirrors Swift's consecutiveRematchWins/Losses.
    private var consecutiveRematchWins: Int = 0
    private var consecutiveRematchLosses: Int = 0

    // "N matches in a row at the same AI difficulty" — deliberately NOT reset by
    // startNewGame(): unlike the rematch streaks above, a fresh match can still be at
    // the same difficulty as the last one, so this persists for the whole app session
    // and is only broken by the player picking a different difficulty (or by not being
    // in a rematch chain at all — see checkSameDifficultyStreak). Mirrors Swift's
    // lastPlayedDifficulty/consecutiveSameDifficultyCount.
    private var lastPlayedDifficulty: HoneycombDifficulty? = null
    private var consecutiveSameDifficultyCount: Int = 0

    // "Player uses Undo, thinks about it, and then makes the exact same move they just
    // undid" — lastPlayerMove tracks every player placement so undoLastAction() can
    // snapshot which move it's about to revert; pendingUndoRepeatCheck holds that move
    // only until the player's very next placement, whether or not it matches. Mirrors
    // Swift's lastPlayerMove/pendingUndoRepeatCheck.
    private var lastPlayerMove: Pair<Int, Int>? = null
    private var pendingUndoRepeatCheck: Pair<Int, Int>? = null

    init {
        val defaultState = HoneycombState()
        val savedState = PreferencesHelper.getObjectSync(
            dataStore, "honeycomb_saved_state", HoneycombState.serializer(), defaultState
        )

        if (savedState != defaultState && savedState.gameState != HoneycombGameState.Setup && savedState.gameState != HoneycombGameState.GameOver) {
            // Transient highlight/banner state was mid-animation when it was saved, and
            // the coroutines that would have cleared it didn't survive the process.
            _state.value = savedState.copy(
                showSuddenDeathBanner = false,
                captureAttackerIds = emptySet(),
                pointHighlightCardId = null,
                pointHighlightStatIndices = emptySet(),
                swapHighlightCardIds = emptySet()
            )
            val extras = PreferencesHelper.getObjectSync(
                dataStore, "honeycomb_saved_match_extras", HoneycombMatchExtras.serializer(), HoneycombMatchExtras()
            )
            sessionCardsCaptured = extras.sessionCardsCaptured
            hasStolenThisMatch = extras.hasStolenThisMatch
            isRematchMatch = extras.isRematchMatch
            consecutiveNoStealWins = extras.consecutiveNoStealWins
            stealProtectionActive = extras.stealProtectionActive
            consecutiveRematchWins = extras.consecutiveRematchWins
            consecutiveRematchLosses = extras.consecutiveRematchLosses
            rematchOpponentDeck = extras.rematchOpponentDeck
            rematchActiveRules = extras.rematchActiveRules
            rematchAscensionDescensionSuits = extras.rematchAscensionDescensionSuits
            if (!savedState.isPlayerTurn && savedState.gameState == HoneycombGameState.Playing) {
                scheduleAiTurn(1000)
            } else if (savedState.gameState == HoneycombGameState.SuddenDeath) {
                // Saved during the SuddenDeathPending window — the coroutine that would
                // have called triggerSuddenDeath() died with the process, so restart it
                // or the match is stuck on a full board with no way forward but Quit.
                scheduleSuddenDeathSequence()
            }
        } else {
            loadOptions()
        }

        viewModelScope.launch {
            _state.debounce(500).collect { currentState ->
                val matchOver = currentState.gameState == HoneycombGameState.GameOver || currentState.gameState == HoneycombGameState.Setup
                val toSave = if (matchOver) defaultState else currentState
                val extras = if (matchOver) HoneycombMatchExtras() else HoneycombMatchExtras(
                    sessionCardsCaptured, hasStolenThisMatch, isRematchMatch, consecutiveNoStealWins,
                    stealProtectionActive, consecutiveRematchWins, consecutiveRematchLosses,
                    rematchOpponentDeck, rematchActiveRules, rematchAscensionDescensionSuits
                )
                PreferencesHelper.setObject(
                    dataStore, "honeycomb_saved_match_extras", HoneycombMatchExtras.serializer(), extras
                )
                PreferencesHelper.setObject(
                    dataStore, "honeycomb_saved_state", HoneycombState.serializer(), toSave
                )
            }
        }
    }

    // Leaving a match that's still being played — Quit Match, or a new match mid-match —
    // counts as a loss and ends the win streak (product decision; same idea as
    // abandoning a solitaire game). Otherwise quitting a match you're losing kept the
    // streak alive. Sudden Death overtime is still the same match, so it counts too.
    // Mac parity (recordAbandonedMatchIfInProgress).
    private fun recordAbandonedMatchIfInProgress() {
        val st = _state.value
        if (st.gameState != HoneycombGameState.Playing && st.gameState != HoneycombGameState.SuddenDeath) return
        updateStatistics {
            it.recordGame(
                won = false, drawn = false,
                captures = sessionCardsCaptured,
                sessionCombos = st.board.sessionSamePlusTriggers,
                flawless = false,
                fallenAceCaptures = st.board.sessionFallenAceCaptures
            )
        }
    }

    fun startNewGame() {
        recordAbandonedMatchIfInProgress()
        resetMatchTransients()
        isRematchMatch = false
        consecutiveNoStealWins = 0
        stealProtectionActive = false
        hasStolenThisMatch = false
        sessionCardsCaptured = 0
        hintUsageCountThisMatch = 0
        consecutiveRematchWins = 0
        consecutiveRematchLosses = 0
        lastPlayerMove = null
        pendingUndoRepeatCheck = null

        var rolledRules = emptyList<HoneycombRule>()
        var rolledSuits = emptySet<String>()
        val opts = _options.value

        if (opts.forceNormalMode) {
            // Explicitly locked to zero rules — a real "Normal" match, as opposed to
            // an empty selectedRules (which means "let roulette decide" below).
        } else if (opts.selectedRules.isEmpty()) {
            // Auto: let roulette decide, with bad-luck protection against repeating the
            // exact same outcome (rules + suit) as the previous match.
            var attempt: Pair<List<HoneycombRule>, Set<String>>
            var attempts = 0
            do {
                attempt = rollRouletteOnce(opts)
                attempts++
            } while (rouletteSignature(attempt.first, attempt.second) == lastRouletteSignature && attempts < 5)
            rolledRules = attempt.first
            rolledSuits = attempt.second
            lastRouletteSignature = rouletteSignature(rolledRules, rolledSuits)
        } else {
            rolledRules = opts.selectedRules.toList()
            // Picked rules draw their Pollination/Smoked Out suit here. Roulette already
            // drew one inside rollRouletteOnce — drawing again overwrote it, so the
            // repeat-protection above compared one suit while the match used another
            // (Mac/Windows keep the roulette's own suit).
            if (rolledRules.contains(HoneycombRule.Ascension) || rolledRules.contains(HoneycombRule.Descension)) {
                rolledSuits = setOf(listOf("S", "H", "D", "C").random())
            }
        }
        
        val noStressModeThisMatch = sharedOptions.noStressMode.value
        val deck = rollOpponentDeck(opts.difficulty, rolledRules, rolledSuits, noStressModeThisMatch)
        
        rematchOpponentDeck = deck
        rematchActiveRules = rolledRules
        rematchAscensionDescensionSuits = rolledSuits

        val opponentHand = deck.map { HoneycombCard(it, CardOwner.Opponent) }

        // Built from defaults rather than copy()'d from the previous match, so nothing
        // match-scoped (matchOutcome, pendingSteal, Sudden Death banner, highlights...)
        // can leak across into the new one.
        _state.value = HoneycombState(
            board = HoneycombBoard().apply { ascensionDescensionSuits = rolledSuits },
            activeRules = rolledRules,
            ascensionDescensionSuits = rolledSuits,
            opponentHand = opponentHand,
            gameState = HoneycombGameState.Playing,
            noStressModeThisMatch = noStressModeThisMatch,
            matchDifficulty = opts.difficulty
        )
        setupPlayerHand()
        finishMatchSetup()
    }

    fun rematch() {
        // Only from a finished match: a fast double-tap on Rematch otherwise ran it twice,
        // re-dealing the just-started rematch and flipping the alternating starter again.
        if (_state.value.gameState != HoneycombGameState.GameOver) return
        if (rematchOpponentDeck.isEmpty()) {
            startNewGame()
            return
        }
        resetMatchTransients()
        isRematchMatch = true
        hasStolenThisMatch = false
        sessionCardsCaptured = 0
        hintUsageCountThisMatch = 0
        lastPlayerMove = null
        pendingUndoRepeatCheck = null

        val opponentHand = rematchOpponentDeck.map { HoneycombCard(it, CardOwner.Opponent) }
        
        // The opponent deck is reused, not re-rolled, but a rematch is still a new match:
        // it takes No Stress Mode's current value for its own lock (steal eligibility).
        _state.value = HoneycombState(
            board = HoneycombBoard().apply { ascensionDescensionSuits = rematchAscensionDescensionSuits },
            activeRules = rematchActiveRules,
            ascensionDescensionSuits = rematchAscensionDescensionSuits,
            opponentHand = opponentHand,
            gameState = HoneycombGameState.Playing,
            noStressModeThisMatch = sharedOptions.noStressMode.value,
            matchDifficulty = _state.value.matchDifficulty
        )
        setupPlayerHand()
        finishMatchSetup(forceAlternateStarter = true)
    }

    private fun setupPlayerHand() {
        val pDeckData = if (_state.value.noStressModeThisMatch) {
            // Overpowered deck: one 5★, one 4★, three 3★ — the strongest composition that
            // still respects the same rarity caps a normal deck must (max one 5★; max one
            // 4★ once a 5★ is present). Mirrors iOS/Mac's setupPlayerHand and Windows'
            // BuildPlayerHand, which deal this instead of the saved deck under No Stress.
            database.randomCards(stars = 5, count = 1) +
                database.randomCards(stars = 4, count = 1) +
                database.randomCards(stars = 3, count = 3)
        } else {
            val activeDeckIndex = _options.value.activeDeckIndex
            val savedDecks = profileManager.savedDecks.value
            val deckIds = if (activeDeckIndex in savedDecks.indices) savedDecks[activeDeckIndex].cardIds else emptyList()
            deckIds.mapNotNull { database.card(it) }
        }
        val pDeck = pDeckData.map { HoneycombCard(it, CardOwner.Player) }.toMutableList()
        
        val oDeck = _state.value.opponentHand.toMutableList()

        var swappedOppCardId: String? = null
        var swappedPlayerCardId: String? = null
        var swapBannerText: String? = null
        if (rematchActiveRules.contains(HoneycombRule.Swap) && pDeck.isNotEmpty() && oDeck.isNotEmpty()) {
            val pIdx = pDeck.indices.random()
            val oIdx = oDeck.indices.random()

            val pCard = pDeck[pIdx]
            val oCard = oDeck[oIdx]
            swapBannerText = formatSwapRuleForBanner(
                swappedAwayPlayerFiveStar = pCard.data.stars == 5,
                tradedUpForPlayer = oCard.data.stars > pCard.data.stars
            )

            pDeck[pIdx] = HoneycombCard(oCard.data, CardOwner.Player, CardOwner.Opponent, oCard.id)
            oDeck[oIdx] = HoneycombCard(pCard.data, CardOwner.Opponent, CardOwner.Player, pCard.id)
            // The swapped-in card is always known to the AI regardless of All Open/Three
            // Open, matching iOS's applyOpponentDeck — otherwise minimaxScore treats the
            // player's swapped slot as unknown and falls back to a shallow leaf evaluation.
            swappedOppCardId = oCard.id
            swappedPlayerCardId = pCard.id
        }

        var openOppIds = emptySet<String>()
        if (rematchActiveRules.contains(HoneycombRule.AllOpen)) {
            openOppIds = oDeck.map { it.id }.toSet()
        } else if (rematchActiveRules.contains(HoneycombRule.ThreeOpen)) {
            openOppIds = oDeck.shuffled().take(3).map { it.id }.toSet()
        }
        swappedOppCardId?.let { openOppIds = openOppIds + it }

        var openPlayerIds = emptySet<String>()
        if (rematchActiveRules.contains(HoneycombRule.AllOpen)) {
            openPlayerIds = pDeck.map { it.id }.toSet()
        } else if (rematchActiveRules.contains(HoneycombRule.ThreeOpen)) {
            openPlayerIds = pDeck.shuffled().take(3).map { it.id }.toSet()
        }
        swappedPlayerCardId?.let { openPlayerIds = openPlayerIds + it }

        val swapIds = setOfNotNull(swappedOppCardId, swappedPlayerCardId)

        _state.update { it.copy(
            playerHand = pDeck,
            playerStartingDeck = pDeck,
            openPlayerCardIds = openPlayerIds,
            opponentHand = oDeck,
            openOpponentCardIds = openOppIds,
            swapHighlightCardIds = swapIds
        ) }

        if (swapIds.isNotEmpty()) {
            enqueueBanner(swapBannerText ?: "${HoneycombRule.Swap.localizedName(bannerCatalog.currentLanguage)}!")
            swapHighlightJob?.cancel()
            swapHighlightJob = viewModelScope.launch {
                delay(2000)
                _state.update { it.copy(swapHighlightCardIds = emptySet()) }
            }
        }
    }

    // Cancelled by resetMatchTransients() so a quit/new match inside the 2s window can't
    // clear the next match's Swap highlight early.
    private var swapHighlightJob: kotlinx.coroutines.Job? = null

    private fun rollOpponentDeck(difficulty: HoneycombDifficulty, rules: List<HoneycombRule>, suits: Set<String>, noStressMode: Boolean): List<HoneycombCardData> {
        // Matches shared/Honeycomb/ViewModels/HoneycombViewModel.swift's
        // normalComposition/reverseComposition exactly — Medium and Hard's star tiers
        // here previously diverged from iOS (Medium included a 1★ slot iOS's Medium never
        // deals; Hard never included a 4★/5★ card at all), making Hard trivially easier
        // than iOS and denying players the higher-tier steal rewards iOS guarantees there.
        val preferLowStats = rules.contains(HoneycombRule.Reverse)
        val composition = if (preferLowStats) {
            when (difficulty) {
                HoneycombDifficulty.Easy -> listOf(Pair(1, 3), Pair(2, 1), Pair(if (Math.random() < 0.2) 3 else 2, 1))
                HoneycombDifficulty.Medium -> listOf(Pair(2, 4), Pair(if (Math.random() < 0.2) 4 else 3, 1))
                HoneycombDifficulty.Hard -> listOf(Pair(1, 2), Pair(2, 3))
                HoneycombDifficulty.UltraHard -> listOf(Pair(1, 5))
            }
        } else {
            when (difficulty) {
                HoneycombDifficulty.Easy -> listOf(Pair(1, 3), Pair(2, 1), Pair(if (Math.random() < 0.2) 3 else 2, 1))
                HoneycombDifficulty.Medium -> listOf(Pair(2, 4), Pair(if (Math.random() < 0.2) 4 else 3, 1))
                HoneycombDifficulty.Hard -> listOf(Pair(3, 3), Pair(4, 1), Pair(5, 1))
                HoneycombDifficulty.UltraHard -> listOf(Pair(3, 2), Pair(4, 1), Pair(5, 2))
            }
        }
        
        val deck = mutableListOf<HoneycombCardData>()
        for ((stars, count) in composition) {
            deck.addAll(database.rulesAwareCards(stars, count, preferLowStats))
        }

        deck.shuffle()
        com.leah.honeycomb.audio.UISound.play("shuffle")

        // Favor New Cards (always on, not a toggle): if every card in the assembled deck
        // is already owned by the player, swap the first owned card for an unowned card
        // from the same star tier (if one exists) — guarantees at least one stealable
        // card per match without touching deck quality or rarity composition.
        if (!noStressMode) {
            val owned = profileManager.unlockedCardIds.value
            val allOwned = deck.all { owned.contains(it.id) }
            if (allOwned) {
                for (i in deck.indices) {
                    val tier = deck[i].stars
                    val unownedInTier = database.allCards.filter { it.stars == tier && !owned.contains(it.id) }
                    val substitute = unownedInTier.randomOrNull()
                    if (substitute != null) {
                        deck[i] = substitute
                        break
                    }
                }
            }
        }

        return ensureAscensionCoverage(deck, difficulty, rules, suits)
    }

    // Ultra Hard only: a player can stack their own deck with cards of the rolled
    // Ascension suit(s) to farm the +1-per-suit-card-on-board bonus, while the
    // opponent's deck is otherwise assembled with no awareness of which suits are even
    // in play. Guarantees at least 3 of the opponent's 5 cards match an active Ascension
    // suit so the AI can benefit from the same bonus the player is exploiting. Descension
    // is deliberately left alone — it's a penalty, so forcing more Descension-suited
    // cards into the AI's hand would only hurt it, not balance anything.
    private fun ensureAscensionCoverage(
        deck: List<HoneycombCardData>,
        difficulty: HoneycombDifficulty,
        rules: List<HoneycombRule>,
        suits: Set<String>
    ): List<HoneycombCardData> {
        if (difficulty != HoneycombDifficulty.UltraHard || !rules.contains(HoneycombRule.Ascension) || suits.isEmpty()) {
            return deck
        }

        val result = deck.toMutableList()
        var matchingCount = result.count { suits.contains(it.suit) }
        if (matchingCount >= 3) return result

        val nonMatchingIndices = result.indices
            .filter { !suits.contains(result[it].suit) }
            .sortedBy { result[it].stars }

        for (idx in nonMatchingIndices) {
            if (matchingCount >= 3) break
            val tier = result[idx].stars
            val usedIds = result.map { it.id }.toSet()
            val candidates = database.allCards.filter { it.stars == tier && suits.contains(it.suit) && !usedIds.contains(it.id) }
            val substitute = candidates.randomOrNull() ?: continue
            result[idx] = substitute
            matchingCount++
        }

        return result
    }

    private fun finishMatchSetup(forceAlternateStarter: Boolean = false) {
        val playerStarts = if (forceAlternateStarter && lastMatchStarterWasPlayer != null) {
            !lastMatchStarterWasPlayer!!
        } else if (starterStreak >= 3 && lastMatchStarterWasPlayer != null) {
            !lastMatchStarterWasPlayer!!
        } else {
            Math.random() < 0.5
        }

        if (lastMatchStarterWasPlayer == playerStarts) {
            starterStreak++
        } else {
            starterStreak = 1
        }
        lastMatchStarterWasPlayer = playerStarts

        _state.update {
            it.copy(
                isPlayerTurn = playerStarts,
                chaosPlayerIndex = if (it.activeRules.contains(HoneycombRule.Chaos) && it.playerHand.isNotEmpty()) (0 until it.playerHand.size).random() else null,
                chaosOpponentIndex = if (it.activeRules.contains(HoneycombRule.Chaos) && it.opponentHand.isNotEmpty()) (0 until it.opponentHand.size).random() else null,
            )
        }

        scheduleIdleCheck()

        // Every active rule gets its own line below "First Move" — mirrors Swift's
        // finishMatchSetup. Swap's line is composed separately in setupPlayerHand
        // (it needs the actual swap outcome, not just "the rule is active"), so it's
        // skipped here to avoid a duplicate plain-name line.
        val language = appLanguage.value
        val st = _state.value
        val firstMoveLine = if (playerStarts) {
            com.leah.honeycomb.Strings.get(com.leah.honeycomb.StringKey.FirstMovePlayer, language)
        } else {
            com.leah.honeycomb.Strings.format(com.leah.honeycomb.StringKey.FirstMoveOpponentFmt, language, _state.value.matchDifficulty.localizedName(language))
        }
        val ruleLines = st.activeRules.filter { it != HoneycombRule.Swap }.map { formatRuleForBanner(it) }.toMutableList()
        // A ruleless match has no per-rule line to (20% of the time) swap for flavor
        // text — this is that same gate, just for the "no extra rules" case, which
        // only ever adds a line, never replaces one.
        if (st.activeRules.isEmpty()) {
            val zeroRulesResult = bannerCatalog.fire(BannerId.RuleSpecificRouletteRollsZeroExtraRules)
            if (zeroRulesResult is BannerFireResult.Message) ruleLines.add(zeroRulesResult.text)
        }
        // NB: startNewGame()/rematch() already call clearBanners() before
        // setupPlayerHand() enqueues the Swap highlight banner (if any) — this just
        // queues behind it rather than clearing it, matching the existing FIFO.
        enqueueBanner((listOf(firstMoveLine) + ruleLines).joinToString("\n"), longDuration = true)

        // stats.gamesPlayed only increments in settleMatch, so it's still 0 here iff
        // this is the very first match this player has ever started (or the first
        // since a stats reset).
        if (_statistics.value.gamesPlayed == 0) {
            val firstLaunchResult = bannerCatalog.fire(BannerId.MilestonesFirstLaunchEver)
            if (firstLaunchResult is BannerFireResult.Message) enqueueBanner(firstLaunchResult.text, longDuration = true)
        }

        checkSameDifficultyStreak()

        if (!playerStarts) {
            scheduleAiTurn(2500)
        } else {
            prewarmHint()
        }
    }

    // Snapshotted right before a player move, popped on undo — reverts both the
    // player's move and the AI's subsequent response in one step, since undo is only
    // ever available again once it's the player's turn (matching Swift's
    // `canUndo: !undoStack.isEmpty && gameState == .playing && isPlayerTurn`).
    private val undoHistory = ArrayDeque<HoneycombState>()
    // sessionCardsCaptured lives outside HoneycombState, so it needs its own parallel undo
    // stack, pushed/popped in lockstep with undoHistory — matches iOS's HoneycombSnapshot,
    // which bundles sessionCardsCaptured into the same undo snapshot as the board.
    private val undoSessionCardsCaptured = ArrayDeque<Int>()

    private fun snapshotForUndo() {
        val st = _state.value
        undoHistory.addLast(
            st.copy(
                board = st.board.copy(cells = st.board.cells.map { it.copy(card = it.card?.copy()) }),
                playerHand = st.playerHand.map { it.copy() },
                opponentHand = st.opponentHand.map { it.copy() },
                // Transient highlights are cleared by their own delayed coroutines, which
                // will have already run by the time this snapshot is restored — keeping
                // them here would bring them back with nothing left to clear them.
                captureAttackerIds = emptySet(),
                pointHighlightCardId = null,
                pointHighlightStatIndices = emptySet(),
                swapHighlightCardIds = emptySet()
            )
        )
        undoSessionCardsCaptured.addLast(sessionCardsCaptured)
    }

    val canUndo: Boolean
        get() = undoHistory.isNotEmpty() && _state.value.gameState == HoneycombGameState.Playing && _state.value.isPlayerTurn

    fun undoLastAction() {
        if (!canUndo) return
        aiMoveGeneration++ // invalidate any pending delayed AI-turn closure from the move being undone
        hintGeneration++
        _state.value = undoHistory.removeLast()
        sessionCardsCaptured = undoSessionCardsCaptured.removeLast()
        clearBanners()
        // Item 3: snapshot the move being undone so the player's very next placement can
        // detect a repeat — cleared unconditionally in playerPlayCard regardless of
        // whether it matches. Mirrors Swift's `pendingUndoRepeatCheck = lastPlayerMove`.
        pendingUndoRepeatCheck = lastPlayerMove
        val result = bannerCatalog.fire(BannerId.GameplayUndoUsedImmediatelyAfterAPlacement)
        if (result is BannerFireResult.Message) enqueueBanner(result.text)
    }

    val hasHintsAvailable: Boolean
        get() = _state.value.gameState == HoneycombGameState.Playing && _state.value.isPlayerTurn && _state.value.playerHand.isNotEmpty()

    private val _hintMove = MutableStateFlow<Pair<Int, Int>?>(null)
    val hintMove: StateFlow<Pair<Int, Int>?> = _hintMove.asStateFlow()

    // Port of iOS's bannerQueue/enqueueBanner/advanceBannerQueue, now backed by the
    // shared BannerCatalog content (BannerCatalog.kt) rather than Honeycomb's own
    // hand-rolled mechanical-only queue. See enqueueCaptureBanners/finishMatchSetup/
    // checkWinMilestones/etc. below for the catalog call sites this replaces.
    private val bannerQueue = BannerQueue(viewModelScope) { sharedOptions.manuallyDismissBanners.value }
    val activeBanner: StateFlow<String?> = bannerQueue.active

    // longDuration no longer changes anything display-wise — every toast is a uniform
    // 2000ms now (see BannerQueue.kt), matching Mac/Windows' 2026-08-07 unification
    // (commit 6856678, "Unify all toast durations to 2.0s"). Kept as a parameter only
    // because removing it would mean touching every call site above for no behavioral
    // gain, mirroring Swift's isLongDuration/flashRuleBannerIsLongDuration being left in
    // place on the queue for the same reason.
    private fun enqueueBanner(text: String, longDuration: Boolean = false) {
        bannerQueue.enqueue(text)
    }

    private fun clearBanners() {
        bannerQueue.clear()
    }

    fun dismissBanner() = bannerQueue.dismissCurrent()

    // Matches iOS's postGameOverlay dismiss button (viewModel.showPostGamePrompt = false) —
    // the win/lose overlay card's own top-trailing X, not a route/game-state change.
    fun dismissPostGamePrompt() {
        _state.update { it.copy(showPostGamePrompt = false) }
    }

    // Fires `id` through the banner catalog and returns whatever it decided should
    // show — the catalog's own flavor text (per the 20% gate), or `existingDefaultText`
    // otherwise. Deliberately uses the caller's own default rather than the catalog
    // entry's own `fallback` field so this doesn't depend on the catalog's fallback
    // string matching this platform's existing text exactly. Mirrors Swift's
    // HoneycombViewModel.bannerCatalogText / Windows' BannerCatalogText.
    private fun bannerCatalogText(id: BannerId, existingDefaultText: String, tokens: Map<String, String> = emptyMap()): String {
        return when (val result = bannerCatalog.fire(id, tokens)) {
            is BannerFireResult.Message -> result.text
            else -> existingDefaultText
        }
    }

    // Maps a rule to the catalog's "Roulette rolls X" flavor id for that rule's intro
    // banner line — mirrors Swift's rouletteBannerID(for:). Rules with no catalog
    // entry (Fallen Ace, Bomb Shelter, Sudden Death) return null and keep their plain
    // display name unconditionally.
    private fun rouletteBannerId(rule: HoneycombRule): BannerId? = when (rule) {
        HoneycombRule.Ascension -> BannerId.RuleSpecificRouletteRollsPollination
        HoneycombRule.Descension -> BannerId.RuleSpecificRouletteRollsSmokedOut
        HoneycombRule.Plus -> BannerId.RuleSpecificRouletteRollsMathBee
        HoneycombRule.Reverse -> BannerId.RuleSpecificRouletteRollsInversion
        HoneycombRule.AllOpen -> BannerId.RuleSpecificRouletteRollsClearSkies
        HoneycombRule.ThreeOpen -> BannerId.RuleSpecificRouletteRollsScoutingParty
        HoneycombRule.Chaos -> BannerId.RuleSpecificRouletteRollsFrenzy
        HoneycombRule.Same -> BannerId.RuleSpecificRouletteRollsSymmetry
        HoneycombRule.Swap -> BannerId.RuleSpecificRouletteRollsNectarExchange
        HoneycombRule.Order -> BannerId.RuleSpecificRouletteRollsHierarchy
        HoneycombRule.FallenAce, HoneycombRule.BombShelter, HoneycombRule.SuddenDeath -> null
    }

    // Intro-banner line for one active rule — 20% of the time swaps the plain rule
    // name for catalog flavor text (e.g. "Pollen is in the air!" instead of
    // "Pollination"). Mirrors Swift's formatRuleForBanner. Ascension/Descension's
    // affected-suit annotation (iOS's suitNames line) isn't reproduced here — Android's
    // rule-name capsule already shows the active suits separately (see
    // HoneycombMatchUI.kt's RulesCapsule), so this only needs the plain/flavor name.
    private fun formatRuleForBanner(rule: HoneycombRule): String {
        val defaultText = rule.localizedName(bannerCatalog.currentLanguage)
        val bannerId = rouletteBannerId(rule) ?: return defaultText
        return bannerCatalogText(bannerId, defaultText)
    }

    // Nectar Exchange (Swap) gets its own formatter because its flavor text depends on
    // what the trade actually did, not just that the rule is active. Mirrors Swift's
    // formatSwapRuleForBanner.
    private fun formatSwapRuleForBanner(swappedAwayPlayerFiveStar: Boolean, tradedUpForPlayer: Boolean): String {
        val defaultText = HoneycombRule.Swap.localizedName(bannerCatalog.currentLanguage)
        val tokens = mapOf("OpponentName" to _state.value.matchDifficulty.displayName)
        if (swappedAwayPlayerFiveStar) {
            return bannerCatalogText(BannerId.RuleSpecificNectarExchangeSwapsAwayThePlayers5StarCard, defaultText, tokens)
        }
        if (tradedUpForPlayer) {
            return bannerCatalogText(BannerId.RuleSpecificNectarExchangeTradesThePlayersWorstCardForThe, defaultText, tokens)
        }
        return bannerCatalogText(BannerId.RuleSpecificRouletteRollsNectarExchange, defaultText, tokens)
    }

    // A card of `suit` (excluding face-down ones) whose modifier has reached at least
    // `threshold` — used to decide whether Ascension's per-placement banner has earned
    // its "in full bloom" flavor alternate yet. Ported from Swift's private static
    // hasCard(matching:modifierAtLeast:on:).
    private fun hasCardModifierAtLeast(suit: String, threshold: Int, board: HoneycombBoard): Boolean {
        return board.cells.any { cell ->
            val card = cell.card
            card != null && !card.isFaceDown && card.data.suit == suit && card.modifier >= threshold
        }
    }

    // A card of `suit` (excluding face-down ones) whose negative modifier has actually
    // clamped one of its stats down to the 1 floor (HoneycombCard.stat(index) clamps to
    // 1..10) — used to decide whether Descension's per-placement banner has earned its
    // "Smoked Out" flavor alternate yet. Ported from Swift's private static
    // hasCard(matching:clampedToOneOn:).
    private fun hasCardClampedToOne(suit: String, board: HoneycombBoard): Boolean {
        return board.cells.any { cell ->
            val card = cell.card
            if (card == null || card.isFaceDown || card.data.suit != suit || card.modifier >= 0) return@any false
            (0 until 4).any { card.data.stats[it] + card.modifier <= 1 }
        }
    }

    // Ascension/Descension's per-placement "kicked in" flavor banner — fires for either
    // side's placement as long as the placed card's own suit is one of the match's 2
    // chosen suits, skipped on the board's very last move (the win/lose overlay covers
    // that transition already). Ported from Swift's bannerText's Ascension/Descension
    // block.
    private fun ascensionDescensionBannerText(placedCard: HoneycombCard, board: HoneycombBoard, rules: List<HoneycombRule>): String? {
        val placedSuit = placedCard.data.suit
        if (board.isFull || !board.ascensionDescensionSuits.contains(placedSuit)) return null
        if (rules.contains(HoneycombRule.Ascension)) {
            val defaultText = "${HoneycombRule.Ascension.localizedName(bannerCatalog.currentLanguage)}!"
            return if (hasCardModifierAtLeast(placedSuit, 3, board)) {
                bannerCatalogText(
                    BannerId.RuleSpecificPollinationPushesACardsModifierTo3OrHigher,
                    defaultText,
                    mapOf("AscensionSuit" to HoneycombCardData.suitDisplayName(placedSuit))
                )
            } else defaultText
        } else if (rules.contains(HoneycombRule.Descension)) {
            val defaultText = "${HoneycombRule.Descension.localizedName(bannerCatalog.currentLanguage)}!"
            return if (hasCardClampedToOne(placedSuit, board)) {
                bannerCatalogText(BannerId.RuleSpecificSmokedOutDropsACardsEffectiveStatTo1, defaultText)
            } else defaultText
        }
        return null
    }

    // Fires the Same!/Plus!/Fallen Ace! rule-name banners for a placement's own direct
    // captures, and the Combo x{N} banner for the placement's own chain flips — the
    // mechanical (non-flavor) subset of Swift's comboBannerText/bannerText, now routed
    // through the catalog so Plus/Fallen Ace/Combo x4+ occasionally show their flavor
    // alternates instead of the plain rule name. Also fires the Ascension/Descension
    // flavor banner (item 1) and the flip-count/rarity/board-state flavor banners (item
    // 2) for this same placement — all ported from Swift's bannerText.
    private fun enqueueCaptureBanners(
        board: HoneycombBoard,
        rules: List<HoneycombRule>,
        placedCard: HoneycombCard,
        boardIndex: Int,
        flips: List<Int>
    ) {
        var comboBannerFired = false
        if (board.lastSameTriggered) {
            enqueueBanner("${HoneycombRule.Same.localizedName(bannerCatalog.currentLanguage)}!")
            comboBannerFired = true
        }
        if (board.lastPlusTriggered) {
            enqueueBanner(bannerCatalogText(BannerId.RuleSpecificAPlayerTriggersAPlusComboTheMathMatchesPerfectly, "${HoneycombRule.Plus.localizedName(bannerCatalog.currentLanguage)}!"))
            comboBannerFired = true
        }
        if (board.lastFallenAceTriggered && rules.contains(HoneycombRule.FallenAce)) {
            enqueueBanner(bannerCatalogText(BannerId.RuleSpecificFallenAceTriggersA1CapturesA10, "${HoneycombRule.FallenAce.localizedName(bannerCatalog.currentLanguage)}!"))
            comboBannerFired = true
        }
        if (board.lastComboFlipCount >= 4) {
            val count = board.lastComboFlipCount
            enqueueBanner(bannerCatalogText(
                BannerId.GameplayComboX4OrHigher,
                "HIVE MIND x$count!",
                mapOf("ComboCount" to "$count")
            ))
            comboBannerFired = true
        } else if (board.lastComboFlipCount > 0) {
            enqueueBanner("HIVE MIND x${board.lastComboFlipCount}!")
            comboBannerFired = true
        }

        // Item 1: Ascension/Descension "kicked in" flavor banners.
        ascensionDescensionBannerText(placedCard, board, rules)?.let { enqueueBanner(it) }

        // Item 2: flip-based gameplay banners — ungated/no-fallback-swap, appended
        // straight from the catalog's own message text (or skipped if the catalog
        // decided not to fire), matching Swift's bare `.fire(id)` usage here (as
        // opposed to the bannerCatalogText wrapper used above).
        if (!comboBannerFired && flips.size >= 3) {
            val id = if (placedCard.owner == CardOwner.Player) {
                BannerId.GameplayPlayerFlips3CardsInASingleTurn
            } else {
                BannerId.GameplayOpponentFlips3OfThePlayersCardsInASingleTurnNotA
            }
            val result = bannerCatalog.fire(id)
            if (result is BannerFireResult.Message) enqueueBanner(result.text)
        }
        val directFlipsCount = flips.count { neighborDirection(boardIndex, it) != null }
        if (directFlipsCount == 4) {
            val result = bannerCatalog.fire(BannerId.GameplayAPlacedCardCapturesOnAll4SidesAtOnce)
            if (result is BannerFireResult.Message) enqueueBanner(result.text)
        }
        if (placedCard.data.stars == 1 && flips.isNotEmpty()) {
            if (flips.size >= 3) {
                val result = bannerCatalog.fire(BannerId.GameplayA1StarCardCaptures3CardsInOneMove)
                if (result is BannerFireResult.Message) enqueueBanner(result.text)
            }
            val capturedFiveStar = flips.any { board.cells[it].card?.data?.stars == 5 }
            if (capturedFiveStar) {
                val result = bannerCatalog.fire(BannerId.GameplayA1StarCardCapturesA5StarCardRarityMismatch)
                if (result is BannerFireResult.Message) enqueueBanner(result.text)
            }
        }
        val playerOwnedOnBoard = board.cells.count { it.card?.owner == CardOwner.Player }
        val opponentOwnedOnBoard = board.cells.count { it.card?.owner == CardOwner.Opponent }
        if (playerOwnedOnBoard == 2 && opponentOwnedOnBoard == 6) {
            val result = bannerCatalog.fire(BannerId.GameplayPlayerHasOnly2CardsOnTheBoardVsOpponents6Few)
            if (result is BannerFireResult.Message) enqueueBanner(result.text)
        }
    }

    // Fires once, exactly on the 5th consecutive REMATCH at the same difficulty — not
    // "count >= 5" (which would fire on every match after that too), and not counting
    // plain New Game starts: a fresh New Game at the same difficulty doesn't demonstrate
    // "you keep coming back to fight this same difficulty tier" the way a real Rematch
    // chain does. Mirrors Swift's checkSameDifficultyStreak/Windows' CheckSameDifficultyStreak.
    private fun checkSameDifficultyStreak() {
        if (!isRematchMatch) {
            consecutiveSameDifficultyCount = 0
            lastPlayedDifficulty = null
            return
        }
        val difficulty = _state.value.matchDifficulty
        if (difficulty == lastPlayedDifficulty) {
            consecutiveSameDifficultyCount++
        } else {
            lastPlayedDifficulty = difficulty
            consecutiveSameDifficultyCount = 1
        }
        if (consecutiveSameDifficultyCount == 5) {
            val result = bannerCatalog.fire(BannerId.GameplayPlayerPlaysAgainstTheSameAiDifficulty5TimesInARow)
            if (result is BannerFireResult.Message) enqueueBanner(result.text, longDuration = true)
        }
    }

    // Fires once, exactly on the win that crosses a threshold — not "matchesWon >=
    // threshold", which would fire on every subsequent win too. Mirrors Windows'
    // GameViewModel.CheckWinMilestones.
    private fun checkWinMilestones(previousMatchesWon: Int, newMatchesWon: Int) {
        val thresholds = listOf(
            10 to BannerId.MilestonesPlayerReaches10TotalWins,
            100 to BannerId.MilestonesPlayerReaches100TotalWins,
            1000 to BannerId.MilestonesPlayerReaches1000TotalWins
        )
        for ((threshold, id) in thresholds) {
            if (newMatchesWon != threshold || previousMatchesWon >= threshold) continue
            val result = bannerCatalog.fire(id)
            if (result is BannerFireResult.Message) enqueueBanner(result.text, longDuration = true)
        }
    }

    // Fires once per app session, the first time Honeycomb's own screen actually
    // displays (see HoneycombMatchUI's LaunchedEffect). A "loading" banner belongs to a
    // screen transition, not a gameplay action. Mirrors Windows' GameView's
    // vm.CheckLoadingBanner() / BannerCatalog.LoadingBannerId().
    private var hasFiredLoadingBannerThisSession = false

    fun checkLoadingBanner() {
        if (hasFiredLoadingBannerThisSession) return
        hasFiredLoadingBannerThisSession = true
        val id = bannerCatalog.loadingBannerId()
        val result = bannerCatalog.fire(id)
        if (result is BannerFireResult.Message) {
            val durationMs = if (bannerCatalog.consumeAppLaunchLoadingFlag()) 3000L else 2000L
            bannerQueue.enqueue(result.text, durationMs)
        }
    }

    // Ambiance/idle nudge: fires if a full minute passes with no move. Re-armed via a
    // generation token so an already-scheduled check from before the last move sees a
    // mismatch and silently no-ops instead of firing late. Mirrors Windows'
    // ScheduleIdleActionCheck.
    private var idleCheckGeneration = 0

    // A game switch counts as player activity — see GameViewModel.cancelIdleActionCheck.
    override fun cancelIdleActionCheck() { idleCheckGeneration++ }

    // Entering Honeycomb mid-match restarts the idle minute from the switch.
    override fun scheduleIdleActionCheck() {
        if (_state.value.gameState == HoneycombGameState.Playing) scheduleIdleCheck() else cancelIdleActionCheck()
    }

    private fun scheduleIdleCheck() {
        idleCheckGeneration++
        val generation = idleCheckGeneration
        viewModelScope.launch {
            delay(60000)
            if (idleCheckGeneration != generation) return@launch
            if (_state.value.gameState != HoneycombGameState.Playing) return@launch
            val result = bannerCatalog.fire(BannerId.IdleActionNoActionTakenForOneMinute)
            if (result is BannerFireResult.Message) enqueueBanner(result.text, longDuration = true)
        }
    }

    // Bumped every time the board changes (any placement) and every fresh findHint()
    // search — mirrors iOS's hintGeneration. Guards both the on-demand search and the
    // prewarm cache so a result computed against a now-stale board is never applied.
    private var hintGeneration: Int = 0
    private var precomputedHint: Pair<Int, Int>? = null
    private var precomputedHintGeneration: Int = -1

    private data class HintSearchInputs(
        val board: HoneycombBoard,
        val playerDeck: List<HoneycombCardData>,
        val opponentDeck: List<HoneycombCardData>,
        val unknownOpponentCardCount: Int,
        val eligibleHands: List<Int>,
        val empties: List<Int>,
        val rules: List<HoneycombRule>
    )

    private fun snapshotHintInputs(): HintSearchInputs {
        val st = _state.value
        val eligibleHands = if (st.mandatedPlayerHandIndex != null) listOfNotNull(st.mandatedPlayerHandIndex) else st.playerHand.indices.toList()
        val empties = st.board.cells.indices.filter { st.board.cells[it].card == null }
        val opponentDeckData = st.opponentHand.filter { st.openOpponentCardIds.contains(it.id) }.map { it.data }
        val unknownOpponentCardCount = st.opponentHand.size - opponentDeckData.size
        return HintSearchInputs(
            board = st.board,
            playerDeck = st.playerHand.map { it.data },
            opponentDeck = opponentDeckData,
            unknownOpponentCardCount = unknownOpponentCardCount,
            eligibleHands = eligibleHands,
            empties = empties,
            rules = st.activeRules
        )
    }

    private fun computeHintMove(inputs: HintSearchInputs): Pair<Int, Int>? =
        HoneycombAI.computeHint(
            board = inputs.board,
            playerDeck = inputs.playerDeck,
            opponentDeck = inputs.opponentDeck,
            unknownOpponentCardCount = inputs.unknownOpponentCardCount,
            eligibleHands = inputs.eligibleHands,
            empties = inputs.empties,
            rules = inputs.rules
        )

    // Speculatively computes the hint the instant it becomes the player's turn (called
    // from finishMatchSetup/right after aiPlayTurn flips isPlayerTurn), so findHint()
    // can usually serve an already-ready result instantly instead of paying the up-to-
    // ~2.6s Ultra-Hard-depth search cost live.
    fun prewarmHint() {
        if (!hasHintsAvailable) return
        val inputs = snapshotHintInputs()
        val generation = hintGeneration
        viewModelScope.launch {
            val hint = withContext(Dispatchers.Default) { computeHintMove(inputs) }
            if (hintGeneration != generation) return@launch
            precomputedHint = hint
            precomputedHintGeneration = generation
        }
    }

    // Reuses the AI opponent's own minimax search (HoneycombAI.computeHint mirrors board
    // ownership so the same machinery optimizes for the player instead) at Ultra Hard's
    // 6-ply depth regardless of match difficulty — a hint is meant to be the
    // mathematically best move, not merely as good as whatever difficulty was picked.
    // Bumped every time a hint is actually shown to the player this match — fires the
    // catalog's "3 hints used in one match" flavor banner exactly once it hits 3.
    // Mirrors Swift's hintUsageCountThisMatch.
    private var hintUsageCountThisMatch = 0

    fun findHint() {
        if (!hasHintsAvailable) return

        hintUsageCountThisMatch++
        if (hintUsageCountThisMatch == 3) {
            val result = bannerCatalog.fire(BannerId.Gameplay3HintsUsedInOneMatch)
            if (result is BannerFireResult.Message) enqueueBanner(result.text, longDuration = true)
        }

        if (precomputedHint != null && precomputedHintGeneration == hintGeneration) {
            _hintMove.value = precomputedHint
            scheduleHintClear()
            return
        }

        hintGeneration++
        val generation = hintGeneration
        val inputs = snapshotHintInputs()
        viewModelScope.launch {
            val hint = withContext(Dispatchers.Default) { computeHintMove(inputs) }
            if (hintGeneration != generation) return@launch
            _hintMove.value = hint
            precomputedHint = hint
            precomputedHintGeneration = generation
            if (hint != null) scheduleHintClear()
        }
    }

    private var hintClearJob: kotlinx.coroutines.Job? = null
    private fun scheduleHintClear() {
        hintClearJob?.cancel()
        hintClearJob = viewModelScope.launch {
            delay(2000)
            _hintMove.value = null
        }
    }

    fun clearHint() {
        hintClearJob?.cancel()
        hintGeneration++
        _hintMove.value = null
    }

    fun quitMatch() {
        recordAbandonedMatchIfInProgress()
        resetMatchTransients()
        _state.value = HoneycombState()
    }

    // The one place every match entry/exit point (quit, new game, rematch) goes through
    // to invalidate the previous match's in-flight work — pending AI turns and the Sudden
    // Death sequence (aiMoveGeneration), hint searches (hintGeneration), the Swap
    // highlight clear, queued banners, and the undo stacks. Mirrors the iOS Nectar
    // Exchange fix: resetting piecemeal per entry point is what let stale callbacks leak.
    private fun resetMatchTransients() {
        aiMoveGeneration++
        clearHint()
        swapHighlightJob?.cancel()
        swapHighlightJob = null
        undoHistory.clear()
        undoSessionCardsCaptured.clear()
        clearBanners()
    }

    // Every delayed AI turn goes through here so it's tied to the generation it was
    // scheduled in — quit/new game/rematch/undo/Sudden Death all bump aiMoveGeneration,
    // which turns an abandoned match's pending turn into a no-op instead of letting it
    // fire early into the next match.
    private fun scheduleAiTurn(delayMs: Long) {
        val gen = aiMoveGeneration
        viewModelScope.launch {
            delay(delayMs)
            if (aiMoveGeneration != gen) return@launch
            aiPlayTurn()
        }
    }

    fun playerPlayCard(handIndex: Int, boardIndex: Int): Boolean {
        val st = _state.value
        if (st.gameState != HoneycombGameState.Playing || !st.isPlayerTurn) return false
        if (handIndex !in 0 until st.playerHand.size) return false
        if (st.board.cells[boardIndex].card != null) return false
        if (st.mandatedPlayerHandIndex != null && st.mandatedPlayerHandIndex != handIndex) return false

        snapshotForUndo()
        clearHint()

        val newPlayerHand = st.playerHand.toMutableList()
        val card = newPlayerHand.removeAt(handIndex)

        // Item 3: undo-then-repeat-same-move detection — fires if this placement is the
        // exact move (same card, same cell) that was just undone, then clears the check
        // regardless of whether it matched. Mirrors Swift's pendingUndoRepeatCheck usage
        // in playerPlayCard.
        val pendingRepeat = pendingUndoRepeatCheck
        if (pendingRepeat != null && pendingRepeat.first == card.data.id && pendingRepeat.second == boardIndex) {
            val result = bannerCatalog.fire(BannerId.GameplayPlayerUsesUndoThinksAboutItAndThenMakesTheExact)
            if (result is BannerFireResult.Message) enqueueBanner(result.text)
        }
        pendingUndoRepeatCheck = null
        lastPlayerMove = card.data.id to boardIndex

        val isFirstCard = st.board.cells.all { it.card == null }
        if (st.activeRules.contains(HoneycombRule.BombShelter) && isFirstCard) {
            card.isFaceDown = true
            card.bombShelterTurnsRemaining = 3
        }

        com.leah.honeycomb.audio.UISound.play("snap")
        val newBoard = st.board.copy(cells = st.board.cells.map { it.copy(card = it.card?.copy()) })
        val flips = newBoard.placeCard(card, boardIndex, st.activeRules)
        sessionCardsCaptured += flips.size
        enqueueCaptureBanners(newBoard, st.activeRules, card, boardIndex, flips)
        processBombShelter(newBoard, boardIndex, st.activeRules)

        _state.update {
            it.copy(
                playerHand = newPlayerHand,
                board = newBoard,
                isPlayerTurn = false,
                chaosPlayerIndex = null,
                chaosOpponentIndex = if (it.activeRules.contains(HoneycombRule.Chaos) && it.opponentHand.isNotEmpty()) (0 until it.opponentHand.size).random() else null,
            )
        }
        flashCapture(card.id, boardIndex, flips)

        checkWinCondition()

        if (_state.value.gameState == HoneycombGameState.Playing) {
            scheduleAiTurn(2500)
        }
        return true
    }

    fun aiPlayTurn() {
        val st = _state.value
        if (st.gameState != HoneycombGameState.Playing || st.isPlayerTurn) return

        val gen = ++aiMoveGeneration
        val difficulty = _state.value.matchDifficulty
        val board = st.board
        val opponentDeckData = st.opponentHand.map { it.data }
        val playerDeckData = st.playerHand.filter { st.openPlayerCardIds.contains(it.id) }.map { it.data }
        val unknownPlayerCardCount = st.playerHand.size - playerDeckData.size
        
        val eligibleHands = if (st.mandatedOpponentHandIndex != null) listOfNotNull(st.mandatedOpponentHandIndex) else st.opponentHand.indices.toList()
        val empties = board.cells.indices.filter { board.cells[it].card == null }
        val rules = st.activeRules

        // Item 5: opponent-about-to-win nudge — fires right before the AI's move (not
        // after), so it reads as anticipation of the last card landing rather than a
        // recap of something that already happened. Pre-move score already reflects
        // everything except this one move. Mirrors Swift's aiPlayTurn/Windows'
        // ScheduleOpponentMove.
        val preMovePScore = board.playerScore + st.playerHand.size
        val preMoveOScore = board.opponentScore + st.opponentHand.size
        if (empties.size == 1 && preMoveOScore - preMovePScore == 2) {
            val warningResult = bannerCatalog.fire(
                BannerId.GameplayOpponentIsWinningByTwoCardsAndIsAboutToPlaceThe,
                mapOf("OpponentName" to difficulty.displayName)
            )
            if (warningResult is BannerFireResult.Message) enqueueBanner(warningResult.text)
        }

        viewModelScope.launch {
            // Hard/UltraHard use 5-6 ply minimax with alpha-beta search — run it off the
            // main thread so board-wide UI doesn't freeze while the AI "thinks", matching
            // Swift's DispatchQueue.global(qos: .userInitiated) offload.
            val move = withContext(Dispatchers.Default) {
                HoneycombAI.computeMove(
                    difficulty = difficulty,
                    board = board,
                    opponentDeck = opponentDeckData,
                    playerDeck = playerDeckData,
                    unknownPlayerCardCount = unknownPlayerCardCount,
                    eligibleHands = eligibleHands,
                    empties = empties,
                    rules = rules
                )
            }

            if (aiMoveGeneration != gen) return@launch

            if (move != null) {
                // Apply against the pre-search snapshot (st), not a fresh _state.value read —
                // move.first/move.second were computed against st, so re-deriving from a
                // possibly-mutated _state.value here (if a suspension point is ever added
                // above) could removeAt() the wrong hand index or place into the wrong cell.
                val newOpponentHand = st.opponentHand.toMutableList()
                val cardToPlay = newOpponentHand.removeAt(move.first)

                val isFirstCard = st.board.cells.all { it.card == null }
                if (st.activeRules.contains(HoneycombRule.BombShelter) && isFirstCard) {
                    cardToPlay.isFaceDown = true
                    cardToPlay.bombShelterTurnsRemaining = 3
                }

                com.leah.honeycomb.audio.UISound.play("snap")
                val newBoard = st.board.copy(cells = st.board.cells.map { it.copy(card = it.card?.copy()) })
                val flips = newBoard.placeCard(cardToPlay, move.second, st.activeRules)
                sessionCardsCaptured += flips.size
                enqueueCaptureBanners(newBoard, st.activeRules, cardToPlay, move.second, flips)
                processBombShelter(newBoard, move.second, st.activeRules)

                _state.update {
                    it.copy(
                        opponentHand = newOpponentHand,
                        board = newBoard,
                        isPlayerTurn = true,
                        chaosOpponentIndex = null,
                        chaosPlayerIndex = if (it.activeRules.contains(HoneycombRule.Chaos) && it.playerHand.isNotEmpty()) (0 until it.playerHand.size).random() else null,
                    )
                }
                flashCapture(cardToPlay.id, move.second, flips)
                hintGeneration++
                checkWinCondition()
                if (_state.value.gameState == HoneycombGameState.Playing && _state.value.isPlayerTurn) {
                    prewarmHint()
                }
            }
        }
    }

    // Maps a captured neighbor's board index to which of the attacker's 4 stats faces
    // it — same neighbor layout as HoneycombBoard.resolveCaptures (3x3 grid, row-major).
    // Returns null if the two indices aren't actually adjacent. Ported from
    // shared/Honeycomb/ViewModels/HoneycombViewModel.swift's neighborDirection.
    private fun neighborDirection(attackerIndex: Int, neighborIndex: Int): Int? {
        val row = attackerIndex / 3
        val col = attackerIndex % 3
        if (neighborIndex == attackerIndex - 3 && row > 0) return 0 // Top
        if (neighborIndex == attackerIndex + 1 && col < 2) return 1 // Right
        if (neighborIndex == attackerIndex + 3 && row < 2) return 2 // Bottom
        if (neighborIndex == attackerIndex - 1 && col > 0) return 3 // Left
        return null
    }

    // Pops the attacking card and flashes its winning stat(s) gold, briefly, right after
    // a capture — ported from iOS's flashCaptureAttackers/pointHighlight. Only the
    // directly-placed card's own direct captures are highlighted; secondary combo/chain
    // flips just flip along with everything else, no separate highlight cycle.
    private fun flashCapture(cardId: String, boardIndex: Int, flips: List<Int>) {
        if (flips.isEmpty()) return
        val directStatIndices = flips.mapNotNull { neighborDirection(boardIndex, it) }.toSet()
        _state.update {
            it.copy(
                captureAttackerIds = it.captureAttackerIds + cardId,
                pointHighlightCardId = cardId,
                pointHighlightStatIndices = directStatIndices
            )
        }
        viewModelScope.launch {
            delay(600)
            _state.update {
                it.copy(
                    captureAttackerIds = it.captureAttackerIds - cardId,
                    pointHighlightCardId = if (it.pointHighlightCardId == cardId) null else it.pointHighlightCardId,
                    pointHighlightStatIndices = if (it.pointHighlightCardId == cardId) emptySet() else it.pointHighlightStatIndices
                )
            }
        }
    }

    private fun checkWinCondition() {
        val st = _state.value
        if (st.board.isFull) {
            settleMatch()
        }
    }

    private fun settleMatch() {
        val st = _state.value
        val pScore = st.board.playerScore + st.playerHand.size
        val oScore = st.board.opponentScore + st.opponentHand.size

        if (pScore > oScore) {
            com.leah.honeycomb.audio.UISound.play("victory")
            _state.update {
                it.copy(
                    matchResult = "You Win!",
                    matchOutcome = HoneycombMatchOutcome.Win,
                    gameState = HoneycombGameState.GameOver,
                    showPostGamePrompt = true
                )
            }
            val previousMatchesWon = _statistics.value.matchesWon
            updateStatistics {
                it.recordGame(
                    won = true, drawn = false,
                    captures = sessionCardsCaptured,
                    sessionCombos = st.board.sessionSamePlusTriggers,
                    flawless = oScore == 0,
                    difficulty = _state.value.matchDifficulty,
                    fallenAceCaptures = st.board.sessionFallenAceCaptures
                )
            }
            checkWinMilestones(previousMatchesWon, _statistics.value.matchesWon)
            if (oScore == 0) {
                val result = bannerCatalog.fire(BannerId.RuleSpecificPlayerWinsFlawlessOpponentScore0)
                if (result is BannerFireResult.Message) enqueueBanner(result.text, longDuration = true)
            }
            // A win's margin is pScore - oScore, maximized exactly when oScore is
            // minimized — i.e. this is always the same condition as the flawless check
            // above, just framed as "the biggest margin possible" rather than "opponent
            // got nothing." Both fire in sequence on the same flawless win, matching
            // Swift/Windows (confirmed: neither reference treats these as mutually
            // exclusive).
            if (oScore == 0) {
                val result = bannerCatalog.fire(BannerId.GameplayPlayerWinsByTheMaximumPossibleMargin)
                if (result is BannerFireResult.Message) enqueueBanner(result.text, longDuration = true)
            }
            if (st.activeRules.size >= 4) {
                val result = bannerCatalog.fire(BannerId.GameplayPlayerWinsAMatchWith4RulesActiveAtOnce)
                if (result is BannerFireResult.Message) enqueueBanner(result.text, longDuration = true)
            }
            applyStealProtection()
            consecutiveRematchLosses = 0
            consecutiveRematchWins++
            if (consecutiveRematchWins == 3) {
                val result = bannerCatalog.fire(
                    BannerId.Gameplay3RematchWinsInARowAgainstTheSameOpponent,
                    mapOf("OpponentName" to _state.value.matchDifficulty.displayName)
                )
                if (result is BannerFireResult.Message) enqueueBanner(result.text, longDuration = true)
            }
        } else if (oScore > pScore) {
            _state.update {
                it.copy(
                    matchResult = "You Lose",
                    matchOutcome = HoneycombMatchOutcome.Loss,
                    gameState = HoneycombGameState.GameOver,
                    showPostGamePrompt = true
                )
            }
            updateStatistics {
                it.recordGame(
                    won = false, drawn = false,
                    captures = sessionCardsCaptured,
                    sessionCombos = st.board.sessionSamePlusTriggers,
                    flawless = false,
                    fallenAceCaptures = st.board.sessionFallenAceCaptures
                )
            }
            if (pScore == 0) {
                val result = bannerCatalog.fire(BannerId.RuleSpecificPlayerLosesFlawless0Captures, mapOf("OpponentName" to _state.value.matchDifficulty.displayName))
                if (result is BannerFireResult.Message) enqueueBanner(result.text, longDuration = true)
            }
            consecutiveRematchWins = 0
            consecutiveRematchLosses++
            if (consecutiveRematchLosses == 3) {
                val result = bannerCatalog.fire(
                    BannerId.Gameplay3RematchLossesInARowAgainstTheSameOpponent,
                    mapOf("OpponentName" to _state.value.matchDifficulty.displayName)
                )
                if (result is BannerFireResult.Message) enqueueBanner(result.text, longDuration = true)
            }
        } else if (st.activeRules.contains(HoneycombRule.SuddenDeath)) {
             _state.update {
                it.copy(
                    matchResult = com.leah.honeycomb.Strings.format(com.leah.honeycomb.StringKey.DrawSuddenDeathFmt, bannerCatalog.currentLanguage, HoneycombRule.SuddenDeath.localizedName(bannerCatalog.currentLanguage)),
                    matchOutcome = HoneycombMatchOutcome.SuddenDeathPending,
                    gameState = HoneycombGameState.SuddenDeath,
                )
            }
            // Entering Sudden Death is not itself a decisive result — do not call
            // recordGame here; only the eventual win/loss/draw resolution records stats.
            // suddenDeathCount is incremented in triggerSuddenDeath() instead, once the
            // overtime round actually begins (matches Swift/C# reference timing) — not
            // here, since a quit/new-game during the delay below should not count it.
            scheduleSuddenDeathSequence()
        } else {
            _state.update {
                it.copy(
                    matchResult = "Draw",
                    matchOutcome = HoneycombMatchOutcome.Draw,
                    gameState = HoneycombGameState.GameOver,
                    showPostGamePrompt = true
                )
            }
            updateStatistics {
                it.recordGame(
                    won = false, drawn = true,
                    captures = sessionCardsCaptured,
                    sessionCombos = st.board.sessionSamePlusTriggers,
                    flawless = false,
                    fallenAceCaptures = st.board.sessionFallenAceCaptures
                )
            }
            consecutiveRematchWins = 0
            consecutiveRematchLosses = 0
        }
    }

    // Ported from Swift's triggerSuddenDeath()/C#'s TriggerSuddenDeathAsync() — a tied
    // match with the Sudden Death rule active continues into overtime rather than
    // ending in a draw. This is NOT rematch(): it keeps the same match (same
    // activeRules/ascensionDescensionSuits, no fresh opponent deck) and every card
    // either side currently owns — whether still in hand or captured on the board —
    // becomes that side's new hand for the next round. Can repeat indefinitely if the
    // overtime round ties again.
    private fun scheduleSuddenDeathSequence() {
        val gen = aiMoveGeneration
        viewModelScope.launch {
            delay(2500)
            if (aiMoveGeneration != gen) return@launch
            _state.update { it.copy(showSuddenDeathBanner = true) }
            delay(1500)
            if (aiMoveGeneration != gen) return@launch
            _state.update { it.copy(showSuddenDeathBanner = false) }
            triggerSuddenDeath()
        }
    }

    private fun triggerSuddenDeath() {
        updateStatistics { it.copy(suddenDeathCount = it.suddenDeathCount + 1) }
        undoHistory.clear()
        undoSessionCardsCaptured.clear()

        val st = _state.value
        val playerCards = (st.board.cells.mapNotNull { it.card }.filter { it.owner == CardOwner.Player } + st.playerHand)
            .map { it.copy(modifier = 0) }
        val opponentCards = (st.board.cells.mapNotNull { it.card }.filter { it.owner == CardOwner.Opponent } + st.opponentHand)
            .map { it.copy(modifier = 0) }

        val newBoard = HoneycombBoard().apply { ascensionDescensionSuits = st.ascensionDescensionSuits }
        val nextPlayerTurn = !st.isPlayerTurn

        // Cards change sides here, so the open sets have to be rebuilt against the new
        // hands. A card is known if it was open in either hand before, or if it was on
        // the board — every placed card was played face-up in front of both players.
        val knownIds = st.openOpponentCardIds + st.openPlayerCardIds +
            st.board.cells.mapNotNull { it.card?.id }
        val openOpponentIds = opponentCards.map { it.id }.filter { it in knownIds }.toSet()
        val openPlayerIds = playerCards.map { it.id }.filter { it in knownIds }.toSet()

        // Chaos picks the forced card for whichever side moves first, same as
        // finishMatchSetup (and iOS's rerollChaosIndexIfNeeded(forPlayerSide:)).
        val chaos = st.activeRules.contains(HoneycombRule.Chaos)
        val chaosPlayerIndex = if (chaos && nextPlayerTurn && playerCards.isNotEmpty()) playerCards.indices.random() else null
        val chaosOpponentIndex = if (chaos && !nextPlayerTurn && opponentCards.isNotEmpty()) opponentCards.indices.random() else null

        aiMoveGeneration++
        hintGeneration++
        _state.update {
            it.copy(
                playerHand = playerCards,
                opponentHand = opponentCards,
                openPlayerCardIds = openPlayerIds,
                openOpponentCardIds = openOpponentIds,
                board = newBoard,
                gameState = HoneycombGameState.Playing,
                isPlayerTurn = nextPlayerTurn,
                matchOutcome = HoneycombMatchOutcome.None,
                matchResult = "",
                chaosPlayerIndex = chaosPlayerIndex,
                chaosOpponentIndex = chaosOpponentIndex
            )
        }

        if (!nextPlayerTurn) {
            scheduleAiTurn(2500)
        } else {
            prewarmHint()
        }
    }

    fun isStealEligible(card: HoneycombCard): Boolean {
        if (profileManager.unlockedCardIds.value.contains(card.data.id)) return false
        if (stealProtectionActive) return true
        return card.originalOwner == CardOwner.Opponent && card.owner == CardOwner.Player
    }

    val hasStealableCard: Boolean
        get() = _state.value.board.cells.any { cell -> cell.card?.let { isStealEligible(it) } ?: false }

    val canStealCard: Boolean
        get() = _state.value.matchOutcome == HoneycombMatchOutcome.Win
            && !_state.value.noStressModeThisMatch
            && !hasStolenThisMatch
            && !profileManager.isCardBankFull
            && hasStealableCard

    // Covers a rematch chain whose frozen opponent deck happens to include a card
    // that's realistically never capturable — without this, the player could keep
    // winning against that exact opponent forever with no legitimate shot at
    // unlocking it. Mirrors iOS's applyStealProtection(): only wins count as
    // evidence of being stuck, only within a rematch chain, and once tripped it
    // stays active until startNewGame() resets it.
    private fun applyStealProtection() {
        if (!isRematchMatch) return
        if (stealProtectionActive) return
        if (hasStealableCard) {
            consecutiveNoStealWins = 0
            return
        }
        consecutiveNoStealWins += 1
        if (consecutiveNoStealWins < 2) return
        consecutiveNoStealWins = 0
        stealProtectionActive = true
    }

    fun requestSteal(boardIndex: Int) {
        if (hasStolenThisMatch) return
        if (_state.value.noStressModeThisMatch) return
        val card = _state.value.board.cells[boardIndex].card ?: return
        if (!isStealEligible(card)) return

        _state.update {
            it.copy(pendingSteal = PendingSteal(boardIndex = boardIndex, cardName = card.data.name))
        }
    }

    fun cancelPendingSteal() {
        _state.update { it.copy(pendingSteal = null) }
    }

    fun confirmPendingSteal() {
        val pending = _state.value.pendingSteal ?: return
        _state.update { it.copy(pendingSteal = null) }

        if (_state.value.noStressModeThisMatch) return
        if (_state.value.matchOutcome != HoneycombMatchOutcome.Win) return
        val card = _state.value.board.cells[pending.boardIndex].card ?: return
        if (!isStealEligible(card)) return
        hasStolenThisMatch = true

        profileManager.unlockCard(card.data.id)

        updateStatistics { it.copy(cardsStolen = it.cardsStolen + 1) }
    }

    fun startOver() {
        viewModelScope.launch {
            profileManager.startOver()
            database.reseed()
        }
        updateOptions(_options.value.copy(activeDeckIndex = 0))
        updateStatistics { it.copy(timesStartedOver = it.timesStartedOver + 1) }
    }

    private fun processBombShelter(board: HoneycombBoard, justPlacedIndex: Int, rules: List<HoneycombRule>) {
        val pendingReveals = mutableListOf<Int>()
        for (i in board.cells.indices) {
            if (i == justPlacedIndex) continue
            val card = board.cells[i].card ?: continue
            if (!card.isFaceDown || card.bombShelterTurnsRemaining == null) continue
            
            val newRemaining = card.bombShelterTurnsRemaining!! - 1
            if (newRemaining <= 0) {
                pendingReveals.add(i)
            } else {
                card.bombShelterTurnsRemaining = newRemaining
            }
        }
        
        for (i in pendingReveals) {
            val card = board.cells[i].card ?: continue
            card.bombShelterTurnsRemaining = null
            // Reveal-triggered flips are never counted into sessionCardsCaptured, matching
            // iOS's revealBombShelterCards — only a placement's own direct captures count.
            board.revealFaceDownCard(i, rules)
        }
    }
}