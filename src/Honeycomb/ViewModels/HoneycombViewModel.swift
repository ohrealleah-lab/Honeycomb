import Foundation
import Observation
import SwiftUI

@Observable
public final class HoneycombViewModel {
    public struct Options: Codable, Equatable {
        public var isSoundEnabled: Bool = true
        public var noStressMode: Bool = false
        public var difficulty: HoneycombDifficulty = .medium
        public var activeDeckIndex: Int = 0 // 0-4
        public var selectedRules: Set<HoneycombRule> = []
        // Explicitly locks the match to zero active rules — distinct from merely having
        // an empty `selectedRules`, which means "let roulette decide" instead.
        public var forceNormalMode: Bool = false
    }

    public var options = Options() {
        didSet {
            // Switching decks or leaving No Stress Mode abandons any in-session swap
            // that hasn't been explicitly saved to a deck slot.
            if oldValue.activeDeckIndex != options.activeDeckIndex || oldValue.noStressMode != options.noStressMode {
                sessionHandOverride = nil
            }
            saveOptions()
        }
    }

    public var debugBannerRequest: DebugBannerKind?
    public var zoomScale: CGFloat = 1.0

    public var board = HoneycombBoard()
    public var playerHand: [HoneycombCard] = []
    public var playerStartingDeck: [HoneycombCard] = []
    public var opponentHand: [HoneycombCard] = []
    // Tracks revealed cards by their own stable `id`, not array position — opponentHand
    // shrinks as cards are played, which shifts every later card's index down by one, so
    // an index-based set would silently drift onto the wrong cards mid-match.
    public var openOpponentCardIds: Set<String> = []

    // The session's current active deck once a post-win "Take a Card" swap has
    // happened — takes priority over the persisted saved-deck slot until the
    // player explicitly saves it (persistActiveDeckToSlot) or switches decks/mode.
    private var sessionHandOverride: [HoneycombCardData]? = nil
    public var hasUnsavedActiveDeck: Bool { sessionHandOverride != nil }

    // Pending swap awaiting the player's confirmation (spec: "A confirmation alert
    // is shown before the swap is completed").
    public struct PendingSwap: Equatable {
        public let boardIndex: Int
        public let replaceHandIndex: Int
        public let incomingCardName: String
        public let outgoingCardName: String
    }
    public var pendingSwap: PendingSwap? = nil
    
    public var activeRules: [HoneycombRule] = []
    public var gameState: HoneycombGameState = .setup
    public var isPlayerTurn: Bool = true
    private var playerStartedLastMatch: Bool = false

    // "Chaos": the single playable card each turn is re-rolled at random the instant
    // that side's turn begins (not fixed once at match start) — nil once that hand's
    // empty. "Order" needs no equivalent stored state: it's always index 0 of whatever
    // remains, which falls out naturally since removing earlier cards shifts the rest
    // up, preserving deck order.
    private var chaosPlayerIndex: Int? = nil
    private var chaosOpponentIndex: Int? = nil

    // The one hand index each side is allowed to play this turn under Order/Chaos, or
    // nil if neither rule is active (any card is fair game, the normal case).
    public var mandatedPlayerHandIndex: Int? {
        if activeRules.contains(.order) { return playerHand.isEmpty ? nil : 0 }
        if activeRules.contains(.chaos) { return chaosPlayerIndex }
        return nil
    }
    public var mandatedOpponentHandIndex: Int? {
        if activeRules.contains(.order) { return opponentHand.isEmpty ? nil : 0 }
        if activeRules.contains(.chaos) { return chaosOpponentIndex }
        return nil
    }

    private func rerollChaosIndexIfNeeded(forPlayerSide: Bool) {
        guard activeRules.contains(.chaos) else { return }
        if forPlayerSide {
            chaosPlayerIndex = playerHand.isEmpty ? nil : Int.random(in: 0..<playerHand.count)
        } else {
            chaosOpponentIndex = opponentHand.isEmpty ? nil : Int.random(in: 0..<opponentHand.count)
        }
    }

    // The eligible opponent hand indices for the AI's move — every card, unless
    // Order/Chaos narrows it to exactly one. (The player's own move validity is
    // checked directly against mandatedPlayerHandIndex in playerPlayCard.)
    private func eligibleOpponentHandIndices() -> [Int] {
        if let mandated = mandatedOpponentHandIndex { return [mandated] }
        return Array(0..<opponentHand.count)
    }
    
    // Post-game state
    public var showPostGamePrompt: Bool = false
    public var matchResult: String = "" // "You Win!", "You Lose", "Draw"
    public var flashRuleBanner: String? = nil
    public var sessionCardsCaptured: Int = 0
    
