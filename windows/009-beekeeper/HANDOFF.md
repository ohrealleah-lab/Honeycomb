# Beekeeper: handoff to a Windows session

**Where we are (2026-11-07):** Phases 1–4 are built and committed (`2e3b9c4c`). Engine, saving, offline earnings, view model, coordinator wiring and the screen all exist. 611 tests pass on Mac. **The screen has never been run by eye**: nobody has seen it yet.

**Read first:** `spec.md` (v3), `plan.md` (includes the MainWindow audit), `tasks.md`, and `Beekeeper/EARLY_LOOP_RULES.md`. Leah's notes win over Gemini's files; flag conflicts, don't decide them.

## Do next, in order
1. `dotnet build` and `dotnet test SoliBee.sln` from `windows/`. Expect 611 passing.
2. Run the app. Fix anything that crashes or looks broken on Beekeeper. Work through the hand-test list in `tasks.md` Phase 4 with Leah.
3. **T037**: check every built-in theme for readable text.
4. **Phase 5 (words):** move the English in `src/SoliBee.Desktop/Views/BeekeeperText.cs` into `tools/Honeycomb_Localization.xlsx`, add Spanish (draft, Leah reviews), run `python3 tools/generate_localization.py`, review the diff. Add the Help page. Scan for gambling words (FR-009). Check the log re-translates on language change.
5. **Phase 6:** second `/analyze`, then T053 (update `windows/CLAUDE.md` six → seven games and the product-rule exceptions in `mac/CLAUDE.md`), Windows publish + smoke test, T055 (refresh stale `UI_SPEC.md`; ask Leah before editing Gemini's files).

## Things to know
- Windows is the reference for Beekeeper (deliberate break from "Mac is the source of truth"). Not in this build: candles/Workshop, roles, Smoker, tool upgrades, special bees, wasps, seasons, swarming.
- Beekeeper's hive is created on first open and keeps ticking while another game is on screen. It has no Undo, Hint, Restart, stats or idle nudge.
- The screen never scales to fit (it scrolls sideways); window size is remembered via new `BeekeeperWidth/Height/Maximized` options.
- Commit freely, but push only when Leah says "push". Stage files only at commit time. No accessibility work.
- Leah is a PM: she hand-tests visually; give her short numbered test steps with every fix, and ask before fixing anything that isn't clearly what she reported.
