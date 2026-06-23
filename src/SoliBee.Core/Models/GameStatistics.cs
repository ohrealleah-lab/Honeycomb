namespace SoliBee.Core.Models;

public class GameStatistics
{
    public int GamesPlayed { get; set; }
    public int GamesWon { get; set; }
    public int CurrentStreak { get; set; }
    public int LongestStreak { get; set; }
    public int VegasHighScore { get; set; }
    public int StandardHighScore { get; set; }
}
