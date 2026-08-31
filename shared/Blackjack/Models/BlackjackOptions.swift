import Foundation

public struct BlackjackOptions: Codable, Equatable {
    public var startingCredits: Int = 100

    enum CodingKeys: String, CodingKey {
        case startingCredits
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startingCredits = try c.decodeIfPresent(Int.self,  forKey: .startingCredits) ?? 100
    }
}
