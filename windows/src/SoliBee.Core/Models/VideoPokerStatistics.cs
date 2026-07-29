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

    // Keyed by rank rather than HandCounts' by-name lookup, since the Deuces Wild
    // paytable's two royal-flush entries are named "Natural Royal"/"Wild Royal" instead
    // of "Royal Flush" — matches Mac's rank-based royalFlushCount.
    public int RoyalFlushCount { get; set; }
    public int CurrentStreak { get; set; }
    public int LongestStreak { get; set; }

    // Toolbar-compatible aliases used by MainWindow bindings
    public int GamesPlayed => TotalHands;
    public int GamesWon    => WinningHands;
}
