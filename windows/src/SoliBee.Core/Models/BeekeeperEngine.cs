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
    public const string Sale = "sale";                     // Value = Beebits earned, Value2 = honey given, Text = bear name
    public const string ShopOpened = "shop_opened";
    public const string ToolBought = "tool_bought";        // Value = new tool level, Text = tool id
    public const string WaxCatcherBought = "wax_catcher_bought";
    public const string CombsAvailable = "combs_available";
    public const string CombBuilt = "comb_built";          // Value = storage added
    public const string WelcomeBack = "welcome_back";      // Value = honey made while away
    public const string WelcomeBackNothing = "welcome_back_nothing";

    // Stage 2
    public const string WorkbenchOpened = "workbench_opened";
    public const string FirstBeeswaxCandle = "first_beeswax_candle";
    public const string HippiesArrive = "hippies_arrive";
    public const string CandlesTraded = "candles_traded";    // Value = sage received, Value2 = candles given
    public const string RepellentUnlocked = "repellent_unlocked";
    public const string UpgradeBought = "upgrade_bought";    // Text = upgrade id
    public const string WaspArrives = "wasp_arrives";
    public const string ShoeHit = "shoe_hit";
    // Value = honey taken. Before stage 6, Value2 = bees flown off (Text = "guards" when guards kept them safe).
    public const string ShoeMissRaid = "shoe_miss_raid";
    public const string WaspRaid = "wasp_raid";
    public const string Bribe = "bribe";                     // Value = honey paid
    public const string WaspLeft = "wasp_left";              // the player stepped away; nothing lost
    public const string CandleLit = "candle_lit";
    public const string CandleOut = "candle_out";

    // Stage 3
    public const string SmokerPuffed = "smoker_puffed";
    public const string CalmEnded = "calm_ended";

    // Stage 4
    public const string SeedGiven = "seed_given";              // Value = seeds in hand; since stage 7 Text = plant id (from the Hippies)
    public const string SeedPlanted = "seed_planted";          // since stage 7 Text = plant id
    public const string SeedSprouted = "seed_sprouted";
    public const string PlantRevealed = "plant_revealed";      // Text = plant id
    public const string FirstPollen = "first_pollen";
    public const string BeeBreadMade = "bee_bread_made";       // first time only
    public const string WoodenHive = "wooden_hive";
    public const string Crafted = "crafted";                   // a batch of more than one: Value = how many, Text = beeswax | repellent | bee_bread

    // Stage 5
    public const string QueenSettles = "queen_settles";
    public const string PantryEmpty = "pantry_empty";          // live play only; away says WelcomeBackPantry
    public const string QueenResumes = "queen_resumes";
    public const string TradeAgreement = "trade_agreement";    // Text = bear name
    public const string WelcomeBackQueen = "welcome_back_queen";   // Value = bees raised while away
    public const string WelcomeBackBear = "welcome_back_bear";     // Value = Beebits from the agreement, Text = bear name
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

    /// <summary>The lines that only reopening the app shows ("While you were away…").</summary>
    public static bool IsWelcomeBack(string key) =>
        key is WelcomeBack or WelcomeBackNothing or WelcomeBackQueen or WelcomeBackBear or WelcomeBackPantry
            or WelcomeBackPropolis or WelcomeBackSageOut;
}

public readonly record struct BeekeeperEvent(string Key, decimal Value = 0m, string? Text = null, decimal Value2 = 0m);

public sealed record CatchResult(bool Stung, decimal BeesGained, IReadOnlyList<BeekeeperEvent> Events);

/// <summary><see cref="BeesRaised"/>: bees the queen raised; <see cref="AgreementBeebits"/>:
/// whole Beebits the bear paid for honey that didn't fit.</summary>
public sealed record AdvanceResult(decimal HoneyStored, decimal WaxMade, IReadOnlyList<BeekeeperEvent> Events,
    decimal BeesRaised = 0m, decimal AgreementBeebits = 0m);

