# Technical Research: PokerBee Suite

## 1. Cross-Platform Architecture: C# + Avalonia UI

### Decision
PokerBee is written entirely in **C# (.NET 8)** with **Avalonia UI** as the single cross-platform UI framework. There are no separate macOS and Windows UI shells — one codebase compiles and runs natively on both platforms from the same development machine (macOS).

```
PokerBee/
├── PokerBee.Core/       # C# class library — zero UI, zero platform imports
├── PokerBee.App/        # Avalonia UI project — single codebase for macOS + Windows
└── PokerBee.Tests/      # xUnit test project
```

### Why Not WinUI 3
WinUI 3 requires the Windows SDK, which cannot be installed on macOS. A Mac developer cannot compile or test a WinUI 3 project without a Windows machine or VM. This breaks the single-developer workflow and eliminates macOS as a primary development environment.

### Why Avalonia
- Avalonia is a .NET UI framework modeled on WPF/XAML that runs on macOS, Windows, and Linux from a single codebase.
- `dotnet build` and `dotnet run` work identically on macOS and Windows — no platform switch required.
- Avalonia's MVVM binding system (`ReactiveUI` or `CommunityToolkit.Mvvm`) mirrors SoliBee's `@Observable` pattern: ViewModels expose bindable properties, Views subscribe with zero glue code.
- Custom rendering via `DrawingContext` or `Canvas` supports the same card layout and felt background SoliBee draws with SwiftUI shapes.
- Published apps: AvaloniaUI powers JetBrains Rider, ReSharper, and several commercial macOS/Windows desktop tools — it is production-proven.

### Architectural Lessons Carried from SoliBee
| SoliBee (Swift) | PokerBee (C#/Avalonia) |
|---|---|
| `@Observable` ViewModel | `ReactiveObject` or `ObservableObject` |
| `options.didSet` + `NotificationCenter.post` | `INotifyPropertyChanged` + `WeakEventManager` or `MessageBus` |
| `decodeIfPresent ?? default` in `Codable` | `JsonSerializer` with `[JsonIgnore(Condition = WhenWritingNull)]` + default property values |
| `AppCoordinator.syncSharedOptions` | `AppCoordinator.SyncSharedOptions` — identical pattern in C# |
| `UserDefaults` | `System.Text.Json` serialized to `~/.config/PokerBee/` (macOS) / `%APPDATA%\PokerBee\` (Windows) via `System.IO` |
| Custom art in `~/Library/Application Support/SoliBee/` | Custom art in `~/.local/share/PokerBee/` (macOS) / `%APPDATA%\PokerBee\` (Windows) |
| `@ObservationIgnored` image cache | Non-reactive field (`[Reactive]` attribute omitted) |

### Build Commands
```bash
# Install .NET 8 SDK (once): https://dotnet.microsoft.com/download
dotnet build                       # debug build, both platforms
dotnet build -c Release            # release build
dotnet run --project PokerBee.App  # run on current platform
dotnet test                        # run all tests
```

Makefile wraps these for parity with SoliBee:
```makefile
build:
    dotnet publish PokerBee.App -c Release -r osx-arm64 --self-contained
    # (or osx-x64, win-x64 depending on target)
```

---

## 2. Card Rendering in Avalonia

### Decision
Re-implement SoliBee's `CardView` as an Avalonia `UserControl`. The card dimensions (128×181), corner radius (10), suit positions, rank text font, and all dark-mode colors are carried over exactly.

### Mapping SwiftUI → Avalonia
| SwiftUI | Avalonia |
|---|---|
| `ZStack` | `Panel` or `Canvas` |
| `Text(rankString).font(.monospaced)` | `TextBlock` with `FontFamily="Courier New"` |
| `Color(red:green:blue:)` | `Color.FromRgb(r, g, b)` |
| `RoundedRectangle(cornerRadius:).stroke` | `Border` with `CornerRadius` and `BorderBrush` |
| `Image(nsImage:).resizable().aspectRatio(.fit)` | `Image` with `Stretch="Uniform"` |
| `CardView.isDarkMode` computed from coordinator | `CardViewModel.IsDarkMode` bound from `AppCoordinator` |

### Dark Mode Colors (unchanged from SoliBee)
- Card background: `#1E1E1E`
- Red suits: `#FF4444`
- Black suits: `#C0C0C0`
- Card border: `#4D4D4D` (`rgb(77,77,77)` ≈ `(0.3, 0.3, 0.3)`)

### Face Card Images
`J.png`, `Q.png`, `K.png`, `red j.png`, `red q.png`, `red k.png`, `dark_*_red.png`, `dark_*_grey.png` are copied directly from SoliBee into `PokerBee.App/Assets/`. Avalonia loads them via `avares://PokerBee.App/Assets/J.png` URI scheme.

In dark mode, the same swap applies: load `dark_k_red.png` / `dark_k_grey.png` instead of `K.png` / `K.png`. Light-mode images use `Stretch="Uniform"` constrained to height 62 (matching SoliBee's `.frame(height: 62)` clip); dark-mode letter images use unconstrained `Stretch="Uniform"` in a 77×122 frame (matching SoliBee's `fillFrame: true`).

---

## 3. Texas Hold 'Em Hand Evaluator

### Decision
C# implementation of 7-card best-5 evaluator using the same algorithm specified in the Swift design:
1. Generate all C(7,5) = 21 five-card subsets from (2 hole + 5 community).
2. Score each via `PokerHandRank` enum (0 = HighCard … 9 = RoyalFlush) + `int[]` kicker array.
3. Return highest-scoring subset; compare kicker arrays lexicographically on rank ties.

```csharp
public enum PokerHandRank { HighCard, OnePair, TwoPair, ThreeOfAKind,
    Straight, Flush, FullHouse, FourOfAKind, StraightFlush, RoyalFlush }

public record PokerHandResult(PokerHandRank Rank, int[] Kickers)
    : IComparable<PokerHandResult> { ... }
```

---

## 4. Blackjack Engine

Same rules as specified in the original research: hit on soft ≤16, stand on hard/soft 17+. Multi-deck shoe with configurable 1–8 decks. Cut-card reshuffle at 60–75% through the shoe.

---

## 5. AI Strategy Engine (Texas Hold 'Em)

Same rule-based approach: Chen formula pre-flop, pot-odds post-flop, configurable bluff frequency (`double BluffFrequency = 0.08`). Implemented as a static `HoldemAI` class in `PokerBee.Core` with no UI dependencies.

---

## 6. Options and Persistence

### Pattern (mirrors SoliBee)
- Each game has its own options class: `HoldemOptions`, `BlackjackOptions`.
- Shared visual settings (`FeltColor`, `CardBackTheme`, `IsDarkMode`, `IsSoundEnabled`) live in `PokerBeeSharedOptions` and are composed into both.
- Serialized to JSON via `System.Text.Json` to `~/.config/PokerBee/holdem_options.json` etc.
- `AppCoordinator.SyncSharedOptions(from, to)` copies shared fields on mode switch — identical logic to SoliBee.
- Each ViewModel's shared-option properties fire `PropertyChanged` when set, which the Avalonia binding system propagates to all bound CardViews automatically (replaces SoliBee's `NotificationCenter` pattern).

### Storage Paths
| Platform | Config dir |
|---|---|
| macOS | `~/.config/PokerBee/` |
| Windows | `%APPDATA%\PokerBee\` |

Resolved in code via `Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData)`.
