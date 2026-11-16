using System;
using System.Collections.Generic;
using System.Linq;

namespace SoliBee.Core.Models;

/// <summary>Where the engine gets its dice rolls, so tests can control them (spec FR-003).</summary>
public interface IRandomSource
{
    double NextDouble();
    int Next(int maxExclusive);
}

public sealed class SystemRandomSource : IRandomSource
{
    public double NextDouble() => Random.Shared.NextDouble();
    public int Next(int maxExclusive) => Random.Shared.Next(maxExclusive);
}

/// <summary>Event keys the engine reports; the view model turns them into story-log lines.</summary>
public static class BeekeeperEvents
{
    public const string NewGame = "new_game";
    public const string FirstBee = "first_bee";
    public const string Sting = "sting";
    public const string StorageFull = "storage_full";
    public const string FirstWax = "first_wax";
    public const string BearArrives = "bear_arrives";      // Text = bear name
    public const string Sale = "sale";                     // Value = Beebits got (stage 10; herbs 2026-11-11 to 11-12), Value2 = honey given, Text = bear name
    public const string ShopOpened = "shop_opened";
    public const string ToolBought = "tool_bought";        // Value = new tool level, Text = tool id
    public const string WaxCatcherBought = "wax_catcher_bought";
    public const string CombsAvailable = "combs_available";
    // Value = bees that moved in (stage 7.5, spec 016); before stage 7.5 it was the honey storage added.
    public const string CombBuilt = "comb_built";
    public const string WelcomeBack = "welcome_back";      // Value = honey made while away
    public const string WelcomeBackNothing = "welcome_back_nothing";

    // Stage 2
    public const string WorkbenchOpened = "workbench_opened";
    public const string HippiesArrive = "hippies_arrive";
    public const string CandlesTraded = "candles_traded";    // Value = clay jars got (stage 10; Beebits 11-11, sage before), Value2 = beeswax candles given
    public const string RepellentUnlocked = "repellent_unlocked";   // the herbal candle's recipe opens (first herb)
    public const string UpgradeBought = "upgrade_bought";    // Text = upgrade id
    public const string WaspArrives = "wasp_arrives";
    public const string ShoeHit = "shoe_hit";
    // Value = honey taken. Before stage 6, Value2 = bees flown off (Text = "guards" when guards kept them safe).
    public const string ShoeMissRaid = "shoe_miss_raid";
    public const string WaspRaid = "wasp_raid";
    public const string Bribe = "bribe";                     // Value = honey paid
    public const string WaspLeft = "wasp_left";              // the player stepped away; nothing lost
    public const string RepArrives = "rep_arrives";          // Text = rep id ("bear", "hippies"); "A {} shows up"
    public const string RepEngaged = "rep_engaged";          // Text = rep id; their trades are open
    public const string RepLeft = "rep_left";                // Text = rep id; a shoe sent them away, they will return
    public const string WaspEngaged = "wasp_engaged";        // first visit only: the wasp wants nothing to do with you and steals honey (Value)
    public const string CandleLit = "candle_lit";
    public const string CandleOut = "candle_out";

    // Stage 3

    // Stage 4
    public const string SeedGiven = "seed_given";              // Value = seeds in hand; since stage 7 Text = plant id (from the Hippies)
    public const string SeedPlanted = "seed_planted";          // since stage 7 Text = plant id
    public const string SeedSprouted = "seed_sprouted";
    public const string PlantRevealed = "plant_revealed";      // Text = plant id
    public const string FirstPollen = "first_pollen";
    public const string BeeBreadMade = "bee_bread_made";       // first time only
    public const string WoodenHive = "wooden_hive";
    public const string Crafted = "crafted";                   // a batch of more than one: Value = how many, Text = repellent | bee_bread | bee_boost | sage_propolis

    // Stage 5
    public const string QueenSettles = "queen_settles";
    public const string PantryEmpty = "pantry_empty";          // live play and open-app gaps; time away says WelcomeBackPantry
    public const string QueenResumes = "queen_resumes";
    public const string TradeAgreement = "trade_agreement";    // Text = bear name
    public const string WelcomeBackQueen = "welcome_back_queen";   // Value = bees raised while away
    // Cut in stage 7.5 (spec 016): the bear no longer sells honey while you are away.
    // public const string WelcomeBackBear = "welcome_back_bear";     // Value = Beebits from the agreement, Text = bear name
    public const string WelcomeBackPantry = "welcome_back_pantry";

    // Stage 6
    public const string OldCountsSettle = "old_counts_settle";   // an older save's bee counts became specialties
    public const string BribeHint = "bribe_hint";                // the wasp is taking notes
    public const string Emissary = "emissary";                   // the wasp nest sends an emissary: raids end
    public const string WaspTrade = "wasp_trade";                // Value = paper got, Value2 = honey given
    public const string FirstPaper = "first_paper";

    // Stage 7
    public const string WaspSeedGiven = "wasp_seed_given";       // Text = plant id (the wasps leave a seed)
    public const string FirstPropolis = "first_propolis";
    public const string BeeBoostLit = "bee_boost_lit";
    public const string BeeBoostOut = "bee_boost_out";
    public const string SagePropolisLit = "sage_propolis_lit";
    public const string SagePropolisOut = "sage_propolis_out";   // live play; away says WelcomeBackSageOut
    public const string WelcomeBackPropolis = "welcome_back_propolis";   // Value = propolis gathered while away
    public const string WelcomeBackSageOut = "welcome_back_sage_out";

    // Stage 7.5 (spec 016)
    public const string WaxFull = "wax_full";                    // there's no more room for wax
    public const string FirstWall = "first_wall";                // a price is above a cap (said once)
    public const string HoneySuperBought = "honey_super_bought"; // Value = level now owned
    public const string WaxTrayBought = "wax_tray_bought";       // Value = level now owned

    // Bee Herbs
    public const string HerbLit = "herb_lit";                    // Text = the buff rolled (BeekeeperHerbs), "dud" included
    public const string HerbOut = "herb_out";                    // Text = the buff that ended

    // Story cards (Bee, 2026-11-11)
    public const string StoryArrives = "story_arrives";          // Text = story id; no log line, the card speaks
    public const string GlovesOn = "gloves_on";                  // the gloves were put on
    public const string GlovesGone = "gloves_gone";              // the 5th No: bare hands for good
    public const string SmokerRepaired = "smoker_repaired";

    // Stage 8 (spec 017)
    public const string SeedsGivenBatch = "seeds_given_batch";   // Value = seeds the Hippies gave in one Trade All (2 or more)
    // Cut from the log (Bee, 2026-11-11): no engine path raises it now; the key and its words stay so it can return.
    public const string SeedJoinsRoll = "seed_joins_roll";       // Text = plant id (the Hippies have a new kind of seed)
    public const string CarpenterBee = "carpenter_bee";          // the carpenter bee moves into the willow
    public const string MeadowBought = "meadow_bought";
    /// <summary>A rare bee's first gift: Text = <see cref="BeekeeperEngine.GiftText"/> (bee, gift, plant), Value = amount.</summary>
    public const string RareBeeArrives = "rare_bee_arrives";
    /// <summary>A rare bee's later gifts; same values as <see cref="RareBeeArrives"/>.</summary>
    public const string HotelGift = "hotel_gift";
    public const string WelcomeBackWood = "welcome_back_wood";   // Value = wood brought while away
    /// <summary>Value = seeds, Value2 = herbs, Text = propolis (invariant number) the guests left while away.</summary>
    public const string WelcomeBackHotel = "welcome_back_hotel";

    // Stage 9 (spec 018)
    public const string CalendarStarted = "calendar_started";    // the first plant: the crocuses are in bloom
    public const string BloomChanged = "bloom_changed";          // Text = the new bloom's id (live; away says WelcomeBackBlooms)
    /// <summary>Text = every bloom that came out while away, in order, joined by '|'; the last is out now.</summary>
    public const string WelcomeBackBlooms = "welcome_back_blooms";

    // Stage 10 (spec 019)
    public const string HoneyPotted = "honey_potted";            // the first potted honey only (later pots are silent)
    public const string PottedSale = "potted_sale";              // Value = Beebits got, Value2 = potted honey given, Text = bear name
    public const string BeeswaxCrafted = "beeswax_crafted";      // a batch of more than one: Value = how many

    /// <summary>The lines that only reopening the app shows ("While you were away…").</summary>
    public static bool IsWelcomeBack(string key) =>
        key is WelcomeBack or WelcomeBackNothing or WelcomeBackQueen or WelcomeBackPantry
            or WelcomeBackPropolis or WelcomeBackSageOut or WelcomeBackWood or WelcomeBackHotel or WelcomeBackBlooms;
    // Cut in stage 7.5 (spec 016): WelcomeBackBear.
    //     key is WelcomeBack or WelcomeBackNothing or WelcomeBackQueen or WelcomeBackBear or WelcomeBackPantry
    //         or WelcomeBackPropolis or WelcomeBackSageOut;
}

public readonly record struct BeekeeperEvent(string Key, decimal Value = 0m, string? Text = null, decimal Value2 = 0m);

public sealed record CatchResult(bool Stung, decimal BeesGained, IReadOnlyList<BeekeeperEvent> Events);

/// <summary><see cref="BeesRaised"/>: bees the queen raised. <see cref="WaxMade"/>: wax stored
/// (since stage 7.5 it stops at the wax cap).</summary>
public sealed record AdvanceResult(decimal HoneyStored, decimal WaxMade, IReadOnlyList<BeekeeperEvent> Events,
    decimal BeesRaised = 0m);
// Cut in stage 7.5 (spec 016): AgreementBeebits, the whole Beebits the bear paid for honey that didn't fit.
// public sealed record AdvanceResult(decimal HoneyStored, decimal WaxMade, IReadOnlyList<BeekeeperEvent> Events,
//     decimal BeesRaised = 0m, decimal AgreementBeebits = 0m);

/// <summary><see cref="Events"/>: what happened, in the order it happened. <see cref="WelcomeBack"/>:
/// the "While you were away" summary, in reading order (top line first); empty for
/// <see cref="BeekeeperEngine.AdvanceGap"/>, which is the app staying open. The caller decides how
/// to put them in its log.</summary>
public sealed record AwayResult(decimal CreditedSeconds, decimal HoneyStored, decimal WaxMade, IReadOnlyList<BeekeeperEvent> Events,
    decimal BeesRaised = 0m, bool PantryEmptied = false)
// Cut in stage 7.5 (spec 016): AgreementBeebits (after BeesRaised).
{
    public IReadOnlyList<BeekeeperEvent> WelcomeBack { get; init; } = Array.Empty<BeekeeperEvent>();
}

/// <summary>Result of a sell, buy or build. <see cref="Done"/> is false when it was refused.</summary>
public sealed record ActionResult(bool Done, decimal Amount, IReadOnlyList<BeekeeperEvent> Events)
{
    public static ActionResult Refused { get; } = new(false, 0m, Array.Empty<BeekeeperEvent>());
}

/// <summary>
/// The Beekeeper rules. No screen, no clock, no timer: callers say how many seconds passed.
/// All amounts are decimal so 0.01 honey steps stay exact.
/// </summary>
public sealed class BeekeeperEngine
{
    private readonly IRandomSource _rng;
    /// <summary>Stage 9: the loaded save had plants but no calendar, so Tidy started it; RevealOnLoad tells it.</summary>
    private bool _calendarStartedOnLoad;

    public BeekeeperConfig Config { get; }
    public BeekeeperState State { get; private set; }

    public BeekeeperEngine(BeekeeperConfig? config = null, BeekeeperState? state = null, IRandomSource? rng = null)
    {
        Config = config ?? BeekeeperConfig.Default;
        _rng = rng ?? new SystemRandomSource();
        State = state ?? NewState();
        if (state is not null)
        {
            // Cut in stage 7.5 (spec 016): files older than version 8 never reach the engine (the save
            // service moves them aside), so there are no old seed counts to convert.
            // if (state.Version < 7) ConvertOldSeeds(state);
            Tidy(state);
        }
    }

    // Cut in stage 7.5 (spec 016): older saves start a new game instead of being converted.
    // /// <summary>A file older than version 7 counted seeds; seed N was plant N (spec 015, FR-609).
    // /// The sprouted plants are already in the list; the growing seed (if any) goes into bed 1 with its
    // /// time left, the seeds in hand become named, and every seed given counts as given.</summary>
    // private void ConvertOldSeeds(BeekeeperState s)
    // {
    //     var plants = Config.Plants;
    //     for (int i = 0; i < s.SeedsGiven && i < plants.Count; i++)
    //     {
    //         if (!s.SeedsGivenIds.Contains(plants[i].Id)) s.SeedsGivenIds.Add(plants[i].Id);
    //         if (i >= s.SeedsPlanted && !s.SeedsInHand.Contains(plants[i].Id)) s.SeedsInHand.Add(plants[i].Id);
    //     }
    //     if (s.GrowSecondsLeft > 0m && s.SeedsPlanted >= 1 && s.SeedsPlanted <= plants.Count && s.Beds.Count == 0)
    //     {
    //         var growing = plants[s.SeedsPlanted - 1];
    //         s.Beds.Add(new BeekeeperBed { PlantId = growing.Id, SecondsLeft = s.GrowSecondsLeft });
    //         if (!s.SeedsGivenIds.Contains(growing.Id)) s.SeedsGivenIds.Add(growing.Id);
    //     }
    //     if (s.SeedsGiven > 0 || s.SeedsPlanted > 0) s.GardenRevealed = true;
    //     s.Version = 7;
    // }

    /// <summary>Sanity for a loaded file: unknown plant ids dropped, a seed still growing in a bed
    /// (an older save) sprouts at once (spec 017, FR-803), and no timer longer than it could ever be.
    /// Since stage 8 plants and seeds may repeat (many of each).</summary>
    private void Tidy(BeekeeperState s)
    {
        bool Known(string id) => id is not null && Config.Plants.Any(p => p.Id == id);
        s.Upgrades = s.Upgrades.Where(id => id is not null).Distinct().ToList();
        // Review fix (2026-11-15): limits from the config are kept here, not by refusing the file (the save
        // service used to compare them with the default config): a tool past the list (it would throw), more
        // bees than MaxBees, and (below) unknown story ids and too many glove declines.
        s.ToolLevel = Math.Clamp(s.ToolLevel, 0, Config.Tools.Count);
        s.Bees = Math.Clamp(s.Bees, 0m, Config.MaxBees);
        s.SeedsGivenIds = s.SeedsGivenIds.Where(Known).Distinct().ToList();
        // Stage 8: every bed sprouts on load and the beds are gone.
        s.Plants = s.Plants.Where(Known).ToList();
        s.Plants.AddRange(s.Beds.Where(b => b is not null && Known(b.PlantId)).Select(b => b.PlantId));
        s.Beds.Clear();
        s.SeedsInHand = s.SeedsInHand.Where(Known).ToList();
        // Bee, 2026-11-11: a seed of a kind already growing plants itself; only new kinds wait in hand.
        s.Plants.AddRange(s.SeedsInHand.Where(id => s.Plants.Contains(id)));
        s.SeedsInHand.RemoveAll(id => s.Plants.Contains(id));
        s.Wood = Math.Max(0m, s.Wood);
        if (s.Wood >= 1m) s.WoodRevealed = true;
        s.RareBeesMet = (s.RareBeesMet ?? new()).Where(id => Config.RareBees.Any(b => b.Id == id)).Distinct().ToList();
        // The hotel's timer never runs past one gift, and an owned hotel always has one running.
        s.HotelSecondsToNext = Math.Clamp(s.HotelSecondsToNext, 0m, Config.HotelGiftSeconds);
        if (s.Upgrades.Contains(BeekeeperUpgrades.BeeHotel) && s.HotelSecondsToNext <= 0m)
            s.HotelSecondsToNext = Config.HotelGiftSeconds;
        // Stage 9 (spec 018, FR-910): the bloom index wraps into range and its time left is clamped
        // to (0, that bloom's length]; a running calendar with no time left gets the full length.
        // A save with plants but no calendar (stage 8) starts it on crocus now (told by RevealOnLoad).
        if (Config.Blooms.Count == 0) s.CalendarStarted = false;
        if (s.CalendarStarted)
        {
            int n = Config.Blooms.Count;
            s.BloomIndex = ((s.BloomIndex % n) + n) % n;
            decimal length = Config.Blooms[s.BloomIndex].Seconds;
            s.BloomSecondsLeft = s.BloomSecondsLeft <= 0m ? length : Math.Min(s.BloomSecondsLeft, length);
        }
        else
        {
            s.BloomIndex = 0;
            s.BloomSecondsLeft = 0m;
            if (s.Plants.Count > 0 && Config.Blooms.Count > 0) { SetCalendarStart(s); _calendarStartedOnLoad = true; }
        }
        // Cut in stage 8 (spec 017): each plant was in one place only (sprouted, in a bed or in hand),
        // and beds past the ones owned gave their seeds back.
        // s.Plants = s.Plants.Where(id => id is not null).Distinct().ToList();
        // s.Beds = s.Beds.Where(b => Known(b.PlantId) && !s.Plants.Contains(b.PlantId)).DistinctBy(b => b.PlantId).ToList();
        // s.SeedsInHand = s.SeedsInHand.Where(id => Known(id) && !s.Plants.Contains(id) && s.Beds.All(b => b.PlantId != id))
        //     .Distinct().ToList();
        // int owned = Config.StartingBeds + (s.Upgrades.Contains(BeekeeperUpgrades.ThirdBed) ? Config.ThirdBedBeds : 0);
        // if (s.Beds.Count > owned)
        // {
        //     s.SeedsInHand.AddRange(s.Beds.Skip(owned).Select(b => b.PlantId));
        //     s.Beds.RemoveRange(owned, s.Beds.Count - owned);
        // }
        // foreach (var bed in s.Beds)
        //     bed.SecondsLeft = Math.Min(bed.SecondsLeft, Config.Plants.First(p => p.Id == bed.PlantId).GrowSeconds);
        // Bee, 2026-11-11: herbs replaced sage; an older save's sage becomes herbs, one for one.
        if (s.Sage > 0m) { s.Herbs += s.Sage; s.Sage = 0m; }
        if (s.SageRevealed) { s.HerbsRevealed = true; s.SageRevealed = false; }
        if (s.Herbs > 0m) s.RepellentUnlocked = true;   // herbs in hand open the herbal candle
        s.Herbs = Math.Max(0m, s.Herbs);
        s.HerbSecondsLeft = Math.Clamp(s.HerbSecondsLeft, 0m, Config.HerbalCandleBurnSeconds * Config.StrongerCandlesBonus);
        if (s.HerbSecondsLeft <= 0m || s.HerbBuff is null || s.HerbBuff == BeekeeperHerbs.Dud || !BeekeeperHerbs.All.Contains(s.HerbBuff))
        {
            s.HerbBuff = null;
            s.HerbSecondsLeft = 0m;
        }
        // A smoker click lasts longer only under Lingering Smoke.
        decimal smokerMax = s.HerbBuff == BeekeeperHerbs.LingeringSmoke ? Config.HerbSmokerSeconds : Config.SmokerBoostSeconds;
        s.SmokerBoostSecondsLeft = Math.Clamp(s.SmokerBoostSecondsLeft, 0m, smokerMax);
        s.BeeBoostSecondsLeft = Math.Min(s.BeeBoostSecondsLeft, Config.BeeBoostCapSeconds);
        s.SagePropolisSecondsLeft = Math.Min(s.SagePropolisSecondsLeft, Config.SagePropolisCapSeconds);
        s.Combs = Math.Max(1, s.Combs);   // the starter comb is always there (stage 7.5)

        // Stage 10 (spec 019, FR-1003, FR-1014): nothing negative; an older save gets the starting
        // jars once and never sees the opening card.
        s.ClayJars = Math.Max(0m, s.ClayJars);
        s.PottedHoney = Math.Max(0m, s.PottedHoney);
        s.BeeswaxCandles = Math.Max(0m, s.BeeswaxCandles);
        if (s.PottedHoney > 0m) s.PottedHoneyRevealed = true;
        if (!s.StartingJarsGiven)
        {
            s.StartingJarsGiven = true;
            s.ClayJars += Config.StartingClayJars;
            if (!s.StoriesDone.Contains(BeekeeperStories.Opening)) s.StoriesDone.Add(BeekeeperStories.Opening);
        }

        // Story cards: only known moments, nothing negative, and a card already answered never shows.
        // The seed card is never done (it comes back for each new kind), so it is never kept as done.
        s.StoriesDone = s.StoriesDone.Where(id => id is not null && BeekeeperStories.Order.Contains(id) && id != BeekeeperStories.Seed).Distinct().ToList();
        // Bee, 2026-11-12: a save that already made these never sees their intro card, and has the craft links.
        void MarkDone(string id) { if (!s.StoriesDone.Contains(id)) s.StoriesDone.Add(id); }
        if (s.PottedHoneyRevealed) MarkDone(BeekeeperStories.PotHoney);
        if (s.BeeBreadRevealed) MarkDone(BeekeeperStories.BeeBread);
        // Review fix (2026-11-15): beeswax candles only (CandlesCrafted counts the herbal and propolis ones too).
        if (s.BeeswaxCrafted || s.BeeswaxCandles > 0m) MarkDone(BeekeeperStories.Candle);
        s.StoryReturnIn = s.StoryReturnIn.Where(kv => BeekeeperStories.Order.Contains(kv.Key) && kv.Value > 0m)
            .ToDictionary(kv => kv.Key, kv => Math.Min(kv.Value, Config.GlovesReturnSeconds));
        s.BeesCaught = Math.Max(0, s.BeesCaught);
        s.OuchSecondsLeft = Math.Clamp(s.OuchSecondsLeft, 0m, MaxFadeSeconds);
        s.GlovesDeclines = Math.Clamp(s.GlovesDeclines, 0, Config.GlovesMaxDeclines);
        s.GlovesLineBeesLeft = Math.Clamp(s.GlovesLineBeesLeft, 0, Math.Max(0, Config.GlovesLineBees));
        if (s.StoryHere is not null && (!BeekeeperStories.Order.Contains(s.StoryHere) || s.StoriesDone.Contains(s.StoryHere)))
            s.StoryHere = null;

        // The story area (Bee, 2026-11-12): one thing at a time. Only known entries wait, each once, and an
        // older save with a card and visitors (or two visitors) up at once keeps the first and queues the rest.
        s.HippieShoes = Math.Max(0, s.HippieShoes);
        s.RepsPresent = (s.RepsPresent ?? new()).Where(id => RepIds.Contains(id)).Distinct().ToList();
        s.RepsEngaged = (s.RepsEngaged ?? new()).Where(id => RepIds.Contains(id)).Distinct().ToList();
        if (s.HippiesDismissedForGood)
        {
            s.RepsEngaged.Remove("hippies");   // review fix (2026-11-15): their trades go with them
            s.RepsPresent.Remove("hippies");
            s.RepReturnIn.Remove("hippies");
        }
        s.StoryQueue = (s.StoryQueue ?? new()).Where(e => e is not null
            && (e == WaspEntry ? s.WaspCountdown <= 0m && !s.EmissaryCome
                : RepOfEntry(e) is { } rep ? !s.RepsPresent.Contains(rep) && !(rep == "hippies" && s.HippiesDismissedForGood)
                : BeekeeperStories.Order.Contains(e) && e != s.StoryHere && !s.StoriesDone.Contains(e))).Distinct().ToList();
        // A save made with a wasp at the door and a card or visitor up too: the wasp goes back to wait its turn.
        if (s.WaspCountdown > 0m && (s.StoryHere is not null || s.RepsPresent.Count > 0) && !s.EmissaryCome)
        {
            s.WaspCountdown = 0m;   // (a visit is only counted once the wasp is met, so none to give back)
            if (!s.StoryQueue.Contains(WaspEntry)) s.StoryQueue.Insert(0, WaspEntry);
        }
        var extraReps = s.StoryHere is not null ? s.RepsPresent.ToList() : s.RepsPresent.Skip(1).ToList();
        foreach (var rep in extraReps) s.RepsPresent.Remove(rep);
        s.StoryQueue.InsertRange(0, extraReps.Select(RepEntry).Where(e => !s.StoryQueue.Contains(e)));
        // A visitor whose return time is used up waits its turn (its time stays at 0 until it is shown).
        foreach (var rep in s.RepReturnIn.Where(kv => kv.Value <= 0m).Select(kv => kv.Key).ToList())
        {
            if (!RepIds.Contains(rep)) { s.RepReturnIn.Remove(rep); continue; }
            s.RepReturnIn[rep] = 0m;
            if (!s.RepsPresent.Contains(rep) && !s.StoryQueue.Contains(RepEntry(rep))) s.StoryQueue.Add(RepEntry(rep));
        }
    }

