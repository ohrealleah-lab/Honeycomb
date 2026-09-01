using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using SoliBee.Core.Localization;

namespace SoliBee.Core.Models;

public enum FeltColorTheme
{
    FeltGreen,
    Crimson,
    RoyalBlue,
    Charcoal,
    Desert,
    Custom
}

public class GameOptions
{
    public List<CustomCardBack> CustomCardBacks { get; set; } = new();
    // Built-in card back designs (Vulpera, Moogle, etc.) the user has chosen to delete
    // from their picker — the underlying bundled asset isn't removed, just hidden from
    // the list, since it's shipped with the app rather than owned by the user.
    public List<string> HiddenDefaultCardBacks { get; set; } = new();
    public FeltColorTheme FeltColor { get; set; } = FeltColorTheme.FeltGreen;
    public string CardBackTheme { get; set; } = "Vulpera";
    public List<CustomBackground> CustomBackgrounds { get; set; } = new();
    // null/"" = "None (Felt Color)"
    public string? BackgroundName { get; set; } = null;
    public double BackgroundScale { get; set; } = 1.0;
    public double BackgroundOffsetX { get; set; } = 0.0;
    public double BackgroundOffsetY { get; set; } = 0.0;
    public bool IsSoundEnabled { get; set; } = true;
    public bool IsVegasScoring { get; set; } = false;
    public bool IsDrawConstraintsEnabled { get; set; } = false;
    public int CustomFeltColorRevision { get; set; } = 0;
    public string CustomFeltColorHex { get; set; } = "#592673";
    public double CardBackScale { get; set; } = 1.0;
    public double CardBackOffsetX { get; set; } = 0.0;
    public double CardBackOffsetY { get; set; } = 0.0;
    public bool IsStatusBarVisible { get; set; } = true;
    public bool HideHintButton { get; set; } = false;
    public bool IsAlwaysOnTop { get; set; } = false;
    // App-wide UI language, same single-source-of-truth pattern as FeltColor above —
    // not per-game. Mirrors the Mac/iOS port's AppCoordinator.language.
    public AppLanguage Language { get; set; } = AppLanguage.English;
    public int FreecellDeckCount { get; set; } = 1;
    public int SpiderSuitCount { get; set; } = 1;

    // "Honey Mode (Flavor)" — renamed and repurposed from the old per-game Point
    // Highlights toggles (KlondikeShowPointHighlights/FreecellShowPointHighlights/
    // SpiderShowPointHighlights/HoneycombOptions.ShowPointHighlights, now removed). A
    // single global switch, matching IsSoundEnabled/IsNoStressMode above: controls both
    // the "+N"/"-N" score popups in every game and, via BannerCatalog reading this
    // field directly, whether Repeatable Flavor/Ambiance banners fire at all across all
    // 6 games. Achievement/Milestone banners are never affected. No migration from the
    // old per-game values — everyone gets a fresh default of on.
    public bool HoneyMode { get; set; } = true;

    // When on, banner/toast flashes stay up (no auto-dismiss timer) and the game is
    // effectively paused until the player clicks the toast or a card, at which point it
    // dismisses and the banner queue resumes. Same single global switch pattern as
    // HoneyMode above, read directly by every game (see FlashToast.Flash and each game
    // view's Vm_OnFlashBanner). Default off — preserves today's auto-dismiss behavior
    // unless the player opts in.
    public bool ManuallyDismissBanners { get; set; } = false;

    // Hides the centered Solibee watermark drawn behind every game's board.
    public bool HideBee { get; set; } = false;

    // Bee watermark per-game scale/position — calibrated on Windows' own board
    // proportions (read from the local Windows install's settings.json) and baked in
    // here as Windows' shipped default, mirroring how mac's own calibrated values were
    // baked in as its default. The dev calibration sliders (WatermarkScaleSection in
    // PreferencesView.axaml + its code-behind) are removed now that these are final —
    // Spider/Video Poker/Blackjack's values below are a SECOND bake-in, redone after
    // 38a00f9 changed how those three anchor their watermark and reset their offsets to
    // 0 (the first round's values were calibrated against the earlier, now-fixed anchor
    // and stopped meaning anything once that landed).
    public double KlondikeWatermarkScale   { get; set; } = 1.2956;
    public double FreecellWatermarkScale   { get; set; } = 1.2956;
    public double SpiderWatermarkScale     { get; set; } = 1.419;
    public double VideoPokerWatermarkScale { get; set; } = 1130;
    public double BlackjackWatermarkScale  { get; set; } = 1870;
    public double HoneycombWatermarkScale  { get; set; } = 1.57;

