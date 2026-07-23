using System;

namespace SoliBee.Core.Models;

public class HoneycombCardData
{
    public int Id { get; init; }
    public string Name { get; init; } = "";
    public int Stars { get; init; }
    public int[] Stats { get; init; } = new int[4];
    public string Suit { get; init; } = "";
}

public class HoneycombCard
{
    public HoneycombCardData Data { get; }
    public int Modifier { get; set; }
    public int OriginalOwner { get; set; }
    public int Owner { get; set; }
    public Guid UniqueInstanceId { get; set; } = Guid.NewGuid();
    public bool IsFaceDown { get; set; } = false;

    public HoneycombCard(HoneycombCardData data, int owner)
    {
        Data = data;
        Owner = owner;
        OriginalOwner = owner;
    }

    public int Stat(int index)
    {
        int val = Data.Stats[index] + Modifier;
        return Math.Min(10, Math.Max(1, val));
    }

    public HoneycombCard Clone()
    {
        return new HoneycombCard(Data, Owner)
        {
            Modifier = Modifier,
            OriginalOwner = OriginalOwner,
            UniqueInstanceId = UniqueInstanceId,
            IsFaceDown = IsFaceDown
        };
    }
}
