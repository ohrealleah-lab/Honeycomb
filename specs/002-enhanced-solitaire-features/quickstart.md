# Quickstart & E2E Validation: Solitaire Enhancements

This document outlines the testing scenarios and commands to validate the new customization, rule variations, audio effects, and controls.

## 1. Setup & Build
Compile and verify the application builds cleanly:

```bash
make clean
make build
make test
```

Launch the application to test the GUI features:
```bash
open SoliBee.app
```

## 2. E2E Validation Scenarios

### Scenario 1: Customizing Background Felt & Card Backs
1. Launch the app.
2. From the top control panel or the application menu, select "Crimson" under felt board colors. Verify that the table felt turns deep red.
3. Open the "Card Deck" menu. Select "Blue Rose".
4. Draw cards and confirm that all face-down card backings display the programmatically drawn blue rose.

### Scenario 2: Toggle Vegas Mode & Scoring Validation
1. Open the "Options" dialog.
2. Check the box for "Vegas Scoring Mode". Click OK.
3. Confirm that the current game resets and the SCORE display changes to `-$52.00` currency formatting.
4. Move an Ace to the Foundation. Confirm that the score increases to `-$47.00`.
5. Move a card from the Foundation back to the Tableau. Confirm that the score drops to `-$52.00`.

### Scenario 3: Draw Constraints & Recycle Limit
1. Ensure "Vegas Scoring" and "Limit Stock Recycles" (Draw Constraints) are active. Set the draw mode to Draw One.
2. Draw cards from the Stock until the Stock pile is empty.
3. Click the empty Stock pile area.
4. Confirm that the Stock pile remains empty and does NOT recycle the Waste cards, since Vegas Draw One allows 0 recycles.

### Scenario 4: Sound Effects & Muting
1. Ensure "Enable Sound" is toggled ON in the Preferences/Options dialog.
2. Click the Stock pile. Verify that a card-shuffling/slide sound plays.
3. Drag and drop a card on a valid pile. Verify that a snapping/sliding audio cue plays.
4. Open Options, uncheck "Enable Sound", and verify that subsequent draws and drops are silent.

### Scenario 5: Keyboard Shortcuts & Undo
1. Press `Cmd+N` and verify that the current match is forfeited and a new game is dealt.
2. Draw a card, then press `Cmd+Z` and verify that the drawn card moves back to the Stock pile.
3. Press `Cmd+H` and verify that the active hint is calculated and highlighted.
4. Press `Cmd+1` or `Cmd+3` to toggle draw mode and confirm the game resets correctly.
