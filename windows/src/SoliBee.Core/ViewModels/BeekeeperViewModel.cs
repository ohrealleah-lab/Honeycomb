using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

/// <summary>
/// One buyer on the shared Trading card (the Bear, the Hippies, later others). Give and Get
/// are resource names ("honey", "beebits", "herbal_candles", "herbs") the view turns into
/// words: "10 honey = 1 Beebit". The view model holds no words.
/// </summary>
/// <remarks>A buyer with <see cref="TradeTimes"/> (the wasps) offers one trade plus x10 and x100
/// buttons, each shown only when <see cref="CanTradeTimes"/> says the whole batch is affordable;
/// <see cref="TradeAll"/> is then unused.</remarks>
public sealed record BeekeeperTradeOffer(
    string Id, string? Name, long Trades,
    decimal GiveAmount, string Give, decimal GetAmount, string Get,
    bool CanTrade, Action TradeOne, Action TradeAll,
    Func<int, bool>? CanTradeTimes = null, Action<int>? TradeTimes = null);

/// <summary>
/// One row of the Hive card (spec 014, FR-505). The view model knows no words: <see cref="Id"/>
/// (one of <see cref="BeekeeperHiveRows"/>) tells the view which label and wording to use, and
/// the numbers fill it in. <see cref="Rate"/> is the per-second rate shown on hover (null: no
/// hover); <see cref="Rate2"/> a second hover number where a row needs one (the pantry's time,
/// the free bees' honey bonus in percent). Every row that grows on its own lists everything that
/// feeds it (Bee, 2026-11-11): <see cref="Sources"/>, each source's amount a second, then
/// <see cref="Boosts"/>, each multiplier that is on with its extra percent.
/// <see cref="SecondsToFull"/> is set only on a row with a cap (Build it with
/// <see cref="BeekeeperViewModel.CappedRow"/>): 0 = full, null = no time to show. Every capped
/// row's hover shows it under the rate, so a new capped row gets it by using that helper.
/// </summary>
public sealed record BeekeeperHiveRow(string Id, bool Visible, decimal Value = 0m, decimal Value2 = 0m,
    decimal? Rate = null, decimal Rate2 = 0m, decimal? SecondsToFull = null,
    IReadOnlyList<BeekeeperBoost>? Boosts = null, IReadOnlyList<BeekeeperSource>? Sources = null);

/// <summary>Something that adds to a growing stat, for a hover: <see cref="Id"/> is "combs",
/// "wax_drip", "free_bees", "queen", "foraging", "resin", "meadow", "carpenter_bee" (stage 8) or a
/// <see cref="BeekeeperHerbs"/> id; <see cref="PerSecond"/> its amount a second (before boosts);
/// <see cref="Count"/> how many combs or bees it comes from, where the line says so.</summary>
public sealed record BeekeeperSource(string Id, decimal PerSecond, decimal Count = 0m);

/// <summary>A boost that is on right now, for a hover: <see cref="Id"/> is "smoker", "bee_boost",
/// "sage_propolis", "free_bees", "wax_catcher", "wooden_hive", "guarding", "nursing", "plant"
/// (stage 8: <see cref="Plant"/>'s bonus from <see cref="Count"/> plants after the first) or a
/// <see cref="BeekeeperHerbs"/> id; <see cref="Percent"/> its extra (100 = +100%).</summary>
public sealed record BeekeeperBoost(string Id, decimal Percent, string? Plant = null, decimal Count = 0m);

/// <summary>Bee ids on the Bees tab (stage 8, FR-813): <see cref="BeekeeperBees"/> ids.</summary>
public static class BeekeeperBeeTab
{
    /// <summary>The plant bonus boost's id in <see cref="BeekeeperBoost"/>.</summary>
    public const string PlantBoost = "plant";
}

/// <summary>A small heading and its rows. The heading only shows while one of its rows does.</summary>
public sealed record BeekeeperHiveGroup(string Id, IReadOnlyList<BeekeeperHiveRow> Rows)
{
    public bool Visible => Rows.Any(r => r.Visible);
}

/// <summary>Group and row ids on the Hive card. A later stage adds a row with one new id here,
/// one entry in <see cref="BeekeeperViewModel.HiveGroups"/> and its words in the view.</summary>
public static class BeekeeperHiveRows
{
    public const string GroupBees = "bees";
    public const string GroupHive = "hive";
    public const string GroupGarden = "garden";
    public const string GroupCrafts = "crafts";
    public const string GroupTradeGoods = "trade_goods";

    // Stage 7.5 (spec 016): the bees row is the free bees (the view labels it "Free bees").
    public const string Honeybees = "honeybees";          // Value = free bees; Rate = bees/s from the queen
    public const string Queen = "queen";                  // Value = 1 laying, 0 resting
    public const string Foraging = "foraging";            // full-width line; Value = pollen a minute
    public const string Guarding = "guarding";            // full-width line; Value = extra honey percent
    public const string Honey = "honey";                  // Value = stored, Value2 = storage; Rate = honey/s, Rate2 = free bees' bonus %
    public const string Wax = "wax";                      // Value = stored (rounded down), Value2 = wax cap; Rate = wax/s
    public const string Combs = "combs";
    public const string CombsFull = "combs_full";         // full-width warning line
    public const string WaxFull = "wax_full";             // full-width warning line (stage 7.5)
    public const string Seeds = "seeds";
    public const string Pollen = "pollen";                // Rate = pollen/s while foraging
    public const string BeeBread = "bee_bread";           // Rate = bee bread eaten/s, Rate2 = pantry seconds
    public const string RepellentCandles = "repellent_candles";
    public const string Beebits = "beebits";
    public const string Herbs = "herbs";   // was "sage" (Bee, 2026-11-11: herbs replaced sage)
    public const string Paper = "paper";
    // Stage 7 (spec 015)
    public const string Nursing = "nursing";              // full-width line; Value = extra laying percent
    public const string Resin = "resin";                  // full-width line; Value = propolis a minute
    public const string Propolis = "propolis";            // Rate = propolis/s while resin
    public const string BeeBoostCandles = "bee_boost_candles";
    public const string SagePropolisCandles = "sage_propolis_candles";
    public const string BeeBoostBurning = "bee_boost_burning";         // full-width line; Value = seconds left
    public const string SagePropolisBurning = "sage_propolis_burning"; // full-width line; Value = seconds left
    // Stage 8 (spec 017)
    public const string Wood = "wood";                    // Value = wood (rounded down); Rate = wood/s from the carpenter bee
    // Cut in stage 6 (spec 014): counts of forager and guard bees.
    // public const string Foragers = "foragers";
    // public const string Guards = "guards";
}

/// <summary>One growing bed on the Garden card: which plant and how long it has left.
/// Unused since stage 8 (spec 017): plants grow at once. Kept for the comment-out rule.</summary>
public sealed record BeekeeperBedView(BeekeeperPlant Plant, decimal SecondsLeft);

/// <summary>One row of the Garden card (stage 8): a plant kind and how many (seeds in hand, or plants growing).</summary>
public sealed record BeekeeperGardenRow(BeekeeperPlant Plant, int Count);

/// <summary>Notes in the Beekeeper's Notebook (spec 015, FR-608): one per thing the hive has.
/// A specialty's note uses the specialty's own id.</summary>
public static class BeekeeperNotes
{
    public const string Queen = "queen";
}

/// <summary>
/// Runs a Beekeeper game for the screen: owns the rules engine, the one-second timer, the
/// story log, autosave and time-away credit. It deliberately knows no words: the log holds
/// event keys plus values and the view turns them into (localized) sentences.
/// The app coordinator owns one of these for the whole session, so the hive keeps working
/// while the player is in another game.
/// </summary>
public partial class BeekeeperViewModel : ObservableObject, IDisposable
{
    /// <summary>How often progress is saved while playing.</summary>
    public const int AutosaveEverySeconds = 5;

    private readonly Func<DateTime> _clock;
    private readonly string? _savePath;
    /// <summary>True when a save file exists but could not be read or set aside: never write over it.</summary>
    private readonly bool _saveBlocked;
    private readonly SynchronizationContext? _syncContext;
    private Timer? _timer;
    private DateTime _lastTickUtc;
    private decimal _carrySeconds;          // leftover fraction of a second between ticks
    private decimal _secondsSinceSave;
    private bool _disposed;
    // Cut in stage 6 (spec 014): No Stress Mode no longer applies to Beekeeper.
    // private readonly Func<bool> _noStressMode;
    private DateTime _lastActivityUtc;

