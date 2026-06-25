namespace SoliBee.Core.Models;

public enum PokerHandRank
{
    HighCard      = 0,
    OnePair       = 1,
    TwoPair       = 2,
    ThreeOfAKind  = 3,
    Straight      = 4,
    Flush         = 5,
    FullHouse     = 6,
    FourOfAKind   = 7,
    StraightFlush = 8,
    RoyalFlush    = 9,
    FiveOfAKind   = 10,
}

public sealed record PokerHandResult(
    PokerHandRank Rank,
    int PairRank = 0,
    int QuadRank = 0);
