using System;
using System.Collections.Generic;
using System.Linq;

namespace SoliBee.Core.Models;

public enum BlackjackPhase { Betting, Playing, DealerTurn, Result }

public enum BlackjackHandResult { Pending, Won, Lost, Push, Blackjack }

public class BlackjackHand
{
    public List<Card> Cards { get; set; } = new();
    public int Bet { get; set; } = 1;
    public bool IsDoubled { get; set; }
    public bool IsStood { get; set; }
    public bool FromSplit { get; set; }
    public BlackjackHandResult Result { get; set; } = BlackjackHandResult.Pending;

    // Full value (all cards, regardless of IsFaceUp) — used for game logic
    public (int Value, bool IsSoft) ComputeValue()
    {
        int value = 0, aces = 0;
        foreach (var c in Cards)
        {
            if (c.Rank == 1) { aces++; value += 11; }
            else value += Math.Min(c.Rank, 10);
        }
        while (value > 21 && aces > 0) { value -= 10; aces--; }
        return (value, aces > 0);
    }

    // Face-up cards only — used for display during Playing phase
    public (int Value, bool IsSoft) ComputeVisibleValue()
    {
        int value = 0, aces = 0;
        foreach (var c in Cards.Where(c => c.IsFaceUp))
        {
            if (c.Rank == 1) { aces++; value += 11; }
            else value += Math.Min(c.Rank, 10);
        }
        while (value > 21 && aces > 0) { value -= 10; aces--; }
        return (value, aces > 0);
    }

    public bool IsBust       => ComputeValue().Value > 21;
    public bool IsBlackjack  => !FromSplit && Cards.Count == 2 && ComputeValue().Value == 21;
    public bool IsComplete   => IsStood || IsBust || IsDoubled || IsBlackjack || ComputeValue().Value == 21;
}

public class BlackjackState
{
    public BlackjackPhase      Phase           { get; set; } = BlackjackPhase.Betting;
    public List<BlackjackHand> PlayerHands     { get; set; } = new() { new() };
    public BlackjackHand       DealerHand      { get; set; } = new();
    public int                 ActiveHandIndex { get; set; } = 0;
    public int                 Credits         { get; set; } = 100;
    public int                 CurrentBet      { get; set; } = 1;
    public bool                IsSplit         { get; set; }
    public int                 LastNetResult   { get; set; }
}
