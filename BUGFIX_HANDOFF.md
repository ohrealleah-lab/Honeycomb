# SoliBee — Bug Fix Handoff

## Project context
SoliBee is an Avalonia UI 11.0.10 / .NET 8 desktop card-game suite (Klondike, Freecell, Spider Solitaire, Video Poker, Blackjack), originally ported from a Mac codebase. Working branch: `004-windows-port`.

Solution layout:
- `src/SoliBee.Core/ViewModels/` — game logic (MVVM, `CommunityToolkit.Mvvm`). One ViewModel per game: `GameViewModel` (Klondike), `FreecellViewModel`, `SpiderViewModel`, `VideoPokerViewModel`, `BlackjackViewModel`.
- `src/SoliBee.Core/Models/` — `Card`, `Pile`, `GameState`, `GameOptions`, etc.
- `src/SoliBee.Desktop/Views/` — Avalonia views + code-behind (not in scope for this handoff; all bugs below are in `SoliBee.Core`).

A full codebase bug review was just completed (manual read of `FreecellViewModel.cs` + two parallel subagent reviews of `GameViewModel`/`VideoPokerViewModel` and `BlackjackViewModel`/`SpiderViewModel`). The five bugs below are confirmed — not speculative — each was traced to an exact file/line and the root cause is understood. None require architectural changes; all are small, scoped fixes within existing methods.

## Bugs to fix

### 1. `Undo()` never recomputes deadlock status (Klondike, Spider, Freecell)
**Files:** `GameViewModel.cs:526`, `SpiderViewModel.cs:598`, `FreecellViewModel.cs:583`

Every state-changing method in these ViewModels follows the pattern `CheckVictory(); CheckAutocomplete(); CheckDeadlock();` after mutating piles — except `Undo()`, which sets `HasNoMoves = false;` directly instead of calling `CheckDeadlock()`. Result: if a player undoes into a position that's genuinely stuck (no legal moves), the "no moves" banner stays hidden until they attempt and fail another move.

**Fix:** in all three `Undo()` methods, replace the line `HasNoMoves = false;` with a call to `CheckDeadlock();` (same as the pattern used elsewhere in each file).

### 2. Spider: undoing past a win leaves stats permanently inflated
**File:** `SpiderViewModel.cs` (`CheckVictory()` ~line 368-390, `Undo()` ~line 592-606, `RestoreSnapshot()` ~line 632)

`CheckVictory()` persists `GamesWon++`, `CurrentStreak++`, `HighScore`, `ShortestWinSeconds` to disk immediately on detecting a win. `Undo()` can roll back past that win — `RestoreSnapshot()` forces `State.HasWon = false` — but never reverts the already-saved stats. A player can win, hit undo, and keep the inflated win/streak count permanently.

**Fix:**  simply disallow `Undo()` once `State.HasWon` has been true for the current game (clear/disable the undo stack on win). No game should allow Undo once win has begun.

### 3. Vegas-scoring baseline inconsistent between New Game and Restart (Klondike)
**File:** `GameViewModel.cs` — `InitializeGame()` vs `RestartGame()`

`InitializeGame()` computes the Vegas starting score as `State.Score - 5200` — i.e. it carries forward whatever score was left over from the *previous* game. `RestartGame()` instead uses a flat `-5200`. Both are "start a fresh round" entry points and should behave identically, but currently New Game lets score bleed across games while Restart doesn't.

**Fix:** make `InitializeGame()` use the same flat `-5200` (or `-5200 * Options.FreecellDeckCount`-style multiplier if applicable) that `RestartGame()` uses, so both paths are consistent.

### 4. Game timer mutates `State.TimerSeconds` from a background thread without synchronization
**File:** `GameViewModel.cs` (and structurally identical timer code in `FreecellViewModel.cs` / `SpiderViewModel.cs`)

Each ViewModel owns a `System.Threading.Timer` whose callback runs on a thread-pool thread and does `State.TimerSeconds++` directly. Only the resulting `OnPropertyChanged` notification is marshaled back to the UI thread via `_syncContext.Post(...)` — the actual read-modify-write of `TimerSeconds` is unsynchronized and can race with UI-thread writes to the same field (e.g. `Undo()` restoring `TimerSeconds` from a snapshot, or `RestartGame()` resetting it to 0).

**Fix:** wrap the increment in a `lock` (using a shared lock object per ViewModel instance), or move the entire `if (...) State.TimerSeconds++;` block inside the `_syncContext.Post(...)` callback so it always executes on the UI thread.

### 5. Blackjack: `DrawCard()` has no bounds check on the deck index
**File:** `BlackjackViewModel.cs:379-383`

```csharp
private Card DrawCard(bool faceUp)
{
    var card = _deck[_deckIdx++];
    return card with { IsFaceUp = faceUp };
}
```
`_deckIdx` is never checked against `_deck.Count`. Currently safe by arithmetic (single 52-card deck, current split rules can't exceed it), but there's zero defensive guard — any future rule change (e.g. resplitting) or an unrelated bug that double-draws would throw an unhandled `IndexOutOfRangeException` and crash the app instead of degrading gracefully.

**Fix:** add a guard at the top of `DrawCard()`: if `_deckIdx >= _deck.Count`, either reshuffle a fresh deck and reset `_deckIdx = 0`, or throw a clearly-named, handled exception so the caller can recover (e.g. abort the round) instead of an unhandled crash.

## Not in scope / explicitly ruled out
During review we also checked and **confirmed correct** (no fix needed): Klondike's `CheckAutocomplete()` (loose "no face-down cards" check is mathematically sound for Klondike specifically), Freecell's autocomplete (already fixed earlier in this session — see `FreecellViewModel.cs` `SimulateAutocomplete()`), Spider's autocomplete (correctly dry-run simulated), and the wild-card poker hand evaluator in `PokerHandEvaluator.cs`.

Two items were flagged as **worth confirming intent on but not auto-fixing**:
- Video Poker `NeedsRebuy` (`SessionCredits < CurrentBet`) can force an unnecessary rebuy prompt when the player could still play at a lower bet.
- Blackjack's 3:2 payout truncates fractional credits (e.g. a 3-credit blackjack pays 7 instead of 7.5) — a code comment claims this is intentional ("matches Mac 3:2 rounding"), so verify against original Mac behavior before changing.

## How to verify after fixing
- Build: `dotnet build src/SoliBee.Desktop/SoliBee.Desktop.csproj`
- Run locally: `dotnet run --project src/SoliBee.Desktop/SoliBee.Desktop.csproj`
- For bug #1: get into a no-moves state, undo one move, confirm the "no moves" banner reappears immediately rather than after a failed move attempt.
- For bug #2: win a Spider game, note the stats panel, hit undo, confirm stats revert (or undo is blocked).
- For bug #3: play a Vegas-scoring Klondike game to a non-zero score, then start New Game and confirm the score resets to exactly -5200 (not `previous_score - 5200`).
- For bug #5: not easily reproducible by hand; a defensive guard is the goal, not a specific repro.
