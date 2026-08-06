using System;
using System.Collections.Generic;

namespace SoliBee.Core.Models;

public enum HoneycombPhase
{
    PreMatch,
    Playing,
    Result
}

public class HoneycombSnapshot
{
    public HoneycombBoard Board { get; set; } = new();
    public List<HoneycombCard> PlayerHand { get; set; } = new();
    public List<HoneycombCard> OpponentHand { get; set; } = new();
    public HashSet<Guid> PlayerRevealedIds { get; set; } = new();
    public HashSet<Guid> OpponentRevealedIds { get; set; } = new();
    public int CurrentTurn { get; set; }
    public int CardsCapturedThisMatch { get; set; }
    public int? PlayerChaosIndex { get; set; }
    public int? OpponentChaosIndex { get; set; }
}

public class HoneycombState
{
    public HoneycombPhase Phase { get; set; } = HoneycombPhase.PreMatch;
    public HoneycombBoard Board { get; set; } = new();
    public List<HoneycombCard> PlayerHand { get; set; } = new();
    public List<HoneycombCard> PlayerStartingDeck { get; set; } = new();
    public List<HoneycombCard> OpponentHand { get; set; } = new();
    public HashSet<Guid> PlayerRevealedIds { get; set; } = new();
    public HashSet<Guid> OpponentRevealedIds { get; set; } = new();
    
    public List<HoneycombRule> ActiveRules { get; set; } = new();
    
    public int CurrentTurn { get; set; } = 1;

    public int CardsCapturedThisMatch { get; set; } = 0;
    public bool HasStolenThisMatch { get; set; } = false;

    // Steal Protection: once a stuck rematch chain trips this (see
    // HoneycombViewModel.ApplyStealProtection), ANY not-yet-unlocked card left on the
    // board becomes stealable for this win, not just one actually captured from the
    // opponent this round. Mirrors the Swift port's stealProtectionActive.
    public bool StealProtectionActive { get; set; } = false;
    
    public int? PlayerChaosIndex { get; set; }
    public int? OpponentChaosIndex { get; set; }

    public Stack<HoneycombSnapshot> UndoStack { get; set; } = new();

    public int PlayerScore { get; set; }
    public int OpponentScore { get; set; }
    
    public bool IsSuddenDeath { get; set; }

    // Gates the win/lose/tie overlay separately from Phase — Phase flips to Result
    // immediately once the match is decided (SettleMatch), but the overlay itself
    // waits an extra beat (see SettleMatch's ShowPostGamePromptDelayMs) so the player
    // sees the final board fully settle before it's covered. Mirrors the Swift port's
    // HoneycombViewModel.showPostGamePrompt.
    public bool ShowPostGamePrompt { get; set; }

    // Ids of the two cards involved in a Swap-rule trade, while their reveal
    // animation is playing at the start of a match. Empty the rest of the time.
    public HashSet<Guid> SwapHighlightIds { get; set; } = new();

    // Point Highlights (Options.ShowPointHighlights): while non-null, the just-placed
    // card at this board cell flashes its winning stat edge(s) — set 0..3 (Top/Right/
    // Bottom/Left) — for a beat before the capture actually flips. Null the rest of the
    // time (including when the option is off, in which case captures apply instantly).
    public int? PointHighlightCellIndex { get; set; }
    public HashSet<int> PointHighlightStatIndices { get; set; } = new();

    // UniqueInstanceId(s) of whichever board card(s) just directly *caused* a capture
    // (the placed card itself, or a Bomb Shelter/Hive Swarm reveal that captured a
    // neighbor) — not the cards they captured. HoneycombCardView pops the attacker's
    // own scale off this, so a capture reads as the attacking card lunging/growing,
    // not the victim swelling up. Transient like PointHighlight above — set at the
    // same moment the capture commits, cleared shortly after. Mirrors the Swift
    // port's captureAttackerIds.
    public HashSet<Guid> CaptureAttackerIds { get; set; } = new();
}
