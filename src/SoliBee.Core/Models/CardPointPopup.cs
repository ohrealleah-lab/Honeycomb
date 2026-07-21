namespace SoliBee.Core.Models;

// Point Highlights: a transient "+N"/"-N" (or "+$5"/"-$5" in Vegas mode) popup flashed
// over the specific card responsible for a score change. Each solitaire ViewModel
// (Klondike/Freecell/Spider) holds at most one of these as plain transient UI state —
// not part of GameState/undo snapshots, same category as an "autoplay running" flag.
public record CardPointPopup(string CardId, string DisplayText);
