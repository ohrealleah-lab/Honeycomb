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

    // Set once the win/no-win banner has fully played and faded for the current
    // result, so switching games and back doesn't replay it from scratch — the View
    // is recreated on every game switch and would otherwise have no memory of having
    // already shown it. Reset on the next Deal().
    public bool ResultBannerShown { get; set; }

    // Toolbar-compatible alias used by MainWindow bindings
    public int MovesCount => 0;
}
