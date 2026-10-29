# Monkey test report

❌ **1 open problem** (newest found Oct 29, 2026).

Every night a GitHub job plays Klondike, Beecell and Spider with thousands of random but legal moves and checks the rules at the bottom of this page after every step. A problem stays listed until a later night's re-check shows it's fixed, so this file only changes when something new turns up or something gets fixed. Each night's run is under GitHub → Actions → "Monkey test (nightly)".

## Problem 1: Beecell: Saved settings or stats came back different after reopening the app

- **Found:** Oct 29, 2026
- **Start:** Beecell, 2 decks. The deal comes from a seed, so it can't be set up by hand, but it replays exactly.
- **What went wrong:** The Beecell stats should be 2deck: played 3, won 0, streak 0, best streak 0 but came back as 2deck: played 2, won 0, streak 0, best streak 0.

**Steps**

1. Quit the app and open it again.

Replay it: `make -C mac monkey-replay CASE=monkey/cases/beecell-saved-reopens-same-77252850.json`

## Rules checked after every step

- Every card is still on the board exactly once.
- The board keeps a legal shape (foundations build up in suit, face-down cards stay underneath, Klondike runs alternate colors, a finished Spider run gets cleared).
- The game says "won" exactly when every card is home.
- Undo gives back exactly the board from before the move (in Klondike standard scoring, minus the undone move's points, as designed).
- Restart gives back the original deal.
- Asking for a hint never changes the board.
- Autocomplete, whenever it's offered, finishes the game.
- Stats add up: a new game on a played, unwon deal ends the streak; a win adds exactly one win; won never exceeds played.
- After quitting and reopening, settings and stats come back the same.
- No step crashes, freezes, or takes more than a few seconds.
