# 🐝 Honeycomb Card Suite

Mono-repo for the SoliBee/Honeycomb card game suite, featuring native applications for macOS and Windows.

- `mac/` — native macOS app (Swift/SwiftUI)
- `windows/` — native Windows app (C#/Avalonia)

*Game logic is equivalent between platforms; naming may differ in places (e.g. "Beecell" on mac vs "Freecell" on windows) as a historical artifact of separate development.*

---

## ♠️ Game Modes

Honeycomb supports six fully implemented, distinct games:

### 1. Klondike Solitaire
* **Modes**: Easy (1-Card Draw) and Standard (3-Card Draw).
* **Rules & Scoring**: Classic scoring rules alongside an optional **Vegas Scoring Mode**.
* **Classic Win Animation**: The cards will flow from the foundations, and you will feel alive again.

### 2. Freecell Solitaire
* **Modes**: Supports both **1-Deck** (8 columns, 4 free cells, 4 foundations) and **2-Deck** (10 columns, 8 free cells, 8 foundations) options.
* **Rules & Scoring**: Open card placement strategy with move limits based on the number of empty free cells and tableau spaces.

### 3. Spider Solitaire
* **Modes**: **1-Suit** (Spades), **2-Suit** (Spades/Hearts), or **4-Suit** (Spades/Hearts/Diamonds/Clubs) options.
* **Rules & Scoring**: Start at 500 points, decrement 1 point per move, and earn 100 points for each full sequence (King to Ace of a single suit) cleared.

### 4. Video Poker
* **Jacks or Better**: Win by holding a pair of Jacks or higher
* **Deuces Wild**: All 2s are wild cards
* **Bonus Poker**: Jacks or Better rules with enhanced payouts for four-of-a-kind hands.

### 5. Video Blackjack
* **Casino-style Blackjack**: Hit, stand, and split.
* **Video Blackjack Betting**: Bid in 1, 10, or 25 credits, or double your last bet.

### 6. Honeycomb (Card Battle)
* **Modes**: Battle an AI opponent on a 3x3 grid with up to two optional match rules from a pool of 11 (including Same, Plus, Ascension, Reverse, Swap, Order, and Chaos).
* **Card Economy**: Build 5-card hands drawn from a 552-card database across 4 suits and 5 rarity tiers.
* **Progression System**: Permanently unlock captured cards into your persistent Card Bank, save custom decks, and track comprehensive stats.

---

## ♥️ Game Features - Make The Game Yours!

* **Custom Card Backs**: Set the card back to whatever image you want. Even an animated gif!
* **Custom Card Art**: Set the art for red and black suits for Aces, Jacks, Kings, and Queens.
* **Custom Card Colors**: Change the color of the cards and the card suits. 
* **Custom Color Background**: Set the tableau to match your deck of cards.
* **Visual Themes**: Use a presaved theme, or create your own! Easily toggle between multiple themes.
* **Retro Sound Effects**: Audio cues for shuffling, snapping cards into place, and victory cascades.
* **No Stress Mode**: Disable timers and hide betting for a relaxed card gaming session.
  
---

## ♣️ Game Capabilities

* **Engine Features**: Supports automated autocomplete once victory is mathematically guaranteed.
* **Hint System**: Instantly highlight optimal legal moves on the board.
* **Full Undo History**: Complete multi-step action undo history.
* **Live Statistics**: Score tracking, move count, game timers, win percentages, and persisted local high scores.

---

## ♦️ Getting Started

Please see the platform-specific READMEs for build instructions and prerequisites:
- [macOS README](mac/README.md)
- [Windows README](windows/README.md)
