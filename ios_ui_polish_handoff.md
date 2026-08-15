# iOS UI polish handoff (for Gemini)

## Status: done — implemented directly, not handed off
All 8 items below were implemented directly in this session rather than handed to
Gemini (see commits: face card letters/borders, top-bar buttons + flavor-text wiring,
and the Themes tab additions). Left in place as a record of the investigation and
reasoning behind each fix — the file:line references below describe the *pre-fix*
state, not what's currently in the codebase.

## Context
A round of manual iOS testing turned up 8 UI gaps between the iOS touch views (`ios/Honeycomb/`) and the mac reference implementation (`mac/src/`) they're meant to track. This handoff covers all 8. Two of them (#2, #5) turned out to have different scope than initially assumed once investigated — read those sections carefully before starting, since the actual work needed there isn't what the one-line description suggests.

Read `ios_localization_handoff.md` (repo root, if still present) for the general shape of a handoff like this — same idea, different topic. General ground rules that apply here too:
- Match mac's implementation exactly where one exists (same values, same components) rather than inventing a new visual language for iOS.
- Build/verify on every change (see "Workflow" below) — don't batch all 8 items into one unverified pass.
- Small, separately-verifiable commits per item beat one giant commit, per this repo's normal working style.

## Known simulator gotcha (read before manually testing)
Earlier in this session, the iOS Simulator got into a state where the entire device — including the Home Screen, not just this app — rendered visibly rotated 90° despite reporting a portrait point-space (820x1180) for tap coordinates. Screenshots looked landscape-rotated while tap coordinates still worked correctly when scaled (not rotated) against the raw image. If you hit this: taps still work using straight proportional scaling from screenshot-pixel-position to the reported point-space (no rotation math needed), but visual verification via screenshot is unreliable until the simulator's orientation state is sorted out. Don't burn much time fighting this — a fresh simulator boot (or asking the user to eyeball it themselves in the real Simulator app) is more reliable than trying to compensate for it programmatically.

---

## 1. Honeycomb toast/banner positioning

**Symptom:** "Toasts launch in top of screen, not middle of screen."

**Current iOS code** — `ios/Honeycomb/Games/HoneycombTouchView.swift`, `flashBanners` (~line 683):
```swift
private var flashBanners: some View {
    VStack {
        if showingRuleBanner {
            bannerCapsule(ruleBannerText, color: .yellow, onDismiss: dismissRuleBanner)
        }
        if showNoHintsBanner {
            bannerCapsule(coordinator.L(.noHintsBanner), color: .orange)
        }
    }
    .frame(maxHeight: .infinity, alignment: .top)   // pins to top
    .padding(.top, 60)                              // extra top offset
    .allowsHitTesting(showingRuleBanner)
}
```
`bannerCapsule` (~line 701) renders a small pill (`Capsule`, `.title3.weight(.black)`, `.black.opacity(0.75)` background) — visually a different, smaller component than mac's, not just a positioning difference.

**Mac reference** — the shared `FlashBannerView` (`mac/src/Views/FlashBannerView.swift`), used identically by *every* game including Honeycomb (`mac/src/Honeycomb/Views/HoneycombView.swift:605-627`):
```swift
// FlashBannerView.swift
var body: some View {
    VStack {
        Spacer(minLength: 8)
        Text(message)
            .font(.system(size: 60, weight: .black))
            ...
        Spacer(minLength: 8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)   // symmetric Spacers => true centering
    .allowsHitTesting(onDismiss != nil)
    .transition(.opacity)
}
```
Mac's Honeycomb rule/no-hints banners use this exact same centered component as every other game, at 60pt text.

**Fix:** Confirm `FlashBannerView.swift` has no AppKit-only APIs (a quick read should confirm — it looked SwiftUI-only during investigation), then replace `flashBanners`/`bannerCapsule` in `HoneycombTouchView.swift` with `FlashBannerView` directly, matching mac's call sites. If `FlashBannerView` turns out to need mac-only APIs, the fallback is: change `flashBanners`'s `alignment: .top` to the default (centered) and drop `.padding(.top, 60)` — a smaller fix that fixes positioning but leaves iOS's banner visually smaller than mac's. Prefer the first approach (shared component) unless it's genuinely blocked.

