namespace SoliBee.Core.Models;

public class BlackjackOptions
{
    public int StartingCredits { get; set; } = 100;
    public int BetPerHand { get; set; } = 1;
    public bool IsSoundEnabled { get; set; } = true;
    public string CardBackTheme { get; set; } = "Vulpera";
    public string FeltColor { get; set; } = "FeltGreen";
    public string CustomFeltColorHex { get; set; } = "#592673";
    public bool IsVignetteEnabled { get; set; } = true;
    public bool IsNoStressMode { get; set; } = false;
}
