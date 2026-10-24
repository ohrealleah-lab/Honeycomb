using System.Collections.Generic;

namespace SoliBee.Core.Models;

public class GameStatistics
{
    public int GamesPlayed { get; set; }
    public int GamesWon { get; set; }
    public int CurrentStreak { get; set; }
    public int LongestStreak { get; set; }
    // The best Vegas result, in cents. Starts at the $52 buy-in loss (−5200) — what a game that
    // paid nothing back ends on — so a game that wins back less than its buy-in still counts as
    // a best score, the way it does on Mac. (It used to start at 0, so only a game finishing in
    // profit was ever recorded.)
    public const int VegasHighScoreStart = -5200;
    public int VegasHighScore { get; set; } = VegasHighScoreStart;
    public int VegasCumulativeScore { get; set; }
    public int StandardHighScore { get; set; }
    public int ShortestWinSeconds { get; set; }

    // Sum of TimerSeconds across timed Klondike wins — divide by TimedGamesWon for "Avg Winning Time".
    public int TotalWinSeconds { get; set; }

    // Klondike wins that were actually timed (not won in / partly in No Stress Mode) — the
    // divisor/gate for ShortestWinSeconds/TotalWinSeconds, same as ModeStats.TimedGamesWon.
    // Dividing by GamesWon deflated Avg Winning Time once any untimed win existed and
    // showed a bogus "0s" Fastest Win when every win so far was untimed.
    public int TimedGamesWon { get; set; }

    // Freecell per-mode stats: keys are "standard_1deck", "standard_2deck". Freecell has
    // no Vegas mode of its own; any legacy "vegas_*" entries are merged in by
    // StatsService.MigrateFreecellVegasStats.
    public Dictionary<string, ModeStats> FreecellStatsByMode { get; set; } = new();

    // Spider per-suit stats: keys are "1", "2", "4"
    public Dictionary<string, ModeStats> SpiderStatsBySuit { get; set; } = new();
}
