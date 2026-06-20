# Quickstart Validation: Beecell

This document details the walkthrough script to verify that Beecell has been implemented successfully without introducing styling or logic issues.

## Verification Checklist

### 1. Board Layout Verification
* Start a new game of Beecell.
* Verify 8 tableau columns are rendered with all 52 cards dealt face-up.
* Verify 4 empty Free Cells are visible in the top left, and 4 empty Foundation slots in the top right.
* Switch options to "Two Decks". Verify that the layout shifts to show 10 tableau columns, 8 Free Cells, and 8 Foundation slots.

### 2. Move Validation Verification
* Attempt to drag a card to a tableau column. Confirm it only stacks if it is one rank lower and of alternating color.
* Drag a single card to a Free Cell. Confirm it is placed correctly. Attempt to drag a second card to the same Free Cell; confirm it is blocked.
* Attempt to move a card sequence. Change the number of empty free cells and columns to confirm the stack size limit validates dynamically.

### 3. Preferences & Aesthetics
* Open the Preferences sheet. Change the felt color to Charcoal.
* Click "Cancel" and verify the board color has *not* changed.
* Open preferences again, select Charcoal, click "OK", and confirm the background and empty slot outlines update to Charcoal/gray tones immediately.
* Confirm that "Undo" is positioned to the right of "Restart Game" in the top bar.
