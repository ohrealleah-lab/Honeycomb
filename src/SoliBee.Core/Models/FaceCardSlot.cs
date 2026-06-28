using System;

namespace SoliBee.Core.Models;

public enum FaceCardSlot
{
    BlackAce, RedAce,
    BlackJack, RedJack,
    BlackQueen, RedQueen,
    BlackKing, RedKing,

    // Diamonds
    DiamondsAce, DiamondsJack, DiamondsQueen, DiamondsKing,

    // Clubs
    ClubsAce, ClubsJack, ClubsQueen, ClubsKing
}

public static class FaceCardSlotExtensions
{
    public static int GetRank(this FaceCardSlot slot) => slot switch
    {
        FaceCardSlot.BlackAce or FaceCardSlot.RedAce or FaceCardSlot.DiamondsAce or FaceCardSlot.ClubsAce => 1,
        FaceCardSlot.BlackJack or FaceCardSlot.RedJack or FaceCardSlot.DiamondsJack or FaceCardSlot.ClubsJack => 11,
        FaceCardSlot.BlackQueen or FaceCardSlot.RedQueen or FaceCardSlot.DiamondsQueen or FaceCardSlot.ClubsQueen => 12,
        FaceCardSlot.BlackKing or FaceCardSlot.RedKing or FaceCardSlot.DiamondsKing or FaceCardSlot.ClubsKing => 13,
        _ => 0
    };

    public static bool GetIsRed(this FaceCardSlot slot) =>
        slot is FaceCardSlot.RedAce or FaceCardSlot.RedJack or FaceCardSlot.RedQueen or FaceCardSlot.RedKing or
                FaceCardSlot.DiamondsAce or FaceCardSlot.DiamondsJack or FaceCardSlot.DiamondsQueen or FaceCardSlot.DiamondsKing;

    public static string GetRankLabel(this FaceCardSlot slot) => slot.GetRank() switch
    {
        1 => "A", 11 => "J", 12 => "Q", 13 => "K", _ => "?"
    };

    public static string GetSuitSymbol(this FaceCardSlot slot) => slot switch
    {
        FaceCardSlot.BlackAce or FaceCardSlot.BlackJack or FaceCardSlot.BlackQueen or FaceCardSlot.BlackKing => "♠",
        FaceCardSlot.RedAce or FaceCardSlot.RedJack or FaceCardSlot.RedQueen or FaceCardSlot.RedKing => "♥",
        FaceCardSlot.DiamondsAce or FaceCardSlot.DiamondsJack or FaceCardSlot.DiamondsQueen or FaceCardSlot.DiamondsKing => "♦",
        FaceCardSlot.ClubsAce or FaceCardSlot.ClubsJack or FaceCardSlot.ClubsQueen or FaceCardSlot.ClubsKing => "♣",
        _ => ""
    };

    public static string GetDisplayName(this FaceCardSlot slot) => slot switch
    {
        FaceCardSlot.BlackAce => "Spades Ace",
        FaceCardSlot.RedAce => "Hearts Ace",
        FaceCardSlot.BlackJack => "Spades Jack",
        FaceCardSlot.RedJack => "Hearts Jack",
        FaceCardSlot.BlackQueen => "Spades Queen",
        FaceCardSlot.RedQueen => "Hearts Queen",
        FaceCardSlot.BlackKing => "Spades King",
        FaceCardSlot.RedKing => "Hearts King",
        FaceCardSlot.DiamondsAce => "Diamonds Ace",
        FaceCardSlot.DiamondsJack => "Diamonds Jack",
        FaceCardSlot.DiamondsQueen => "Diamonds Queen",
        FaceCardSlot.DiamondsKing => "Diamonds King",
        FaceCardSlot.ClubsAce => "Clubs Ace",
        FaceCardSlot.ClubsJack => "Clubs Jack",
        FaceCardSlot.ClubsQueen => "Clubs Queen",
        FaceCardSlot.ClubsKing => "Clubs King",
        _ => ""
    };

    public static FaceCardSlot? SlotFor(int rank, CardSuit suit) => (rank, suit) switch
    {
        (1, CardSuit.Spades) => FaceCardSlot.BlackAce,
        (1, CardSuit.Hearts) => FaceCardSlot.RedAce,
        (1, CardSuit.Diamonds) => FaceCardSlot.DiamondsAce,
        (1, CardSuit.Clubs) => FaceCardSlot.ClubsAce,
        (11, CardSuit.Spades) => FaceCardSlot.BlackJack,
        (11, CardSuit.Hearts) => FaceCardSlot.RedJack,
        (11, CardSuit.Diamonds) => FaceCardSlot.DiamondsJack,
        (11, CardSuit.Clubs) => FaceCardSlot.ClubsJack,
        (12, CardSuit.Spades) => FaceCardSlot.BlackQueen,
        (12, CardSuit.Hearts) => FaceCardSlot.RedQueen,
        (12, CardSuit.Diamonds) => FaceCardSlot.DiamondsQueen,
        (12, CardSuit.Clubs) => FaceCardSlot.ClubsQueen,
        (13, CardSuit.Spades) => FaceCardSlot.BlackKing,
        (13, CardSuit.Hearts) => FaceCardSlot.RedKing,
        (13, CardSuit.Diamonds) => FaceCardSlot.DiamondsKing,
        (13, CardSuit.Clubs) => FaceCardSlot.ClubsKing,
        _ => null
    };
}

public class CustomFaceArt
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public FaceCardSlot Slot { get; set; }
    public string RelativePath { get; set; } = "";
    public double Scale { get; set; } = 1.0;
    public double OffsetX { get; set; } = 0.0;
    public double OffsetY { get; set; } = 0.0;
    public bool IsEnabled { get; set; } = true;
}
