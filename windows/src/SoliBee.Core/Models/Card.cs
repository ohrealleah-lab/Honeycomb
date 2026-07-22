namespace SoliBee.Core.Models;

public enum CardSuit
{
    Spades,
    Hearts,
    Diamonds,
    Clubs
}

public record Card(
    string Id,
    CardSuit Suit,
    int Rank,
    bool IsFaceUp
);
