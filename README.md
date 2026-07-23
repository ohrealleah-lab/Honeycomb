# Honeycomb Card Suite :honeybee: :honey_pot:

**Honeycomb Card Suite** is a designed to recreate the gameplay dynamics of classic card games with modern flourishes and deep customization.  Change the card decks and card art to your pictures. Match the felt and card color, save it as a full custom theme. Make your own dark mode. **Make the game yours.** 

**Honeycomb** was built using spec-driven development with SpecKit, Claude Code, and Gemini. The  macOS version is written in Swift 6 & SwiftUI, the Windows version is C# & Avalonia. 

---

## ♠️ Game Modes

**Honeycomb** supports six fully implemented, distinct games:

### 1. Klondike Solitaire
* **Modes**: Easy (1-Card Draw) and Standard (3-Card Draw).
* **Rules & Scoring**: Classic scoring rules alongside an optional **Vegas Scoring Mode**.
* **Classic Win Animation**: The cards will flow from the foundations, and you will feel alive again.

<img width="593" height="476" alt="image" src="https://github.com/user-attachments/assets/f5fed961-fdb1-4fdf-b5cc-d1fb5b82f70c" />


### 2. Freecell Solitaire
* **Modes**: Supports both **1-Deck** (8 columns, 4 free cells, 4 foundations) and **2-Deck** (10 columns, 8 free cells, 8 foundations) options.
* **Rules & Scoring**: Open card placement strategy with move limits based on the number of empty free cells and tableau spaces.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/03839abd-a435-4f3d-8177-a7b57512a3bd" />


### 3. Spider Solitaire
* **Modes**: **1-Suit** (Spades), **2-Suit** (Spades/Hearts), or **4-Suit** (Spades/Hearts/Diamonds/Clubs) options.
* **Rules & Scoring**: Start at 500 points, decrement 1 point per move, and earn 100 points for each full sequence (King to Ace of a single suit) cleared.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/c0e104b2-fedd-459e-acf7-fbe61e33d25b" />


### 4. Video Poker
* **Jacks or Better**: Win by holding a pair of Jacks or higher
* **Deuces Wild**: All 2s are wild cards
* **Bonus Poker**: Jacks or Better rules with enhanced payouts for four-of-a-kind hands.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/423a7722-9c35-4d01-bcfc-8305df7148e7" />


### 5. Video Blackjack
* **Casino-style Blackjack**: Hit, stand, double, and split.
* **Video Blackjack Betting**: Bid in 1, 10, or 25 credits, or double your last bet.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/22b6e2df-fa43-46a3-b7c9-251584fca22a" />


### 6. Honeycomb (Triple Triad Style Card Battle)
* **Modes**: Battle an AI opponent on a 3x3 grid with up to two optional match rules from a pool of 11 (including Same, Plus, Ascension, Reverse, Swap, Order, and Chaos).
* **Card Economy**: Build 5-card hands drawn from a 552-card database across 4 suits and 5 rarity tiers.
* **Progression System**: Steal captured cards into your persistent Card Bank, build custom decks, and track comprehensive stats.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/30e2edd0-d275-4e4f-8fc1-37b2f020a8f3" />


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
