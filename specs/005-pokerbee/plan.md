# Implementation Plan: PokerBee Suite

**Branch**: `005-pokerbee` | **Date**: 2026-06-24 | **Spec**: [spec.md](./spec.md)

## Summary

PokerBee is a cross-platform card game suite (Texas Hold 'Em + Blackjack) written in **C# (.NET 8)** with **Avalonia UI**. A single codebase compiles and runs on both macOS and Windows from any development machine. The architecture mirrors SoliBee's MVVM discipline: all game logic in a platform-agnostic Core library, all UI in a thin Avalonia layer. Card rendering, visual customization, and the options/sync pattern are ported directly from SoliBee's design into C#/Avalonia equivalents.

## Technical Context

**Language**: C# 12 / .NET 8  
**UI Framework**: Avalonia 11 (`Avalonia`, `Avalonia.ReactiveUI`)  
**Architecture**: MVVM — `ReactiveObject` ViewModels, Avalonia XAML Views  
**Core Library**: `PokerBee.Core` — zero Avalonia/UI imports, fully unit-testable  
**Test Framework**: xUnit  
**Build**: `dotnet build` / `dotnet publish` — works identically on macOS and Windows  
**Storage**: `System.Text.Json` to `~/.config/PokerBee/` (macOS) / `%APPDATA%\PokerBee\` (Windows)  
**Custom Art Storage**: `~/.local/share/PokerBee/` (macOS) / `%APPDATA%\PokerBee\art\` (Windows)  

## Project Structure

```
PokerBee/
├── PokerBee.Core/                    # C# class library — zero UI imports
│   ├── Models/
│   │   ├── Card.cs                   # Rank, Suit, FaceUp — mirrors SoliBee Card.swift
│   │   ├── Deck.cs                   # Shuffle, multi-deck, Deal(), cut-card reshuffle
│   │   ├── GameMode.cs               # Enum: Holdem, Blackjack
│   │   ├── HoldemGameState.cs
│   │   ├── HoldemPlayer.cs
│   │   ├── HoldemOptions.cs          # decodeIfPresent pattern → default property values
│   │   ├── HoldemStatistics.cs
│   │   ├── BlackjackGameState.cs
│   │   ├── BlackjackHand.cs
│   │   ├── BlackjackOptions.cs
│   │   ├── BlackjackStatistics.cs
│   │   ├── PokerBeeSharedOptions.cs  # Felt, CardBack, IsDarkMode, IsSoundEnabled
│   │   ├── PokerHandResult.cs        # Rank enum + kicker array + IComparable
│   │   ├── SidePot.cs
│   │   ├── FeltColorTheme.cs         # Mirrors SoliBee FeltColorTheme enum
│   │   ├── CustomCardBack.cs
│   │   ├── CustomFaceArt.cs
│   │   └── FaceCardSlot.cs           # BlackAce, RedJack, etc. — mirrors SoliBee
│   ├── Engines/
│   │   ├── HandEvaluator.cs          # C(7,5) best-5 evaluator
│   │   ├── HoldemAI.cs               # Chen formula + pot-odds + bluff frequency
│   │   └── BlackjackDealer.cs        # Dealer draw-to-17 rule engine
│   ├── Managers/
│   │   ├── CustomCardBackManager.cs  # Singleton, persists to app data dir
│   │   └── CustomFaceCardArtManager.cs
│   └── ViewModels/
│       ├── AppCoordinator.cs         # Mode switching + SyncSharedOptions
│       ├── HoldemViewModel.cs        # ReactiveObject, all Hold 'Em game logic
│       └── BlackjackViewModel.cs     # ReactiveObject, all Blackjack game logic
│
├── PokerBee.App/                     # Avalonia UI — single project for macOS + Windows
│   ├── App.axaml / App.axaml.cs      # Application entry point
│   ├── Views/
│   │   ├── AppRouterView.axaml       # Switches between HoldemView / BlackjackView
│   │   ├── CardView.axaml            # Card rendering — 128×181, same layout as SoliBee
│   │   ├── HoldemView.axaml          # Table, community cards, player seats, action buttons
│   │   ├── BlackjackView.axaml       # Dealer area, player hand, bet/action controls
│   │   ├── TableView.axaml           # Felt background container
│   │   ├── ChipView.axaml            # Chip stack display
│   │   ├── OptionsView.axaml         # Shared preferences panel
│   │   ├── CardDeckSelectorView.axaml
│   │   └── FaceCardArtSectionView.axaml
│   ├── Assets/
│   │   ├── J.png, Q.png, K.png
│   │   ├── red j.png, red q.png, red k.png
│   │   ├── dark_k_red.png, dark_q_red.png, dark_j_red.png
│   │   ├── dark_k_grey.png, dark_q_grey.png, dark_j_grey.png
│   │   └── *.wav  (shuffle, snap, chip sounds)
│   └── PokerBee.App.csproj
│
├── PokerBee.Tests/                   # xUnit test project
│   ├── HandEvaluatorTests.cs
│   ├── HoldemViewModelTests.cs
│   ├── BlackjackViewModelTests.cs
│   └── OptionsTests.cs
│
├── PokerBee.sln
└── Makefile                          # Wraps dotnet commands for parity with SoliBee
```

## Key Architecture Decisions

### AppCoordinator (identical pattern to SoliBee)
`AppCoordinator` holds both ViewModels alive simultaneously. `GameMode` property setter calls `SyncSharedOptions(from, to)` which copies `IsDarkMode`, `IsSoundEnabled`, `FeltColor`, `CardBackTheme`, `CustomFeltColorRevision` from the outgoing ViewModel's options to the incoming one — preventing visual settings from diverging when the player switches games.

### MVVM: ReactiveObject replaces @Observable
SoliBee's `@Observable` macro auto-generates property observation. In Avalonia the equivalent is `ReactiveObject` from `ReactiveUI`:
```csharp
// SoliBee Swift                    // PokerBee C#
@Observable class HoldemViewModel   class HoldemViewModel : ReactiveObject
var options: HoldemOptions {        private HoldemOptions _options;
    didSet { saveOptions() }        public HoldemOptions Options {
}                                       get => _options;
                                        set { this.RaiseAndSetIfChanged(ref _options, value);
                                              SaveOptions(); } }
```

### Options Pattern (mirrors SoliBee decodeIfPresent)
C# options classes use constructor defaults and `[JsonIgnore(Condition = WhenWritingNull)]`. Missing keys on deserialize fall back to property defaults — same resilience as SoliBee's `decodeIfPresent ?? default`:
```csharp
public class HoldemOptions {
    public string CardBackTheme { get; set; } = "Vulpera";
    public bool IsDarkMode { get; set; } = false;
    public FeltColorTheme FeltColor { get; set; } = FeltColorTheme.FeltGreen;
    // new fields added here just work — no migration needed
}
```

### Notification System → PropertyChanged
SoliBee uses `NotificationCenter.post(name: .darkModeDidChange)` to broadcast to all CardViews. In Avalonia, `INotifyPropertyChanged` (raised by `RaiseAndSetIfChanged`) propagates through the binding system automatically — no manual subscriber registration needed. `CardView` binds `IsDarkMode` to the ViewModel; Avalonia updates all instances when the property changes.

### Card Image Loading
Avalonia loads bundled assets via URI: `new Uri("avares://PokerBee.App/Assets/dark_k_red.png")`. The `CardView` code-behind selects the correct asset URI based on `IsDarkMode`, `Rank`, and `Suit.IsRed` — identical logic to SoliBee's `CardCenterSuitView`.

## Constitution Check

No violations. All game rules and AI are in `PokerBee.Core` with zero Avalonia dependency. ViewModels in Core are testable with plain xUnit without launching the UI.
