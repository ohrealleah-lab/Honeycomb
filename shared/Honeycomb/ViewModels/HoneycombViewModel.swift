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
        // Flashes the attacker's winning stat right before a capture flips the board.
        public var showPointHighlights: Bool = true
        public var hideHintButton: Bool = false
        public var bannedRules: Set<String> = []

        public init() {}

        // Manual decodeIfPresent-based init (rather than relying on synthesized
        // Codable) so a new field added later — like showPointHighlights just now —
        // can't cause an old save missing that key to fail decoding this whole struct
        // (the caller only ever uses `try?`, so any decode error silently resets every
        // field to its default, not just the missing one).
        private enum CodingKeys: String, CodingKey {
            case isSoundEnabled, noStressMode, difficulty, activeDeckIndex, selectedRules, forceNormalMode, showPointHighlights
            case hideHintButton, bannedRules
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            isSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? true
            noStressMode = try container.decodeIfPresent(Bool.self, forKey: .noStressMode) ?? false
            difficulty = try container.decodeIfPresent(HoneycombDifficulty.self, forKey: .difficulty) ?? .medium
            activeDeckIndex = try container.decodeIfPresent(Int.self, forKey: .activeDeckIndex) ?? 0
            // Reverse is no longer manually selectable (it stays roulette-only, since
            // it's easily exploitable when a player can pick it on purpose) — strip it
            // from any save made back when it was a selectable rule.
            selectedRules = (try container.decodeIfPresent(Set<HoneycombRule>.self, forKey: .selectedRules) ?? []).subtracting([.reverse])
            forceNormalMode = try container.decodeIfPresent(Bool.self, forKey: .forceNormalMode) ?? false
            showPointHighlights = try container.decodeIfPresent(Bool.self, forKey: .showPointHighlights) ?? true
            hideHintButton = try container.decodeIfPresent(Bool.self, forKey: .hideHintButton) ?? false
            bannedRules = try container.decodeIfPresent(Set<String>.self, forKey: .bannedRules) ?? []
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(isSoundEnabled, forKey: .isSoundEnabled)
            try container.encode(noStressMode, forKey: .noStressMode)
            try container.encode(difficulty, forKey: .difficulty)
            try container.encode(activeDeckIndex, forKey: .activeDeckIndex)
            try container.encode(selectedRules, forKey: .selectedRules)
            try container.encode(forceNormalMode, forKey: .forceNormalMode)
            try container.encode(showPointHighlights, forKey: .showPointHighlights)
            try container.encode(hideHintButton, forKey: .hideHintButton)
            try container.encode(bannedRules, forKey: .bannedRules)
        }

        public static func == (lhs: Options, rhs: Options) -> Bool {
            lhs.isSoundEnabled == rhs.isSoundEnabled
                && lhs.noStressMode == rhs.noStressMode
                && lhs.difficulty == rhs.difficulty
                && lhs.activeDeckIndex == rhs.activeDeckIndex
                && lhs.selectedRules == rhs.selectedRules
                && lhs.forceNormalMode == rhs.forceNormalMode
                && lhs.showPointHighlights == rhs.showPointHighlights
                && lhs.hideHintButton == rhs.hideHintButton
                && lhs.bannedRules == rhs.bannedRules
        }
    }

    public var options = Options() {
        didSet {
            saveOptions()
        }
    }

    public var debugBannerRequest: DebugBannerKind? = nil {
        didSet {
            if let kind = debugBannerRequest {
                debugSetupBannerState(kind)
                debugBannerRequest = nil
            }
        }
    }

    public func debugSetupBannerState(_ kind: DebugBannerKind) {
        switch kind {
        case .win:
            gameState = .gameOver
            playerHand.removeAll()
            opponentHand.removeAll()
            // To simulate a win, just fill the board with player's color
            for i in 0..<board.cells.count {
                if board.cells[i].card != nil {
                    board.cells[i].card?.owner = .player
                }
            }
            showPostGamePrompt = true
        case .loss, .stuck:
            gameState = .gameOver
            playerHand.removeAll()
            opponentHand.removeAll()
            // To simulate a loss, fill with opponent color
            for i in 0..<board.cells.count {
                if board.cells[i].card != nil {
                    board.cells[i].card?.owner = .opponent
                }
            }
            showPostGamePrompt = true
        case .autocomplete:
            break
        case .same:
            flashRuleBanner = "SAME!"
        case .plus:
            flashRuleBanner = "PLUS!"
        case .suddenDeath:
            flashRuleBanner = "SUDDEN DEATH!"
        }
    }
    public var zoomScale: CGFloat = 1.0

    public var board = HoneycombBoard()
    public var playerHand: [HoneycombCard] = []
    public var playerStartingDeck: [HoneycombCard] = []
    public var opponentHand: [HoneycombCard] = []
    // Tracks revealed cards by their own stable `id`, not array position — opponentHand
    // shrinks as cards are played, which shifts every later card's index down by one, so
    // an index-based set would silently drift onto the wrong cards mid-match.
    public var openOpponentCardIds: Set<String> = []
    // Mirrors openOpponentCardIds for the player's hand — All Open/Three Open reveal
    // both hands to both sides (matching real Triple Triad), not just the opponent's
    // hand to the human. The human always sees their own cards regardless (there's no
    // UI-hiding concern here); this set's only consumer is aiPlayTurn(), which uses it
    // to decide what the AI is allowed to actually know about the player's hand rather
    // than reading playerHand directly.
    public var openPlayerCardIds: Set<String> = []

    // Pending steal awaiting the player's confirmation ("Are you sure you want to
    // steal this card?"). Stealing unlocks the card straight into the card bank — it
    // no longer touches the active deck/hand at all.
    public struct PendingSteal: Equatable {
        public let boardIndex: Int
        public let cardName: String
    }
    public var pendingSteal: PendingSteal? = nil
    
    public var activeRules: [HoneycombRule] = []
    // The 2 suits Ascension/Descension affects this match, rolled once in setupRules()
    // and mirrored onto `board.ascensionDescensionSuits` every time the board resets
    // (startNewGame, Sudden Death) so it's never re-rolled mid-match. Empty when
    // neither rule is active. Also drives the "Ascension: Hearts, Spades" rules-banner
    // text in HoneycombView.
    public private(set) var ascensionDescensionSuits: Set<String> = []
    public var gameState: HoneycombGameState = .setup
    public var isPlayerTurn: Bool = true
    // Coin toss for who starts each match, with "bad luck protection": once the same
    // side has started 3 matches in a row, the 4th is forced to the other side (e.g.
    // 3 player starts in a row guarantees the opponent starts match #4), so an unlucky
    // streak can't run indefinitely the way a plain coin toss could.
    private var starterStreak: Int = 0
    private var lastMatchStarterWasPlayer: Bool? = nil

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
    public var flashRuleBanner: String? = nil {
        didSet {
            if flashRuleBanner != nil {
                flashRuleBannerTrigger += 1
            }
        }
    }
    public var flashRuleBannerTrigger: Int = 0
    public var sessionCardsCaptured: Int = 0

    // Which of the attacker's N/E/S/W stats (0=Top,1=Right,2=Bottom,3=Left) are
    // currently flashing because they just won a capture — transient, not part of
    // HoneycombSnapshot (undo doesn't need to rewind a mid-animation highlight).
    public var pointHighlight: (cardId: String, statIndices: Set<Int>)? = nil

    // Maps a captured neighbor's board index to which of the attacker's 4 stats faces
    // it — same neighbor layout as HoneycombBoard.resolveCaptures (3x3 grid, row-major).
    // Returns nil if the two indices aren't actually adjacent.
    private func neighborDirection(from attackerIndex: Int, to neighborIndex: Int) -> Int? {
        let row = attackerIndex / 3
        let col = attackerIndex % 3
        if neighborIndex == attackerIndex - 3 && row > 0 { return 0 } // Top
        if neighborIndex == attackerIndex + 1 && col < 2 { return 1 } // Right
        if neighborIndex == attackerIndex + 3 && row < 2 { return 2 } // Bottom
        if neighborIndex == attackerIndex - 1 && col > 0 { return 3 } // Left
        return nil
    }

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
            // Matches requestSteal's real eligibility: captured this round (owner ==
            // .player, not just originalOwner == .opponent), not already owned, and
            // the one-steal-per-match cap not already spent.
            let opponentBoardIndices = hasStolenThisMatch ? [] : (0..<9).filter {
                guard let card = board.cells[$0].card, card.originalOwner == .opponent, card.owner == .player else { return false }
                return !HoneycombProfileManager.shared.unlockedCardIds.contains(card.data.id)
            }
            for bIdx in opponentBoardIndices {
                moves.append(HoneycombLegalMove(action: "takeCard", handIndex: nil, boardIndex: bIdx, replaceHandIndex: nil))
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

    // Snapshot of the opponent's card pool (pre-Swap) and rules from the most recent
    // genuinely-new match — captured only by startNewGame(), never by rematch() itself,
    // so any number of chained Rematches keep drawing from the same underlying 5 cards
    // instead of drifting to whatever the last rematch happened to roll. Freezing the
    // pool *before* Swap resolves (rather than the already-swapped hand) lets each
    // rematch roll its own independent Swap trade against the same cards — a different
    // pairing each time, same underlying deck (mirrors Triple Triad's rematch loop).
    private var rematchOpponentDeck: [HoneycombCardData] = []
    private var rematchActiveRules: [HoneycombRule] = []
    private var rematchAscensionDescensionSuits: Set<String> = []

    // Set when this match opened with a Swap trade (by startNewGame() or rematch(),
    // since rematch() now re-rolls its own trade), so finishMatchSetup() can fold
    // "Swap!" into the "First Move" banner as a second line instead of flashing it
    // separately a beat later.
    private var pendingSwapBannerLine: String? = nil

    public var canRematch: Bool { !rematchOpponentDeck.isEmpty }

    public func startNewGame() {
        // Invalidates any AI move computation still in flight on a background queue from
        // the match/round this is resetting (e.g. Surrender calling straight into this
        // without going through aiPlayTurn again first).
        aiMoveGeneration += 1
        handSetupGeneration += 1
        let generation = handSetupGeneration
        undoStack.removeAll()
        swapHighlightCardIds.removeAll()
        pendingSwapBannerLine = nil
        clearHint()

        board = HoneycombBoard()
        setupRules()
        board.ascensionDescensionSuits = ascensionDescensionSuits
        setupPlayerHand()

        let deck = rollOpponentDeck()
        // Freeze the opponent's card pool (pre-Swap) + this match's rules — this
        // becomes the baseline every future rematch() call replays, until the next
        // real startNewGame() rolls a fresh one.
        rematchOpponentDeck = deck
        rematchActiveRules = activeRules
        rematchAscensionDescensionSuits = ascensionDescensionSuits

        let swapResult = applyOpponentDeck(deck)
        stageSwapAnimation(swapResult, generation: generation)
        finishMatchSetup()
    }

    // Shared tail between startNewGame() and rematch(): stages a computed-but-not-yet-
    // applied Swap trade in three beats — highlight the two real cards, a pause so the
    // player registers which two are about to move, then animate them into their
    // swapped homes — rather than the trade having silently already happened by the
    // very first frame, which read as if it hadn't occurred at all.
    private func stageSwapAnimation(_ swapResult: SwapResult?, generation: Int) {
        guard let swapResult else { return }

        // Folded into the "First Move" banner in finishMatchSetup() as a second
        // line instead of flashing separately — see pendingSwapBannerLine.
        pendingSwapBannerLine = "Swap!"

        // playerStartingDeck deliberately keeps the player's real, pre-swap card
        // here — it's what "Your Deck"/Take-a-Card and the rarity-cap check at
        // match end are based on, so every one of the 5 slots stays normally
        // replaceable and reflects the deck the player actually owns. If it showed
        // the swapped-in opponent card instead, that card would occupy a
        // permanent-looking deck slot despite never being unlocked, and — worse —
        // its stats would corrupt the rarity-cap math (e.g. rejecting a stolen 5★
        // as "too many 5★" because the player's own 5★ no longer looked present).
        // If the player wants to keep the swapped-in card, they still can — by
        // capturing/stealing it off the board like any other opponent card.

        // Highlight the two real, not-yet-swapped cards right away, in sync with
        // the combined "First Move" + "Swap!" banner (no separate delayed flash —
        // see pendingSwapBannerLine), so the player sees exactly which two are
        // about to trade before anything moves.
        swapHighlightCardIds = [swapResult.preSwapPlayerCard.id, swapResult.preSwapOpponentCard.id]

        // Actually animate the trade partway through the banner's now-2s run.
        // Looked up by id (not the original array index) in case the player
        // already played one of the two cards during the highlight pause — if so,
        // it's skipped rather than resurrected into a slot it no longer occupies.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.handSetupGeneration == generation else { return }
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

    // Shared tail between startNewGame() and rematch() — decides who moves first,
    // flashes the opening banner, and (if the opponent starts) kicks off their move.
    // Everything before this point differs between the two (rule/hand setup); once
    // board/activeRules/playerHand/opponentHand are all in place, the rest is identical.
    private func finishMatchSetup() {
        gameState = .playing
        showPostGamePrompt = false
        sessionCardsCaptured = 0
        board.sessionSamePlusTriggers = 0
        board.sessionFallenAceCaptures = 0
        hasStolenThisMatch = false
        let playerStarts: Bool
        if starterStreak >= 3, let lastMatchStarterWasPlayer {
            playerStarts = !lastMatchStarterWasPlayer
        } else {
            playerStarts = Bool.random()
        }
        if let lastMatchStarterWasPlayer, lastMatchStarterWasPlayer == playerStarts {
            starterStreak += 1
        } else {
            starterStreak = 1
        }
        lastMatchStarterWasPlayer = playerStarts
        isPlayerTurn = playerStarts
        rerollChaosIndexIfNeeded(forPlayerSide: isPlayerTurn)
        // Second line reuses the same Text/font as the headline above (FlashBannerView
        // just renders whatever's after the "\n") — used to fold in "Swap!" instead of
        // flashing it as its own separate banner a beat later.
        let firstMoveLine = isPlayerTurn ? "First Move: Player!" : "First Move: Opponent!"
        if let swapLine = pendingSwapBannerLine {
            flashRuleBanner = "\(firstMoveLine)\n\(swapLine)"
            pendingSwapBannerLine = nil
        } else {
            flashRuleBanner = firstMoveLine
        }

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

    // Replays the last genuinely-new match's opponent card pool and rules — the board
    // resets and the player's hand is rebuilt from their current active deck (so a card
    // just stolen via Take a Card carries forward), and the match's rules stay frozen.
    // If Swap is active, a fresh trade is rolled against this same pool each time (a
    // different pairing, same underlying 5 cards — mirrors Triple Triad's rematch
    // loop), and All Open/Three Open reveal picks re-roll too. Repeated Rematches keep
    // drawing from the same opponent pool until startNewGame() rolls a fresh one, which
    // is what lets a player steal their way through an opponent's whole card pool.
    public func rematch() {
        guard canRematch else {
            startNewGame()
            return
        }
        aiMoveGeneration += 1
        handSetupGeneration += 1
        let generation = handSetupGeneration
        undoStack.removeAll()
        swapHighlightCardIds.removeAll()
        pendingSwapBannerLine = nil
        clearHint()

        board = HoneycombBoard()
        activeRules = rematchActiveRules
        ascensionDescensionSuits = rematchAscensionDescensionSuits
        board.ascensionDescensionSuits = ascensionDescensionSuits
        setupPlayerHand()

        let swapResult = applyOpponentDeck(rematchOpponentDeck)
        stageSwapAnimation(swapResult, generation: generation)
        finishMatchSetup()
    }

    // A deliberate pause before the opponent's move actually lands — long enough to
    // read the board (and, under Order/Chaos, to see which of their cards is
    // highlighted as the one they're about to play) before it happens.
    private static let opponentMoveDelay: TimeInterval = 2.5
    // How long a capture's winning stat(s) flash before the flip actually happens.
    private static let pointHighlightDelay: TimeInterval = 0.5

    private func setupRules() {
        if options.forceNormalMode {
            // Explicitly locked to zero rules — a real "Normal" match, as opposed to
            // an empty selectedRules (which means "let roulette decide" below).
            activeRules = []
        } else if options.selectedRules.isEmpty {
            // Roulette mode — can now occasionally roll 0 rules too, for a genuine
            // Normal match, instead of always forcing at least one.
            var pool = HoneycombRule.allCases
            // Remove banned rules from pool
            pool.removeAll { options.bannedRules.contains($0.rawValue) }
            
            if options.difficulty == .easy {
                // Ascension/Descension and Fallen Ace punish misreads of the board in
                // ways that are especially brutal for a new player — keep Easy's
                // roulette pool to rules that don't compound an opponent-favoring swing.
                pool.removeAll { $0 == .ascension || $0 == .descension || $0 == .fallenAce }
            }
            
            // If Normal Mode is banned, force at least 1 rule
            let normalBanned = options.bannedRules.contains("Normal Mode")

            // "Stop here" is a flat probability at EVERY draw, fully decoupled from
            // how much exclusivity has shrunk the pool (an earlier scaled-stopWeight
            // attempt inflated "stop" after big exclusivity removals and made
            // solo-rule odds WORSE, not better — see git history). Draw 1 uses
            // 1/(originalPoolSize+1) so Normal stays roughly as rare as any single
            // rule (~7.7% for the default 12-rule pool). Draw 2 uses a distinct,
            // deliberately solved probability so that "exactly one rule" lands at a
            // full 1/3 overall, rather than being capped near Normal's rate: with a
            // single shared stop-probability p, P(exactly 1 rule) = (1-p)*p can never
            // exceed p, so Normal necessarily out-paced single-rule matches. Solving
            // (1 - stopProbabilityFirst) * stopProbabilitySecond = 1/3 removes that
            // ceiling while leaving Normal's rate untouched.
            let originalPoolSize = pool.count
            let stopProbabilityFirst = 1.0 / Double(originalPoolSize + 1)
            let targetSingleRuleRate = 1.0 / 3.0
            let stopProbabilitySecond = targetSingleRuleRate / (1.0 - stopProbabilityFirst)
            activeRules = []
            for slot in 0..<2 {
                guard !pool.isEmpty else { break }
                let mustPick = slot == 0 && normalBanned
                let stopProbability = slot == 0 ? stopProbabilityFirst : stopProbabilitySecond
                if !mustPick && Double.random(in: 0..<1) < stopProbability { break }

                let randomRule = pool.randomElement()!
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
                // Bomb Shelter's hidden card doesn't work when All Open/Three Open
                // reveals every card anyway.
                if randomRule == .allOpen || randomRule == .threeOpen { pool.removeAll { $0 == .bombShelter } }
                if randomRule == .bombShelter { pool.removeAll { $0 == .allOpen || $0 == .threeOpen } }
            }
        } else {
            activeRules = Array(options.selectedRules)
        }

        if activeRules.contains(.ascension) || activeRules.contains(.descension) {
            ascensionDescensionSuits = Set(["S", "H", "D", "C"].shuffled().prefix(1))
        } else {
            ascensionDescensionSuits = []
        }
    }
    
    private func setupPlayerHand() {
        if options.noStressMode {
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
        case .medium:
            // Honey Bee: a 20% chance of a 4★ card instead of the usual 3★, so its
            // deck isn't entirely predictable at this difficulty.
            let lastSlot = Double.random(in: 0..<1) < 0.2 ? 4 : 3
            return [(2, 4), (lastSlot, 1)]
        case .hard: return [(3, 3), (4, 1), (5, 1)]
        case .ultraHard: return [(3, 2), (4, 1), (5, 2)]
        }
    }

    // Under Reverse, low stats win, so a difficulty's Reverse deck should be built from
    // whichever tiers are actually strong under that inverted rule instead of its
    // normal (high-star-heavy) table. Easy borrows Hard's normal table wholesale (see
    // setupOpponentHand); Medium reuses its own normal table, since under Reverse its
    // four 2*, one 3* composition is already low-stat-heavy enough to hold up as its
    // own Reverse deck. Hard gets an explicit two 1*, three 2* table instead of
    // borrowing Medium's — Medium's table left Hard too close to Medium's own Reverse
    // strength. Ultra Hard goes all the way to five 1* cards — 1* is the tier with the
    // lowest possible stat sum (see TIER_CONFIG in cards_db.json's generation), so an
    // Ultra Hard deck borrowing even Easy's one 2* slot was still measurably weaker
    // under Reverse than an all-1* deck.
    private func reverseComposition(for difficulty: HoneycombDifficulty) -> [(stars: Int, count: Int)] {
        switch difficulty {
        case .easy: return normalComposition(for: .hard)
        case .medium: return normalComposition(for: .medium)
        case .hard: return [(1, 2), (2, 3)]
        case .ultraHard: return [(1, 5)]
        }
    }

    // Rolls a brand-new opponent card pool for a genuinely-new match. Only called from
    // startNewGame() — rematch() reuses the frozen pool from rematchOpponentDeck
    // instead, via applyOpponentDeck(_:), so repeated rematches keep facing the same
    // underlying 5 cards.
    private func rollOpponentDeck() -> [HoneycombCardData] {
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

        // Favor New Cards (always on, not a toggle): if every card in the assembled
        // deck is already owned by the player, swap the first owned card for an
        // unowned card from the same star tier (if one exists). This guarantees at
        // least one stealable card per match without touching deck quality, AI
        // strength, or the rarity composition — one slot is swapped at most, and only
        // when all 5 slots would otherwise be owned already.
        if !options.noStressMode {
            let owned = HoneycombProfileManager.shared.unlockedCardIds
            let allOwned = deck.allSatisfy { owned.contains($0.id) }
            if allOwned {
                for i in deck.indices {
                    let tier = deck[i].stars
                    let unownedInTier = db.allCards.filter { $0.stars == tier && !owned.contains($0.id) }
                    if let substitute = unownedInTier.randomElement() {
                        deck[i] = substitute
                        break
                    }
                }
            }
        }
        return deck
    }

    // Wires up a given opponent card pool as this match's opponentHand: rolls a fresh
    // Swap trade (if active) and fresh All Open/Three Open reveal picks against it.
    // Shared by startNewGame() (a newly-rolled pool) and rematch() (the frozen pool
    // from the last genuinely-new match) — either way, this is what makes each call a
    // fresh roll of who trades with whom and what gets revealed.
    @discardableResult
    private func applyOpponentDeck(_ deck: [HoneycombCardData]) -> SwapResult? {
        opponentHand = deck.map { HoneycombCard(data: $0, owner: .opponent) }

        // Computed (not yet applied — see stageSwapAnimation) before the reveal-set
        // below, so All Open/Three Open see the hand as it will look *after* the trade
        // rather than revealing/hiding a card that's about to be swapped away.
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

        // Symmetric reveal: All Open/Three Open uncover both hands, not just the
        // opponent's — matching real Triple Triad and giving HoneycombAI.aiPlayTurn a
        // real, non-cheating notion of what it's actually allowed to see of the
        // player's hand.
        openPlayerCardIds.removeAll()
        var eventualPlayerIds = playerHand.map { $0.id }
        if let swap = swapResult {
            eventualPlayerIds[swap.playerIndex] = swap.finalPlayerCard.id
        }
        if activeRules.contains(.allOpen) {
            openPlayerCardIds = Set(eventualPlayerIds)
        } else if activeRules.contains(.threeOpen) {
            openPlayerCardIds = Set(eventualPlayerIds.shuffled().prefix(3))
        }
        // A card that came from the opponent's hand via Swap stays visible to the
        // opponent for the rest of the match — the AI already knows exactly what it is,
        // it was its own card a moment ago.
        if let swap = swapResult {
            openPlayerCardIds.insert(swap.finalPlayerCard.id)
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

    public func isPlayerCardVisibleToOpponent(cardId: String) -> Bool {
        return openPlayerCardIds.contains(cardId)
    }

    // MARK: - Hint

    public struct HintMove: Equatable {
        public let handIndex: Int
        public let boardIndex: Int
    }

    public var activeHint: HintMove? = nil
    private var hintClearTask: DispatchWorkItem?
    // Bumped on every findHint() call and every player/opponent placement — guards the
    // background minimax search below (up to ~2.6s at Ultra Hard's 6-ply depth, same
    // cost as aiPlayTurn's own worst case) from landing after the board it was computed
    // against no longer matches reality, e.g. the player played a card by hand while a
    // hint was still computing.
    private var hintGeneration: Int = 0

    // Cheap synchronous check for whether a hint is even possible right now — doesn't
    // run the actual search, just whether there's a legal card+cell to suggest.
    public var hasHintsAvailable: Bool {
        gameState == .playing && isPlayerTurn && !playerHand.isEmpty
            && !HoneycombAI.emptyBoardIndices(board: board).isEmpty
    }

    // Highlights the suggested card in hand and the board cell to place it on, matching
    // Beecell/Spider's hint pattern: one suggestion per press, auto-clearing after 2s.
    // Always searches at Ultra Hard's caliber (see HoneycombAI.computeHint) regardless
    // of the match's own difficulty, and only ever sees opponent cards actually revealed
    // to the player, matching the AI's own fairness guard against reading hidden hands.
    public func findHint() {
        hintClearTask?.cancel()
        activeHint = nil
        guard hasHintsAvailable else { return }

        hintGeneration += 1
        let generation = hintGeneration

        let boardSnapshot = board
        let empties = HoneycombAI.emptyBoardIndices(board: boardSnapshot)
        let eligibleHands: [Int]
        if let mandated = mandatedPlayerHandIndex {
            eligibleHands = [mandated]
        } else {
            eligibleHands = Array(0..<playerHand.count)
        }
        let playerDeckData = playerHand.map { $0.data }
        let visibleOpponentCards = opponentHand.filter { isOpponentCardVisible(cardId: $0.id) }
        let opponentDeckData = visibleOpponentCards.map { $0.data }
        let unknownOpponentCardCount = opponentHand.count - visibleOpponentCards.count
        let rules = activeRules

        func compute() -> HintMove? {
            if let move = HoneycombAI.computeHint(
                board: boardSnapshot,
                playerDeck: playerDeckData,
                opponentDeck: opponentDeckData,
                unknownOpponentCardCount: unknownOpponentCardCount,
                eligibleHands: eligibleHands,
                empties: empties,
                rules: rules
            ) {
                return HintMove(handIndex: move.handIndex, boardIndex: move.boardIndex)
            }
            // The minimax search should never actually come back empty here — hasHintsAvailable
            // already guarantees eligibleHands/empties are both non-empty, which is all
            // computeHint needs to produce a candidate. But if it ever does (an
            // unanticipated edge case), still surface *some* legal placement rather than
            // silently showing nothing — a non-optimal suggestion beats none at all.
            guard let fallbackHand = eligibleHands.first, let fallbackCell = empties.first else { return nil }
            return HintMove(handIndex: fallbackHand, boardIndex: fallbackCell)
        }

        if UISound.isHeadlessMode {
            activeHint = compute()
            if activeHint != nil { scheduleHintClear() }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let hint = compute()
            DispatchQueue.main.async {
                guard let self, self.hintGeneration == generation else { return }
                self.activeHint = hint
                if hint != nil { self.scheduleHintClear() }
            }
        }
    }

    private func scheduleHintClear() {
        let task = DispatchWorkItem { [weak self] in
            self?.activeHint = nil
        }
        hintClearTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
    }

    public func clearHint() {
        hintGeneration += 1
        hintClearTask?.cancel()
        activeHint = nil
    }

    // Comma-joined summary of this match's active rules — "Normal" if none — used as
    // the "First Move" banner's second line. Mirrors HoneycombView's rulesBannerLines
    // formatting for Ascension/Descension (calling out the 2 affected suits) so the two
    // banners never disagree about what the match's rules actually are.
    private func activeRulesSummaryText() -> String {
        if activeRules.isEmpty { return "Normal" }
        return activeRules.map { rule -> String in
            if (rule == .ascension || rule == .descension), !ascensionDescensionSuits.isEmpty {
                let suitNames = ascensionDescensionSuits.sorted().map { HoneycombCardData.suitDisplayName($0) }
                return "\(rule.rawValue) Suit: \(suitNames.joined(separator: ", "))"
            }
            return rule.rawValue
        }.joined(separator: ", ")
    }

    // Ascension/Descension now only affects 2 chosen suits (not every card), so this
    // flashes for either side's placement as long as the placed card's own suit is
    // actually one of them — unlike the old blanket-effect version, this can no longer
    // fire "every single turn," so there's no more reason to suppress it on the
    // opponent's moves. Same/Plus/Fallen Ace only matter on the turns they actually
    // match/win a capture, so those flash whenever board.last{Same,Plus,FallenAce}
    // Triggered says something really fired, regardless of who placed the card.
    private func flashRuleBannerIfNeeded(placedSuit: String) {
        var parts: [String] = []
        // Skip on the game's last move (the one that fills the board) — the win/lose
        // overlay appears immediately after, and an Ascension/Descension banner flashing
        // at the same moment just clutters that transition. Same/Plus/Combo still show,
        // since those describe what the final move itself actually did.
        if !board.isFull && board.ascensionDescensionSuits.contains(placedSuit) {
            if activeRules.contains(.ascension) {
                parts.append("Ascension!")
            } else if activeRules.contains(.descension) {
                parts.append("Descension!")
            }
        }
        if board.lastSameTriggered { parts.append("Same!") }
        if board.lastPlusTriggered { parts.append("Plus!") }
        if board.lastFallenAceTriggered { parts.append("Fallen Ace!") }
        // Combo = a Same/Plus-triggered flip going on to capture its own neighbors —
        // not just any move that happens to flip 2+ ordinary neighbors at once.
        if board.lastComboFlipCount > 0 {
            parts.append("COMBO x\(board.lastComboFlipCount)!")
        }
        if !parts.isEmpty {
            flashRuleBanner = parts.joined(separator: " ")
        }
    }


    // Set for the entire span of a placement that's showing a point highlight — i.e.
    // between the delay starting and `finishPlacement` running. Distinct from
    // `isPlayerTurn`/`gameState`, which (deliberately) don't change until after the
    // delay resolves, to avoid disturbing Sudden Death's turn-alternation toggle
    // (`triggerSuddenDeath` flips `isPlayerTurn` based on its value at that time, which
    // must still reflect "did the player just move," not get overwritten early). This
    // flag exists purely to keep `canUndo` and re-entrant taps blocked during the delay.
    public private(set) var isAnimatingPlacement: Bool = false

    // Returns whether the card was actually placed — callers (HoneycombView's tap/drop
    // handlers) use this to decide whether to clear their selected-card state. Every
    // guard below is a legitimate reason the move might not happen (most narrowly,
    // isAnimatingPlacement being briefly true right as the player's turn starts, while
    // the previous move's point-highlight flash is still finishing) — if the view
    // cleared the selection unconditionally regardless of this return value, a tap that
    // landed in that window would silently do nothing while still deselecting the card,
    // making it look like the tap "didn't work" until the player reselected and tried
    // again.
    @discardableResult
    public func playerPlayCard(handIndex: Int, boardIndex: Int) -> Bool {
        guard gameState == .playing, isPlayerTurn, !isAnimatingPlacement else { return false }
        guard handIndex >= 0 && handIndex < playerHand.count else { return false }
        guard board.cells[boardIndex].card == nil else { return false }
        // Order/Chaos restrict which single card is legal to play this turn.
        guard mandatedPlayerHandIndex == nil || mandatedPlayerHandIndex == handIndex else { return false }

        clearHint()
        saveStateForUndo()

        let card = playerHand.remove(at: handIndex)
        // Chaos's mandated index is only re-rolled (below, and in applyAIMove) when it
        // becomes this side's turn again — left stale here, it would keep pointing at
        // whatever index the just-played card's removal shifted into, highlighting the
        // wrong card for the rest of the opponent's turn instead of clearing until
        // rerollChaosIndexIfNeeded recomputes it fresh.
        if activeRules.contains(.chaos) { chaosPlayerIndex = nil }
        applyPlacement(card: card, boardIndex: boardIndex, isFirstCard: playerHand.count == 4) { [weak self] in
            guard let self, self.gameState == .playing else { return }
            self.isPlayerTurn = false
            // Reroll now (not lazily inside aiPlayTurn) so the mandated card is already
            // highlighted for the player to see during the delay below, before the AI
            // actually plays it.
            self.rerollChaosIndexIfNeeded(forPlayerSide: false)
            if UISound.isHeadlessMode {
                self.aiPlayTurn()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.opponentMoveDelay) {
                    self.aiPlayTurn()
                }
            }
        }
        return true
    }

    // Places `card`, optionally staging a "flash the winning stat(s), then flip"
    // sequence before the capture becomes visible (Point Highlights). `completion` runs
    // once the placement (and its capture/flip, if any) has fully resolved — each
    // caller uses it to schedule whatever comes next (the opponent's turn, or the
    // player's), so that scheduling can't race ahead of an in-progress animation.
    private func applyPlacement(card: HoneycombCard, boardIndex: Int, isFirstCard: Bool, completion: @escaping () -> Void) {
        var finalBoard = board
        var placedCard = card
        
        let isBombShelterFirst = activeRules.contains(.bombShelter) && isFirstCard
        if isBombShelterFirst {
            placedCard.isFaceDown = true
            placedCard.bombShelterTurnsRemaining = 3
        }

        let flips = finalBoard.placeCard(placedCard, at: boardIndex, rules: activeRules, skipCaptures: isBombShelterFirst)

        // Ticks down any other still-hidden Bomb Shelter card(s) already on the board —
        // this play counts as one of their 3 turns, whether or not this play was itself
        // a Bomb Shelter placement. The card flips on its own once the timer runs out,
        // rather than waiting for the match to end.
        advanceBombShelterTimers(on: &finalBoard, excluding: boardIndex)

        // Only the directly-placed card's own captures get highlighted — secondary
        // combo/chain flips (a captured card immediately flipping its own neighbors)
        // just flip along with everything else below, no separate highlight cycle.
        let directStatIndices = Set(flips.compactMap { neighborDirection(from: boardIndex, to: $0) })

        if options.showPointHighlights, !directStatIndices.isEmpty, !UISound.isHeadlessMode {
            // Show the new card placed but not yet flipped — captured cells keep their
            // pre-capture owner for one beat while the attacker's winning stat(s) flash.
            var intermediateBoard = board
            intermediateBoard.cells[boardIndex].card = placedCard
            board = intermediateBoard
            pointHighlight = (cardId: placedCard.id, statIndices: directStatIndices)
            isAnimatingPlacement = true

            DispatchQueue.main.asyncAfter(deadline: .now() + Self.pointHighlightDelay) { [weak self] in
                guard let self else { return }
                self.pointHighlight = nil
                withAnimation {
                    self.board = finalBoard
                }
                self.isAnimatingPlacement = false
                self.finishPlacement(placedSuit: placedCard.data.suit, flipsCount: flips.count, completion: completion)
            }
        } else {
            board = finalBoard
            finishPlacement(placedSuit: placedCard.data.suit, flipsCount: flips.count, completion: completion)
        }
    }

    private func finishPlacement(placedSuit: String, flipsCount: Int, completion: @escaping () -> Void) {
        sessionCardsCaptured += flipsCount
        flashRuleBannerIfNeeded(placedSuit: placedSuit)
        if options.isSoundEnabled {
            UISound.play(named: "snap", enabled: true)
        }
        checkWinCondition()
        completion()
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
        let openPlayerCardIds: Set<String>
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
        !undoStack.isEmpty && gameState == .playing && isPlayerTurn && !isAnimatingPlacement
    }

    private func saveStateForUndo() {
        undoStack.push(HoneycombSnapshot(
            board: board,
            playerHand: playerHand,
            opponentHand: opponentHand,
            openOpponentCardIds: openOpponentCardIds,
            openPlayerCardIds: openPlayerCardIds,
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
        clearHint()

        board = previous.board
        playerHand = previous.playerHand
        opponentHand = previous.opponentHand
        openOpponentCardIds = previous.openOpponentCardIds
        openPlayerCardIds = previous.openPlayerCardIds
        isPlayerTurn = previous.isPlayerTurn
        sessionCardsCaptured = previous.sessionCardsCaptured
        chaosPlayerIndex = previous.chaosPlayerIndex
        chaosOpponentIndex = previous.chaosOpponentIndex
        flashRuleBanner = nil
        pointHighlight = nil
        isAnimatingPlacement = false
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
        // Only cards actually revealed to the opponent (All Open/Three Open — see
        // openPlayerCardIds) are passed through; any remaining hidden cards are counted
        // but never exposed as concrete data, so the AI can't read the player's hand it
        // isn't supposed to see. See HoneycombAI.minimaxScore's unknownPlayerCardCount
        // handling for how the search responds when some of the player's hand is hidden.
        let visiblePlayerCards = playerHand.filter { isPlayerCardVisibleToOpponent(cardId: $0.id) }
        let playerDeckData = visiblePlayerCards.map { $0.data }
        let unknownPlayerCardCount = playerHand.count - visiblePlayerCards.count
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
                unknownPlayerCardCount: unknownPlayerCardCount,
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
        if activeRules.contains(.chaos) { chaosOpponentIndex = nil }
        applyPlacement(card: cardToPlay, boardIndex: bestMove.boardIndex, isFirstCard: opponentHand.count == 4) { [weak self] in
            guard let self, self.gameState == .playing else { return }
            self.isPlayerTurn = true
            // Reroll now so the player's mandated card (under Chaos) is highlighted
            // the instant it becomes their turn, not lazily on their first tap.
            self.rerollChaosIndexIfNeeded(forPlayerSide: true)
        }
    }

    // Bomb Shelter: the hidden card flips on its own 3 turns after it was played,
    // rather than waiting for the match to end — a timed landmine the opponent has to
    // play around, instead of a secret that's only relevant at the final score.
    private func advanceBombShelterTimers(on board: inout HoneycombBoard, excluding justPlacedIndex: Int) {
        for i in 0..<9 {
            if i == justPlacedIndex { continue }
            guard var card = board.cells[i].card, card.isFaceDown, let remaining = card.bombShelterTurnsRemaining else { continue }

            let newRemaining = remaining - 1
            if newRemaining <= 0 {
                card.bombShelterTurnsRemaining = nil
                board.cells[i].card = card
                _ = board.revealFaceDownCard(at: i, rules: activeRules)
                flashRuleBanner = "Bomb Shelter Revealed!"
            } else {
                card.bombShelterTurnsRemaining = newRemaining
                board.cells[i].card = card
            }
        }
    }

    private func checkWinCondition() {
        if board.isFull {
            if activeRules.contains(.bombShelter) {
                revealBombSheltersAndSettle()
            } else {
                settleMatch()
            }
        }
    }

    private func revealBombSheltersAndSettle() {
        isAnimatingPlacement = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            let starterOwner: CardOwner = self.playerHand.isEmpty ? .player : .opponent
            
            var starterCell = -1
            var secondCell = -1
            
            for i in 0..<9 {
                if let card = self.board.cells[i].card, card.isFaceDown {
                    if card.originalOwner == starterOwner { starterCell = i }
                    else { secondCell = i }
                }
            }

            if starterCell != -1 {
                let flips = self.board.revealFaceDownCard(at: starterCell, rules: self.activeRules)
                if !flips.isEmpty && self.options.isSoundEnabled {
                    UISound.play(named: "snap", enabled: true)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                
                if secondCell != -1 {
                    let flips = self.board.revealFaceDownCard(at: secondCell, rules: self.activeRules)
                    if !flips.isEmpty && self.options.isSoundEnabled {
                        UISound.play(named: "snap", enabled: true)
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    self.isAnimatingPlacement = false
                    self.settleMatch()
                }
            }
        }
    }

    private func settleMatch() {
        if board.isFull {
            // The board just filled, which always ends either the match (win/lose) or
            // this round (draw, into Sudden Death) — any Hint highlight still showing
            // from the move that just landed is no longer relevant either way.
            clearHint()
            let pScore = board.playerScore + playerHand.count
            let oScore = board.opponentScore + opponentHand.count
            
            if pScore > oScore {
                matchResult = "You Win!"
                gameState = .gameOver
                if options.isSoundEnabled { UISound.play(named: "victory", enabled: true) }
                stats.recordGame(won: true, drawn: false, captures: sessionCardsCaptured, sessionCombos: board.sessionSamePlusTriggers, flawless: oScore == 0, difficulty: options.difficulty, fallenAceCaptures: board.sessionFallenAceCaptures)
            } else if oScore > pScore {
                matchResult = "You Lose"
                gameState = .gameOver
                stats.recordGame(won: false, drawn: false, captures: sessionCardsCaptured, sessionCombos: board.sessionSamePlusTriggers, flawless: false, fallenAceCaptures: board.sessionFallenAceCaptures)
            } else {
                matchResult = "Draw - Sudden Death!"
                gameState = .suddenDeath
                stats.recordGame(won: false, drawn: true, captures: sessionCardsCaptured, sessionCombos: board.sessionSamePlusTriggers, flawless: false, fallenAceCaptures: board.sessionFallenAceCaptures)
                
                // Give enough time for the final card placement and any combo animations to fully resolve
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                    self?.flashRuleBanner = "Sudden Death!"
                    self?.triggerSuddenDeath()
                }
                return
            }
            saveStats()
            // HoneycombView holds the win/lose overlay back on its own (gated on its
            // showingRuleBanner state) until any Combo/Same/Plus/Ascension/Descension
            // banner currently on screen finishes — that covers a banner from the move
            // right before this one too, not just one fired on this exact placement, so
            // showPostGamePrompt can just be set immediately here.
            showPostGamePrompt = true
        }
    }
    
    private func triggerSuddenDeath() {
        stats.suddenDeathCount += 1
        saveStats()

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
        // Sudden Death doesn't reroll rules, so the same suits chosen at match start
        // (setupRules) carry over rather than picking a fresh pair for the tie-break.
        board.ascensionDescensionSuits = ascensionDescensionSuits
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

    // "Take a Card" is capped at one successful steal per match — the player must
    // Rematch (or start a new match) to steal again, even if multiple opponent cards
    // were captured this round. Reset in finishMatchSetup, the shared tail of both
    // startNewGame() and rematch().
    public private(set) var hasStolenThisMatch: Bool = false

    // Whether at least one card on the board is actually eligible to steal right now —
    // same predicate both mac's and iOS's board-cell rendering use to decide the yellow
    // steal-highlight border. Without this check, "Take a Card"/"Steal Card" could show
    // on a win where the player never captured anything of the opponent's (or already
    // unlocked everything they did capture), leading into a steal flow with nothing on
    // the board actually selectable.
    public var hasStealableCard: Bool {
        board.cells.contains { cell in
            guard let card = cell.card else { return false }
            return card.originalOwner == .opponent
                && card.owner == .player
                && !HoneycombProfileManager.shared.unlockedCardIds.contains(card.data.id)
        }
    }

    // Stages a steal so the UI can show a confirmation alert before it's applied
    // ("Are you sure you want to steal this card?"). Stealing unlocks the card
    // straight into the card bank — it no longer touches the active deck/hand at
    // all, so there's nothing left to validate against deck composition (the old
    // 5★/4★ caps only ever existed to keep a 5-card deck legal).
    public func requestSteal(boardIndex: Int) {
        // Stealable requires the player to have actually captured this card this
        // round — it must be one the opponent originally played (originalOwner) AND
        // currently sitting under the player's control (owner) at match end. A card
        // the opponent still holds was never captured, so it isn't eligible. Already
        // owning the card (it's in the player's card bank) is also disqualifying —
        // stealing it would gain nothing and just burn the one steal this match allows.
        guard !hasStolenThisMatch else { return }
        guard let incoming = board.cells[boardIndex].card,
              incoming.originalOwner == .opponent, incoming.owner == .player,
              !HoneycombProfileManager.shared.unlockedCardIds.contains(incoming.data.id) else { return }

        pendingSteal = PendingSteal(boardIndex: boardIndex, cardName: incoming.data.name)
    }

    public func cancelPendingSteal() {
        pendingSteal = nil
    }

    public func confirmPendingSteal() {
        guard let steal = pendingSteal else { return }
        pendingSteal = nil
        guard let card = board.cells[steal.boardIndex].card, card.originalOwner == .opponent else { return }

        HoneycombProfileManager.shared.unlockCard(id: card.data.id)
        stats.cardsStolen += 1
        saveStats()
        hasStolenThisMatch = true
    }

    public func takeCard(boardIndex: Int) {
        requestSteal(boardIndex: boardIndex)
        confirmPendingSteal()
    }

    public func restartCurrentGame() {
        startNewGame()
    }
    
    public func resetStatistics() {
        stats = HoneycombStats()
        saveStats()
    }

    // Wipes saved decks/card bank back to Deck 1 (renamed "Default") and rerolls the
    // entire card database with a new seed, so a maxed-out collection can be played
    // again with a different set of cards. Order matters: the profile wipe reads
    // Deck 1's cards under the *current* seed before HoneycombDatabase regenerates
    // under a new one. Deck 1 becomes the active deck since every other slot is
    // wiped and a stale index into an now-empty slot would be nonsensical.
    public func startOver() {
        HoneycombProfileManager.shared.startOver()
        HoneycombDatabase.shared.reseed()
        options.activeDeckIndex = 0
        stats.timesStartedOver += 1
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
