using System.Collections.Generic;

namespace SoliBee.Core.Models;

public enum PileType
{
    Stock,
    Waste,
    Foundation,
    Tableau,
    FreeCell
}

public class Pile
{
    public string Id { get; }
    public PileType Type { get; }
    public List<Card> Cards { get; } = new();

    public Pile(string id, PileType type)
    {
        Id = id;
        Type = type;
    }
}
