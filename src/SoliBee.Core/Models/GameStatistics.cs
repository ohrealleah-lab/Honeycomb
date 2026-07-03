using System.Collections.Generic;

namespace SoliBee.Core.Models;

public class GameStatistics
{
    public int GamesPlayed { get; set; }
    public int GamesWon { get; set; }
    public int CurrentStreak { get; set; }
    public int LongestStreak { get; set; }
    public int VegasHighScore { get; set; }
    public int StandardHighScore { get; set; }
    public int ShortestWinSeconds { get; set; }

    // Freecell per-mode stats: keys are "standard_1deck", "vegas_1deck", "standard_2deck", "vegas_2deck"
    public Dictionary<string, ModeStats> FreecellStatsByMode { get; set; } = new();

    // Spider per-suit stats: keys are "1", "2", "4"
    public Dictionary<string, ModeStats> SpiderStatsBySuit { get; set; } = new();
}
