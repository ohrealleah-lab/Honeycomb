namespace SoliBee.Core.Models;

public class BlackjackStatistics
{
    public int HandsPlayed { get; set; }
    public int HandsWon { get; set; }
    public int HandsLost { get; set; }
    public int HandsPushed { get; set; }
    public int Blackjacks { get; set; }
    public int TotalCreditsWon { get; set; }
    public int TotalCreditsWagered { get; set; }
}