    /// <summary>True while the Beekeeper screen is showing in a window that isn't minimised.
    /// The view sets it; wasps only come while it is true.</summary>
    public bool IsWatched { get; set; }

    public BeekeeperEngine Engine { get; private set; }
    public BeekeeperState State => Engine.State;
    public BeekeeperConfig Config => Engine.Config;

    /// <param name="isHeadless">True means no timer (tests call <see cref="Tick"/> themselves).</param>
    /// <param name="persist">False means never touch the disk.</param>
    /// <param name="savePath">Where to save; null uses the app's data folder.</param>
    /// <param name="initialState">Start from this instead of loading a save (tests).</param>
    /// <param name="noStressMode">Unused since stage 6 (No Stress Mode no longer applies to
    /// Beekeeper); kept so callers and tests stay as they are.</param>
    public BeekeeperViewModel(
        bool isHeadless = false,
        BeekeeperConfig? config = null,
        IRandomSource? rng = null,
        Func<DateTime>? clock = null,
        bool persist = true,
        string? savePath = null,
        BeekeeperState? initialState = null,
        Func<bool>? noStressMode = null)
    {
        _clock = clock ?? (() => DateTime.UtcNow);
        _ = noStressMode;
        // Cut in stage 6 (spec 014):
        // _noStressMode = noStressMode ?? (() => SettingsService.LoadOptions().IsNoStressMode);
        _syncContext = SynchronizationContext.Current;
        _savePath = persist ? (savePath ?? BeekeeperSaveService.SaveFilePath) : null;

        BeekeeperState? loaded = initialState;
        if (loaded is null && _savePath is not null)
            loaded = BeekeeperSaveService.Load(_savePath, out _saveBlocked);
        Engine = new BeekeeperEngine(config, loaded, rng);

        var now = _clock();
        _lastTickUtc = now;
        _lastActivityUtc = now;

        if (loaded is null)
        {
            LogEvents(new[] { new BeekeeperEvent(BeekeeperEvents.NewGame) });
        }
        else
        {
            // Time since the last save counts as time away (closing the app, a long gap, etc.).
            // The load reveals come first, so an older save's wooden hive (the queen) and trade
            // agreement already count for the time away.
            LogEvents(Engine.RevealOnLoad());   // an older save may already have earned The Workbench
            decimal gap = BeekeeperSaveService.SecondsSinceSaved(loaded, now);
            if (Engine.IsAway(gap)) LogAway(Engine.AdvanceAway(gap));
        }

        if (!isHeadless) StartTimer();
    }

    // ------------------------------------------------------------------ what the screen shows

    // Short text for the top stats bar. Honey shows how full the combs are ("45 / 200").
    private static AppLanguage CurrentLanguage => SettingsService.LoadOptions().Language;
    public string BeesDisplay => NumberFormatter.Format(State.Bees, CurrentLanguage);
    public string HoneyDisplay =>
        NumberFormatter.Format(State.Honey, CurrentLanguage) + " / " + NumberFormatter.Format(Engine.HoneyStorage, CurrentLanguage);
    /// <summary>Wax shows how full its cap is too ("12 / 20"), rounded down like honey (stage 7.5).</summary>
    public string WaxDisplay =>
        NumberFormatter.Format(Math.Floor(State.Wax), CurrentLanguage) + " / " + NumberFormatter.Format(Engine.WaxStorage, CurrentLanguage);
    // Cut in stage 7.5 (spec 016): public string WaxDisplay => NumberFormatter.Format(State.Wax, CurrentLanguage);
    public string BeebitsDisplay => NumberFormatter.Format(State.Beebits, CurrentLanguage);

    public decimal Bees => State.Bees;
    public decimal Honey => State.Honey;
    public decimal HoneyStorage => Engine.HoneyStorage;
    /// <summary>What the hive makes right now (doubled while the bees are calm).</summary>
    public decimal HoneyPerSecond => Engine.HoneyPerSecondNow;
    /// <summary>What the hive makes in wax right now.</summary>
    public decimal WaxPerSecond => Engine.WaxPerSecondNow;
    public decimal Wax => State.Wax;
    // Cut in stage 7.5 (spec 016): wax no longer follows honey.
    // public decimal WaxProgress => State.WaxProgress;
    // public decimal HoneyPerWax => Config.HoneyPerWax;
    public decimal Beebits => State.Beebits;
    public int ToolLevel => State.ToolLevel;
    public int BeesPerClick => Engine.BeesPerClick;
    public bool HasWaxCatcher => State.HasWaxCatcher;
    public int Combs => State.Combs;
    /// <summary>The next comb's wax price.</summary>
    public decimal CombCost => Engine.CombCost;
    /// <summary>The next comb's bee price (stage 7.5): these free bees move in.</summary>
    public decimal CombBeeCost => Engine.CombBeeCost;
    /// <summary>Honey storage the next comb adds (bigger with the Technologies).</summary>
    public decimal StoragePerComb => Engine.StoragePerComb;
    /// <summary>Wax storage the next comb adds (bigger with the Technologies).</summary>
    public decimal WaxStoragePerComb => Engine.WaxStoragePerComb;
    /// <summary>Honey a second the next comb adds, with the lasting boosts.</summary>
    public decimal HoneyPerComb => Engine.HoneyPerCombNow;
    /// <summary>The wax cap (stage 7.5).</summary>
    public decimal WaxStorage => Engine.WaxStorage;
    public bool WaxIsFull => Engine.IsWaxFull;
    /// <summary>The first bee has been caught: the combs make honey from then on, even at 0 free bees.</summary>
    public bool HiveStarted => Engine.HiveStarted;
    public string BearName => State.BearName;
    public long Trades => State.Trades;
    public BeekeeperTool? NextTool => Engine.NextTool;
    public bool StorageIsFull => Engine.IsStorageFull;

    // Finished values for the screen, so it does no rules or percentage maths of its own.
    /// <summary>Honey bonus of the wooden hive, as a percent ("25").</summary>
    public decimal WoodenHiveBonusPercent => (Config.WoodenHiveHoneyMultiplier - 1m) * 100m;
    public decimal BeeBoostBonusPercent => (Config.BeeBoostHoneyMultiplier - 1m) * 100m;
    public decimal SagePropolisBonusPercent => (Config.SagePropolisHoneyMultiplier - 1m) * 100m;
    /// <summary>Live seconds one herbal candle burns right now (Stronger Candles counted).</summary>
    public decimal HerbalCandleBurnSeconds => Engine.HerbalCandleBurnSeconds;
    /// <summary>Bees a click would catch with <paramref name="tool"/>, Practice counted.</summary>
    public int BeesPerClickWith(BeekeeperTool tool) => Engine.BeesPerClickWith(tool);
    // Cut in stage 8 (spec 017): no beds.
    // /// <summary>Garden bed rows to draw: every bed owned (a save may hold more growing than owned).</summary>
    // public int BedRowCount => Math.Max(BedCount, State.Beds.Count);

    public bool HoneyRevealed => State.HoneyRevealed;
    /// <summary>The Hive card: the first bee, or the first whole wax from the drip (stage 7.5: wax
    /// can come before any bee is caught).</summary>
    public bool HiveCardShown => State.HoneyRevealed || State.WaxRevealed;
    public bool BearRevealed => State.BearRevealed;
    public bool BeebitsRevealed => State.BeebitsRevealed;
    public bool WaxRevealed => State.WaxRevealed;
    public bool ShopRevealed => State.ShopRevealed;
    public bool CombsRevealed => State.CombsRevealed;

