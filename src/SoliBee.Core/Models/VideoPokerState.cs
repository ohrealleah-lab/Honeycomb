using System.Collections.Generic;

namespace SoliBee.Core.Models;

public class VideoPokerState
{
    public VideoPokerPhase Phase { get; set; } = VideoPokerPhase.Deal;
    public List<Card> Hand { get; set; } = new();
    public bool[] HeldSlots { get; set; } = new bool[5];
    public int SessionCredits { get; set; } = 100;
    public int CurrentBet { get; set; } = 1;
    public int LastPayout { get; set; }
    public string LastHandName { get; set; } = "";
    public bool[] WinningCardMask { get; set; } = new bool[5];

    // Toolbar-compatible alias used by MainWindow bindings
    public int MovesCount => 0;
}
