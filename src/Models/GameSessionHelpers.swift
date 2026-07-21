import Foundation

// Shared 1-second repeating timer used by every game's ViewModel to drive `state.timerSeconds`.
// The ViewModel still owns `state.isTimerActive`/`state.timerSeconds` (they're part of each
// game's persisted/undoable state); this just wraps the Timer scheduling that was previously
// copy-pasted identically into GameViewModel, BeecellViewModel, and SpiderViewModel.
final class GameTimer {
    private var timer: Timer?

    func start(isActive: () -> Bool, setActive: (Bool) -> Void, tick: @escaping () -> Void) {
        guard !isActive() else { return }
        setActive(true)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in tick() }
    }

    func stop(setActive: (Bool) -> Void) {
        timer?.invalidate()
        timer = nil
        setActive(false)
    }
}

// Bounded undo history shared by every game's ViewModel — caps at `capacity` snapshots,
// dropping the oldest once full.
struct UndoStack<State> {
    private var stack: [State] = []
    private let capacity: Int

    init(capacity: Int = 100) {
        self.capacity = capacity
    }

    var isEmpty: Bool { stack.isEmpty }

    mutating func push(_ state: State) {
        stack.append(state)
        if stack.count > capacity {
            stack.removeFirst()
        }
    }

    mutating func pop() -> State? {
        stack.isEmpty ? nil : stack.removeLast()
    }

    mutating func removeAll() {
        stack.removeAll()
    }
}

// Smart Drop Detection: when a player drags a stack, the tapped card might not be the one
// they meant to grab (e.g. grabbing a 10♠ sitting just above the 9♥ they actually wanted).
// Rather than rejecting the whole drop, this finds the longest suffix of the dragged stack —
// trimming cards off the grabbed end, never the bottom — that is a legal move onto the
// target. Trimmed leading cards are simply left behind in the source pile (never removed),
// so nothing needs to visually "snap back": the drag overlay resets and the untouched cards
// are exactly where they always were.
enum SmartDrop {
    static func resolve(cards: [Card], isValidMove: ([Card]) -> Bool) -> [Card]? {
        guard !cards.isEmpty else { return nil }
        for start in 0..<cards.count {
            let suffix = Array(cards[start...])
            if isValidMove(suffix) {
                return suffix
            }
        }
        return nil
    }
}

// Shared win-condition check: the foundation pile count reaching the target total, and the
// game not already marked won. Each ViewModel still owns its own win-completion side effects
// (stopTimer/recordWin/playSound/score adjustments) since those differ per game.
enum WinDetection {
    static func hasWon(foundationCardCount: Int, totalCards: Int, alreadyWon: Bool) -> Bool {
        foundationCardCount == totalCards && !alreadyWon
    }
}