    // Stage 2
    public decimal RepellentCandles => State.RepellentCandles;
    public long CandlesCrafted => State.CandlesCrafted;
    public decimal Herbs => State.Herbs;
    public bool WorkbenchRevealed => State.WorkbenchRevealed;
    public bool HippiesRevealed => State.HippiesRevealed;
    public bool HerbsRevealed => State.HerbsRevealed;
    public bool RepellentUnlocked => State.RepellentUnlocked;
    /// <summary>The herbal candle is shown (recipe, light button): the first herb has come.</summary>
    public bool RepellentShown => Engine.RepellentShown;
    public bool WaspApproaching => Engine.WaspApproaching;
    public decimal WaspSecondsLeft => State.WaspCountdown;
    public decimal RepellentSecondsLeft => State.RepellentSecondsLeft;
    public decimal BribeCost => Engine.BribeCost;
    public IReadOnlyList<BeekeeperUpgrade> ShopUpgrades => Engine.ShopUpgrades;
    public bool CanBuyUpgrade(string id) => Engine.CanBuyUpgrade(id);
    /// <summary>The percent a Shop upgrade's blurb quotes, or null when its blurb has no number.</summary>
    public decimal? UpgradeBonusPercent(string id) => Engine.UpgradeBonusPercent(id);
    public bool CanCraftRepellent => Engine.CanCraftRepellent;
    public bool CanTradeCandles => Engine.CanTradeCandles;
    public bool CanThrowShoe => Engine.WaspApproaching;
    public bool CanBribe => Engine.CanBribe;
    /// <summary>The wasp's first visit: the choices are Throw a shoe / Engage (later: Throw a shoe / Bribe).</summary>
    public bool WaspFirstVisit => Engine.WaspFirstVisit;
    public bool CanEngageWasp => Engine.CanEngageWasp;
    /// <summary>Reps (ids "bear", "hippies") at the door, waiting for Throw a shoe or Engage.</summary>
    public IReadOnlyList<string> RepsPresent => Engine.RepsPresent.ToList();
    public bool CanLightRepellent => Engine.CanLightRepellent;

    /// <summary>Every buyer the player has met, in the order they arrived (Leah: one shared
    /// trade interface for all trades). Each trades bundles: give 10, get 1.</summary>
    public IReadOnlyList<BeekeeperTradeOffer> TradeOffers
    {
        get
        {
            var offers = new List<BeekeeperTradeOffer>();
            // The bear's trade of the moment: 10 honey for 1 herb, or 8 honey under the agreement.
            // Reps' trades appear only once the player has engaged them.
            if (State.BearRevealed && Engine.RepEngaged("bear"))
                offers.Add(new BeekeeperTradeOffer("bear", State.BearName, State.Trades,
                    Engine.HoneyPerTradeNow, "honey", Engine.HerbsPerTradeNow, "herbs", CanSell, SellTen, SellAll));
            // The Hippies buy herbal candles for Beebits (Bee, 2026-11-11: was 10 beeswax candles for 1 sage).
            if (State.HippiesRevealed && Engine.RepEngaged("hippies"))
                offers.Add(new BeekeeperTradeOffer("hippies", null, State.HippieTrades,
                    1m, "herbal_candles", Engine.BeebitsPerCandleNow, "beebits", CanTradeCandles, TradeTenCandles, TradeAllCandles));
            // Stage 6: the wasps, once their emissary has come. One paper a click, or x10 / x100.
            if (State.EmissaryCome)
                offers.Add(new BeekeeperTradeOffer("wasps", null, State.WaspTrades,
                    Config.HoneyPerPaper, "honey", 1m, "paper", Engine.CanTradePaper,
                    () => TradePaperTimes(1), () => TradePaperTimes(1), Engine.CanTradePaperTimes, TradePaperTimes));
            return offers;
        }
    }

    // Stage 3
    /// <summary>Everything a successful click catches right now (tool, Practice and the slice).</summary>
    public decimal BeesPerCatch => Engine.BeesPerCatch;
    public bool HasSmoker => Engine.Owns(BeekeeperUpgrades.Smoker);
    /// <summary>True while a recent smoker click is boosting honey.</summary>
    public bool IsSmokerBoosted => Engine.IsSmokerBoosted;
    /// <summary>The smoker's honey boost, as a percent ("50").</summary>
    public decimal SmokerBoostPercent => Engine.SmokerBoostPercent;

    // Stage 4: the Garden
    public bool GardenRevealed => State.GardenRevealed;
    /// <summary>Seeds in hand, not yet planted.</summary>
    public int Seeds => State.SeedsInHand.Count;
    /// <summary>The seeds in hand, as plants, each with its own Plant button.</summary>
    public IReadOnlyList<BeekeeperPlant> SeedsInHand => Engine.SeedsInHand;
    // Cut in stage 7 (spec 015): one growing plant, kept a surprise. Seeds are named now.
    // public BeekeeperPlant? GrowingPlant => Engine.GrowingPlant;
    // Cut in stage 8 (spec 017, FR-803): plants grow at once, so there are no beds to show.
    // public bool IsGrowing => Engine.IsGrowing;
    // /// <summary>How many garden beds there are (two, three with the Third Bed).</summary>
    // public int BedCount => Engine.BedCount;
    // public int FreeBeds => Engine.FreeBeds;
    // /// <summary>The beds with a seed growing, soonest to sprout first.</summary>
    // public IReadOnlyList<BeekeeperBedView> GrowingBeds => State.Beds
    //     .Select(b => new { Bed = b, Plant = Engine.PlantById(b.PlantId) })
    //     .Where(x => x.Plant is not null)
    //     .OrderBy(x => x.Bed.SecondsLeft)
    //     .Select(x => new BeekeeperBedView(x.Plant!, x.Bed.SecondsLeft))
    //     .ToList();
    public IReadOnlyList<BeekeeperPlant> SproutedPlants => Engine.SproutedPlants;

    /// <summary>The Garden card's seed rows (stage 8): one per kind in hand, with the count, in
    /// config order. Its Plant button plants one.</summary>
    public IReadOnlyList<BeekeeperGardenRow> SeedRows =>
        Config.Plants.Select(p => new BeekeeperGardenRow(p, Engine.SeedCount(p.Id)))
            .Where(r => r.Count > 0).ToList();

    /// <summary>The Garden card's plant rows (stage 8): one per kind growing, with how many.</summary>
    public IReadOnlyList<BeekeeperGardenRow> PlantRows =>
        Config.Plants.Select(p => new BeekeeperGardenRow(p, Engine.PlantCount(p.Id)))
            .Where(r => r.Count > 0).ToList();
    // Cut in stage 6 (spec 014): counts of forager and guard bees (now specialties).
    // public decimal ForagerBees => State.ForagerBees;
    // public decimal GuardBees => State.GuardBees;
    public decimal Pollen => State.Pollen;
    public decimal BeeBread => State.BeeBread;
    public bool PollenRevealed => State.PollenRevealed;
    public bool BeeBreadRevealed => State.BeeBreadRevealed;
    public bool HasWoodenHive => State.HasWoodenHive;
    public bool WoodenHiveOffered => Engine.WoodenHiveOffered;
    public bool CanPlantSeed => Engine.CanPlantSeed;
    public bool CanPlantSeedOf(string plantId) => Engine.CanPlantSeedOf(plantId);
    public bool CanMakeBeeBread => Engine.CanMakeBeeBread;
    public bool CanMoveToWoodenHive => Engine.CanMoveToWoodenHive;

    // Stage 5: the queen and the trade agreement
    /// <summary>The Queen row shows once she has settled into the wooden hive.</summary>
    public bool HasQueen => Engine.HasQueen;
    public bool IsQueenLaying => Engine.IsQueenLaying;
    /// <summary>Bees a second the queen raises right now (0 while she rests).</summary>
    /// <summary>A Hive row that has both a rate and a cap: the shared place "time to full" is worked
    /// out (<see cref="BeekeeperEngine.SecondsToFull"/>). <paramref name="shown"/> is the number the row
    /// displays; <paramref name="exact"/> is the true amount the time is worked from.</summary>
    public static BeekeeperHiveRow CappedRow(string id, bool visible, decimal shown, decimal exact, decimal cap, decimal rate) =>
        new(id, visible, shown, cap, rate, SecondsToFull: BeekeeperEngine.SecondsToFull(exact, cap, rate));

    /// <summary>What the free bees add to the comb honey right now, as a percent ("0.4"); capped by the config.</summary>
    public decimal FreeBeeHoneyBonusPercent => (Engine.FreeBeeHoneyFactor - 1m) * 100m;

