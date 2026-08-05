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
            enqueueBanner("\(HoneycombRule.same.rawValue.uppercased())!")
        case .plus:
            enqueueBanner("\(HoneycombRule.plus.rawValue.uppercased())!")
        case .suddenDeath:
            enqueueBanner("\(HoneycombRule.suddenDeath.rawValue.uppercased())!")
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
    // A FIFO queue of banner texts, replacing a single last-write-wins slot — that let a
    // second event (e.g. a Bomb Shelter reveal firing moments after an ordinary
    // placement's own capture, or two staggered end-of-match reveals) silently clobber
    // an earlier banner before it had been on screen long enough to read, or before it
    // rendered at all. The view shows `flashRuleBanner` (the queue's front) and calls
    // `advanceBannerQueue()` once its own dismiss timer completes, revealing whatever's
    // queued behind it — see enqueueBanner/advanceBannerQueue/clearBannerQueue below.
    private var bannerQueue: [String] = []
    public var flashRuleBanner: String? { bannerQueue.first }
    public var flashRuleBannerTrigger: Int = 0

    private func enqueueBanner(_ text: String) {
        bannerQueue.append(text)
        // Only bump the trigger when this becomes the front of the queue — if something
        // is already showing, the view picks this one up on its own via
        // advanceBannerQueue() once the current banner's dismiss timer fires, rather
        // than interrupting it.
        if bannerQueue.count == 1 {
            flashRuleBannerTrigger += 1
        }
    }

    // Called by the view once the currently-shown banner's own dismiss timer completes.
    public func advanceBannerQueue() {
        guard !bannerQueue.isEmpty else { return }
        bannerQueue.removeFirst()
        if !bannerQueue.isEmpty {
            flashRuleBannerTrigger += 1
        }
    }

    private func clearBannerQueue() {
        bannerQueue.removeAll()
    }
    public var sessionCardsCaptured: Int = 0

    // Which of the attacker's N/E/S/W stats (0=Top,1=Right,2=Bottom,3=Left) are
    // currently flashing because they just won a capture — transient, not part of
    // HoneycombSnapshot (undo doesn't need to rewind a mid-animation highlight).
    public var pointHighlight: (cardId: String, statIndices: Set<Int>)? = nil

    // Id(s) of the card(s) that just directly *caused* a capture (the placed card
    // itself, or a Hive Swarm reveal that captured a neighbor) — not the cards they
    // captured. HoneycombCardView pops the attacker's own scale off this rather than
    // the captured neighbors', so a capture reads as the attacking card lunging/
    // growing, not the victim swelling up. A Set (not a single id) since a Bomb
    // Shelter timer expiring for both sides on the same turn can hand back two
    // reveals — and thus two attackers — at once. Transient like pointHighlight
    // above: flashCaptureAttackers sets it, then clears shortly after.
    public var captureAttackerIds: Set<String> = []

    private func flashCaptureAttackers(_ ids: Set<String>) {
        guard !ids.isEmpty, !UISound.isHeadlessMode else { return }
        captureAttackerIds.formUnion(ids)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.captureAttackerIds.subtract(ids)
        }
    }

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
    // Nectar Exchange's 3-beat "lift, fly, land" animation (mirrors FFXIV Triple
    // Triad's card-swap flourish) — drives the scale/shadow HoneycombView applies
    // to the two swapHighlightCardIds cards. See stageSwapAnimation for the timing
    // that transitions this.
    public enum SwapAnimationPhase {
        case idle, lifting, moving, landing
    }
    public private(set) var swapAnimationPhase: SwapAnimationPhase = .idle
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

    public var canRematch: Bool { !rematchOpponentDeck.isEmpty }

    // Steal Protection: true only for a match started via rematch() (not a fresh
    // startNewGame() roll) — settleMatch() reads this to decide whether a win with
    // nothing new to steal should count toward consecutiveNoStealWins below. A fresh
    // match's own opponent-deck roll (rollOpponentDeck) already guarantees at least
    // one unlockable card, so this protection only ever needs to cover the frozen
    // rematch pool, which doesn't get that same guarantee.
    private var isRematchMatch: Bool = false
    // How many rematches in a row (against the same frozen rematchOpponentDeck) the
    // player has WON with nothing new to steal — e.g. the opponent's deck happens to
    // include a card that's realistically never capturable (an all-Ace 5★). Reset to
    // 0 by startNewGame() (a fresh opponent pool starts this over) and by any win that
    // *does* yield a stealable card (the protection wasn't needed that time). At 2,
    // settleMatch() grants a card directly (see grantStealProtectionCard) and resets
    // this back to 0, rather than growing without bound. Losses/draws don't touch it
    // either way — only a won rematch counts as evidence the player is stuck.
    private var consecutiveNoStealWins: Int = 0

    public func startNewGame() {
        // Invalidates any AI move computation still in flight on a background queue from
        // the match/round this is resetting (e.g. Surrender calling straight into this
        // without going through aiPlayTurn again first).
        aiMoveGeneration += 1
        handSetupGeneration += 1
        let generation = handSetupGeneration
        undoStack.removeAll()
        swapHighlightCardIds.removeAll()
        clearHint()
        lastHiveSwarmPhrase = nil
        isRematchMatch = false
        consecutiveNoStealWins = 0
        // Defensive reset — a previous match quit (or otherwise interrupted) while
        // this was true (e.g. mid-Swap-animation-wait, see quitMatch) would otherwise
        // leave it stuck true forever, since nothing else clears it for a match that
        // doesn't itself have a pending Swap. Bumping handSetupGeneration above
        // already invalidates that stale closure, so this can't be raced back to true.
        isAnimatingPlacement = false

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
        // the combined "First Move" + rules banner (no separate delayed flash —
        // "Swap" is just one of activeRules, listed by finishMatchSetup() like any
        // other active rule), so the player sees exactly which two are about to
        // trade before anything moves.
        swapHighlightCardIds = [swapResult.preSwapPlayerCard.id, swapResult.preSwapOpponentCard.id]

        // Actually animate the trade only after the deal-flip has fully finished
        // playing out (plus a deliberate pause) — the trade used to start at a flat
        // 2.0s matching only the "First Move" banner's own runtime, which predates
        // the deal-flip animation and could let the trade start while the last
        // card(s) were still flipping in.
        DispatchQueue.main.asyncAfter(deadline: .now() + swapStartDelay) { [weak self] in
            guard let self, self.handSetupGeneration == generation else { return }

            // Beat 1 — The Lift: scale up + shadow, cards not yet relocated. See
            // HoneycombView's swap rendering (scaleEffect/shadow keyed off
            // swapAnimationPhase, applied only to swapHighlightCardIds) for the
            // visual side of this; the phase transition here just drives it.
            withAnimation(.easeInOut(duration: Self.swapLiftDuration)) {
                self.swapAnimationPhase = .lifting
            }
            // "whoosh" doesn't exist as its own asset yet — shuffle is the closest
            // existing sound for a lift-off flourish. Swap this out once a
            // dedicated whoosh effect is added.
            if self.options.isSoundEnabled {
                UISound.play(named: "shuffle", enabled: true)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + Self.swapLiftDuration) { [weak self] in
                guard let self, self.handSetupGeneration == generation else { return }

                // Beat 2 — The Flight: the actual data-level trade, animated across
                // the full flight duration so matchedGeometryEffect interpolates
                // the cross-hand position change while scale stays elevated from
                // Beat 1. Looked up by id (not the original array index) in case
                // the player already played one of the two cards during the
                // highlight pause — if so, it's skipped rather than resurrected
                // into a slot it no longer occupies.
                self.swapAnimationPhase = .moving
                withAnimation(.easeInOut(duration: Self.swapFlightDuration)) {
                    if let idx = self.playerHand.firstIndex(where: { $0.id == swapResult.preSwapPlayerCard.id }) {
                        self.playerHand[idx] = swapResult.finalPlayerCard
                    }
                    if let idx = self.opponentHand.firstIndex(where: { $0.id == swapResult.preSwapOpponentCard.id }) {
                        self.opponentHand[idx] = swapResult.finalOpponentCard
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + Self.swapFlightDuration) { [weak self] in
                    guard let self, self.handSetupGeneration == generation else { return }

                    // Beat 3 — The Touchdown: scale back down to normal, shadow fades.
                    withAnimation(.easeInOut(duration: Self.swapLandDuration)) {
                        self.swapAnimationPhase = .landing
                    }
                    if self.options.isSoundEnabled {
                        UISound.play(named: "snap", enabled: true)
                    }

                    // Same two ids throughout (identity-preserving swap), so the
                    // highlight keeps tracking them across all 3 beats. Held past
                    // the Touchdown's own duration by swapHighlightHoldBuffer so it
                    // doesn't clear right as the scale-down animation is still
                    // finishing.
                    DispatchQueue.main.asyncAfter(deadline: .now() + Self.swapLandDuration + Self.swapHighlightHoldBuffer) { [weak self] in
                        guard let self, self.handSetupGeneration == generation else { return }
                        self.swapAnimationPhase = .idle
                        self.swapHighlightCardIds.removeAll()
                    }
                }
            }
        }
    }

    // Display text for one active rule in the "First Move" banner: just the rule's
    // name, except Ascension/Descension which also name the affected suit(s) — e.g.
    // "Swap", "Ascension: Hearts". No trailing punctuation; the banner's own "!"
    // belongs only after "First Move: Player/Opponent".
    private func formatRuleForBanner(_ rule: HoneycombRule) -> String {
        if rule == .ascension || rule == .descension {
            let suitNames = ascensionDescensionSuits.sorted().map { HoneycombCardData.suitDisplayName($0) }
            return "\(rule.rawValue): \(suitNames.joined(separator: ", "))"
        }
        return rule.rawValue
    }

    // Shared tail between startNewGame() and rematch() — decides who moves first,
    // flashes the opening banner, and (if the opponent starts) kicks off their move.
    // Everything before this point differs between the two (rule/hand setup); once
    // board/activeRules/playerHand/opponentHand are all in place, the rest is identical.
    // `forceAlternateStarter` is set by rematch(): unlike a genuinely new match (a fresh
    // coin toss, just with bad-luck protection against a long same-side streak), a
    // rematch of the same match should always hand the opening move to whoever didn't
    // have it last time, so replaying repeatedly can't keep favoring one side.
    private func finishMatchSetup(forceAlternateStarter: Bool = false) {
        gameState = .playing
        showPostGamePrompt = false
        sessionCardsCaptured = 0
        board.sessionSamePlusTriggers = 0
        board.sessionFallenAceCaptures = 0
        hasStolenThisMatch = false
        let playerStarts: Bool
        if forceAlternateStarter, let lastMatchStarterWasPlayer {
            playerStarts = !lastMatchStarterWasPlayer
        } else if starterStreak >= 3, let lastMatchStarterWasPlayer {
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
        // Every active rule (up to 2) gets its own line below "First Move", in the
        // same font (FlashBannerView just renders whatever's after each "\n") —
        // rather than only Swap riding along while Ascension/Descension/etc. never
        // got shown here at all.
        let firstMoveLine = isPlayerTurn ? "First Move: Player!" : "First Move: \(options.difficulty.displayName)!"
        let ruleLines = activeRules.map { formatRuleForBanner($0) }
        // A brand new match starting — any banner still queued from the previous one
        // (e.g. a match ended mid-combo-sequence) is no longer relevant.
        clearBannerQueue()
        enqueueBanner(([firstMoveLine] + ruleLines).joined(separator: "\n"))

        if options.isSoundEnabled {
            UISound.play(named: "shuffle", enabled: true)
        }

        // A Swap trade is pending iff stageSwapAnimation (called just before this, by
        // both startNewGame and rematch) populated the highlight set. When one is
        // pending, the first move — player input or the AI's opening move — must wait
        // until the trade's own animation has actually landed, rather than stepping on
        // it mid-swap.
        let swapPending = !swapHighlightCardIds.isEmpty
        if swapPending {
            isAnimatingPlacement = true
        }
        let generation = handSetupGeneration

        func startFirstMove() {
            if swapPending {
                isAnimatingPlacement = false
            }
            if !isPlayerTurn {
                self.aiPlayTurn()
            }
        }

        if !isPlayerTurn || swapPending {
            let delay = swapPending ? swapAnimationCompleteDelay : Self.opponentMoveDelay
            if UISound.isHeadlessMode {
                startFirstMove()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, self.handSetupGeneration == generation else { return }
                    startFirstMove()
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
        isRematchMatch = true
        aiMoveGeneration += 1
        handSetupGeneration += 1
        let generation = handSetupGeneration
        undoStack.removeAll()
        swapHighlightCardIds.removeAll()
        clearHint()
        isAnimatingPlacement = false
        lastHiveSwarmPhrase = nil

        board = HoneycombBoard()
        activeRules = rematchActiveRules
        ascensionDescensionSuits = rematchAscensionDescensionSuits
        board.ascensionDescensionSuits = ascensionDescensionSuits
        setupPlayerHand()

        let swapResult = applyOpponentDeck(rematchOpponentDeck)
        stageSwapAnimation(swapResult, generation: generation)
        finishMatchSetup(forceAlternateStarter: true)
    }

    // A deliberate pause before the opponent's move actually lands — long enough to
    // read the board (and, under Order/Chaos, to see which of their cards is
    // highlighted as the one they're about to play) before it happens.
    private static let opponentMoveDelay: TimeInterval = 2.5
    // Matches mac HoneycombView's deal-flip runtime: 10 hand slots (5 player, then 5
    // opponent) play their flip one after another with no overlap — dealFlipStagger
    // equals each flip's own HoneycombFlipTiming.duration (0.4s), so 10 cards take
    // 10*0.4=4.0s total. Must stay in sync with those View-layer constants (mirrors
    // the Windows port's DealFlipTotalMs, which plays the same way). iOS doesn't have
    // the deal-flip animation yet, so this is just a no-op pause there.
    // If the opponent's cards are face-down (the default unless rules dictate otherwise),
    // they don't visually flip at all, meaning the animation appears completely finished
    // after the 5 player cards (2.0s). This dynamically skips that empty 2.0s block.
    private var dealFlipTotalDuration: TimeInterval {
        let opponentCardsVisible = opponentHand.contains { isOpponentCardVisible(cardId: $0.id) }
        return opponentCardsVisible ? 4.0 : 2.0
    }
    // Deliberate pause after the deal-flip finishes before the Nectar Exchange trade
    // starts, so the two animations never visually overlap — mirrors the Windows
    // port's SwapPostDealDelayMs. Short on purpose: the Lift beat right after this
    // is itself part of the animation (cards visibly scaling up), so this alone
    // should read as a beat, not a stall.
    private static let swapPostDealDelay: TimeInterval = 0.2
    // When the Swap trade's card-move animation actually starts (see
    // stageSwapAnimation) — the deal-flip's own runtime plus the deliberate post-deal
    // pause above. Previously a flat 2.0s matching only the "First Move" banner's own
    // runtime, which predates the deal-flip animation and could let the trade start
    // while the deal-flip was still playing, or (via swapAnimationCompleteDelay
    // below) let the first move fire before the trade's own animation had actually
    // landed.
    private var swapStartDelay: TimeInterval { dealFlipTotalDuration + Self.swapPostDealDelay }
    // Nectar Exchange's 3-beat "lift, fly, land" animation durations — see
    // stageSwapAnimation, which transitions swapAnimationPhase through .lifting/
    // .moving/.landing on exactly these timings. Total 1.7s (was a flat 0.9s
    // single-beat slide before this).
    private static let swapLiftDuration: TimeInterval = 0.5
    private static let swapFlightDuration: TimeInterval = 0.8
    private static let swapLandDuration: TimeInterval = 0.4
    private static let swapTotalMoveDuration: TimeInterval = swapLiftDuration + swapFlightDuration + swapLandDuration
    // Same 0.3s buffer the old single-beat design held past its own move duration,
    // so the highlight doesn't clear right as the Touchdown scale-down is still
    // finishing.
    private static let swapHighlightHoldBuffer: TimeInterval = 0.3
    // How long after match setup the Swap trade's *entire* sequence (see
    // stageSwapAnimation) actually finishes — swapStartDelay + all 3 beats +
    // the highlight-hold buffer. The first move (player input or the AI's
    // opening move) waits until this point when a Swap trade is pending,
    // instead of stepping on the trade mid-animation.
    private var swapAnimationCompleteDelay: TimeInterval { swapStartDelay + Self.swapTotalMoveDuration + Self.swapHighlightHoldBuffer }
    // How long a capture's winning stat(s) flash before the flip actually happens.
    private static let pointHighlightDelay: TimeInterval = 0.5

    // Bad-luck protection for Roulette: a plain independent roll can land on the exact
    // same result (same rule set AND same Ascension/Descension suit) several matches in
    // a row, which reads as "broken" even though it's just an unlucky draw. Re-rolling
    // whenever a draw exactly repeats the previous match's result — up to a small retry
    // cap, so a heavily-restricted pool (few unbanned rules) can't loop forever — makes
    // back-to-back identical rolls impossible without meaningfully changing each rule's
    // long-run odds.
    private var lastRouletteSignature: String? = nil
    private static let maxRouletteRerolls = 5

    private func setupRules() {
        if options.forceNormalMode {
            // Explicitly locked to zero rules — a real "Normal" match, as opposed to
            // an empty selectedRules (which means "let roulette decide" below).
            activeRules = []
            ascensionDescensionSuits = []
        } else if options.selectedRules.isEmpty {
            var rolledRules: [HoneycombRule] = []
            var rolledSuits: Set<String> = []
            for _ in 0..<Self.maxRouletteRerolls {
                (rolledRules, rolledSuits) = rollRouletteOnce()
                if rouletteSignature(rules: rolledRules, suits: rolledSuits) != lastRouletteSignature { break }
                // Otherwise keep re-rolling; the loop's final attempt is accepted
                // unconditionally rather than looping forever.
            }
            activeRules = rolledRules
            ascensionDescensionSuits = rolledSuits
            lastRouletteSignature = rouletteSignature(rules: rolledRules, suits: rolledSuits)
            return
        } else {
            activeRules = Array(options.selectedRules)
        }

        if activeRules.contains(.ascension) || activeRules.contains(.descension) {
            ascensionDescensionSuits = Set(["S", "H", "D", "C"].shuffled().prefix(1))
        } else {
            ascensionDescensionSuits = []
        }
    }

    // A stable, order-independent string identifying one roulette outcome, so two rolls
    // that only differ in the order rules happened to be drawn still compare equal.
    private func rouletteSignature(rules: [HoneycombRule], suits: Set<String>) -> String {
        let ruleNames = rules.map(\.rawValue).sorted().joined(separator: ",")
        let suitNames = suits.sorted().joined(separator: ",")
        return "\(ruleNames)|\(suitNames)"
    }

    // One independent roulette draw — rule set plus (if applicable) Ascension/Descension
    // suit. Can occasionally roll 0 rules, for a genuine Normal match, instead of always
    // forcing at least one.
    private func rollRouletteOnce() -> (rules: [HoneycombRule], suits: Set<String>) {
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

        var maxSlots = 2
        var forceMustPickAll = false

        if options.difficulty == .ultraHard {
            let roll = Double.random(in: 0..<1)
            if roll < 0.25 { maxSlots = 4 }
            else if roll < 0.70 { maxSlots = 3 }
            else if roll < 0.95 { maxSlots = 2 }
            else if roll < 0.99 { maxSlots = 1 }
            else { maxSlots = 0 }

            if maxSlots == 0 && normalBanned { maxSlots = 1 }
            forceMustPickAll = true
        } else if options.difficulty == .hard {
            let hardRoll = Double.random(in: 0..<1)
            if hardRoll < 0.01 {
                maxSlots = 4
                forceMustPickAll = true
            } else if hardRoll < 0.26 {
                maxSlots = 3
                forceMustPickAll = true
            }
        }

        var rules: [HoneycombRule] = []
        for slot in 0..<maxSlots {
            guard !pool.isEmpty else { break }
            let mustPick = (slot == 0 && normalBanned) || forceMustPickAll
            let stopProbability = slot == 0 ? stopProbabilityFirst : stopProbabilitySecond
            if !mustPick && Double.random(in: 0..<1) < stopProbability { break }

            let randomRule = Self.weightedRandomRule(from: pool)
            rules.append(randomRule)
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

        let suits: Set<String>
        if rules.contains(.ascension) || rules.contains(.descension) {
            suits = Set(["S", "H", "D", "C"].shuffled().prefix(1))
        } else {
            suits = []
        }
        return (rules, suits)
    }

    // Weighted draw from `pool` using each rule's `HoneycombRule.weight` — every weight
    // is a positive Int, and `pool` is guaranteed non-empty by rollRouletteOnce's caller
    // (guard !pool.isEmpty), so totalWeight is always > 0 here and Int.random(in:) can't
    // trap. The trailing `pool.last!` is unreachable (the loop above always finds a rule
    // before randomValue can go negative past the last element) but keeps this total.
    private static func weightedRandomRule(from pool: [HoneycombRule]) -> HoneycombRule {
        let totalWeight = pool.reduce(0) { $0 + $1.weight }
        var randomValue = Int.random(in: 0..<totalWeight)
        for rule in pool {
            randomValue -= rule.weight
            if randomValue < 0 { return rule }
        }
        return pool.last!
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

        // Composition always assembles in the same fixed star-tier order (e.g. Ultra
        // Hard is always [3,3,4,5,5]), which — combined with the Order rule always
        // mandating hand-index 0 — made the AI's entire play sequence 100% predictable
        // every match: a player could always count on 2 weak opens followed by a
        // guaranteed 5-star, 5-star finish. Shuffle unconditionally (not just when
        // Order is active) so tier position never leaks information, regardless of
        // which rules end up active this match.
        deck.shuffle()

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

        deck = ensureAscensionCoverage(deck)
        return deck
    }

    // Ultra Hard only: a player can stack their own deck with cards of the rolled
    // Ascension suit(s) to farm the +1-per-suit-card-on-board bonus, while the
    // opponent's deck is otherwise assembled with no awareness of which suits are
    // even in play. Guarantees at least 3 of the opponent's 5 cards match an active
    // Ascension suit so the AI can benefit from the same bonus the player is
    // exploiting, rather than the player getting the mode's biggest lever for free.
    // Descension is deliberately left alone — it's a penalty, so forcing more
    // Descension-suited cards into the AI's hand would only hurt it, not balance
    // anything.
    private func ensureAscensionCoverage(_ deck: [HoneycombCardData]) -> [HoneycombCardData] {
        guard options.difficulty == .ultraHard,
              activeRules.contains(.ascension),
              !ascensionDescensionSuits.isEmpty else { return deck }

        var result = deck
        var matchingCount = result.filter { ascensionDescensionSuits.contains($0.suit) }.count
        guard matchingCount < 3 else { return result }

        let db = HoneycombDatabase.shared
        // Swap the deck's lowest-star non-matching cards first, so the deck's overall
        // power level (its highest-star cards) stays intact where possible.
        let nonMatchingIndices = result.indices
            .filter { !ascensionDescensionSuits.contains(result[$0].suit) }
            .sorted { result[$0].stars < result[$1].stars }

        for idx in nonMatchingIndices {
            guard matchingCount < 3 else { break }
            let tier = result[idx].stars
            let usedIds = Set(result.map(\.id))
            let candidates = db.allCards.filter {
                $0.stars == tier && ascensionDescensionSuits.contains($0.suit) && !usedIds.contains($0.id)
            }
            guard let substitute = candidates.randomElement() else { continue }
            result[idx] = substitute
            matchingCount += 1
        }
        return result
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
        if let swap = swapResult {
            // Whether that slot ended up visible (All Open, or Three Open's random
            // pick landed on it) — checked BEFORE the unconditional insert below,
            // since that would otherwise always make this true.
            let slotIsVisible = openOpponentCardIds.contains(swap.finalOpponentCard.id)
            // A card that came from the player's own hand via Swap stays face-up in the
            // opponent's hand for the rest of the match — the player already knows exactly
            // what it is, so there's nothing left to hide.
            openOpponentCardIds.insert(swap.finalOpponentCard.id)
            // If that slot is visible, the CURRENT pre-swap card sitting there is
            // visible too for the whole window before the trade actually lands —
            // only its eventual (post-swap) id was registered above, so without
            // this the card about to be swapped away incorrectly rendered as
            // hidden/face-down until the trade completed.
            if slotIsVisible {
                openOpponentCardIds.insert(opponentHand[swap.opponentIndex].id)
            }
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
        if let swap = swapResult {
            let slotIsVisible = openPlayerCardIds.contains(swap.finalPlayerCard.id)
            // A card that came from the opponent's hand via Swap stays visible to the
            // opponent for the rest of the match — the AI already knows exactly what it is,
            // it was its own card a moment ago.
            openPlayerCardIds.insert(swap.finalPlayerCard.id)
            // Mirrors the opponent-side fix above: if that slot is visible, the
            // CURRENT pre-swap card sitting there is visible too for the whole
            // window before the trade actually lands.
            if slotIsVisible {
                openPlayerCardIds.insert(playerHand[swap.playerIndex].id)
            }
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
        hintClearTask?.cancel()

        let clearTask = DispatchWorkItem { [weak self] in
            self?.activeHint = nil
        }
        hintClearTask = clearTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: clearTask)
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
    // Takes the board explicitly (rather than reading `self.board`) so it can be
    // computed *before* a capture's resulting board is actually committed — see
    // stageCaptureCommit, which needs the banner text up front to decide whether
    // this placement gets the announcement pause.
    private func bannerText(placedSuit: String, for board: HoneycombBoard) -> String? {
        var parts: [String] = []
        // Skip on the game's last move (the one that fills the board) — the win/lose
        // overlay appears immediately after, and an Ascension/Descension banner flashing
        // at the same moment just clutters that transition. Same/Plus/Combo still show,
        // since those describe what the final move itself actually did.
        if !board.isFull && board.ascensionDescensionSuits.contains(placedSuit) {
            if activeRules.contains(.ascension) {
                parts.append("\(HoneycombRule.ascension.rawValue)!")
            } else if activeRules.contains(.descension) {
                parts.append("\(HoneycombRule.descension.rawValue)!")
            }
        }
        if let combo = Self.comboBannerText(for: board) { parts.append(combo) }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    // Same/Plus/Fallen Ace/Combo only ever describe what the board's last capture
    // resolution actually did, independent of whether that resolution came from a normal
    // placement (flashRuleBannerIfNeeded) or a Bomb Shelter reveal flipping a hidden card
    // on its own (advanceBombShelterTimers/revealBombSheltersAndSettle) — both paths run
    // the same resolveCaptures logic, so both need to surface it the same way. Takes the
    // board explicitly (rather than reading `self.board`) since advanceBombShelterTimers
    // operates on a local `inout` board that hasn't been assigned to self.board yet.
    private static func comboBannerText(for board: HoneycombBoard) -> String? {
        var parts: [String] = []
        if board.lastSameTriggered { parts.append("\(HoneycombRule.same.rawValue)!") }
        if board.lastPlusTriggered { parts.append("\(HoneycombRule.plus.rawValue)!") }
        if board.lastFallenAceTriggered { parts.append("\(HoneycombRule.fallenAce.rawValue)!") }
        // Combo = a Same/Plus-triggered flip going on to capture its own neighbors —
        // not just any move that happens to flip 2+ ordinary neighbors at once.
        if board.lastComboFlipCount > 0 {
            parts.append("HIVE MIND x\(board.lastComboFlipCount)!")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
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
        var capturedBoard = board
        var placedCard = card

        let isBombShelterFirst = activeRules.contains(.bombShelter) && isFirstCard
        if isBombShelterFirst {
            placedCard.isFaceDown = true
            placedCard.bombShelterTurnsRemaining = 3
        }

        // Note: this only resolves the just-placed card's own capture — any *other*
        // hidden Bomb Shelter card's timer expiring is handled separately, as its own
        // staged step, by finishPlacement below. Bundling both into one board mutation
        // used to mean a same-turn reveal committed in the exact same instant as this
        // capture, with a single banner slot overwritten by whichever set it last.
        let flips = capturedBoard.placeCard(placedCard, at: boardIndex, rules: activeRules, skipCaptures: isBombShelterFirst)

        // Only the directly-placed card's own captures get highlighted — secondary
        // combo/chain flips (a captured card immediately flipping its own neighbors)
        // just flip along with everything else below, no separate highlight cycle.
        let directStatIndices = Set(flips.compactMap { neighborDirection(from: boardIndex, to: $0) })

        // Only an actual capture (Same/Plus/Fallen Ace/Combo — an Ascension/
        // Descension-only note never captures anything) gets the announcement pause
        // (see stageCaptureCommit): the banner shows first, and the *captured
        // neighbors'* flip waits until the banner has mostly faded, instead of landing
        // in the same instant and having the toast cover it. The placed card itself
        // never waits on this — see below.
        let banner = bannerText(placedSuit: placedCard.data.suit, for: capturedBoard)
        // Only the placed card's own DIRECT capture makes it "the card doing the
        // flipping" — a combo chain's secondary flips are captures made by whichever
        // neighbor they captured, not by this placement itself, so they don't add
        // their own attacker id here.
        let attackerIds: Set<String> = flips.isEmpty ? [] : [placedCard.id]

        // Show the placed card immediately — captured cells keep their pre-capture
        // owner for now — regardless of Point Highlights or whether there's a banner
        // to wait for. The attacking card should never sit invisible while a capture
        // banner plays out, and its own capture-attacker pop (flashCaptureAttackers)
        // fires right here too: it's the placement itself popping, not the captured
        // neighbors' flip, so there's no reason for it to wait on the banner either.
        var intermediateBoard = board
        intermediateBoard.cells[boardIndex].card = placedCard
        board = intermediateBoard
        flashCaptureAttackers(attackerIds)
        isAnimatingPlacement = true

        if options.showPointHighlights, !directStatIndices.isEmpty, !UISound.isHeadlessMode {
            // One beat with the attacker's winning stat(s) flashed before the
            // captured neighbors actually flip.
            pointHighlight = (cardId: placedCard.id, statIndices: directStatIndices)

            DispatchQueue.main.asyncAfter(deadline: .now() + Self.pointHighlightDelay) { [weak self] in
                guard let self else { return }
                self.pointHighlight = nil
                self.stageCaptureCommit(capturedBoard, banner: banner, hasCapture: !attackerIds.isEmpty) {
                    self.finishPlacement(flipsCount: flips.count, excludingBoardIndex: boardIndex, completion: completion)
                }
            }
        } else {
            stageCaptureCommit(capturedBoard, banner: banner, hasCapture: !attackerIds.isEmpty) { [weak self] in
                self?.finishPlacement(flipsCount: flips.count, excludingBoardIndex: boardIndex, completion: completion)
            }
        }
    }

    // How long the announcement banner (Same/Plus/Fallen Ace/Combo, Ascension/
    // Descension, and Hive Swarm's own reveal banner) stays on screen — mostly faded —
    // before the board commit actually happens, so the moment reads as a beat that
    // pauses the game instead of the flip/pop and banner landing together. Matches the
    // banner's own fade timeline (see HoneycombView's flashRuleBannerTrigger handler):
    // 1.2s fully visible, then roughly 80% through its 0.3s fade-out.
    private static let captureBannerPauseDelay: TimeInterval = 1.44

    // Enqueues `banner` (if any) and, only when there was an actual capture
    // (`hasCapture`), holds off committing `newBoard` — i.e. the captured neighbors'
    // flip — until captureBannerPauseDelay has passed, so the banner is always what
    // the player sees first, never something landing underneath/alongside it. The
    // placed card itself already committed and popped immediately in applyPlacement,
    // before this ever runs — this only ever gates the *captured* side. A banner-less
    // move, or an Ascension/Descension-only note with no capture behind it, commits
    // `newBoard` immediately: there's nothing left to protect from the banner (for a
    // non-capturing move, `newBoard` is identical to what's already on screen anyway).
    private func stageCaptureCommit(_ newBoard: HoneycombBoard, banner: String?, hasCapture: Bool, onCommit: @escaping () -> Void) {
        guard let banner, hasCapture, !UISound.isHeadlessMode else {
            if let banner { enqueueBanner(banner) }
            board = newBoard
            // Resets whatever applyPlacement set true before this ran.
            isAnimatingPlacement = false
            onCommit()
            return
        }
        enqueueBanner(banner)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.captureBannerPauseDelay) { [weak self] in
            guard let self else { return }
            withAnimation {
                self.board = newBoard
            }
            self.isAnimatingPlacement = false
            onCommit()
        }
    }

    // Stage A (above the Bomb Shelter check below): the just-placed card's own capture —
    // its banner, sound, and (already flipped by the time this runs) board state. Stage
    // B: any *other* hidden Bomb Shelter card's 3-turn timer expiring as a side effect of
    // this same turn. Ticking it down here, after Stage A has fully committed, and
    // staggering its own board commit/flip/banner behind a short pause keeps the two
    // events visually sequential instead of landing in the same instant and stepping on
    // each other — previously both were computed into one board mutation and committed
    // together, so a reveal's own flip/banner could appear (or get silently overwritten)
    // in the exact same frame as the placed card's own capture.
    private func finishPlacement(flipsCount: Int, excludingBoardIndex: Int, completion: @escaping () -> Void) {
        sessionCardsCaptured += flipsCount
        if options.isSoundEnabled {
            UISound.play(named: "snap", enabled: true)
        }

        // Always committed immediately — a hidden card's countdown must persist every
        // turn (even when nothing reaches zero this time) or it could never actually
        // count down to a reveal.
        let pendingReveals = tickBombShelterTimers(excluding: excludingBoardIndex)

        // The common case: nothing hit zero this turn — finish immediately, exactly as
        // before this change.
        guard !pendingReveals.isEmpty else {
            checkWinCondition()
            completion()
            return
        }

        isAnimatingPlacement = true
        let revealBombShelters = { [weak self] in
            guard let self else { return }
            let (revealedBoard, banners, attackerIds) = self.revealBombShelterCards(at: pendingReveals)

            let commitReveal = { [weak self] in
                guard let self else { return }
                withAnimation {
                    self.board = revealedBoard
                }
                self.flashCaptureAttackers(attackerIds)
                if self.options.isSoundEnabled {
                    UISound.play(named: "snap", enabled: true)
                }
                self.isAnimatingPlacement = false
                self.checkWinCondition()
                completion()
            }

            // Hive Swarm's own reveal gets the same announcement pause as an
            // ordinary Same/Plus/Fallen Ace/Combo capture: banner first, then the
            // flip once it's mostly faded — rather than the flip landing instantly
            // and the banner following half a second later.
            guard !banners.isEmpty, !UISound.isHeadlessMode else {
                for banner in banners { self.enqueueBanner(banner) }
                commitReveal()
                return
            }
            for banner in banners { self.enqueueBanner(banner) }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.captureBannerPauseDelay, execute: commitReveal)
        }
        if UISound.isHeadlessMode {
            revealBombShelters()
        } else {
            // Give Stage A's own flip/banner a moment to actually be seen (its flip
            // animation alone runs ~0.4s — HoneycombCardView's onChange(of: card.owner))
            // before Stage B's board change and banner(s) land.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: revealBombShelters)
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
        clearBannerQueue()
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
    // play around, instead of a secret that's only relevant at the final score. Returns
    // one banner string per card actually revealed this call (almost always 0 or 1, but
    // never silently drops a second simultaneous reveal's banner the way a single
    // `flashRuleBanner` assignment used to). Only ticks the countdown — there's nothing
    // visible to stage about a mere decrement, so this commits straight to `board`
    // immediately rather than leaving it to the caller (a card whose timer doesn't yet
    // reach zero must still actually persist that decrement every turn, or it can never
    // count down to a reveal at all). Returns the indices (if any) whose timer just hit
    // zero — resolving *those* into an actual reveal is left to revealBombShelterCards
    // below, so the caller can stage that part's visual effects separately.
    private func tickBombShelterTimers(excluding justPlacedIndex: Int) -> [Int] {
        var pendingReveals: [Int] = []
        var updated = board
        for i in 0..<9 {
            if i == justPlacedIndex { continue }
            guard var card = updated.cells[i].card, card.isFaceDown, let remaining = card.bombShelterTurnsRemaining else { continue }

            let newRemaining = remaining - 1
            if newRemaining <= 0 {
                pendingReveals.append(i)
            } else {
                card.bombShelterTurnsRemaining = newRemaining
                updated.cells[i].card = card
            }
        }
        board = updated
        return pendingReveals
    }

    // Resolves the actual reveal (flip + capture) for cards whose Bomb Shelter timer
    // just hit zero (per tickBombShelterTimers above), returning the resulting board,
    // one banner per card revealed, and the id(s) of whichever revealed card(s) went
    // on to actually capture a neighbor (a reveal that captures nothing isn't "the
    // card doing the flipping" and shouldn't pop) — kept separate so the caller can
    // commit/animate this part on its own schedule instead of in the same instant as
    // the countdown.
    private func revealBombShelterCards(at indices: [Int]) -> (board: HoneycombBoard, banners: [String], attackerIds: Set<String>) {
        var updated = board
        var banners: [String] = []
        var attackerIds: Set<String> = []
        for i in indices {
            guard var card = updated.cells[i].card else { continue }
            let revealedOwner = card.originalOwner
            card.bombShelterTurnsRemaining = nil
            updated.cells[i].card = card
            let flips = updated.revealFaceDownCard(at: i, rules: activeRules)
            if !flips.isEmpty { attackerIds.insert(card.id) }
            banners.append([hiveSwarmRevealBanner(for: revealedOwner), Self.comboBannerText(for: updated)].compactMap { $0 }.joined(separator: " "))
        }
        return (updated, banners, attackerIds)
    }

    // Randomly chosen phrase set for a Hive Swarm (Bomb Shelter) reveal's own banner
    // — kept distinct between the player's and opponent's reveal within the same
    // match (lastHiveSwarmPhrase, reset alongside the other per-match state in
    // startNewGame/rematch) so a match where both sides reveal a hidden card doesn't
    // repeat the same phrase.
    private static let hiveSwarmRevealPhrases: [String] = [
        "Hive Stings!",
        "Swarm is Unleashed!",
        "Swarm Awakens!",
        "Hive is Buzzing into Action!"
    ]
    private var lastHiveSwarmPhrase: String?

    private func hiveSwarmRevealBanner(for owner: CardOwner) -> String {
        let pool = Self.hiveSwarmRevealPhrases.filter { $0 != lastHiveSwarmPhrase }
        let phrase = pool.randomElement() ?? Self.hiveSwarmRevealPhrases.randomElement()!
        lastHiveSwarmPhrase = phrase
        let possessive = owner == .player ? "Your" : "\(options.difficulty.displayName)'s"
        return "\(possessive) \(phrase)"
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
                if let combo = Self.comboBannerText(for: self.board) {
                    // Give the reveal's own flip a moment to actually be seen
                    // (HoneycombCardView's onChange(of: card.isFaceDown), ~0.4s) before
                    // its banner lands.
                    if UISound.isHeadlessMode {
                        self.enqueueBanner(combo)
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.enqueueBanner(combo)
                        }
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }

                if secondCell != -1 {
                    let flips = self.board.revealFaceDownCard(at: secondCell, rules: self.activeRules)
                    if !flips.isEmpty && self.options.isSoundEnabled {
                        UISound.play(named: "snap", enabled: true)
                    }
                    if let combo = Self.comboBannerText(for: self.board) {
                        if UISound.isHeadlessMode {
                            self.enqueueBanner(combo)
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                                self?.enqueueBanner(combo)
                            }
                        }
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
                applyStealProtection()
            } else if oScore > pScore {
                matchResult = "You Lose"
                gameState = .gameOver
                stats.recordGame(won: false, drawn: false, captures: sessionCardsCaptured, sessionCombos: board.sessionSamePlusTriggers, flawless: false, fallenAceCaptures: board.sessionFallenAceCaptures)
            } else if activeRules.contains(.suddenDeath) {
                matchResult = "Draw - \(HoneycombRule.suddenDeath.rawValue)!"
                gameState = .suddenDeath
                stats.recordGame(won: false, drawn: true, captures: sessionCardsCaptured, sessionCombos: board.sessionSamePlusTriggers, flawless: false, fallenAceCaptures: board.sessionFallenAceCaptures)

                // Give enough time for the final card placement and any combo animations to fully resolve
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                    self?.enqueueBanner("\(HoneycombRule.suddenDeath.rawValue)!")
                    self?.triggerSuddenDeath()
                }
                return
            } else {
                // Sudden Death isn't active for this match (Triple Triad-style: it's now
                // an opt-in Rule, not automatic on every tie) — a tie is a final result
                // like a win/loss, not a continuation.
                matchResult = "Tie!"
                gameState = .gameOver
                stats.recordGame(won: false, drawn: true, captures: sessionCardsCaptured, sessionCombos: board.sessionSamePlusTriggers, flawless: false, fallenAceCaptures: board.sessionFallenAceCaptures)
            }
            saveStats()
            // HoneycombView also holds the win/lose overlay back on its own (gated on
            // its showingRuleBanner state) until any Combo/Same/Plus/Ascension/
            // Descension banner currently on screen finishes. On top of that, match
            // Video Poker/Blackjack's own result-banner pacing (see
            // VideoPokerView/BlackjackView's _resultShowTimer, 1.5s) — a beat between
            // the result being decided and the win/lose overlay actually covering the
            // board, so the player sees the final board fully settle first. Skipped in
            // headless mode (automated testing bridge) — same reasoning as
            // playerPlayCard's opponentMoveDelay bypass, tests need this synchronous.
            if UISound.isHeadlessMode {
                showPostGamePrompt = true
            } else {
                let generation = handSetupGeneration
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self, self.handSetupGeneration == generation else { return }
                    self.showPostGamePrompt = true
                }
            }
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

    // Steal Protection: covers the case where a rematch's frozen opponent pool
    // happens to include a card that's realistically never capturable (e.g. a 5★
    // with an Ace on every side) — without this, the player could keep winning
    // against that exact opponent forever and never have a legitimate shot at
    // unlocking it. Only wins count as evidence of being stuck (a loss/draw doesn't
    // say anything about whether the opponent's deck is capturable), and only within
    // a rematch chain (isRematchMatch) — a fresh startNewGame() roll already
    // guarantees at least one unlockable card via rollOpponentDeck, so it doesn't
    // need this safety net.
    private func applyStealProtection() {
        guard isRematchMatch else { return }
        guard !hasStealableCard else {
            consecutiveNoStealWins = 0
            return
        }
        consecutiveNoStealWins += 1
        guard consecutiveNoStealWins >= 2 else { return }
        consecutiveNoStealWins = 0
        grantStealProtectionCard()
    }

    // Grants the lowest-★ not-yet-unlocked card from this specific opponent's frozen
    // rematch pool (random among ties at that tier) directly into the Card Bank — no
    // steal confirmation, since nothing was actually captured to steal. Silently does
    // nothing if every card in the pool is already unlocked (rare: only possible once
    // the player has already unlocked this opponent's whole 5-card deck some other
    // way, at which point hasStealableCard being false no longer indicates being
    // stuck, just that there's nothing left here to give).
    private func grantStealProtectionCard() {
        let candidates = rematchOpponentDeck.filter { !HoneycombProfileManager.shared.unlockedCardIds.contains($0.id) }
        guard let lowestStars = candidates.map(\.stars).min() else { return }
        guard let granted = candidates.filter({ $0.stars == lowestStars }).randomElement() else { return }
        HoneycombProfileManager.shared.unlockCard(id: granted.id)
        enqueueBanner("Steal Protection: Unlocked \(granted.name)!")
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

    // Quit Match only ever flipped gameState to .setup — the board view renders
    // viewModel.board.cells unconditionally (not gated on gameState), so the
    // just-quit match's cards stayed visibly on screen underneath the setup UI.
    // Reset to a fresh empty board so quitting actually clears it.
    //
    // Also bumps handSetupGeneration and clears isAnimatingPlacement/
    // swapHighlightCardIds — quitting mid-match can interrupt a pending Swap
    // animation (isAnimatingPlacement set true at match start, only ever cleared by
    // a generation-guarded closure ~2.9s later) or an in-flight placement animation.
    // Without this, repeatedly starting and quitting matches could catch that window
    // and leave isAnimatingPlacement stuck true — since startNewGame() doesn't
    // otherwise reset it on a match with no pending Swap of its own — permanently
    // blocking playerPlayCard on every future match.
    public func quitMatch() {
        handSetupGeneration += 1
        isAnimatingPlacement = false
        swapHighlightCardIds.removeAll()
        board = HoneycombBoard()
        gameState = .setup
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

extension HoneycombViewModel.Options: HasCommonGameOptions {
    public var commonOptions: CommonGameOptions {
        get {
            CommonGameOptions(
                isSoundEnabled: isSoundEnabled,
                noStressMode: noStressMode,
                hideHintButton: hideHintButton
            )
        }
        set {
            isSoundEnabled = newValue.isSoundEnabled
            noStressMode = newValue.noStressMode
            if let v = newValue.hideHintButton { hideHintButton = v }
        }
    }
}
