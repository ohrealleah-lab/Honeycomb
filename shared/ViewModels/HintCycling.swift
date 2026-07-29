import Foundation

// Shared "cycle through a queue of hints, or generate a fresh one, then auto-dismiss"
// logic used identically by Klondike, Beecell, and Spider's `findHint()` (only the
// Move type, collectHints()/labeled() implementations, and no-hint fallback text
// differ per game). Honeycomb's hint system computes asynchronously and doesn't cycle
// through a queue, so it isn't a fit for this and keeps its own implementation.
enum HintCycling {
    static func findHint<Move>(
        activeHint: inout Move?,
        hintQueue: inout [Move],
        hintQueueIndex: inout Int,
        collectHints: () -> [Move],
        label: (_ hint: Move, _ index: Int, _ total: Int) -> Move,
        noHintFallback: () -> Move,
        scheduleClear: () -> Void
    ) {
        // Cycle through the existing queue if a hint is still visible.
        if !hintQueue.isEmpty && activeHint != nil {
            hintQueueIndex = (hintQueueIndex + 1) % hintQueue.count
            activeHint = label(hintQueue[hintQueueIndex], hintQueueIndex, hintQueue.count)
            scheduleClear()
            return
        }

        hintQueue = collectHints()
        hintQueueIndex = 0

        guard !hintQueue.isEmpty else {
            activeHint = noHintFallback()
            scheduleClear()
            return
        }

        activeHint = label(hintQueue[0], 0, hintQueue.count)
        scheduleClear()
    }
}