---

## 2. Honeycomb Deck Builder — **premise is false, no gap exists**

Investigation found iOS already has a full deck builder: `ios/Honeycomb/Games/HoneycombDecksSheet.swift` (422 lines), explicitly a "Touch port of the mac app's 'Manage Decks' window" per its own header comment. It has Saved Decks / Card Bank tabs, favoriting, a full `DeckBuilderSheet` with the same 5-star/4-star rarity-cap validation mac has, etc.

The only real difference is **discoverability**, not functionality: mac exposes "Manage Decks" as an always-visible top-toolbar button (`HoneycombView.swift:253-256`, hidden in `.setup`/`.gameOver`/`noStressMode` per mac's own gating). iOS reaches the identical screen one level deeper — hamburger → Options tab → "Manage Decks" row inside `HoneycombSettingsSection` → `HoneycombDecksSheet` (`HoneycombTouchView.swift:60,137,141`).

**This is the same shape of gap as item #6** (top-bar entry point missing, underlying feature present) — don't treat it as separate work. If you do #6's top-bar pass for Honeycomb, decide there whether Manage Decks also deserves a top-bar icon (mac shows it conditionally, so mirror that condition) or whether leaving it in the Options tab is fine for iPhone's tighter width. No new screen or logic needs building either way.

---

## 3. Honeycomb Ban/Rules should be a top-menu-bar button

**Mac:** `Rules` is a dedicated toolbar button (`HoneycombView.swift:216-219`) opening a full-screen sheet, `HoneycombRulesView` (a standalone struct, `HoneycombView.swift:1199`, with its own `selectedRules`/`bannedRules` state).

**iOS:** No dedicated Rules button and no dedicated Rules screen exist. Two lesser, separate mechanisms currently stand in:
1. A **read-only popover** explaining the currently-active rules, triggered by tapping the rules banner text (`HoneycombTouchView.swift:416-422`) — this doesn't let you change anything.
2. Rule selection + ban list as **`DisclosureGroup`s buried in the Options tab** (`HoneycombTouchView.swift:930` `matchRulesDisclosure`, `:967` `banListDisclosure`) inside `HoneycombSettingsSection`.

There is no `HoneycombRulesView`-equivalent sheet on iOS at all (confirmed zero grep hits).

**Fix, per the user's stated scope** ("for now it can open the existing slide-out"): add a Rules button to iOS's `topBar` (`HoneycombTouchView.swift:209-243`) that opens `SlideDownMenu` with the Options tab active, ideally with the "Match Rules"/"Ban List" `DisclosureGroup`s pre-expanded. `SlideDownMenu` doesn't currently support jumping to a specific tab from outside (its tab selection is private `@State`, see item #6) — that plumbing is shared work between this item and #6, do it once and reuse.

---

## 4. "Flavor Missing" — banner/flavor-text pipeline not wired on 5 of 6 iOS games

This is the biggest item in this batch — budget accordingly.

**The good news:** the actual flavor-text *generation* is entirely shared and already working — `shared/*/ViewModels/*ViewModel.swift` for all 6 games (Klondike, Beecell, Spider, VideoPoker, Blackjack, Honeycomb) already call `BannerCatalog.shared.fire(...)` and expose `flashBanner`/`flashBannerTrigger` properties. Nothing needs to change in `shared/`.

**The gap:** on iOS, only `HoneycombTouchView.swift` (line ~187-190) actually listens for its trigger (`viewModel.flashRuleBannerTrigger`) and displays something (see item #1 for what/how). The other five iOS touch views never reference `flashBanner`/`flashBannerTrigger`/`BannerCatalog` at all (confirmed zero grep hits in each):
- `ios/Honeycomb/Games/KlondikeTouchView.swift`
- `ios/Honeycomb/Games/BeecellTouchView.swift`
- `ios/Honeycomb/Games/SpiderTouchView.swift`
- `ios/Honeycomb/Games/VideoPokerTouchView.swift`
- `ios/Honeycomb/Games/BlackjackTouchView.swift`

So on those 5 games, milestone banners, idle nudges, "no hints available," and every other flavor-text moment are being generated by the shared ViewModel and then silently dropped — never rendered.

**Mac reference** for the wiring pattern (repeat this shape once per game, iOS-side):
```
mac/src/Views/GameView.swift:760-761        .onChange(of: viewModel.flashBannerTrigger) { ... }
mac/src/Beecell/Views/BeecellView.swift:765-766
mac/src/Spider/Views/SpiderView.swift:621-622
mac/src/VideoPoker/Views/VideoPokerView.swift:325-326
mac/src/Blackjack/Views/BlackjackView.swift:270-271
```
plus each game's `FlashBannerView(...)` render site (`GameView.swift:563,567`, `BeecellView.swift:598,602`, `SpiderView.swift:456,460`, `VideoPokerView.swift:157`, `BlackjackView.swift:153`).

**Fix:** for each of the 5 iOS touch views, add the `onChange(of: viewModel.flashBannerTrigger)` listener + a banner-display state var + `FlashBannerView(...)` render site, mirroring mac's exact wiring at the lines above. This is mechanical repetition once the first one is done — do Klondike first, verify it end-to-end (trigger an idle-hint banner or similar and confirm it displays, centered per item #1's fix), then replicate to the other 4.

---

## 5. "Themes missing options" — partially present, several sections genuinely missing (bigger than a quick fix)

**iOS has a Themes tab** (`ios/Honeycomb/Menu/SlideDownMenu.swift`, `MenuTab.themes`), and it does cover: felt color **presets only**, felt vignette toggle, card back picker (bundled + custom), background picker (bundled + custom + none), and a face-card-art entry point (`themeSection`, ~lines 137-247).

**What's missing entirely** (confirmed zero references in `SlideDownMenu.swift`), compared to mac's `ThemesOptionsView.swift`:
- **Saved theme presets** — save/load/rename/delete a whole named theme bundle. Mac: `mac/src/Views/ThemesSectionView.swift`. No iOS equivalent.
- **Custom felt color picker** — mac has a live `ColorPicker` bound to `customFeltRed`/`Green`/`Blue` on `AppCoordinator` (`ThemesOptionsView.swift:307-316`). iOS only exposes the fixed preset swatches — there's no way to reach the custom-RGB felt color at all on iOS currently.
- **Custom card colors** (suit color / card face background / hint-highlight overrides) — mac: `mac/src/Views/CustomCardColorSectionView.swift`, wired in via `ThemesOptionsView.swift:374`. No iOS equivalent.

**Assessment — flag this to the user before starting:** this is closer to "build 3 missing UI sections" than "fix a wiring bug" like the other items in this batch. It's a real, confirmed gap, but it's a materially bigger chunk of work than #1/#3/#4/#7/#8. Recommend treating it as its own follow-up pass rather than folding it into this batch, unless the user explicitly wants it included now — check with them rather than assuming scope.

---

## 6. Options/Themes/game-selection should be top-menu-bar buttons on iOS (opening the existing slide-out is fine for now)

**Mac's top toolbar** (`mac/src/Views/GameView.swift:108-151`, using Klondike as the representative example — same shape on every game):
1. `GameSelectionDropdown` (line 110) — popover listing `GameMode.allCases`
2. New Game
3. Restart
4. Options — opens that game's Options sheet (Themes lives inside it as a sub-panel; mac has no *separate* Themes toolbar button, worth noting so you don't add one iOS doesn't need either)
5. Hint (conditional)
6. Undo
7. Status items (bankroll/score, moves, timer), right-aligned

**iOS's top bar** is a single hamburger icon (`Image(systemName: "line.3.horizontal")`) opening `SlideDownMenu`, confirmed identical across all 6 `*TouchView.swift` files — no direct-access buttons for Game Selection or Options at all. (Aside, not part of this request but worth a one-line fix while in this code: Klondike has no Restart control anywhere on iOS — zero grep hits for "restart" in `KlondikeTouchView.swift`.)

The content the user wants exposed already exists inside `SlideDownMenu` (`MenuTab`: `.games`, `.options`, `.themes`) — this item is purely about adding **entry points**, not building new screens.

**Fix:**
1. `SlideDownMenu.swift`'s tab selection is currently private `@State` initialized to `.games` (~line 24) — change this to accept an initial/external tab (e.g. a `@Binding<MenuTab>` or an `initialTab` init parameter defaulting to `.games`) so callers can jump straight to a specific tab.
2. Add 2 (maybe 3) icon buttons to each game's `topBar` — Game Selection and Options at minimum (mac doesn't have a separate Themes button, so a 3rd "Themes" icon is optional/your call, but if added it should jump straight to `MenuTab.themes`). Each button sets `isMenuOpen = true` and sets the target tab.
3. Reuses the same plumbing item #3 needs (jumping to a specific tab) — do that once, share it.

