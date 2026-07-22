using System;
using System.Collections.Generic;
using System.Linq;

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
    public int FreecellDeckCount { get; set; } = 1;
    public int SpiderSuitCount { get; set; } = 1;

    // Point Highlights: transient "+N"/"-N" popup flashed over the card responsible for
    // a score change. Genuinely per-game (not a single global toggle synced across all
    // three), matching how every other card-game setting in this class is scoped.
    public bool KlondikeShowPointHighlights { get; set; } = true;
    public bool FreecellShowPointHighlights { get; set; } = true;
    public bool SpiderShowPointHighlights { get; set; } = true;

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

    // Theme editor color overrides — null means use the compiled default
    public string? ThemeFaceBackNormal { get; set; }
    public string? ThemeFaceBorderNormal { get; set; }
    public string? ThemeTextRed { get; set; }
    public string? ThemeTextBlackNormal { get; set; }
    public string? ThemeCardShadow { get; set; }

    // Update-check state (see UpdateCheckService). UpdateChecksDisabledAtVersion
    // records which version was running when the user declined, so a later install
    // of anything newer than that can clear the flag automatically.
    public bool UpdateChecksDisabled { get; set; } = false;
    public string? UpdateChecksDisabledAtVersion { get; set; }
    public DateTime? LastUpdateCheckUtc { get; set; }

    // Deep-copies CustomCardBacks (not just the list container) so callers can diff
    // "old vs new" against the live options object — a shallow element copy would let
    // an in-place edit to an existing entry (e.g. the Card Back Editor adjusting scale/
    // offset) mutate the "original" snapshot too, silently defeating Preferences' Cancel.
    public GameOptions Clone()
    {
        var clone = (GameOptions)MemberwiseClone();
        clone.CustomCardBacks = CustomCardBacks.Select(c => new CustomCardBack
        {
            Name     = c.Name,
            FileName = c.FileName,
            Scale    = c.Scale,
            OffsetX  = c.OffsetX,
            OffsetY  = c.OffsetY,
        }).ToList();
        clone.HiddenDefaultCardBacks = new List<string>(HiddenDefaultCardBacks);
        clone.CustomBackgrounds = CustomBackgrounds.Select(b => new CustomBackground
        {
            Name     = b.Name,
            FileName = b.FileName,
            Scale    = b.Scale,
            OffsetX  = b.OffsetX,
            OffsetY  = b.OffsetY,
        }).ToList();
        return clone;
    }
}
