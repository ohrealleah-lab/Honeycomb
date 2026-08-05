import Foundation

public enum HoneycombRule: String, Codable, CaseIterable {
    case ascension = "Pollination"
    case descension = "Smoked Out"
    case same = "Symmetry"
    case plus = "Hive Math"
    case fallenAce = "Queen's Fall"
    case reverse = "Inversion"
    case allOpen = "Clear Skies"
    case threeOpen = "Scouting Party"
    case swap = "Nectar Exchange"
    case order = "Hierarchy"
    case chaos = "Frenzy"
    case bombShelter = "Hive Swarm"
    case suddenDeath = "Swarm to the Death"

    // Roulette draw weight — approximates real Triple Triad (FFXIV) NPC rule
    // frequencies so combo-enabling rules (Same/Plus) come up often and
    // restrictive ones (Reverse/Order/Descension) stay rare, instead of every
    // rule having an equal ~8.3% shot. Bomb Shelter has no FFXIV equivalent —
    // tiered as Medium alongside the other moderate-impact rules. Sudden Death
    // is FFXIV's rarest rule (2.2%) but is deliberately weighted High here — a
    // product decision, not a data-fidelity call, now that it's opt-in rather
    // than automatic.
    public var weight: Int {
        switch self {
        case .plus, .same, .suddenDeath:
            return 30
        case .swap, .chaos, .threeOpen, .bombShelter:
            return 15
        case .ascension, .allOpen, .fallenAce:
            return 8
        case .descension, .reverse, .order:
            return 3
        }
    }
}

extension HoneycombRule {
    public func explanation(activeSuits: Set<String> = []) -> String {
        switch self {
        case .same:
            return "If 2+ touching neighbor stats match your card's facing stats, all matching neighbors are captured simultaneously."
        case .plus:
            return "If the sum of (your stat + neighbor's stat) equals the same total across 2+ neighbors, all involved cards are captured."
        case .fallenAce:
            return "A card with a stat of 1 attacking a 10 (\"A\") always captures it!"
        case .reverse:
            return "Inverts all comparisons—lower stats beat higher stats."
        case .ascension:
            if activeSuits.isEmpty {
                return "Grants +1 to stats for all cards matching randomly selected suits as more of that suit enter the board."
            } else {
                let suitNames = activeSuits.sorted().map { HoneycombCardData.suitDisplayName($0) }.joined(separator: " and ")
                return "Grants +1 to stats for all \(suitNames) cards as more of that suit enter the board."
            }
        case .descension:
            if activeSuits.isEmpty {
                return "Inflicts -1 to stats for all cards matching randomly selected suits as more of that suit enter the board."
            } else {
                let suitNames = activeSuits.sorted().map { HoneycombCardData.suitDisplayName($0) }.joined(separator: " and ")
                return "Inflicts -1 to stats for all \(suitNames) cards as more of that suit enter the board."
            }
        case .order:
            return "Forces you to play cards in exact deck sequence."
        case .chaos:
            return "Randomly mandates which card must be played each turn."
        case .allOpen:
            return "Both players' hands are completely visible."
        case .threeOpen:
            return "Three randomly selected cards from each player's hand are visible."
        case .bombShelter:
            return "First card played remains face-down for 3 turns before flipping automatically."
        case .suddenDeath:
            return "If the match ends in a draw, a rematch begins immediately."
        case .swap:
            return "Before the match, one card from your hand is randomly swapped with one of the opponent's."
        }
    }
}

public struct HoneycombCell: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var card: HoneycombCard?
}

