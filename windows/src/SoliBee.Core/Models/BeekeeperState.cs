using System;
using System.Collections.Generic;

namespace SoliBee.Core.Models;

/// <summary>One story-log line, kept as an event key plus values so a language change
/// can re-translate it (spec FR-007). Never store finished sentences.</summary>
public sealed class BeekeeperLogEntry
{
    public string Key { get; set; } = "";
    public decimal Value { get; set; }
    public string? Text { get; set; }
}

/// <summary>Everything that is saved for a Beekeeper game.</summary>
public sealed class BeekeeperState
{
    public int Version { get; set; } = 1;

    // Resources
    public decimal Bees { get; set; }
    public decimal Honey { get; set; }
    /// <summary>Honey stored since the last wax dropped (0 up to HoneyPerWax).</summary>
    public decimal WaxProgress { get; set; }
    public decimal Wax { get; set; }
    public decimal Beebits { get; set; }

    // Purchases
    /// <summary>0 = Bare Hands, 1 = Gloves, 2 = Net, 3 = Vacuum.</summary>
    public int ToolLevel { get; set; }
    public bool HasWaxCatcher { get; set; }
    public int Combs { get; set; }

    // The bear
    public string BearName { get; set; } = "";
    public long Trades { get; set; }

    // Sticky reveals (once true, stay true)
    public bool HoneyRevealed { get; set; }     // Hive card + HONEY stat
    public bool BearRevealed { get; set; }
    public bool BeebitsRevealed { get; set; }
    public bool WaxRevealed { get; set; }
    public bool ShopRevealed { get; set; }
    public bool CombsRevealed { get; set; }

    /// <summary>True once "the combs are full" has been announced; cleared when room opens up.</summary>
    public bool StorageFullAnnounced { get; set; }

    public List<BeekeeperLogEntry> Log { get; set; } = new();

    /// <summary>When this was saved (UTC); used to work out time away.</summary>
    public DateTime? SavedAtUtc { get; set; }
}
