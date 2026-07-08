namespace SoliBee.Core.Models;

public class VideoPokerOptions
{
    public VideoPokerVariant Variant { get; set; } = VideoPokerVariant.JacksOrBetter;
    public int StartingCredits { get; set; } = 100;
    public int BetPerHand { get; set; } = 1;
    public bool IsSoundEnabled { get; set; } = true;
    public string CardBackTheme { get; set; } = "Vulpera";
    public string FeltColor { get; set; } = "FeltGreen";
    public string CustomFeltColorHex { get; set; } = "#592673";
    public bool IsFinalFantasyMode { get; set; }
    public bool IsVignetteEnabled { get; set; } = true;
    public bool IsNoStressMode { get; set; } = false;

    // Shallow copy so callers can snapshot "before edits" and restore it later
    // (e.g. Preferences' Cancel button) without aliasing the live instance.
    public VideoPokerOptions Clone() => (VideoPokerOptions)MemberwiseClone();
}
