# 🐝 Honeycomb Card Suite



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
  *Output: `src/SoliBee.Desktop/bin/publish/win-x64/Honeycomb.exe` — copy the `.exe` and the `Assets/` folder together to run.*

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
