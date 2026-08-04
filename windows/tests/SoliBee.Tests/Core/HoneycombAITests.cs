using Xunit;
using SoliBee.Core.Models;
using System.Collections.Generic;
using System.Linq;

namespace SoliBee.Tests.Core;

public class HoneycombAITests
{
    private HoneycombCard CreateCard(int id, int[] stats, int owner)
    {
        return new HoneycombCard(new HoneycombCardData { Id = id, Stats = stats, Suit = "S" }, owner);
    }

    [Fact]
    public void Easy_PicksValidIndices()
    {
        var board = new HoneycombBoard();
        var aiHand = new List<HoneycombCard> { CreateCard(1, new[] {1,1,1,1}, 2) };
        var playerHand = new List<HoneycombCard> { CreateCard(2, new[] {1,1,1,1}, 1) };
        
        var move = HoneycombAI.FindMove(board, aiHand, playerHand, 0, new HashSet<HoneycombRule>(), HoneycombDifficulty.Easy, 2, 1, null);
        
        Assert.Equal(0, move.HandIndex);
        Assert.InRange(move.CellIndex, 0, 8);
    }

    [Fact]
    public void Medium_GreedilyPicksMaxCaptures()
    {
        var board = new HoneycombBoard();
        // Opponent cards to capture
        board.PlaceCard(CreateCard(1, new[] {1,1,1,1}, 1), 0, new HashSet<HoneycombRule>()); 
        board.PlaceCard(CreateCard(2, new[] {1,1,1,1}, 1), 2, new HashSet<HoneycombRule>()); 
        
        // Place at 0, 2, and 4 so position 1 captures 3 cards.
        board.PlaceCard(CreateCard(4, new[] {1,1,1,1}, 1), 4, new HashSet<HoneycombRule>());
        
        var aiHand = new List<HoneycombCard> { CreateCard(5, new[] {10,10,10,10}, 2) };
        
        var move = HoneycombAI.FindMove(board, aiHand, new List<HoneycombCard>(), 0, new HashSet<HoneycombRule>(), HoneycombDifficulty.Medium, 2, 1, null);
        
        // Should pick pos 1 because it's between 0, 2, and 4, capturing all three.
        Assert.Equal(1, move.CellIndex);
    }

    [Fact]
    public void Minimax_PrefersSafeMove()
    {
        var board = new HoneycombBoard();
        
        // 4 is Player. Top=1.
        board.PlaceCard(CreateCard(1, new[] {1,10,10,10}, 1), 4, new HashSet<HoneycombRule>());
        
        var aiHand = new List<HoneycombCard> { 
            CreateCard(2, new[] {10, 10, 2, 1}, 2), // If at 1, Left=1 exposed to 0. (Index 0)
            CreateCard(3, new[] {10, 10, 2, 10}, 2) // If at 1, Left=10 safe from 0. (Index 1)
        };
        var playerHand = new List<HoneycombCard> {
            CreateCard(4, new[] {10,10,10,10}, 1) 
        };
        
        var move = HoneycombAI.FindMove(board, aiHand, playerHand, 0, new HashSet<HoneycombRule>(), HoneycombDifficulty.Hard, 2, 1, null);
        
        // Should pick Card 3 (HandIndex 1) because it doesn't leave its left side vulnerable to Player's 10.
        Assert.Equal(1, move.HandIndex);
        Assert.Equal(1, move.CellIndex);
    }

    [Fact]
    public void RulesAwareCards_LowStats_Differs()
    {
        var db = HoneycombDatabase.Shared;
        Assert.NotEmpty(db.AllCards);

        // RulesAwareCards draws are weighted-random, not a deterministic top/bottom
        // slice — a single 5-card draw from the full tier is too small a sample for
        // the preferLowStats bias to reliably show up (it can, and does, flip either
        // way by chance). Average over many trials instead, so this asserts the real
        // statistical bias the weighting is meant to produce rather than depending on
        // any one draw's luck.
        const int trials = 200;
        double lowTotal = 0;
        double highTotal = 0;
        int lowCount = 0;
        int highCount = 0;

        for (int i = 0; i < trials; i++)
        {
            var lowCards = db.RulesAwareCards(1, 5, preferLowStats: true);
            var highCards = db.RulesAwareCards(1, 5, preferLowStats: false);

            lowTotal += lowCards.Sum(c => c.Stats.Sum());
            lowCount += lowCards.Count;
            highTotal += highCards.Sum(c => c.Stats.Sum());
            highCount += highCards.Count;
        }

        double lowAvg = lowTotal / lowCount;
        double highAvg = highTotal / highCount;

        Assert.True(lowAvg < highAvg, $"Expected preferLowStats average ({lowAvg}) to be lower than preferHighStats average ({highAvg}) over {trials} trials.");
    }
}