---

## 7. Card face letters (J/Q/K/A) should show the letter only, no suit icon underneath

**Current iOS** — `ios/Honeycomb/Views/TouchCardView.swift:69-78`:
```swift
} else if card.rank >= 11 {
    // Face cards: large letter over the suit, like the mac dark-mode letters.
    VStack(spacing: height * 0.02) {
        Text(rankText)
            .font(.system(size: width * 0.42, weight: .black, design: .serif))
        Image(systemName: suitSymbol)
            .resizable().aspectRatio(contentMode: .fit)
            .frame(width: width * 0.22)
    }
    .foregroundStyle(suitColor)
}
```
This is exactly the "letter with a suit underneath" the user wants removed.

**Also found while investigating (not explicitly reported, but the same bug):** `card.rank >= 11` excludes Ace (rank 1), so Aces fall into the `else` branch (line ~79-84) and currently render as a bare suit symbol with **no letter at all**. The user's request implies Aces should show "A" the same way — fix the condition too, not just the composition.

**Mac reference:** per `mac/CLAUDE.md`'s "Card rendering" section, mac's *dark-mode* face cards (the actual precedent — iOS's own comment references "mac dark-mode letters") use pre-baked **letter-only PNGs** (`dark_k_red.png`, `dark_j_grey.png`, etc.), rendered full-frame via `FaceCardImageView(fillFrame: true)` — no separate suit glyph composited underneath; suit is implied by color alone (red `#FF4444` vs. grey `#C0C0C0`, per `mac/CLAUDE.md`'s "Dark mode card colors" section).

