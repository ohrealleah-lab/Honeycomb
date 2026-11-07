# Beekeeper stage 4: handoff to a new session

**Where we are (2026-11-07):** Stages 1–3 of Beekeeper are built, committed and hand-tested by Leah, plus several layout changes. Stage 4 is fully specced, and Leah accepted every placeholder. **Nothing for stage 4 is built yet.** 30 local commits are not pushed; push only when Leah says "push".

## Read first
1. `windows/012-beekeeper-garden/spec.md` (v2): what to build. All placeholders are accepted.
2. `Beekeeper/LONG_TERM_DESIGN.md`, stage 3 "Seeds, discovery and bee types": the why.
3. `windows/CLAUDE.md` for build and test commands.
4. For patterns, skim how stages 2 and 3 were done: `windows/010-beekeeper-workbench/` and `windows/011-beekeeper-catching/`. Their code is in the files listed below.

## Where the code is
| What | File |
|---|---|
| Every number (placeholders) | `windows/src/SoliBee.Core/Models/BeekeeperConfig.cs` |
| Saved state (now version 3) | `windows/src/SoliBee.Core/Models/BeekeeperState.cs` |
| The rules (no clock, no UI) | `windows/src/SoliBee.Core/Models/BeekeeperEngine.cs` |
| Save version and sanity checks | `windows/src/SoliBee.Core/Services/BeekeeperSaveService.cs` |
| Timer, commands, wasp time, trade offers | `windows/src/SoliBee.Core/ViewModels/BeekeeperViewModel.cs` |
| The screen | `windows/src/SoliBee.Desktop/Views/BeekeeperView.axaml(.cs)` |
| All Beekeeper words (looks up the workbook) | `windows/src/SoliBee.Desktop/Views/BeekeeperText.cs` |
| Help page, debug menu | `HelpWindow.axaml(.cs)`, `MainWindow.axaml(.cs)` (Banners → Beekeeper) |
| Tests | `windows/tests/SoliBee.Tests/Core/Beekeeper*Tests.cs`, `ViewModels/Beekeeper*Tests.cs` |

## How things are done here (keep doing them)
- **Engine first, then the view model, then the screen.** The engine has no clock: live play calls `Advance(seconds)`, time away calls `AdvanceAway(seconds)`, and both must agree. For stage 4, growing a seed, attracting bees and pollen must work for any span in one step, and must work while away.
- **Save version goes to 4.** Older JSON saves load as they are (new fields default to zero). Add sanity checks for the new amounts, and a test that a version 3 file loads with nothing lost.
- **Story log:** the engine returns events (key + `Value`/`Value2`/`Text`); `BeekeeperText.LogLine` turns them into words. Never store sentences.
- **Words:** every visible string goes into `tools/Honeycomb_Localization.xlsx` (English + a Spanish draft) using a small openpyxl script, then run `python tools/generate_localization.py` (Windows: `python`, not `python3`). Remove words that are no longer used. No betting or gambling words; bees "fly off", never die.
- **Hive card** tracks every material (add rows for seeds, forager bees, guard bees, pollen, bee bread). Its title becomes the hive's name ("A SKEP IN THE GARDEN").
- **Stage 4 removes nothing from the Shop** (Guard Bees were never built there); guards come from the bramble.
- **Building:** if `Honeycomb.exe` is running (Leah often has it open), build into a scratch folder with `-o <scratchpad>/build-check` to check it compiles, and tell Leah to close the app for the real rebuild. Use the `-p:` form for MSBuild options in Git Bash (`/p:` gets turned into a path).
- **Tests:** while working, run `dotnet test tests/SoliBee.Tests/SoliBee.Tests.csproj --filter "FullyQualifiedName~Beekeeper"` from `windows/` (under a second). Run the full suite (about 2 minutes) once before the final commit. Ignore the two intermittent Honeycomb card-game test failures (Leah's decision).
- **Commits:** commit freely, with clear messages and the Co-Authored-By line; stage only the files you changed.

## Working with Leah
- She is a PM and the only tester until she calls Beekeeper beta-ready. She tests by eye: give short numbered hand-test steps with every build, using the debug menu (add "Give a seed", "Finish growing", "+10 pollen").
- **Before starting any change, recommend a model and effort (and whether a new session is better) and wait for her OK.** She is careful with credits.
- Systems first, placeholder numbers in the config, tuning later. Flag real rule conflicts; don't stop for tuning questions.
- Ask before fixing anything that isn't clearly what she reported. She often sends quick layout notes mid-task: finish or commit the current step, then handle them.
- Remind her when it's time for a new session (at the end of a stage, or when the conversation gets long).