    /// <summary>Where the honey comes from: the combs and (stage 8) the meadow, before any boost.</summary>
    public IReadOnlyList<BeekeeperSource> HoneySourcesNow
    {
        get
        {
            if (!Engine.HiveStarted) return Array.Empty<BeekeeperSource>();
            var sources = new List<BeekeeperSource> { new("combs", State.Combs * Config.HoneyPerCombPerSecond, State.Combs) };
            if (State.HasMeadow) sources.Add(new("meadow", Engine.MeadowHoneyPerSecond));
            return sources;
        }
    }
    // Cut in stage 8 (spec 017): combs only.
    // public IReadOnlyList<BeekeeperSource> HoneySourcesNow =>
    //     Engine.HiveStarted
    //         ? new[] { new BeekeeperSource("combs", State.Combs * Config.HoneyPerCombPerSecond, State.Combs) }
    //         : Array.Empty<BeekeeperSource>();

    /// <summary>Stage 8 (FR-805): each plant kind adding to <paramref name="target"/> right now, as a
    /// hover boost ("Wildflowers ×49: +49%").</summary>
    public IReadOnlyList<BeekeeperBoost> PlantBoosts(string target) =>
        Engine.PlantBonusSources(target)
            .Select(x => new BeekeeperBoost(BeekeeperBeeTab.PlantBoost, x.Share * 100m, x.Plant.Id, x.Extra)).ToList();

    /// <summary>Where the wax comes from: the drip, and the free bees (before any boost).</summary>
    public IReadOnlyList<BeekeeperSource> WaxSourcesNow
    {
        get
        {
            var sources = new List<BeekeeperSource> { new("wax_drip", Config.WaxBasePerSecond) };
            if (State.Bees > 0m) sources.Add(new("free_bees", State.Bees * Config.WaxPerFreeBeePerSecond, Math.Floor(State.Bees)));
            return sources;
        }
    }

    /// <summary>Where new bees come from on their own: the queen (while she lays) and Wanderers.</summary>
    public IReadOnlyList<BeekeeperSource> BeeSourcesNow
    {
        get
        {
            var sources = new List<BeekeeperSource>();
            if (Engine.IsQueenLaying) sources.Add(new("queen", Engine.QueenBeesPerSecondNow));
            if (Engine.IsHerb(BeekeeperHerbs.Wanderers))
                sources.Add(new(BeekeeperHerbs.Wanderers, Config.HerbWanderersBeesPerMinute / 60m));
            return sources;
        }
    }

    /// <summary>Boosts on the bees: nursing speeds the queen (already in her rate).</summary>
    public IReadOnlyList<BeekeeperBoost> BeeBoostsNow =>
        Engine.IsQueenLaying && Engine.NursingMultiplier > 1m
            ? new[] { new BeekeeperBoost("nursing", (Engine.NursingMultiplier - 1m) * 100m) }
            : Array.Empty<BeekeeperBoost>();

    /// <summary>The honey boosts on right now: the lasting ones (the wooden hive, guarding, the free
    /// bees' bonus) and the passing ones (the Smoker, Busy Bees, the two propolis candles), for the
    /// honey hover. Each is already in the rate; this says where it comes from.</summary>
    public IReadOnlyList<BeekeeperBoost> HoneyBoostsNow
    {
        get
        {
            var boosts = new List<BeekeeperBoost>();
            if (State.HasWoodenHive) boosts.Add(new("wooden_hive", WoodenHiveBonusPercent));
            if (Engine.GuardingMultiplier > 1m) boosts.Add(new("guarding", (Engine.GuardingMultiplier - 1m) * 100m));
            // hidden until the bonus reaches 0.01% (below that it would read "+0%")
            if (FreeBeeHoneyBonusPercent >= 0.01m) boosts.Add(new("free_bees", FreeBeeHoneyBonusPercent));
            boosts.AddRange(PlantBoosts(BeekeeperBonusTargets.Honey));   // stage 8: wildflowers and bramble past the first
            if (Engine.IsSmokerBoosted) boosts.Add(new("smoker", Engine.SmokerBoostPercentNow));
            if (Engine.IsHerb(BeekeeperHerbs.BusyBees)) boosts.Add(new(BeekeeperHerbs.BusyBees, (Config.HerbHoneyMultiplier - 1m) * 100m));
            if (Engine.IsBeeBoosted) boosts.Add(new("bee_boost", BeeBoostBonusPercent));
            if (Engine.IsSagePropolisBurning) boosts.Add(new("sage_propolis", SagePropolisBonusPercent));
            return boosts;
        }
    }

    /// <summary>The wax boosts on right now (the Wax-Catchers, Wax Makers), for the wax hover.</summary>
    public IReadOnlyList<BeekeeperBoost> WaxBoostsNow
    {
        get
        {
            var boosts = new List<BeekeeperBoost>();
            // Stage 8: the Wax-Catchers alone (WaxMultiplier now holds the clover's bonus too).
            if (Engine.WaxCatcherFactor > 1m) boosts.Add(new("wax_catcher", (Engine.WaxCatcherFactor - 1m) * 100m));
            // Cut in stage 8: if (Engine.WaxMultiplier > 1m) boosts.Add(new("wax_catcher", (Engine.WaxMultiplier - 1m) * 100m));
            boosts.AddRange(PlantBoosts(BeekeeperBonusTargets.Wax));   // stage 8: clover past the first
            if (Engine.IsHerb(BeekeeperHerbs.Wax)) boosts.Add(new(BeekeeperHerbs.Wax, (Config.HerbWaxMultiplier - 1m) * 100m));
            return boosts;
        }
    }

    public decimal QueenBeesPerSecond => Engine.QueenBeesPerSecondNow;
    /// <summary>Bee bread a second the brood eats right now (0 while she rests).</summary>
    public decimal BeeBreadPerSecond => Engine.BeeBreadPerSecondNow;
    /// <summary>How long the pantry lasts at this rate (0 while she rests).</summary>
    public decimal PantrySecondsLeft => Engine.PantrySecondsLeft;
    public bool HasTradeAgreement => State.HasTradeAgreement;
    /// <summary>Honey in one bundle right now (10, or 8 under the agreement).</summary>
    public decimal HoneyPerTradeNow => Engine.HoneyPerTradeNow;
    public decimal HerbsPerTradeNow => Engine.HerbsPerTradeNow;
    // Cut in stage 7.5 (spec 016): the agreement no longer sells honey by itself.
    // /// <summary>Beebits a second the bear's agreement brings while the combs are full.</summary>
    // public decimal AgreementBeebitsPerSecond => Engine.AgreementBeebitsPerSecondNow;

    // Stage 6: specialties and the wasp emissary
    /// <summary>The hive's specialties (foraging, guarding, nursing, resin), from the sprouted plants.</summary>
    public IReadOnlyList<string> Specialties => Engine.Specialties;
    public long BribesTotal => State.BribesTotal;
    public bool EmissaryCome => Engine.EmissaryCome;
    public long WaspTrades => State.WaspTrades;
    public decimal Paper => State.Paper;
    public bool CanTradePaper => Engine.CanTradePaper;

    // Stage 7: the poplar, propolis, the two candles and the Notebook
    public decimal Propolis => State.Propolis;
    /// <summary>The two propolis candles' recipes show at The Workbench once the poplar has sprouted.</summary>
    public bool PropolisCandlesShown => Engine.PropolisCandlesShown;
    public decimal BeeBoostCandles => State.BeeBoostCandles;
    public decimal SagePropolisCandles => State.SagePropolisCandles;
    public decimal BeeBoostSecondsLeft => State.BeeBoostSecondsLeft;
    public decimal SagePropolisSecondsLeft => State.SagePropolisSecondsLeft;
    public bool CanCraftBeeBoost => Engine.CanCraftBeeBoost;
    public bool CanCraftSagePropolis => Engine.CanCraftSagePropolis;
    public bool CanLightBeeBoost => Engine.CanLightBeeBoost;
    public bool CanLightSagePropolis => Engine.CanLightSagePropolis;
    public bool CanCraftBeeBoostTimes(int n) => Engine.CanCraftBeeBoostTimes(n);
    public bool CanCraftSagePropolisTimes(int n) => Engine.CanCraftSagePropolisTimes(n);
    public void CraftBeeBoostTimes(int n) => Apply(Engine.CraftBeeBoost(n));
    public void CraftSagePropolisTimes(int n) => Apply(Engine.CraftSagePropolis(n));

    /// <summary>The Notebook (bought with paper) brings the Bees card back.</summary>
    public bool HasNotebook => Engine.Owns(BeekeeperUpgrades.Notebook);