    // Bee, 2026-11-12: a new game starts with 0 Beebits, and the Beebits row waits for the first trade.
    // (2026-11-11: 75 Beebits, one Wax-Catcher as a free choice.) Before: new() { BearName = PickBearName() }
    private BeekeeperState NewState() => new()
    {
        BearName = PickBearName(), Beebits = Config.StartingBeebits,
        // Bee, 2026-11-11: the Shop waits for the first comb built (was: open at once, 75 ≥ 10 Beebits).
        // ShopRevealed = Config.StartingBeebits >= Config.ShopRevealBeebits,
        BeebitsRevealed = Config.StartingBeebits > 0m,
        // Stage 10 (spec 019): a skep and a few clay jars in the garden; the opening card is due.
        ClayJars = Config.StartingClayJars, StartingJarsGiven = true,
    };

    private string PickBearName()
    {
        var names = Config.BearNames;
        return names.Count == 0 ? "" : names[_rng.Next(names.Count)];
    }

    /// <summary>Throws the hive away and starts again with a freshly named bear.</summary>
    public IReadOnlyList<BeekeeperEvent> StartNewGame()
    {
        State = NewState();
        return new[] { new BeekeeperEvent(BeekeeperEvents.NewGame) };
    }

    // ------------------------------------------------------------------ numbers the screen shows

    // Cut in stage 7.5 (spec 016): honey storage only, and no starter comb.
    // public decimal HoneyStorage =>
    //     (Config.StartingStorage + State.Combs * Config.StoragePerComb) * StorageMultiplier;

    /// <summary>The hive has started: the first bee has been caught (sticky; spec 016, FR-703).
    /// From then on the combs make honey, the welcome-back is told and New Game asks first, even
    /// with 0 free bees. Never test <c>State.Bees &gt; 0</c> for this: paying for a comb can take
    /// free bees to 0.</summary>
    public bool HiveStarted => State.HoneyRevealed;

    /// <summary>The Hive card: hidden until a bee is caught (Bee, 2026-11-12), or the drip's first whole wax
    /// (stage 7.5: wax can come before any bee).</summary>
    public bool HiveCardShown => State.BeesCaught > 0 || State.HoneyRevealed || State.WaxRevealed;

    /// <summary>The Clay jars row: from a new game (the jars found in the garden). It shows once the Hive card does.</summary>
    public bool ClayJarsShown => State.StartingJarsGiven || State.ClayJars > 0m;

    /// <summary>Combs bought: the starter comb doesn't count. Prices and the caps' comb room use this.</summary>
    public int CombsBought => Math.Max(0, State.Combs - 1);

    /// <summary>The honey cap: the starting room (the starter comb's), plus room for each comb
    /// bought and each Honey Super, grown by the Technologies (Bigger Combs, the Propolis Seal).</summary>
    /// <remarks>Stage 8 (spec 017, FR-812): the meadow adds its room before the Technologies.</remarks>
    public decimal HoneyStorage =>
        (Config.StartingHoneyCap + CombsBought * Config.HoneyCapPerComb + State.HoneySupers * Config.HoneySuperCapacity
         + (State.HasMeadow ? Config.MeadowHoneyCap : 0m))
        * StorageMultiplier;

    /// <summary>The wax cap, small on purpose (spec 016): the starting room, plus a little for each
    /// comb bought and each Wax Tray (and the meadow's, stage 8), grown by the same Technologies.</summary>
    /// <remarks>Bee, 2026-11-12: the Wax-Catcher adds its room here (it doubled the wax rate before).</remarks>
    public decimal WaxStorage =>
        (Config.StartingWaxCap + CombsBought * Config.WaxCapPerComb + State.WaxTrays * Config.WaxTrayCapacity
         + (State.HasWaxCatcher ? Config.WaxCatcherWaxCap : 0m)
         + (State.HasMeadow ? Config.MeadowWaxCap : 0m))
        * StorageMultiplier;

    /// <summary>Wax room the Wax-Catcher adds right now (the Technologies counted), for its Shop blurb.</summary>
    public decimal WaxCatcherRoom => Config.WaxCatcherWaxCap * StorageMultiplier;

    /// <summary>The one rule for "time to full" on any capped resource (the Hive card's rate hovers):
    /// seconds until <paramref name="amount"/> reaches <paramref name="cap"/> at <paramref name="rate"/>
    /// a second. 0 when it is already full; null when it is not filling (rate zero or below).</summary>
    public static decimal? SecondsToFull(decimal amount, decimal cap, decimal rate)
    {
        if (amount >= cap) return 0m;
        if (rate <= 0m) return null;
        return (cap - amount) / rate;
    }

    /// <summary>The combs are full: no more honey is stored (the one place this is decided).</summary>
    public bool IsStorageFull => State.Honey >= HoneyStorage;

    /// <summary>There's no room for more wax: no more wax is stored.</summary>
    public bool IsWaxFull => State.Wax >= WaxStorage;

    /// <summary>Honey storage one comb adds right now.</summary>
    public decimal StoragePerComb => Config.HoneyCapPerComb * StorageMultiplier;
    // Cut in stage 7.5 (spec 016): public decimal StoragePerComb => Config.StoragePerComb * StorageMultiplier;

    /// <summary>Wax storage one comb adds right now.</summary>
    public decimal WaxStoragePerComb => Config.WaxCapPerComb * StorageMultiplier;

    /// <summary>Honey a second one comb adds, with the lasting boosts (the wooden hive, guarding).</summary>
    public decimal HoneyPerCombNow => Config.HoneyPerCombPerSecond * HiveMultiplier;

    /// <summary>Free bees' small honey bonus: +0.02% per 100 free bees, capped at +25%; it multiplies
    /// the comb honey, so with no combs it adds nothing. Part of <see cref="HiveMultiplier"/>, the one
    /// place the honey rate is worked out, so live, away, hovers and time-to-full agree.</summary>
    public decimal FreeBeeHoneyFactor => 1m + FreeBeeHoneyBonus(State.Bees);

    /// <summary>The Technologies' multiplier on both caps (honey and wax since stage 7.5).</summary>
    public decimal StorageMultiplier =>
        (Owns(BeekeeperUpgrades.BiggerCombs2) ? Config.BiggerCombs2Multiplier
         : Owns(BeekeeperUpgrades.BiggerCombs1) ? Config.BiggerCombs1Multiplier
         : 1m)
        * (Owns(BeekeeperUpgrades.PropolisSeal) ? Config.PropolisSealStorageMultiplier : 1m);   // stage 7

    /// <summary>Bees the tool catches per click, grown by the Practice upgrades (rounded down).</summary>
    public int BeesPerClick =>
        (int)Math.Floor((State.ToolLevel <= 0 ? Config.BareHandsBees : Config.Tools[State.ToolLevel - 1].BeesPerClick)
                        * PracticeMultiplier);

    /// <summary>Bees a click would catch with <paramref name="tool"/>, Practice counted (for the Shop's blurb).</summary>
    public int BeesPerClickWith(BeekeeperTool tool) => (int)Math.Floor(tool.BeesPerClick * PracticeMultiplier);

    private decimal PracticeMultiplier =>
        Owns(BeekeeperUpgrades.MorePractice) ? Config.MorePracticeMultiplier
        : Owns(BeekeeperUpgrades.Practice) ? Config.PracticeMultiplier
        : 1m;

    /// <summary>Everything one successful click catches: exactly the tool's bees (Practice counted),
    /// so the Shop's "catches N bees" is true. The one place this is worked out, so the catch and the
    /// popup agree.</summary>
    public decimal BeesPerCatch => BeesPerClick * HerbClickNow;

    /// <summary>Quick Fingers: Catch Bee and the Smoker are this many times as strong while it burns, else 1.</summary>
    public decimal HerbClickNow => IsHerb(BeekeeperHerbs.QuickFingers) ? Config.HerbClickMultiplier : 1m;
    // Cut (Bee, 2026-11-10; may return): each catch also brought in a slice of the hive (0.1%, rounded
    // down, capped at 10 x the tool's bees; spec 013, FR-405). The Shop said "2 bees" while gloves caught 3.
    // public decimal BeesPerCatch => BeesPerClick + Math.Min(Math.Floor(State.Bees * Config.CatchSliceShare), SliceCap);
    // public decimal SliceCap => Math.Floor(BeesPerClick * Config.SliceCapMultiple);

    /// <summary>The hive's base honey rate: each comb makes a flat rate (spec 016, FR-703), from the
    /// first bee caught on, however many bees there are. Raids and the like use this, never the
    /// calm boost.</summary>
    public decimal HoneyPerSecond => BaseHoneyPerSecond * HiveMultiplier;

    /// <summary>Honey a second before any boost: the combs' flat rate plus the meadow's (stage 8,
    /// FR-812: the meadow works like one giant comb, so every honey boost applies to it too).
    /// 0 before the first bee. Production and <see cref="HoneyPerSecond"/> both read this.</summary>
    public decimal BaseHoneyPerSecond =>
        HiveStarted ? State.Combs * Config.HoneyPerCombPerSecond + MeadowHoneyPerSecond : 0m;

    /// <summary>The meadow's own honey a second before the boosts (0 without it).</summary>
    public decimal MeadowHoneyPerSecond => State.HasMeadow ? Config.MeadowHoneyPerSecond : 0m;
    // Cut in stage 8 (spec 017): combs only.
    // public decimal HoneyPerSecond =>
    //     HiveStarted ? State.Combs * Config.HoneyPerCombPerSecond * HiveMultiplier : 0m;
    // Cut in stage 7.5 (spec 016): every bee made honey.
    // public decimal HoneyPerSecond => State.Bees * Config.HoneyPerBeePerSecond * HiveMultiplier;

    /// <summary>Lasting boosts to the combs' honey: the wooden hive and guarding ("the hive
    /// feels safe"), multiplied together. Everything that reads honey per second (production,
    /// raids, hover rates) sees it, live and away alike. Wax never does.</summary>
    /// <remarks>Stage 8 (spec 017, FR-805): the honey plants' bonus (wildflowers and bramble past the
    /// first of each) multiplies in here with the other lasting boosts.</remarks>
    /// <remarks>Stage 9 (spec 018, FR-906): winter slows it (<see cref="WinterMultiplier"/>); being
    /// here, it slows the meadow's honey too.</remarks>
    /// <remarks>Bee, 2026-11-12: the Honey Dipper (+50%) is one of the lasting boosts.</remarks>
    public decimal HiveMultiplier => HiveMultiplierBeforeFreeBees * FreeBeeHoneyFactor;

    /// <summary><see cref="HiveMultiplier"/> without the free bees' bonus: the lasting boosts that stay the same
    /// all through a stretch of <see cref="Work"/> (the free bees can grow inside one).</summary>
    private decimal HiveMultiplierBeforeFreeBees => (State.HasWoodenHive ? Config.WoodenHiveHoneyMultiplier : 1m)
        * GuardingMultiplier * PlantBonus(BeekeeperBonusTargets.Honey) * WinterMultiplier * HoneyDipperMultiplier;

    /// <summary>The free bees' honey bonus (the part of <see cref="FreeBeeHoneyFactor"/> above 1) for a hive of
    /// <paramref name="bees"/>; the one formula, so the rate shown and the honey made agree.</summary>
    private decimal FreeBeeHoneyBonus(decimal bees) =>
        Math.Min(Config.FreeBeeHoneyBonusCap, bees / 100m * Config.FreeBeeHoneyBonusPer100);

    /// <summary>
    /// <see cref="FreeBeeHoneyFactor"/> summed over a stretch of <paramref name="seconds"/> while the free bees
    /// grow (review fix, 2026-11-15): from <paramref name="startBees"/> they rise in a straight line for
    /// <paramref name="layingSeconds"/>, then stay at <paramref name="startBees"/> + <paramref name="raised"/>.
    /// The bonus follows them up to its cap. Before, a stretch used its end-of-stretch bees for every second, so
    /// one long stretch (time away) paid more than many short ones (live play); this exact area makes them agree,
    /// the way the wax's bee-seconds already did.
    /// </summary>
    private decimal FreeBeeFactorSeconds(decimal startBees, decimal raised, decimal layingSeconds, decimal seconds)
    {
        // Bees never pass MaxBees, so neither does their bonus.
        decimal cap = Math.Min(Config.FreeBeeHoneyBonusCap, FreeBeeHoneyBonus(Config.MaxBees));
        decimal Bonus(decimal bees) => Math.Min(cap, FreeBeeHoneyBonus(bees));

        decimal area;
        decimal start = Bonus(startBees);
        if (layingSeconds <= 0m || raised <= 0m)
            area = start * layingSeconds;
        else
        {
            // The bonus a second gains while she lays, before the cap (a straight line in the bees).
            decimal slope = raised / 100m * Config.FreeBeeHoneyBonusPer100 / layingSeconds;
            if (start >= cap || slope <= 0m) area = start * layingSeconds;
            else
            {
                decimal toCap = (cap - start) / slope;   // seconds until the bonus reaches its cap
                area = toCap >= layingSeconds
                    ? start * layingSeconds + slope * layingSeconds * layingSeconds / 2m
                    : start * toCap + slope * toCap * toCap / 2m + cap * (layingSeconds - toCap);
            }
        }
        area += Bonus(startBees + raised) * (seconds - layingSeconds);
        return seconds + area;
    }

    /// <summary>The Honey Dipper's honey multiplier: 1.5 once bought, else 1.</summary>
    public decimal HoneyDipperMultiplier => Owns(BeekeeperUpgrades.HoneyDipper) ? Config.HoneyDipperHoneyMultiplier : 1m;
    // Cut in stage 8: public decimal HiveMultiplier => (State.HasWoodenHive ? Config.WoodenHiveHoneyMultiplier : 1m) * GuardingMultiplier * FreeBeeHoneyFactor;

    /// <summary>What the hive makes right now: the base rate with whichever boosts are on (calm
    /// bees, a bee-boost candle, a sage-propolis candle).</summary>
    public decimal HoneyPerSecondNow => HoneyPerSecond * LiveBoostNow * SagePropolisBoostNow;

    /// <summary>The boosts that only work while the app is open, multiplied: calm bees and a
    /// bee-boost candle (stage 7). Time away never has them.</summary>
    public decimal LiveBoostNow =>
        SmokerBoostNow * (IsBeeBoosted ? Config.BeeBoostHoneyMultiplier : 1m)
        * (IsHerb(BeekeeperHerbs.BusyBees) ? Config.HerbHoneyMultiplier : 1m);

    /// <summary>The sage-propolis candle's boost, on while it burns, live or away.</summary>
    public decimal SagePropolisBoostNow => IsSagePropolisBurning ? Config.SagePropolisHoneyMultiplier : 1m;

    /// <summary>Wax the hive makes right now (spec 016, FR-705): a tiny drip plus a little from
    /// every free bee, times the Wax-Catchers. Not multiplied by combs, and no calm, candle,
    /// wooden-hive or guarding term: those boost honey only.</summary>
    // Bee, 2026-11-11: no wax at all (drip included) until the first bee is caught.
    // Stage 8 (spec 017, FR-805): the clover past the first adds its bonus here (WaxMultiplier).
    public decimal WaxPerSecondNow => !HiveStarted ? 0m :
        (Config.WaxBasePerSecond + State.Bees * Config.WaxPerFreeBeePerSecond) * WaxMultiplier * HerbWaxNow;
    // Cut in stage 7.5 (spec 016): wax followed all the honey made, calm counted.
    // public decimal WaxPerSecondNow => HoneyPerSecondNow / Config.HoneyPerWax * WaxPerBatch;

    /// <summary>The Wax-Catchers on the wax rate: 1, 2 with the Wax-Catcher, 3 with the Better
    /// Wax-Catcher (was WaxPerBatch, wax per 50 honey, before stage 7.5).</summary>
    /// <remarks>Stage 8 (spec 017, FR-805): times the wax plants' bonus (clover past the first).</remarks>
    public decimal WaxMultiplier => WaxCatcherFactor * PlantBonus(BeekeeperBonusTargets.Wax);

    /// <summary>The Wax-Catchers alone on the wax rate (the wax hover lists it apart from the clover). Bee,
    /// 2026-11-12: the Wax-Catcher raises the wax cap instead, so only the Better Wax-Catcher boosts the rate
    /// (×1.5). A later Wax-Catcher upgrade will add a wax production boost here (not built yet).</summary>
    public decimal WaxCatcherFactor =>
        State.HasWaxCatcher && Owns(BeekeeperUpgrades.BetterWaxCatcher) ? Config.BetterWaxCatcherBonus : 1m;
    // Cut (Bee, 2026-11-12; may return): the Wax-Catcher itself doubled the wax rate.
    // !State.HasWaxCatcher ? 1m
    //     : Owns(BeekeeperUpgrades.BetterWaxCatcher) ? Config.WaxCatcherMultiplier * Config.BetterWaxCatcherBonus
    //     : Config.WaxCatcherMultiplier;

    public bool Owns(string upgradeId) => State.Upgrades.Contains(upgradeId);

    /// <summary>floor(base × growth^n), or decimal.MaxValue (effectively unbuyable) on overflow.</summary>
    private static decimal GrowingPrice(decimal basePrice, decimal growth, int n)
    {
        try
        {
            decimal cost = basePrice;
            for (int i = 0; i < n; i++) cost *= growth;
            return Math.Floor(cost);
        }
        catch (OverflowException)
        {
            return decimal.MaxValue;
        }
    }

    /// <summary>The next comb's wax price: floor(10 × 1.25^n), n = combs bought (the starter doesn't count).</summary>
    /// <remarks>Stage 8 (spec 017, FR-808): Wooden Frames halve it, rounded down. A bought discount,
    /// not a wall fix: nothing lowers a price because of a wall.</remarks>
    public decimal CombCost
    {
        get
        {
            decimal wax = GrowingPrice(Config.CombBaseWaxCost, Config.CombCostGrowth, CombsBought);
            return Owns(BeekeeperUpgrades.WoodenFrames) && wax != decimal.MaxValue
                ? Math.Floor(wax * Config.FramesWaxMultiplier) : wax;
        }
    }
    // Cut in stage 8: public decimal CombCost => GrowingPrice(Config.CombBaseWaxCost, Config.CombCostGrowth, CombsBought);
    // Cut in stage 7.5 (spec 016): floor(50 × 1.25^N) where N = combs already built (no starter comb).

    /// <summary>The next comb's bee price: floor(20 × 1.4^n), n = combs bought. These bees move in
    /// and leave the free-bee count; "how many bees fit in a comb" is simply this price.</summary>
    public decimal CombBeeCost => GrowingPrice(Config.CombBaseBeeCost, Config.CombBeeCostGrowth, CombsBought);

    /// <summary>The next Honey Super's price in wood (stage 8, FR-807a; Beebits before): floor(10 × 1.5^level).</summary>
    public decimal HoneySuperCost => GrowingPrice(Config.HoneySuperBaseCost, Config.HoneySuperCostGrowth, State.HoneySupers);

    /// <summary>The next Wax Tray's price in Beebits: floor(100 × 1.6^level).</summary>
    public decimal WaxTrayCost => GrowingPrice(Config.WaxTrayBaseCost, Config.WaxTrayCostGrowth, State.WaxTrays);

    /// <summary>The next tool in the shop, or null when the Vacuum is owned.</summary>
    public BeekeeperTool? NextTool =>
        State.ToolLevel < Config.Tools.Count ? Config.Tools[State.ToolLevel] : null;

    /// <summary>Honey in one bear trade: 10, or 8 under the trade agreement. Everything about
    /// selling reads this and <see cref="BeebitsPerTradeNow"/>.</summary>
    /// <remarks>Bee, 2026-11-15: under the Trades herb a trade is as many bundles as it takes for whole Beebits
    /// (2 bundles: 20 honey for 15), so the pay is exact and no decimals show.</remarks>
    public decimal HoneyPerTradeNow =>
        (State.HasTradeAgreement ? Config.BetterHoneyPerTrade : Config.HoneyPerTrade) * BundlesPerTrade;

    /// <summary>Beebits one bundle of plain honey pays right now: 5, more under the Trades herb
    /// (stage 10, spec 019; the bear paid herbs 2026-11-11 to 11-12).</summary>
    public decimal BeebitsPerTradeNow => WithTradeHerb(Config.BeebitsPerTrade) * BundlesPerTrade;

    /// <summary>Bundles in one trade: the fewest that pay whole Beebits at the rate of the moment (1, or 2 under
    /// the Trades herb's ×1.5). Capped at 100 for an odd config.</summary>
    private decimal BundlesPerTrade
    {
        get
        {
            decimal each = WithTradeHerb(Config.BeebitsPerTrade);
            int n = 1;
            while (n < 100 && n * each != Math.Floor(n * each)) n++;
            return n;
        }
    }

    /// <summary>Beebits one potted honey pays right now: 20, more under the Trades herb.</summary>
    public decimal PottedHoneyBeebitsNow => WithTradeHerb(Config.PottedHoneyBeebits);

    // Cut (Bee, 2026-11-12): the bear paid herbs, and the Hippies paid Beebits for herbal candles.
    // /// <summary>Herbs one bear trade gives right now: 1, more under Good Deals.</summary>
    // public decimal HerbsPerTradeNow => WithTradeHerb(Config.HerbsPerTrade);
    // /// <summary>Beebits the Hippies pay for one herbal candle right now, more under Good Deals.</summary>
    // public decimal BeebitsPerCandleNow => WithTradeHerb(Config.HippieBeebitsPerCandle);

    /// <summary>A trade's pay under the Trades herb, exact; unchanged otherwise. Bee, 2026-11-15: it rounded up
    /// per bundle (Sell All of 10 bundles paid 80, not 75); now a plain-honey trade holds enough bundles for
    /// whole Beebits (<see cref="BundlesPerTrade"/>).</summary>
    private decimal WithTradeHerb(decimal pay) => pay * HerbTradeNow;

