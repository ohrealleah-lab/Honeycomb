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
/// are resource names ("honey", "beebits", "beeswax_candles", "sage") the view turns into
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
/// hover); <see cref="Rate2"/> a second hover number where a row needs one (the pantry's time).
/// </summary>
public sealed record BeekeeperHiveRow(string Id, bool Visible, decimal Value = 0m, decimal Value2 = 0m,
    decimal? Rate = null, decimal Rate2 = 0m);

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

    public const string Honeybees = "honeybees";          // Value = bees; Rate = bees/s from the queen
    public const string Queen = "queen";                  // Value = 1 laying, 0 resting
    public const string Foraging = "foraging";            // full-width line; Value = pollen a minute
    public const string Guarding = "guarding";            // full-width line; Value = extra honey percent
    public const string Honey = "honey";                  // Value = stored, Value2 = storage; Rate = honey/s
    public const string Wax = "wax";                      // Rate = wax/s
    public const string Combs = "combs";
    public const string CombsFull = "combs_full";         // full-width warning line
    public const string Seeds = "seeds";
    public const string Pollen = "pollen";                // Rate = pollen/s while foraging
    public const string BeeBread = "bee_bread";           // Rate = bee bread eaten/s, Rate2 = pantry seconds
    public const string BeeswaxCandles = "beeswax_candles";
    public const string RepellentCandles = "repellent_candles";
    public const string Beebits = "beebits";
    public const string Sage = "sage";
    public const string Paper = "paper";
    // Stage 7 (spec 015)
    public const string Nursing = "nursing";              // full-width line; Value = extra laying percent
    public const string Resin = "resin";                  // full-width line; Value = propolis a minute
    public const string Propolis = "propolis";            // Rate = propolis/s while resin
    public const string BeeBoostCandles = "bee_boost_candles";
    public const string SagePropolisCandles = "sage_propolis_candles";
    public const string BeeBoostBurning = "bee_boost_burning";         // full-width line; Value = seconds left
    public const string SagePropolisBurning = "sage_propolis_burning"; // full-width line; Value = seconds left
    // Cut in stage 6 (spec 014): counts of forager and guard bees.
    // public const string Foragers = "foragers";
    // public const string Guards = "guards";
}

