using System.Collections.Generic;

namespace SoliBee.Core.Models;

public class GameStatistics
{
    public int GamesPlayed { get; set; }
    public int GamesWon { get; set; }
    public int CurrentStreak { get; set; }
    public int LongestStreak { get; set; }
    public int VegasHighScore { get; set; }
    public int VegasCumulativeScore { get; set; }
    public int StandardHighScore { get; set; }
    public int ShortestWinSeconds { get; set; }

    // Sum of TimerSeconds across all Klondike wins — divide by GamesWon for "Avg Winning Time".
    public int TotalWinSeconds { get; set; }

    // Freecell per-mode stats: keys are "standard_1deck", "standard_2deck". Freecell has
    // no Vegas mode of its own; any legacy "vegas_*" entries are merged in by
    // StatsService.MigrateFreecellVegasStats.
    public Dictionary<string, ModeStats> FreecellStatsByMode { get; set; } = new();

    // Spider per-suit stats: keys are "1", "2", "4"
    public Dictionary<string, ModeStats> SpiderStatsBySuit { get; set; } = new();
}
