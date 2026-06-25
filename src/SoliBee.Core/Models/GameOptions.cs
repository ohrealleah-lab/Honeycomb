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
    public int BeecellDeckCount { get; set; } = 1;
    public int SpiderSuitCount { get; set; } = 1;

    public bool HasAppliedDefaultTheme { get; set; } = false;

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
}
