# 🐝 Solibee Solitaire Suite
What's the #1 issue facing Windows users today? A lack of ad-free Klondike Solitaire. I used SpecKit, Gemini, and Claude to build Solitaire for Windows so my woes would end (and to brush up on Agentic development.) 

A native Windows Solitaire suite written in **Avalonia UI 11 / .NET 8 C#**, designed to recreate the gameplay dynamics of classic Solitaire games with modern flourishes and customization. **Make the game yours**.

---

## ♠️ Game Modes

Solibee supports four fully implemented, distinct games selectable via the **Game Selection** dropdown:

### 1. Klondike
* **Modes**: Easy (1-Card Draw) and Standard (3-Card Draw).
* **Rules & Scoring**: Classic scoring rules alongside an optional **Vegas Scoring Mode**.

### 2. Freecell
* **Modes**: Supports both **1-Deck** (8 columns, 4 free cells, 4 foundations) and **2-Deck** (10 columns, 4 free cells, 8 foundations) options.
* **Rules & Scoring**: Open card placement strategy with move limits based on the number of empty free cells and tableau spaces.

### 3. Spider Solitaire
* **Modes**: **1-Suit** (Spades), **2-Suit** (Spades/Hearts), or **4-Suit** (Spades/Hearts/Diamonds/Clubs) options.
* **Rules & Scoring**: Start at 500 points, decrement 1 point per move, and earn 100 points for each full sequence (King to Ace of a single suit) cleared.

### 3. Video Poker
* **Modes**: **Jacks or Better, Deuces Wild, Bonus Poker**
* **Rules & Scoring**: **Jacks or Better**: Win by holding a pair of Jacks or higher, **Deuces Wild**: All 2s are wild cards, **Bonus Poker**: Jacks or Better rules with enhanced payouts for four-of-a-kind hands.

  
---

## ♥️ Game Features - Make The Game Yours!

* **Custom Card Backs**: Set the card back to whatever you want. Even an animated gif!
* **Custom Card Art**: Set the art for red and black suits for Aces, Jacks, Kings, and Queens.
* **Custom Color Background**: Set the tableau to match your deck of cards.
* **Visual Themes**: Use a presaved theme, or create your own! Easily toggle between multiple themes.
* **Retro Sound Effects**: Audio cues for shuffling, snapping cards into place, and victory cascades.
* **ZERO AI Art**: All art was created by real artists, used with permission.
  
---

## ♣️ Game Capabilties

* **Engine Features**: Supports automated autocomplete once victory is mathematically guaranteed.
* **Hint System**: Instantly highlight optimal legal moves on the board.
* **Full Undo History**: Complete multi-step action undo history.
* **Live Statistics**: Score tracking, move count, game timers, win percentages, and persisted local high scores.

---

## ♦️ Getting Started

### Prerequisites
* **Operating System**: Windows 10 or later
* **SDK**: [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)

### Build Commands

* **Debug build**:
  ```bash
  dotnet build src/SoliBee.Desktop/SoliBee.Desktop.csproj
  ```

* **Publish self-contained Windows executable**:
  ```bash
  dotnet publish src/SoliBee.Desktop/SoliBee.Desktop.csproj /p:PublishProfile=win-x64
  ```
  *Output: `src/SoliBee.Desktop/bin/publish/win-x64/SoliBee.Desktop.exe` — copy the `.exe` and the `Assets/` folder together to run.*

---

## 📁 Repository Structure

```text
SolibeeWin/
├── src/
│   ├── SoliBee.Core/
│   │   ├── Models/         # Card, GameOptions, GameState, Pile, …
│   │   ├── Services/       # SettingsService, FaceCardArtService, StatsService
│   │   └── ViewModels/     # GameViewModel, BeecellViewModel, SpiderViewModel, AppCoordinator
│   └── SoliBee.Desktop/
│       ├── Views/          # CardView, GameView, MainWindow, PreferencesView, BeecellView, SpiderView, …
│       ├── Assets/         # Images and WAV sound files
│       └── Properties/
│           └── PublishProfiles/
│               └── win-x64.pubxml
```
