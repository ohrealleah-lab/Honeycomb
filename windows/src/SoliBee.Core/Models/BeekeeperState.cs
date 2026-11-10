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

/// <summary>One garden bed that is growing a seed (spec 015).</summary>
public sealed class BeekeeperBed
{
    public string PlantId { get; set; } = "";
    public decimal SecondsLeft { get; set; }
}

/// <summary>Everything that is saved for a Beekeeper game.</summary>
public sealed class BeekeeperState
{
    /// <summary>1 = first build; 2 = stage 2 (Workbench, candles, Hippies, wasps); 3 = stage 3
    /// (more tools, the Smoker); 4 = stage 4 (the Garden, pollen, the wooden hive); 5 = stage 5 (the
    /// queen, the trade agreement); 6 = stage 6 (specialties, the wasp emissary, paper); 7 = stage 7
    /// (named seeds, beds, propolis, two candles); 8 = stage 7.5 (combs make the honey, bees as
    /// currency, honey and wax caps). Since version 8 an older file is not loaded at all: it is moved
    /// aside and a new game starts (spec 016, FR-714).</summary>
    // Review fix (stage 7.5): a file with no Version field now reads as 0 and is moved aside, instead
    // of passing as the current version. Save always writes CurrentVersion, so real files are fine.
    public int Version { get; set; }
    // Cut in the stage 7.5 review: public int Version { get; set; } = 8;

    // Resources
    /// <summary>Free bees (stage 7.5, spec 016): the bees not living in a comb. They make the wax,
    /// and a comb is paid for with them (those bees move in and leave this count for good). The
    /// catch slice reads this. Can be 0 in a running game: never use it to mean "started".</summary>
    public decimal Bees { get; set; }
    public decimal Honey { get; set; }
    // Cut in stage 7.5 (spec 016): wax no longer follows honey.
    // /// <summary>Honey stored since the last wax dropped (0 up to HoneyPerWax).</summary>
    // public decimal WaxProgress { get; set; }
    /// <summary>Fractional since stage 7.5 (the screen shows it rounded down, as honey).</summary>
    public decimal Wax { get; set; }
    public decimal Beebits { get; set; }

    // Purchases
    /// <summary>0 = Bare Hands, 1 = Gloves, 2 = Net, 3 = Vacuum.</summary>
    public int ToolLevel { get; set; }
    public bool HasWaxCatcher { get; set; }
    /// <summary>Combs held, the starter comb counted (stage 7.5: a new game has 1, never fewer).
    /// Prices and caps count combs bought, Combs - 1.</summary>
    public int Combs { get; set; } = 1;

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
    /// <summary>True once the first repellent candle is made (brings its Hive row, spec 010).</summary>
    public bool RepellentCrafted { get; set; }

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
    // Cut in stage 7.5 (spec 016): files older than version 8 no longer load, so the stage 4 to 6
    // seed counts that older files were converted from are not needed.
    // /// <summary>Obsolete (stage 7): seeds the Hippies gave in all (the Nth was the Nth plant's seed).</summary>
    // public int SeedsGiven { get; set; }
    // /// <summary>Obsolete (stage 7): seeds in hand, not yet planted.</summary>
    // public int Seeds { get; set; }
    // /// <summary>Obsolete (stage 7): seeds planted in all; the next one grew Plants[SeedsPlanted].</summary>
    // public int SeedsPlanted { get; set; }
    // /// <summary>Obsolete (stage 7): seconds until the growing seed sprouted; 0 = nothing growing.</summary>
    // public decimal GrowSecondsLeft { get; set; }
    /// <summary>Plant ids that have sprouted, in order.</summary>
    public List<string> Plants { get; set; } = new();
    // Cut in stage 7.5 (spec 016): older files no longer load.
    // /// <summary>Obsolete since stage 6 (spec 014): plants give specialties instead. Still read so
    // /// stage 4 and 5 files load, and kept so the counts could come back; never used or shown.</summary>
    // public decimal ForagerBees { get; set; }
    // /// <summary>Obsolete since stage 6 (spec 014); see <see cref="ForagerBees"/>.</summary>
    // public decimal GuardBees { get; set; }
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
    /// <summary>The bear's trade agreement. Since stage 7.5 (spec 016) it means a better selling
    /// rate (BetterHoneyPerBeebit); before, the bear took the honey that didn't fit.</summary>
    public bool HasTradeAgreement { get; set; }
    // Cut in stage 7.5 (spec 016): no auto-sale.
    // /// <summary>Overflow honey the bear has taken towards the next Beebit (0 up to AgreementHoneyPerBeebit).</summary>
    // public decimal AgreementHoneyProgress { get; set; }

