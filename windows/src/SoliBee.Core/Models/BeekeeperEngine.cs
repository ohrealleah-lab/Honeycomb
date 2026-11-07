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
    public const string Sale = "sale";                     // Value = Beebits earned
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
    public const string CandlesTraded = "candles_traded";    // Value = sage received
    public const string RepellentUnlocked = "repellent_unlocked";
    public const string UpgradeBought = "upgrade_bought";    // Text = upgrade id
    public const string WaspArrives = "wasp_arrives";
    public const string ShoeHit = "shoe_hit";
    public const string ShoeMissRaid = "shoe_miss_raid";     // Value = honey taken, Value2 = bees flown off
    public const string WaspRaid = "wasp_raid";              // Value = honey taken, Value2 = bees flown off
    public const string Bribe = "bribe";                     // Value = honey paid
    public const string WaspLeft = "wasp_left";              // the player stepped away; nothing lost
    public const string CandleLit = "candle_lit";
    public const string CandleOut = "candle_out";

    // Stage 3
    public const string SmokerPuffed = "smoker_puffed";
    public const string CalmEnded = "calm_ended";
}

public readonly record struct BeekeeperEvent(string Key, decimal Value = 0m, string? Text = null, decimal Value2 = 0m);

public sealed record CatchResult(bool Stung, decimal BeesGained, IReadOnlyList<BeekeeperEvent> Events);

public sealed record AdvanceResult(decimal HoneyStored, decimal WaxMade, IReadOnlyList<BeekeeperEvent> Events);

