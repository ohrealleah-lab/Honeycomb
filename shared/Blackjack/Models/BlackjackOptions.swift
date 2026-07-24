import Foundation

public struct BlackjackOptions: Codable, Equatable {
    public var startingCredits: Int = 100
    public var isSoundEnabled: Bool = true
    public var noStressMode: Bool = false

    enum CodingKeys: String, CodingKey {
        case startingCredits, isSoundEnabled, noStressMode
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startingCredits = try c.decodeIfPresent(Int.self,  forKey: .startingCredits) ?? 100
        isSoundEnabled  = try c.decodeIfPresent(Bool.self,  forKey: .isSoundEnabled)  ?? true
        noStressMode    = try c.decodeIfPresent(Bool.self,  forKey: .noStressMode)    ?? false
    }
}
