import Foundation

public enum HoneycombDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case ultraHard = "Ultra Hard"
    
    public var displayName: String {
        switch self {
        case .easy: return "Baby Bee"
        case .medium: return "Honey Bee"
        case .hard: return "Queen Bee"
        case .ultraHard: return "Killer Bee"
        }
    }
}

public enum HoneycombGameState: String, Codable, Equatable {
    case setup
    case playing
    case gameOver
    case suddenDeath
}

// Language-independent counterpart to HoneycombViewModel.matchResult (which holds the
// already-localized display string, e.g. "You Win!"/"¡Ganaste!") — gameplay logic (Take
// a Card eligibility, win-color highlighting, etc.) must branch on this instead of
// comparing matchResult against a hardcoded English literal, which silently never
// matches once the display string is translated.
public enum HoneycombMatchOutcome: Equatable {
    case none
    case win
    case loss
    case tie
    // Sudden Death triggered — not a final result, the match continues into overtime.
    case suddenDeathPending
}
