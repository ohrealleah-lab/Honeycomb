namespace SoliBee.Core.Models;

public class ModeStats
{
    public int GamesPlayed { get; set; }
    public int GamesWon { get; set; }
    public int CurrentStreak { get; set; }
    public int LongestStreak { get; set; }
    public int HighScore { get; set; }
    public int ShortestWinSeconds { get; set; }

    // Sum of TimerSeconds across all wins for this mode — divide by GamesWon for "Avg Winning Time".
    public int TotalWinSeconds { get; set; }
}
