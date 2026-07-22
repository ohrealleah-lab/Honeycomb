using Xunit;
using SoliBee.Core.Models;
using System.Collections.Generic;
using System.Linq;

namespace SoliBee.Tests.Core;

public class HoneycombBoardTests
{
    private HoneycombCard CreateCard(int id, int[] stats, int owner, string suit = "S")
    {
        return new HoneycombCard(new HoneycombCardData { Id = id, Stats = stats, Suit = suit }, owner);
    }

    [Fact]
    public void PlainCapture_HigherBeatsLower()
    {
        var board = new HoneycombBoard();
        var rules = new HashSet<HoneycombRule>();
        
        board.PlaceCard(CreateCard(1, new[] {5,5,2,5}, 2), 4, rules); // Opponent center
        var flipped = board.PlaceCard(CreateCard(2, new[] {6,5,5,5}, 1), 7, rules); // Player bottom
        
        Assert.Single(flipped);
        Assert.Equal(4, flipped[0]);
        Assert.Equal(1, board.Cells[4].Card!.Owner);
    }

    [Fact]
    public void ReverseCapture_LowerBeatsHigher()
    {
        var board = new HoneycombBoard();
        var rules = new HashSet<HoneycombRule> { HoneycombRule.Reverse };
        
        board.PlaceCard(CreateCard(1, new[] {5,5,5,5}, 2), 4, rules); // Opponent center
        var flipped = board.PlaceCard(CreateCard(2, new[] {2,5,5,5}, 1), 7, rules); // Player bottom (2 vs 5 on top)
        
        Assert.Single(flipped);
        Assert.Equal(4, flipped[0]);
    }

    [Fact]
    public void Same_FiresAcrossTwoNeighbors_IncludingOwn()
    {
        var board = new HoneycombBoard();
        var rules = new HashSet<HoneycombRule> { HoneycombRule.Same };
        
        // Opponent at top (pos 1), stat[2] = 5
        board.PlaceCard(CreateCard(1, new[] {5,5,5,5}, 2), 1, rules);
        // Player at left (pos 3), stat[1] = 5
        board.PlaceCard(CreateCard(2, new[] {5,5,5,5}, 1), 3, rules);
        
        // Player places at center (pos 4), stat[0]=5 (matches top), stat[3]=5 (matches left)
        var flipped = board.PlaceCard(CreateCard(3, new[] {5,5,5,5}, 1), 4, rules);
        
        Assert.Single(flipped); // Only the opponent's card flips, but Same triggers
        Assert.Equal(1, flipped[0]);
        Assert.True(board.LastSameTriggered);
        Assert.Equal(1, board.SessionSamePlusTriggers);
    }

    [Fact]
    public void Plus_FiresOnSharedSum()
    {
        var board = new HoneycombBoard();
        var rules = new HashSet<HoneycombRule> { HoneycombRule.Plus };
        
        // Top (pos 1), stat[2]=6. Attacker pos 4 stat[0]=4. Sum = 10
        board.PlaceCard(CreateCard(1, new[] {5,5,6,5}, 2), 1, rules);
        // Right (pos 5), stat[3]=3. Attacker pos 4 stat[1]=7. Sum = 10
        board.PlaceCard(CreateCard(2, new[] {5,5,5,3}, 2), 5, rules);
        
        var flipped = board.PlaceCard(CreateCard(3, new[] {4,7,5,5}, 1), 4, rules);
        
        Assert.Equal(2, flipped.Count);
        Assert.Contains(1, flipped);
        Assert.Contains(5, flipped);
        Assert.True(board.LastPlusTriggered);
    }

