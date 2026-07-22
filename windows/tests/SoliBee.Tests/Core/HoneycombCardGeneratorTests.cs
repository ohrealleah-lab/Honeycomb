using Xunit;
using SoliBee.Core.Models;
using System.Linq;

namespace SoliBee.Tests.Core;

public class HoneycombCardGeneratorTests
{
    [Fact]
    public void SplitMix64_Seed1_ProducesExactSequence()
    {
        var rng = new SplitMix64(1);
        ulong[] expected = {
            10451216379200822465UL,
            13757245211066428519UL,
            17911839290282890590UL,
            8196980753821780235UL,
            8195237237126968761UL,
            14072917602864530048UL,
            16184226688143867045UL,
            9648886400068060533UL
        };

        for (int i = 0; i < expected.Length; i++)
        {
            Assert.Equal(expected[i], rng.Next());
        }
    }

    [Fact]
    public void SplitMix64_Seed42_ProducesExactSequence()
    {
        var rng = new SplitMix64(42);
        ulong[] expected = {
            13679457532755275413UL,
            2949826092126892291UL,
            5139283748462763858UL,
            6349198060258255764UL,
            701532786141963250UL,
            16015981125662989062UL,
            4028864712777624925UL,
            14769051326987775908UL
        };

        for (int i = 0; i < expected.Length; i++)
        {
            Assert.Equal(expected[i], rng.Next());
        }
    }

    [Fact]
    public void GenerateAllCards_Seed1_ProducesExactCards()
    {
        var cards = HoneycombCardGenerator.GenerateAllCards(1);
        Assert.Equal(552, cards.Count);

        AssertCard(cards[0], 1, "Spade 1", 1, new[] {4,4,4,2}, "S");
        AssertCard(cards[1], 2, "Spade 2", 1, new[] {3,1,4,5}, "S");
        AssertCard(cards[2], 3, "Spade 3", 1, new[] {3,4,2,4}, "S");
        AssertCard(cards[25], 26, "Spade 26", 1, new[] {2,5,4,2}, "S");
        AssertCard(cards[26], 27, "Spade 27", 2, new[] {3,4,4,6}, "S");
        AssertCard(cards[61], 62, "Spade 62", 2, new[] {2,7,1,7}, "S");
        AssertCard(cards[62], 63, "Spade 63", 3, new[] {6,6,5,3}, "S");
        AssertCard(cards[102], 103, "Spade 103", 3, new[] {3,8,5,5}, "S");
        AssertCard(cards[103], 104, "Spade 104", 4, new[] {6,7,7,5}, "S");
        AssertCard(cards[123], 124, "Spade 124", 4, new[] {7,7,3,7}, "S");
        AssertCard(cards[124], 125, "Spade 125", 5, new[] {7,7,9,6}, "S");
        AssertCard(cards[137], 138, "Spade 138", 5, new[] {10,4,8,8}, "S");
        AssertCard(cards[138], 139, "Heart 1", 1, new[] {2,5,3,5}, "H");
        AssertCard(cards[139], 140, "Heart 2", 1, new[] {2,6,3,4}, "H");
        AssertCard(cards[275], 276, "Heart 138", 5, new[] {5,10,10,5}, "H");
        AssertCard(cards[413], 414, "Diamond 138", 5, new[] {10,6,2,10}, "D");
        AssertCard(cards[551], 552, "Club 138", 5, new[] {10,7,2,6}, "C");
    }

    [Fact]
    public void GenerateAllCards_Seed42_ProducesExactCards()
    {
        var cards = HoneycombCardGenerator.GenerateAllCards(42);
        Assert.Equal(552, cards.Count);

        AssertCard(cards[0], 1, "Spade 1", 1, new[] {6,2,2,3}, "S");
        AssertCard(cards[1], 2, "Spade 2", 1, new[] {3,5,2,4}, "S");
        AssertCard(cards[137], 138, "Spade 138", 5, new[] {9,7,8,3}, "S");
        AssertCard(cards[138], 139, "Heart 1", 1, new[] {2,2,2,7}, "H");
        AssertCard(cards[551], 552, "Club 138", 5, new[] {6,2,8,9}, "C");
    }
    
    [Fact]
    public void GenerateAllCards_FollowsStructuralConstraints()
    {
        var cards = HoneycombCardGenerator.GenerateAllCards(12345);
        Assert.Equal(552, cards.Count);
        
        string[] suits = { "S", "H", "D", "C" };
        foreach (var suit in suits)
        {
            var suitCards = cards.Where(c => c.Suit == suit).ToList();
            Assert.Equal(138, suitCards.Count);
            
            // Check tier counts
            Assert.Equal(26, suitCards.Count(c => c.Stars == 1));
            Assert.Equal(36, suitCards.Count(c => c.Stars == 2));
            Assert.Equal(41, suitCards.Count(c => c.Stars == 3));
            Assert.Equal(21, suitCards.Count(c => c.Stars == 4));
            Assert.Equal(14, suitCards.Count(c => c.Stars == 5));
            
            // No duplicate stat combos within a suit
            var combos = suitCards.Select(c => string.Join(",", c.Stats)).ToHashSet();
            Assert.Equal(138, combos.Count);
        }
        
        // Different seeds produce different pools
        var cards2 = HoneycombCardGenerator.GenerateAllCards(67890);
        var stats1 = string.Join("|", cards.Select(c => string.Join(",", c.Stats)));
        var stats2 = string.Join("|", cards2.Select(c => string.Join(",", c.Stats)));
        Assert.NotEqual(stats1, stats2);
    }

    private void AssertCard(HoneycombCardData card, int expectedId, string expectedName, int expectedStars, int[] expectedStats, string expectedSuit)
    {
        Assert.Equal(expectedId, card.Id);
        Assert.Equal(expectedName, card.Name);
        Assert.Equal(expectedStars, card.Stars);
        Assert.Equal(expectedStats, card.Stats);
        Assert.Equal(expectedSuit, card.Suit);
    }
}
