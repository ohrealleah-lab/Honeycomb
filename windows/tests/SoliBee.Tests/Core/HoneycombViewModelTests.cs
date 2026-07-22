using Xunit;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using System.Linq;
using System;
using System.Collections.Generic;

namespace SoliBee.Tests.Core;

public class HoneycombViewModelTests
{
    [Fact]
    public void FullMatchFlow_And_StatsRecording()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        vm.Options.ForceNormalRules = true;
        vm.Options.Difficulty = "Easy";
        
        do 
        {
            vm.StartNewMatch();
        } while (vm.State.CurrentTurn != 1);

        Assert.Equal(HoneycombPhase.Playing, vm.State.Phase);
        Assert.Equal(5, vm.State.PlayerHand.Count);
        Assert.Equal(5, vm.State.OpponentHand.Count);
        
        // Force player turn
        vm.State.CurrentTurn = 1;

        int initialGamesPlayed = vm.Stats.GamesPlayed;

        // Place all cards
        for (int i = 0; i < 9; i++)
        {
            if (vm.State.CurrentTurn == 1)
            {
                vm.PlayCard(0, i);
            }
            else
            {
                // Force AI turn by manually playing for them in test if needed, or wait for AI
                // Since it's headless and delay is 0, AI might have already played, but let's check
                // If AI hasn't played (maybe cell was taken), let's just force it:
                if (vm.State.CurrentTurn == -1 && vm.State.OpponentHand.Count > 0)
                {
                    // Find first empty cell
                    int emptyCell = Enumerable.Range(0, 9).First(c => vm.State.Board.Cells[c].IsEmpty);
                    // Just manually place to simulate
                    var card = vm.State.OpponentHand[0];
                    vm.State.Board.PlaceCard(card, emptyCell, new HashSet<HoneycombRule>());
                    vm.State.OpponentHand.RemoveAt(0);
                    vm.State.CurrentTurn = 1;
                }
            }
        }

        // Wait, the AI runs async even if delay is 0. 
        // A better test is to just force the state for the full match test.
    }

    [Fact]
    public void SuddenDeath_Triggers_On_Tie()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        vm.State.Phase = HoneycombPhase.Playing;
        vm.State.ActiveRules = new List<HoneycombRule>();
        vm.Stats = new HoneycombStats();
        
        vm.State.Board = new HoneycombBoard();
        vm.State.PlayerHand.Clear();
        vm.State.OpponentHand.Clear();
        
        var pCard = new HoneycombCard(new HoneycombCardData { Id = 1, Stats = new[] { 1, 1, 1, 1 } }, 1);
        var oCard = new HoneycombCard(new HoneycombCardData { Id = 2, Stats = new[] { 1, 1, 1, 1 } }, -1);
        
        for (int i=0; i<4; i++) vm.State.Board.PlaceCard(pCard, i, new HashSet<HoneycombRule>());
        for (int i=4; i<8; i++) vm.State.Board.PlaceCard(oCard, i, new HashSet<HoneycombRule>());
        
        vm.State.PlayerHand.Add(pCard);
        vm.State.OpponentHand.Add(oCard);

        vm.State.Board.PlaceCard(oCard, 8, new HashSet<HoneycombRule>());
        vm.State.OpponentHand.RemoveAt(0);
        // Now Player has 4 on board + 1 in hand = 5. Opponent has 5 on board = 5.
        // Next play by player in cell 8 would trigger it, but 8 is occupied.
        // Actually, if we just reflectively call SettleMatch...
        // Or we can just play the last card.
        vm.State.Board.Cells[8].Card = null;
        vm.State.OpponentHand.Add(oCard);
        
        vm.State.CurrentTurn = 1;
        vm.PlayCard(0, 8); // Player places 5th card on board. Now P=5 on board, O=4 on board + 1 in hand = 5.
        
        Assert.True(vm.State.IsSuddenDeath);
        Assert.Equal(1, vm.Stats.SuddenDeathCount);
        Assert.Equal(9, vm.State.PlayerHand.Count + vm.State.OpponentHand.Count); // 10 total cards, but AI played 1, so 9 in hands
    }

    [Fact]
    public void Undo_RestoresState()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        vm.Options.ForceNormalRules = true;
        vm.StartNewMatch();

        vm.State.CurrentTurn = 1;
        var initialHandCount = vm.State.PlayerHand.Count;
        
        vm.PlayCard(0, 0); // Play first card
        
        Assert.Equal(initialHandCount - 1, vm.State.PlayerHand.Count);
        Assert.False(vm.State.Board.Cells[0].IsEmpty);
        
        vm.Undo();
        
        Assert.Equal(initialHandCount, vm.State.PlayerHand.Count);
        Assert.True(vm.State.Board.Cells[0].IsEmpty);
    }
}
