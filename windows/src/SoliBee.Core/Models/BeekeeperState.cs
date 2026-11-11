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
    /// <summary>Herbal candles (10 wax + 1 herb). Saved under the old name: they were repellent candles.</summary>
    public decimal RepellentCandles { get; set; }
    /// <summary>Every candle ever crafted, of any kind (brings the Hippies).</summary>
    public long CandlesCrafted { get; set; }
    /// <summary>Cut (Bee, 2026-11-11): herbs replaced sage. Read from older saves only; the engine
    /// moves it into <see cref="Herbs"/> on load.</summary>
    public decimal Sage { get; set; }
    public long HippieTrades { get; set; }
    public List<string> Upgrades { get; set; } = new();

    public bool WorkbenchRevealed { get; set; }
    public bool HippiesRevealed { get; set; }
    /// <summary>Cut (Bee, 2026-11-11): older saves only; becomes <see cref="HerbsRevealed"/> on load.</summary>
    public bool SageRevealed { get; set; }
    /// <summary>The herbal candle's recipe is open (the first herb from the bear). Saved under its
    /// old name: it was the sage repellent candle.</summary>
    public bool RepellentUnlocked { get; set; }
    /// <summary>True once the first herbal candle is made (brings its Hive row). Old name kept for saves.</summary>
    public bool RepellentCrafted { get; set; }

    /// <summary>Wasp time left on burning repellent candles (0 = none burning). Herbal candles no
    /// longer keep wasps away; an older save's burning candle just burns out.</summary>
    public decimal RepellentSecondsLeft { get; set; }
    /// <summary>Wasp time until the next wasp; 0 means "not rolled yet".</summary>
    public decimal NextWaspInSeconds { get; set; }

    // ----- The Smoker: a click boost. Never saved, so time away never has it (older saves'
    // CalmMeter / CalmSecondsLeft fields are simply ignored when loading).
    /// <summary>Live seconds of smoker boost left; 0 = off. Each smoker click refreshes it.</summary>
    [JsonIgnore]
    public decimal SmokerBoostSecondsLeft { get; set; }

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
    /// <summary>Plant ids that have sprouted, in order. Since stage 8 an id can be here many times
    /// (count it with BeekeeperEngine.PlantCount).</summary>
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
    /// <summary>Seeds in hand, by plant id, not yet planted. Since stage 8 an id can be here many times.</summary>
    public List<string> SeedsInHand { get; set; } = new();
    /// <summary>Since stage 8 (spec 017, FR-802): plant ids whose seed has joined its giver's roll (each
    /// said once in the log). A seed is in the roll when it is listed here or its giver has traded
    /// enough, so an older save's list (seeds given once each) never blocks a roll.
    /// Before stage 8: plant ids whose seed had been given, so each was given once.</summary>
    public List<string> SeedsGivenIds { get; set; } = new();
    /// <summary>Cut in stage 8 (spec 017, FR-803): plants grow at once. Read from older saves only;
    /// the engine sprouts every bed on load and empties the list.</summary>
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

    // ----- Trade reps arrive like wasps (older saves load with these empty)
    /// <summary>Reps (bear, hippies) whose first arrival has been handled. A revealed rep missing
    /// here (new reveal, or an older save) shows up on the next rep time.</summary>
    public List<string> RepsMet { get; set; } = new();
    /// <summary>Reps at the door now, waiting for "Throw a shoe" or "Engage".</summary>
    public List<string> RepsPresent { get; set; } = new();
    /// <summary>Reps the player engaged: their trades are open.</summary>
    public List<string> RepsEngaged { get; set; } = new();
    /// <summary>Seconds until a rep that was sent away comes back, by rep id.</summary>
    public Dictionary<string, decimal> RepReturnIn { get; set; } = new();
    // ----- Story cards (older saves load with these empty)
    /// <summary>The story card showing now (a <see cref="BeekeeperStories"/> id), or null.</summary>
    public string? StoryHere { get; set; }
    /// <summary>Moments answered for good.</summary>
    public List<string> StoriesDone { get; set; } = new();
    /// <summary>Play seconds until a declined moment comes back, by story id.</summary>
    public Dictionary<string, decimal> StoryReturnIn { get; set; } = new();
    /// <summary>Bees caught by clicking, all time.</summary>
    public long BeesCaught { get; set; }
    /// <summary>True once the first sting has happened (at 10 bees caught by hand): brings the "Ouch!" card.</summary>
    public bool FirstStingDone { get; set; }
    /// <summary>Play seconds the "Ouch!" card has left before it goes by itself.</summary>
    public decimal OuchSecondsLeft { get; set; }
    public int GlovesDeclines { get; set; }
    /// <summary>True once the gloves were refused five times: kept for a future hard-mode achievement.</summary>
    public bool GlovesRefusedForGood { get; set; }

    /// <summary>Wasps that have shown up in all; the first visit offers Engage, later ones Bribe.</summary>
    public long WaspVisits { get; set; }

    // ----- Herbs (Bee, 2026-11-11; older saves load with their sage as herbs)
    /// <summary>Herbs from the bear (1 a trade). They go into herbal candles and prices, as sage did.</summary>
    public decimal Herbs { get; set; }
    /// <summary>True once herbs have been seen (sticky): shows the Herbs row.</summary>
    public bool HerbsRevealed { get; set; }
    /// <summary>The buff the lit herbal candle rolled (a <see cref="BeekeeperHerbs"/> id), or null when none burns.</summary>
    public string? HerbBuff { get; set; }
    /// <summary>Live seconds the lit herbal candle has left; 0 = none burning. Waits while the app is closed.</summary>
    public decimal HerbSecondsLeft { get; set; }

    // ----- Stage 8 (spec 017): seeds, wood and the meadow (older saves load with these empty, FR-814)
    /// <summary>Wood the carpenter bee has brought (fractional; shown rounded down). No cap.</summary>
    public decimal Wood { get; set; }
    /// <summary>True once wood has been seen (sticky): brings the wood upgrades and the Honey Super.</summary>
    public bool WoodRevealed { get; set; }
    /// <summary>True once the carpenter bee has come (the first willow planted). Sticky.</summary>
    public bool CarpenterBeeCame { get; set; }
    /// <summary>Seconds of time (live or away) until the bee hotel's next gift; counts only once the hotel is owned.</summary>
    public decimal HotelSecondsToNext { get; set; }
    /// <summary>Rare bees that have brought a gift, in the order they first came (the Bees tab).</summary>
    public List<string> RareBeesMet { get; set; } = new();
    /// <summary>True once the meadow has been bought (it works like one giant comb).</summary>
    public bool HasMeadow { get; set; }

    // ----- Stage 9 (spec 018): the bloom calendar (older saves load with these empty, FR-910)
    /// <summary>True once the calendar has started (the first plant). Sticky.</summary>
    public bool CalendarStarted { get; set; }
    /// <summary>Which bloom is out now: an index into BeekeeperConfig.Blooms.</summary>
    public int BloomIndex { get; set; }
    /// <summary>Seconds of game time (live or credited away) the bloom has left.</summary>
    public decimal BloomSecondsLeft { get; set; }

    /// <summary>Seconds left to respond to an approaching wasp; 0 = no wasp. Never saved:
    /// a wasp still around when the game closes simply leaves.</summary>
    [JsonIgnore]
    public decimal WaspCountdown { get; set; }

    public List<BeekeeperLogEntry> Log { get; set; } = new();

    /// <summary>When this was saved (UTC); used to work out time away.</summary>
    public DateTime? SavedAtUtc { get; set; }
}
