using System;

namespace SoliBee.Core.Models;

public enum FaceCardSlot
{
    BlackAce, RedAce,
    BlackJack, RedJack,
    BlackQueen, RedQueen,
    BlackKing, RedKing
}

public static class FaceCardSlotExtensions
{
    public static int GetRank(this FaceCardSlot slot) => slot switch
    {
        FaceCardSlot.BlackAce or FaceCardSlot.RedAce => 1,
        FaceCardSlot.BlackJack or FaceCardSlot.RedJack => 11,
        FaceCardSlot.BlackQueen or FaceCardSlot.RedQueen => 12,
        FaceCardSlot.BlackKing or FaceCardSlot.RedKing => 13,
        _ => 0
    };

    public static bool GetIsRed(this FaceCardSlot slot) =>
        slot is FaceCardSlot.RedAce or FaceCardSlot.RedJack or FaceCardSlot.RedQueen or FaceCardSlot.RedKing;

    public static string GetRankLabel(this FaceCardSlot slot) => slot.GetRank() switch
    {
        1 => "A", 11 => "J", 12 => "Q", 13 => "K", _ => "?"
    };

    public static string GetSuitSymbol(this FaceCardSlot slot) =>
        slot.GetIsRed() ? "♥" : "♠";

    public static string GetDisplayName(this FaceCardSlot slot) => slot switch
    {
        FaceCardSlot.BlackAce => "Black Ace",
        FaceCardSlot.RedAce => "Red Ace",
        FaceCardSlot.BlackJack => "Black Jack",
        FaceCardSlot.RedJack => "Red Jack",
        FaceCardSlot.BlackQueen => "Black Queen",
        FaceCardSlot.RedQueen => "Red Queen",
        FaceCardSlot.BlackKing => "Black King",
        FaceCardSlot.RedKing => "Red King",
        _ => ""
    };

    public static FaceCardSlot? SlotFor(int rank, bool isRed) => (rank, isRed) switch
    {
        (1, false) => FaceCardSlot.BlackAce,
        (1, true) => FaceCardSlot.RedAce,
        (11, false) => FaceCardSlot.BlackJack,
        (11, true) => FaceCardSlot.RedJack,
        (12, false) => FaceCardSlot.BlackQueen,
        (12, true) => FaceCardSlot.RedQueen,
        (13, false) => FaceCardSlot.BlackKing,
        (13, true) => FaceCardSlot.RedKing,
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
