import Foundation

// Referenced by every game's ViewModel (`debugBannerRequest`), so it lives in shared/
// rather than with the mac-only debug menu UI that fires it.
public enum DebugBannerKind {
    case win, loss, stuck, autocomplete
    case same, plus, suddenDeath
}