    /// <summary>Beebits a sale of <paramref name="count"/> trades pays at <paramref name="each"/>. Whole already;
    /// the floor only guards an odd config (Beebits stay whole).</summary>
    private static decimal SalePay(decimal count, decimal each) => Math.Floor(count * each);

    public bool CanSell => State.Honey >= HoneyPerTradeNow;

    /// <summary>At least one potted honey to sell (stage 10). Like plain honey, the screen only
    /// offers it while the bear's trades are open.</summary>
    public bool CanSellPotted => State.PottedHoney >= 1m;

    // Bee, 2026-11-11: no catching tool can be bought without the gloves (found in a story card).
    public bool CanBuyNextTool => NextTool is { } t && State.ShopRevealed && State.ToolLevel >= 1 && State.Beebits >= t.Cost;

    public bool CanBuyWaxCatcher =>
        !State.HasWaxCatcher && State.ShopRevealed && State.Beebits >= Config.WaxCatcherCost;

    /// <summary>A comb needs both its bees and its wax (spec 016, FR-708).</summary>
    public bool CanBuildComb => State.Bees >= CombBeeCost && State.Wax >= CombCost;
    // Cut in stage 7.5 (spec 016): public bool CanBuildComb => State.Wax >= CombCost;

    // ------------------------------------------------------------------ walls (stage 7.5)

    /// <summary>A wax price above the wax cap: a wall (spec 016, FR-710). Walls are intended; the
    /// screen says it needs more storage. Nothing ever lowers a price or raises a cap because of one.</summary>
    public bool IsWaxWall(decimal wax) => wax > WaxStorage;

    /// <summary>A honey price above the honey cap: the same kind of wall.</summary>
    public bool IsHoneyWall(decimal honey) => honey > HoneyStorage;

    /// <summary>The next comb's price doesn't fit in the hive.</summary>
    public bool CombIsWall => IsWaxWall(CombCost);

    /// <summary>The wooden hive's price doesn't fit in the hive.</summary>
    public bool WoodenHiveIsWall => IsWaxWall(Config.WoodenHiveWax);

    /// <summary>A Shop upgrade's price doesn't fit in the hive.</summary>
    public bool UpgradeIsWall(string id) =>
        Config.Upgrades.FirstOrDefault(u => u.Id == id) is { } u && IsWaxWall(u.Wax);

    /// <summary>The Shop is on screen (it also opens with The Workbench).</summary>
    public bool ShopShown => State.ShopRevealed || State.WorkbenchRevealed;

    /// <summary>The comb row is on screen (the Combs panel, at The Workbench).</summary>
    public bool CombRowShown => State.CombsRevealed || State.WorkbenchRevealed;

    /// <summary>Any price the player can see is a wall: the comb or the wooden hive. (A Shop upgrade whose price
    /// is a wall is hidden from the Shop, so it is never seen; review fix, 2026-11-15, dropped that always-false part.)</summary>
    public bool AnyWallShown =>
        (CombRowShown && CombIsWall)
        || (WoodenHiveOffered && WoodenHiveIsWall);

    /// <summary>The first wall the player sees is told once in the log. Only a flag and an event.</summary>
    private void CheckWalls(List<BeekeeperEvent> events)
    {
        if (State.FirstWallAnnounced || !AnyWallShown) return;
        State.FirstWallAnnounced = true;
        events.Add(new BeekeeperEvent(BeekeeperEvents.FirstWall));
    }

    // ------------------------------------------------------------------ capacity upgrades (stage 7.5)

    /// <summary>Honey Super and Wax Tray rows show at The Workbench once the Shop is showing (the Workbench or 15 Beebits) and
    /// the Combs panel has appeared. Beebits only, so selling honey always pays past a wall.</summary>
    // Review change (Bee): the Shop counts as open once the Workbench shows it, not only after 15 Beebits.
    public bool CapacityUpgradesShown => ShopShown && State.CombsRevealed;
    // Cut after the stage 7.5 review: public bool CapacityUpgradesShown => State.ShopRevealed && State.CombsRevealed;

    /// <summary>The Honey Super row (stage 8, FR-807a): it costs wood, so it shows only once the
    /// carpenter bee has brought some. Supers bought with Beebits before stay.</summary>
    public bool HoneySuperShown => CapacityUpgradesShown && WoodSeen;

    public bool CanBuyHoneySuper => HoneySuperShown && State.Wood >= HoneySuperCost;
    // Cut in stage 8 (spec 017): public bool CanBuyHoneySuper => CapacityUpgradesShown && State.Beebits >= HoneySuperCost;

    public bool CanBuyWaxTray => CapacityUpgradesShown && State.Beebits >= WaxTrayCost;