    /// <summary>The Notebook's notes: the queen once she has settled, then each specialty the hive has,
    /// in the order they came. The view turns an id into its note.</summary>
    public IReadOnlyList<string> NotebookNotes
    {
        get
        {
            var notes = new List<string>();
            if (Engine.HasQueen) notes.Add(BeekeeperNotes.Queen);
            notes.AddRange(Engine.Specialties);
            return notes;
        }
    }
    public bool CanTradePaperTimes(int n) => Engine.CanTradePaperTimes(n);
    public void TradePaperTimes(int n) => Apply(Engine.TradeForPaper(n));

    // Stage 8 (spec 017): wood, the wood upgrades, the bee hotel, the meadow and the Bees tab
    public decimal Wood => State.Wood;
    /// <summary>The Wood row and the Bees tab's carpenter bee: the first willow has been planted.</summary>
    public bool HasCarpenterBee => Engine.HasCarpenterBee;
    /// <summary>Wood a second right now (the willows' bonus included).</summary>
    public decimal WoodPerSecond => Engine.WoodPerSecondNow;
    /// <summary>The Honey Super row: it costs wood, so it waits for the first wood.</summary>
    public bool HoneySuperShown => Engine.HoneySuperShown;
    /// <summary>Each candle's wax price now (halved by the Dipping Rack, rounded down).</summary>
    public decimal HerbalCandleWaxNow => Engine.HerbalCandleWaxNow;
    public decimal BeeBoostCandleWaxNow => Engine.BeeBoostCandleWaxNow;
    public decimal SagePropolisCandleWaxNow => Engine.SagePropolisCandleWaxNow;
    /// <summary>Candles one craft makes (2 with the Candle Molds).</summary>
    public int CandlesPerCraft => Engine.CandlesPerCraft;
    /// <summary>A candle row's wax price is above the wax cap (it follows the Dipping Rack).</summary>
    public bool CandleIsWall(decimal waxNow) => Engine.IsWaxWall(waxNow);
    public bool HasBeeHotel => Engine.HasBeeHotel;
    /// <summary>Seconds until the bee hotel's next gift (0 without the hotel).</summary>
    public decimal HotelSecondsToNext => Engine.HasBeeHotel ? State.HotelSecondsToNext : 0m;

    /// <summary>The meadow: offered on the Hive card once one wildflower and one clover are planted.</summary>
    public bool MeadowOffered => Engine.MeadowOffered;
    public bool CanBuyMeadow => Engine.CanBuyMeadow;
    public bool HasMeadow => State.HasMeadow;
    public int MeadowWildflowersHave => Engine.PlantCount(BeekeeperPlants.Wildflowers);
    public int MeadowCloverHave => Engine.PlantCount(BeekeeperPlants.Clover);
    public int MeadowWildflowersNeed => Config.MeadowWildflowers;
    public int MeadowCloverNeed => Config.MeadowClover;
    /// <summary>What the meadow gives, for its blurb: honey a second (before boosts) and the room it adds.</summary>
    public decimal MeadowHoneyPerSecond => Config.MeadowHoneyPerSecond;
    public decimal MeadowHoneyRoom => Config.MeadowHoneyCap * Engine.StorageMultiplier;
    public decimal MeadowWaxRoom => Config.MeadowWaxCap * Engine.StorageMultiplier;

    /// <summary>How many of a plant kind are growing (the Garden card).</summary>
    public int PlantCount(string plantId) => Engine.PlantCount(plantId);
    /// <summary>One plant kind's bonus right now, in percent (each one after the first: +1%).</summary>
    public decimal PlantBonusPercent(BeekeeperPlant plant) => Engine.PlantBonusShare(plant) * 100m;

    /// <summary>The Bees tab (FR-813): every bee the hive has, in the order they came: the honeybees
    /// (from the first bee caught), the queen (once settled), the carpenter bee, then each rare bee
    /// after its first gift. The view adds what each does and a fact.</summary>
    public IReadOnlyList<string> BeesMet
    {
        get
        {
            var bees = new List<string>();
            if (Engine.HiveStarted) bees.Add(BeekeeperBees.Honey);
            if (Engine.HasQueen) bees.Add(BeekeeperBees.Queen);
            if (Engine.HasCarpenterBee) bees.Add(BeekeeperBees.Carpenter);
            bees.AddRange(State.RareBeesMet);
            return bees;
        }
    }

    [RelayCommand(CanExecute = nameof(CanBuyMeadow))]
    public void BuyMeadow() => Apply(Engine.BuyMeadow());

    /// <summary>The Hive card, in groups (spec 014, FR-505): Bees, The hive, Garden, Crafts, Trade goods.</summary>
    public IReadOnlyList<BeekeeperHiveGroup> HiveGroups
    {
        get
        {
            var specialties = Engine.Specialties;
            var bees = new List<BeekeeperHiveRow>
            {
                // Stage 7.5: free bees (they can be 0 in a running game).
                new(BeekeeperHiveRows.Honeybees, true, State.Bees,
                    Rate: Engine.HasQueen || BeeSourcesNow.Count > 0 ? BeeSourcesNow.Sum(x => x.PerSecond) : null,
                    Sources: BeeSourcesNow, Boosts: BeeBoostsNow),
                new(BeekeeperHiveRows.Queen, Engine.HasQueen, Engine.IsQueenLaying ? 1m : 0m),
            };
            foreach (var id in specialties)
            {
                // Cut (Bee, 2026-11-11): the "Foraging: 3 pollen a minute" line. The Pollen row's hover still names foraging.
                // if (id == BeekeeperSpecialties.Foraging)
                //     bees.Add(new(BeekeeperHiveRows.Foraging, true, Engine.ForagingPollenPerMinute));
                // else
                if (id == BeekeeperSpecialties.Guarding)
                    bees.Add(new(BeekeeperHiveRows.Guarding, true, (Engine.GuardingMultiplier - 1m) * 100m));
                else if (id == BeekeeperSpecialties.Nursing)
                    bees.Add(new(BeekeeperHiveRows.Nursing, true, (Engine.NursingMultiplier - 1m) * 100m));
                else if (id == BeekeeperSpecialties.Resin)
                    bees.Add(new(BeekeeperHiveRows.Resin, true, Engine.ResinPropolisPerMinute));
            }
            // Cut in stage 6 (spec 014): the forager and guard counts.
            // bees.Add(new(BeekeeperHiveRows.Foragers, State.ForagerBees > 0m, Math.Floor(State.ForagerBees)));
            // bees.Add(new(BeekeeperHiveRows.Guards, State.GuardBees > 0m, Math.Floor(State.GuardBees)));

            return new[]
            {
                new BeekeeperHiveGroup(BeekeeperHiveRows.GroupBees, bees),
                new BeekeeperHiveGroup(BeekeeperHiveRows.GroupHive, new BeekeeperHiveRow[]
                {
                    // Stage 7.5 (spec 016): honey from the first bee; wax with its cap, rounded down.
                    CappedRow(BeekeeperHiveRows.Honey, Engine.HiveStarted, State.Honey, State.Honey, Engine.HoneyStorage, Engine.HoneyPerSecondNow)
                        with { Rate2 = FreeBeeHoneyBonusPercent, Boosts = HoneyBoostsNow, Sources = HoneySourcesNow },
                    CappedRow(BeekeeperHiveRows.Wax, State.WaxRevealed, Math.Floor(State.Wax), State.Wax, Engine.WaxStorage, Engine.WaxPerSecondNow)
                        with { Boosts = WaxBoostsNow, Sources = WaxSourcesNow },
                    new(BeekeeperHiveRows.Combs, State.CombsRevealed, State.Combs),
                    // Cut (may return): the red "full" lines. A capped number is colored instead (the view reads SecondsToFull == 0).
                    // new(BeekeeperHiveRows.CombsFull, StorageIsFull && Engine.HiveStarted),
                    // new(BeekeeperHiveRows.WaxFull, State.WaxRevealed && Engine.IsWaxFull),
                    // Cut in stage 7.5 (spec 016):
                    // new(BeekeeperHiveRows.Honey, true, State.Honey, Engine.HoneyStorage, Engine.HoneyPerSecondNow),
                    // new(BeekeeperHiveRows.Wax, State.WaxRevealed, State.Wax, Rate: Engine.WaxPerSecondNow),
                    // new(BeekeeperHiveRows.CombsFull, StorageIsFull),
                }),
                new BeekeeperHiveGroup(BeekeeperHiveRows.GroupGarden, new BeekeeperHiveRow[]
                {
                    new(BeekeeperHiveRows.Seeds, State.GardenRevealed, State.SeedsInHand.Count),
                    new(BeekeeperHiveRows.Pollen, Engine.PollenShown, Math.Floor(State.Pollen),
                        Rate: Engine.ForagingPollenPerMinute > 0m ? Engine.PollenPerSecondNow : null,
                        Sources: Engine.ForagingPollenPerMinute > 0m ? new[] { new BeekeeperSource("foraging", Engine.PollenPerSecondNow) } : null),
                    new(BeekeeperHiveRows.BeeBread, State.BeeBreadRevealed, State.BeeBread,
                        Rate: Engine.HasQueen ? Engine.BeeBreadPerSecondNow : null, Rate2: Engine.PantrySecondsLeft),
                    // Stage 8: the resin's own rate as the source, the poplars past the first as a boost.
                    new(BeekeeperHiveRows.Propolis, Engine.PropolisShown,
                        Math.Floor(State.Propolis), Rate: Engine.ResinPropolisPerMinute > 0m ? Engine.PropolisPerSecondNow : null,
                        Sources: Engine.ResinPropolisPerMinute > 0m ? new[] { new BeekeeperSource("resin", Engine.ResinPropolisPerMinute / 60m) } : null,
                        Boosts: PlantBoosts(BeekeeperBonusTargets.Propolis)),
                    // Cut in stage 8: Sources: ... new BeekeeperSource("resin", Engine.PropolisPerSecondNow) ...
                    // Stage 8 (spec 017): wood from the carpenter bee, with the willows' bonus. No cap.
                    new(BeekeeperHiveRows.Wood, Engine.WoodShown, Math.Floor(State.Wood),
                        Rate: Engine.HasCarpenterBee ? Engine.WoodPerSecondNow : null,
                        Sources: Engine.HasCarpenterBee ? new[] { new BeekeeperSource("carpenter_bee", Config.WoodPerMinute / 60m) } : null,
                        Boosts: PlantBoosts(BeekeeperBonusTargets.Wood)),
                }),
                new BeekeeperHiveGroup(BeekeeperHiveRows.GroupCrafts, new BeekeeperHiveRow[]
                {
                    new(BeekeeperHiveRows.RepellentCandles, Engine.RepellentCandlesRowShown, State.RepellentCandles),
                    new(BeekeeperHiveRows.BeeBoostCandles, Engine.BeeBoostCandlesShown, State.BeeBoostCandles),
                    new(BeekeeperHiveRows.SagePropolisCandles, Engine.SagePropolisCandlesShown, State.SagePropolisCandles),
                    new(BeekeeperHiveRows.BeeBoostBurning, Engine.IsBeeBoosted, State.BeeBoostSecondsLeft),
                    new(BeekeeperHiveRows.SagePropolisBurning, Engine.IsSagePropolisBurning, State.SagePropolisSecondsLeft),
                }),
                new BeekeeperHiveGroup(BeekeeperHiveRows.GroupTradeGoods, new BeekeeperHiveRow[]
                {
                    new(BeekeeperHiveRows.Beebits, State.BeebitsRevealed, State.Beebits),
                    new(BeekeeperHiveRows.Herbs, State.HerbsRevealed, State.Herbs),
                    new(BeekeeperHiveRows.Paper, Engine.PaperShown, State.Paper),
                }),
            };
        }
    }