    [Fact]
    public void ComboChain_FlipsSecondCard()
    {
        var board = new HoneycombBoard();
        var rules = new HashSet<HoneycombRule> { HoneycombRule.Plus };
        
        // Left (pos 3), stat[1]=3. Will be captured by Same/Plus. Wait, let's just do a normal chain.
        // The chain captures use normal capture.
        // We use Plus to start the chain because Same/Plus bypass normal check, but combo uses normal check.
        // Attacker center (pos 4), Top (pos 1), Left (pos 3).
        
        // Top (pos 1), stat[2]=6.
        board.PlaceCard(CreateCard(1, new[] {5,5,6,5}, 2), 1, rules);
        // Left (pos 3), stat[1]=3.
        board.PlaceCard(CreateCard(2, new[] {5,5,5,3}, 2), 3, rules);
        
        // Far left (pos 0), stat[1]=1. Owned by opponent. 
        board.PlaceCard(CreateCard(3, new[] {5,1,5,5}, 2), 0, rules);
        
        // Player plays center (pos 4). stat[0]=4, stat[3]=7. Both sums are 10.
        // Pos 1 and Pos 3 flip via Plus.
        // Now pos 3 is player's. Its stat[0] vs pos 0 stat[2]? No, pos 3 top is pos 0? No, pos 0 is above pos 3.
        // Wait, indices:
        // 0 1 2
        // 3 4 5
        // 6 7 8
        // Pos 3 top is pos 0. Pos 3 stat[0] attacks pos 0 stat[2].
        // Pos 3 card: stat = {5, 5, 5, 3}. stat[0] = 5.
        // Pos 0 card: stat = {5, 1, 5, 5}. stat[2] = 5. 5 vs 5 is a tie. We need a win.
        // Change pos 0 stat[2] to 2.
        var board2 = new HoneycombBoard();
        board2.PlaceCard(CreateCard(1, new[] {5,5,6,5}, 2), 1, rules);
        board2.PlaceCard(CreateCard(2, new[] {5,3,5,5}, 2), 3, rules);
        board2.PlaceCard(CreateCard(3, new[] {5,1,2,5}, 2), 0, rules); // Pos 0 bottom is 2
        
        // Player plays center (pos 4)
        var flipped = board2.PlaceCard(CreateCard(4, new[] {4,5,5,7}, 1), 4, rules);
        
        // 4 flips 1 and 3 via plus. 3 combo-flips 0.
        Assert.Equal(3, flipped.Count);
        Assert.Contains(1, flipped);
        Assert.Contains(3, flipped);
        Assert.Contains(0, flipped);
        Assert.Equal(1, board2.LastComboFlipCount);
    }

    [Fact]
    public void FallenAce_WinAndBlockedMirror()
    {
        var rules = new HashSet<HoneycombRule> { HoneycombRule.FallenAce };
        
        // Win: 1 beats 10
        var b1 = new HoneycombBoard();
        b1.PlaceCard(CreateCard(1, new[] {5,5,10,5}, 2), 1, rules); // Pos 1 (Top). Bottom (stat 2) = 10.
        var f1 = b1.PlaceCard(CreateCard(2, new[] {1,5,5,5}, 1), 4, rules); // Pos 4. Top (stat 0) = 1.
        Assert.Single(f1);
        Assert.True(b1.LastFallenAceTriggered);
        Assert.Equal(1, b1.SessionFallenAceCaptures);

        // Blocked Mirror: 10 vs 1 normally wins, but blocked by Fallen Ace
        var b2 = new HoneycombBoard();
        b2.PlaceCard(CreateCard(1, new[] {5,5,1,5}, 2), 1, rules); // Bottom = 1
        var f2 = b2.PlaceCard(CreateCard(2, new[] {10,5,5,5}, 1), 4, rules); // Top = 10
        Assert.Empty(f2); // Blocked
    }

    [Fact]
    public void FallenAce_Reverse_WinAndBlockedMirror()
    {
        var rules = new HashSet<HoneycombRule> { HoneycombRule.FallenAce, HoneycombRule.Reverse };
        
        // Win: 10 beats 1
        var b1 = new HoneycombBoard();
        b1.PlaceCard(CreateCard(1, new[] {5,5,1,5}, 2), 1, rules); // Bottom = 1
        var f1 = b1.PlaceCard(CreateCard(2, new[] {10,5,5,5}, 1), 4, rules); 
        Assert.Single(f1);
        Assert.True(b1.LastFallenAceTriggered);

        // Blocked Mirror: 1 vs 10 normally wins in Reverse, but blocked
        var b2 = new HoneycombBoard();
        b2.PlaceCard(CreateCard(1, new[] {5,5,10,5}, 2), 1, rules); // Bottom = 10
        var f2 = b2.PlaceCard(CreateCard(2, new[] {1,5,5,5}, 1), 4, rules); 
        Assert.Empty(f2); // Blocked
    }

    [Fact]
    public void Ascension_ModifierScales()
    {
        var board = new HoneycombBoard();
        board.AscensionDescensionSuits = new List<string> { "S", "H" };
        var rules = new HashSet<HoneycombRule> { HoneycombRule.Ascension };

        board.PlaceCard(CreateCard(1, new[] {5,5,5,5}, 1, "S"), 0, rules);
        Assert.Equal(1, board.Cells[0].Card!.Modifier);

        board.PlaceCard(CreateCard(2, new[] {5,5,5,5}, 1, "S"), 1, rules);
        Assert.Equal(2, board.Cells[0].Card!.Modifier);
        Assert.Equal(2, board.Cells[1].Card!.Modifier);
    }

    [Fact]
    public void Descension_ModifierGoesNegative()
    {
        var board = new HoneycombBoard();
        board.AscensionDescensionSuits = new List<string> { "S", "H" };
        var rules = new HashSet<HoneycombRule> { HoneycombRule.Descension };

        board.PlaceCard(CreateCard(1, new[] {5,5,5,5}, 1, "S"), 0, rules);
        Assert.Equal(-1, board.Cells[0].Card!.Modifier);
        
        // Test clamping (Stat method)
        Assert.Equal(4, board.Cells[0].Card!.Stat(0)); 
    }
}