public struct HoneycombBoard: Codable, Equatable {
    public var cells: [HoneycombCell]
    public let rows = 3
    public let cols = 3
    public var sessionSamePlusTriggers: Int = 0
    // Running total, for the whole match, of captures where a printed "1" edge topples
    // a printed "10" (Ace) edge, OR the capture was specifically authorized by the
    // Fallen Ace house rule exception (which compares effective, modifier-adjusted
    // stats) — either counts, since Ascension/Descension can move the effective stats
    // away from (or into) 1/10 relative to what's actually printed on the cards.
    public var sessionFallenAceCaptures: Int = 0
    // Whether the Same/Plus rule actually fired on the most recent placeCard call —
    // unlike Ascension/Descension (an always-on modifier each turn), Same/Plus only
    // matter on the turns they actually match, so callers use these to flash a
    // "Same!"/"Plus!" banner only when something really happened.
    public private(set) var lastSameTriggered = false
    public private(set) var lastPlusTriggered = false
    // Whether the Fallen Ace rule's own capture exception (Ace topples a 10, or the
    // reverse under the Reverse rule) is what won a capture on the most recent
    // placeCard call — same "only flash when something really happened" purpose as
    // lastSameTriggered/lastPlusTriggered above.
    public private(set) var lastFallenAceTriggered = false
    // Count of cards flipped specifically by the Same/Plus combo chain reaction (a
    // captured card going on to capture its own neighbors), as opposed to the cards
    // flipped directly by the placed card itself. A plain move that happens to flip 2
    // ordinary neighbors via normal higher/lower-stat captures is not a combo — real
    // Triple Triad's "Combo" is specifically this chain-reaction case, so callers
    // should gate a "COMBO!" banner on this being > 0, not on total flip count.
    public private(set) var lastComboFlipCount = 0
    // The 2 suits Ascension/Descension actually affects this match (rolled once by
    // HoneycombViewModel when the rule is chosen, carried unchanged into every board
    // this match creates, including Sudden Death's fresh board and every board
    // HoneycombAI simulates — it's just a plain value on this struct, so copies get it
    // for free without threading a new parameter through the AI's recursive search).
    // A card whose suit isn't in this set plays as normal, unaffected by the rule.
    public var ascensionDescensionSuits: Set<String> = []

    // rows/cols are always 3 and aren't part of persisted state.
    private enum CodingKeys: String, CodingKey {
        case cells, sessionSamePlusTriggers, lastSameTriggered, lastPlusTriggered
        case lastFallenAceTriggered, lastComboFlipCount, ascensionDescensionSuits
        case sessionFallenAceCaptures
    }

    public init() {
        self.cells = (0..<9).map { _ in HoneycombCell(card: nil) }
    }

    public mutating func placeCard(_ card: HoneycombCard, at index: Int, rules: [HoneycombRule], skipCaptures: Bool = false) -> [Int] {
        guard index >= 0 && index < cells.count, cells[index].card == nil else { return [] }

        cells[index].card = card
        lastSameTriggered = false
        lastPlusTriggered = false
        lastFallenAceTriggered = false
        lastComboFlipCount = 0

        // Recompute Ascension/Descension modifiers BEFORE resolving captures — the
        // newly placed card immediately benefits (or suffers) from the current suit
        // count, including the card it's about to fight with.
        updateModifiers(rules: rules)
        
        if skipCaptures { return [] }
        
        let flips = resolveCaptures(at: index, rules: rules, isCombo: false)

        return flips
    }
    
    // A flipped Hive Swarm card is treated exactly like a card just placed from
    // hand: it recomputes Ascension/Descension modifiers first (so it immediately
    // inherits whatever suit count built up while it sat hidden — its own
    // suitCount() exclusion no longer applies now that isFaceDown is false), then
    // runs the same full capture resolution as placeCard (Same/Plus/Fallen Ace,
    // combo cascades included) — no special-cased rule stripping.
    public mutating func revealFaceDownCard(at index: Int, rules: [HoneycombRule]) -> [Int] {
        guard index >= 0 && index < cells.count, let card = cells[index].card, card.isFaceDown else { return [] }

        cells[index].card!.isFaceDown = false

        lastSameTriggered = false
        lastPlusTriggered = false
        lastFallenAceTriggered = false
        lastComboFlipCount = 0

        updateModifiers(rules: rules)

        return resolveCaptures(at: index, rules: rules, isCombo: false)
    }
    
    // Face-down Hive Swarm cards are excluded — they exist in total isolation until
    // they flip, so they neither reveal their suit nor contribute to Pollination/
    // Smoked Out counts for other cards while hidden.
    private func suitCount(suit: String) -> Int {
        return cells.compactMap { $0.card }.filter { !$0.isFaceDown && $0.data.suit == suit }.count
    }