    /// <summary>Story log, newest first.</summary>
    public IReadOnlyList<BeekeeperLogEntry> Log => State.Log;

    public bool CanSell => Engine.CanSell;
    public bool CanBuyNextTool => Engine.CanBuyNextTool;
    public bool CanBuyWaxCatcher => Engine.CanBuyWaxCatcher;
    public bool CanBuildComb => Engine.CanBuildComb;

    // ---- stage 7.5: walls and capacity upgrades. A wall (a price above a cap) is its own state,
    // separate from "can't afford yet": the view only reads these (spec 016, FR-710).
    /// <summary>The comb row is on screen (the Combs panel, at The Workbench).</summary>
    public bool CombRowShown => Engine.CombRowShown;
    /// <summary>The next comb's wax price is above the wax cap: it needs more storage.</summary>
    public bool CombIsWall => Engine.CombIsWall;
    /// <summary>The wooden hive's wax price is above the wax cap.</summary>
    public bool WoodenHiveIsWall => Engine.WoodenHiveIsWall;
    /// <summary>A Shop upgrade's wax price is above the wax cap.</summary>
    public bool UpgradeIsWall(string id) => Engine.UpgradeIsWall(id);
    /// <summary>Honey Super and Wax Tray rows (Shop open and Combs panel shown).</summary>
    public bool CapacityUpgradesShown => Engine.CapacityUpgradesShown;
    public int HoneySupers => State.HoneySupers;
    public int WaxTrays => State.WaxTrays;
    public decimal HoneySuperCost => Engine.HoneySuperCost;
    public decimal WaxTrayCost => Engine.WaxTrayCost;
    public decimal HoneySuperCapacity => Config.HoneySuperCapacity * Engine.StorageMultiplier;
    public decimal WaxTrayCapacity => Config.WaxTrayCapacity * Engine.StorageMultiplier;
    public bool CanBuyHoneySuper => Engine.CanBuyHoneySuper;
    public bool CanBuyWaxTray => Engine.CanBuyWaxTray;

    /// <summary>What the last Catch Bee click did; <see cref="CatchSerial"/> goes up on every
    /// click so the view can play its popup even when two clicks look the same.</summary>
    public CatchResult? LastCatch { get; private set; }
    public int CatchSerial { get; private set; }

    // ------------------------------------------------------------------ player actions

    private DateTime _stingLockedUntilUtc = DateTime.MinValue;

    /// <summary>A sting just happened: Catch Bee is disabled for <see cref="BeekeeperConfig.StingLockoutSeconds"/>.</summary>
    public bool IsStingLocked => _clock() < _stingLockedUntilUtc;

    /// <summary>How long the sting lockout has left, for the button to time its own recovery.</summary>
    public TimeSpan StingLockoutLeft => IsStingLocked ? _stingLockedUntilUtc - _clock() : TimeSpan.Zero;

    [RelayCommand]
    public void Catch()
    {
        NoteActivity();
        if (IsStingLocked) return;   // the button is red and disabled for a moment after a sting
        var result = Engine.Catch();
        if (result.Stung) _stingLockedUntilUtc = _clock().AddSeconds((double)Config.StingLockoutSeconds);
        LastCatch = result;
        CatchSerial++;
        LogEvents(result.Events);
        Refresh();
    }

    [RelayCommand(CanExecute = nameof(CanSell))]
    public void SellTen() => Apply(Engine.SellTen());

    [RelayCommand(CanExecute = nameof(CanSell))]
    public void SellAll() => Apply(Engine.SellAll());

    [RelayCommand(CanExecute = nameof(CanBuyNextTool))]
    public void BuyNextTool() => Apply(Engine.BuyNextTool());

    [RelayCommand(CanExecute = nameof(CanBuyWaxCatcher))]
    public void BuyWaxCatcher() => Apply(Engine.BuyWaxCatcher());

    [RelayCommand(CanExecute = nameof(CanBuildComb))]
    public void BuildComb() => Apply(Engine.BuildComb());

    [RelayCommand(CanExecute = nameof(CanBuyHoneySuper))]
    public void BuyHoneySuper() => Apply(Engine.BuyHoneySuper());

    [RelayCommand(CanExecute = nameof(CanBuyWaxTray))]
    public void BuyWaxTray() => Apply(Engine.BuyWaxTray());


    [RelayCommand(CanExecute = nameof(CanCraftRepellent))]
    public void CraftRepellent() => Apply(Engine.CraftRepellent());

    [RelayCommand(CanExecute = nameof(CanTradeCandles))]
    public void TradeTenCandles() => Apply(Engine.TradeTenCandles());

    [RelayCommand(CanExecute = nameof(CanTradeCandles))]
    public void TradeAllCandles() => Apply(Engine.TradeAllCandles());