    // Stats
    public var stats = HoneycombStats()
    
    public var legalMoves: [HoneycombLegalMove] {
        var moves: [HoneycombLegalMove] = []
        if gameState == .playing && isPlayerTurn {
            let emptyBoardIndices = (0..<9).filter { board.cells[$0].card == nil }
            for hIdx in 0..<playerHand.count {
                for bIdx in emptyBoardIndices {
                    moves.append(HoneycombLegalMove(action: "playCard", handIndex: hIdx, boardIndex: bIdx, replaceHandIndex: nil))
                }
            }
        } else if gameState == .gameOver && showPostGamePrompt && matchResult == "You Win!" {
            let opponentBoardIndices = (0..<9).filter { board.cells[$0].card?.originalOwner == .opponent }
            for bIdx in opponentBoardIndices {
                for rIdx in 0..<playerStartingDeck.count {
                    moves.append(HoneycombLegalMove(action: "takeCard", handIndex: nil, boardIndex: bIdx, replaceHandIndex: rIdx))
                }
            }
            moves.append(HoneycombLegalMove(action: "startNewGame", handIndex: nil, boardIndex: nil, replaceHandIndex: nil))
        } else if gameState == .gameOver || gameState == .setup {
            moves.append(HoneycombLegalMove(action: "startNewGame", handIndex: nil, boardIndex: nil, replaceHandIndex: nil))
        }
        return moves
    }
    
    public var state: HoneycombState {
        HoneycombState(
            gameState: gameState,
            isPlayerTurn: isPlayerTurn,
            activeRules: activeRules,
            playerHand: playerHand.map { SimplifiedCard(card: $0) },
            opponentHand: opponentHand.map { isOpponentCardVisible(cardId: $0.id) ? SimplifiedCard(card: $0) : SimplifiedCard(name: "Hidden", owner: "opponent", stats: [0, 0, 0, 0]) },
            board: board.cells.map { cell in
                cell.card.map { SimplifiedCard(card: $0) }
            },
            playerScore: board.playerScore + playerHand.count,
            opponentScore: board.opponentScore + opponentHand.count,
            matchResult: matchResult,
            showPostGamePrompt: showPostGamePrompt,
            legalMoves: legalMoves
        )
    }
    
    public init() {
        loadStats()
        loadOptions()
    }

    // Highlighted (thick yellow border) while a Swap trade's on-screen animation is
    // playing out, so the two traded cards are visually called out.
    public var swapHighlightCardIds: Set<String> = []
    // Invalidates a pending deferred Swap-reveal closure the same way aiMoveGeneration
    // guards AI move computations — bumped on every new match/round so a stale timer
    // from a match the player already left can't reach into the new one.
    private var handSetupGeneration: Int = 0

