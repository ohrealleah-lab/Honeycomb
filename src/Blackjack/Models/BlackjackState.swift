import Foundation

public enum BlackjackPhase: Equatable {
    case betting
    case playing
    case dealerTurn
    case result
}

public enum BlackjackHandResult: Equatable {
    case win
    case loss
    case push
    case blackjack
    case bust
}

public struct BlackjackHand: Equatable {
    public var cards: [Card]
    public var bet: Int
    public var isDoubled: Bool = false
    public var isSplitAce: Bool = false
    public var result: BlackjackHandResult? = nil

    public init(cards: [Card], bet: Int) {
        self.cards = cards
        self.bet = bet
    }

    public var value: Int { BlackjackState.handValue(cards) }
    public var isBust: Bool { value > 21 }
    public var isBlackjack: Bool { cards.count == 2 && value == 21 }
}

public struct BlackjackState: Equatable {
    public var phase: BlackjackPhase = .betting
    public var playerHands: [BlackjackHand] = []
    public var activeHandIndex: Int = 0
    public var dealerCards: [Card] = []
    public var deck: [Card] = []
    public var sessionCredits: Int = 100
    public var currentBet: Int = 1
    public var handsDealt: Int = 0
    public var lastResultSummary: String = ""
    public var lastNetResult: Int = 0
    public var dealerValue: Int { BlackjackState.handValue(dealerCards) }
    public var dealerVisibleValue: Int {
        // Only count face-up cards during playing phase
        let visible = dealerCards.filter { $0.faceUp }
        return BlackjackState.handValue(visible)
    }

    // Compute best blackjack hand value (aces as 11 or 1)
    public static func handValue(_ cards: [Card]) -> Int {
        var total = 0
        var aces = 0
        for card in cards where card.faceUp {
            let r = card.rank
            if r == 1 { aces += 1; total += 11 }
            else if r >= 10 { total += 10 }
            else { total += r }
        }
        while total > 21 && aces > 0 { total -= 10; aces -= 1 }
        return total
    }
}