    // ----- Stage 6: specialties and the wasp emissary (version 6)
    /// <summary>Wasps bribed in all (never reset); the emissary comes at BribesForEmissary.</summary>
    public long BribesTotal { get; set; }
    /// <summary>True once the wasp nest has sent its emissary: no wasp ever comes again.</summary>
    public bool EmissaryCome { get; set; }
    /// <summary>Trades with the wasps (their reputation); a batch counts as one.</summary>
    public long WaspTrades { get; set; }
    public decimal Paper { get; set; }
    // Cut in stage 7.5 (spec 016): older files no longer load.
    // /// <summary>True once an older save's forager and guard counts have been turned into
    // /// specialties and announced (said once).</summary>
    // public bool OldCountsAnnounced { get; set; }

    // ----- Stage 7: more seeds, the poplar and propolis (version 7)
    /// <summary>Seeds in hand, by plant id, not yet planted.</summary>
    public List<string> SeedsInHand { get; set; } = new();
    /// <summary>Plant ids whose seed has been given, so each is given once.</summary>
    public List<string> SeedsGivenIds { get; set; } = new();
    /// <summary>The garden beds that are growing a seed (a free bed is simply not listed).
    /// Never more than the beds owned.</summary>
    public List<BeekeeperBed> Beds { get; set; } = new();
    public decimal Propolis { get; set; }
    /// <summary>True once propolis has been seen (sticky): shows the Propolis Seal in the Shop.</summary>
    public bool PropolisRevealed { get; set; }
    /// <summary>True once paper has been seen (sticky): shows the Notebook and the Third Bed.</summary>
    public bool PaperRevealed { get; set; }
    public decimal BeeBoostCandles { get; set; }
    public decimal SagePropolisCandles { get; set; }
    /// <summary>Live seconds of bee-boost left (honey up); 0 = not burning. Waits while the app is closed.</summary>
    public decimal BeeBoostSecondsLeft { get; set; }
    /// <summary>Seconds of sage-propolis left (honey up); burns while the app is closed too.</summary>
    public decimal SagePropolisSecondsLeft { get; set; }

    // ----- Stage 7.5: combs, bees as currency (version 8)
    /// <summary>Honey Supers bought (each adds honey room; bought again and again).</summary>
    public int HoneySupers { get; set; }
    /// <summary>Wax Trays bought (each adds wax room; bought again and again).</summary>
    public int WaxTrays { get; set; }
    /// <summary>True once "there's no more room for wax" has been said; cleared when room opens up.</summary>
    public bool WaxFullAnnounced { get; set; }
    /// <summary>True once the first wall (a price above a cap) has been told in the log (said once).</summary>
    public bool FirstWallAnnounced { get; set; }

    /// <summary>Seconds left to respond to an approaching wasp; 0 = no wasp. Never saved:
    /// a wasp still around when the game closes simply leaves.</summary>
    [JsonIgnore]
    public decimal WaspCountdown { get; set; }

    public List<BeekeeperLogEntry> Log { get; set; } = new();

    /// <summary>When this was saved (UTC); used to work out time away.</summary>
    public DateTime? SavedAtUtc { get; set; }
}
