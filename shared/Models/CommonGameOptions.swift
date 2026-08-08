import Foundation

/// The subset of per-game option fields that are conceptually the same across games
/// (sound, stress mode, hint visibility, timer). Not every game has every field — a
/// `nil` here means "this game doesn't have this concept," so callers like
/// `AppCoordinator.syncSharedOptions` know to leave it untouched rather than
/// force-propagating a placeholder value. honeyMode is deliberately NOT here — like
/// isSoundEnabled/noStressMode, it's a true single-source value living on
/// AppCoordinator itself (see its own comments) and kept in sync across every game by
/// applySharedCommonOptionsToAllGames(), not by this protocol's per-outgoing-game sync.
public struct CommonGameOptions: Equatable {
    public var isSoundEnabled: Bool
    public var noStressMode: Bool
    public var hideHintButton: Bool?
    public var isTimed: Bool?

    public init(
        isSoundEnabled: Bool,
        noStressMode: Bool,
        hideHintButton: Bool? = nil,
        isTimed: Bool? = nil
    ) {
        self.isSoundEnabled = isSoundEnabled
        self.noStressMode = noStressMode
        self.hideHintButton = hideHintButton
        self.isTimed = isTimed
    }
}

/// Conformed to by every game's Options struct so shared logic (currently just
/// `AppCoordinator.syncSharedOptions`) can read/write the common fields without
/// switching on the concrete Options type. Each conformance only fills in the fields
/// that struct actually has; the setter ignores any field that arrives `nil`.
///
/// Nothing enforces getter/setter symmetry within one conformance: if a struct's getter
/// reports a field (e.g. `isTimed`) but its setter forgets to assign it back, sync would
/// silently no-op that field for that game instead of failing loudly. When adding or
/// copy-pasting a conformance, double-check every field the getter returns is also
/// written by the setter.
public protocol HasCommonGameOptions {
    var commonOptions: CommonGameOptions { get set }
}
