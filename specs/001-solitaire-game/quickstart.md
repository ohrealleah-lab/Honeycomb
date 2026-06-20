# SoliBee Quickstart & Validation Guide

This guide describes how to build, test, and validate the **SoliBee** Solitaire game on macOS.

## Prerequisites
- macOS 14.0 or newer.
- Xcode Command Line Tools installed (must support Swift 6 / `swiftc`). Verify with `swift --version`.

---

## 1. Setup & Build Commands

A `Makefile` is provided in the repository root to automate the build and packaging of the standalone `.app` bundle.

### Build the Application:
Run the following command from the project root directory:
```bash
make build
```
This command compiles all Swift files under the `src/` directory and packages them into the `SoliBee.app` bundle in the repository root.

### Clean Build Directory:
To remove the compiled app and intermediate files:
```bash
make clean
```

---

## 2. Test Execution

Unit tests are written using Swift's native testing capabilities (`Swift Testing` or `XCTest`).

### Run Unit Tests:
Run the test suite using the following command:
```bash
make test
```
This runs all tests defined in the `SoliBeeTests/` directory, validating:
1. Shuffling and initialization rules.
2. 1-Card and 3-Card draw mechanics (including legacy end-of-stock boundary behavior).
3. Movement validation rules (Tableau card colors/ranks, empty spaces accepting Kings only).
4. Auto-flipping of exposed face-down tableau cards.
5. Score calculations.
6. Hint prioritization matrix and autocomplete readiness check.

---

## 3. Run & Manual Validation

### Launch the Application:
Open the compiled standalone app bundle:
```bash
open SoliBee.app
```

### Manual Validation Checklist:
1. **Game Modes**: Go to the "Game" menu or the toggle buttons, select **3-Card Draw**, draw cards from the stock, and verify fanned cards. Switch back to **1-Card Draw** and verify one-by-one drawing.
2. **Move Validation**: Attempt to drag a Red card onto another Red card in the Tableau. Verify it snaps back. Verify a Red 7 stacks on a Black 8.
3. **Double-Click Shortcut**: Double-click an Ace. It should fly automatically to an empty Foundation slot. Double-click other cards to verify standard path routing.
4. **Hints**: Click "Hint" to verify that the game highlights the next best move according to the priority matrix.
5. **Autocomplete**: Clear all face-down cards and draw piles. Verify that the "Autocomplete Game" button appears. Click it, and check that all remaining cards animate to the foundations.
6. **Victory Cascades**: Win the game (or click Autocomplete to win) and watch cards bounce off foundations, leaving retro trailing frames on the green felt table.
