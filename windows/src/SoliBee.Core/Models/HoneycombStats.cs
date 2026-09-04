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

    // Win % of decisive games (draws excluded from the denominator) — was
    // independently reimplemented identically in MainWindow.axaml.cs (and again on
    // mac/iOS, now fixed to share shared/Honeycomb/Models/HoneycombStats.swift's
    // winRate). Now the one shared source all three read.
    public double WinRate
    {
        get
        {
            int decisiveGames = GamesPlayed - MatchesDrawn;
            return decisiveGames > 0 ? 100.0 * MatchesWon / decisiveGames : 0.0;
        }
    }

    public void RecordGame(bool won, bool drawn, int captures, int sessionCombos, bool flawless, HoneycombDifficulty difficulty, int fallenAceCaptures)
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
                case HoneycombDifficulty.Easy: EasyWins++; break;
                case HoneycombDifficulty.Medium: MediumWins++; break;
                case HoneycombDifficulty.Hard: HardWins++; break;
                case HoneycombDifficulty.UltraHard: UltraHardWins++; break;
            }
        }
        else
        {
            MatchesLost++;
            CurrentWinStreak = 0;
        }
    }
}
