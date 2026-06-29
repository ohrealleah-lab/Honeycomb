namespace SoliBee.Core.Models;

public class VideoPokerOptions
{
    public VideoPokerVariant Variant { get; set; } = VideoPokerVariant.JacksOrBetter;
    public int StartingCredits { get; set; } = 100;
    public int BetPerHand { get; set; } = 1;
    public bool IsSoundEnabled { get; set; } = true;
    public bool HideStatsButton { get; set; }
    public bool HideHintButton { get; set; }
    public string CardBackTheme { get; set; } = "Vulpera";
    public string FeltColor { get; set; } = "FeltGreen";
    public string CustomFeltColorHex { get; set; } = "#592673";
    public bool IsFinalFantasyMode { get; set; }
    public bool IsVignetteEnabled { get; set; } = true;
}