    public func startNewGame() {
        // Invalidates any AI move computation still in flight on a background queue from
        // the match/round this is resetting (e.g. Surrender calling straight into this
        // without going through aiPlayTurn again first).
        aiMoveGeneration += 1
        handSetupGeneration += 1
        let generation = handSetupGeneration
        undoStack.removeAll()
        swapHighlightCardIds.removeAll()

        board = HoneycombBoard()
        setupRules()
        setupPlayerHand()
        let swapResult = setupOpponentHand()

        if let swapResult {
            // playerStartingDeck (Card Bank unlock eligibility) reflects the final
            // post-swap hand right away — Swap conceptually happens "before the match
            // begins" — even though the *visual* trade is staged below.
            var startingDeck = playerHand
            startingDeck[swapResult.playerIndex] = swapResult.finalPlayerCard
            playerStartingDeck = startingDeck

            // Stage 1 (T+0.5s): highlight the two real, not-yet-swapped cards and flash
            // the "Swap!" banner, so the player sees exactly which two are about to
            // trade before anything moves.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.handSetupGeneration == generation else { return }
                self.flashRuleBanner = "Swap!"
                self.swapHighlightCardIds = [swapResult.preSwapPlayerCard.id, swapResult.preSwapOpponentCard.id]

                // Stage 2 (T+1.5s): actually animate the trade. Looked up by id (not
                // the original array index) in case the player already played one of
                // the two cards during the highlight pause — if so, it's skipped
                // rather than resurrected into a slot it no longer occupies.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    guard self.handSetupGeneration == generation else { return }
                    withAnimation(.easeInOut(duration: 0.6)) {
                        if let idx = self.playerHand.firstIndex(where: { $0.id == swapResult.preSwapPlayerCard.id }) {
                            self.playerHand[idx] = swapResult.finalPlayerCard
                        }
                        if let idx = self.opponentHand.firstIndex(where: { $0.id == swapResult.preSwapOpponentCard.id }) {
                            self.opponentHand[idx] = swapResult.finalOpponentCard
                        }
                    }
                    // Same two ids throughout (identity-preserving swap), so the
                    // highlight just keeps tracking them across the move.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        guard self.handSetupGeneration == generation else { return }
                        self.swapHighlightCardIds.removeAll()
                    }
                }
            }
        }

        gameState = .playing
        showPostGamePrompt = false
        sessionCardsCaptured = 0
        board.sessionSamePlusTriggers = 0
        playerStartedLastMatch.toggle()
        isPlayerTurn = playerStartedLastMatch
        rerollChaosIndexIfNeeded(forPlayerSide: isPlayerTurn)

        if options.isSoundEnabled {
            UISound.play(named: "shuffle", enabled: true)
        }

        if !isPlayerTurn {
            if UISound.isHeadlessMode {
                self.aiPlayTurn()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.opponentMoveDelay) {
                    self.aiPlayTurn()
                }
            }
        }
    }

    // A deliberate pause before the opponent's move actually lands — long enough to
    // read the board (and, under Order/Chaos, to see which of their cards is
    // highlighted as the one they're about to play) before it happens.
    private static let opponentMoveDelay: TimeInterval = 2.5

    private func setupRules() {
        if options.forceNormalMode {
            // Explicitly locked to zero rules — a real "Normal" match, as opposed to
            // an empty selectedRules (which means "let roulette decide" below).
            activeRules = []
        } else if options.selectedRules.isEmpty {
            // Roulette mode — can now occasionally roll 0 rules too, for a genuine
            // Normal match, instead of always forcing at least one.
            var pool = HoneycombRule.allCases
            let count = Int.random(in: 0...2)
            activeRules = []
            for _ in 0..<count {
                if let randomRule = pool.randomElement() {
                    activeRules.append(randomRule)
                    pool.removeAll { $0 == randomRule }
                    // Exclusivity
                    if randomRule == .ascension { pool.removeAll { $0 == .descension } }
                    if randomRule == .descension { pool.removeAll { $0 == .ascension } }
                    // Order (always play index 0) and Chaos (a random forced card each
                    // turn) are contradictory ways of constraining the same "which card
                    // must you play" slot.
                    if randomRule == .order { pool.removeAll { $0 == .chaos } }
                    if randomRule == .chaos { pool.removeAll { $0 == .order } }
                    // All Open (whole hand revealed) and Three Open (partial reveal) are
                    // contradictory ways of constraining the same "how much of the
                    // opponent's hand is visible" setting.
                    if randomRule == .allOpen { pool.removeAll { $0 == .threeOpen } }
                    if randomRule == .threeOpen { pool.removeAll { $0 == .allOpen } }
                }
            }
        } else {
            activeRules = Array(options.selectedRules)
        }
    }
    
    private func setupPlayerHand() {
        if options.noStressMode {
            // Checked before sessionHandOverride (and clears any stale one) — No
            // Stress Mode's spec is "the player does not choose a deck in this mode,"
            // so every deal gets a fresh random overpowered deck regardless of
            // whatever was left over from a steal made before this mode was entered.
            // The Steal Card button is itself hidden in this mode, so normally nothing
            // sets a new override while it's on — this is defense in depth.
            sessionHandOverride = nil
            // Overpowered deck: one 5*, one 4*, three 3* — the strongest composition
            // that still respects the same rarity caps a normal deck must (max one 5*;
            // max one 4* once a 5* is present), rather than the two-5* deal used
            // previously, which broke those caps outright.
            let db = HoneycombDatabase.shared
            let fives = db.randomCards(stars: 5, count: 1)
            let fours = db.randomCards(stars: 4, count: 1)
            let threes = db.randomCards(stars: 3, count: 3)
            let deck = fives + fours + threes
            playerHand = deck.map { HoneycombCard(data: $0, owner: .player) }
        } else if let override = sessionHandOverride, override.count == 5 {
            // A post-win swap this session hasn't been saved to a deck slot yet —
            // it stays the active deck until the player saves it or switches decks/mode.
            playerHand = override.map { HoneycombCard(data: $0, owner: .player) }
        } else {
            // Load from profile
            let deckState = HoneycombProfileManager.shared.savedDecks[options.activeDeckIndex]
            if deckState.cardIds.count == 5 {
                let db = HoneycombDatabase.shared
                playerHand = deckState.cardIds.compactMap { id in
                    if let data = db.card(id: id) {
                        return HoneycombCard(data: data, owner: .player)
                    }
                    return nil
                }
            } else {
                // Fallback to random weak deck
                let ones = HoneycombDatabase.shared.randomCards(stars: 1, count: 5)
                playerHand = ones.map { HoneycombCard(data: $0, owner: .player) }
            }
        }
        
        playerStartingDeck = playerHand
    }
    
    // Each difficulty's normal (non-Reverse) star-tier composition: (stars, count) pairs
    // summing to 5 cards. Higher difficulty = higher star tiers = higher stat totals.
    private func normalComposition(for difficulty: HoneycombDifficulty) -> [(stars: Int, count: Int)] {
        switch difficulty {
        case .easy: return [(1, 4), (2, 1)]
        case .medium: return [(2, 4), (3, 1)]
        case .hard: return [(3, 3), (4, 1), (5, 1)]
        case .ultraHard: return [(3, 2), (4, 1), (5, 2)]
        }
    }

    // Under Reverse, low stats win, so a difficulty's Reverse deck should be built from
    // whichever tiers are actually strong under that inverted rule instead of its
    // normal (high-star-heavy) table. Easy/Medium borrow their opposite difficulty's
    // normal table wholesale (see setupOpponentHand); Hard gets an explicit two 1*,
    // three 2* table instead of Medium's borrowed one — Medium's table (four 2*, one
    // 3*) left Hard too close to Medium's own Reverse strength. Ultra Hard goes all the
    // way to five 1* cards — 1* is the tier with the lowest possible stat sum (see
    // TIER_CONFIG in cards_db.json's generation), so an Ultra Hard deck borrowing even
    // Easy's one 2* slot was still measurably weaker under Reverse than an all-1* deck.
    private func reverseComposition(for difficulty: HoneycombDifficulty) -> [(stars: Int, count: Int)] {
        switch difficulty {
        case .easy: return normalComposition(for: .ultraHard)
        case .medium: return normalComposition(for: .hard)
        case .hard: return [(1, 2), (2, 3)]
        case .ultraHard: return [(1, 5)]
        }
    }

    @discardableResult
    private func setupOpponentHand() -> SwapResult? {
        let db = HoneycombDatabase.shared
        // Reverse flips capture direction (low beats high), so low-stat cards are
        // strictly better on both offense and defense (see canCapture in
        // HoneycombBoard). Mirroring each difficulty's star tiers in place (1<->5,
        // 2<->4, 3 stays) wasn't strong enough: Ultra Hard's table has two slots fixed
        // at 3* that never mirror away, so 40% of its "hardest" reverse deck was still
        // mid-weight 3* cards — plenty for a player with any cheap low-stat deck to
        // win trivially and farm the other high-value cards along with it.
        //
        // Instead, under Reverse each difficulty uses its own dedicated Reverse table
        // (reverseComposition) built from whichever tiers are actually strong under the
        // inverted rule, rather than the tiers its difficulty normally implies. This
        // keeps difficulty meaningful under Reverse (Ultra Hard is still the hardest AI
        // to beat) while making the loot it hands out proportionate — you no longer get
        // high-star cards from a match that was actually easy.
        let preferLowStats = activeRules.contains(.reverse)
        let composition = preferLowStats
            ? reverseComposition(for: options.difficulty)
            : normalComposition(for: options.difficulty)

        var deck: [HoneycombCardData] = []
        for (stars, count) in composition {
            deck += db.rulesAwareCards(stars: stars, count: count, preferLowStats: preferLowStats)
        }
        opponentHand = deck.map { HoneycombCard(data: $0, owner: .opponent) }

        // Computed (not yet applied — see startNewGame) before the reveal-set below,
        // so All Open/Three Open see the hand as it will look *after* the trade rather
        // than revealing/hiding a card that's about to be swapped away.
        let swapResult = computeSwapIfNeeded()

        openOpponentCardIds.removeAll()
        var eventualOpponentIds = opponentHand.map { $0.id }
        if let swap = swapResult {
            eventualOpponentIds[swap.opponentIndex] = swap.finalOpponentCard.id
        }
        if activeRules.contains(.allOpen) {
            openOpponentCardIds = Set(eventualOpponentIds)
        } else if activeRules.contains(.threeOpen) {
            openOpponentCardIds = Set(eventualOpponentIds.shuffled().prefix(3))
        }
        // A card that came from the player's own hand via Swap stays face-up in the
        // opponent's hand for the rest of the match — the player already knows exactly
        // what it is, so there's nothing left to hide.
        if let swap = swapResult {
            openOpponentCardIds.insert(swap.finalOpponentCard.id)
        }

        return swapResult
    }

    // A computed-but-not-yet-applied Swap trade. startNewGame stages this in three
    // beats instead of applying it immediately: highlight the two real cards first, a
    // pause so the player registers which two are about to move, then animate them
    // into their swapped homes — rather than the trade having silently already
    // happened by the very first frame, which read as if it hadn't occurred at all.
    struct SwapResult {
        let playerIndex: Int
        let opponentIndex: Int
        let preSwapPlayerCard: HoneycombCard
        let preSwapOpponentCard: HoneycombCard
        let finalPlayerCard: HoneycombCard
        let finalOpponentCard: HoneycombCard
    }

    // "Swap": before the match begins, one random card from each hand trades places —
    // rarity is ignored, so any card in either hand is eligible. Each swapped card
    // plays for whoever it was swapped to (owner = the new holder), but keeps its true
    // owner in originalOwner, so at match end it reverts for win-unlock purposes and
    // remains stealable by its rightful owner if they don't recapture it themselves.
    // Purely computes the trade — playerHand/opponentHand aren't touched here; see
    // startNewGame for when/how it's actually applied.
    private func computeSwapIfNeeded() -> SwapResult? {
        guard activeRules.contains(.swap), !playerHand.isEmpty, !opponentHand.isEmpty else { return nil }
        let pIdx = Int.random(in: 0..<playerHand.count)
        let oIdx = Int.random(in: 0..<opponentHand.count)
        let originalPlayerCard = playerHand[pIdx]
        let originalOpponentCard = opponentHand[oIdx]
        // Identity-preserving: the id that was sitting in one hand moves to the other,
        // so the on-screen swap animation can track it as the same card relocating
        // rather than a new one materializing on each side.
        let finalPlayerCard = HoneycombCard(data: originalOpponentCard.data, owner: .player, originalOwner: .opponent, id: originalOpponentCard.id)
        let finalOpponentCard = HoneycombCard(data: originalPlayerCard.data, owner: .opponent, originalOwner: .player, id: originalPlayerCard.id)
        return SwapResult(
            playerIndex: pIdx, opponentIndex: oIdx,
            preSwapPlayerCard: originalPlayerCard, preSwapOpponentCard: originalOpponentCard,
            finalPlayerCard: finalPlayerCard, finalOpponentCard: finalOpponentCard
        )
    }

    public func isOpponentCardVisible(cardId: String) -> Bool {
        return openOpponentCardIds.contains(cardId)
    }

    // Ascension/Descension are always-on modifiers, but only flash on the player's own
    // placements (not the opponent's) so the banner doesn't fire every single turn.
    // Same/Plus only matter on the turns they actually match a capture, so those flash
    // whenever board.last{Same,Plus}Triggered says something really fired, regardless
    // of who placed the card.
    private func flashRuleBannerIfNeeded(isPlayerAction: Bool, flipsCount: Int) {
        var parts: [String] = []
        // Skip on the game's last move (the one that fills the board) — the win/lose
        // overlay appears immediately after, and an Ascension/Descension banner flashing
        // at the same moment just clutters that transition. Same/Plus/Combo still show,
        // since those describe what the final move itself actually did.
        if isPlayerAction && !board.isFull {
            if activeRules.contains(.ascension) {
                parts.append("Ascension!")
            } else if activeRules.contains(.descension) {
                parts.append("Descension!")
            }
        }
        if board.lastSameTriggered { parts.append("Same!") }
        if board.lastPlusTriggered { parts.append("Plus!") }
        if flipsCount > 1 {
            parts.append("COMBO x\(flipsCount)!")
        }
        if !parts.isEmpty {
            flashRuleBanner = parts.joined(separator: " ")
        }
    }


    public func playerPlayCard(handIndex: Int, boardIndex: Int) {
        guard gameState == .playing, isPlayerTurn else { return }
        guard handIndex >= 0 && handIndex < playerHand.count else { return }
        guard board.cells[boardIndex].card == nil else { return }
        // Order/Chaos restrict which single card is legal to play this turn.
        guard mandatedPlayerHandIndex == nil || mandatedPlayerHandIndex == handIndex else { return }

        saveStateForUndo()

        let card = playerHand.remove(at: handIndex)
        let flips = board.placeCard(card, at: boardIndex, rules: activeRules)
        sessionCardsCaptured += flips.count
        flashRuleBannerIfNeeded(isPlayerAction: true, flipsCount: flips.count)

        if options.isSoundEnabled {
            UISound.play(named: "snap", enabled: true)
        }

        checkWinCondition()

        if gameState == .playing {
            isPlayerTurn = false
            // Reroll now (not lazily inside aiPlayTurn) so the mandated card is already
            // highlighted for the player to see during the delay below, before the AI
            // actually plays it.
            rerollChaosIndexIfNeeded(forPlayerSide: false)
            if UISound.isHeadlessMode {
                self.aiPlayTurn()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.opponentMoveDelay) {
                    self.aiPlayTurn()
                }
            }
        }
    }
    
    // Bumped every time a new AI turn is computed (and on any hard reset, e.g.
    // startNewGame/Surrender) so a stale background computation from a previous turn
    // or match can detect it's no longer current and silently drop itself instead of
    // corrupting the new game's state.
    private var aiMoveGeneration: Int = 0

    // MARK: - Undo
    //
    // Reuses the same UndoStack<State> every other game's ViewModel already uses
    // (GameSessionHelpers.swift) instead of rolling a new history mechanism. Honeycomb
    // has no single consolidated `state` struct to snapshot wholesale like Klondike/
    // Beecell/Spider do, so this snapshots just the fields a player's move can change.
    private struct HoneycombSnapshot {
        let board: HoneycombBoard
        let playerHand: [HoneycombCard]
        let opponentHand: [HoneycombCard]
        let openOpponentCardIds: Set<String>
        let isPlayerTurn: Bool
        let sessionCardsCaptured: Int
        let chaosPlayerIndex: Int?
        let chaosOpponentIndex: Int?
    }
    private var undoStack = UndoStack<HoneycombSnapshot>()

    // Only undoes the player's own most recent move — snapshots are taken right before
    // each of the player's placements, so restoring one lands back at the start of the
    // player's turn (after whatever the AI most recently played), never mid-AI-turn.
    public var canUndo: Bool {
        !undoStack.isEmpty && gameState == .playing && isPlayerTurn
    }

    private func saveStateForUndo() {
        undoStack.push(HoneycombSnapshot(
            board: board,
            playerHand: playerHand,
            opponentHand: opponentHand,
            openOpponentCardIds: openOpponentCardIds,
            isPlayerTurn: isPlayerTurn,
            sessionCardsCaptured: sessionCardsCaptured,
            chaosPlayerIndex: chaosPlayerIndex,
            chaosOpponentIndex: chaosOpponentIndex
        ))
    }

    public func undoLastAction() {
        guard let previous = undoStack.pop() else { return }
        // Invalidates any AI move computation still in flight — shouldn't be possible
        // given canUndo requires isPlayerTurn, but matches the same safety net
        // startNewGame uses in case a stale background result lands after this.
        aiMoveGeneration += 1

        board = previous.board
        playerHand = previous.playerHand
        opponentHand = previous.opponentHand
        openOpponentCardIds = previous.openOpponentCardIds
        isPlayerTurn = previous.isPlayerTurn
        sessionCardsCaptured = previous.sessionCardsCaptured
        chaosPlayerIndex = previous.chaosPlayerIndex
        chaosOpponentIndex = previous.chaosOpponentIndex
        flashRuleBanner = nil
    }

    public func aiPlayTurn() {
        guard gameState == .playing, !isPlayerTurn else { return }

        aiMoveGeneration += 1
        let generation = aiMoveGeneration

        // Snapshot everything the search needs as plain value types so it can run on a
        // background queue without touching `self` at all — Hard/Ultra Hard's minimax
        // search can take up to ~2.6s in the worst case (full hands, empty board), which
        // would otherwise freeze the UI for that long since it was previously computed
        // synchronously inside the delayed main-thread closure.
        let boardSnapshot = board
        let opponentDeckData = opponentHand.map { $0.data }
        let playerDeckData = playerHand.map { $0.data }
        let rules = activeRules
        let difficulty = options.difficulty
        let eligibleHands = eligibleOpponentHandIndices()
        let empties = HoneycombAI.emptyBoardIndices(board: boardSnapshot)

        func computeMove() -> (handIndex: Int, boardIndex: Int)? {
            HoneycombAI.computeMove(
                difficulty: difficulty,
                board: boardSnapshot,
                opponentDeck: opponentDeckData,
                playerDeck: playerDeckData,
                eligibleHands: eligibleHands,
                empties: empties,
                rules: rules
            )
        }

        // Headless mode (automated testing bridge) needs the move applied synchronously
        // and deterministically before the calling command returns — no backgrounding.
        if UISound.isHeadlessMode {
            applyAIMove(computeMove())
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let move = computeMove()
            DispatchQueue.main.async {
                guard let self, self.aiMoveGeneration == generation else { return }
                self.applyAIMove(move)
            }
        }
    }

    private func applyAIMove(_ move: (handIndex: Int, boardIndex: Int)?) {
        guard gameState == .playing, !isPlayerTurn else { return }
        guard let bestMove = move else { return }

        let cardToPlay = opponentHand.remove(at: bestMove.handIndex)
        let flips = board.placeCard(cardToPlay, at: bestMove.boardIndex, rules: activeRules)
        sessionCardsCaptured += flips.count
        flashRuleBannerIfNeeded(isPlayerAction: false, flipsCount: flips.count)

        if options.isSoundEnabled {
            UISound.play(named: "snap", enabled: true)
        }

        checkWinCondition()

        if gameState == .playing {
            isPlayerTurn = true
            // Reroll now so the player's mandated card (under Chaos) is highlighted
            // the instant it becomes their turn, not lazily on their first tap.
            rerollChaosIndexIfNeeded(forPlayerSide: true)
        }
    }

    private func checkWinCondition() {
        if board.isFull {
            let pScore = board.playerScore + playerHand.count
            let oScore = board.opponentScore + opponentHand.count
            
            if pScore > oScore {
                matchResult = "You Win!"
                gameState = .gameOver
                if options.isSoundEnabled { UISound.play(named: "victory", enabled: true) }
                stats.recordGame(won: true, drawn: false, captures: sessionCardsCaptured, sessionCombos: board.sessionSamePlusTriggers, flawless: oScore == 0, isUltraHard: options.difficulty == .ultraHard)

                // Keep what you hold: unlock original player cards
                for cell in board.cells {
                    if let card = cell.card, card.owner == .player, card.originalOwner == .player {
                        HoneycombProfileManager.shared.unlockCard(id: card.data.id)
                    }
                }
            } else if oScore > pScore {
                matchResult = "You Lose"
                gameState = .gameOver
                stats.recordGame(won: false, drawn: false, captures: sessionCardsCaptured, sessionCombos: board.sessionSamePlusTriggers, flawless: false)
            } else {
                matchResult = "Draw - Sudden Death!"
                gameState = .suddenDeath
                flashRuleBanner = "Sudden Death!"
                stats.recordGame(won: false, drawn: true, captures: sessionCardsCaptured, sessionCombos: board.sessionSamePlusTriggers, flawless: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.triggerSuddenDeath()
                }
                return
            }
            saveStats()
            showPostGamePrompt = true
        }
    }
    
    private func triggerSuddenDeath() {
        // A new round's board bears no resemblance to the just-ended one, so nothing in
        // the undo stack applies to it anymore.
        undoStack.removeAll()

        // Collect all cards currently owned by the player, regardless of who played them.
        // Cards coming off the board may still carry an Ascension/Descension modifier
        // from the just-ended round; reset it to 0 since they're going back into a hand
        // (off the board entirely, on a fresh empty board where nothing is boosted yet)
        // — otherwise they'd keep displaying the previous round's inflated/deflated
        // stats instead of their base card values.
        let pCards = (board.cells.compactMap { $0.card }.filter { $0.owner == .player } + playerHand)
            .map { card -> HoneycombCard in var c = card; c.modifier = 0; return c }
        let oCards = (board.cells.compactMap { $0.card }.filter { $0.owner == .opponent } + opponentHand)
            .map { card -> HoneycombCard in var c = card; c.modifier = 0; return c }

        playerHand = pCards
        opponentHand = oCards
        
        board = HoneycombBoard()
        gameState = .playing
        // alternate turns on sudden death
        isPlayerTurn.toggle()
        rerollChaosIndexIfNeeded(forPlayerSide: isPlayerTurn)

        if !isPlayerTurn {
            if UISound.isHeadlessMode {
                self.aiPlayTurn()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.opponentMoveDelay) {
                    self.aiPlayTurn()
                }
            }
        }
    }
    
    // Post Game actions

    // Shown by the view as an alert when a steal is rejected for violating the deck
    // rarity caps — the "Take a Card" flow bypasses HoneycombDecksView's editor (and
    // its validateDeck check) entirely, so without this a player could freely steal
    // their way to a deck with two 5★ cards or three 4★ cards.
    public var swapValidationError: String? = nil

    // Same caps as HoneycombDecksView.validateDeck: at most one 5★ card; at most one
    // 4★ card if a 5★ card is present, else at most two 4★ cards. Returns the message
    // to show the player, or nil if the hypothetical deck is within the caps.
    private func rarityCapViolation(in deckData: [HoneycombCardData]) -> String? {
        func message(count: Int, stars: Int) -> String {
            "You can only have \(count) \(stars)★ card\(count == 1 ? "" : "s") in your active deck."
        }
        let fiveStars = deckData.filter { $0.stars == 5 }.count
        let fourStars = deckData.filter { $0.stars == 4 }.count
        if fiveStars > 1 {
            return message(count: 1, stars: 5)
        } else if fiveStars == 1 && fourStars > 1 {
            return message(count: 1, stars: 4)
        } else if fiveStars == 0 && fourStars > 2 {
            return message(count: 2, stars: 4)
        }
        return nil
    }

    // Stages a "Take a Card" swap so the UI can show a confirmation alert before
    // it's applied (spec: "A confirmation alert is shown before the swap is completed").
    public func requestSwap(boardIndex: Int, replaceHandIndex: Int) {
        // Any card the opponent originally played is stealable, regardless of who
        // currently holds it — a card recaptured back by the player doesn't unlock via
        // the win-bonus either (that requires originalOwner == .player), so without
        // this it'd be permanently stuck outside the player's collection.
        guard let incoming = board.cells[boardIndex].card, incoming.originalOwner == .opponent else { return }
        guard replaceHandIndex >= 0 && replaceHandIndex < playerStartingDeck.count else { return }

        var hypotheticalDeck = playerStartingDeck.map { $0.data }
        hypotheticalDeck[replaceHandIndex] = incoming.data
        if let violation = rarityCapViolation(in: hypotheticalDeck) {
            swapValidationError = violation
            return
        }

        let outgoing = playerStartingDeck[replaceHandIndex]
        pendingSwap = PendingSwap(boardIndex: boardIndex, replaceHandIndex: replaceHandIndex,
                                   incomingCardName: incoming.data.name, outgoingCardName: outgoing.data.name)
    }

    public func cancelPendingSwap() {
        pendingSwap = nil
    }

    // Applies a confirmed swap. This only updates the session's active deck —
    // persisting it into a saved deck slot is a separate, explicit action
    // (persistActiveDeckToSlot), matching spec §7's "you can overwrite a
    // pre-saved deck slot... via a confirmation prompt."
    public func confirmPendingSwap() {
        guard let swap = pendingSwap else { return }
        pendingSwap = nil
        guard let card = board.cells[swap.boardIndex].card, card.originalOwner == .opponent else { return }

        HoneycombProfileManager.shared.unlockCard(id: card.data.id)

        var newDeck = playerStartingDeck.map { $0.data }
        if swap.replaceHandIndex >= 0 && swap.replaceHandIndex < newDeck.count {
            newDeck[swap.replaceHandIndex] = card.data
        }
        sessionHandOverride = newDeck

        startNewGame()
    }

    public func takeCard(boardIndex: Int, replaceHandIndex: Int) {
        requestSwap(boardIndex: boardIndex, replaceHandIndex: replaceHandIndex)
        confirmPendingSwap()
    }

    // Persists the current session's active deck (post-swap) into one of the 5
    // saved slots, overwriting its cards but never its locked name. No-op in No
    // Stress Mode, which has no deck slot of its own.
    public func persistActiveDeckToSlot(index: Int) {
        guard !options.noStressMode else { return }
        guard let override = sessionHandOverride, override.count == 5 else { return }
        guard index >= 0 && index < HoneycombProfileManager.shared.savedDecks.count else { return }
        let name = HoneycombProfileManager.shared.savedDecks[index].name
        HoneycombProfileManager.shared.saveDeck(index: index, name: name, cardIds: override.map { $0.id })
        sessionHandOverride = nil
    }
    
    public func restartCurrentGame() {
        startNewGame()
    }
    
    public func resetStatistics() {
        stats = HoneycombStats()
        saveStats()
    }
    public func stopTimer() {}
    
    private let statsKey = "honeycomb_stats"
    private func loadStats() {
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(HoneycombStats.self, from: data) {
            stats = decoded
        }
    }
    private func saveStats() {
        if let encoded = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(encoded, forKey: statsKey)
        }
    }

    private let optionsKey = "honeycomb_options"
    private func loadOptions() {
        if let data = UserDefaults.standard.data(forKey: optionsKey),
           let decoded = try? JSONDecoder().decode(Options.self, from: data) {
            options = decoded
        }
    }
    private func saveOptions() {
        if let encoded = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(encoded, forKey: optionsKey)
        }
    }
}
