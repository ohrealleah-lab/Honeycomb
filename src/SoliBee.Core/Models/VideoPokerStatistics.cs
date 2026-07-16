using System.Collections.Generic;

namespace SoliBee.Core.Models;

public class VideoPokerStatistics
{
    public int TotalHands { get; set; }
    public int WinningHands { get; set; }
    public long TotalCreditsWon { get; set; }
    public long TotalCreditsWagered { get; set; }
    public int BiggestPay { get; set; }
    public int Rebuys { get; set; }
    public Dictionary<string, int> HandCounts { get; set; } = new();
    public int CurrentStreak { get; set; }
    public int LongestStreak { get; set; }

    // Toolbar-compatible aliases used by MainWindow bindings
    public int GamesPlayed => TotalHands;
    public int GamesWon    => WinningHands;
}
