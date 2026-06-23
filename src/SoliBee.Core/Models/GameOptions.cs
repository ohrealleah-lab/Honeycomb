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
    public FeltColorTheme FeltColor { get; set; } = FeltColorTheme.FeltGreen;
    public string CardBackTheme { get; set; } = "Vulpera";
    public bool IsTimed { get; set; } = true;
    public bool IsSoundEnabled { get; set; } = true;
    public bool IsVegasScoring { get; set; } = false;
    public bool IsDrawConstraintsEnabled { get; set; } = false;
    public int CustomFeltColorRevision { get; set; } = 0;
    public double CardBackScale { get; set; } = 1.0;
    public double CardBackOffsetX { get; set; } = 0.0;
    public double CardBackOffsetY { get; set; } = 0.0;
}