**Important:** mac's dark-mode letters are image assets, not a live system font — there is no font name/constant in mac's code to diff against. Don't go looking for one. The actionable target is: single centered letter, full-frame-ish sizing (not squeezed into half the card by a sibling icon), suit conveyed by color only.

**Fix:**
1. In the `card.rank >= 11` branch, delete the `Image(systemName: suitSymbol)` line and its `VStack` wrapper — just center `Text(rankText)` alone, sized/positioned to read similarly to mac's full-frame letter PNGs (larger than the current `width * 0.42` is likely appropriate now that it's not sharing vertical space with an icon — eyeball it against a mac screenshot).
2. Change the condition to `card.rank >= 11 || card.rank == 1` (or equivalent) so Ace renders the same way as J/Q/K instead of falling into the suit-only `else` branch.
3. Font choice: iOS's existing `.system(size:, weight: .black, design: .serif)` is a reasonable starting point since there's no mac font to match exactly — but sanity-check the weight/serif-vs-sans choice by eye against how mac's dark-mode letters actually look, and adjust if it reads noticeably different.

---

## 8. Card borders not visible in stacked-card games (Klondike/Beecell/Spider tableaus)

**Current iOS** — `ios/Honeycomb/Views/TouchCardView.swift`:
- The border stroke only exists **inside the `if card.faceUp` branch** (lines ~56-62):
  ```swift
  if card.faceUp {
      RoundedRectangle(cornerRadius: width * 0.07)
          .stroke(Color.black.opacity(0.85), lineWidth: 0.75)
      ...
  } else {
      HoneycombSimpleCardBack()   // no stroke at the TouchCardView level
  }
  ```
  Face-down cards (extremely common in a Klondike/Spider tableau — stock pile, unflipped tableau cards) get no comparable edge from `TouchCardView` itself.
