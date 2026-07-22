namespace SoliBee.Core.Models;

public sealed record VideoPokerPayEntry(
    string HandName,
    PokerHandRank Rank,
    VideoPokerQualifier Qualifier,
    int[] Multipliers)
{
    public int Payout(int bet) => bet >= 1 && bet <= 5 ? Multipliers[bet - 1] * bet : 0;
}
