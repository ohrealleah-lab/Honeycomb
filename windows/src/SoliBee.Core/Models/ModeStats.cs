namespace SoliBee.Core.Models;

public class ModeStats
{
    public int GamesPlayed { get; set; }
    public int GamesWon { get; set; }
    public int CurrentStreak { get; set; }
    public int LongestStreak { get; set; }
    public int HighScore { get; set; }
    public int ShortestWinSeconds { get; set; }

    // Sum of TimerSeconds across all wins for this mode — divide by TimedGamesWon for "Avg Winning Time".
    public int TotalWinSeconds { get; set; }

    // Count of GamesWon that were actually timed (i.e. not won in No Stress Mode) — the
    // correct divisor/gate for ShortestWinSeconds/TotalWinSeconds, since those only ever
    // accumulate for timed wins. Using GamesWon instead would show a bogus "0s" fastest
    // win the first time a game is won in No Stress Mode.
    public int TimedGamesWon { get; set; }
}
