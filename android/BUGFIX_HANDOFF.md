# SoliBee Android Port — Bug Fix Handoff

## Project Context
Android port audit across all 6 games (Klondike, Spider, Beecell, Blackjack, Video Poker, Honeycomb). This document mirrors the structure of the Windows `BUGFIX_HANDOFF.md` and records findings from the Phase 7 cross-game structural audit.

## Bugs / Audit Findings

### 1. `Undo()` deadlock status recomputation (Klondike, Spider, Beecell)
**Finding:** None found. Checked explicitly. 
**Details:** In the Windows port, `Undo()` failed to call `CheckDeadlock()` resulting in UI bugs when undoing into a stuck state. In the Android port, `GameViewModel.kt`, `SpiderViewModel.kt`, and `BeecellViewModel.kt` all successfully call `checkStuckState()` at the end of `undoLastAction()`. No fix required.

### 2. Undoing past a win leaves stats inflated (Spider)
**Finding:** None found. Checked explicitly.
**Details:** The Android port's `undoLastAction()` implementations in Spider and Beecell start with `if (_state.value.hasWon) return`. Undo is correctly disabled once the game is won, preventing stat inflation.

### 3. Vegas-scoring baseline inconsistent (Klondike "New Game" vs "Restart")
**Finding:** None found. Checked explicitly.
**Details:** `startNewGame()` and `restartCurrentGame()` in Klondike's `GameViewModel.kt` consistently handle the base `-5200` offset for Vegas scoring without bleeding the score arbitrarily between games. 

### 4. Timer threading synchronization
**Finding:** None found. Checked explicitly.
**Details:** The timer uses Kotlin Coroutines and `MutableStateFlow.update { }`, which guarantees atomic read-modify-write operations on the `timerSeconds` state. It does not suffer from the `System.Threading.Timer` background thread races seen in the Avalonia Windows port.

### 5. Blackjack `DrawCard()` bounds check
**Finding:** None found. Checked explicitly.
**Details:** Blackjack's `popCard()` method has an explicit `if (s.deck.isEmpty()) return null` check preventing `IndexOutOfBoundsException`, which gracefully returns `null` if the deck is empty.

### 6. Honeycomb "New Match" vs "Rematch" Math
**Finding:** Found issue.
**Details:** `consecutiveNoStealWins` and `stealProtectionActive` fields in `HoneycombViewModel.kt` were omitted from the Android port during translation, meaning this divergent-reset-math pattern is absent. The only tracked reset variables (`isRematchMatch` and `hasStolenThisMatch`) are correctly reset in both `startNewGame()` and `rematch()`.

### 7. Hardcoded UI Strings (Localization)
**Finding:** Found hardcoded strings across Compose views.
**Details:** Grepping for `Text("` across the codebase reveals that Compose Views (e.g. `MainActivity.kt`, `KlondikeBoard.kt`, `HoneycombMatchUI.kt`) extensively use hardcoded strings instead of routing through `Strings.get(StringKey.*, language)`. The generated `Strings.kt` table exists, but the UI is not fully connected to it. A mechanical pass is needed to route all `Text("...")` calls through `Strings.get(StringKey.*, appLanguage)`.

## Conclusion
The core logical bugs from the Windows port were inherently avoided in the Android port due to differences in state management (StateFlow vs INotifyPropertyChanged), null-safety, and explicit early returns added during earlier phases. The remaining technical debt is purely localized strings in Compose Views.
