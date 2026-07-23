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
    
    public int? PlayerChaosIndex { get; set; }
    public int? OpponentChaosIndex { get; set; }

    public Stack<HoneycombSnapshot> UndoStack { get; set; } = new();

    public int PlayerScore { get; set; }
    public int OpponentScore { get; set; }
    
    public bool IsSuddenDeath { get; set; }
}
