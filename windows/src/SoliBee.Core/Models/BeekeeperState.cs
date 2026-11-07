using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace SoliBee.Core.Models;

/// <summary>One story-log line, kept as an event key plus values so a language change
/// can re-translate it (spec FR-007). Never store finished sentences.</summary>
public sealed class BeekeeperLogEntry
{
    public string Key { get; set; } = "";
    public decimal Value { get; set; }
    /// <summary>A second number when a line needs two (a raid: honey taken, bees flown off).</summary>
    public decimal Value2 { get; set; }
    public string? Text { get; set; }
}

/// <summary>Everything that is saved for a Beekeeper game.</summary>
public sealed class BeekeeperState
{
    /// <summary>1 = first build; 2 = stage 2 (Workbench, candles, Hippies, wasps); 3 = stage 3
    /// (more tools, the Smoker); 4 = stage 4 (the Garden, pollen, the wooden hive); 5 = stage 5 (the
    /// queen, the trade agreement). Older files load as they are: anything newer starts at zero.</summary>
    public int Version { get; set; } = 5;

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

    // ----- Stage 2: The Workbench, candles, Hippies, wasps (version 2)
    public decimal BeeswaxCandles { get; set; }
    public decimal RepellentCandles { get; set; }
    /// <summary>Every candle ever crafted, of any kind (brings the Hippies).</summary>
    public long CandlesCrafted { get; set; }
    public decimal Sage { get; set; }
    public long HippieTrades { get; set; }
    public List<string> Upgrades { get; set; } = new();

    public bool WorkbenchRevealed { get; set; }
    public bool HippiesRevealed { get; set; }
    public bool SageRevealed { get; set; }
    public bool RepellentUnlocked { get; set; }

    /// <summary>Wasp time left on burning repellent candles (0 = none burning).</summary>
    public decimal RepellentSecondsLeft { get; set; }
    /// <summary>Wasp time until the next wasp; 0 means "not rolled yet".</summary>
    public decimal NextWaspInSeconds { get; set; }

    // ----- Stage 3: the Smoker (version 3)
    /// <summary>Clicks towards the next puff (0 up to CalmMeterClicks).</summary>
    public int CalmMeter { get; set; }
    /// <summary>Live seconds of calm left (honey doubled); 0 = not calm.</summary>
    public decimal CalmSecondsLeft { get; set; }

    // ----- Stage 4: the Garden (version 4)
    /// <summary>Seeds the Hippies have given in all (the Nth is the Nth plant's seed).</summary>
    public int SeedsGiven { get; set; }
    /// <summary>Seeds in hand, not yet planted.</summary>
    public int Seeds { get; set; }
    /// <summary>Seeds planted in all; the next one grows Plants[SeedsPlanted].</summary>
    public int SeedsPlanted { get; set; }
    /// <summary>Seconds until the growing seed sprouts; 0 = nothing growing.</summary>
    public decimal GrowSecondsLeft { get; set; }
    /// <summary>Plant ids that have sprouted, in order.</summary>
    public List<string> Plants { get; set; } = new();
    public decimal ForagerBees { get; set; }
    public decimal GuardBees { get; set; }
    public decimal Pollen { get; set; }
    public decimal BeeBread { get; set; }
    public bool HasWoodenHive { get; set; }
    public bool GardenRevealed { get; set; }
    public bool PollenRevealed { get; set; }
    public bool BeeBreadRevealed { get; set; }

    // ----- Stage 5: the queen and the trade agreement (version 5)
    /// <summary>True once the queen has settled into the wooden hive (announced once). She lays
    /// whenever this is true and there is bee bread.</summary>
    public bool QueenSettled { get; set; }
    /// <summary>True once "the pantry is empty" has been said; cleared when bee bread comes back.</summary>
    public bool PantryEmptyAnnounced { get; set; }
    public bool HasTradeAgreement { get; set; }
    /// <summary>Overflow honey the bear has taken towards the next Beebit (0 up to AgreementHoneyPerBeebit).</summary>
    public decimal AgreementHoneyProgress { get; set; }

    /// <summary>Seconds left to respond to an approaching wasp; 0 = no wasp. Never saved:
    /// a wasp still around when the game closes simply leaves.</summary>
    [JsonIgnore]
    public decimal WaspCountdown { get; set; }

    public List<BeekeeperLogEntry> Log { get; set; } = new();

    /// <summary>When this was saved (UTC); used to work out time away.</summary>
    public DateTime? SavedAtUtc { get; set; }
}
