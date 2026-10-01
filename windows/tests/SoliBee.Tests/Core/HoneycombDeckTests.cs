using Xunit;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using System.Collections.Generic;
using System.Linq;

namespace SoliBee.Tests.Core;

public class HoneycombDeckTests
{
    private int GetCardOfStars(int stars)
    {
        return HoneycombDatabase.Shared.AllCards.First(c => c.Stars == stars).Id;
    }

    [Fact]
    public void ValidateDeck_ValidDeck()
    {
        // 1 5-star, 1 4-star, 3 3-star
        var ids = new List<int> {
            GetCardOfStars(5),
            GetCardOfStars(4),
            GetCardOfStars(3),
            GetCardOfStars(3),
            GetCardOfStars(3)
        };
        
        bool isValid = HoneycombProfileManager.Shared.ValidateDeck(ids, "Valid Deck", out var error);
        Assert.True(isValid);
        Assert.Empty(error);
    }

    [Fact]
    public void ValidateDeck_RejectsTooManyFiveStars()
    {
        var ids = new List<int> {
            GetCardOfStars(5),
            GetCardOfStars(5),
            GetCardOfStars(3),
            GetCardOfStars(3),
            GetCardOfStars(3)
        };
        
        bool isValid = HoneycombProfileManager.Shared.ValidateDeck(ids, "Deck", out var error);
        Assert.False(isValid);
        Assert.Equal("A deck can never contain more than one 5★ card.", error);
    }

    [Fact]
    public void ValidateDeck_RejectsFourStarsWhenFiveStarPresent()
    {
        var ids = new List<int> {
            GetCardOfStars(5),
            GetCardOfStars(4),
            GetCardOfStars(4),
            GetCardOfStars(3),
            GetCardOfStars(3)
        };
        
        bool isValid = HoneycombProfileManager.Shared.ValidateDeck(ids, "Deck", out var error);
        Assert.False(isValid);
        Assert.Equal("If you have a 5★ card, you can only have one 4★ card.", error);
    }

    [Fact]
    public void ValidateDeck_RejectsTooManyFourStarsWhenNoFiveStar()
    {
        var ids = new List<int> {
            GetCardOfStars(4),
            GetCardOfStars(4),
            GetCardOfStars(4),
            GetCardOfStars(3),
            GetCardOfStars(3)
        };
        
        bool isValid = HoneycombProfileManager.Shared.ValidateDeck(ids, "Deck", out var error);
        Assert.False(isValid);
        Assert.Equal("A deck can never contain more than two 4★ cards.", error);
    }

    [Fact]
    public void ValidateDeck_RejectsInvalidLength()
    {
        var ids = new List<int> { GetCardOfStars(1) };
        bool isValid = HoneycombProfileManager.Shared.ValidateDeck(ids, "Deck", out var error);
        Assert.False(isValid);
        Assert.Equal("A deck must contain exactly 5 cards.", error);
    }

    // Every message the deck builder can show must come back in the player's language —
    // these used to be hard-coded English, so Spanish players saw English errors.
    [Fact]
    public void ValidateDeck_ReturnsSpanishMessages_WhenLanguageIsSpanish()
    {
        var spanish = AppLanguage.Spanish;
        var five = GetCardOfStars(5);
        var four = GetCardOfStars(4);
        var three = GetCardOfStars(3);

        HoneycombProfileManager.Shared.ValidateDeck(new List<int> { three }, "Deck", out var wrongSize, spanish);
        Assert.Equal("Un mazo debe contener exactamente 5 cartas.", wrongSize);

        var fiveCards = new List<int> { three, three, three, three, three };
        HoneycombProfileManager.Shared.ValidateDeck(fiveCards, "", out var noName, spanish);
        Assert.Equal("El nombre del mazo no puede estar vacío.", noName);

        HoneycombProfileManager.Shared.ValidateDeck(fiveCards, new string('x', 21), out var longName, spanish);
        Assert.Equal("El nombre del mazo no puede superar los 20 caracteres.", longName);

        HoneycombProfileManager.Shared.ValidateDeck(new List<int> { five, five, three, three, three }, "Deck", out var twoFives, spanish);
        Assert.Equal("Un mazo nunca puede contener más de una carta de 5★.", twoFives);

        HoneycombProfileManager.Shared.ValidateDeck(new List<int> { five, four, four, three, three }, "Deck", out var fiveAndFours, spanish);
        Assert.Equal("Si tienes una carta de 5★, solo puedes tener una carta de 4★.", fiveAndFours);

        HoneycombProfileManager.Shared.ValidateDeck(new List<int> { four, four, four, three, three }, "Deck", out var threeFours, spanish);
        Assert.Equal("Un mazo nunca puede contener más de dos cartas de 4★.", threeFours);
    }

    [Fact]
    public void ValidateDeck_RejectsEmptyName()
    {
        var ids = new List<int> { GetCardOfStars(1), GetCardOfStars(1), GetCardOfStars(1), GetCardOfStars(1), GetCardOfStars(1) };
        bool isValid = HoneycombProfileManager.Shared.ValidateDeck(ids, "", out var error);
        Assert.False(isValid);
        Assert.Equal("Deck name cannot be empty.", error);
    }

    [Fact]
    public void ValidateDeck_RejectsLongName()
    {
        var ids = new List<int> { GetCardOfStars(1), GetCardOfStars(1), GetCardOfStars(1), GetCardOfStars(1), GetCardOfStars(1) };
        bool isValid = HoneycombProfileManager.Shared.ValidateDeck(ids, new string('A', 21), out var error);
        Assert.False(isValid);
        Assert.Equal("Deck name cannot exceed 20 characters.", error);
    }

    [Fact]
    public void ComputeStartOverDeck_PreservesComposition()
    {
        var prevIds = new List<int> {
            GetCardOfStars(5),
            GetCardOfStars(4),
            GetCardOfStars(3),
            GetCardOfStars(2),
            GetCardOfStars(1)
        };

        var newIds = HoneycombProfileManager.ComputeStartOverDeck(prevIds);

        Assert.Equal(5, newIds.Count);
        var newStars = newIds.Select(id => HoneycombDatabase.Shared.Card(id)?.Stars ?? 1).OrderByDescending(s => s).ToList();
        
        Assert.Equal(5, newStars[0]);
        Assert.Equal(4, newStars[1]);
        Assert.Equal(3, newStars[2]);
        Assert.Equal(2, newStars[3]);
        Assert.Equal(1, newStars[4]);
    }
}