    public double KlondikeWatermarkOffsetX   { get; set; } = -120.0;
    public double KlondikeWatermarkOffsetY   { get; set; } = -72.0;
    public double FreecellWatermarkOffsetX   { get; set; } = -120.0;
    public double FreecellWatermarkOffsetY   { get; set; } = -72.0;
    public double SpiderWatermarkOffsetX     { get; set; } = -41.026;
    public double SpiderWatermarkOffsetY     { get; set; } = -212.821;
    public double VideoPokerWatermarkOffsetX { get; set; } = -15.385;
    public double VideoPokerWatermarkOffsetY { get; set; } = 23.077;
    public double BlackjackWatermarkOffsetX  { get; set; } = -17.949;
    public double BlackjackWatermarkOffsetY  { get; set; } = 74.359;
    public double HoneycombWatermarkOffsetX  { get; set; } = -312.0;
    public double HoneycombWatermarkOffsetY  { get; set; } = -240.0;

    public bool IsVignetteEnabled { get; set; } = true;
    // Turns off timers (solitaire) and enables free play (VP/Blackjack — hides the
    // credit/bet board and betting controls; hands are played without wagering).
    public bool IsNoStressMode { get; set; } = false;
    public bool HasAppliedDefaultTheme { get; set; } = false;
    // Id of the saved theme (from ThemeService.LoadThemes) most recently applied or
    // saved-as — null means "never explicitly applied one" (treated like Default for
    // warning purposes). Not touched by manual color/felt/art edits, so comparing
    // live options against this theme's saved snapshot detects unsaved drift.
    public Guid? ActiveThemeId { get; set; } = null;
    public string LastGameMode { get; set; } = "SolitaireDraw1";
    public int HoneycombActiveDeckIndex { get; set; } = 0;
    public List<int> PlayerDeckIds { get; set; } = new List<int> { 1, 2, 3, 4, 5 };

    // Debug option to scale the vignette (0.5–2.0)
    public double VignetteScale   { get; set; } = 1.0;

    // Per-game window size (normal/restored size + maximize flag)
    public double KlondikeWidth      { get; set; } = 1120;
    public double KlondikeHeight     { get; set; } = 1100;
    public bool   KlondikeMaximized  { get; set; } = false;
    public double FreecellWidth       { get; set; } = 1200;
    public double FreecellHeight      { get; set; } = 1200;
    public bool   FreecellMaximized   { get; set; } = false;
    public double SpiderWidth        { get; set; } = 1500;
    // Tall enough that a fully-built 13-card same-suit run (K down to Ace) fits
    // without scrolling — see MainWindow.ComputeBoardMinSize for the matching floor.
    public double SpiderHeight       { get; set; } = 1100;
    public bool   SpiderMaximized    { get; set; } = false;
    public double VideoPokerWidth    { get; set; } = 1000;
    public double VideoPokerHeight   { get; set; } = 700;
    public bool   VideoPokerMaximized { get; set; } = false;
    public double BlackjackWidth     { get; set; } = 1000;
    public double BlackjackHeight    { get; set; } = 920;
    public bool   BlackjackMaximized { get; set; } = false;
    public double HoneycombWidth     { get; set; } = 1120;
    public double HoneycombHeight    { get; set; } = 800;
    public bool   HoneycombMaximized { get; set; } = false;

    // Theme editor color overrides — null means use the compiled default
    public string? ThemeFaceBackNormal { get; set; }
    public string? ThemeFaceBorderNormal { get; set; }
    public string? ThemeTextRed { get; set; }
    public string? ThemeTextBlackNormal { get; set; }
    public string? ThemeCardShadow { get; set; }
    public string? ThemeHintHighlight { get; set; }

    // Deep-copies every field via a JSON round-trip (same approach as ThemeService's
    // ClonePreset, and for the same reason its own comment gives: a hand-listed field-
    // by-field copy would silently drop any new mutable/reference field added later
    // instead of failing to compile). Callers rely on this being a true deep copy to diff
    // "old vs new" against the live options object — a shallow copy would let an in-place
    // edit to an existing entry (e.g. the Card Back Editor adjusting scale/offset) mutate
    // the "original" snapshot too, silently defeating Preferences' Cancel.
    public GameOptions Clone() =>
        JsonSerializer.Deserialize<GameOptions>(JsonSerializer.Serialize(this))!;
}
