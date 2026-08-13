# Honeycomb Card Suite :honeybee: :honey_pot:

**Honeycomb Card Suite** is designed to recreate the gameplay dynamics of classic card games with modern flourishes and deep customization.  Change the card decks and card art to your pictures. Match the felt and card color, save it as a full custom theme. Make your own dark mode. **Make the game yours.** 

**Honeycomb Card Suite** está diseñado para recrear la dinámica de los juegos de cartas clásicos con toques modernos y una profunda personalización. Cambia los mazos y el arte de las cartas por tus propias imágenes. Combina el color del fieltro y de las cartas, y guárdalo como un tema personalizado completo. Crea tu propio modo oscuro. **Haz que el juego sea tuyo.**

**Honeycomb** was built using spec-driven development with SpecKit, Claude Code, and Gemini. The macOS & iOS versions are written in Swift 6 & SwiftUI, the Windows version is C# & Avalonia. Zero AI art assets are used. All art used with permission, special thanks to the friends who contributed, that wish to remain uncredited.

---

## ♠️ Game Modes

**Honeycomb Card Suite** supports six fully implemented, distinct games:

### 1. Honeycomb (Triple Triad Style Card Battle)
* **Dynamic Gameplay**: Strategically place cards featuring attack values on all four sides to control a 3x3 grid, navigating a roulette built from a pool of 13 rules, including Symmetry, Math Bee, Pollination, and Swarm to the Death. Includes a ban list to remove rules from roulette.
* **Massive Collection**: Draft your perfect 5-card hand from a 552-card database spanning 4 suits and 5 rarity tiers. 
* **Meaningful Progression**: Permanently steal cards from your opponent to build up your Card Bank, craft custom decks, and track comprehensive battle stats.
* **Challenging AI**: Climb the ranks against Baby Bee, Honey Bee, Queen Bee, and Killer Bee — each bringing their own unique decks and strategies.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/30e2edd0-d275-4e4f-8fc1-37b2f020a8f3" />

### 2. Klondike Solitaire
* **Modes**: Easy (1-Card Draw) and Standard (3-Card Draw).
* **Rules & Scoring**: Classic scoring rules alongside an optional **Vegas Scoring Mode**.
* **Classic Win Animation**: The cards will flow from the foundations, and you will feel alive again.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/ae9058b8-6ca7-4123-bfa8-17aa959256c4" />

### 3. Freecell Solitaire
* **Modes**: Supports both **1-Deck** (8 columns, 4 free cells, 4 foundations) and **2-Deck** (10 columns, 8 free cells, 8 foundations) options.
* **Rules & Scoring**: Open card placement strategy with move limits based on the number of empty free cells and tableau spaces.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/03839abd-a435-4f3d-8177-a7b57512a3bd" />

### 4. Spider Solitaire
* **Modes**: **1-Suit** (Spades), **2-Suit** (Spades/Hearts), or **4-Suit** (Spades/Hearts/Diamonds/Clubs) options.
* **Rules & Scoring**: Start at 500 points, decrement 1 point per move, and earn 100 points for each full sequence (King to Ace of a single suit) cleared.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/c0e104b2-fedd-459e-acf7-fbe61e33d25b" />

### 5. Video Poker
* **Jacks or Better**: Win by holding a pair of Jacks or higher
* **Deuces Wild**: All 2s are wild cards
* **Bonus Poker**: Jacks or Better rules with enhanced payouts for four-of-a-kind hands.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/423a7722-9c35-4d01-bcfc-8305df7148e7" />

### 6. Video Blackjack
* **Casino-style Blackjack**: Hit, stand, double, and split.
* **Video Blackjack Betting**: Bid in 1, 10, or 25 credits, or double your last bet.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/22b6e2df-fa43-46a3-b7c9-251584fca22a" />

---

## ♥️ Game Features - Make The Game Yours!

* **Languages**: English and Español support.
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