- **No drop shadow anywhere on normal card rendering.** The only `.shadow(...)` in the file (~lines 155,158) is the pulsing hint-highlight glow, unrelated. `KlondikeTouchView.swift:392` has one `.shadow(radius: 8, y: 4)` but it's applied to a dragged/ghost card, not per-card in the tableau.
- Note: the stroke color/width that *is* present for face-up cards (`Color.black.opacity(0.85)`, `lineWidth: 0.75`) already numerically match mac — this isn't a color/opacity bug on the face-up path.

**Mac reference** — `mac/src/Views/CardView.swift:34-49`:
```swift
public var body: some View {
    ZStack {
        if card.faceUp { CardFrontView(...) } else { CardBackView(...) }
    }
    .frame(width: CardDimensions.width, height: CardDimensions.height)
    .background(...)
    .cornerRadius(10)
    .overlay(
        RoundedRectangle(cornerRadius: 10)
            .stroke(outlineColor, lineWidth: 0.75)      // applied uniformly, faceUp or not
    )
    .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1.5)   // present on every card
    ...
}
```

**Likely root cause:** the missing per-card drop shadow is very plausibly the dominant contributor to "borders not visible when stacked" — in a tightly overlapping tableau, it's the shadow (not just a 0.75pt stroke, which is subtle even on mac) that actually separates overlapping card edges visually. The stroke-only-on-faceUp gap compounds it for face-down stacks specifically.

**Fix:**
1. Move the border stroke to apply unconditionally at the `TouchCardView` body level (both `card.faceUp` and not), instead of nested inside the `if card.faceUp` branch.
2. Add `.shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1.5)` to `TouchCardView`'s outer frame, matching mac exactly.
3. Verify specifically in a deep tableau stack (Spider's initial deal is a good stress test — up to 19+ cards in one column) that adjacent card edges are now visually distinguishable.

---

## Workflow

Same as `ios_localization_handoff.md`'s workflow section:
1. `cd mac && swift build` — fast sanity check that shared code still compiles (most of these changes are iOS-only, but #1/#4 touch `FlashBannerView` usage patterns worth double-checking don't accidentally need a mac-side change).
2. `cd mac && make test` — full suite, run before considering any item done if it touched anything under `shared/` (most of these items don't).
3. iOS build: `cd ios && xcodegen generate && xcodebuild -project Honeycomb.xcodeproj -scheme Honeycomb -destination 'generic/platform=iOS Simulator' build`, or open `ios/Honeycomb.xcodeproj` in Xcode directly.
4. Manual verification in the iOS Simulator for each item — see the simulator orientation gotcha above if screenshots look wrong.
5. One commit per item (or per closely-related pair, e.g. #3+#6 sharing the `SlideDownMenu` tab-selection plumbing) rather than one giant commit for all 8 — matches this repo's normal working style, makes review/revert easier if one item needs rework.

## Suggested order

Roughly cheapest/most-isolated first, biggest/most-open-ended last:
1. **#7** (face card letters) — self-contained, one file, clear before/after.
2. **#8** (card borders/shadow) — self-contained, one file, clear before/after.
3. **#1** (toast positioning) — self-contained to `HoneycombTouchView.swift`.
4. **#3 + #6** (top-bar buttons, shared `SlideDownMenu` plumbing) — do together since #3's Rules button and #6's Game Selection/Options buttons need the same tab-jump capability.
5. **#2** — verify the no-op conclusion holds, fold any "should Manage Decks get a top-bar icon" decision into #6's pass, no separate work otherwise.
6. **#4** (flavor text wiring) — biggest mechanical item, 5 games to repeat the same pattern across.
7. **#5** (theme options) — flag scope to the user first; likely deserves its own separate pass rather than being squeezed into this batch.

## What's explicitly NOT in scope here
- Windows — not touched by this handoff.
- Anything under `shared/` — every item above is a display/wiring gap on the iOS view layer; the underlying game logic and ViewModels are already correct and shared with mac.
- Klondike's missing Restart button (noted in passing under item #6) — flagged for awareness, not requested by the user, don't fix it as part of this batch unless asked.