public sealed record AwayResult(decimal CreditedSeconds, decimal HoneyStored, decimal WaxMade, IReadOnlyList<BeekeeperEvent> Events);

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

    private decimal StorageMultiplier =>
        Owns(BeekeeperUpgrades.BiggerCombs2) ? Config.BiggerCombs2Multiplier
        : Owns(BeekeeperUpgrades.BiggerCombs1) ? Config.BiggerCombs1Multiplier
        : 1m;

    /// <summary>Bees the tool catches per click, grown by the Practice upgrades (rounded down).</summary>
    public int BeesPerClick =>
        (int)Math.Floor((State.ToolLevel <= 0 ? Config.BareHandsBees : Config.Tools[State.ToolLevel - 1].BeesPerClick)
                        * PracticeMultiplier);

    private decimal PracticeMultiplier =>
        Owns(BeekeeperUpgrades.MorePractice) ? Config.MorePracticeMultiplier
        : Owns(BeekeeperUpgrades.Practice) ? Config.PracticeMultiplier
        : 1m;

    /// <summary>Everything one successful click catches: the tool's bees plus a slice of the
    /// hive (0.1%, rounded down; Practice doesn't grow the slice). The one place this is worked
    /// out, so the catch, the popup and the tool line agree.</summary>
    public decimal BeesPerCatch => BeesPerClick + Math.Floor(State.Bees * Config.CatchSliceShare);

    /// <summary>The colony's base rate. Raids and the like use this, never the calm boost.</summary>
    public decimal HoneyPerSecond => State.Bees * Config.HoneyPerBeePerSecond;

    /// <summary>What the hive makes right now (doubled while the bees are calm).</summary>
    public decimal HoneyPerSecondNow => HoneyPerSecond * (IsCalm ? Config.CalmHoneyMultiplier : 1m);

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

        // Only Bare Hands ever get stung; better tools never roll the dice.
        if (State.ToolLevel == 0 && _rng.NextDouble() < Config.StingChance)
        {
            events.Add(new BeekeeperEvent(BeekeeperEvents.Sting));
            return new CatchResult(true, 0m, events);
        }

        decimal gained = BeesPerCatch;
        State.Bees += gained;
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
        decimal calm = seconds > 0m ? Math.Min(seconds, State.CalmSecondsLeft) : 0m;
        var (stored, wax) = Produce(calm, events, Config.CalmHoneyMultiplier);
        var (stored2, wax2) = Produce(seconds - calm, events);
        if (calm > 0m)
        {
            State.CalmSecondsLeft -= calm;
            if (State.CalmSecondsLeft <= 0m) events.Add(new BeekeeperEvent(BeekeeperEvents.CalmEnded));
        }
        return new AdvanceResult(stored + stored2, wax + wax2, events);
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
        var (stored, wax) = Produce(credited * Config.OfflineRate, events);

        if (State.Bees > 0m)
        {
            events.Add(stored > 0m
                ? new BeekeeperEvent(BeekeeperEvents.WelcomeBack, stored)
                : new BeekeeperEvent(BeekeeperEvents.WelcomeBackNothing));
        }
        return new AwayResult(credited, stored, wax, events);
    }

    private (decimal stored, decimal waxMade) Produce(decimal seconds, List<BeekeeperEvent> events, decimal boost = 1m)
    {
        RefreshStorageFlag();
        if (seconds <= 0m || State.Bees <= 0m) return (0m, 0m);

        decimal made = State.Bees * Config.HoneyPerBeePerSecond * seconds * boost;
        decimal room = Math.Max(0m, HoneyStorage - State.Honey);
        decimal stored = Math.Min(made, room);
        State.Honey += stored;

        if (made > room && !State.StorageFullAnnounced)
        {
            State.StorageFullAnnounced = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.StorageFull));
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
        return (stored, waxMade);
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

        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.Sale, bundles, State.BearName) };
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
    /// has enough combs. Returns what to tell the player (nothing if already open).</summary>
    public IReadOnlyList<BeekeeperEvent> RevealOnLoad()
    {
        var events = new List<BeekeeperEvent>();
        OpenWorkbenchIfDue(events);
        return events;
    }

    private void OpenWorkbenchIfDue(List<BeekeeperEvent> events)
    {
        if (State.WorkbenchRevealed || State.Combs < Config.WorkbenchCombs) return;
        State.WorkbenchRevealed = true;
        events.Add(new BeekeeperEvent(BeekeeperEvents.WorkbenchOpened));
    }

    public bool CanCraftBeeswax => State.WorkbenchRevealed && State.Wax >= Config.BeeswaxCandleWax;

    public bool CanCraftRepellent =>
        State.WorkbenchRevealed && State.RepellentUnlocked
        && State.Wax >= Config.RepellentCandleWax && State.Sage >= Config.RepellentCandleSage;

    /// <summary>Crafting is instant (Leah).</summary>
    public ActionResult CraftBeeswax()
    {
        if (!CanCraftBeeswax) return ActionResult.Refused;
        State.Wax -= Config.BeeswaxCandleWax;
        State.BeeswaxCandles++;
        var events = new List<BeekeeperEvent>();
        if (State.CandlesCrafted == 0) events.Add(new BeekeeperEvent(BeekeeperEvents.FirstBeeswaxCandle));
        CountCandleCrafted(events);
        return new ActionResult(true, 1m, events);
    }

    public ActionResult CraftRepellent()
    {
        if (!CanCraftRepellent) return ActionResult.Refused;
        State.Wax -= Config.RepellentCandleWax;
        State.Sage -= Config.RepellentCandleSage;
        State.RepellentCandles++;
        var events = new List<BeekeeperEvent>();
        CountCandleCrafted(events);
        return new ActionResult(true, 1m, events);
    }

    private void CountCandleCrafted(List<BeekeeperEvent> events)
    {
        State.CandlesCrafted++;
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

        var events = new List<BeekeeperEvent> { new(BeekeeperEvents.CandlesTraded, bundles) };
        if (!State.RepellentUnlocked)
        {
            // The sage repellent candle comes once there is sage to make it with (placeholder rule).
            State.RepellentUnlocked = true;
            events.Add(new BeekeeperEvent(BeekeeperEvents.RepellentUnlocked));
        }
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
        BeekeeperUpgrades.NeedsRepellent => State.RepellentUnlocked,
        BeekeeperUpgrades.NeedsVacuum => State.ToolLevel >= VacuumLevel,
        var other => Owns(other),
    };

    private int VacuumLevel => Config.Tools.ToList().FindIndex(t => t.Id == "vacuum") + 1;

    public bool CanBuyUpgrade(string id) =>
        Config.Upgrades.FirstOrDefault(u => u.Id == id) is { } u
        && !Owns(id) && IsUnlocked(u)
        && State.Beebits >= u.Beebits && State.Wax >= u.Wax && State.Sage >= u.Sage;

    /// <summary>Takes every part of the cost at once, or nothing.</summary>
    public ActionResult BuyUpgrade(string id)
    {
        if (!CanBuyUpgrade(id)) return ActionResult.Refused;
        var u = Config.Upgrades.First(x => x.Id == id);
        State.Beebits -= u.Beebits;
        State.Wax -= u.Wax;
        State.Sage -= u.Sage;
        State.Upgrades.Add(id);
        RefreshStorageFlag();
        return new ActionResult(true, u.Beebits, new[] { new BeekeeperEvent(BeekeeperEvents.UpgradeBought, 0m, id) });
    }

    // ------------------------------------------------------------------ wasps

    public bool WaspApproaching => State.WaspCountdown > 0m;

    /// <summary>Wasp time that one repellent candle buys (longer with Stronger Candles).</summary>
    public decimal RepellentBurnSeconds =>
        Config.RepellentBurnSeconds * (Owns(BeekeeperUpgrades.StrongerCandles) ? Config.StrongerCandlesBonus : 1m);

    /// <summary>
    /// "Wasp time" passed: only while Beekeeper is on screen, the player is active and No
    /// Stress Mode is off (the view model decides). A burning candle uses it up; otherwise
    /// it counts down to the next wasp. Away time never comes here.
    /// </summary>
    public IReadOnlyList<BeekeeperEvent> AdvanceWaspTime(decimal seconds)
    {
        var events = new List<BeekeeperEvent>();
        if (seconds <= 0m || !State.WorkbenchRevealed || WaspApproaching) return events;

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
        if (!State.WorkbenchRevealed || WaspApproaching) return Array.Empty<BeekeeperEvent>();
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

    /// <summary>Pay 25% of the stored honey (at least 1); the wasp leaves and no bees fly off.</summary>
    public ActionResult Bribe()
    {
        if (!CanBribe) return ActionResult.Refused;
        decimal paid = BribeCost;
        State.Honey -= paid;
        RefreshStorageFlag();
        EndWasp();
        return new ActionResult(true, paid, new[] { new BeekeeperEvent(BeekeeperEvents.Bribe, paid) });
    }

    public bool CanLightRepellent => State.RepellentCandles >= 1m;

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

    private BeekeeperEvent Raid(string key)
    {
        decimal honey = Math.Min(State.Honey, Math.Floor(HoneyPerSecond * Config.RaidHoneySeconds));
        decimal bees = Math.Floor(State.Bees * Config.RaidBeeShare);
        State.Honey -= honey;
        State.Bees -= bees;
        RefreshStorageFlag();
        EndWasp();
        return new BeekeeperEvent(key, honey, null, bees);
    }

    private void EndWasp()
    {
        State.WaspCountdown = 0m;
        State.NextWaspInSeconds = 0m;   // rolled afresh on the next wasp time
    }

    // ------------------------------------------------------------------ debug

    /// <summary>
    /// Debug builds only (the Banners menu): hands out bees, wax and Beebits so later stages
    /// can be reached without hours of play. The game itself never calls this.
    /// </summary>
    public IReadOnlyList<BeekeeperEvent> DebugGrant(decimal bees, decimal wax, decimal beebits)
    {
        var events = new List<BeekeeperEvent>();
        if (bees > 0m)
        {
            State.Bees += bees;
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