/// <summary>One growing bed on the Garden card: which plant and how long it has left.</summary>
public sealed record BeekeeperBedView(BeekeeperPlant Plant, decimal SecondsLeft);

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
    public string WaxDisplay => NumberFormatter.Format(State.Wax, CurrentLanguage);
    public string BeebitsDisplay => NumberFormatter.Format(State.Beebits, CurrentLanguage);

    public decimal Bees => State.Bees;
    public decimal Honey => State.Honey;
    public decimal HoneyStorage => Engine.HoneyStorage;
    /// <summary>What the hive makes right now (doubled while the bees are calm).</summary>
    public decimal HoneyPerSecond => Engine.HoneyPerSecondNow;
    /// <summary>What the hive makes in wax right now.</summary>
    public decimal WaxPerSecond => Engine.WaxPerSecondNow;
    public decimal Wax => State.Wax;
    public decimal WaxProgress => State.WaxProgress;
    public decimal HoneyPerWax => Config.HoneyPerWax;
    public decimal Beebits => State.Beebits;
    public int ToolLevel => State.ToolLevel;
    public int BeesPerClick => Engine.BeesPerClick;
    public bool HasWaxCatcher => State.HasWaxCatcher;
    public int Combs => State.Combs;
    public decimal CombCost => Engine.CombCost;
    /// <summary>Honey storage the next comb adds (bigger with the Bigger Combs upgrades).</summary>
    public decimal StoragePerComb => Engine.StoragePerComb;
    public string BearName => State.BearName;
    public long Trades => State.Trades;
    public BeekeeperTool? NextTool => Engine.NextTool;
    public bool StorageIsFull => Engine.IsStorageFull;

    // Finished values for the screen, so it does no rules or percentage maths of its own.
    /// <summary>How full the Smoker's bar is, 0 to 1: the calm time left while calm, otherwise the calm meter.</summary>
    public decimal CalmBarFraction => IsCalm
        ? CalmSecondsLeft / Config.CalmSeconds
        : (decimal)CalmMeter / Math.Max(1, CalmMeterClicks);
    /// <summary>Honey bonus of the wooden hive, as a percent ("25").</summary>
    public decimal WoodenHiveBonusPercent => (Config.WoodenHiveHoneyMultiplier - 1m) * 100m;
    public decimal BeeBoostBonusPercent => (Config.BeeBoostHoneyMultiplier - 1m) * 100m;
    public decimal SagePropolisBonusPercent => (Config.SagePropolisHoneyMultiplier - 1m) * 100m;
    /// <summary>Wasp time one repellent candle buys right now (Stronger Candles counted).</summary>
    public decimal RepellentBurnSeconds => Engine.RepellentBurnSeconds;
    /// <summary>Bees a click would catch with <paramref name="tool"/>, Practice counted.</summary>
    public int BeesPerClickWith(BeekeeperTool tool) => Engine.BeesPerClickWith(tool);
    /// <summary>Garden bed rows to draw: every bed owned (a save may hold more growing than owned).</summary>
    public int BedRowCount => Math.Max(BedCount, State.Beds.Count);

    public bool HoneyRevealed => State.HoneyRevealed;
    public bool BearRevealed => State.BearRevealed;
    public bool BeebitsRevealed => State.BeebitsRevealed;
    public bool WaxRevealed => State.WaxRevealed;
    public bool ShopRevealed => State.ShopRevealed;
    public bool CombsRevealed => State.CombsRevealed;

    // Stage 2
    public decimal BeeswaxCandles => State.BeeswaxCandles;
    public decimal RepellentCandles => State.RepellentCandles;
    public long CandlesCrafted => State.CandlesCrafted;
    public decimal Sage => State.Sage;
    public bool WorkbenchRevealed => State.WorkbenchRevealed;
    public bool HippiesRevealed => State.HippiesRevealed;
    public bool SageRevealed => State.SageRevealed;
    public bool RepellentUnlocked => State.RepellentUnlocked;
    /// <summary>The repellent candle is shown (recipe, light button, Hive row): unlocked, and
    /// not yet retired by the emissary (spec 014).</summary>
    public bool RepellentShown => Engine.RepellentShown;
    public bool WaspApproaching => Engine.WaspApproaching;
    public decimal WaspSecondsLeft => State.WaspCountdown;
    public decimal RepellentSecondsLeft => State.RepellentSecondsLeft;
    public decimal BribeCost => Engine.BribeCost;
    public IReadOnlyList<BeekeeperUpgrade> ShopUpgrades => Engine.ShopUpgrades;
    public bool CanBuyUpgrade(string id) => Engine.CanBuyUpgrade(id);
    /// <summary>The percent a Shop upgrade's blurb quotes, or null when its blurb has no number.</summary>
    public decimal? UpgradeBonusPercent(string id) => Engine.UpgradeBonusPercent(id);
    public bool CanCraftBeeswax => Engine.CanCraftBeeswax;
    public bool CanCraftRepellent => Engine.CanCraftRepellent;
    public bool CanTradeCandles => Engine.CanTradeCandles;
    public bool CanThrowShoe => Engine.WaspApproaching;
    public bool CanBribe => Engine.CanBribe;
    public bool CanLightRepellent => Engine.CanLightRepellent;

    /// <summary>Every buyer the player has met, in the order they arrived (Leah: one shared
    /// trade interface for all trades). Each trades bundles: give 10, get 1.</summary>
    public IReadOnlyList<BeekeeperTradeOffer> TradeOffers
    {
        get
        {
            var offers = new List<BeekeeperTradeOffer>();
            if (State.BearRevealed)
                offers.Add(new BeekeeperTradeOffer("bear", State.BearName, State.Trades,
                    Config.HoneyPerBeebit, "honey", 1m, "beebits", CanSell, SellTen, SellAll));
            if (State.HippiesRevealed)
                offers.Add(new BeekeeperTradeOffer("hippies", null, State.HippieTrades,
                    Config.CandlesPerSage, "beeswax_candles", 1m, "sage", CanTradeCandles, TradeTenCandles, TradeAllCandles));
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
    public int CalmMeter => State.CalmMeter;
    public int CalmMeterClicks => Config.CalmMeterClicks;
    public bool IsCalm => Engine.IsCalm;
    public decimal CalmSecondsLeft => State.CalmSecondsLeft;
    public bool CanPuff => Engine.CanPuff;

    // Stage 4: the Garden
    public bool GardenRevealed => State.GardenRevealed;
    /// <summary>Seeds in hand, not yet planted.</summary>
    public int Seeds => State.SeedsInHand.Count;
    /// <summary>The seeds in hand, as plants, each with its own Plant button.</summary>
    public IReadOnlyList<BeekeeperPlant> SeedsInHand => Engine.SeedsInHand;
    public bool IsGrowing => Engine.IsGrowing;
    // Cut in stage 7 (spec 015): one growing plant, kept a surprise. Seeds are named now.
    // public BeekeeperPlant? GrowingPlant => Engine.GrowingPlant;
    /// <summary>How many garden beds there are (two, three with the Third Bed).</summary>
    public int BedCount => Engine.BedCount;
    public int FreeBeds => Engine.FreeBeds;
    /// <summary>The beds with a seed growing, soonest to sprout first.</summary>
    public IReadOnlyList<BeekeeperBedView> GrowingBeds => State.Beds
        .Select(b => new { Bed = b, Plant = Engine.PlantById(b.PlantId) })
        .Where(x => x.Plant is not null)
        .OrderBy(x => x.Bed.SecondsLeft)
        .Select(x => new BeekeeperBedView(x.Plant!, x.Bed.SecondsLeft))
        .ToList();
    public IReadOnlyList<BeekeeperPlant> SproutedPlants => Engine.SproutedPlants;
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
    public decimal QueenBeesPerSecond => Engine.QueenBeesPerSecondNow;
    /// <summary>Bee bread a second the brood eats right now (0 while she rests).</summary>
    public decimal BeeBreadPerSecond => Engine.BeeBreadPerSecondNow;
    /// <summary>How long the pantry lasts at this rate (0 while she rests).</summary>
    public decimal PantrySecondsLeft => Engine.PantrySecondsLeft;
    public bool HasTradeAgreement => State.HasTradeAgreement;
    /// <summary>Beebits a second the bear's agreement brings while the combs are full.</summary>
    public decimal AgreementBeebitsPerSecond => Engine.AgreementBeebitsPerSecondNow;

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

    /// <summary>The Hive card, in groups (spec 014, FR-505): Bees, The hive, Garden, Crafts, Trade goods.</summary>
    public IReadOnlyList<BeekeeperHiveGroup> HiveGroups
    {
        get
        {
            var specialties = Engine.Specialties;
            var bees = new List<BeekeeperHiveRow>
            {
                new(BeekeeperHiveRows.Honeybees, true, State.Bees,
                    Rate: Engine.HasQueen ? Engine.QueenBeesPerSecondNow : null),
                new(BeekeeperHiveRows.Queen, Engine.HasQueen, Engine.IsQueenLaying ? 1m : 0m),
            };
            foreach (var id in specialties)
            {
                if (id == BeekeeperSpecialties.Foraging)
                    bees.Add(new(BeekeeperHiveRows.Foraging, true, Engine.ForagingPollenPerMinute));
                else if (id == BeekeeperSpecialties.Guarding)
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
                    new(BeekeeperHiveRows.Honey, true, State.Honey, Engine.HoneyStorage, Engine.HoneyPerSecondNow),
                    new(BeekeeperHiveRows.Wax, State.WaxRevealed, State.Wax, Rate: Engine.WaxPerSecondNow),
                    new(BeekeeperHiveRows.Combs, State.CombsRevealed, State.Combs),
                    new(BeekeeperHiveRows.CombsFull, StorageIsFull),
                }),
                new BeekeeperHiveGroup(BeekeeperHiveRows.GroupGarden, new BeekeeperHiveRow[]
                {
                    new(BeekeeperHiveRows.Seeds, State.GardenRevealed, State.SeedsInHand.Count),
                    new(BeekeeperHiveRows.Pollen, Engine.PollenShown, Math.Floor(State.Pollen),
                        Rate: Engine.ForagingPollenPerMinute > 0m ? Engine.PollenPerSecondNow : null),
                    new(BeekeeperHiveRows.BeeBread, State.BeeBreadRevealed, State.BeeBread,
                        Rate: Engine.HasQueen ? Engine.BeeBreadPerSecondNow : null, Rate2: Engine.PantrySecondsLeft),
                    new(BeekeeperHiveRows.Propolis, Engine.PropolisShown,
                        Math.Floor(State.Propolis), Rate: Engine.ResinPropolisPerMinute > 0m ? Engine.PropolisPerSecondNow : null),
                }),
                new BeekeeperHiveGroup(BeekeeperHiveRows.GroupCrafts, new BeekeeperHiveRow[]
                {
                    new(BeekeeperHiveRows.BeeswaxCandles, Engine.BeeswaxCandlesShown, State.BeeswaxCandles),
                    new(BeekeeperHiveRows.RepellentCandles, Engine.RepellentCandlesRowShown, State.RepellentCandles),
                    new(BeekeeperHiveRows.BeeBoostCandles, Engine.BeeBoostCandlesShown, State.BeeBoostCandles),
                    new(BeekeeperHiveRows.SagePropolisCandles, Engine.SagePropolisCandlesShown, State.SagePropolisCandles),
                    new(BeekeeperHiveRows.BeeBoostBurning, Engine.IsBeeBoosted, State.BeeBoostSecondsLeft),
                    new(BeekeeperHiveRows.SagePropolisBurning, Engine.IsSagePropolisBurning, State.SagePropolisSecondsLeft),
                }),
                new BeekeeperHiveGroup(BeekeeperHiveRows.GroupTradeGoods, new BeekeeperHiveRow[]
                {
                    new(BeekeeperHiveRows.Beebits, State.BeebitsRevealed, State.Beebits),
                    new(BeekeeperHiveRows.Sage, State.SageRevealed, State.Sage),
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

    /// <summary>What the last Catch Bee click did; <see cref="CatchSerial"/> goes up on every
    /// click so the view can play its popup even when two clicks look the same.</summary>
    public CatchResult? LastCatch { get; private set; }
    public int CatchSerial { get; private set; }

    // ------------------------------------------------------------------ player actions

    [RelayCommand]
    public void Catch()
    {
        NoteActivity();
        var result = Engine.Catch();
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

    [RelayCommand(CanExecute = nameof(CanCraftBeeswax))]
    public void CraftBeeswax() => Apply(Engine.CraftBeeswax());

    [RelayCommand(CanExecute = nameof(CanCraftRepellent))]
    public void CraftRepellent() => Apply(Engine.CraftRepellent());

    [RelayCommand(CanExecute = nameof(CanTradeCandles))]
    public void TradeTenCandles() => Apply(Engine.TradeTenCandles());

    [RelayCommand(CanExecute = nameof(CanTradeCandles))]
    public void TradeAllCandles() => Apply(Engine.TradeAllCandles());

    [RelayCommand(CanExecute = nameof(CanThrowShoe))]
    public void ThrowShoe() => Apply(Engine.ThrowShoe());

    [RelayCommand(CanExecute = nameof(CanBribe))]
    public void Bribe() => Apply(Engine.Bribe());

    [RelayCommand(CanExecute = nameof(CanLightRepellent))]
    public void LightRepellent() => Apply(Engine.LightRepellent());

    [RelayCommand(CanExecute = nameof(CanPuff))]
    public void PuffSmoker() => Apply(Engine.PuffSmoker());

    // Batches (x10, x100): the screen only offers a size when the whole batch can be paid for.
    public bool CanCraftBeeswaxTimes(int n) => Engine.CanCraftBeeswaxTimes(n);
    public bool CanCraftRepellentTimes(int n) => Engine.CanCraftRepellentTimes(n);
    public bool CanMakeBeeBreadTimes(int n) => Engine.CanMakeBeeBreadTimes(n);
    public void CraftBeeswaxTimes(int n) => Apply(Engine.CraftBeeswax(n));
    public void CraftRepellentTimes(int n) => Apply(Engine.CraftRepellent(n));
    public void MakeBeeBreadTimes(int n) => Apply(Engine.MakeBeeBread(n));

    /// <summary>Plants a seed in a free bed: the named one, or the first in hand when null.</summary>
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

    [RelayCommand(CanExecute = nameof(CanMakeBeeBread))]
    public void MakeBeeBread() => Apply(Engine.MakeBeeBread());

    [RelayCommand(CanExecute = nameof(CanMoveToWoodenHive))]
    public void MoveToWoodenHive() => Apply(Engine.MoveToWoodenHive());

    /// <summary>Debug builds only: the Hippies hand over the next seed.</summary>
    public void DebugGiveSeed()
    {
        LogEvents(Engine.DebugGiveSeed());
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: every seed not yet given is handed over.</summary>
    public void DebugGiveEverySeed()
    {
        LogEvents(Engine.DebugGiveEverySeed());
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

    /// <summary>Debug builds only: the Hippie trades go to 19; one more brings the willow seed.</summary>
    public void DebugHippieTradesTo19()
    {
        LogEvents(Engine.DebugHippieTradesTo19());
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: every growing seed sprouts now.</summary>
    public void DebugFinishGrowing()
    {
        LogEvents(Engine.DebugFinishGrowing());
        SaveNow();
        Refresh();
    }

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

    /// <summary>Debug builds only: credits time away as if the app had been closed, welcome-back lines included.</summary>
    public void DebugSpendAway(decimal seconds)
    {
        LogAway(Engine.AdvanceAway(seconds));
        _lastTickUtc = _clock();
        SaveNow();
        Refresh();
    }

    /// <summary>Debug builds only: fills the Smoker's calm meter.</summary>
    public void DebugFillCalmMeter()
    {
        Engine.DebugFillCalmMeter();
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
    /// is something to lose (a brand-new hive with no bees starts over silently).</summary>
    public bool NewGameNeedsConfirmation => State.Bees > 0m;

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
        CraftBeeswaxCommand.NotifyCanExecuteChanged();
        CraftRepellentCommand.NotifyCanExecuteChanged();
        TradeTenCandlesCommand.NotifyCanExecuteChanged();
        TradeAllCandlesCommand.NotifyCanExecuteChanged();
        ThrowShoeCommand.NotifyCanExecuteChanged();
        BribeCommand.NotifyCanExecuteChanged();
        LightRepellentCommand.NotifyCanExecuteChanged();
        PuffSmokerCommand.NotifyCanExecuteChanged();
        PlantSeedCommand.NotifyCanExecuteChanged();
        CraftBeeBoostCommand.NotifyCanExecuteChanged();
        CraftSagePropolisCommand.NotifyCanExecuteChanged();
        LightBeeBoostCommand.NotifyCanExecuteChanged();
        LightSagePropolisCommand.NotifyCanExecuteChanged();
        MakeBeeBreadCommand.NotifyCanExecuteChanged();
        MoveToWoodenHiveCommand.NotifyCanExecuteChanged();
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
