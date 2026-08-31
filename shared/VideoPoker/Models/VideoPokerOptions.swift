import Foundation

public enum VideoPokerVariant: String, Codable, CaseIterable, Equatable {
    case jacksOrBetter = "Jacks or Better"
    case deucesWild    = "Deuces Wild"
    case bonusPoker    = "Bonus Poker"
}

public enum VideoPokerPlayMode: String, Codable, CaseIterable, Equatable {
    case single = "Single Play"
    case triple = "Triple Play"

    // Triple Play is hidden from the UI for now (still under polish). Flip this back to
    // true to re-expose the Options picker and stop forcing saved state back to single.
    public static let tripleEnabled = false
}

public struct VideoPokerOptions: Codable, Equatable {
    public var variant: VideoPokerVariant = .jacksOrBetter
    public var playMode: VideoPokerPlayMode = .single
    public var startingCredits: Int = 100
    public var betPerHand: Int = 1          // 1–5 coins

    enum CodingKeys: String, CodingKey {
        case variant, playMode, startingCredits, betPerHand
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        variant        = try c.decodeIfPresent(VideoPokerVariant.self, forKey: .variant) ?? .jacksOrBetter
        playMode       = try c.decodeIfPresent(VideoPokerPlayMode.self, forKey: .playMode) ?? .single
        startingCredits = try c.decodeIfPresent(Int.self, forKey: .startingCredits) ?? 100
        betPerHand     = try c.decodeIfPresent(Int.self, forKey: .betPerHand) ?? 1
    }
}