    private mutating func updateModifiers(rules: [HoneycombRule]) {
        for i in 0..<cells.count {
            guard var card = cells[i].card else { continue }
            card.modifier = 0
            // A face-down card stays untouched by suit modifiers until it flips —
            // its modifier is never rendered while hidden, but leaving it at 0 (and
            // never reading its own count into other cards' totals via suitCount)
            // keeps it in true isolation rather than a merely-invisible-but-live state.
            if card.isFaceDown {
                cells[i].card = card
                continue
            }
            // Only the 2 chosen suits are affected — a card of any other suit plays as
            // normal (modifier stays 0), giving the rolled suits distinct "flavor" for
            // the match instead of a blanket effect across every card.
            if ascensionDescensionSuits.contains(card.data.suit) {
                if rules.contains(.ascension) {
                    card.modifier = suitCount(suit: card.data.suit)
                } else if rules.contains(.descension) {
                    card.modifier = -suitCount(suit: card.data.suit)
                }
            }
            cells[i].card = card
        }
    }
    
    private mutating func resolveCaptures(at index: Int, rules: [HoneycombRule], isCombo: Bool) -> [Int] {
        guard let attacker = cells[index].card else { return [] }
        let row = index / cols
        let col = index % cols
        var flippedIndices: [Int] = []
        var comboQueue: [Int] = []
        
        let reverse = rules.contains(.reverse)
        let fallenAce = rules.contains(.fallenAce)
        
        // Fallen Ace's own exception, isolated so a capture that wins specifically
        // through it (as opposed to the normal higher/lower-stat comparison) can be
        // flagged for the rule banner below.
        func isFallenAceWin(aStat: Int, tStat: Int) -> Bool {
            guard fallenAce else { return false }
            if !reverse && aStat == 1 && tStat == 10 { return true }
            if reverse && aStat == 10 && tStat == 1 { return true }
            return false
        }

        // The mirror-image pairing Fallen Ace disallows outright — a 1-vs-10 matchup
        // is a strict, one-directional exception (1 always beats 10; under Reverse, 10
        // always beats 1), not "whoever attacks wins." Without this, the ordinary
        // higher/lower-stat comparison below would still grant the losing side its
        // normal win (10 > 1, or under Reverse 1 < 10), undermining the exception.
        func isFallenAceBlockedLoss(aStat: Int, tStat: Int) -> Bool {
            guard fallenAce else { return false }
            if !reverse && aStat == 10 && tStat == 1 { return true }
            if reverse && aStat == 1 && tStat == 10 { return true }
            return false
        }

        func canCapture(aStat: Int, tStat: Int) -> Bool {
            if isFallenAceWin(aStat: aStat, tStat: tStat) { return true }
            if isFallenAceBlockedLoss(aStat: aStat, tStat: tStat) { return false }
            if reverse {
                return aStat < tStat
            } else {
                return aStat > tStat
            }
        }
        
        var neighbors: [(dir: Int, idx: Int, aStat: Int, tStat: Int, enemy: Bool)] = []
        
        if row > 0 { // Top
            let tIdx = index - cols
            if let tCard = cells[tIdx].card, !tCard.isFaceDown {
                neighbors.append((0, tIdx, attacker.stat(at: 0), tCard.stat(at: 2), tCard.owner != attacker.owner))
            }
        }
        if col < cols - 1 { // Right
            let tIdx = index + 1
            if let tCard = cells[tIdx].card, !tCard.isFaceDown {
                neighbors.append((1, tIdx, attacker.stat(at: 1), tCard.stat(at: 3), tCard.owner != attacker.owner))
            }
        }
        if row < rows - 1 { // Bottom
            let tIdx = index + cols
            if let tCard = cells[tIdx].card, !tCard.isFaceDown {
                neighbors.append((2, tIdx, attacker.stat(at: 2), tCard.stat(at: 0), tCard.owner != attacker.owner))
            }
        }
        if col > 0 { // Left
            let tIdx = index - 1
            if let tCard = cells[tIdx].card, !tCard.isFaceDown {
                neighbors.append((3, tIdx, attacker.stat(at: 3), tCard.stat(at: 1), tCard.owner != attacker.owner))
            }
        }
        
        // Same & Plus (Only if not a combo iteration)
        if !isCombo {
            var sameMatches: [Int] = []
            var plusSums: [Int: [Int]] = [:]
            
            for n in neighbors {
                if rules.contains(.same) {
                    if n.aStat == n.tStat {
                        sameMatches.append(n.idx)
                    }
                }
                if rules.contains(.plus) {
                    let sum = n.aStat + n.tStat
                    plusSums[sum, default: []].append(n.idx)
                }
            }
            
            // A stat match against a side is only a real "Same!"/"Plus!" event if it
            // actually captures something — matching 2+ sides where every matched
            // neighbor already belongs to the attacker (e.g. placed between two of
            // your own cards) shouldn't flash the banner or count toward the session
            // total, since nothing actually flipped.
            var triggers: Set<Int> = []
            var sameActuallyFlips = false
            if sameMatches.count >= 2 {
                for idx in sameMatches { triggers.insert(idx) }
                sameActuallyFlips = sameMatches.contains { cells[$0].card?.owner != attacker.owner }
            }
            var plusActuallyFlips = false
            for (_, indices) in plusSums {
                if indices.count >= 2 {
                    for idx in indices { triggers.insert(idx) }
                    if indices.contains(where: { cells[$0].card?.owner != attacker.owner }) {
                        plusActuallyFlips = true
                    }
                }
            }
            lastSameTriggered = sameActuallyFlips
            lastPlusTriggered = plusActuallyFlips

            if sameActuallyFlips || plusActuallyFlips {
                sessionSamePlusTriggers += 1
            }

            for idx in triggers {
                if cells[idx].card?.owner != attacker.owner {
                    cells[idx].card?.owner = attacker.owner
                    flippedIndices.append(idx)
                    comboQueue.append(idx)
                }
            }
        }
        
        // Normal captures
        for n in neighbors {
            if n.enemy && !flippedIndices.contains(n.idx) {
                if canCapture(aStat: n.aStat, tStat: n.tStat) {
                    let viaFallenAceRule = isFallenAceWin(aStat: n.aStat, tStat: n.tStat)
                    if viaFallenAceRule {
                        lastFallenAceTriggered = true
                    }
                    // Fallen Ace stat: printed/base 1-vs-10 on the capturing edge, OR the
                    // capture actually went through via the Fallen Ace rule exception
                    // (effective stats) — either way counts, even if Ascension/Descension
                    // moved the effective stats away from (or into) 1/10 relative to the
                    // printed values.
                    let baseAStat = attacker.data.stats[n.dir]
                    let baseTStat = cells[n.idx].card!.data.stats[(n.dir + 2) % 4]
                    if (baseAStat == 1 && baseTStat == 10) || viaFallenAceRule {
                        sessionFallenAceCaptures += 1
                    }
                    cells[n.idx].card?.owner = attacker.owner
                    flippedIndices.append(n.idx)
                    // Once inside a combo chain (isCombo), every further capture keeps
                    // the chain cascading — a plain top-level capture (isCombo == false)
                    // never starts a combo on its own; only Same/Plus can. Counted here,
                    // at the point of capture, so a multi-level cascade is counted
                    // exactly once per flipped card (not once per recursion level).
                    if isCombo {
                        comboQueue.append(n.idx)
                        lastComboFlipCount += 1
                    }
                }
            }
        }

        // Process Combo Queue — recurses until no card captured by the chain has any
        // further captures of its own left to make.
        for comboIdx in comboQueue {
            let comboFlips = resolveCaptures(at: comboIdx, rules: rules, isCombo: true)
            flippedIndices.append(contentsOf: comboFlips)
        }
        
        return flippedIndices
    }
    
    public var isFull: Bool {
        return !cells.contains { $0.card == nil }
    }
    
    public var playerScore: Int {
        return cells.filter { $0.card?.owner == .player }.count
    }
    
    public var opponentScore: Int {
        return cells.filter { $0.card?.owner == .opponent }.count
    }
}