    [RelayCommand(CanExecute = nameof(CanThrowShoe))]
    public void ThrowShoe() => Apply(Engine.ThrowShoe());

    [RelayCommand(CanExecute = nameof(CanEngageWasp))]
    public void EngageWasp() => Apply(Engine.EngageWasp());

    public void EngageRep(string id) => Apply(Engine.EngageRep(id));
    public void ThrowShoeAtRep(string id) => Apply(Engine.ThrowShoeAtRep(id));

    // Story cards
    /// <summary>The story card showing now (a <see cref="BeekeeperStories"/> id), or null.</summary>
    public string? StoryHere => Engine.StoryHere;
    public void PutOnGloves() => Apply(Engine.PutOnGloves());
    public void LeaveGloves() => Apply(Engine.LeaveGloves());
    public void RepairSmoker() => Apply(Engine.RepairSmoker());
    /// <summary>The seed the "Plant it?" story card is about (a kind never planted), or null.</summary>
    public string? StorySeed => Engine.StorySeed;
    /// <summary>The "Plant it?" card's button (Bee, 2026-11-11).</summary>
    public void PlantFromStory() => Apply(Engine.PlantFromStory());

    /// <summary>Debug builds only: shows a story card now (<see cref="BeekeeperStories"/> id).</summary>
    public void DebugShowStory(string id)
    {
        NoteActivity();
        LogEvents(Engine.DebugShowStory(id));
        Refresh();
    }

    [RelayCommand(CanExecute = nameof(CanBribe))]
    public void Bribe() => Apply(Engine.Bribe());

    [RelayCommand(CanExecute = nameof(CanLightRepellent))]
    public void LightRepellent() => Apply(Engine.LightRepellent());

    [RelayCommand(CanExecute = nameof(HasSmoker))]
    public void UseSmoker() => Apply(Engine.UseSmoker());

    // Batches (x10, x100): the screen only offers a size when the whole batch can be paid for.
    public bool CanCraftRepellentTimes(int n) => Engine.CanCraftRepellentTimes(n);
    public bool CanMakeBeeBreadTimes(int n) => Engine.CanMakeBeeBreadTimes(n);
    public void CraftRepellentTimes(int n) => Apply(Engine.CraftRepellent(n));
    public void MakeBeeBreadTimes(int n) => Apply(Engine.MakeBeeBread(n));

    /// <summary>Plants one seed (stage 8: it grows at once): the named kind, or the first in hand when null.</summary>
    [RelayCommand(CanExecute = nameof(CanPlantSeed))]
    public void PlantSeed(string? plantId) => Apply(Engine.PlantSeed(plantId));

    [RelayCommand(CanExecute = nameof(CanCraftBeeBoost))]
    public void CraftBeeBoost() => Apply(Engine.CraftBeeBoost());

    [RelayCommand(CanExecute = nameof(CanCraftSagePropolis))]
    public void CraftSagePropolis() => Apply(Engine.CraftSagePropolis());

    [RelayCommand(CanExecute = nameof(CanLightBeeBoost))]
    public void LightBeeBoost() => Apply(Engine.LightBeeBoost());

    [RelayCommand(CanExecute = nameof(CanLightSagePropolis))]
    public void LightSagePropolis() => Apply(Engine.LightSagePropolis());

    // Herbal candles (lit with LightRepellent): each rolls one buff; one burns at a time.
    /// <summary>The buff the lit herbal candle rolled, or null when none burns.</summary>
    public string? HerbBuff => Engine.IsHerbBurning ? State.HerbBuff : null;
    public decimal HerbSecondsLeft => State.HerbSecondsLeft;

    [RelayCommand(CanExecute = nameof(CanMakeBeeBread))]
    public void MakeBeeBread() => Apply(Engine.MakeBeeBread());

    [RelayCommand(CanExecute = nameof(CanMoveToWoodenHive))]
    public void MoveToWoodenHive() => Apply(Engine.MoveToWoodenHive());

    // Cut in stage 8 (spec 017, FR-817): "Give seed" and "Give every seed" (seeds given once each).
    // public void DebugGiveSeed() { LogEvents(Engine.DebugGiveSeed()); SaveNow(); Refresh(); }
    // public void DebugGiveEverySeed() { LogEvents(Engine.DebugGiveEverySeed()); SaveNow(); Refresh(); }

    /// <summary>Debug builds only: the next seed joins its roll.</summary>
    public void DebugUnlockNextSeed() => DebugDo(Engine.DebugUnlockNextSeed());

    /// <summary>Debug builds only: every seed joins its roll.</summary>
    public void DebugUnlockEverySeed() => DebugDo(Engine.DebugUnlockEverySeed());

    /// <summary>Debug builds only: +10 of every seed in hand.</summary>
    public void DebugGiveTenOfEverySeed() => DebugDo(Engine.DebugGiveSeedsOfEvery(10));

    /// <summary>Debug builds only: the meadow's price straight into the garden (+50 wildflowers and +50 clover).</summary>
    public void DebugPlantMeadowPrice() => DebugDo(Engine.DebugPlant(BeekeeperPlants.Wildflowers, Config.MeadowWildflowers)
        .Concat(Engine.DebugPlant(BeekeeperPlants.Clover, Config.MeadowClover)).ToList());

    /// <summary>Debug builds only: hands out wood.</summary>
    public void DebugGiveWood(decimal wood) => DebugDo(Engine.DebugGiveWood(wood));

    /// <summary>Debug builds only: the carpenter bee comes now.</summary>
    public void DebugSummonCarpenterBee() => DebugDo(Engine.DebugSummonCarpenterBee());

    /// <summary>Debug builds only: a bee hotel gift now (once the hotel is bought).</summary>
    public void DebugHotelGift() => DebugDo(Engine.DebugHotelGift());

