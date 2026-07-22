using System;
using System.Collections.Generic;

namespace SoliBee.Core.Models;

public class HoneycombStats
{
    public int GamesPlayed { get; set; }
    public int MatchesWon { get; set; }
    public int MatchesLost { get; set; }
    public int MatchesDrawn { get; set; }
    public int CardsCaptured { get; set; }
    public int CurrentWinStreak { get; set; }
    public int LongestWinStreak { get; set; }
    public int FlawlessVictories { get; set; }
    public int SamePlusTriggers { get; set; }
    public int UltraHardWins { get; set; }
    public int TimesStartedOver { get; set; }
    public int EasyWins { get; set; }
    public int MediumWins { get; set; }
    public int HardWins { get; set; }
    public int CardsStolen { get; set; }
    public int FallenAces { get; set; }
    public int SuddenDeathCount { get; set; }
    public List<int> CollectedCardIds { get; set; } = new List<int> { 1, 2, 3, 4, 5 }; // default starter deck

    public void RecordGame(bool won, bool drawn, int captures, int sessionCombos, bool flawless, string difficulty, int fallenAceCaptures)
    {
        GamesPlayed++;
        CardsCaptured += captures;
        SamePlusTriggers += sessionCombos;
        FallenAces += fallenAceCaptures;

        if (drawn)
        {
            MatchesDrawn++;
            CurrentWinStreak = 0;
        }
        else if (won)
        {
            MatchesWon++;
            CurrentWinStreak++;
            if (CurrentWinStreak > LongestWinStreak)
            {
                LongestWinStreak = CurrentWinStreak;
            }

            if (flawless) FlawlessVictories++;

            switch (difficulty)
            {
                case "Easy": EasyWins++; break;
                case "Medium": MediumWins++; break;
                case "Hard": HardWins++; break;
                case "UltraHard": UltraHardWins++; break;
            }
        }
        else
        {
            MatchesLost++;
            CurrentWinStreak = 0;
        }
    }
}
