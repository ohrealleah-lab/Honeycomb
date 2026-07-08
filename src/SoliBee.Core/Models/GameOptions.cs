using System.Collections.Generic;

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
    public FeltColorTheme FeltColor { get; set; } = FeltColorTheme.FeltGreen;
    public string CardBackTheme { get; set; } = "Vulpera";
    public bool IsTimed { get; set; } = true;
    public bool IsSoundEnabled { get; set; } = true;
    public bool IsVegasScoring { get; set; } = false;
    public bool IsDrawConstraintsEnabled { get; set; } = false;
    public bool IsFinalFantasyMode { get; set; } = false;
    public int CustomFeltColorRevision { get; set; } = 0;
    public string CustomFeltColorHex { get; set; } = "#592673";
    public double CardBackScale { get; set; } = 1.0;
    public double CardBackOffsetX { get; set; } = 0.0;
    public double CardBackOffsetY { get; set; } = 0.0;
    public bool IsStatusBarVisible { get; set; } = true;
    public bool HideHintButton { get; set; } = false;
    public bool HideStatsButton { get; set; } = false;
    public bool HideZoomControls { get; set; } = false;
    public int FreecellDeckCount { get; set; } = 1;
    public int SpiderSuitCount { get; set; } = 1;

    public bool IsVignetteEnabled { get; set; } = true;
    public bool HasAppliedDefaultTheme { get; set; } = false;
    public string LastGameMode { get; set; } = "SolitaireDraw1";

    // Per-game zoom levels (LayoutTransform scale, 0.6–2.0)
    public double KlondikeZoom    { get; set; } = 1.0;
    public double FreecellZoom     { get; set; } = 1.0;
    public double SpiderZoom      { get; set; } = 1.0;
    public double VideoPokerZoom  { get; set; } = 1.0;

    // Per-game default zoom (restored by Reset Zoom / set by "Make Current Zoom Default")
    public double KlondikeDefaultZoom    { get; set; } = 1.0;
    public double FreecellDefaultZoom     { get; set; } = 1.0;
    public double SpiderDefaultZoom      { get; set; } = 1.0;
    public double VideoPokerDefaultZoom  { get; set; } = 1.0;
    public double BlackjackDefaultZoom   { get; set; } = 1.0;

    // Debug option to scale the vignette (0.5–2.0)
    public double VignetteScale   { get; set; } = 1.0;

    // Per-game window size (normal/restored size + maximize flag)
    public double KlondikeWidth      { get; set; } = 1120;
    public double KlondikeHeight     { get; set; } = 950;
    public bool   KlondikeMaximized  { get; set; } = false;
    public double FreecellWidth       { get; set; } = 1200;
    public double FreecellHeight      { get; set; } = 1050;
    public bool   FreecellMaximized   { get; set; } = false;
    public double SpiderWidth        { get; set; } = 1500;
    // Tall enough that a fully-built 13-card same-suit run (K down to Ace) fits
    // without scrolling — see MainWindow.ComputeBoardMinSize for the matching floor.
    public double SpiderHeight       { get; set; } = 950;
    public bool   SpiderMaximized    { get; set; } = false;
    public double VideoPokerWidth    { get; set; } = 1000;
    public double VideoPokerHeight   { get; set; } = 700;
    public bool   VideoPokerMaximized { get; set; } = false;
    public double BlackjackZoom      { get; set; } = 1.0;
    public double BlackjackWidth     { get; set; } = 1000;
    public double BlackjackHeight    { get; set; } = 950;
    public bool   BlackjackMaximized { get; set; } = false;

    // Theme editor color overrides — null means use the compiled default
    public string? ThemeFaceBackNormal { get; set; }
    public string? ThemeFaceBackFF { get; set; }
    public string? ThemeFaceBorderNormal { get; set; }
    public string? ThemeFaceBorderFF { get; set; }
    public string? ThemeFaceBorderFFCard { get; set; }
    public string? ThemeTextRed { get; set; }
    public string? ThemeTextRedFF { get; set; }
    public string? ThemeTextBlackNormal { get; set; }
    public string? ThemeTextBlackFF { get; set; }
    public string? ThemeCardShadow { get; set; }

    // Shallow copy so callers can diff "old vs new" against the live options object —
    // mutating the same instance in place would make any before/after comparison a no-op.
    public GameOptions Clone()
    {
        var clone = (GameOptions)MemberwiseClone();
        clone.CustomCardBacks = new List<CustomCardBack>(CustomCardBacks);
        return clone;
    }
}
