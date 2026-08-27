# Honeycomb Card Suite :honeybee: :honey_pot:

**Honeycomb Card Suite** is designed to recreate the gameplay dynamics of classic card games with modern flourishes and deep customization.  Change the card decks and card art to your pictures. Match the felt and card color, save it as a full custom theme. Make your own dark mode. **Make the game yours.** 

**Honeycomb Card Suite** está diseñado para recrear la dinámica de los juegos de cartas clásicos con toques modernos y una profunda personalización. Cambia los mazos y el arte de las cartas por tus propias imágenes. Combina el color del fieltro y de las cartas, y guárdalo como un tema personalizado completo. Crea tu propio modo oscuro. **Haz que el juego sea tuyo.**

**Honeycomb** was built using spec-driven development with SpecKit, Claude Code, and Gemini. The macOS & iOS versions are written in Swift 6 & SwiftUI, the Windows version is C# & Avalonia. Zero AI art assets are used. All art used with permission, special thanks to the friends who contributed whom wish to remain uncredited.

---

## ♠️ Game Modes

**Honeycomb Card Suite** supports six fully implemented, distinct games:

### 1. Honeycomb (Triple Triad Style Card Battle)
* **Dynamic Gameplay**: Strategically place cards featuring attack values on all four sides to control a 3x3 grid, navigating a roulette built from a pool of 13 rules, including Symmetry, Math Bee, Pollination, and Swarm to the Death. Includes a ban list to remove rules from roulette.
* **Massive Collection**: Draft your perfect 5-card hand from a 552-card database spanning 4 suits and 5 rarity tiers. 
* **Meaningful Progression**: Permanently steal cards from your opponent to build up your Card Bank, craft custom decks, and track comprehensive battle stats.
* **Challenging AI**: Climb the ranks against Baby Bee, Honey Bee, Queen Bee, and Killer Bee — each bringing their own unique decks and strategies.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/bb8a4358-e6d7-4e19-a99a-1e88cc7bb26f" />


### 2. Klondike Solitaire
* **Modes**: Easy (1-Card Draw) and Standard (3-Card Draw).
* **Rules & Scoring**: Classic scoring rules alongside an optional **Vegas Scoring Mode**.
* **Classic Win Animation**: The cards will flow from the foundations, and you will feel alive again.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/f99f00e9-da4c-40b3-bbf2-d8b9855a69bb" />


### 3. Freecell Solitaire
* **Modes**: Supports both **1-Deck** (8 columns, 4 free cells, 4 foundations) and **2-Deck** (10 columns, 8 free cells, 8 foundations) options.
* **Rules & Scoring**: Open card placement strategy with move limits based on the number of empty free cells and tableau spaces.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/fbe299bc-7c49-4ebc-9d09-779e20c31ea0" />

### 4. Spider Solitaire
* **Modes**: **1-Suit** (Spades), **2-Suit** (Spades/Hearts), or **4-Suit** (Spades/Hearts/Diamonds/Clubs) options.
* **Rules & Scoring**: Start at 500 points, decrement 1 point per move, and earn 100 points for each full sequence (King to Ace of a single suit) cleared.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/e1585280-d30b-4ab7-a834-0c834d93d923" />

### 5. Video Poker
* **Jacks or Better**: Win by holding a pair of Jacks or higher
* **Deuces Wild**: All 2s are wild cards
* **Bonus Poker**: Jacks or Better rules with enhanced payouts for four-of-a-kind hands.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/35eed9e9-93c3-4ef3-95c7-9f4632211cbc" />

### 6. Video Blackjack
* **Casino-style Blackjack**: Hit, stand, double, and split.
* **Video Blackjack Betting**: Bid in 1, 10, or 25 credits, or double your last bet.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/4981aa0d-ca78-4f1d-bfa1-eb476b21e246" />

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