public sealed record AwayResult(decimal CreditedSeconds, decimal HoneyStored, decimal WaxMade, IReadOnlyList<BeekeeperEvent> Events,
    decimal BeesRaised = 0m, decimal AgreementBeebits = 0m, bool PantryEmptied = false);

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

    public BeekeeperConfig Config { get; }
    public BeekeeperState State { get; private set; }

    public BeekeeperEngine(BeekeeperConfig? config = null, BeekeeperState? state = null, IRandomSource? rng = null)
    {
        Config = config ?? BeekeeperConfig.Default;
        _rng = rng ?? new SystemRandomSource();
        State = state ?? NewState();
        if (state is not null)
        {
            if (state.Version < 7) ConvertOldSeeds(state);
            Tidy(state);
        }
    }

    /// <summary>A file older than version 7 counted seeds; seed N was plant N (spec 015, FR-609).
    /// The sprouted plants are already in the list; the growing seed (if any) goes into bed 1 with its
    /// time left, the seeds in hand become named, and every seed given counts as given.</summary>
    private void ConvertOldSeeds(BeekeeperState s)
    {
        var plants = Config.Plants;
        for (int i = 0; i < s.SeedsGiven && i < plants.Count; i++)
        {
            if (!s.SeedsGivenIds.Contains(plants[i].Id)) s.SeedsGivenIds.Add(plants[i].Id);
            if (i >= s.SeedsPlanted && !s.SeedsInHand.Contains(plants[i].Id)) s.SeedsInHand.Add(plants[i].Id);
        }
        if (s.GrowSecondsLeft > 0m && s.SeedsPlanted >= 1 && s.SeedsPlanted <= plants.Count && s.Beds.Count == 0)
        {
            var growing = plants[s.SeedsPlanted - 1];
            s.Beds.Add(new BeekeeperBed { PlantId = growing.Id, SecondsLeft = s.GrowSecondsLeft });
            if (!s.SeedsGivenIds.Contains(growing.Id)) s.SeedsGivenIds.Add(growing.Id);
        }
        if (s.SeedsGiven > 0 || s.SeedsPlanted > 0) s.GardenRevealed = true;
        s.Version = 7;
    }

    /// <summary>Sanity for a loaded file: unknown plant ids dropped, no more beds than owned.</summary>
    private void Tidy(BeekeeperState s)
    {
        bool Known(string id) => Config.Plants.Any(p => p.Id == id);
        s.SeedsInHand.RemoveAll(id => !Known(id));
        s.SeedsGivenIds.RemoveAll(id => !Known(id));
        s.Beds.RemoveAll(b => !Known(b.PlantId));
        int owned = Config.StartingBeds + (s.Upgrades.Contains(BeekeeperUpgrades.ThirdBed) ? Config.ThirdBedBeds : 0);
        if (s.Beds.Count > owned) s.Beds.RemoveRange(owned, s.Beds.Count - owned);
    }

    private BeekeeperState NewState() => new() { BearName = PickBearName() };

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

    /// <summary>All honey storage (starting room plus combs), grown by the Bigger Combs upgrades.</summary>
    public decimal HoneyStorage =>
        (Config.StartingStorage + State.Combs * Config.StoragePerComb) * StorageMultiplier;

    /// <summary>Honey storage one comb adds right now.</summary>
    public decimal StoragePerComb => Config.StoragePerComb * StorageMultiplier;

    private decimal StorageMultiplier =>
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

    /// <summary>Everything one successful click catches: the tool's bees plus a slice of the
    /// hive (0.1%, rounded down; Practice doesn't grow the slice), the slice capped at 10 × the
    /// tool's bees (spec 013, FR-405). The one place this is worked out, so the catch, the popup
    /// and the tool line agree.</summary>
    public decimal BeesPerCatch => BeesPerClick + Math.Min(Math.Floor(State.Bees * Config.CatchSliceShare), SliceCap);

    /// <summary>The most bees the slice can bring in on one click.</summary>
    public decimal SliceCap => Math.Floor(BeesPerClick * Config.SliceCapMultiple);

    /// <summary>The colony's base rate. Raids and the like use this, never the calm boost.</summary>
    public decimal HoneyPerSecond => State.Bees * Config.HoneyPerBeePerSecond * HiveMultiplier;

    /// <summary>Lasting boosts to every honeybee's honey: the wooden hive and guarding ("the hive
    /// feels safe"), multiplied together. Everything that reads honey per second (production, the
    /// queen's growing hive, raids, hover rates, the trade agreement) sees it, live and away alike.</summary>
    public decimal HiveMultiplier => (State.HasWoodenHive ? Config.WoodenHiveHoneyMultiplier : 1m) * GuardingMultiplier;

    /// <summary>What the hive makes right now: the base rate with whichever boosts are on (calm
    /// bees, a bee-boost candle, a sage-propolis candle).</summary>
    public decimal HoneyPerSecondNow => HoneyPerSecond * LiveBoostNow * SagePropolisBoostNow;

    /// <summary>The boosts that only work while the app is open, multiplied: calm bees and a
    /// bee-boost candle (stage 7). Time away never has them.</summary>
    public decimal LiveBoostNow =>
        (IsCalm ? Config.CalmHoneyMultiplier : 1m) * (IsBeeBoosted ? Config.BeeBoostHoneyMultiplier : 1m);

    /// <summary>The sage-propolis candle's boost, on while it burns, live or away.</summary>
    public decimal SagePropolisBoostNow => IsSagePropolisBurning ? Config.SagePropolisHoneyMultiplier : 1m;

    /// <summary>Wax the hive makes right now: follows all honey made (full combs or not),
    /// with the Wax-Catcher, its upgrade and calm bees counted.</summary>
    public decimal WaxPerSecondNow => HoneyPerSecondNow / Config.HoneyPerWax * WaxPerBatch;

    /// <summary>Wax per 50 honey: 1, 2 with the Wax-Catcher, 3 with the Better Wax-Catcher.</summary>
    public decimal WaxPerBatch =>
        !State.HasWaxCatcher ? 1m
        : Owns(BeekeeperUpgrades.BetterWaxCatcher) ? Config.WaxCatcherMultiplier * Config.BetterWaxCatcherBonus
        : Config.WaxCatcherMultiplier;

    public bool Owns(string upgradeId) => State.Upgrades.Contains(upgradeId);

    /// <summary>floor(50 × 1.25^N) where N = combs already built.</summary>
    public decimal CombCost
    {
        get
        {
            try
            {
                decimal cost = Config.CombBaseWaxCost;
                for (int i = 0; i < State.Combs; i++) cost *= Config.CombCostGrowth;
                return Math.Floor(cost);
            }
            catch (OverflowException)
            {
                return decimal.MaxValue; // effectively unbuyable
            }
        }
    }

    /// <summary>The next tool in the shop, or null when the Vacuum is owned.</summary>
    public BeekeeperTool? NextTool =>
        State.ToolLevel < Config.Tools.Count ? Config.Tools[State.ToolLevel] : null;

    public bool CanSell => State.Honey >= Config.HoneyPerBeebit;

    public bool CanBuyNextTool => NextTool is { } t && State.ShopRevealed && State.Beebits >= t.Cost;

    public bool CanBuyWaxCatcher =>
        !State.HasWaxCatcher && State.ShopRevealed && State.Beebits >= Config.WaxCatcherCost;

    public bool CanBuildComb => State.Wax >= CombCost;

    /// <summary>A gap longer than the threshold counts as time away.</summary>
    public bool IsAway(decimal gapSeconds) => gapSeconds > Config.AwayThresholdSeconds;

    // ------------------------------------------------------------------ catching

    public CatchResult Catch()
    {
        var events = new List<BeekeeperEvent>();

        // Every click calms the bees a little once the Smoker is owned, stings included.
        if (Owns(BeekeeperUpgrades.Smoker) && State.CalmMeter < Config.CalmMeterClicks) State.CalmMeter++;

        // While the bees are calm, every click tops the calm time back up: a perk for staying active.
        if (IsCalm)
            State.CalmSecondsLeft = Math.Min(Config.CalmSeconds, State.CalmSecondsLeft + Config.CalmCatchRefillSeconds);

        // Only Bare Hands ever get stung; better tools never roll the dice.
        if (State.ToolLevel == 0 && _rng.NextDouble() < Config.StingChance)
        {
            events.Add(new BeekeeperEvent(BeekeeperEvents.Sting));
            return new CatchResult(true, 0m, events);
        }

        decimal gained = BeesPerCatch;
        State.Bees = Math.Min(Config.MaxBees, State.Bees + gained);
        if (!State.HoneyRevealed)
        {
            State.HoneyRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.FirstBee));
        }
        return new CatchResult(false, gained, events);
    }

    // ------------------------------------------------------------------ time passing

    /// <summary>Normal play: the hive works for <paramref name="seconds"/>. Calm bees (after a
    /// puff of the Smoker) make double honey, and only live play uses up calm time.</summary>
    public AdvanceResult Advance(decimal seconds)
    {
        var events = new List<BeekeeperEvent>();
        // Cut in stage 7 (spec 015): one calm part then the rest. Now the stretch is split at
        // whichever live boost (calm, bee-boost candle) ends first, again and again (FR-604).
        // decimal calm = seconds > 0m ? Math.Min(seconds, State.CalmSecondsLeft) : 0m;
        // var a = Work(calm, events, Config.CalmHoneyMultiplier);
        // var b = Work(seconds - calm, events);
        Made total = default;
        decimal left = seconds;
        if (left <= 0m) total = Work(left, events);
        while (left > 0m)
        {
            bool calm = State.CalmSecondsLeft > 0m, beeBoost = State.BeeBoostSecondsLeft > 0m;
            decimal step = left;
            if (calm) step = Math.Min(step, State.CalmSecondsLeft);
            if (beeBoost) step = Math.Min(step, State.BeeBoostSecondsLeft);
            total += Work(step, events, LiveBoostNow);   // the hive goes on growing across the parts (FR-402)
            left -= step;
            if (calm)
            {
                State.CalmSecondsLeft -= step;
                if (State.CalmSecondsLeft <= 0m) { State.CalmSecondsLeft = 0m; events.Add(new BeekeeperEvent(BeekeeperEvents.CalmEnded)); }
            }
            if (beeBoost)
            {
                State.BeeBoostSecondsLeft -= step;
                if (State.BeeBoostSecondsLeft <= 0m) { State.BeeBoostSecondsLeft = 0m; events.Add(new BeekeeperEvent(BeekeeperEvents.BeeBoostOut)); }
            }
        }
        return new AdvanceResult(total.Stored, total.Wax, events, total.Raised, total.AgreementBeebits);
    }

    // ------------------------------------------------------------------ the Smoker (stage 3)

    public bool IsCalm => State.CalmSecondsLeft > 0m;

    public bool CanPuff =>
        Owns(BeekeeperUpgrades.Smoker) && State.CalmMeter >= Config.CalmMeterClicks && !IsCalm;

    /// <summary>A full meter, puffed by hand: the bees are calm (double honey) for a while.</summary>
    public ActionResult PuffSmoker()
    {
        if (!CanPuff) return ActionResult.Refused;
        State.CalmMeter = 0;
        State.CalmSecondsLeft = Config.CalmSeconds;
        return new ActionResult(true, Config.CalmSeconds, new[] { new BeekeeperEvent(BeekeeperEvents.SmokerPuffed) });
    }

    /// <summary>Debug builds only: fills the calm meter.</summary>
    public void DebugFillCalmMeter() => State.CalmMeter = Config.CalmMeterClicks;

    /// <summary>
    /// Time away: the same maths as <see cref="Advance"/> in one step, capped at 3 days,
    /// paid at the offline rate, ignored if negative. Storage still limits the honey.
    /// </summary>
    public AwayResult AdvanceAway(decimal gapSeconds)
    {
        var events = new List<BeekeeperEvent>();
        if (gapSeconds <= 0m) return new AwayResult(0m, 0m, 0m, events);

        decimal credited = Math.Min(gapSeconds, Config.OfflineCapSeconds);
        decimal propolisBefore = State.Propolis;
        var m = Work(credited * Config.OfflineRate, events);   // the bee-boost candle waits: no live boost here

        // An empty pantry while away is told in the welcome-back lines instead (and so is a
        // sage-propolis candle burning down).
        if (m.PantryEmptied) events.RemoveAll(e => e.Key == BeekeeperEvents.PantryEmpty);
        bool sageOut = events.RemoveAll(e => e.Key == BeekeeperEvents.SagePropolisOut) > 0;

        if (State.Bees > 0m)
        {
            // The log shows the newest line first, so these are added bottom line first:
            // they then read "the bees made…", "the queen raised…", "propolis…", "the bear left…",
            // "the pantry…", "the candle…".
            if (sageOut) events.Add(new BeekeeperEvent(BeekeeperEvents.WelcomeBackSageOut));
            if (m.PantryEmptied) events.Add(new BeekeeperEvent(BeekeeperEvents.WelcomeBackPantry));
            if (m.AgreementBeebits > 0m)
                events.Add(new BeekeeperEvent(BeekeeperEvents.WelcomeBackBear, m.AgreementBeebits, State.BearName));
            decimal gathered = Math.Floor(State.Propolis - propolisBefore);
            if (gathered > 0m) events.Add(new BeekeeperEvent(BeekeeperEvents.WelcomeBackPropolis, gathered));
            decimal raised = Math.Floor(m.Raised);
            if (raised > 0m) events.Add(new BeekeeperEvent(BeekeeperEvents.WelcomeBackQueen, raised));
            // Honey that found a home: stored, or taken by the bear under the agreement.
            decimal honey = m.Stored + m.Taken;
            events.Add(honey > 0m
                ? new BeekeeperEvent(BeekeeperEvents.WelcomeBack, honey)
                : new BeekeeperEvent(BeekeeperEvents.WelcomeBackNothing));
        }
        return new AwayResult(credited, m.Stored, m.Wax, events, m.Raised, m.AgreementBeebits, m.PantryEmptied);
    }

    /// <summary>What one stretch made. <see cref="Taken"/> is the overflow honey the bear took.</summary>
    private readonly record struct Made(decimal Stored, decimal Wax, decimal Raised, decimal Taken,
                                        decimal AgreementBeebits, bool PantryEmptied)
    {
        public static Made operator +(Made x, Made y) => new(x.Stored + y.Stored, x.Wax + y.Wax, x.Raised + y.Raised,
            x.Taken + y.Taken, x.AgreementBeebits + y.AgreementBeebits, x.PantryEmptied || y.PantryEmptied);
    }

    /// <summary>
    /// The hive and the garden work for <paramref name="seconds"/>. If the growing seed sprouts
    /// part-way, the stretch is split there, so a new specialty (guarding's honey, foraging's
    /// pollen) only counts from the moment it sprouts, the same live and away (spec 014, FR-503).
    /// </summary>
    private Made Work(decimal seconds, List<BeekeeperEvent> events, decimal boost = 1m)
    {
        if (seconds <= 0m) return Produce(seconds, events, boost);

        // Cut in stage 7 (spec 015): the stretch was split once, at the one growing seed's sprout.
        // decimal before = IsGrowing ? Math.Min(seconds, State.GrowSecondsLeft) : seconds;
        // var made = Produce(before, events, boost);
        // GrowGarden(before, events);
        // decimal after = seconds - before;
        // if (after > 0m) { made += Produce(after, events, boost); GrowGarden(after, events); }
        // return made;

        // Now it is split at every change, soonest first (FR-603): each bed's sprout and the
        // sage-propolis candle burning out. Between splits nothing changes, so every piece is
        // exact and many short stretches equal one long one, live or away.
        Made made = default;
        decimal left = seconds;
        while (left > 0m)
        {
            decimal step = left;
            foreach (var bed in State.Beds) step = Math.Min(step, bed.SecondsLeft);
            if (State.SagePropolisSecondsLeft > 0m) step = Math.Min(step, State.SagePropolisSecondsLeft);

            made += Produce(step, events, boost);
            Attract(step, events);
            left -= step;

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
            GrowBeds(step, events);
        }
        return made;
    }

    /// <summary>Beds grow for <paramref name="step"/> seconds; those that reach zero sprout.</summary>
    private void GrowBeds(decimal step, List<BeekeeperEvent> events)
    {
        foreach (var bed in State.Beds.ToList())
        {
            bed.SecondsLeft -= step;
            if (bed.SecondsLeft <= 0m) Sprout(bed, events);
        }
    }

    private void Sprout(BeekeeperBed bed, List<BeekeeperEvent> events)
    {
        State.Beds.Remove(bed);
        State.Plants.Add(bed.PlantId);
        events.Add(new BeekeeperEvent(BeekeeperEvents.SeedSprouted, 0m, bed.PlantId));
        events.Add(new BeekeeperEvent(BeekeeperEvents.PlantRevealed, 0m, bed.PlantId));
    }

    /// <summary>
    /// The hive works for <paramref name="seconds"/> in one exact step, so many short stretches
    /// add up to one long one (FR-402, FR-403). While the queen lays, the bees grow in a straight
    /// line, so the honey is the area under that line; the stretch is split where the pantry runs
    /// out (growth before, flat after). Honey beyond the room left overflows: the bear buys it
    /// under the trade agreement, otherwise it is lost. Wax follows all honey made.
    /// </summary>
    private Made Produce(decimal seconds, List<BeekeeperEvent> events, decimal boost = 1m)
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
            if (wouldRaise >= canFeed)
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

        State.Bees = Math.Min(Config.MaxBees, State.Bees + raised);
        if (perMinute > 0m)
            State.BeeBread = emptied ? 0m : Math.Max(0m, State.BeeBread - raised / Config.BeesPerBeeBread);
        if (emptied && !State.PantryEmptyAnnounced)
        {
            State.PantryEmptyAnnounced = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.PantryEmpty));
        }

        if (beeSeconds <= 0m) return new Made(0m, 0m, raised, 0m, 0m, emptied);

        decimal made = beeSeconds * Config.HoneyPerBeePerSecond * boost * SagePropolisBoostNow * HiveMultiplier;
        decimal room = Math.Max(0m, HoneyStorage - State.Honey);
        decimal stored = Math.Min(made, room);
        State.Honey += stored;

        if (made > room && !State.StorageFullAnnounced)
        {
            State.StorageFullAnnounced = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.StorageFull));
        }

        // The trade agreement: the bear takes the overflow at half price, fractions kept (FR-404).
        decimal taken = 0m, agreementBeebits = 0m;
        if (State.HasTradeAgreement && made > stored)
        {
            taken = made - stored;
            State.AgreementHoneyProgress += taken;
            agreementBeebits = Math.Floor(State.AgreementHoneyProgress / Config.AgreementHoneyPerBeebit);
            if (agreementBeebits > 0m)
            {
                State.AgreementHoneyProgress -= agreementBeebits * Config.AgreementHoneyPerBeebit;
                State.Beebits += agreementBeebits;
                State.BeebitsRevealed = true;
            }
        }

        // Wax follows all the honey the bees make, so it keeps coming when the combs are
        // full (Leah, 2026-11-07). Selling honey never touches it.
        decimal waxMade = 0m;
        State.WaxProgress += made;
        decimal batches = Math.Floor(State.WaxProgress / Config.HoneyPerWax);
        if (batches > 0m)
        {
            State.WaxProgress -= batches * Config.HoneyPerWax;
            waxMade = batches * WaxPerBatch;
            State.Wax += waxMade;
            if (!State.WaxRevealed)
            {
                State.WaxRevealed = true;
                events.Add(new BeekeeperEvent(BeekeeperEvents.FirstWax));
            }
        }

        CheckReveals(events);
        return new Made(stored, waxMade, raised, taken, agreementBeebits, emptied);
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

    /// <summary>Beebits a second the agreement brings while the combs are full.</summary>
    public decimal AgreementBeebitsPerSecondNow =>
        State.HasTradeAgreement && State.Honey >= HoneyStorage ? HoneyPerSecondNow / Config.AgreementHoneyPerBeebit : 0m;

    private void OfferAgreementIfDue(List<BeekeeperEvent> events)
    {
        if (State.HasTradeAgreement || State.Trades < Config.AgreementTrades) return;
        State.HasTradeAgreement = true;
        events.Add(new BeekeeperEvent(BeekeeperEvents.TradeAgreement, 0m, State.BearName));
    }

    // ------------------------------------------------------------------ the bear

    /// <summary>Sell exactly one bundle (10 honey for 1 Beebit).</summary>
    public ActionResult SellTen() => Sell(all: false);

    /// <summary>Sell as many whole bundles as possible; the remainder stays. Counts as one trade.</summary>
    public ActionResult SellAll() => Sell(all: true);

    private ActionResult Sell(bool all)
    {
        if (!CanSell) return ActionResult.Refused;

        decimal bundles = all ? Math.Floor(State.Honey / Config.HoneyPerBeebit) : 1m;
        State.Honey -= bundles * Config.HoneyPerBeebit;
        State.Beebits += bundles;
        State.Trades++;
        State.BeebitsRevealed = true;
        RefreshStorageFlag();

        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.Sale, bundles, State.BearName, bundles * Config.HoneyPerBeebit) };
        OfferAgreementIfDue(events);
        CheckReveals(events);
        return new ActionResult(true, bundles, events);
    }

    // ------------------------------------------------------------------ the shop

    /// <summary>Buys the next tool in order (Gloves, then Net, then Vacuum).</summary>
    public ActionResult BuyNextTool()
    {
        if (!CanBuyNextTool || NextTool is not { } tool) return ActionResult.Refused;

        State.Beebits -= tool.Cost;
        State.ToolLevel++;
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.ToolBought, State.ToolLevel, tool.Id) };
        return new ActionResult(true, tool.Cost, events);
    }

    /// <summary>The Wax-Catcher is independent of the tool order.</summary>
    public ActionResult BuyWaxCatcher()
    {
        if (!CanBuyWaxCatcher) return ActionResult.Refused;

        State.Beebits -= Config.WaxCatcherCost;
        State.HasWaxCatcher = true;
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.WaxCatcherBought) };
        return new ActionResult(true, Config.WaxCatcherCost, events);
    }

    // ------------------------------------------------------------------ combs

    public ActionResult BuildComb()
    {
        decimal cost = CombCost;
        if (State.Wax < cost) return ActionResult.Refused;

        decimal storageBefore = HoneyStorage;
        State.Wax -= cost;
        State.Combs++;
        RefreshStorageFlag();
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.CombBuilt, HoneyStorage - storageBefore) };
        OpenWorkbenchIfDue(events);
        return new ActionResult(true, cost, events);
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
        AnnounceOldCountsIfDue(events);
        SendEmissaryIfDue(events);
        GiveSeedsIfDue(events);   // an older save past a seed's trade count gets that seed (stage 7)
        return events;
    }

    /// <summary>Stage 4 and 5 saves counted forager and guard bees. The specialties come from the
    /// plants on their own; this only says so once, if there was a count to speak of.</summary>
    private void AnnounceOldCountsIfDue(List<BeekeeperEvent> events)
    {
        if (State.OldCountsAnnounced) return;
        State.OldCountsAnnounced = true;
        if (State.ForagerBees > 0m || State.GuardBees > 0m)
            events.Add(new BeekeeperEvent(BeekeeperEvents.OldCountsSettle));
    }

    private void OpenWorkbenchIfDue(List<BeekeeperEvent> events)
    {
        if (State.WorkbenchRevealed || State.Combs < Config.WorkbenchCombs) return;
        State.WorkbenchRevealed = true;
        events.Add(new BeekeeperEvent(BeekeeperEvents.WorkbenchOpened));
    }

    /// <summary>Whether a batch of <paramref name="count"/> can be paid for in full.</summary>
    public bool CanCraftBeeswaxTimes(int count) =>
        count >= 1 && State.WorkbenchRevealed && State.Wax >= Config.BeeswaxCandleWax * count;

    public bool CanCraftBeeswax => CanCraftBeeswaxTimes(1);

    /// <summary>Repellent candles retire once the emissary has come (spec 014): the recipe,
    /// the light button and the Hive row are hidden; any left stay in the save, unseen.</summary>
    public bool RepellentRetired => State.EmissaryCome;

    public bool CanCraftRepellentTimes(int count) =>
        count >= 1 && State.WorkbenchRevealed && State.RepellentUnlocked && !RepellentRetired
        && State.Wax >= Config.RepellentCandleWax * count && State.Sage >= Config.RepellentCandleSage * count;

    public bool CanCraftRepellent => CanCraftRepellentTimes(1);

    /// <summary>Crafting is instant (Leah).</summary>
    /// <summary>Makes <paramref name="count"/> candles at once: exactly count times the cost, or nothing.</summary>
    public ActionResult CraftBeeswax(int count = 1)
    {
        if (!CanCraftBeeswaxTimes(count)) return ActionResult.Refused;
        State.Wax -= Config.BeeswaxCandleWax * count;
        State.BeeswaxCandles += count;
        var events = new List<BeekeeperEvent>();
        if (count > 1) events.Add(new BeekeeperEvent(BeekeeperEvents.Crafted, count, "beeswax"));
        if (State.CandlesCrafted == 0) events.Add(new BeekeeperEvent(BeekeeperEvents.FirstBeeswaxCandle));
        CountCandleCrafted(events, count);
        return new ActionResult(true, count, events);
    }

    public ActionResult CraftRepellent(int count = 1)
    {
        if (!CanCraftRepellentTimes(count)) return ActionResult.Refused;
        State.Wax -= Config.RepellentCandleWax * count;
        State.Sage -= Config.RepellentCandleSage * count;
        State.RepellentCandles += count;
        State.RepellentCrafted = true;
        var events = new List<BeekeeperEvent>();
        if (count > 1) events.Add(new BeekeeperEvent(BeekeeperEvents.Crafted, count, "repellent"));
        CountCandleCrafted(events, count);
        return new ActionResult(true, count, events);
    }

    // ------------------------------------------------------------------ the propolis candles (stage 7)

    /// <summary>The two propolis candles' recipes show at The Workbench once the poplar has sprouted.</summary>
    public bool PropolisCandlesShown => State.WorkbenchRevealed && HasSpecialty(BeekeeperSpecialties.Resin);

    public bool CanCraftBeeBoostTimes(int count) =>
        count >= 1 && PropolisCandlesShown
        && State.Wax >= Config.BeeBoostCandleWax * count && State.Propolis >= Config.BeeBoostCandlePropolis * count;

    public bool CanCraftBeeBoost => CanCraftBeeBoostTimes(1);

    public bool CanCraftSagePropolisTimes(int count) =>
        count >= 1 && PropolisCandlesShown
        && State.Wax >= Config.SagePropolisCandleWax * count && State.Sage >= Config.SagePropolisCandleSage * count
        && State.Propolis >= Config.SagePropolisCandlePropolis * count;

    public bool CanCraftSagePropolis => CanCraftSagePropolisTimes(1);

    public ActionResult CraftBeeBoost(int count = 1)
    {
        if (!CanCraftBeeBoostTimes(count)) return ActionResult.Refused;
        State.Wax -= Config.BeeBoostCandleWax * count;
        State.Propolis -= Config.BeeBoostCandlePropolis * count;
        State.BeeBoostCandles += count;
        var events = new List<BeekeeperEvent>();
        if (count > 1) events.Add(new BeekeeperEvent(BeekeeperEvents.Crafted, count, "bee_boost"));
        CountCandleCrafted(events, count);
        return new ActionResult(true, count, events);
    }

    public ActionResult CraftSagePropolis(int count = 1)
    {
        if (!CanCraftSagePropolisTimes(count)) return ActionResult.Refused;
        State.Wax -= Config.SagePropolisCandleWax * count;
        State.Sage -= Config.SagePropolisCandleSage * count;
        State.Propolis -= Config.SagePropolisCandlePropolis * count;
        State.SagePropolisCandles += count;
        var events = new List<BeekeeperEvent>();
        if (count > 1) events.Add(new BeekeeperEvent(BeekeeperEvents.Crafted, count, "sage_propolis"));
        CountCandleCrafted(events, count);
        return new ActionResult(true, count, events);
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

    private void CountCandleCrafted(List<BeekeeperEvent> events, int count = 1)
    {
        State.CandlesCrafted += count;
        if (!State.HippiesRevealed && State.CandlesCrafted >= Config.HippiesRevealCandles)
        {
            State.HippiesRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.HippiesArrive));
        }
    }

    // ------------------------------------------------------------------ the Hippies

    public bool CanTradeCandles => State.HippiesRevealed && State.BeeswaxCandles >= Config.CandlesPerSage;

    /// <summary>10 beeswax candles for 1 sage.</summary>
    public ActionResult TradeTenCandles() => TradeCandles(all: false);

    /// <summary>As many bundles of 10 as possible; the rest are kept.</summary>
    public ActionResult TradeAllCandles() => TradeCandles(all: true);

    private ActionResult TradeCandles(bool all)
    {
        if (!CanTradeCandles) return ActionResult.Refused;
        decimal bundles = all ? Math.Floor(State.BeeswaxCandles / Config.CandlesPerSage) : 1m;
        State.BeeswaxCandles -= bundles * Config.CandlesPerSage;
        State.Sage += bundles;
        State.HippieTrades++;
        State.SageRevealed = true;

        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.CandlesTraded, bundles, null, bundles * Config.CandlesPerSage) };
        if (!State.RepellentUnlocked)
        {
            // The sage repellent candle comes once there is sage to make it with (placeholder rule).
            State.RepellentUnlocked = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.RepellentUnlocked));
        }
        GiveSeedsIfDue(events);
        return new ActionResult(true, bundles, events);
    }

    // ------------------------------------------------------------------ upgrades (in the Shop)

    /// <summary>Upgrades that are unlocked and not yet bought, in Shop order. Bought and
    /// still-locked upgrades are not listed (Leah: hide purchased upgrades).</summary>
    public IReadOnlyList<BeekeeperUpgrade> ShopUpgrades =>
        Config.Upgrades.Where(u => !Owns(u.Id) && IsUnlocked(u)).ToList();

    // Stage 2's upgrades come with The Workbench; stage 3's catching upgrades only need the Vacuum.
    private bool IsUnlocked(BeekeeperUpgrade u) => u.Needs switch
    {
        BeekeeperUpgrades.NeedsWorkbench => State.WorkbenchRevealed,
        BeekeeperUpgrades.NeedsWaxCatcher => State.WorkbenchRevealed && State.HasWaxCatcher,
        // Stronger Candles leaves the Shop with the repellent candle (spec 014), unless bought.
        BeekeeperUpgrades.NeedsRepellent => State.RepellentUnlocked && !RepellentRetired,
        BeekeeperUpgrades.NeedsVacuum => State.ToolLevel >= VacuumLevel,
        // Stage 7 (spec 015)
        BeekeeperUpgrades.NeedsPaper => PaperSeen,
        BeekeeperUpgrades.NeedsGardenAndPaper => State.GardenRevealed && PaperSeen,
        BeekeeperUpgrades.NeedsPropolis => PropolisSeen,
        var other => Owns(other),
    };

    /// <summary>Paper has been seen: a wasp trade, or any paper held (also an older save's).</summary>
    public bool PaperSeen => State.PaperRevealed || State.WaspTrades > 0 || State.Paper > 0m;

    /// <summary>Propolis has been seen: the poplar has sprouted, or any propolis was held.</summary>
    public bool PropolisSeen => State.PropolisRevealed || State.Propolis >= 1m;

    private int VacuumLevel => Config.Tools.ToList().FindIndex(t => t.Id == "vacuum") + 1;

    public bool CanBuyUpgrade(string id) =>
        Config.Upgrades.FirstOrDefault(u => u.Id == id) is { } u
        && !Owns(id) && IsUnlocked(u)
        && State.Beebits >= u.Beebits && State.Wax >= u.Wax && State.Sage >= u.Sage
        && State.Paper >= u.Paper && State.Propolis >= u.Propolis;

    /// <summary>Takes every part of the cost at once, or nothing.</summary>
    public ActionResult BuyUpgrade(string id)
    {
        if (!CanBuyUpgrade(id)) return ActionResult.Refused;
        var u = Config.Upgrades.First(x => x.Id == id);
        State.Beebits -= u.Beebits;
        State.Wax -= u.Wax;
        State.Sage -= u.Sage;
        State.Paper -= u.Paper;
        State.Propolis -= u.Propolis;
        State.Upgrades.Add(id);
        RefreshStorageFlag();
        return new ActionResult(true, u.Beebits, new[] { new BeekeeperEvent(BeekeeperEvents.UpgradeBought, 0m, id) });
    }

    // ------------------------------------------------------------------ wasps

    public bool WaspApproaching => State.WaspCountdown > 0m && !State.EmissaryCome;

    /// <summary>True once the wasp nest has sent its emissary: no wasp ever comes again.</summary>
    public bool EmissaryCome => State.EmissaryCome;

    /// <summary>Wasp time that one repellent candle buys (longer with Stronger Candles).</summary>
    public decimal RepellentBurnSeconds =>
        Config.RepellentBurnSeconds * (Owns(BeekeeperUpgrades.StrongerCandles) ? Config.StrongerCandlesBonus : 1m);

    /// <summary>
    /// "Wasp time" passed: only while Beekeeper is on screen and the player is active (the view
    /// model decides; No Stress Mode no longer applies to Beekeeper, spec 014). A burning candle
    /// uses it up; otherwise it counts down to the next wasp. Away time never comes here, and
    /// after the emissary nothing happens at all.
    /// </summary>
    public IReadOnlyList<BeekeeperEvent> AdvanceWaspTime(decimal seconds)
    {
        var events = new List<BeekeeperEvent>();
        if (seconds <= 0m || !State.WorkbenchRevealed || WaspApproaching || State.EmissaryCome) return events;

        if (State.RepellentSecondsLeft > 0m)
        {
            State.RepellentSecondsLeft = Math.Max(0m, State.RepellentSecondsLeft - seconds);
            if (State.RepellentSecondsLeft == 0m) events.Add(new BeekeeperEvent(BeekeeperEvents.CandleOut));
            return events;   // a candle's time is never also wasp time
        }

        if (State.NextWaspInSeconds <= 0m) RollNextWasp();
        State.NextWaspInSeconds -= seconds;
        if (State.NextWaspInSeconds <= 0m)
        {
            State.NextWaspInSeconds = 0m;
            State.WaspCountdown = Config.WaspCountdownSeconds;
            events.Add(new BeekeeperEvent(BeekeeperEvents.WaspArrives));
        }
        return events;
    }

    private void RollNextWasp()
    {
        decimal span = Config.WaspMaxSeconds - Config.WaspMinSeconds;
        State.NextWaspInSeconds = Config.WaspMinSeconds + span * (decimal)_rng.NextDouble();
    }

    /// <summary>Calls a wasp at once (debug builds only; the game never does this).</summary>
    public IReadOnlyList<BeekeeperEvent> DebugCallWasp()
    {
        if (!State.WorkbenchRevealed || WaspApproaching || State.EmissaryCome) return Array.Empty<BeekeeperEvent>();
        State.NextWaspInSeconds = 0m;
        State.WaspCountdown = Config.WaspCountdownSeconds;
        return new[] { new BeekeeperEvent(BeekeeperEvents.WaspArrives) };
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
            EndWasp();
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
        EndWasp();
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

    public bool CanLightRepellent => State.RepellentCandles >= 1m && !RepellentRetired;

    /// <summary>Uses one candle: no wasps while it burns, and an approaching wasp leaves at once.
    /// Lighting another adds its time.</summary>
    public ActionResult LightRepellent()
    {
        if (!CanLightRepellent) return ActionResult.Refused;
        State.RepellentCandles--;
        State.RepellentSecondsLeft += RepellentBurnSeconds;
        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.CandleLit) };
        if (WaspApproaching) EndWasp();
        return new ActionResult(true, 1m, events);
    }

    /// <summary>A raid takes 3 minutes' worth of honey and nothing else (spec 014: never bees).</summary>
    private BeekeeperEvent Raid(string key)
    {
        decimal honey = Math.Min(State.Honey, Math.Floor(HoneyPerSecond * Config.RaidHoneySeconds));
        // Cut in stage 6 (spec 014): some bees flew off, unless a guard bee kept them safe.
        // bool guarded = HasGuards;   // one guard bee and no raid ever costs a bee
        // decimal bees = guarded ? 0m : Math.Floor(State.Bees * Config.RaidBeeShare);
        // State.Bees -= bees;
        State.Honey -= honey;
        RefreshStorageFlag();
        EndWasp();
        return new BeekeeperEvent(key, honey);
        // return new BeekeeperEvent(key, honey, guarded ? "guards" : null, bees);
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
        GiveSeedsIfDue(events);   // the wasps' reputation brings the poplar seed
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

    /// <summary>Garden beds owned: two, three with the Third Bed.</summary>
    public int BedCount => Config.StartingBeds + (Owns(BeekeeperUpgrades.ThirdBed) ? Config.ThirdBedBeds : 0);

    /// <summary>Beds with a seed growing.</summary>
    public bool IsGrowing => State.Beds.Count > 0;

    public int FreeBeds => Math.Max(0, BedCount - State.Beds.Count);

    public BeekeeperPlant? PlantById(string id) => Config.Plants.FirstOrDefault(p => p.Id == id);

    /// <summary>Seeds in hand, as plants (in the order they were given).</summary>
    public IReadOnlyList<BeekeeperPlant> SeedsInHand =>
        State.SeedsInHand.Select(PlantById).OfType<BeekeeperPlant>().ToList();

    /// <summary>Plants that have sprouted, in order.</summary>
    public IReadOnlyList<BeekeeperPlant> SproutedPlants =>
        State.Plants.Select(id => Config.Plants.FirstOrDefault(p => p.Id == id)).OfType<BeekeeperPlant>().ToList();

    /// <summary>The hive's specialties, from the sprouted plants, in the order they first came.</summary>
    public IReadOnlyList<string> Specialties => SproutedPlants.Select(p => p.Specialty).Distinct().ToList();

    public bool HasSpecialty(string id) => SproutedPlants.Any(p => p.Specialty == id);

    /// <summary>Nursing's laying multiplier: every nursing plant's strength, multiplied (1 = none).</summary>
    public decimal NursingMultiplier
    {
        get
        {
            decimal m = 1m;
            foreach (var p in SproutedPlants)
                if (p.Specialty == BeekeeperSpecialties.Nursing) m *= p.Strength;
            return m;
        }
    }

    /// <summary>Propolis a minute from resin: every resin plant's strength, added up.</summary>
    public decimal ResinPropolisPerMinute =>
        SproutedPlants.Where(p => p.Specialty == BeekeeperSpecialties.Resin).Sum(p => p.Strength);

    public decimal PropolisPerSecondNow => ResinPropolisPerMinute / 60m;

    /// <summary>Pollen a minute from foraging: every foraging plant's strength, added up.</summary>
    public decimal ForagingPollenPerMinute =>
        SproutedPlants.Where(p => p.Specialty == BeekeeperSpecialties.Foraging).Sum(p => p.Strength);

    public decimal PollenPerSecondNow => ForagingPollenPerMinute / 60m;

    /// <summary>Guarding's honey multiplier: every guarding plant's strength, multiplied (1 = none).</summary>
    public decimal GuardingMultiplier
    {
        get
        {
            decimal m = 1m;
            foreach (var p in SproutedPlants)
                if (p.Specialty == BeekeeperSpecialties.Guarding) m *= p.Strength;
            return m;
        }
    }

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

    /// <summary>Gives every seed whose giver has traded enough and that was not given yet: the
    /// Hippies' plants by Hippie trades, the wasps' by wasp trades. Each plant is given once, by
    /// id. Checked after a trade and on load (so an older save past a count gets its seed).</summary>
    private void GiveSeedsIfDue(List<BeekeeperEvent> events)
    {
        foreach (var plant in Config.Plants)
        {
            if (State.SeedsGivenIds.Contains(plant.Id) || State.Plants.Contains(plant.Id)
                || State.SeedsInHand.Contains(plant.Id) || State.Beds.Any(b => b.PlantId == plant.Id)) continue;
            bool byWasps = plant.Giver == BeekeeperGivers.Wasps;
            long trades = byWasps ? State.WaspTrades : State.HippieTrades;
            if (trades < plant.SeedAtTrade) continue;
            GiveSeed(plant, byWasps, events);
        }
    }

    private void GiveSeed(BeekeeperPlant plant, bool byWasps, List<BeekeeperEvent> events)
    {
        State.SeedsGivenIds.Add(plant.Id);
        State.SeedsInHand.Add(plant.Id);
        State.GardenRevealed = true;
        events.Add(new BeekeeperEvent(byWasps ? BeekeeperEvents.WaspSeedGiven : BeekeeperEvents.SeedGiven,
            State.SeedsInHand.Count, plant.Id));
    }

    /// <summary>A seed in hand and a free bed.</summary>
    public bool CanPlantSeed => State.SeedsInHand.Count >= 1 && FreeBeds > 0;

    public bool CanPlantSeedOf(string plantId) => State.SeedsInHand.Contains(plantId) && FreeBeds > 0;

    /// <summary>Plants a seed in a free bed, for its own grow time. <paramref name="plantId"/> null
    /// plants the first seed in hand.</summary>
    public ActionResult PlantSeed(string? plantId = null)
    {
        plantId ??= State.SeedsInHand.FirstOrDefault();
        if (plantId is null || !CanPlantSeedOf(plantId) || PlantById(plantId) is not { } plant) return ActionResult.Refused;
        State.SeedsInHand.Remove(plantId);
        State.Beds.Add(new BeekeeperBed { PlantId = plantId, SecondsLeft = plant.GrowSeconds });
        return new ActionResult(true, 1m, new[] { new BeekeeperEvent(BeekeeperEvents.SeedPlanted, 0m, plantId) });
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
        State.Pollen += ForagingPollenPerMinute * seconds / 60m;
        State.Propolis += ResinPropolisPerMinute * seconds / 60m;
        if (!State.PropolisRevealed && State.Propolis >= 1m)
        {
            State.PropolisRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.FirstPropolis));
        }

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
        NoteBeeBreadAdded(events);
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

    private bool SeedNotYetGiven(BeekeeperPlant p) =>
        !State.SeedsGivenIds.Contains(p.Id) && !State.Plants.Contains(p.Id)
        && !State.SeedsInHand.Contains(p.Id) && !State.Beds.Any(b => b.PlantId == p.Id);

    /// <summary>Debug builds only: a seed is handed over (the next plant whose seed has not been given).</summary>
    public IReadOnlyList<BeekeeperEvent> DebugGiveSeed()
    {
        var events = new List<BeekeeperEvent>();
        if (Config.Plants.FirstOrDefault(SeedNotYetGiven) is { } next)
            GiveSeed(next, next.Giver == BeekeeperGivers.Wasps, events);
        return events;
    }

    /// <summary>Debug builds only: every seed not yet given is handed over.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugGiveEverySeed()
    {
        var events = new List<BeekeeperEvent>();
        foreach (var plant in Config.Plants.Where(SeedNotYetGiven).ToList())
            GiveSeed(plant, plant.Giver == BeekeeperGivers.Wasps, events);
        return events;
    }

    /// <summary>Debug builds only: every growing seed sprouts now.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugFinishGrowing()
    {
        var events = new List<BeekeeperEvent>();
        foreach (var bed in State.Beds.OrderBy(b => b.SecondsLeft).ToList()) Sprout(bed, events);
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

    /// <summary>Debug builds only: the Hippie trade count goes up to 19 (one short of the willow
    /// seed), the Hippies arrive if they hadn't and ten candles are put on the shelf for the trade.
    /// Seeds already due at that count are given.</summary>
    public IReadOnlyList<BeekeeperEvent> DebugHippieTradesTo19()
    {
        var events = new List<BeekeeperEvent>();
        if (!State.HippiesRevealed)
        {
            State.HippiesRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.HippiesArrive));
        }
        State.HippieTrades = Math.Max(State.HippieTrades, 19);
        if (State.BeeswaxCandles < Config.CandlesPerSage) State.BeeswaxCandles = Config.CandlesPerSage;
        GiveSeedsIfDue(events);
        return events;
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

    // ------------------------------------------------------------------ reveals

    private void CheckReveals(List<BeekeeperEvent> events)
    {
        if (!State.BearRevealed && State.Honey >= Config.BearRevealHoney)
        {
            State.BearRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.BearArrives, 0m, State.BearName));
        }
        if (!State.ShopRevealed && State.Beebits >= Config.ShopRevealBeebits)
        {
            State.ShopRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.ShopOpened));
        }
        if (!State.CombsRevealed && State.Wax >= Config.CombsRevealWax)
        {
            State.CombsRevealed = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.CombsAvailable));
        }
    }

    /// <summary>Lets "the combs are full" be announced again once there is room again.</summary>
    private void RefreshStorageFlag()
    {
        if (State.Honey < HoneyStorage) State.StorageFullAnnounced = false;
    }
}