    /// <summary>One more Honey Super: more honey room, for wood (stage 8). Bought again and again.</summary>
    public ActionResult BuyHoneySuper()
    {
        if (!CanBuyHoneySuper) return ActionResult.Refused;
        decimal cost = HoneySuperCost;
        State.Wood -= cost;
        // Cut in stage 8 (spec 017): State.Beebits -= cost;
        State.HoneySupers++;
        RefreshStorageFlag();
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.HoneySuperBought, State.HoneySupers) };
        return new ActionResult(true, cost, events);
    }

    /// <summary>One more Wax Tray: more wax room. Bought again and again.</summary>
    public ActionResult BuyWaxTray()
    {
        if (!CanBuyWaxTray) return ActionResult.Refused;
        decimal cost = WaxTrayCost;
        State.Beebits -= cost;
        State.WaxTrays++;
        RefreshStorageFlag();
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.WaxTrayBought, State.WaxTrays) };
        return new ActionResult(true, cost, events);
    }

    /// <summary>A gap longer than the threshold counts as time away.</summary>
    public bool IsAway(decimal gapSeconds) => gapSeconds > Config.AwayThresholdSeconds;

    // ------------------------------------------------------------------ catching

    public CatchResult Catch()
    {
        var events = new List<BeekeeperEvent>();

        // Only Bare Hands ever get stung, and only after the first 10 bees caught by hand: the first
        // sting at 10 is certain (it brings the "Ouch!" card), then it is a chance on every click.
        // Better tools never roll the dice.
        bool stingsOn = State.ToolLevel == 0 && State.BeesCaught >= Config.StingsStartAtBees;
        if (stingsOn && (!State.FirstStingDone || _rng.NextDouble() < Config.StingChance))
        {
            State.FirstStingDone = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.Sting));
            return new CatchResult(true, 0m, events);
        }

        decimal gained = BeesPerCatch;
        State.Bees = Math.Min(Config.MaxBees, State.Bees + gained);
        State.BeesCaught += (long)gained;
        // Bee, 2026-11-12: the "gloves fit well" card goes once enough bees are caught while it shows.
        if (State.StoryHere == BeekeeperStories.GlovesFit)
        {
            State.GlovesLineBeesLeft = Math.Max(0, State.GlovesLineBeesLeft - (int)gained);
            if (State.GlovesLineBeesLeft == 0) FinishStory(BeekeeperStories.GlovesFit);
        }
        FinishOpeningIfDue();   // stage 10: the first bee caught ends the opening card
        if (!State.HoneyRevealed)
        {
            State.HoneyRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.FirstBee));
        }
        CheckReveals(events);   // the bear comes at 100 bees caught by hand
        return new CatchResult(false, gained, events);
    }

    // ------------------------------------------------------------------ time passing

    /// <summary>Normal play: the hive works for <paramref name="seconds"/>. The live boosts
    /// (smoker clicks, a bee-boost candle) are used up only by live play.</summary>
    public AdvanceResult Advance(decimal seconds)
    {
        var events = new List<BeekeeperEvent>();
        // The stretch is split at whichever live boost (smoker, bee-boost candle) ends first,
        // again and again (FR-604).
        Made total = default;
        decimal left = seconds;
        if (left <= 0m) total = Work(left, events);
        while (left > 0m)
        {
            bool smoker = State.SmokerBoostSecondsLeft > 0m, beeBoost = State.BeeBoostSecondsLeft > 0m;
            bool herb = IsHerbBurning;
            decimal step = left;
            if (smoker) step = Math.Min(step, State.SmokerBoostSecondsLeft);
            if (beeBoost) step = Math.Min(step, State.BeeBoostSecondsLeft);
            if (herb) step = Math.Min(step, State.HerbSecondsLeft);
            total += Work(step, events, LiveBoostNow, HerbWaxNow);   // the hive goes on growing across the parts (FR-402)
            // Wanderers: stray bees fly in while the herb burns (added after the stretch's work).
            if (IsHerb(BeekeeperHerbs.Wanderers))
                State.Bees = Math.Min(Config.MaxBees, Snap(State.Bees + Config.HerbWanderersBeesPerMinute * step / 60m));
            left -= step;
            if (smoker) State.SmokerBoostSecondsLeft = Math.Max(0m, State.SmokerBoostSecondsLeft - step);
            if (beeBoost)
            {
                State.BeeBoostSecondsLeft -= step;
                if (State.BeeBoostSecondsLeft <= 0m) { State.BeeBoostSecondsLeft = 0m; events.Add(new BeekeeperEvent(BeekeeperEvents.BeeBoostOut)); }
            }
            if (herb)
            {
                State.HerbSecondsLeft -= step;
                if (State.HerbSecondsLeft <= 0m)
                {
                    events.Add(new BeekeeperEvent(BeekeeperEvents.HerbOut, 0m, State.HerbBuff));
                    State.HerbSecondsLeft = 0m;
                    State.HerbBuff = null;
                }
            }
        }
        return new AdvanceResult(total.Stored, total.Wax, events, total.Raised);
    }

    // ------------------------------------------------------------------ the Smoker (stage 3)

    public bool CanUseSmoker => Owns(BeekeeperUpgrades.Smoker);

    public bool IsSmokerBoosted => State.SmokerBoostSecondsLeft > 0m;

    /// <summary>The smoker boost in percent. Today the config's base; later smoker upgrades
    /// will add their points here.</summary>
    public decimal SmokerBoostPercent => Config.SmokerBoostPercent;

    /// <summary>The boost in percent right now: <see cref="SmokerBoostPercent"/>, x3 under Quick Fingers.
    /// (The Shop keeps quoting the base.)</summary>
    public decimal SmokerBoostPercentNow => SmokerBoostPercent * HerbClickNow;

    /// <summary>The smoker's honey factor right now: 1 + percent/100 while boosted, else 1.
    /// Multiplied with the other honey boosts.</summary>
    public decimal SmokerBoostNow => IsSmokerBoosted ? 1m + SmokerBoostPercentNow / 100m : 1m;

    /// <summary>Live seconds one smoker click lasts: 1, or 30 under Lingering Smoke.</summary>
    public decimal SmokerClickSeconds =>
        IsHerb(BeekeeperHerbs.LingeringSmoke) ? Config.HerbSmokerSeconds : Config.SmokerBoostSeconds;

    /// <summary>A smoker click: honey is boosted for the next few live seconds (refreshes, not stacks).</summary>
    public ActionResult UseSmoker()
    {
        if (!CanUseSmoker) return ActionResult.Refused;
        State.SmokerBoostSecondsLeft = SmokerClickSeconds;
        return new ActionResult(true, SmokerClickSeconds, Array.Empty<BeekeeperEvent>());
    }

    /// <summary>
    /// Time away: the same maths as <see cref="Advance"/> in one step, capped at 3 days,
    /// paid at the offline rate, ignored if negative. Storage still limits the honey. For the app
    /// having been closed: an empty pantry and a sage-propolis candle burning down are told in the
    /// <see cref="AwayResult.WelcomeBack"/> summary instead of as their live events.
    /// </summary>
    public AwayResult AdvanceAway(decimal gapSeconds)
    {
        var events = new List<BeekeeperEvent>();
        if (gapSeconds <= 0m) return new AwayResult(0m, 0m, 0m, events);

        decimal propolisBefore = State.Propolis, woodBefore = State.Wood;
        var (credited, m) = AwayStretch(gapSeconds, events);

        if (m.PantryEmptied) events.RemoveAll(e => e.Key == BeekeeperEvents.PantryEmpty);
        bool sageOut = events.RemoveAll(e => e.Key == BeekeeperEvents.SagePropolisOut) > 0;
        // Stage 8 (spec 017): the hotel's gifts while away are told in one welcome-back line. A rare
        // bee's first gift keeps its own line (it joins the Bees tab).
        decimal giftSeeds = 0m, giftHerbs = 0m, giftPropolis = 0m;
        foreach (var e in events.Where(e => e.Key is BeekeeperEvents.HotelGift or BeekeeperEvents.RareBeeArrives))
        {
            switch (ParseGiftText(e.Text).Gift)
            {
                case BeekeeperGifts.Seed: giftSeeds += e.Value; break;
                case BeekeeperGifts.Herbs: giftHerbs += e.Value; break;
                case BeekeeperGifts.Propolis: giftPropolis += e.Value; break;
            }
        }
        events.RemoveAll(e => e.Key == BeekeeperEvents.HotelGift);
        // Stage 9 (spec 018): bloom changes while away make one welcome-back line, in order.
        var blooms = events.Where(e => e.Key == BeekeeperEvents.BloomChanged).Select(e => e.Text ?? "").ToList();
        events.RemoveAll(e => e.Key == BeekeeperEvents.BloomChanged);

        // In reading order, top line first: "the combs filled…", "the queen raised…", "propolis…",
        // "the pantry…", "the candle…".
        var welcome = new List<BeekeeperEvent>();
        // Stage 7.5 (spec 016, FR-713): told once the first bee has been caught, even with 0 free
        // bees. Before that there is no message, though the wax drip still counted.
        // Cut in stage 7.5: if (State.Bees > 0m)
        if (HiveStarted)
        {
            // Under 1 honey would read "filled with 0 honey", so that counts as nothing.
            decimal honey = m.Stored;
            // Cut in stage 7.5 (spec 016): honey that found a home included the bear's take.
            // decimal honey = m.Stored + m.Taken;
            welcome.Add(honey >= 1m
                ? new BeekeeperEvent(BeekeeperEvents.WelcomeBack, honey)
                : new BeekeeperEvent(BeekeeperEvents.WelcomeBackNothing));
            decimal raised = Math.Floor(m.Raised);
            if (raised > 0m) welcome.Add(new BeekeeperEvent(BeekeeperEvents.WelcomeBackQueen, raised));
            // Propolis from the poplar only: the wool carder bee's is told with the hotel's gifts.
            decimal gathered = Math.Floor(State.Propolis - propolisBefore - giftPropolis);
            if (gathered > 0m) welcome.Add(new BeekeeperEvent(BeekeeperEvents.WelcomeBackPropolis, gathered));
            decimal wood = Math.Floor(State.Wood - woodBefore);
            if (wood > 0m) welcome.Add(new BeekeeperEvent(BeekeeperEvents.WelcomeBackWood, wood));
            if (giftSeeds + giftHerbs + giftPropolis > 0m)
                welcome.Add(new BeekeeperEvent(BeekeeperEvents.WelcomeBackHotel, giftSeeds,
                    giftPropolis.ToString(System.Globalization.CultureInfo.InvariantCulture), giftHerbs));
            // Cut in stage 7.5 (spec 016): the bear's Beebits for the overflow.
            // if (m.AgreementBeebits > 0m)
            //     welcome.Add(new BeekeeperEvent(BeekeeperEvents.WelcomeBackBear, m.AgreementBeebits, State.BearName));
            if (m.PantryEmptied) welcome.Add(new BeekeeperEvent(BeekeeperEvents.WelcomeBackPantry));
            if (sageOut) welcome.Add(new BeekeeperEvent(BeekeeperEvents.WelcomeBackSageOut));
        }
        // The calendar runs from the first plant, which needs a started hive in play, but a debug
        // start can come first: tell the blooms whatever the hive.
        if (blooms.Count > 0)
            welcome.Add(new BeekeeperEvent(BeekeeperEvents.WelcomeBackBlooms, blooms.Count, string.Join("|", blooms)));
        return new AwayResult(credited, m.Stored, m.Wax, events, m.Raised, m.PantryEmptied)
        {
            WelcomeBack = welcome,
        };
    }

    /// <summary>
    /// A long gap while the app stayed open (a sleep, a frozen window): the same maths and caps as
    /// <see cref="AdvanceAway"/>, but the events come out as in live play (an empty pantry and a
    /// candle burning out are told as they happened) and there is no welcome-back summary, since
    /// only reopening the app says "While you were away".
    /// </summary>
    public AwayResult AdvanceGap(decimal gapSeconds)
    {
        var events = new List<BeekeeperEvent>();
        if (gapSeconds <= 0m) return new AwayResult(0m, 0m, 0m, events);
        var (credited, m) = AwayStretch(gapSeconds, events);
        return new AwayResult(credited, m.Stored, m.Wax, events, m.Raised, m.PantryEmptied);
    }

    /// <summary>The one place a gap is worked out, shared by <see cref="AdvanceAway"/> and
    /// <see cref="AdvanceGap"/>, so they cannot drift apart.</summary>
    private (decimal Credited, Made Made) AwayStretch(decimal gapSeconds, List<BeekeeperEvent> events)
    {
        decimal credited = Math.Min(gapSeconds, Config.OfflineCapSeconds);
        var m = Work(credited * Config.OfflineRate, events);   // the bee-boost candle waits: no live boost here
        return (credited, m);
    }

    /// <summary>What one stretch made: honey and wax stored, bees raised.</summary>
    private readonly record struct Made(decimal Stored, decimal Wax, decimal Raised, bool PantryEmptied)
    {
        public static Made operator +(Made x, Made y) => new(x.Stored + y.Stored, x.Wax + y.Wax, x.Raised + y.Raised,
            x.PantryEmptied || y.PantryEmptied);
    }
    // Cut in stage 7.5 (spec 016): Taken (the overflow honey the bear took) and AgreementBeebits.
    // private readonly record struct Made(decimal Stored, decimal Wax, decimal Raised, decimal Taken,
    //                                     decimal AgreementBeebits, bool PantryEmptied)
    // {
    //     public static Made operator +(Made x, Made y) => new(x.Stored + y.Stored, x.Wax + y.Wax, x.Raised + y.Raised,
    //         x.Taken + y.Taken, x.AgreementBeebits + y.AgreementBeebits, x.PantryEmptied || y.PantryEmptied);
    // }

    /// <summary>
    /// The hive and the garden work for <paramref name="seconds"/>. If the growing seed sprouts
    /// part-way, the stretch is split there, so a new specialty (guarding's honey, foraging's
    /// pollen) only counts from the moment it sprouts, the same live and away (spec 014, FR-503).
    /// </summary>
    private Made Work(decimal seconds, List<BeekeeperEvent> events, decimal boost = 1m, decimal waxBoost = 1m)
    {
        if (seconds <= 0m) return Produce(seconds, events, boost, waxBoost);

        // Cut in stage 7 (spec 015): the stretch was split once, at the one growing seed's sprout.
        // decimal before = IsGrowing ? Math.Min(seconds, State.GrowSecondsLeft) : seconds;
        // var made = Produce(before, events, boost);
        // GrowGarden(before, events);
        // decimal after = seconds - before;
        // if (after > 0m) { made += Produce(after, events, boost); GrowGarden(after, events); }
        // return made;

        // Now it is split at every change, soonest first (FR-603): the sage-propolis candle burning
        // out and (stage 8, FR-811) each bee hotel gift. Between splits nothing changes, so every
        // piece is exact and many short stretches equal one long one, live or away. (Stage 7 also
        // split at each bed's sprout; plants grow at once since stage 8.)
        Made made = default;
        decimal left = seconds;
        while (left > 0m)
        {
            decimal step = left;
            // Cut in stage 8 (spec 017): foreach (var bed in State.Beds) step = Math.Min(step, bed.SecondsLeft);
            if (State.SagePropolisSecondsLeft > 0m) step = Math.Min(step, State.SagePropolisSecondsLeft);
            bool hotel = HasBeeHotel;
            if (hotel) step = Math.Min(step, State.HotelSecondsToNext);
            // Stage 9 (spec 018, FR-904): and at every change of bloom. Produce and Attract read the
            // piece's bloom; it moves on only at the end of the piece.
            bool calendar = State.CalendarStarted;
            if (calendar) step = Math.Min(step, State.BloomSecondsLeft);

            made += Produce(step, events, boost, waxBoost);
            Attract(step, events);
            left -= step;

            if (calendar)
            {
                State.BloomSecondsLeft -= step;
                if (State.BloomSecondsLeft <= 0m) NextBloom(events);
            }

            if (hotel)
            {
                State.HotelSecondsToNext -= step;
                if (State.HotelSecondsToNext <= 0m)
                {
                    State.HotelSecondsToNext = Config.HotelGiftSeconds;
                    GiveHotelGift(events);
                }
            }

            // Apply whatever happened at the end of the piece (ties in one instant: any order).
            if (State.SagePropolisSecondsLeft > 0m)
            {
                State.SagePropolisSecondsLeft -= step;
                if (State.SagePropolisSecondsLeft <= 0m)
                {
                    State.SagePropolisSecondsLeft = 0m;
                    events.Add(new BeekeeperEvent(BeekeeperEvents.SagePropolisOut));
                }
            }
            // Cut in stage 8 (spec 017): GrowBeds(step, events);
        }
        CheckWalls(events);   // the first propolis or wood may show a new price
        return made;
    }

    // Cut in stage 8 (spec 017, FR-803): plants grow at once, so no bed grows or sprouts.
    // /// <summary>Beds grow for <paramref name="step"/> seconds; those that reach zero sprout.</summary>
    // private void GrowBeds(decimal step, List<BeekeeperEvent> events)
    // {
    //     foreach (var bed in State.Beds.ToList())
    //     {
    //         bed.SecondsLeft -= step;
    //         if (bed.SecondsLeft <= 0m) Sprout(bed, events);
    //     }
    // }
    //
    // private void Sprout(BeekeeperBed bed, List<BeekeeperEvent> events)
    // {
    //     State.Beds.Remove(bed);
    //     State.Plants.Add(bed.PlantId);
    //     events.Add(new BeekeeperEvent(BeekeeperEvents.SeedSprouted, 0m, bed.PlantId));
    //     events.Add(new BeekeeperEvent(BeekeeperEvents.PlantRevealed, 0m, bed.PlantId));
    // }

    /// <summary>Closer than this to a tidy number counts as that number.</summary>
    private const decimal RoundingDust = 0.00000000000000001m;

    /// <summary>A third of a bee can't be stored exactly, so sums of many short stretches end a
    /// hair under the true amount (1999.99… for 2000). This puts a running total back on the tidy
    /// number when it is only rounding dust away, so live play and time away agree.</summary>
    private static decimal Snap(decimal value)
    {
        decimal tidy = Math.Round(value, 15);
        return Math.Abs(value - tidy) < RoundingDust ? tidy : value;
    }

    /// <summary>
    /// The hive works for <paramref name="seconds"/> in one exact step, so many short stretches
    /// add up to one long one (FR-402, FR-403; spec 016, FR-706).
    /// <para>Honey (stage 7.5): each comb makes a flat rate, times the boosts, from the first bee
    /// on (none before). Wax: a tiny drip plus a little from every free bee, times the Wax-Catchers.
    /// While the queen lays, the free bees grow in a straight line, so the wax from them is the area
    /// under that line; the stretch is split where the pantry runs out (growth before, flat after).</para>
    /// <para>Each is stored up to the room left; the rest stops (nothing is wasted into the other,
    /// nothing is sold). The rates never read what is stored, so <c>min(made, room)</c> keeps many
    /// short stretches equal to one long one, even when a cap is reached part-way.</para>
    /// </summary>
    private Made Produce(decimal seconds, List<BeekeeperEvent> events, decimal boost = 1m, decimal waxBoost = 1m)
    {
        RefreshStorageFlag();
        if (seconds <= 0m) return default;

        // The brood. Laying lasts until the pantry (bees it can still feed) runs out.
        decimal perMinute = LayingBeesPerMinute;
        decimal raised = 0m, layingSeconds = 0m;
        bool emptied = false;
        if (perMinute > 0m)
        {
            decimal canFeed = State.BeeBread * Config.BeesPerBeeBread;
            decimal wouldRaise = perMinute * seconds / 60m;
            if (wouldRaise >= canFeed - RoundingDust)
            {
                raised = canFeed;
                layingSeconds = Math.Min(seconds, canFeed * 60m / perMinute);
                emptied = true;
            }
            else
            {
                raised = wouldRaise;
                layingSeconds = seconds;
            }
        }

        // Bee-seconds: the flat hive, plus the growing triangle, plus the new bees after laying stops.
        decimal beeSeconds = State.Bees * seconds
                             + perMinute * layingSeconds * layingSeconds / 120m
                             + raised * (seconds - layingSeconds);
        // The free bees' honey bonus over the same stretch (review fix, 2026-11-15), worked out before they grow.
        decimal factorSeconds = FreeBeeFactorSeconds(State.Bees, raised, layingSeconds, seconds);

        State.Bees = Math.Min(Config.MaxBees, Snap(State.Bees + raised));
        if (perMinute > 0m)
            State.BeeBread = emptied ? 0m : Math.Max(0m, Snap(State.BeeBread - raised / Config.BeesPerBeeBread));
        if (emptied && !State.PantryEmptyAnnounced)
        {
            State.PantryEmptyAnnounced = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.PantryEmpty));
        }

        // Cut in stage 7.5 (spec 016): with no bee-seconds nothing was made. Now the wax drips and
        // the reveals run with no bees at all.
        // if (beeSeconds <= 0m) return new Made(0m, 0m, raised, 0m, 0m, emptied);

        // Honey: flat per comb (spec 016, FR-703), boosted by calm and candles (boost, the
        // sage-propolis candle) and the hive (wooden hive, guarding). None before the first bee.
        // Stage 8 (spec 017): the meadow's honey joins the combs' before the boosts (BaseHoneyPerSecond).
        // Review fix (2026-11-15): the free bees' bonus is summed over the stretch (factorSeconds), as they grow.
        decimal made = BaseHoneyPerSecond * factorSeconds * boost * SagePropolisBoostNow * HiveMultiplierBeforeFreeBees;
        // Cut in stage 8: decimal made = HiveStarted
        //     ? State.Combs * Config.HoneyPerCombPerSecond * seconds * boost * SagePropolisBoostNow * HiveMultiplier
        //     : 0m;
        // Cut in stage 7.5 (spec 016): every bee-second made honey.
        // decimal made = beeSeconds * Config.HoneyPerBeePerSecond * boost * SagePropolisBoostNow * HiveMultiplier;
        decimal room = Math.Max(0m, HoneyStorage - State.Honey);
        decimal stored = Math.Min(made, room);
        State.Honey = Snap(State.Honey + stored);

        // Cut after the stage 7.5 review (Bee): no log line when the honey is capped.
        // if (made > room && !State.StorageFullAnnounced)
        // {
        //     State.StorageFullAnnounced = true;
        //     events.Add(new BeekeeperEvent(BeekeeperEvents.StorageFull));
        // }

        // Cut in stage 7.5 (spec 016): the trade agreement's auto-sale. Full combs simply stop.
        // // The trade agreement: the bear takes the overflow at half price, fractions kept (FR-404).
        // decimal taken = 0m, agreementBeebits = 0m;
        // if (State.HasTradeAgreement && made > stored)
        // {
        //     taken = made - stored;
        //     State.AgreementHoneyProgress = Snap(State.AgreementHoneyProgress + taken);
        //     agreementBeebits = Math.Floor(State.AgreementHoneyProgress / Config.AgreementHoneyPerBeebit);
        //     if (agreementBeebits > 0m)
        //     {
        //         State.AgreementHoneyProgress -= agreementBeebits * Config.AgreementHoneyPerBeebit;
        //         State.Beebits += agreementBeebits;
        //         State.BeebitsRevealed = true;
        //     }
        // }

        // Cut in stage 7.5 (spec 016): wax followed all the honey the bees made.
        // // Wax follows all the honey the bees make, so it keeps coming when the combs are
        // // full (Leah, 2026-11-07). Selling honey never touches it.
        // decimal waxMade = 0m;
        // State.WaxProgress = Snap(State.WaxProgress + made);
        // decimal batches = Math.Floor(State.WaxProgress / Config.HoneyPerWax);
        // if (batches > 0m)
        // {
        //     State.WaxProgress -= batches * Config.HoneyPerWax;
        //     waxMade = batches * WaxPerBatch;
        //     State.Wax += waxMade;
        //     if (!State.WaxRevealed)
        //     {
        //         State.WaxRevealed = true;
        //         events.Add(new BeekeeperEvent(BeekeeperEvents.FirstWax));
        //     }
        // }

        // Wax (spec 016, FR-705/706): the drip plus the free bees' share, times the Wax-Catchers;
        // no calm, candle, wooden-hive or guarding term. Stored up to the wax cap; the rest stops.
        // Bee, 2026-11-11: the drip waits for the first bee caught (HiveStarted), like the honey.
        decimal waxMade = !HiveStarted ? 0m
            : (Config.WaxBasePerSecond * seconds + beeSeconds * Config.WaxPerFreeBeePerSecond) * WaxMultiplier * waxBoost;
        decimal waxRoom = Math.Max(0m, WaxStorage - State.Wax);
        decimal waxStored = Math.Min(waxMade, waxRoom);
        State.Wax = Snap(State.Wax + waxStored);

        // Cut after the stage 7.5 review (Bee): no log line when the wax is capped.
        // if (waxMade > 0m && State.Wax >= WaxStorage && !State.WaxFullAnnounced)
        // {
        //     State.WaxFullAnnounced = true;
        //     events.Add(new BeekeeperEvent(BeekeeperEvents.WaxFull));
        // }
        if (!State.WaxRevealed && State.Wax >= Config.WaxRevealWax)
        {
            State.WaxRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.FirstWax));
        }

        CheckReveals(events);
        return new Made(stored, waxStored, raised, emptied);
    }

    // ------------------------------------------------------------------ the queen (stage 5)

    /// <summary>0 = the skep, 1 = the wooden hive; later hives add steps.</summary>
    public int HiveStep => State.HasWoodenHive ? 1 : 0;

    /// <summary>Bees a minute the queen raises in this hive when fed, faster with nursing (stage 7).
    /// Everything that reads her rate (the brood, the pantry, hover rates, welcome-back) sees it.</summary>
    public decimal QueenRatePerMinute
    {
        get
        {
            var rates = Config.QueenBeesPerMinute;
            return (rates.Count == 0 ? 0m : rates[Math.Min(HiveStep, rates.Count - 1)]) * NursingMultiplier;
        }
    }

    /// <summary>Bees a second the queen raises right now before nursing (and its crocus): the hover's source
    /// line, with nursing listed as a boost (review fix, 2026-11-15).</summary>
    public decimal QueenBaseBeesPerSecondNow => NursingMultiplier > 0m ? QueenBeesPerSecondNow / NursingMultiplier : 0m;

    public bool HasQueen => State.QueenSettled;

    /// <summary>The queen lays while there is bee bread; otherwise she rests.</summary>
    public bool IsQueenLaying => State.QueenSettled && State.BeeBread > 0m && QueenRatePerMinute > 0m;

    private decimal LayingBeesPerMinute => IsQueenLaying ? QueenRatePerMinute : 0m;

    public decimal QueenBeesPerSecondNow => LayingBeesPerMinute / 60m;

    public decimal BeeBreadPerSecondNow => QueenBeesPerSecondNow / Config.BeesPerBeeBread;

    /// <summary>How long the pantry lasts at this rate, or 0 when the queen is resting.</summary>
    public decimal PantrySecondsLeft =>
        IsQueenLaying ? State.BeeBread * Config.BeesPerBeeBread * 60m / QueenRatePerMinute : 0m;

    private void SettleQueenIfDue(List<BeekeeperEvent> events)
    {
        // The wooden hive brings the queen: moving in is the introduction to her (Bee, 2026-11-12;
        // briefly she came with the first bee bread, but then the skep ate the bread meant for the move).
        if (State.QueenSettled || !State.HasWoodenHive) return;
        State.QueenSettled = true;
        events.Add(new BeekeeperEvent(BeekeeperEvents.QueenSettles));
        // Moving in with an empty pantry: no "pantry is empty" line, but fresh bee bread says so.
        if (State.BeeBread <= 0m) State.PantryEmptyAnnounced = true;
    }

    /// <summary>Bee bread came in: a resting queen gets back to work, and says so once.</summary>
    private void NoteBeeBreadAdded(List<BeekeeperEvent> events)
    {
        if (!State.PantryEmptyAnnounced || State.BeeBread <= 0m) return;
        State.PantryEmptyAnnounced = false;
        if (State.QueenSettled) events.Add(new BeekeeperEvent(BeekeeperEvents.QueenResumes));
    }

    // ------------------------------------------------------------------ the trade agreement (stage 5)

    // Cut in stage 7.5 (spec 016): the agreement no longer sells the overflow; it is a better rate.
    // /// <summary>Beebits a second the agreement brings while the combs are full.</summary>
    // public decimal AgreementBeebitsPerSecondNow =>
    //     State.HasTradeAgreement && IsStorageFull ? HoneyPerSecondNow / Config.AgreementHoneyPerBeebit : 0m;

    /// <summary>At 25 trades (stage 7.5) the bear offers a better rate from the next sale on.</summary>
    private void OfferAgreementIfDue(List<BeekeeperEvent> events)
    {
        if (State.HasTradeAgreement || State.Trades < Config.AgreementTrades) return;
        State.HasTradeAgreement = true;
        events.Add(new BeekeeperEvent(BeekeeperEvents.TradeAgreement, 0m, State.BearName));
    }

    // ------------------------------------------------------------------ the bear

    /// <summary>Trade exactly one bundle (10 honey for 5 Beebits; 8 honey under the agreement).</summary>
    public ActionResult SellTen() => Sell(all: false);

    /// <summary>Sell as many whole bundles as possible; the remainder stays. Counts as one trade.</summary>
    public ActionResult SellAll() => Sell(all: true);

    /// <summary>Whole bundles at the rate of the moment (spec 016, FR-711): the sale that brings
    /// the agreement is still paid at the old rate.</summary>
    private ActionResult Sell(bool all)
    {
        if (!CanSell) return ActionResult.Refused;

        decimal bundle = HoneyPerTradeNow;
        decimal bundles = all ? Math.Floor(State.Honey / bundle) : 1m;
        // Stage 10 (spec 019, FR-1002): the bear pays Beebits again.
        decimal paid = SalePay(bundles, BeebitsPerTradeNow);
        State.Honey -= bundles * bundle;
        State.Beebits += paid;
        State.BeebitsRevealed = true;
        State.Trades++;
        // Cut (Bee, 2026-11-12): the bear paid herbs, and the first herb opened the herbal candle.
        // decimal paid = bundles * HerbsPerTradeNow;
        // State.Herbs += paid;
        // State.HerbsRevealed = true;
        RefreshStorageFlag();

        // Value: Beebits paid; Value2: honey given.
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.Sale, paid, State.BearName, bundles * bundle) };
        // Cut (Bee, 2026-11-12): the leafcutter bee's first herbs open the recipe now (GiveHotelGift).
        // if (!State.RepellentUnlocked)
        // {
        //     State.RepellentUnlocked = true;
        //     events.Add(new BeekeeperEvent(BeekeeperEvents.RepellentUnlocked));
        // }
        OfferAgreementIfDue(events);
        CheckReveals(events);
        return new ActionResult(true, paid, events);
    }

    /// <summary>Sell one potted honey to the bear (stage 10). One trade toward the agreement.</summary>
    public ActionResult SellPotted() => SellPottedHoney(all: false);

    /// <summary>Sell every potted honey at once. Still one trade, as Sell All is.</summary>
    public ActionResult SellAllPotted() => SellPottedHoney(all: true);

    /// <summary>Potted honey has one price (FR-1006): the agreement's better rate is for plain honey
    /// only. The Trades herb lifts it as it does plain honey.</summary>
    private ActionResult SellPottedHoney(bool all)
    {
        if (!CanSellPotted) return ActionResult.Refused;
        decimal pots = all ? Math.Floor(State.PottedHoney) : 1m;
        decimal paid = SalePay(pots, PottedHoneyBeebitsNow);
        State.PottedHoney -= pots;
        State.Beebits += paid;
        State.BeebitsRevealed = true;
        State.Trades++;
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.PottedSale, paid, State.BearName, pots) };
        OfferAgreementIfDue(events);
        CheckReveals(events);
        return new ActionResult(true, paid, events);
    }

    // ------------------------------------------------------------------ potted honey (stage 10)

    /// <summary>Potting honey is on offer from the first honey (the hive has started).</summary>
    public bool PotHoneyShown => State.HoneyRevealed;

    /// <summary>Enough honey and clay jars for this many potted honeys.</summary>
    public bool CanPotHoneyTimes(int count) =>
        count >= 1 && PotHoneyShown && State.Honey >= Config.PotHoneyHoney * count && State.ClayJars >= Config.PotHoneyJars * count;

    public bool CanPotHoney => CanPotHoneyTimes(1);

    /// <summary>Honey + a clay jar make one potted honey (FR-1005), or a batch. The jars are used up. Potted
    /// honey has no cap and doesn't count toward the honey cap, so potting frees honey room.</summary>
    public ActionResult PotHoney(int count = 1)
    {
        if (!CanPotHoneyTimes(count)) return ActionResult.Refused;
        State.Honey -= Config.PotHoneyHoney * count;
        State.ClayJars -= Config.PotHoneyJars * count;
        State.PottedHoney += count;
        RefreshStorageFlag();   // honey went down
        var events = new List<BeekeeperEvent>();
        if (!State.PottedHoneyRevealed)
        {
            State.PottedHoneyRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.HoneyPotted, count));
        }
        CraftCardDone(BeekeeperStories.PotHoney);
        return new ActionResult(true, count, events);
    }

    // ------------------------------------------------------------------ craft links (Bee, 2026-11-12)

    /// <summary>The Hive row's +1 / +10 / +100 links are open once the craft's story card is done.</summary>
    public bool CraftLinksOpen(string craft) => State.StoriesDone.Contains(craft);

    /// <summary>Can this craft ("pot_honey", "beeswax_candle" or "bee_bread", the story ids) be done this many times?</summary>
    public bool CanCraftTimes(string craft, int count) => craft switch
    {
        BeekeeperStories.PotHoney => CanPotHoneyTimes(count),
        BeekeeperStories.Candle => CanCraftBeeswaxTimes(count),
        BeekeeperStories.BeeBread => CanMakeBeeBreadTimes(count),
        _ => false,
    };

    public ActionResult CraftTimes(string craft, int count) => craft switch
    {
        BeekeeperStories.PotHoney => PotHoney(count),
        BeekeeperStories.Candle => CraftBeeswax(count),
        BeekeeperStories.BeeBread => MakeBeeBread(count),
        _ => ActionResult.Refused,
    };

    /// <summary>The third link's size: 100, or 1000 once a whole 1000 can be paid for.</summary>
    public int CraftBigStep(string craft) =>
        CanCraftTimes(craft, Config.CraftLinkHuge) ? Config.CraftLinkHuge : Config.CraftLinkBig;

    /// <summary>Review fix (2026-11-15): the first of a craft made any way (its card's button, or a direct call)
    /// makes its story card done at once, as loading a save that has made one does (Tidy). The screen only
    /// crafts from the card and the links today, so this keeps the engine's rule in one place.</summary>
    private void CraftCardDone(string id)
    {
        if (State.StoryHere == id) FinishStory(id);
        else if (!State.StoriesDone.Contains(id))
        {
            State.StoriesDone.Add(id);
            State.StoryReturnIn.Remove(id);
            State.StoryQueue.Remove(id);
        }
    }

    /// <summary>The card's button: makes the first one, and the card is done for good (the links open).</summary>
    public ActionResult CraftFromStory()
    {
        string? id = State.StoryHere;
        if (id is not (BeekeeperStories.PotHoney or BeekeeperStories.Candle or BeekeeperStories.BeeBread))
            return ActionResult.Refused;
        var result = CraftTimes(id, 1);
        if (!result.Done) return result;
        FinishStory(id);
        return result;
    }

    // ------------------------------------------------------------------ the shop

    /// <summary>Buys the next tool in order (Gloves, then Net, then Vacuum).</summary>
    public ActionResult BuyNextTool()
    {
        if (!CanBuyNextTool || NextTool is not { } tool) return ActionResult.Refused;

        State.Beebits -= tool.Cost;
        State.ToolLevel++;
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.ToolBought, State.ToolLevel, tool.Id) };
        CheckWalls(events);   // the Vacuum brings upgrades that may be walls
        return new ActionResult(true, tool.Cost, events);
    }

    /// <summary>The Wax-Catcher is independent of the tool order.</summary>
    public ActionResult BuyWaxCatcher()
    {
        if (!CanBuyWaxCatcher) return ActionResult.Refused;

        State.Beebits -= Config.WaxCatcherCost;
        State.HasWaxCatcher = true;
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.WaxCatcherBought) };
        CheckWalls(events);
        return new ActionResult(true, Config.WaxCatcherCost, events);
    }

    // ------------------------------------------------------------------ combs

    /// <summary>A new comb (spec 016, FR-708): its bee price leaves the free-bee count for good (the
    /// bees move in; no per-comb count is kept) and its wax is spent. Both caps grow.</summary>
    public ActionResult BuildComb()
    {
        if (!CanBuildComb) return ActionResult.Refused;
        decimal bees = CombBeeCost, wax = CombCost;

        State.Bees -= bees;
        State.Wax -= wax;
        State.Combs++;
        State.CombsRevealed = true;
        RefreshStorageFlag();
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.CombBuilt, bees) };
        OpenWorkbenchIfDue(events);
        CheckReveals(events);   // the first comb opens the Shop (Bee, 2026-11-11); also checks the walls
        return new ActionResult(true, wax, events);
        // Cut in stage 7.5 (spec 016): wax only, and the event carried the honey storage added.
        // decimal cost = CombCost;
        // if (State.Wax < cost) return ActionResult.Refused;
        // decimal storageBefore = HoneyStorage;
        // State.Wax -= cost;
        // State.Combs++;
        // RefreshStorageFlag();
        // var events = new List<BeekeeperEvent> { new(BeekeeperEvents.CombBuilt, HoneyStorage - storageBefore) };
        // OpenWorkbenchIfDue(events);
        // return new ActionResult(true, cost, events);
    }

    // ------------------------------------------------------------------ The Workbench (stage 2)

    /// <summary>For a game just loaded: opens The Workbench for an old save that already
    /// has enough combs, settles the queen into an older save's wooden hive and starts the
    /// trade agreement for a save already past 100 bear trades. Since stage 6 it also turns an
    /// older save's forager and guard counts into specialties (said once) and sends the emissary
    /// to a save that somehow has enough bribes without it. Returns what to tell the player
    /// (nothing if all of that already happened).</summary>
    public IReadOnlyList<BeekeeperEvent> RevealOnLoad()
    {
        var events = new List<BeekeeperEvent>();
        OpenWorkbenchIfDue(events);
        SettleQueenIfDue(events);
        OfferAgreementIfDue(events);
        // Cut in stage 7.5 (spec 016): older saves no longer load.
        // AnnounceOldCountsIfDue(events);
        SendEmissaryIfDue(events);
        // Cut in stage 8 (spec 017): GiveSeedsIfDue(events);   // a save past a seed's trade count gets that seed (stage 7)
        UnlockSeedsIfDue(events);          // stage 8: a save past a seed's trade count has it in the roll
        SummonCarpenterBeeIfDue(events);   // stage 8: a save with a willow (or a bed that sprouted on load)
        // Stage 9: a save with plants and no calendar started it on load (Tidy); say so once.
        if (_calendarStartedOnLoad)
        {
            _calendarStartedOnLoad = false;
            events.Add(new BeekeeperEvent(BeekeeperEvents.CalendarStarted, 0m, CurrentBloom?.Id));
        }
        CheckWalls(events);
        return events;
    }

    // Cut in stage 7.5 (spec 016): older saves no longer load.
    // /// <summary>Stage 4 and 5 saves counted forager and guard bees. The specialties come from the
    // /// plants on their own; this only says so once, if there was a count to speak of.</summary>
    // private void AnnounceOldCountsIfDue(List<BeekeeperEvent> events)
    // {
    //     if (State.OldCountsAnnounced) return;
    //     State.OldCountsAnnounced = true;
    //     if (State.ForagerBees > 0m || State.GuardBees > 0m)
    //         events.Add(new BeekeeperEvent(BeekeeperEvents.OldCountsSettle));
    // }

    private void OpenWorkbenchIfDue(List<BeekeeperEvent> events)
    {
        if (State.WorkbenchRevealed || State.Combs < Config.WorkbenchCombs) return;
        State.WorkbenchRevealed = true;
        events.Add(new BeekeeperEvent(BeekeeperEvents.WorkbenchOpened));
    }

    // Cut (Bee, 2026-11-11): repellent candles retired once the emissary had come (spec 014).
    // Herbal candles never retire: they are a buff and a trade good, not a wasp defence.
    // public bool RepellentRetired => State.EmissaryCome;

    /// <summary>The herbal candle (2 wax + 1 herb; the old repellent candle's recipe and names).
    /// Whether a batch of <paramref name="count"/> can be paid for in full.</summary>
    public bool CanCraftRepellentTimes(int count) =>
        count >= 1 && State.WorkbenchRevealed && State.RepellentUnlocked
        && State.Wax >= HerbalCandleWaxNow * count && State.Herbs >= Config.HerbalCandleHerbs * count;

    public bool CanCraftRepellent => CanCraftRepellentTimes(1);

    // ---- the candle upgrades (stage 8, spec 017: Candle Molds and the Dipping Rack)

    /// <summary>Candles one craft makes, for one price: 2 with the Candle Molds, else 1 (FR-809).</summary>
    public int CandlesPerCraft => Owns(BeekeeperUpgrades.CandleMolds) ? Config.CandlesPerCraftWithMolds : 1;

    /// <summary>A candle's wax price now (FR-810): halved by the Dipping Rack, rounded down. Every
    /// candle check, craft and price text reads this, so batches and walls follow it.</summary>
    public decimal CandleWax(decimal baseWax) =>
        Owns(BeekeeperUpgrades.DippingRack) ? Math.Floor(baseWax * Config.RackWaxMultiplier) : baseWax;

    public decimal HerbalCandleWaxNow => CandleWax(Config.HerbalCandleWax);
    public decimal BeeswaxCandleWaxNow => CandleWax(Config.BeeswaxCandleWax);
    public decimal BeeBoostCandleWaxNow => CandleWax(Config.BeeBoostCandleWax);
    public decimal SagePropolisCandleWaxNow => CandleWax(Config.SagePropolisCandleWax);

    /// <summary>Crafting is instant (Leah). Makes <paramref name="count"/> crafts at once: exactly
    /// count times the cost, or nothing. Each craft makes <see cref="CandlesPerCraft"/> candles.</summary>
    public ActionResult CraftRepellent(int count = 1)
    {
        if (!CanCraftRepellentTimes(count)) return ActionResult.Refused;
        decimal made = (decimal)count * CandlesPerCraft;   // review fix (2026-11-15): int overflowed past ~1 billion
        State.Wax -= HerbalCandleWaxNow * count;
        State.Herbs -= Config.HerbalCandleHerbs * count;
        State.RepellentCandles += made;
        State.RepellentCrafted = true;
        var events = new List<BeekeeperEvent>();
        if (count > 1) events.Add(new BeekeeperEvent(BeekeeperEvents.Crafted, made, "repellent"));
        CountCandleCrafted(events, made);
        return new ActionResult(true, made, events);
        // Cut in stage 8 (spec 017): one candle a craft at the full wax.
        // State.Wax -= Config.HerbalCandleWax * count;
        // State.RepellentCandles += count;
        // if (count > 1) events.Add(new BeekeeperEvent(BeekeeperEvents.Crafted, count, "repellent"));
        // CountCandleCrafted(events, count);
        // return new ActionResult(true, count, events);
    }

    // ------------------------------------------------------------------ the beeswax candle (stage 10)

    /// <summary>The beeswax candle's recipe (and its Hive row) shows with The Workbench, before any herb.</summary>
    public bool BeeswaxShown => State.WorkbenchRevealed;

    /// <summary>The Beeswax candles Hive row: like Potted honey and Bee bread, from its story card's first craft
    /// (review fix, 2026-11-15: it showed at 0 with The Workbench, before the candle card).</summary>
    public bool BeeswaxCandlesRowShown => State.StoriesDone.Contains(BeekeeperStories.Candle) || State.BeeswaxCandles > 0m;

    /// <summary>Wax only (FR-1007): the Dipping Rack halves it, rounded down.</summary>
    public bool CanCraftBeeswaxTimes(int count) =>
        count >= 1 && BeeswaxShown && State.Wax >= BeeswaxCandleWaxNow * count;

    public bool CanCraftBeeswax => CanCraftBeeswaxTimes(1);

    /// <summary>Beeswax candles for the Hippies. Each craft makes <see cref="CandlesPerCraft"/>, and
    /// they count toward the candles that bring the Hippies. They can't be lit.</summary>
    public ActionResult CraftBeeswax(int count = 1)
    {
        if (!CanCraftBeeswaxTimes(count)) return ActionResult.Refused;
        decimal made = (decimal)count * CandlesPerCraft;   // review fix (2026-11-15): int overflowed past ~1 billion
        State.Wax -= BeeswaxCandleWaxNow * count;
        State.BeeswaxCandles += made;
        State.BeeswaxCrafted = true;
        CraftCardDone(BeekeeperStories.Candle);
        var events = new List<BeekeeperEvent>();
        if (count > 1) events.Add(new BeekeeperEvent(BeekeeperEvents.BeeswaxCrafted, made));
        CountCandleCrafted(events, made);
        return new ActionResult(true, made, events);
    }

    // ------------------------------------------------------------------ the propolis candles (stage 7)

    /// <summary>The two propolis candles' recipes show at The Workbench once the poplar has sprouted.</summary>
    public bool PropolisCandlesShown => State.WorkbenchRevealed && HasSpecialty(BeekeeperSpecialties.Resin);

    // Stage 8 (spec 017): the wax reads CandleWax (the Dipping Rack) and each craft makes
    // CandlesPerCraft (the Candle Molds). Before: Config.BeeBoostCandleWax / SagePropolisCandleWax, one a craft.
    public bool CanCraftBeeBoostTimes(int count) =>
        count >= 1 && PropolisCandlesShown
        && State.Wax >= BeeBoostCandleWaxNow * count && State.Propolis >= Config.BeeBoostCandlePropolis * count;

    public bool CanCraftBeeBoost => CanCraftBeeBoostTimes(1);

    public bool CanCraftSagePropolisTimes(int count) =>
        count >= 1 && PropolisCandlesShown
        && State.Wax >= SagePropolisCandleWaxNow * count && State.Herbs >= Config.SagePropolisCandleHerbs * count
        && State.Propolis >= Config.SagePropolisCandlePropolis * count;

    public bool CanCraftSagePropolis => CanCraftSagePropolisTimes(1);

    public ActionResult CraftBeeBoost(int count = 1)
    {
        if (!CanCraftBeeBoostTimes(count)) return ActionResult.Refused;
        decimal made = (decimal)count * CandlesPerCraft;   // review fix (2026-11-15): int overflowed past ~1 billion
        State.Wax -= BeeBoostCandleWaxNow * count;
        State.Propolis -= Config.BeeBoostCandlePropolis * count;
        State.BeeBoostCandles += made;
        var events = new List<BeekeeperEvent>();
        if (count > 1) events.Add(new BeekeeperEvent(BeekeeperEvents.Crafted, made, "bee_boost"));
        CountCandleCrafted(events, made);
        return new ActionResult(true, made, events);
    }

    public ActionResult CraftSagePropolis(int count = 1)
    {
        if (!CanCraftSagePropolisTimes(count)) return ActionResult.Refused;
        decimal made = (decimal)count * CandlesPerCraft;   // review fix (2026-11-15): int overflowed past ~1 billion
        State.Wax -= SagePropolisCandleWaxNow * count;
        State.Herbs -= Config.SagePropolisCandleHerbs * count;
        State.Propolis -= Config.SagePropolisCandlePropolis * count;
        State.SagePropolisCandles += made;
        var events = new List<BeekeeperEvent>();
        if (count > 1) events.Add(new BeekeeperEvent(BeekeeperEvents.Crafted, made, "sage_propolis"));
        CountCandleCrafted(events, made);
        return new ActionResult(true, made, events);
    }

    /// <summary>A bee-boost candle burns (honey up) in live play only.</summary>
    public bool IsBeeBoosted => State.BeeBoostSecondsLeft > 0m;
    public bool IsSagePropolisBurning => State.SagePropolisSecondsLeft > 0m;

    public bool CanLightBeeBoost =>
        State.BeeBoostCandles >= 1m && State.BeeBoostSecondsLeft < Config.BeeBoostCapSeconds;

    public bool CanLightSagePropolis =>
        State.SagePropolisCandles >= 1m && State.SagePropolisSecondsLeft < Config.SagePropolisCapSeconds;

    /// <summary>Lighting another adds its time, up to the cap.</summary>
    public ActionResult LightBeeBoost()
    {
        if (!CanLightBeeBoost) return ActionResult.Refused;
        State.BeeBoostCandles--;
        State.BeeBoostSecondsLeft = Math.Min(Config.BeeBoostCapSeconds, State.BeeBoostSecondsLeft + Config.BeeBoostBurnSeconds);
        return new ActionResult(true, 1m, new[] { new BeekeeperEvent(BeekeeperEvents.BeeBoostLit) });
    }

    public ActionResult LightSagePropolis()
    {
        if (!CanLightSagePropolis) return ActionResult.Refused;
        State.SagePropolisCandles--;
        State.SagePropolisSecondsLeft = Math.Min(Config.SagePropolisCapSeconds, State.SagePropolisSecondsLeft + Config.SagePropolisBurnSeconds);
        return new ActionResult(true, 1m, new[] { new BeekeeperEvent(BeekeeperEvents.SagePropolisLit) });
    }

    private void CountCandleCrafted(List<BeekeeperEvent> events, decimal count = 1m)
    {
        // Review fix (2026-11-15): stops at the most a save can count instead of wrapping negative (which made
        // the next autosave look damaged and moved the whole hive aside).
        decimal room = long.MaxValue - (decimal)Math.Max(0L, State.CandlesCrafted);
        State.CandlesCrafted = count >= room ? long.MaxValue : Math.Max(0L, State.CandlesCrafted) + (long)Math.Max(0m, count);
        if (!State.HippiesRevealed && State.CandlesCrafted >= Config.HippiesRevealCandles)
        {
            State.HippiesRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.HippiesArrive));
        }
    }

    // ------------------------------------------------------------------ the Hippies

    /// <summary>The Hippies trade clay jars for beeswax candles (stage 10, spec 019: "candles for pots
    /// only"). They take no other candle, and pay no Beebits and no herbs. (2026-11-11 to 11-12 they
    /// bought herbal candles for Beebits; before that, beeswax candles for sage.)</summary>
    public bool CanTradeCandles => State.HippiesRevealed && !State.HippiesDismissedForGood && State.BeeswaxCandles >= Config.CandlesPerJar;
    // Cut (Bee, 2026-11-12): public bool CanTradeCandles => State.HippiesRevealed && State.RepellentCandles >= 1m;

    /// <summary>One clay jar for 3 beeswax candles. (Name kept from when a trade was 10 beeswax candles.)</summary>
    public ActionResult TradeTenCandles() => TradeCandles(all: false);

    /// <summary>As many jars as the beeswax candles allow; each jar is a trade.</summary>
    public ActionResult TradeAllCandles() => TradeCandles(all: true);

    private ActionResult TradeCandles(bool all)
    {
        if (!CanTradeCandles) return ActionResult.Refused;
        decimal jars = all ? Math.Floor(State.BeeswaxCandles / Config.CandlesPerJar) : 1m;
        decimal candles = jars * Config.CandlesPerJar;
        State.BeeswaxCandles -= candles;
        State.ClayJars += jars;
        // Cut (Bee, 2026-11-12): the Hippies paid Beebits for herbal candles, one candle a trade.
        // decimal candles = all ? Math.Floor(State.RepellentCandles) : 1m;
        // State.RepellentCandles -= candles;
        // decimal paid = candles * BeebitsPerCandleNow;
        // State.Beebits += paid;
        // State.BeebitsRevealed = true;
        // Cut (Bee, 2026-11-11): 10 beeswax candles for 1 sage, and the first sage opened the
        // repellent candle.
        // decimal bundles = all ? Math.Floor(State.BeeswaxCandles / Config.CandlesPerSage) : 1m;
        // State.BeeswaxCandles -= bundles * Config.CandlesPerSage;
        // State.Sage += bundles * SagePerTradeNow; State.SageRevealed = true;

        // Value: clay jars got; Value2: candles given.
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.CandlesTraded, jars, null, candles) };
        // Stage 8 (spec 017, FR-802): each trade rolls on its own (stage 10: a trade is one jar, was one
        // candle). A seed joins the roll from its trade on (that trade rolls with it). One log line for
        // the seeds of a batch.
        // Review fix (2026-11-15): the first jars of a batch roll one by one; the rest are worked out in a few
        // steps (GiveSeedsForManyTrades), so a huge stack can't freeze the game.
        var given = new List<string>();
        int exact = (int)Math.Min(jars, Math.Max(0, Config.HippieTradeExactRolls));
        for (int i = 0; i < exact; i++)
        {
            AddHippieTrades(1m);
            UnlockSeedsIfDue(events);
            if (given.Count < Config.HippieTradeSeedsMax
                && RollSeed(BeekeeperGivers.Hippies, Config.HippieSeedChance) is { } seed) given.Add(seed);
        }
        GiveSeedsForManyTrades(jars - Math.Min(jars, exact), events, given);
        if (given.Count == 1)
            events.Add(new BeekeeperEvent(BeekeeperEvents.SeedGiven, State.SeedsInHand.Count, given[0]));
        else if (given.Count > 1)
            events.Add(new BeekeeperEvent(BeekeeperEvents.SeedsGivenBatch, given.Count));
        // Cut in stage 8 (spec 017): GiveSeedsIfDue(events);   // each seed once, on a set trade
        CheckReveals(events);
        return new ActionResult(true, jars, events);
    }

    /// <summary>Adds Hippie trades, stopping at the most a save can count.</summary>
    private void AddHippieTrades(decimal trades)
    {
        decimal room = long.MaxValue - (decimal)Math.Max(0L, State.HippieTrades);
        State.HippieTrades = trades >= room ? long.MaxValue : Math.Max(0L, State.HippieTrades) + (long)trades;
    }

    /// <summary>
    /// The jars of a batch past <see cref="BeekeeperConfig.HippieTradeExactRolls"/> (review fix, 2026-11-15).
    /// They count as trades as before, and a new seed still joins the roll at its trade, but each run of trades
    /// between two such moments gives its seeds at once: the average (trades × chance, the leftover fraction a
    /// roll of its own), each kind in the roll equally likely, never past <see cref="BeekeeperConfig.HippieTradeSeedsMax"/>
    /// for the whole batch. It uses the game's own random rolls, so a seeded game still plays the same.
    /// </summary>
    private void GiveSeedsForManyTrades(decimal trades, List<BeekeeperEvent> events, List<string> given)
    {
        decimal chance = (decimal)Math.Clamp(Config.HippieSeedChance, 0.0, 1.0);
        while (trades >= 1m)
        {
            // A run ends just before the trade where the next seed joins the roll; that trade starts the next run
            // (a seed joining on this run's first trade is in this run's roll, as it is for a single trade).
            decimal step = trades;
            foreach (var plant in Config.Plants)
            {
                if (plant.Giver != BeekeeperGivers.Hippies || IsSeedUnlocked(plant)) continue;
                decimal until = (decimal)plant.SeedAtTrade - State.HippieTrades - 1m;
                if (until >= 1m) step = Math.Min(step, until);
            }
            AddHippieTrades(step);
            UnlockSeedsIfDue(events);
            trades -= step;

            var pool = Config.Plants.Where(p => p.Giver == BeekeeperGivers.Hippies && IsSeedUnlocked(p)).ToList();
            int room = Config.HippieTradeSeedsMax - given.Count;
            if (pool.Count == 0 || room <= 0 || chance <= 0m) continue;
            decimal average = step * chance;
            decimal whole = Math.Floor(average);
            if (whole < room && (decimal)_rng.NextDouble() < average - whole) whole++;
            int seeds = (int)Math.Min(whole, room);
            // Each kind equally likely: an even share each, and the leftover ones picked at random.
            var counts = new int[pool.Count];
            for (int k = 0; k < pool.Count; k++) counts[k] = seeds / pool.Count;
            for (int r = 0; r < seeds % pool.Count; r++) counts[pool.Count == 1 ? 0 : _rng.Next(pool.Count)]++;
            for (int k = 0; k < pool.Count; k++)
            {
                if (counts[k] == 0) continue;
                AddSeedsInHand(pool[k].Id, counts[k]);
                given.AddRange(Enumerable.Repeat(pool[k].Id, counts[k]));
            }
        }
    }

    // ------------------------------------------------------------------ herbal candles (lit)

    /// <summary>An herbal candle is burning (a dud never burns).</summary>
    public bool IsHerbBurning => State.HerbSecondsLeft > 0m && State.HerbBuff is not null;

    /// <summary>The lit herbal candle rolled <paramref name="buff"/> and still burns.</summary>
    public bool IsHerb(string buff) => IsHerbBurning && State.HerbBuff == buff;

    /// <summary>The wax factor of the moment: more under a wax herb, else 1.</summary>
    public decimal HerbWaxNow => IsHerb(BeekeeperHerbs.Wax) ? Config.HerbWaxMultiplier : 1m;

    /// <summary>The trade factor of the moment: more under a trades herb, else 1.</summary>
    public decimal HerbTradeNow => IsHerb(BeekeeperHerbs.Trades) ? Config.HerbTradeMultiplier : 1m;

    /// <summary>Live seconds one herbal candle burns: longer with Stronger Candles.</summary>
    public decimal HerbalCandleBurnSeconds =>
        Config.HerbalCandleBurnSeconds * (Owns(BeekeeperUpgrades.StrongerCandles) ? Config.StrongerCandlesBonus : 1m);

    /// <summary>Live seconds a candle burns once it rolled <paramref name="buff"/>: Quick Fingers is
    /// short (30 s), the rest use the usual time; Stronger Candles stretches both.</summary>
    public decimal HerbBurnSecondsFor(string buff) =>
        (buff == BeekeeperHerbs.QuickFingers ? Config.HerbClickBurnSeconds : Config.HerbalCandleBurnSeconds)
        * (Owns(BeekeeperUpgrades.StrongerCandles) ? Config.StrongerCandlesBonus : 1m);

    /// <summary>One at a time: another can be lit once the last has burned out.</summary>
    public bool CanLightRepellent => State.RepellentCandles >= 1m && !IsHerbBurning;

    /// <summary>Lights an herbal candle: it rolls one buff (by the config's weights) that burns in
    /// live play. A dud is used up with nothing burning.</summary>
    public ActionResult LightRepellent()
    {
        if (!CanLightRepellent) return ActionResult.Refused;
        State.RepellentCandles--;
        string buff = RollHerbBuff();
        if (buff == BeekeeperHerbs.Dud)
        {
            State.HerbBuff = null;
            State.HerbSecondsLeft = 0m;
        }
        else
        {
            State.HerbBuff = buff;
            State.HerbSecondsLeft = HerbBurnSecondsFor(buff);
        }
        // Value: the number the log line quotes (percent, or a Smoker click's seconds), kept with the line.
        decimal value = buff switch
        {
            BeekeeperHerbs.BusyBees => (Config.HerbHoneyMultiplier - 1m) * 100m,
            BeekeeperHerbs.Wax => (Config.HerbWaxMultiplier - 1m) * 100m,
            BeekeeperHerbs.Trades => (Config.HerbTradeMultiplier - 1m) * 100m,
            BeekeeperHerbs.LingeringSmoke => Config.HerbSmokerSeconds,
            BeekeeperHerbs.QuickFingers => Config.HerbClickMultiplier * 100m,   // 300 (percent of normal)
            _ => 0m,
        };
        return new ActionResult(true, 1m, new[] { new BeekeeperEvent(BeekeeperEvents.HerbLit, value, buff, State.HerbSecondsLeft) });
    }

    private string RollHerbBuff()
    {
        var weights = Config.HerbBuffWeights.Where(w => w.Weight > 0).ToList();
        int total = weights.Sum(w => w.Weight);
        if (total <= 0) return BeekeeperHerbs.Dud;
        int roll = _rng.Next(total);
        foreach (var (buff, weight) in weights)
        {
            if (roll < weight) return buff;
            roll -= weight;
        }
        return weights[^1].Buff;
    }

    // ------------------------------------------------------------------ upgrades (in the Shop)

    /// <summary>Upgrades that are unlocked and not yet bought, in Shop order. Bought and
    /// still-locked upgrades are not listed (Leah: hide purchased upgrades). An upgrade whose wax
    /// price is above the wax cap (a wall) is not listed either: it shows once the hive can hold
    /// its price, so there is never a "needs more storage" line for it.</summary>
    public IReadOnlyList<BeekeeperUpgrade> ShopUpgrades =>
        Config.Upgrades.Where(u => !Owns(u.Id) && IsUnlocked(u) && !IsWaxWall(u.Wax)).ToList();

    // Stage 2's upgrades come with The Workbench; stage 3's catching upgrades only need the Vacuum.
    private bool IsUnlocked(BeekeeperUpgrade u) => u.Needs switch
    {
        BeekeeperUpgrades.NeedsWorkbench => State.WorkbenchRevealed,
        BeekeeperUpgrades.NeedsWaxCatcher => State.WorkbenchRevealed && State.HasWaxCatcher,
        // Stronger Candles comes with the herbal candle (it makes it burn longer).
        BeekeeperUpgrades.NeedsRepellent => RepellentShown,
        BeekeeperUpgrades.NeedsVacuum => State.ToolLevel >= VacuumLevel,
        // Stage 7 (spec 015)
        BeekeeperUpgrades.NeedsPaper => PaperSeen,
        BeekeeperUpgrades.NeedsGardenAndPaper => State.GardenRevealed && PaperSeen,
        BeekeeperUpgrades.NeedsPropolis => PropolisSeen,
        BeekeeperUpgrades.NeedsWood => WoodSeen,   // stage 8: the first wood
        BeekeeperUpgrades.NeedsNothing => true,
        BeekeeperUpgrades.NeedsStory => false,   // never in the Shop: a story card hands it out
        var other => Owns(other),
    };

    /// <summary>Paper has been seen: a wasp trade, or any paper held (also an older save's).</summary>
    public bool PaperSeen => State.PaperRevealed || State.WaspTrades > 0 || State.Paper > 0m;

    /// <summary>Propolis has been seen: the poplar has sprouted, or any propolis was held.</summary>
    public bool PropolisSeen => State.PropolisRevealed || State.Propolis >= 1m;

    /// <summary>Wood has been seen (stage 8): the carpenter bee has come and brought the first
    /// wood. Brings the wood upgrades, the Honey Super row and the Wood row's full number.</summary>
    public bool WoodSeen => State.CarpenterBeeCame && (State.WoodRevealed || State.Wood >= 1m);

    // ---- which Hive rows show (one rule each, specs 009 to 015; the view model only reads these)

    /// <summary>The Pollen row: pollen has been seen, or foraging is on (the wildflowers or clover have sprouted).</summary>
    public bool PollenShown => State.PollenRevealed || State.Pollen > 0m || ForagingPollenPerMinute > 0m;

    /// <summary>The Propolis row: propolis has been seen or held, or resin is on (the poplar has sprouted).</summary>
    public bool PropolisShown => State.PropolisRevealed || State.Propolis > 0m || ResinPropolisPerMinute > 0m;

    /// <summary>The Paper row: the first paper (a wasp trade, or any paper held).</summary>
    public bool PaperShown => PaperSeen;

    /// <summary>The herbal candle's recipe and light button (at The Workbench): unlocked by the first
    /// herb. It never retires now (was: && !RepellentRetired).</summary>
    public bool RepellentShown => State.RepellentUnlocked && State.WorkbenchRevealed;

    /// <summary>The Repellent candles Hive row: shown once the first one is made, while the candle is shown.</summary>
    public bool RepellentCandlesRowShown =>
        RepellentShown && (State.RepellentCrafted || State.RepellentCandles > 0m || State.RepellentSecondsLeft > 0m);

    /// <summary>The bee-boost candle row shows with its recipe, so it stays when the last candle is lit.</summary>
    public bool BeeBoostCandlesShown => PropolisCandlesShown || State.BeeBoostCandles > 0m;

    public bool SagePropolisCandlesShown => PropolisCandlesShown || State.SagePropolisCandles > 0m;

    private int VacuumLevel => Config.Tools.ToList().FindIndex(t => t.Id == "vacuum") + 1;

    /// <summary>The percent an upgrade's Shop blurb quotes ("+50% honey storage"), from the config,
    /// or null for an upgrade whose blurb has no number.</summary>
    public decimal? UpgradeBonusPercent(string id)
    {
        decimal? Pct(decimal multiplier) => (multiplier - 1m) * 100m;
        return id switch
        {
            BeekeeperUpgrades.BiggerCombs1 => Pct(Config.BiggerCombs1Multiplier),
            BeekeeperUpgrades.BiggerCombs2 => Pct(Config.BiggerCombs2Multiplier),
            BeekeeperUpgrades.BetterWaxCatcher => Pct(Config.BetterWaxCatcherBonus),
            BeekeeperUpgrades.StrongerCandles => Pct(Config.StrongerCandlesBonus),
            BeekeeperUpgrades.Practice => Pct(Config.PracticeMultiplier),
            BeekeeperUpgrades.MorePractice => Pct(Config.MorePracticeMultiplier),
            BeekeeperUpgrades.PropolisSeal => Pct(Config.PropolisSealStorageMultiplier),
            BeekeeperUpgrades.Smoker => SmokerBoostPercent,
            // Stage 8: how much less wax, in percent (50 = half).
            BeekeeperUpgrades.WoodenFrames => (1m - Config.FramesWaxMultiplier) * 100m,
            BeekeeperUpgrades.DippingRack => (1m - Config.RackWaxMultiplier) * 100m,
            BeekeeperUpgrades.CandleMolds => Config.CandlesPerCraftWithMolds,   // candles a craft
            BeekeeperUpgrades.HoneyDipper => Pct(Config.HoneyDipperHoneyMultiplier),   // Bee, 2026-11-12
            _ => null,
        };
    }

    public bool CanBuyUpgrade(string id) =>
        Config.Upgrades.FirstOrDefault(u => u.Id == id) is { } u
        && !Owns(id) && IsUnlocked(u)
        && State.Beebits >= u.Beebits && State.Wax >= u.Wax && State.Herbs >= u.Herbs
        && State.Paper >= u.Paper && State.Propolis >= u.Propolis && State.Bees >= u.Bees
        && State.Wood >= u.Wood;   // stage 8

    /// <summary>Takes every part of the cost at once, or nothing.</summary>
    public ActionResult BuyUpgrade(string id)
    {
        if (!CanBuyUpgrade(id)) return ActionResult.Refused;
        var u = Config.Upgrades.First(x => x.Id == id);
        State.Beebits -= u.Beebits;
        State.Wax -= u.Wax;
        State.Herbs -= u.Herbs;
        State.Paper -= u.Paper;
        State.Propolis -= u.Propolis;
        State.Bees -= u.Bees;
        State.Wood -= u.Wood;
        State.Upgrades.Add(id);
        // Stage 8: the bee hotel's first gift comes one whole interval after it is hung up.
        if (id == BeekeeperUpgrades.BeeHotel) State.HotelSecondsToNext = Config.HotelGiftSeconds;
        RefreshStorageFlag();
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.UpgradeBought, 0m, id) };
        CheckWalls(events);   // the next upgrade in a line may be a wall
        return new ActionResult(true, u.Beebits, events);
    }

    // ------------------------------------------------------------------ wasps

    public bool WaspApproaching => State.WaspCountdown > 0m && !State.EmissaryCome;

    /// <summary>True once the wasp nest has sent its emissary: no wasp ever comes again.</summary>
    public bool EmissaryCome => State.EmissaryCome;

    // Cut (Bee, 2026-11-11), with the repellent candle: wasp time that one repellent candle buys (longer with
    // Stronger Candles).
    // public decimal RepellentBurnSeconds =>
    //     Config.RepellentBurnSeconds * (Owns(BeekeeperUpgrades.StrongerCandles) ? Config.StrongerCandlesBonus : 1m);

    /// <summary>
    /// "Wasp time" passed: only while Beekeeper is on screen and the player is active (the view
    /// model decides; No Stress Mode no longer applies to Beekeeper, spec 014). An older save's burning
    /// repellent candle (<see cref="BeekeeperState.RepellentSecondsLeft"/>; none can be lit now) uses it up, and
    /// no wasp comes, not even one already waiting its turn; otherwise it counts down to the next wasp. Away
    /// time never comes here, and after the emissary nothing happens at all.
    /// </summary>
    public IReadOnlyList<BeekeeperEvent> AdvanceWaspTime(decimal seconds)
    {
        var events = new List<BeekeeperEvent>();
        // Bee, 2026-11-14: a wasp that has come waits its turn in the story queue (one thing at a time), and
        // wasp time is paused while it waits, as a visitor's return time is.
        if (seconds <= 0m || !State.WorkbenchRevealed || WaspApproaching || State.EmissaryCome) return events;
        // Review fix (2026-11-15): only wasp time brings a queued wasp to the door, so it never comes (and
        // drifts off unseen, spending a visit) while nobody is watching.
        // Review fix (2026-11-15): an old save's candle burns first, so it burns down (and keeps the wasp away)
        // even with a wasp waiting its turn; it used to stay lit forever while the wasp came anyway.
        if (State.RepellentSecondsLeft > 0m)
        {
            State.RepellentSecondsLeft = Math.Max(0m, State.RepellentSecondsLeft - seconds);
            if (State.RepellentSecondsLeft == 0m) events.Add(new BeekeeperEvent(BeekeeperEvents.CandleOut));
            return events;   // a candle's time is never also wasp time
        }
        if (State.StoryQueue.Contains(WaspEntry)) { FillStoryArea(events, waspMayCome: true); return events; }

        if (State.NextWaspInSeconds <= 0m) RollNextWasp();
        State.NextWaspInSeconds -= seconds;
        if (State.NextWaspInSeconds <= 0m)
        {
            State.NextWaspInSeconds = 0m;
            Enqueue(WaspEntry);   // shown (countdown started, "buzzing" line told) when its turn comes
            FillStoryArea(events, waspMayCome: true);
        }
        return events;
    }

    /// <summary>True while the wasp at the door is on its first visit: the choices are Throw a shoe /
    /// Engage. Later visits are Throw a shoe / Bribe. (Older saves that already bribed count as later.)
    /// Review fix (2026-11-15): a visit counts once the wasp has been met (<see cref="WaspMet"/>), so this is
    /// "no wasp met yet" (was: WaspVisits &lt;= 1, counted on arrival).</summary>
    public bool WaspFirstVisit => State.WaspVisits == 0 && State.BribesTotal == 0;

    public bool CanEngageWasp => WaspApproaching && WaspFirstVisit;

    /// <summary>First visit only: the player speaks to the wasp, which wants nothing to do with them and steals
    /// honey, the same amount as if it had been left alone (a raid). Bee, 2026-11-14: it used to hum and leave
    /// with nothing lost. It does not count towards the emissary.</summary>
    public ActionResult EngageWasp()
    {
        if (!CanEngageWasp) return ActionResult.Refused;
        var raid = Raid(BeekeeperEvents.WaspEngaged);   // Value = honey stolen
        return new ActionResult(true, raid.Value, new[] { raid });
    }

    // ------------------------------------------------------------------ trade reps (bear, hippies)

    public static readonly string[] RepIds = { "bear", "hippies" };

    private bool RepRevealed(string id) => id switch
    {
        "bear" => State.BearRevealed,
        "hippies" => State.HippiesRevealed && !State.HippiesDismissedForGood,   // 5 shoes: gone for good
        _ => false,
    };

    public bool RepPresent(string id) => State.RepsPresent.Contains(id);
    public bool RepEngaged(string id) => State.RepsEngaged.Contains(id);

    /// <summary>The rep at the door right now (Bee, 2026-11-12: one at a time, so 0 or 1 of them).</summary>
    public IReadOnlyList<string> RepsPresent => State.RepsPresent;

    /// <summary>Rep time passes (the view model feeds it every non-away tick). A revealed rep arrives
    /// the first time; one sent away by a shoe arrives again when its delay is used up. No emissary rule.
    /// Bee, 2026-11-12: an arriving rep joins the story queue and is shown when its turn comes (its return
    /// time held at 0 until then); the "shows up again" line is told when it is shown.</summary>
    public IReadOnlyList<BeekeeperEvent> AdvanceRepTime(decimal seconds)
    {
        var events = new List<BeekeeperEvent>();
        foreach (var id in RepIds)
        {
            if (!RepRevealed(id)) continue;
            if (!State.RepsMet.Contains(id))
            {
                State.RepsMet.Add(id);
                Enqueue(RepEntry(id));
                // No log line the first time: the reveal line (BearArrives / HippiesArrive) already says so.
            }
            else if (State.RepReturnIn.TryGetValue(id, out var left) && left > 0m)
            {
                left -= Math.Max(0m, seconds);
                State.RepReturnIn[id] = Math.Max(0m, left);   // at 0 it waits its turn, paused
                if (left <= 0m) Enqueue(RepEntry(id));
            }
        }
        FillStoryArea(events);
        return events;
    }

    /// <summary>Opens the rep's trades.</summary>
    public ActionResult EngageRep(string id)
    {
        if (!State.RepsPresent.Remove(id)) return ActionResult.Refused;
        if (!State.RepsEngaged.Contains(id)) State.RepsEngaged.Add(id);
        return new ActionResult(true, 0m, new[] { new BeekeeperEvent(BeekeeperEvents.RepEngaged, 0m, id) });
    }

    /// <summary>The rep leaves and comes back later (RepReturnSeconds). No miss, no emissary.
    /// Bee, 2026-11-12: the first shoe ever at a bear brings a one-time card; the Hippies' 5th shoe (over all
    /// their visits) sends them away for good, with a card instead of the "back later" line.</summary>
    public ActionResult ThrowShoeAtRep(string id)
    {
        if (!State.RepsPresent.Remove(id)) return ActionResult.Refused;
        if (id == "bear") State.BearShoeThrown = true;
        if (id == "hippies")
        {
            if (State.HippieShoes < int.MaxValue) State.HippieShoes++;   // never wraps negative (a hand-edited save)
            if (State.HippieShoes >= Config.HippiesShoesForGood)
            {
                State.HippiesDismissedForGood = true;
                State.RepsEngaged.Remove(id);
                State.RepReturnIn.Remove(id);
                State.StoryQueue.Remove(RepEntry(id));
                return new ActionResult(true, 1m, Array.Empty<BeekeeperEvent>());   // the card speaks
            }
        }
        State.RepReturnIn[id] = Config.RepReturnSeconds;
        return new ActionResult(true, 1m, new[] { new BeekeeperEvent(BeekeeperEvents.RepLeft, 0m, id) });
    }

    // ------------------------------------------------------------------ the story area (Bee, 2026-11-12)
    // Story cards and visitors (the bear, the Hippies) show one at a time, in the order they arrive. What
    // arrives while something is showing waits in State.StoryQueue; a card that fades by itself holds the
    // queue while it fades. Before, the visitors stacked under the card in one panel.

    private const string RepPrefix = "rep:";
    private static string RepEntry(string id) => RepPrefix + id;
    private static string? RepOfEntry(string entry) => entry.StartsWith(RepPrefix, StringComparison.Ordinal) ? entry[RepPrefix.Length..] : null;

    /// <summary>A story card or a visitor is showing.</summary>
    public bool StoryAreaBusy => State.StoryHere is not null || State.RepsPresent.Count > 0 || WaspApproaching;

    /// <summary>The wasp's place in the story queue (Bee, 2026-11-14: wasps wait their turn like visitors).</summary>
    private const string WaspEntry = "wasp";

    /// <summary>What waits its turn, in order (story ids, and "rep:bear" / "rep:hippies").</summary>
    public IReadOnlyList<string> StoryQueue => State.StoryQueue;

    /// <summary>Play seconds a card that goes by itself stays up, or null for a card that waits for an answer.</summary>
    private decimal? FadeSeconds(string id) => id switch
    {
        BeekeeperStories.Ouch => Config.OuchSeconds,
        BeekeeperStories.BearShoe => Config.BearShoeCardSeconds,
        BeekeeperStories.HippiesGone => Config.HippiesGoneCardSeconds,
        _ => null,
    };

    private decimal MaxFadeSeconds => Math.Max(Config.OuchSeconds, Math.Max(Config.BearShoeCardSeconds, Config.HippiesGoneCardSeconds));

    private void Enqueue(string entry)
    {
        if (!State.StoryQueue.Contains(entry)) State.StoryQueue.Add(entry);
    }

    /// <summary>An entry still belongs in the queue: a rep still coming and not at the door, or a story
    /// moment still due, not answered, not waiting to come back and not showing.</summary>
    private bool StillWaiting(string entry) => entry == WaspEntry
        ? State.WorkbenchRevealed && !State.EmissaryCome && !WaspApproaching
        : RepOfEntry(entry) is { } rep
        ? RepRevealed(rep) && !State.RepsPresent.Contains(rep) && !State.RepsEngaged.Contains(rep)
        : BeekeeperStories.Order.Contains(entry) && entry != State.StoryHere && !State.StoriesDone.Contains(entry)
          && !State.StoryReturnIn.ContainsKey(entry) && StoryDue(entry);

    /// <summary>Newly due moments join the back of the queue (in story order), what no longer belongs leaves
    /// it, and when nothing is showing the front comes forward: a card (its fade timer starts) or a visitor
    /// (a returning one is told in the log). A wasp at the front comes only on wasp time
    /// (<paramref name="waspMayCome"/>: Beekeeper watched); until then it holds its place and the rest wait behind it.</summary>
    private void FillStoryArea(List<BeekeeperEvent> events, bool waspMayCome = false)
    {
        State.StoryQueue.RemoveAll(e => !StillWaiting(e));
        foreach (var id in BeekeeperStories.Order)
            if (!State.StoryQueue.Contains(id) && StillWaiting(id)) State.StoryQueue.Add(id);
        if (StoryAreaBusy || State.StoryQueue.Count == 0) return;
        if (State.StoryQueue[0] == WaspEntry && !waspMayCome) return;

        string next = State.StoryQueue[0];
        State.StoryQueue.RemoveAt(0);
        if (next == WaspEntry)
        {
            State.WaspCountdown = Config.WaspCountdownSeconds;
            // Review fix (2026-11-15): the visit counts once the wasp is met (WaspMet), not when it arrives, so a
            // wasp that drifts off unanswered (or is at the door when the app closes) never uses up the first visit.
            events.Add(new BeekeeperEvent(BeekeeperEvents.WaspArrives));
            return;
        }
        if (RepOfEntry(next) is { } rep)
        {
            State.RepsPresent.Add(rep);
            // A rep back from a shoe is told now; the first time, its reveal line already said it.
            if (State.RepReturnIn.Remove(rep)) events.Add(new BeekeeperEvent(BeekeeperEvents.RepArrives, 0m, rep));
            return;
        }
        State.StoryHere = next;
        if (FadeSeconds(next) is { } fade) State.OuchSecondsLeft = fade;
        events.Add(new BeekeeperEvent(BeekeeperEvents.StoryArrives, 0m, next));
    }

    // ------------------------------------------------------------------ story cards

    /// <summary>The story card showing now, or null.</summary>
    public string? StoryHere => State.StoryHere;

    private bool StoryDue(string id) => id switch
    {
        BeekeeperStories.Opening => true,   // until it is done (its button, or the first bee caught)
        BeekeeperStories.Ouch => State.ToolLevel == 0 && State.FirstStingDone,
        BeekeeperStories.Gloves => State.ToolLevel == 0 && !State.GlovesRefusedForGood
                                   && State.BeesCaught >= Config.GlovesOfferBees,
        BeekeeperStories.Smoker => !Owns(BeekeeperUpgrades.Smoker) && State.Bees >= Config.SmokerStoryBees,
        BeekeeperStories.Seed => State.SeedsInHand.Count > 0,   // a kind never planted (Bee, 2026-11-11)
        // Bee, 2026-11-12: the crafts that left The Workbench. Each shows while the first one can be made
        // (the candle: wax for several), and leaves by itself if that stops being true.
        BeekeeperStories.PotHoney => State.Honey >= Config.PotHoneyStoryHoney && CanPotHoney,
        BeekeeperStories.Candle => CanCraftBeeswaxTimes(Config.CandleStoryCandles),
        BeekeeperStories.BeeBread => CanMakeBeeBread,
        // Bee, 2026-11-12
        BeekeeperStories.GlovesFit => State.GlovesLineBeesLeft > 0,
        BeekeeperStories.BearShoe => State.BearShoeThrown,
        BeekeeperStories.HippiesGone => State.HippiesDismissedForGood,
        _ => false,
    };

    /// <summary>The seed the "Plant it?" card is about: the first in hand, or null.</summary>
    public string? StorySeed => State.SeedsInHand.FirstOrDefault();

    /// <summary>The "Plant it?" card's button: plants that seed (and any more of its kind in hand).</summary>
    public ActionResult PlantFromStory()
    {
        if (State.StoryHere != BeekeeperStories.Seed || StorySeed is not { } id) return ActionResult.Refused;
        return PlantSeed(id);   // clears the card; the next new kind, if any, brings it back
    }

    /// <summary>Story time passes (play time only, like rep time). Counts down declined moments and the
    /// fading card, then fills the story area (Bee, 2026-11-12: one card or visitor at a time, in the order
    /// they arrive; due moments queue behind a visitor at the door).
    /// Raises <see cref="BeekeeperEvents.StoryArrives"/> (no log line: the card speaks).</summary>
    /// <remarks>Review fix (2026-11-15): a card that fades by itself counts down only while
    /// <paramref name="watched"/> (Beekeeper on screen), so it is never marked done unseen.</remarks>
    public IReadOnlyList<BeekeeperEvent> AdvanceStoryTime(decimal seconds, bool watched = true)
    {
        var events = new List<BeekeeperEvent>();
        foreach (var id in State.StoryReturnIn.Keys.ToList())
        {
            decimal left = State.StoryReturnIn[id] - Math.Max(0m, seconds);
            if (left > 0m) State.StoryReturnIn[id] = left;
            else State.StoryReturnIn.Remove(id);
        }
        if (watched && State.StoryHere is { } fading && FadeSeconds(fading) is not null)
        {
            // "Ouch!" and the other cards with no button fade by themselves after a few seconds of play.
            State.OuchSecondsLeft -= Math.Max(0m, seconds);
            if (State.OuchSecondsLeft <= 0m) { State.OuchSecondsLeft = 0m; FinishStory(fading); }
        }
        // The seed card leaves by itself once there is nothing left to plant.
        if (State.StoryHere == BeekeeperStories.Seed && !StoryDue(BeekeeperStories.Seed)) State.StoryHere = null;
        // Cut (Bee, 2026-11-14; may return): a craft card stays until its button is clicked (it left by itself when the first one
        // couldn't be made any more, e.g. after a comb spent the wax); its button is dimmed meanwhile.
        // if (State.StoryHere is BeekeeperStories.PotHoney or BeekeeperStories.Candle or BeekeeperStories.BeeBread
        //     && !StoryDue(State.StoryHere)) State.StoryHere = null;
        // The gloves-fit card is done once its bees are caught (normally Catch finishes it at once).
        if (State.StoryHere == BeekeeperStories.GlovesFit && !StoryDue(BeekeeperStories.GlovesFit)) FinishStory(BeekeeperStories.GlovesFit);
        // Review fix (2026-11-15): the pot-honey card with no clay jars could wait forever, since the jars come
        // from the Hippies, who wait behind it. When something else waits, it steps aside (not done); it comes
        // back once it can be made again.
        if (State.StoryHere == BeekeeperStories.PotHoney && State.ClayJars < Config.PotHoneyJars && State.StoryQueue.Count > 0)
            State.StoryHere = null;
        FillStoryArea(events);
        return events;
    }

    /// <summary>The opening card's button ("Look around"): the card is done for good. No log line.</summary>
    public ActionResult BeginFromStory()
    {
        if (State.StoryHere != BeekeeperStories.Opening) return ActionResult.Refused;
        FinishStory(BeekeeperStories.Opening);
        return new ActionResult(true, 0m, Array.Empty<BeekeeperEvent>());
    }

    /// <summary>The first bee caught finishes the opening card too, silently, whether it is showing
    /// or not yet, so it never holds up "Ouch!" (FR-1004).</summary>
    private void FinishOpeningIfDue()
    {
        if (State.StoriesDone.Contains(BeekeeperStories.Opening)) return;
        if (State.BeesCaught < Config.OpeningCardClicks) return;   // Bee, 2026-11-12: stays up for the first few clicks
        if (State.StoryHere == BeekeeperStories.Opening) FinishStory(BeekeeperStories.Opening);
        else State.StoriesDone.Add(BeekeeperStories.Opening);
    }

    /// <summary>Yes: the gloves go on (tool level 1). Refused unless the gloves card is showing.</summary>
    public ActionResult PutOnGloves()
    {
        if (State.StoryHere != BeekeeperStories.Gloves) return ActionResult.Refused;
        State.ToolLevel = Math.Max(State.ToolLevel, 1);
        State.GlovesLineBeesLeft = Config.GlovesLineBees;
        FinishStory(BeekeeperStories.Gloves);
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.GlovesOn) };
        CheckWalls(events);
        return new ActionResult(true, 0m, events);
    }

    /// <summary>No: the card goes away and comes back after GlovesReturnSeconds of play; the Nth No is for good.</summary>
    public ActionResult LeaveGloves()
    {
        if (State.StoryHere != BeekeeperStories.Gloves) return ActionResult.Refused;
        State.GlovesDeclines++;
        State.StoryHere = null;
        if (State.GlovesDeclines >= Config.GlovesMaxDeclines)
        {
            State.GlovesRefusedForGood = true;
            if (!State.StoriesDone.Contains(BeekeeperStories.Gloves)) State.StoriesDone.Add(BeekeeperStories.Gloves);
            return new ActionResult(true, 0m, new[] { new BeekeeperEvent(BeekeeperEvents.GlovesGone) });
        }
        State.StoryReturnIn[BeekeeperStories.Gloves] = Config.GlovesReturnSeconds;
        return new ActionResult(true, 0m, Array.Empty<BeekeeperEvent>());
    }

    /// <summary>Repair (free): the Smoker works right away. Refused unless the Smoker card is showing.</summary>
    public ActionResult RepairSmoker()
    {
        if (State.StoryHere != BeekeeperStories.Smoker) return ActionResult.Refused;
        if (!State.Upgrades.Contains(BeekeeperUpgrades.Smoker)) State.Upgrades.Add(BeekeeperUpgrades.Smoker);
        FinishStory(BeekeeperStories.Smoker);
        return new ActionResult(true, 0m, new[] { new BeekeeperEvent(BeekeeperEvents.SmokerRepaired) });
    }

    private void FinishStory(string id)
    {
        State.StoryHere = null;
        State.StoryReturnIn.Remove(id);
        if (!State.StoriesDone.Contains(id)) State.StoriesDone.Add(id);
    }

    /// <summary>Shows a story card now (debug builds only; the game never does this).</summary>
    public IReadOnlyList<BeekeeperEvent> DebugShowStory(string id)
    {
        if (!BeekeeperStories.Order.Contains(id) || StoryAreaBusy || State.StoriesDone.Contains(id))
            return Array.Empty<BeekeeperEvent>();
        State.StoryReturnIn.Remove(id);
        State.StoryQueue.Remove(id);
        State.StoryHere = id;
        if (FadeSeconds(id) is { } fade) State.OuchSecondsLeft = fade;
        return new[] { new BeekeeperEvent(BeekeeperEvents.StoryArrives, 0m, id) };
    }

    private void RollNextWasp()
    {
        decimal span = Config.WaspMaxSeconds - Config.WaspMinSeconds;
        State.NextWaspInSeconds = Config.WaspMinSeconds + span * (decimal)_rng.NextDouble();
    }

    /// <summary>Calls a wasp at once (debug builds only; the game never does this).</summary>
    public IReadOnlyList<BeekeeperEvent> DebugCallWasp()
    {
        if (!State.WorkbenchRevealed || WaspApproaching || State.EmissaryCome || State.StoryQueue.Contains(WaspEntry))
            return Array.Empty<BeekeeperEvent>();
        State.NextWaspInSeconds = 0m;
        var events = new List<BeekeeperEvent>();
        Enqueue(WaspEntry);   // it waits its turn behind whatever is showing
        FillStoryArea(events, waspMayCome: true);
        return events;
    }

    /// <summary>Real seconds pass while the player watches an approaching wasp; at zero it raids.</summary>
    public IReadOnlyList<BeekeeperEvent> AdvanceWaspCountdown(decimal seconds)
    {
        if (!WaspApproaching || seconds <= 0m) return Array.Empty<BeekeeperEvent>();
        State.WaspCountdown = Math.Max(0m, State.WaspCountdown - seconds);
        return State.WaspCountdown > 0m ? Array.Empty<BeekeeperEvent>() : new[] { Raid(BeekeeperEvents.WaspRaid) };
    }

    /// <summary>The player left Beekeeper, went idle or the computer slept: the wasp drifts off, nothing lost.</summary>
    public IReadOnlyList<BeekeeperEvent> WaspLeaves()
    {
        if (!WaspApproaching) return Array.Empty<BeekeeperEvent>();
        EndWasp();
        return new[] { new BeekeeperEvent(BeekeeperEvents.WaspLeft) };
    }

    /// <summary>60% the wasp is driven off; 40% it raids at once. One throw per wasp.</summary>
    public ActionResult ThrowShoe()
    {
        if (!WaspApproaching) return ActionResult.Refused;
        if (_rng.NextDouble() < Config.ShoeHitChance)
        {
            WaspMet();
            return new ActionResult(true, 1m, new[] { new BeekeeperEvent(BeekeeperEvents.ShoeHit) });
        }
        return new ActionResult(true, 0m, new[] { Raid(BeekeeperEvents.ShoeMissRaid) });
    }

    public bool CanBribe => WaspApproaching && State.Honey >= 1m;

    /// <summary>The honey a bribe would cost right now.</summary>
    public decimal BribeCost => Math.Max(1m, Math.Floor(State.Honey * Config.BribeHoneyShare));

    /// <summary>Pay 25% of the stored honey (at least 1); the wasp leaves. Every bribe counts
    /// towards the emissary, in total (spec 014): the 3rd brings a hint, the 5th the emissary.</summary>
    public ActionResult Bribe()
    {
        if (!CanBribe) return ActionResult.Refused;
        decimal paid = BribeCost;
        State.Honey -= paid;
        State.BribesTotal++;
        RefreshStorageFlag();
        WaspMet();
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.Bribe, paid) };
        if (State.BribesTotal == Config.BribesForHint && State.BribesTotal < Config.BribesForEmissary)
            events.Add(new BeekeeperEvent(BeekeeperEvents.BribeHint));
        SendEmissaryIfDue(events);
        return new ActionResult(true, paid, events);
    }

    /// <summary>Enough bribes and the wasp nest sends its emissary: raids end for good, any wasp
    /// still here leaves, and the wasps become a trading partner. A one-way switch.</summary>
    private void SendEmissaryIfDue(List<BeekeeperEvent> events)
    {
        if (State.EmissaryCome || State.BribesTotal < Config.BribesForEmissary) return;
        State.EmissaryCome = true;
        EndWasp();
        events.Add(new BeekeeperEvent(BeekeeperEvents.Emissary));
    }

    // Cut (Bee, 2026-11-11): the repellent candle kept wasps away; the herbal candle took its place
    // and rolls a buff instead (LightRepellent, with the herbal candles above).
    // public bool CanLightRepellent => State.RepellentCandles >= 1m && !RepellentRetired;
    // public ActionResult LightRepellent()
    // {
    //     if (!CanLightRepellent) return ActionResult.Refused;
    //     State.RepellentCandles--;
    //     State.RepellentSecondsLeft += RepellentBurnSeconds;
    //     var events = new List<BeekeeperEvent> { new(BeekeeperEvents.CandleLit) };
    //     if (WaspApproaching) EndWasp();
    //     return new ActionResult(true, 1m, events);
    // }

    /// <summary>A raid takes 3 minutes' worth of honey and nothing else (spec 014: never bees).</summary>
    /// <remarks>Review fix (2026-11-15): always a whole amount (an odd 0.4 honey stored is left alone), so the
    /// log's rounded-down number is what was taken; 0 taken is told with no amount.</remarks>
    private BeekeeperEvent Raid(string key)
    {
        decimal honey = Math.Floor(Math.Max(0m, Math.Min(State.Honey, Math.Floor(HoneyPerSecond * Config.RaidHoneySeconds))));
        // Cut in stage 6 (spec 014): some bees flew off, unless a guard bee kept them safe.
        // bool guarded = HasGuards;   // one guard bee and no raid ever costs a bee
        // decimal bees = guarded ? 0m : Math.Floor(State.Bees * Config.RaidBeeShare);
        // State.Bees -= bees;
        State.Honey -= honey;
        RefreshStorageFlag();
        WaspMet();   // engaged, missed with a shoe, or left to its countdown while watched
        return new BeekeeperEvent(key, honey);
        // return new BeekeeperEvent(key, honey, guarded ? "guards" : null, bees);
    }

    /// <summary>The player met the wasp at the door (answered it, or watched its countdown run out): the visit
    /// counts, and the wasp goes. A wasp that drifts off unseen (<see cref="WaspLeaves"/>) or is sent home by the
    /// emissary doesn't count.</summary>
    private void WaspMet()
    {
        State.WaspVisits++;
        EndWasp();
    }

    private void EndWasp()
    {
        State.WaspCountdown = 0m;
        State.NextWaspInSeconds = 0m;   // rolled afresh on the next wasp time
    }

    // ------------------------------------------------------------------ the wasps' paper (stage 6)

    /// <summary>Whether <paramref name="count"/> paper can be bought from the wasps in one go.</summary>
    public bool CanTradePaperTimes(int count) =>
        count >= 1 && State.EmissaryCome && State.Honey >= Config.HoneyPerPaper * count;

    public bool CanTradePaper => CanTradePaperTimes(1);

    /// <summary>Honey for paper: exactly count times the price, or nothing. One click is one
    /// trade towards the wasps' reputation, whatever the batch.</summary>
    public ActionResult TradeForPaper(int count = 1)
    {
        if (!CanTradePaperTimes(count)) return ActionResult.Refused;
        decimal honey = Config.HoneyPerPaper * count;
        State.Honey -= honey;
        State.Paper += count;
        State.WaspTrades++;
        RefreshStorageFlag();
        State.PaperRevealed = true;
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.WaspTrade, count, null, honey) };
        if (State.WaspTrades == 1) events.Add(new BeekeeperEvent(BeekeeperEvents.FirstPaper));
        // Stage 8 (spec 017): from their 20th trade on, each wasp trade (a batch is one) may give a poplar seed.
        // Cut in stage 8: GiveSeedsIfDue(events);   // the wasps' reputation brings the poplar seed
        UnlockSeedsIfDue(events);
        if (RollSeed(BeekeeperGivers.Wasps, Config.WaspSeedChance) is { } seed)
            events.Add(new BeekeeperEvent(BeekeeperEvents.WaspSeedGiven, State.SeedsInHand.Count, seed));
        CheckWalls(events);
        return new ActionResult(true, count, events);
    }

    // ------------------------------------------------------------------ the Garden (stage 4)

    // Cut in stage 6 (spec 014): guards no longer protect bees in a raid.
    // public bool HasGuards => State.GuardBees >= 1m;
    // Cut in stage 7 (spec 015): one growing seed, and "the Nth seed is the Nth plant".
    // public bool IsGrowing => State.GrowSecondsLeft > 0m;
    // public BeekeeperPlant? GrowingPlant =>
    //     IsGrowing && State.SeedsPlanted >= 1 && State.SeedsPlanted <= Config.Plants.Count
    //         ? Config.Plants[State.SeedsPlanted - 1] : null;

    // Cut in stage 8 (spec 017, FR-803): plants grow at once, so there are no beds.
    // /// <summary>Garden beds owned: two, three with the Third Bed.</summary>
    // public int BedCount => Config.StartingBeds + (Owns(BeekeeperUpgrades.ThirdBed) ? Config.ThirdBedBeds : 0);
    // /// <summary>Beds with a seed growing.</summary>
    // public bool IsGrowing => State.Beds.Count > 0;
    // public int FreeBeds => Math.Max(0, BedCount - State.Beds.Count);

    public BeekeeperPlant? PlantById(string id) => Config.Plants.FirstOrDefault(p => p.Id == id);

    /// <summary>Seeds in hand, as plants (in the order they were given; a kind can repeat).</summary>
    public IReadOnlyList<BeekeeperPlant> SeedsInHand =>
        State.SeedsInHand.Select(PlantById).OfType<BeekeeperPlant>().ToList();

    /// <summary>Seeds of one kind in hand (stage 8).</summary>
    public int SeedCount(string plantId) => State.SeedsInHand.Count(id => id == plantId);

    /// <summary>Plants of one kind in the garden (stage 8, FR-804: many of each).</summary>
    public int PlantCount(string plantId) => State.Plants.Count(id => id == plantId);

    /// <summary>Plants that have sprouted, in order (a kind can repeat since stage 8).</summary>
    public IReadOnlyList<BeekeeperPlant> SproutedPlants =>
        State.Plants.Select(id => Config.Plants.FirstOrDefault(p => p.Id == id)).OfType<BeekeeperPlant>().ToList();

    /// <summary>Each plant kind in the garden once, in the order each first came (stage 8, FR-804).
    /// Every specialty reads this, so a specialty never grows past the first plant of a kind.</summary>
    public IReadOnlyList<BeekeeperPlant> PlantKinds => SproutedPlants.DistinctBy(p => p.Id).ToList();

    /// <summary>The hive's specialties, from the sprouted plants, in the order they first came.</summary>
    public IReadOnlyList<string> Specialties => PlantKinds.Select(p => p.Specialty).Distinct().ToList();

    public bool HasSpecialty(string id) => PlantKinds.Any(p => p.Specialty == id);

    /// <summary>Nursing's laying multiplier: each nursing plant kind's strength once, multiplied (1 = none).
    /// Stage 9: its bonus part works twice as hard in crocus (×1.5 → ×2).</summary>
    public decimal NursingMultiplier => 1m + (NursingMultiplierAlone - 1m) * BloomFavour(BeekeeperSpecialties.Nursing);

    /// <summary>Nursing's laying multiplier without the bloom (for the hovers).</summary>
    public decimal NursingMultiplierAlone
    {
        get
        {
            decimal m = 1m;
            foreach (var p in PlantKinds)
                if (p.Specialty == BeekeeperSpecialties.Nursing) m *= p.Strength;
            return m;
        }
    }

    /// <summary>Propolis a minute from resin: each resin plant kind's strength once, added up
    /// (before the poplars' bonus; see <see cref="PropolisPerMinute"/>). Stage 9: doubled in goldenrod.</summary>
    public decimal ResinPropolisPerMinute => ResinPropolisPerMinuteAlone * BloomFavour(BeekeeperSpecialties.Resin);

    /// <summary>Propolis a minute from resin without the goldenrod (for the hovers, which list the bloom as a boost).</summary>
    public decimal ResinPropolisPerMinuteAlone =>
        PlantKinds.Where(p => p.Specialty == BeekeeperSpecialties.Resin).Sum(p => p.Strength);

    /// <summary>The bee hotel can bring propolis (a rare bee whose gift it is): the Propolis hover says so.</summary>
    public bool HotelBringsPropolis => HasBeeHotel && Config.RareBees.Any(b => b.Gift == BeekeeperGifts.Propolis);

    /// <summary>Propolis a minute, with the propolis plants' bonus (stage 8, FR-805).</summary>
    public decimal PropolisPerMinute => ResinPropolisPerMinute * PlantBonus(BeekeeperBonusTargets.Propolis);

    public decimal PropolisPerSecondNow => PropolisPerMinute / 60m;

    /// <summary>Pollen a minute from foraging: each foraging plant kind's strength once, added up
    /// (wildflowers and clover: 3 + 3).</summary>
    /// <remarks>Stage 9: doubled in clover (6 → 12).</remarks>
    public decimal ForagingPollenPerMinute => ForagingPollenPerMinuteAlone * BloomFavour(BeekeeperSpecialties.Foraging);

    /// <summary>Pollen a minute from foraging without the clover (for the hovers, which list the bloom as a boost).</summary>
    public decimal ForagingPollenPerMinuteAlone =>
        PlantKinds.Where(p => p.Specialty == BeekeeperSpecialties.Foraging).Sum(p => p.Strength);

    public decimal PollenPerSecondNow => ForagingPollenPerMinute / 60m;

    /// <summary>Guarding's honey multiplier: each guarding plant kind's strength once, multiplied (1 = none).
    /// Stage 9: its bonus part works twice as hard in linden (+25% → +50%).</summary>
    public decimal GuardingMultiplier => 1m + (GuardingMultiplierAlone - 1m) * BloomFavour(BeekeeperSpecialties.Guarding);

    /// <summary>Guarding's honey multiplier without the bloom (for the hovers).</summary>
    public decimal GuardingMultiplierAlone
    {
        get
        {
            decimal m = 1m;
            foreach (var p in PlantKinds)
                if (p.Specialty == BeekeeperSpecialties.Guarding) m *= p.Strength;
            return m;
        }
    }

    // ---- the bloom calendar (stage 9, spec 018)

    /// <summary>The bloom out now, or null before the calendar has started.</summary>
    public BeekeeperBloom? CurrentBloom =>
        State.CalendarStarted && Config.Blooms.Count > 0 ? Config.Blooms[State.BloomIndex % Config.Blooms.Count] : null;

    /// <summary>The bloom that comes after this one (null before the calendar).</summary>
    public BeekeeperBloom? NextBloomUp =>
        CurrentBloom is null ? null : Config.Blooms[(State.BloomIndex + 1) % Config.Blooms.Count];

    /// <summary>Seconds of game time the bloom has left (0 before the calendar).</summary>
    public decimal BloomSecondsLeft => State.CalendarStarted ? State.BloomSecondsLeft : 0m;

    public bool IsWinter => CurrentBloom?.Id == BeekeeperBlooms.Winter;

    /// <summary>How hard <paramref name="specialty"/> works because of the bloom:
    /// <see cref="BeekeeperConfig.BloomFavourMultiplier"/> while the bloom favours it, else 1 (FR-905).</summary>
    public decimal BloomFavour(string specialty) =>
        CurrentBloom?.Favours == specialty ? Config.BloomFavourMultiplier : 1m;

    /// <summary>True when the bloom out now favours a specialty the hive has (the bloom changes a number).</summary>
    public bool BloomFavourActive => CurrentBloom?.Favours is { } f && HasSpecialty(f);

    /// <summary>Winter's honey factor: <see cref="BeekeeperConfig.WinterHoneyMultiplier"/> in winter, else 1 (FR-906).</summary>
    public decimal WinterMultiplier => IsWinter ? Config.WinterHoneyMultiplier : 1m;

    private void SetCalendarStart(BeekeeperState s)
    {
        s.CalendarStarted = true;
        s.BloomIndex = 0;
        s.BloomSecondsLeft = BloomLength(0);
    }

    private decimal BloomLength(int index) => Math.Max(1m, Config.Blooms[index].Seconds);   // never 0, or Work would stall

    /// <summary>Starts the calendar on the first bloom (crocus) with its full length, once (FR-903).
    /// Every path that adds the first plant calls this; it is also the debug shortcut.</summary>
    public IReadOnlyList<BeekeeperEvent> StartCalendar()
    {
        var events = new List<BeekeeperEvent>();
        StartCalendarIfDue(events, force: true);
        return events;
    }

    /// <summary>The calendar starts with the first plant (or at once when <paramref name="force"/>d).</summary>
    private void StartCalendarIfDue(List<BeekeeperEvent> events, bool force = false)
    {
        if (State.CalendarStarted || Config.Blooms.Count == 0 || (!force && State.Plants.Count == 0)) return;
        SetCalendarStart(State);
        events.Add(new BeekeeperEvent(BeekeeperEvents.CalendarStarted, 0m, CurrentBloom!.Id));
    }

    /// <summary>The next bloom comes out (wrapping), with its full length and a <see cref="BeekeeperEvents.BloomChanged"/> event.</summary>
    private void NextBloom(List<BeekeeperEvent> events)
    {
        State.BloomIndex = (State.BloomIndex + 1) % Config.Blooms.Count;
        State.BloomSecondsLeft = BloomLength(State.BloomIndex);
        events.Add(new BeekeeperEvent(BeekeeperEvents.BloomChanged, 0m, Config.Blooms[State.BloomIndex].Id));
    }

    /// <summary>Debug builds only: the next bloom comes out now, nothing produced.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugNextBloom()
    {
        var events = new List<BeekeeperEvent>();
        if (State.CalendarStarted) NextBloom(events);
        return events;
    }

    // ---- plant bonuses (stage 8, FR-805)

    /// <summary>One plant kind's bonus share: <see cref="BeekeeperPlant.BonusPerExtra"/> for each plant
    /// of that kind after the first (0 with one or none).</summary>
    public decimal PlantBonusShare(BeekeeperPlant plant) => plant.BonusPerExtra * Math.Max(0, PlantCount(plant.Id) - 1);

    /// <summary>The plants' bonus on one resource's rate: 1 + every kind's share for that target,
    /// added up, never multiplied. It never reads what is stored, so live and away agree.</summary>
    public decimal PlantBonus(string target)
    {
        decimal sum = 0m;
        foreach (var p in PlantKinds)
            if (p.BonusTarget == target) sum += PlantBonusShare(p);
        return 1m + sum;
    }

    /// <summary>The plant kinds adding to <paramref name="target"/> right now (two or more of the
    /// kind), for the growth hovers: each kind, how many after the first, and its share.</summary>
    public IReadOnlyList<(BeekeeperPlant Plant, int Extra, decimal Share)> PlantBonusSources(string target) =>
        PlantKinds.Where(p => p.BonusTarget == target && PlantBonusShare(p) > 0m)
            .Select(p => (p, PlantCount(p.Id) - 1, PlantBonusShare(p))).ToList();

    // ---- the seed rolls (stage 8, FR-802)

    // Cut in stage 7 (spec 015): the Nth Hippie seed was the Nth plant, one at a time.
    // private void GiveSeedIfDue(List<BeekeeperEvent> events)
    // {
    //     if (State.SeedsGiven >= Config.Plants.Count) return;
    //     if (State.HippieTrades < Config.Plants[State.SeedsGiven].SeedAtTrade) return;
    //     State.SeedsGiven++;
    //     State.Seeds++;
    //     State.GardenRevealed = true;
    //     events.Add(new BeekeeperEvent(BeekeeperEvents.SeedGiven, State.Seeds));
    // }

    // Cut in stage 8 (spec 017, FR-802): each seed was given once, on a set trade. Seeds now come
    // through a roll on every trade (UnlockSeedsIfDue, RollSeed).
    // /// <summary>Gives every seed whose giver has traded enough and that was not given yet: the
    // /// Hippies' plants by Hippie trades, the wasps' by wasp trades. Each plant is given once, by
    // /// id. Checked after a trade and on load (so an older save past a count gets its seed).</summary>
    // private void GiveSeedsIfDue(List<BeekeeperEvent> events)
    // {
    //     foreach (var plant in Config.Plants)
    //     {
    //         if (State.SeedsGivenIds.Contains(plant.Id) || State.Plants.Contains(plant.Id)
    //             || State.SeedsInHand.Contains(plant.Id) || State.Beds.Any(b => b.PlantId == plant.Id)) continue;
    //         bool byWasps = plant.Giver == BeekeeperGivers.Wasps;
    //         long trades = byWasps ? State.WaspTrades : State.HippieTrades;
    //         if (trades < plant.SeedAtTrade) continue;
    //         GiveSeed(plant, byWasps, events);
    //     }
    // }
    //
    // private void GiveSeed(BeekeeperPlant plant, bool byWasps, List<BeekeeperEvent> events)
    // {
    //     State.SeedsGivenIds.Add(plant.Id);
    //     State.SeedsInHand.Add(plant.Id);
    //     State.GardenRevealed = true;
    //     events.Add(new BeekeeperEvent(byWasps ? BeekeeperEvents.WaspSeedGiven : BeekeeperEvents.SeedGiven,
    //         State.SeedsInHand.Count, plant.Id));
    // }

    /// <summary>A seed is in its giver's roll: its giver has traded enough, or it is listed in
    /// <see cref="BeekeeperState.SeedsGivenIds"/> (said in the log, an older save's given seeds, or debug).</summary>
    public bool IsSeedUnlocked(BeekeeperPlant plant) =>
        State.SeedsGivenIds.Contains(plant.Id)
        || (plant.Giver == BeekeeperGivers.Wasps ? State.WaspTrades : State.HippieTrades) >= plant.SeedAtTrade;

    /// <summary>Every seed in a roll so far, in config order (the mason bee picks from these).</summary>
    public IReadOnlyList<BeekeeperPlant> UnlockedSeeds => Config.Plants.Where(IsSeedUnlocked).ToList();

    /// <summary>Seeds whose giver has now traded enough join the roll, each listed once; the
    /// Hippies' say so in the log ("a new kind of seed"), the wasps' come quietly.</summary>
    private void UnlockSeedsIfDue(List<BeekeeperEvent> events)
    {
        foreach (var plant in Config.Plants)
        {
            if (State.SeedsGivenIds.Contains(plant.Id) || !IsSeedUnlocked(plant)) continue;
            State.SeedsGivenIds.Add(plant.Id);
            // Cut (Bee, 2026-11-11): the "The Hippies have a new kind of seed" log line.
            // if (plant.Giver == BeekeeperGivers.Hippies)
            //     events.Add(new BeekeeperEvent(BeekeeperEvents.SeedJoinsRoll, 0m, plant.Id));
        }
    }

    /// <summary>One trade's roll: with <paramref name="chance"/>, one seed from the giver's unlocked
    /// seeds, each equally likely, goes in hand. No unlocked seed, no roll. Returns the plant id or null.</summary>
    private string? RollSeed(string giver, double chance)
    {
        var pool = Config.Plants.Where(p => p.Giver == giver && IsSeedUnlocked(p)).ToList();
        if (pool.Count == 0 || _rng.NextDouble() >= chance) return null;
        var plant = pool[pool.Count == 1 ? 0 : _rng.Next(pool.Count)];
        AddSeedsInHand(plant.Id, 1);
        return plant.Id;
    }

    /// <summary>Every seed that arrives comes through here. Bee, 2026-11-11: once a kind has been
    /// planted, its seeds plant themselves (no effort); only a kind never planted waits in hand, and
    /// the "Plant it?" story card asks for it. Planting changes no rate a stretch is running on:
    /// gifts land at the end of a piece of <see cref="Work"/>, so live and away still agree.</summary>
    private void AddSeedsInHand(string plantId, int count)
    {
        if (count <= 0) return;
        var target = State.Plants.Contains(plantId) ? State.Plants : State.SeedsInHand;
        for (int i = 0; i < count; i++) target.Add(plantId);
        State.GardenRevealed = true;
    }

    // ---- planting (stage 8: at once)

    /// <summary>A seed in hand (no bed needed since stage 8).</summary>
    public bool CanPlantSeed => State.SeedsInHand.Count >= 1;

    public bool CanPlantSeedOf(string plantId) => State.SeedsInHand.Contains(plantId);
    // Cut in stage 8 (spec 017): a free bed was needed too.
    // public bool CanPlantSeed => State.SeedsInHand.Count >= 1 && FreeBeds > 0;
    // public bool CanPlantSeedOf(string plantId) => State.SeedsInHand.Contains(plantId) && FreeBeds > 0;

    /// <summary>Plants one seed: the plant is in the garden at once (stage 8, FR-803), with the
    /// usual planted and sprouted events. The first willow brings the carpenter bee.
    /// <paramref name="plantId"/> null plants the first seed in hand.</summary>
    public ActionResult PlantSeed(string? plantId = null)
    {
        plantId ??= State.SeedsInHand.FirstOrDefault();
        if (plantId is null || !CanPlantSeedOf(plantId) || PlantById(plantId) is null) return ActionResult.Refused;
        State.SeedsInHand.Remove(plantId);
        bool firstOfKind = !State.Plants.Contains(plantId);
        State.Plants.Add(plantId);
        // Bee, 2026-11-11: the rest of this kind in hand plants itself with it.
        int more = State.SeedsInHand.RemoveAll(id => id == plantId);
        for (int i = 0; i < more; i++) State.Plants.Add(plantId);
        if (State.StoryHere == BeekeeperStories.Seed) State.StoryHere = null;   // the card has been answered
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.SeedPlanted, 0m, plantId) };
        // The first of a kind brings its specialty: the Notebook and the Hive card show it.
        if (firstOfKind) events.Add(new BeekeeperEvent(BeekeeperEvents.PlantRevealed, 0m, plantId));
        StartCalendarIfDue(events);   // stage 9: the first plant starts the calendar
        SummonCarpenterBeeIfDue(events);
        CheckWalls(events);
        return new ActionResult(true, 1m, events);
        // Cut in stage 8 (spec 017): the seed went into a bed for its grow time.
        // State.Beds.Add(new BeekeeperBed { PlantId = plantId, SecondsLeft = plant.GrowSeconds });
        // return new ActionResult(true, 1m, new[] { new BeekeeperEvent(BeekeeperEvents.SeedPlanted, 0m, plantId) });
    }

    // ---- the carpenter bee and wood (stage 8, FR-806)

    /// <summary>The carpenter bee has come: it brings wood.</summary>
    public bool HasCarpenterBee => State.CarpenterBeeCame;

    /// <summary>Wood a minute: the carpenter bee's rate times the willows' bonus; 0 without the bee.</summary>
    public decimal WoodPerMinuteNow =>
        State.CarpenterBeeCame ? Config.WoodPerMinute * PlantBonus(BeekeeperBonusTargets.Wood) : 0m;

    public decimal WoodPerSecondNow => WoodPerMinuteNow / 60m;

    /// <summary>The Wood row shows once the carpenter bee has come.</summary>
    public bool WoodShown => State.CarpenterBeeCame || State.Wood > 0m;

    /// <summary>The first willow (in the garden, by planting or an older save's bed) brings the carpenter bee, once.</summary>
    private void SummonCarpenterBeeIfDue(List<BeekeeperEvent> events)
    {
        if (State.CarpenterBeeCame || !State.Plants.Contains(Config.CarpenterBeePlant)) return;
        State.CarpenterBeeCame = true;
        events.Add(new BeekeeperEvent(BeekeeperEvents.CarpenterBee));
    }

    // ---- the bee hotel (stage 8, FR-811)

    public bool HasBeeHotel => Owns(BeekeeperUpgrades.BeeHotel);

    /// <summary>One part of a hotel gift's event text, so the log can name the bee and the gift.</summary>
    public readonly record struct GiftParts(string Bee, string Gift, string? Plant);

    /// <summary>A gift's event text: "bee|gift" or "bee|seed|plant" (a log entry keeps one text).</summary>
    public static string GiftText(string bee, string gift, string? plant = null) =>
        plant is null ? $"{bee}|{gift}" : $"{bee}|{gift}|{plant}";

    public static GiftParts ParseGiftText(string? text)
    {
        var parts = (text ?? "").Split('|');
        return new GiftParts(parts[0], parts.Length > 1 ? parts[1] : "", parts.Length > 2 ? parts[2] : null);
    }

    /// <summary>One rare bee comes back with a gift: which bee is random, each equally likely. The
    /// mason bee brings a seed from those in a roll so far (herbs instead when there is none). A
    /// bee's first gift adds it to <see cref="BeekeeperState.RareBeesMet"/> (the Bees tab).</summary>
    private void GiveHotelGift(List<BeekeeperEvent> events)
    {
        var bees = Config.RareBees;
        if (bees.Count == 0) return;
        var bee = bees[bees.Count == 1 ? 0 : _rng.Next(bees.Count)];
        string gift = bee.Gift;
        decimal amount = bee.Amount;
        string? plant = null;
        switch (gift)
        {
            case BeekeeperGifts.Seed:
                var pool = UnlockedSeeds;
                if (pool.Count == 0)
                {
                    gift = BeekeeperGifts.Herbs;
                    amount = Config.MasonFallbackHerbs;
                    goto case BeekeeperGifts.Herbs;
                }
                plant = pool[pool.Count == 1 ? 0 : _rng.Next(pool.Count)].Id;
                AddSeedsInHand(plant, (int)amount);
                break;
            case BeekeeperGifts.Herbs:
                State.Herbs += amount;
                State.HerbsRevealed = true;
                // Stage 10 (spec 019, FR-1009): herbs come only from here, so the first ones open the
                // herbal candle's recipe (the bear's first herb did before). Said before the gift line.
                if (!State.RepellentUnlocked)
                {
                    State.RepellentUnlocked = true;
                    events.Add(new BeekeeperEvent(BeekeeperEvents.RepellentUnlocked));
                }
                break;
            case BeekeeperGifts.Propolis:
                State.Propolis += amount;
                if (!State.PropolisRevealed && State.Propolis >= 1m)
                {
                    State.PropolisRevealed = true;
                    events.Add(new BeekeeperEvent(BeekeeperEvents.FirstPropolis));
                }
                break;
        }
        bool first = !State.RareBeesMet.Contains(bee.Id);
        if (first) State.RareBeesMet.Add(bee.Id);
        events.Add(new BeekeeperEvent(first ? BeekeeperEvents.RareBeeArrives : BeekeeperEvents.HotelGift,
            amount, GiftText(bee.Id, gift, plant)));
    }

    // ---- the meadow (stage 8, FR-812)

    /// <summary>The Hive card offers the meadow once one wildflower and one clover are planted.</summary>
    public bool MeadowOffered =>
        !State.HasMeadow && PlantCount(BeekeeperPlants.Wildflowers) >= 1 && PlantCount(BeekeeperPlants.Clover) >= 1;

    /// <summary>Enough of both plants (counted, not spent).</summary>
    public bool CanBuyMeadow =>
        MeadowOffered && PlantCount(BeekeeperPlants.Wildflowers) >= Config.MeadowWildflowers
        && PlantCount(BeekeeperPlants.Clover) >= Config.MeadowClover;

    /// <summary>The hive spreads into the meadow: honey and both caps grow, the plants stay and keep working.</summary>
    public ActionResult BuyMeadow()
    {
        if (!CanBuyMeadow) return ActionResult.Refused;
        State.HasMeadow = true;
        RefreshStorageFlag();
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.MeadowBought) };
        CheckWalls(events);
        return new ActionResult(true, 1m, events);
    }

    // Cut in stage 7 (spec 015): GrowGarden did the one growing seed; Work now splits at every
    // sprout (and the sage-propolis candle burning out) and calls Attract between the splits.

    /// <summary>
    /// The garden's gathering for <paramref name="seconds"/>: pollen (foraging) and propolis (resin)
    /// are straight lines in time (rate × seconds; spec 014), so one long stretch equals many short
    /// ones. <see cref="Work"/> never lets a stretch cross a sprout, so the rates are constant here.
    /// </summary>
    private void Attract(decimal seconds, List<BeekeeperEvent> events)
    {
        if (seconds <= 0m) return;

        // Multiply first and divide once, so whole minutes stay exact.
        State.Pollen = Snap(State.Pollen + ForagingPollenPerMinute * seconds / 60m);
        // Stage 8 (spec 017): propolis with the poplars' bonus, and the carpenter bee's wood (no cap).
        State.Propolis = Snap(State.Propolis + PropolisPerMinute * seconds / 60m);
        // Cut in stage 8: State.Propolis = Snap(State.Propolis + ResinPropolisPerMinute * seconds / 60m);
        if (!State.PropolisRevealed && State.Propolis >= 1m)
        {
            State.PropolisRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.FirstPropolis));
        }
        State.Wood = Snap(State.Wood + WoodPerMinuteNow * seconds / 60m);
        if (!State.WoodRevealed && State.Wood >= 1m) State.WoodRevealed = true;

        // Cut in stage 6 (spec 014): plants attracted forager and guard bees, and pollen was the
        // area under the growing forager line.
        // decimal foragersPerMinute = 0m, guardsPerMinute = 0m;
        // foreach (var p in SproutedPlants)
        // {
        //     if (p.Bee == BeekeeperBees.Forager) foragersPerMinute += p.BeesPerMinute;
        //     else if (p.Bee == BeekeeperBees.Guard) guardsPerMinute += p.BeesPerMinute;
        // }
        // State.Pollen += (State.ForagerBees * seconds * 120m + foragersPerMinute * seconds * seconds)
        //                 / (Config.ForagersPerPollenPerMinute * 60m * 120m);
        // State.ForagerBees += foragersPerMinute * seconds / 60m;
        // State.GuardBees += guardsPerMinute * seconds / 60m;

        if (!State.PollenRevealed && State.Pollen >= 1m)
        {
            State.PollenRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.FirstPollen));
        }
    }

    public bool CanMakeBeeBreadTimes(int count) =>
        count >= 1 && State.PollenRevealed
        && State.Pollen >= Config.BeeBreadPollen * count && State.Honey >= Config.BeeBreadHoney * count;

    public bool CanMakeBeeBread => CanMakeBeeBreadTimes(1);

    /// <summary>Crafting is instant: pollen and honey make bee bread, one or a batch.</summary>
    public ActionResult MakeBeeBread(int count = 1)
    {
        if (!CanMakeBeeBreadTimes(count)) return ActionResult.Refused;
        State.Pollen -= Config.BeeBreadPollen * count;
        State.Honey -= Config.BeeBreadHoney * count;
        State.BeeBread += count;
        RefreshStorageFlag();
        var events = new List<BeekeeperEvent>();
        if (count > 1) events.Add(new BeekeeperEvent(BeekeeperEvents.Crafted, count, "bee_bread"));
        if (!State.BeeBreadRevealed)
        {
            State.BeeBreadRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.BeeBreadMade));
        }
        CraftCardDone(BeekeeperStories.BeeBread);
        // Cut (Bee, 2026-11-12): the first bee bread brought the queen; now the wooden hive does.
        // SettleQueenIfDue(events);
        NoteBeeBreadAdded(events);
        CheckWalls(events);   // the wooden hive is offered now, and may be a wall
        return new ActionResult(true, count, events);
    }

    /// <summary>The Hive card offers the move once the player has first made bee bread.</summary>
    public bool WoodenHiveOffered => State.BeeBreadRevealed && !State.HasWoodenHive;

    public bool CanMoveToWoodenHive =>
        WoodenHiveOffered && State.Wax >= Config.WoodenHiveWax && State.BeeBread >= Config.WoodenHiveBeeBread;

    public ActionResult MoveToWoodenHive()
    {
        if (!CanMoveToWoodenHive) return ActionResult.Refused;
        State.Wax -= Config.WoodenHiveWax;
        State.BeeBread -= Config.WoodenHiveBeeBread;
        State.HasWoodenHive = true;
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.WoodenHive) };
        SettleQueenIfDue(events);
        return new ActionResult(true, 1m, events);
    }

    // ------------------------------------------------------------------ debug

    // Cut in stage 8 (spec 017, FR-817): "Give seed", "Give every seed" and "Finish growing" handed
    // over seeds given once each and sprouted the beds. Now: unlock the next seed / every seed.
    // private bool SeedNotYetGiven(BeekeeperPlant p) =>
    //     !State.SeedsGivenIds.Contains(p.Id) && !State.Plants.Contains(p.Id)
    //     && !State.SeedsInHand.Contains(p.Id) && !State.Beds.Any(b => b.PlantId == p.Id);
    // public IReadOnlyList<BeekeeperEvent> DebugGiveSeed() { ... GiveSeed(next, ...) ... }
    // public IReadOnlyList<BeekeeperEvent> DebugGiveEverySeed() { ... GiveSeed(plant, ...) ... }
    // public IReadOnlyList<BeekeeperEvent> DebugFinishGrowing() { ... Sprout(bed, events) ... }

    /// <summary>Debug builds only: the next seed (in config order) not yet in a roll joins its roll now.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugUnlockNextSeed()
    {
        var events = new List<BeekeeperEvent>();
        if (Config.Plants.FirstOrDefault(p => !IsSeedUnlocked(p)) is { } next) DebugUnlock(next, events);
        return events;
    }

    /// <summary>Debug builds only: every seed joins its roll now.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugUnlockEverySeed()
    {
        var events = new List<BeekeeperEvent>();
        foreach (var plant in Config.Plants.Where(p => !IsSeedUnlocked(p)).ToList()) DebugUnlock(plant, events);
        return events;
    }

    private void DebugUnlock(BeekeeperPlant plant, List<BeekeeperEvent> events)
    {
        State.SeedsGivenIds.Add(plant.Id);
        // Cut (Bee, 2026-11-11): events.Add(new BeekeeperEvent(BeekeeperEvents.SeedJoinsRoll, 0m, plant.Id));
    }

    /// <summary>Debug builds only: <paramref name="count"/> seeds of every kind in hand.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugGiveSeedsOfEvery(int count)
    {
        foreach (var plant in Config.Plants) AddSeedsInHand(plant.Id, count);
        return Array.Empty<BeekeeperEvent>();
    }

    /// <summary>Debug builds only: plants of the given kind go straight into the garden (the meadow's plants).</summary>
    public IReadOnlyList<BeekeeperEvent> DebugPlant(string plantId, int count)
    {
        var events = new List<BeekeeperEvent>();
        if (PlantById(plantId) is null || count <= 0) return events;
        if (!State.Plants.Contains(plantId)) events.Add(new BeekeeperEvent(BeekeeperEvents.PlantRevealed, 0m, plantId));
        for (int i = 0; i < count; i++) State.Plants.Add(plantId);
        State.GardenRevealed = true;
        StartCalendarIfDue(events);   // stage 9
        SummonCarpenterBeeIfDue(events);
        CheckWalls(events);
        return events;
    }

    /// <summary>Debug builds only: hands out wood.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugGiveWood(decimal wood)
    {
        if (wood > 0m)
        {
            State.Wood += wood;
            State.WoodRevealed = true;
        }
        return Array.Empty<BeekeeperEvent>();
    }

    /// <summary>Debug builds only: the carpenter bee comes now, willow or not.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugSummonCarpenterBee()
    {
        if (State.CarpenterBeeCame) return Array.Empty<BeekeeperEvent>();
        State.CarpenterBeeCame = true;
        return new[] { new BeekeeperEvent(BeekeeperEvents.CarpenterBee) };
    }

    /// <summary>Debug builds only: a bee hotel gift now (the hotel must be owned; its timer is untouched).</summary>
    public IReadOnlyList<BeekeeperEvent> DebugHotelGift()
    {
        var events = new List<BeekeeperEvent>();
        if (HasBeeHotel) GiveHotelGift(events);
        return events;
    }

    /// <summary>Debug builds only: hands out propolis.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugGivePropolis(decimal propolis)
    {
        var events = new List<BeekeeperEvent>();
        if (propolis <= 0m) return events;
        State.Propolis += propolis;
        if (!State.PropolisRevealed)
        {
            State.PropolisRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.FirstPropolis));
        }
        return events;
    }

    /// <summary>Debug builds only: hands out paper.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugGivePaper(decimal paper)
    {
        var events = new List<BeekeeperEvent>();
        if (paper <= 0m) return events;
        State.Paper += paper;
        State.PaperRevealed = true;
        return events;
    }

    /// <summary>Debug builds only: the Hippie trade count goes up to 199 (one short of the willow
    /// seed), the Hippies arrive if they hadn't and ten candles are put on the shelf for the trade.
    /// Seeds already due at that count are given.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugHippieTradesTo199()
    {
        var events = new List<BeekeeperEvent>();
        if (!State.HippiesRevealed)
        {
            State.HippiesRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.HippiesArrive));
        }
        State.HippieTrades = Math.Max(State.HippieTrades, 199);
        // Stage 10: beeswax candles for one jar (was one herbal candle for the trade).
        if (State.BeeswaxCandles < Config.CandlesPerJar) State.BeeswaxCandles = Config.CandlesPerJar;
        // Cut (Bee, 2026-11-12): if (State.RepellentCandles < 1m) State.RepellentCandles = 1m;
        UnlockSeedsIfDue(events);   // was GiveSeedsIfDue before stage 8
        return events;
    }

    /// <summary>Debug builds only (stage 10): hands out clay jars.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugGiveClayJars(decimal jars)
    {
        if (jars > 0m) State.ClayJars += jars;
        return Array.Empty<BeekeeperEvent>();
    }

    /// <summary>Debug builds only (stage 10): hands out potted honey (its row and the bear's buttons show).</summary>
    public IReadOnlyList<BeekeeperEvent> DebugGivePottedHoney(decimal pots)
    {
        var events = new List<BeekeeperEvent>();
        if (pots <= 0m) return events;
        State.PottedHoney += pots;
        if (!State.PottedHoneyRevealed)
        {
            State.PottedHoneyRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.HoneyPotted, pots));
        }
        return events;
    }

    /// <summary>Debug builds only (stage 10): beeswax candles on the shelf (not counted as crafted).</summary>
    public IReadOnlyList<BeekeeperEvent> DebugGiveBeeswaxCandles(decimal candles)
    {
        if (candles > 0m) State.BeeswaxCandles += candles;
        return Array.Empty<BeekeeperEvent>();
    }

    /// <summary>Debug builds only: hands out pollen.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugGivePollen(decimal pollen)
    {
        var events = new List<BeekeeperEvent>();
        State.Pollen += pollen;
        if (!State.PollenRevealed && State.Pollen >= 1m)
        {
            State.PollenRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.FirstPollen));
        }
        return events;
    }

    /// <summary>Debug builds only: hands out bee bread (a resting queen starts again).</summary>
    public IReadOnlyList<BeekeeperEvent> DebugGiveBeeBread(decimal beeBread)
    {
        var events = new List<BeekeeperEvent>();
        if (beeBread <= 0m) return events;
        State.BeeBread += beeBread;
        State.BeeBreadRevealed = true;
        NoteBeeBreadAdded(events);
        return events;
    }

    /// <summary>Debug builds only: the bear count goes up to one short of the trade agreement,
    /// so the next sale brings it. Brings the bear if he hasn't come yet.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugBearTradesToAlmostAgreement()
    {
        var events = new List<BeekeeperEvent>();
        if (!State.BearRevealed)
        {
            State.BearRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.BearArrives, 0m, State.BearName));
        }
        State.Trades = Math.Max(State.Trades, Config.AgreementTrades - 1);
        return events;
    }

    /// <summary>Debug builds only: the bribe count goes up to one short of the emissary, so the
    /// next bribe brings it.</summary>
    public void DebugBribesToAlmostEmissary() =>
        State.BribesTotal = Math.Max(State.BribesTotal, Config.BribesForEmissary - 1);

    /// <summary>Debug builds only: the emissary comes now.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugBringEmissary()
    {
        var events = new List<BeekeeperEvent>();
        State.BribesTotal = Math.Max(State.BribesTotal, Config.BribesForEmissary);
        SendEmissaryIfDue(events);
        return events;
    }

    /// <summary>Debug builds only: hands out honey (it may go over the combs' room).</summary>
    public IReadOnlyList<BeekeeperEvent> DebugGiveHoney(decimal honey)
    {
        var events = new List<BeekeeperEvent>();
        if (honey <= 0m) return events;
        State.Honey += honey;
        if (!State.HoneyRevealed)
        {
            State.HoneyRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.FirstBee));
        }
        CheckReveals(events);
        return events;
    }

    /// <summary>
    /// Debug builds only (the Banners menu): hands out bees, wax and Beebits so later stages
    /// can be reached without hours of play. The game itself never calls this.
    /// </summary>
    public IReadOnlyList<BeekeeperEvent> DebugGrant(decimal bees, decimal wax, decimal beebits)
    {
        var events = new List<BeekeeperEvent>();
        if (bees > 0m)
        {
            State.Bees = Math.Min(Config.MaxBees, State.Bees + bees);
            if (!State.HoneyRevealed)
            {
                State.HoneyRevealed = true;
                events.Add(new BeekeeperEvent(BeekeeperEvents.FirstBee));
            }
        }
        if (wax > 0m)
        {
            State.Wax += wax;
            if (!State.WaxRevealed)
            {
                State.WaxRevealed = true;
                events.Add(new BeekeeperEvent(BeekeeperEvents.FirstWax));
            }
        }
        if (beebits > 0m)
        {
            State.Beebits += beebits;
            State.BeebitsRevealed = true;
        }
        CheckReveals(events);
        return events;
    }

    /// <summary>Debug builds only (stage 7.5): <paramref name="count"/> more combs, free of charge.
    /// The Combs panel shows, and The Workbench opens if this reaches it.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugAddCombs(int count)
    {
        var events = new List<BeekeeperEvent>();
        if (count <= 0) return events;
        State.Combs += count;
        State.CombsRevealed = true;
        RefreshStorageFlag();
        OpenWorkbenchIfDue(events);
        CheckReveals(events);
        return events;
    }

    /// <summary>Debug builds only (stage 7.5): wax up to the wax cap (never down).</summary>
    public IReadOnlyList<BeekeeperEvent> DebugFillWax()
    {
        var events = new List<BeekeeperEvent>();
        State.Wax = Math.Max(State.Wax, WaxStorage);
        if (!State.WaxRevealed)
        {
            State.WaxRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.FirstWax));
        }
        CheckReveals(events);
        return events;
    }

    // ------------------------------------------------------------------ reveals

    private void CheckReveals(List<BeekeeperEvent> events)
    {
        if (!State.BearRevealed && State.BeesCaught >= Config.BearRevealBees)
        {
            State.BearRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.BearArrives, 0m, State.BearName));
        }
        // Bee, 2026-11-11: the Shop opens with the first comb built. Was: State.Beebits >= Config.ShopRevealBeebits.
        if (!State.ShopRevealed && CombsBought >= Config.ShopRevealCombsBought)
        {
            State.ShopRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.ShopOpened));
        }
        if (!State.CombsRevealed && State.Wax >= Config.CombsRevealWax)
        {
            State.CombsRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.CombsAvailable));
        }
        CheckWalls(events);
    }

    /// <summary>Lets "the combs are full" and "no more room for wax" be announced again once there
    /// is room again (stage 7.5: both caps).</summary>
    private void RefreshStorageFlag()
    {
        if (!IsStorageFull) State.StorageFullAnnounced = false;
        if (!IsWaxFull) State.WaxFullAnnounced = false;
    }
}
