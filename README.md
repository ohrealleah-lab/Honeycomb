<p align="center">
  <img src="mac/images/icon/AppIcon-1024.png" width="128" alt="Honeycomb app icon">
</p>

# Honeycomb Card Suite :honeybee: :honey_pot:

[![macOS build](https://img.shields.io/github/actions/workflow/status/ohrealleah-lab/Honeycomb/build-release-mac.yml?branch=main&label=macOS%20build)](https://github.com/ohrealleah-lab/Honeycomb/actions/workflows/build-release-mac.yml)
[![iOS build](https://img.shields.io/github/actions/workflow/status/ohrealleah-lab/Honeycomb/build-test-ios.yml?branch=main&label=iOS%20build)](https://github.com/ohrealleah-lab/Honeycomb/actions/workflows/build-test-ios.yml)
[![Windows build](https://img.shields.io/github/actions/workflow/status/ohrealleah-lab/Honeycomb/build-sign-windows.yml?event=push&label=Windows%20build)](https://github.com/ohrealleah-lab/Honeycomb/actions/workflows/build-sign-windows.yml)
[![Latest release](https://img.shields.io/github/v/release/ohrealleah-lab/Honeycomb?label=release)](https://github.com/ohrealleah-lab/Honeycomb/releases)
[![Test coverage](https://codecov.io/gh/ohrealleah-lab/Honeycomb/branch/main/graph/badge.svg)](https://codecov.io/gh/ohrealleah-lab/Honeycomb)
![Platforms: macOS, iOS, Windows, Android](https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Windows%20%7C%20Android-blue)

Six card games, four platforms, one shared rule engine, and a deep customization system. Includes a Triple Triad–style card battler (Honeycomb) plus Klondike, Freecell, Spider, Video Poker, and Blackjack.

**▶ [Play it on itch.io](https://playhoneycomb.itch.io/honeycomb-card-suite)** · [Español](README.es.md)

<!-- HERO SCREENSHOT goes here -->

---

## 🛠️ Tech at a Glance

| Platform | Language | UI | Notes |
|---|---|---|---|
| macOS | Swift 6 | SwiftUI | macOS 14+, unit-tested, release builds via CI |
| iOS | Swift 6 | SwiftUI | iOS 17+, shares its game logic with macOS, build and smoke test via CI |
| Windows | C# (.NET 10) | Avalonia | Signed release builds via CI |
| Android | Kotlin | Jetpack Compose | minSdk 26 |

* **Shared core**: macOS and iOS use the same Swift game logic (`shared/`). The Windows and Android versions mirror it by hand.
* **Localization pipeline**: English and Español strings live in one spreadsheet (`tools/`) that generates the string files for every platform.
* **Tests & CI**: GitHub Actions workflows build macOS, Windows, and iOS, with unit tests covering game state, scoring, casino logic, and the Honeycomb card database.
* **How it was built**: spec-driven development with SpecKit and Claude Code. Zero AI art assets are used. All art is used with permission, with special thanks to the friends who contributed and wish to remain uncredited.
* **License**: [PolyForm Noncommercial 1.0.0](LICENSE). Free to use, copy, and modify for noncommercial purposes.

---

## 🎨 Make The Game Yours

Change the card decks and card art to your own pictures. Match the felt and card colors and save it all as a full custom theme. Make your own dark mode. **Make the game yours.**

---

## ♠️ Game Modes

**Honeycomb Card Suite** supports six fully implemented, distinct games:

> **Platform note:** On iOS and Android, Video Poker and Blackjack are free play only (no betting or credits), and Klondike has no Vegas Scoring Mode.

### 1. Honeycomb (Triple Triad Style Card Battle)
* **Dynamic Gameplay**: Strategically place cards featuring attack values on all four sides to control a 3x3 grid, navigating a roulette built from a pool of 13 rules, including Symmetry, Math Bee, Pollination, and Swarm to the Death. Includes a ban list to remove rules from roulette.
* **Massive Collection**: Draft your perfect 5-card hand from a 552-card database spanning 4 suits and 5 rarity tiers.
* **Meaningful Progression**: Permanently steal cards from your opponent to build up your Card Bank, craft custom decks, and track comprehensive battle stats.
* **Challenging AI**: Climb the ranks against Baby Bee, Honey Bee, Queen Bee, and Killer Bee — each bringing their own unique decks and strategies.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/bb8a4358-e6d7-4e19-a99a-1e88cc7bb26f" />


### 2. Klondike Solitaire
* **Modes**: Easy (1-Card Draw) and Standard (3-Card Draw).
* **Rules & Scoring**: Classic scoring rules alongside an optional **Vegas Scoring Mode** (Mac and Windows).
* **Classic Win Animation**: The cards will flow from the foundations, and you will feel alive again.

<img width="800" height="648" alt="youwin" src="https://github.com/user-attachments/assets/16a20aee-a8b9-4486-b4ad-f9eac83fee36" />


### 3. Freecell Solitaire
* **Modes**: Supports both **1-Deck** (8 columns, 4 free cells, 4 foundations) and **2-Deck** (10 columns, 8 free cells, 8 foundations) options.
* **Rules & Scoring**: Open card placement strategy with move limits based on the number of empty free cells and tableau spaces.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/fbe299bc-7c49-4ebc-9d09-779e20c31ea0" />

### 4. Spider Solitaire
* **Modes**: **1-Suit** (Spades), **2-Suit** (Spades/Hearts), or **4-Suit** (Spades/Hearts/Diamonds/Clubs) options.
* **Rules & Scoring**: Start at 500 points, decrement 1 point per move, and earn 100 points for each full sequence (King to Ace of a single suit) cleared.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/e1585280-d30b-4ab7-a834-0c834d93d923" />

### 5. Video Poker
* **Jacks or Better**: Win by holding a pair of Jacks or higher.
* **Deuces Wild**: All 2s are wild cards.
* **Bonus Poker**: Jacks or Better rules with extra emphasis on four-of-a-kind hands.

<img width="597" height="476" alt="image" src="https://github.com/user-attachments/assets/35eed9e9-93c3-4ef3-95c7-9f4632211cbc" />

### 6. Video Blackjack
* **Classic Blackjack**: Hit, stand, double, and split.
* **Video Blackjack Betting** (Mac and Windows): Build your bet with 1, 5, 10, or 25 chips, or double it with 2X.

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
* **No Stress Mode**: Disable timers for a relaxed card gaming session. On Mac and Windows, it also switches Video Poker and Blackjack to betting-free play.

---

## ♣️ Game Capabilities

* **Engine Features**: Supports automated autocomplete once victory is mathematically guaranteed.
* **Hint System**: Instantly highlight optimal legal moves on the board.
* **Full Undo History**: Complete multi-step action undo history.
* **Live Statistics**: Score tracking, move count, game timers, win percentages, and persisted local high scores.

---

## ♦️ Getting Started

Platform-specific build instructions and prerequisites:

* [macOS README](mac/README.md)
* [Windows README](windows/README.md)
* **iOS**: `cd ios && xcodegen generate`, then open `Honeycomb.xcodeproj` in Xcode (iOS 17+).
* **Android**: `cd android && ./gradlew assembleDebug` (minSdk 26).
