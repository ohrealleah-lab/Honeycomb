import Foundation

public enum HoneycombRule: String, Codable, CaseIterable {
    case ascension = "Ascension"
    case descension = "Descension"
    case same = "Same"
    case plus = "Plus"
    case fallenAce = "Fallen Ace"
    case reverse = "Reverse"
    case allOpen = "All Open"
    case threeOpen = "Three Open"
    case swap = "Swap"
    case order = "Order"
    case chaos = "Chaos"
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
    // Whether the Same/Plus rule actually fired on the most recent placeCard call —
    // unlike Ascension/Descension (an always-on modifier each turn), Same/Plus only
    // matter on the turns they actually match, so callers use these to flash a
    // "Same!"/"Plus!" banner only when something really happened.
    public private(set) var lastSameTriggered = false
    public private(set) var lastPlusTriggered = false

    public init() {
        self.cells = (0..<9).map { _ in HoneycombCell(card: nil) }
    }

    public mutating func placeCard(_ card: HoneycombCard, at index: Int, rules: [HoneycombRule]) -> [Int] {
        guard index >= 0 && index < cells.count, cells[index].card == nil else { return [] }

        cells[index].card = card
        lastSameTriggered = false
        lastPlusTriggered = false

        // Recompute Ascension/Descension modifiers BEFORE resolving captures — the
        // newly placed card immediately benefits (or suffers) from the current suit
        // count, including the card it's about to fight with.
        updateModifiers(rules: rules)
        let flips = resolveCaptures(at: index, rules: rules, isCombo: false)

        return flips
    }
    
    private func suitCount(suit: String) -> Int {
        return cells.compactMap { $0.card }.filter { $0.data.suit == suit }.count
    }
    
    private mutating func updateModifiers(rules: [HoneycombRule]) {
        for i in 0..<cells.count {
            guard var card = cells[i].card else { continue }
            card.modifier = 0
            if rules.contains(.ascension) {
                card.modifier = suitCount(suit: card.data.suit)
            } else if rules.contains(.descension) {
                card.modifier = -suitCount(suit: card.data.suit)
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
        
        func canCapture(aStat: Int, tStat: Int) -> Bool {
            if fallenAce {
                if !reverse && aStat == 1 && tStat == 10 { return true }
                if reverse && aStat == 10 && tStat == 1 { return true }
            }
            if reverse {
                return aStat < tStat
            } else {
                return aStat > tStat
            }
        }
        
        var neighbors: [(dir: Int, idx: Int, aStat: Int, tStat: Int, enemy: Bool)] = []
        
        if row > 0 { // Top
            let tIdx = index - cols
            if let tCard = cells[tIdx].card {
                neighbors.append((0, tIdx, attacker.stat(at: 0), tCard.stat(at: 2), tCard.owner != attacker.owner))
            }
        }
        if col < cols - 1 { // Right
            let tIdx = index + 1
            if let tCard = cells[tIdx].card {
                neighbors.append((1, tIdx, attacker.stat(at: 1), tCard.stat(at: 3), tCard.owner != attacker.owner))
            }
        }
        if row < rows - 1 { // Bottom
            let tIdx = index + cols
            if let tCard = cells[tIdx].card {
                neighbors.append((2, tIdx, attacker.stat(at: 2), tCard.stat(at: 0), tCard.owner != attacker.owner))
            }
        }
        if col > 0 { // Left
            let tIdx = index - 1
            if let tCard = cells[tIdx].card {
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
            
            var triggers: Set<Int> = []
            if sameMatches.count >= 2 {
                lastSameTriggered = true
                for idx in sameMatches { triggers.insert(idx) }
            }
            for (_, indices) in plusSums {
                if indices.count >= 2 {
                    lastPlusTriggered = true
                    for idx in indices { triggers.insert(idx) }
                }
            }
            
            if !triggers.isEmpty {
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
                    cells[n.idx].card?.owner = attacker.owner
                    flippedIndices.append(n.idx)
                }
            }
        }
        
        // Process Combo Queue
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