    private void DebugDo(IReadOnlyList<BeekeeperEvent> events)
    {
        LogEvents(events);
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: hands out propolis.</summary>
    public void DebugGivePropolis(decimal propolis)
    {
        LogEvents(Engine.DebugGivePropolis(propolis));
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: hands out paper.</summary>
    public void DebugGivePaper(decimal paper)
    {
        LogEvents(Engine.DebugGivePaper(paper));
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: the Hippie trades go to 199; one more brings the willow seed.</summary>
    public void DebugHippieTradesTo199()
    {
        LogEvents(Engine.DebugHippieTradesTo199());
        SaveNow();
        Refresh();
    }

    // Cut in stage 8 (spec 017): plants grow at once.
    // /// <summary>Debug builds only: every growing seed sprouts now.</summary>
    // public void DebugFinishGrowing() { LogEvents(Engine.DebugFinishGrowing()); SaveNow(); Refresh(); }

    /// <summary>Debug builds only: hands out pollen.</summary>
    public void DebugGivePollen(decimal pollen)
    {
        LogEvents(Engine.DebugGivePollen(pollen));
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: hands out bee bread.</summary>
    public void DebugGiveBeeBread(decimal beeBread)
    {
        LogEvents(Engine.DebugGiveBeeBread(beeBread));
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: one more sale to the bear brings the trade agreement.</summary>
    public void DebugBearTradesToAlmostAgreement()
    {
        LogEvents(Engine.DebugBearTradesToAlmostAgreement());
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: one more bribe brings the emissary.</summary>
    public void DebugBribesToAlmostEmissary()
    {
        Engine.DebugBribesToAlmostEmissary();
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: the emissary comes now.</summary>
    public void DebugBringEmissary()
    {
        LogEvents(Engine.DebugBringEmissary());
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: hands out honey.</summary>
    public void DebugGiveHoney(decimal honey)
    {
        LogEvents(Engine.DebugGiveHoney(honey));
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: the hive has ten times the bees (or 10 if it has none).</summary>
    public void DebugMultiplyBees()
    {
        decimal extra = State.Bees > 0m ? State.Bees * 9m : 10m;
        LogEvents(Engine.DebugGrant(extra, 0m, 0m));
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only (stage 7.5): five more combs, free of charge.</summary>
    public void DebugAddCombs(int count)
    {
        LogEvents(Engine.DebugAddCombs(count));
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only (stage 7.5): wax up to the wax cap.</summary>
    public void DebugFillWax()
    {
        LogEvents(Engine.DebugFillWax());
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: credits time away as if the app had been closed, welcome-back lines included.</summary>
    public void DebugSpendAway(decimal seconds)
    {
        LogAway(Engine.AdvanceAway(seconds));
        _lastTickUtc = _clock();
        SaveNow();
        Refresh();
    }

    /// <summary>Buys a Shop upgrade by id (the Shop draws its rows from <see cref="ShopUpgrades"/>).</summary>
    public void BuyUpgrade(string id) => Apply(Engine.BuyUpgrade(id));

    private void Apply(ActionResult result)
    {
        NoteActivity();
        if (result.Done) LogEvents(result.Events);
        Refresh();
    }

    /// <summary>The player clicked or pressed a key on the Beekeeper screen. Wasps only come
    /// to a player who has done this in the last few minutes.</summary>
    public void NoteActivity() => _lastActivityUtc = _clock();

    /// <summary>Debug builds only: a wasp arrives now (once The Workbench is open).</summary>
    public void DebugCallWasp()
    {
        NoteActivity();
        LogEvents(Engine.DebugCallWasp());
        Refresh();
    }

    /// <summary>The "Start over? Your hive will be lost." question is only asked when there
    /// is something to lose: once the first bee has been caught, even with 0 free bees left (stage
    /// 7.5, FR-713). A brand-new hive with no bee caught yet starts over silently.</summary>
    public bool NewGameNeedsConfirmation => Engine.HiveStarted;
    // Cut in stage 7.5 (spec 016): public bool NewGameNeedsConfirmation => State.Bees > 0m;

    /// <summary>Starts over. The view calls this after any confirmation.</summary>
    public void StartNewGame()
    {
        var events = Engine.StartNewGame();
        _carrySeconds = 0m;
        _lastTickUtc = _clock();
        _lastActivityUtc = _lastTickUtc;
        LogEvents(events);
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: see <see cref="BeekeeperEngine.DebugGrant"/>. Saved at once.</summary>
    public void DebugGrant(decimal bees, decimal wax, decimal beebits)
    {
        LogEvents(Engine.DebugGrant(bees, wax, beebits));
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: the hive works for <paramref name="seconds"/> at once, as in live play.</summary>
    public void DebugSkip(decimal seconds)
    {
        LogEvents(Engine.Advance(seconds).Events);
        SaveNow();
        Refresh();
    }

    // ------------------------------------------------------------------ time

    /// <summary>
    /// Moves the hive forward to "now". Normal ticks (about a second apart) feed the engine
    /// whole seconds and carry the leftover fraction. A gap longer than the away threshold
    /// (sleep, a frozen window) is credited as time away instead: capped at 3 days, nothing
    /// for a clock that went backwards.
    /// </summary>
    public void Tick()
    {
        if (_disposed) return;

        var now = _clock();
        decimal gap = (decimal)(now - _lastTickUtc).TotalSeconds;
        _lastTickUtc = now;
        if (gap <= 0m) return;

        bool away = Engine.IsAway(gap);
        if (away)
        {
            // The app was open the whole time, so the honey is credited quietly: only
            // reopening the app says "While you were away" (Leah, 2026-11-07). The engine tells
            // an empty pantry or a burnt-out candle the live way.
            LogEvents(Engine.AdvanceGap(gap).Events);
        }
        else
        {
            _carrySeconds += gap;
            decimal whole = Math.Floor(_carrySeconds);
            if (whole >= 1m)
            {
                _carrySeconds -= whole;
                LogEvents(Engine.Advance(whole).Events);
            }
        }

        AdvanceWasps(gap, away, now);
        if (!away) LogEvents(Engine.AdvanceRepTime(gap));
        if (!away) LogEvents(Engine.AdvanceStoryTime(gap));   // play time only: the 2 minutes don't pass while away

        _secondsSinceSave += gap;
        if (_secondsSinceSave >= AutosaveEverySeconds) SaveNow();

        Refresh();
    }

    /// <summary>
    /// Wasps only bother a player who can respond: Beekeeper on screen and a click or key in
    /// the last few minutes. An approaching wasp runs its countdown on real time and leaves
    /// (nothing lost) if the player steps away, goes idle or the computer slept. Otherwise
    /// "wasp time" passes. No Stress Mode no longer stops wasps (spec 014); the emissary does,
    /// for good (the engine ignores wasp time after it).
    /// </summary>
    private void AdvanceWasps(decimal gap, bool away, DateTime now)
    {
        bool watching = IsWatched && (decimal)(now - _lastActivityUtc).TotalSeconds <= Config.IdleSeconds;
        if (Engine.WaspApproaching)
        {
            LogEvents(away || !watching ? Engine.WaspLeaves() : Engine.AdvanceWaspCountdown(gap));
            return;
        }
        if (!away && watching) LogEvents(Engine.AdvanceWaspTime(gap));
        // Cut in stage 6 (spec 014): No Stress Mode kept wasps away.
        // if (!away && watching && !_noStressMode()) LogEvents(Engine.AdvanceWaspTime(gap));
    }

    /// <summary>Writes the game to disk now (also done every few seconds, on New Game and on close).</summary>
    public bool SaveNow()
    {
        _secondsSinceSave = 0m;
        return _savePath is not null && !_saveBlocked && BeekeeperSaveService.Save(State, _savePath, _clock());
    }

    private void StartTimer()
    {
        _timer = new Timer(_ =>
        {
            // Everything runs on the UI thread, like the card games' timers.
            if (_syncContext is not null) _syncContext.Post(__ => Tick(), null);
            else Tick();
        }, null, 1000, 1000);
    }

    // ------------------------------------------------------------------ log and refresh

    /// <summary>Time away: what happened, then the welcome-back lines. The log shows the newest
    /// line first, and the engine gives the lines top first, so they go in bottom line first.</summary>
    private void LogAway(AwayResult away)
    {
        LogEvents(away.Events);
        LogEvents(away.WelcomeBack.Reverse());
    }

    private void LogEvents(IEnumerable<BeekeeperEvent> events)
    {
        foreach (var e in events)
        {
            // A sting is shown as a popup only; logging every one would drown the story.
            if (e.Key == BeekeeperEvents.Sting) continue;
            // A story card speaks for itself: no log line when it arrives.
            if (e.Key == BeekeeperEvents.StoryArrives) continue;

            State.Log.Insert(0, new BeekeeperLogEntry { Key = e.Key, Value = e.Value, Value2 = e.Value2, Text = e.Text });
        }
        while (State.Log.Count > BeekeeperSaveService.MaxLogEntries)
            State.Log.RemoveAt(State.Log.Count - 1);
    }

    private void Refresh()
    {
        OnPropertyChanged(string.Empty); // every property above may have changed
        SellTenCommand.NotifyCanExecuteChanged();
        SellAllCommand.NotifyCanExecuteChanged();
        BuyNextToolCommand.NotifyCanExecuteChanged();
        BuyWaxCatcherCommand.NotifyCanExecuteChanged();
        BuildCombCommand.NotifyCanExecuteChanged();
        BuyHoneySuperCommand.NotifyCanExecuteChanged();
        BuyWaxTrayCommand.NotifyCanExecuteChanged();
        CraftRepellentCommand.NotifyCanExecuteChanged();
        TradeTenCandlesCommand.NotifyCanExecuteChanged();
        TradeAllCandlesCommand.NotifyCanExecuteChanged();
        ThrowShoeCommand.NotifyCanExecuteChanged();
        EngageWaspCommand.NotifyCanExecuteChanged();
        BribeCommand.NotifyCanExecuteChanged();
        LightRepellentCommand.NotifyCanExecuteChanged();
        UseSmokerCommand.NotifyCanExecuteChanged();
        PlantSeedCommand.NotifyCanExecuteChanged();
        CraftBeeBoostCommand.NotifyCanExecuteChanged();
        CraftSagePropolisCommand.NotifyCanExecuteChanged();
        LightBeeBoostCommand.NotifyCanExecuteChanged();
        LightSagePropolisCommand.NotifyCanExecuteChanged();
        MakeBeeBreadCommand.NotifyCanExecuteChanged();
        MoveToWoodenHiveCommand.NotifyCanExecuteChanged();
        BuyMeadowCommand.NotifyCanExecuteChanged();
    }

    public void Dispose()
    {
        if (_disposed) return;
        _timer?.Dispose();
        _timer = null;
        SaveNow();
        _disposed = true;
    }
}
