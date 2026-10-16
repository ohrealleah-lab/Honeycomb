# 🐝 Honeycomb Card Suite — Windows

## ♦️ Getting Started

### Prerequisites
* **Operating System**: Windows 10 or later
* **SDK**: [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)

### Build Commands
Run these from the `windows/` folder.

* **Debug build**:
  ```bash
  dotnet build src/SoliBee.Desktop/SoliBee.Desktop.csproj
  ```

* **Run the tests**:
  ```bash
  dotnet test tests/SoliBee.Tests/SoliBee.Tests.csproj
  ```

* **Publish a self-contained Windows executable**:
  ```bash
  dotnet publish src/SoliBee.Desktop/SoliBee.Desktop.csproj -c Release -r win-x64 --self-contained
  ```
  *Produces a single-file `Honeycomb.exe` in the project's `bin/Release/.../publish/` folder. Keep the `.wav` sound files and `HoneycombBannerCatalog.json` next to the `.exe` — they're copied there, not embedded.*

---

## 📁 Repository Structure

```text
windows/
├── SoliBee.sln
├── src/
│   ├── SoliBee.Core/           # Game logic, no UI
│   │   ├── Models/             # Cards, game state, options, statistics
│   │   ├── Services/           # Settings, stats, themes, face-card art, file safety
│   │   ├── Localization/       # English and Español strings
│   │   └── ViewModels/         # One view model per game, plus AppCoordinator
│   └── SoliBee.Desktop/        # Avalonia UI
│       ├── Views/              # Game views, card views, editors, dialogs
│       ├── Services/           # Sound playback
│       └── Assets/             # Images, fonts, and sound files
└── tests/
    └── SoliBee.Tests/          # Unit tests
```

The game logic is hand-ported from the shared Swift code in `../shared/`.
