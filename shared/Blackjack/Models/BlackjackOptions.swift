import Foundation

public struct BlackjackOptions: Codable, Equatable {
    public var startingCredits: Int = 100
    public var isSoundEnabled: Bool = true
    public var noStressMode: Bool = false
    // Driven by AppCoordinator.honeyMode (single app-wide source of truth) via
    // applySharedCommonOptionsToAllGames — never user-edited here directly.
    public var honeyMode: Bool = true

    enum CodingKeys: String, CodingKey {
        case startingCredits, isSoundEnabled, noStressMode, honeyMode
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startingCredits = try c.decodeIfPresent(Int.self,  forKey: .startingCredits) ?? 100
        isSoundEnabled  = try c.decodeIfPresent(Bool.self,  forKey: .isSoundEnabled)  ?? true
        noStressMode    = try c.decodeIfPresent(Bool.self,  forKey: .noStressMode)    ?? false
        honeyMode       = try c.decodeIfPresent(Bool.self,  forKey: .honeyMode)       ?? true
    }
}

extension BlackjackOptions: HasCommonGameOptions {
    public var commonOptions: CommonGameOptions {
        get {
            CommonGameOptions(isSoundEnabled: isSoundEnabled, noStressMode: noStressMode)
        }
        set {
            isSoundEnabled = newValue.isSoundEnabled
            noStressMode = newValue.noStressMode
        }
    }
}
