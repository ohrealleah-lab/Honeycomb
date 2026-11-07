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
    private readonly SynchronizationContext? _syncContext;
    private Timer? _timer;
    private DateTime _lastTickUtc;
    private decimal _carrySeconds;          // leftover fraction of a second between ticks
    private decimal _secondsSinceSave;
    private bool _disposed;
    private readonly Func<bool> _noStressMode;
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
    /// <param name="noStressMode">Reads No Stress Mode; null uses the app's Options.</param>
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
        _noStressMode = noStressMode ?? (() => SettingsService.LoadOptions().IsNoStressMode);
        _syncContext = SynchronizationContext.Current;
        _savePath = persist ? (savePath ?? BeekeeperSaveService.SaveFilePath) : null;

        var loaded = initialState ?? (_savePath is null ? null : BeekeeperSaveService.Load(_savePath));
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
            decimal gap = BeekeeperSaveService.SecondsSinceSaved(loaded, now);
            if (Engine.IsAway(gap)) LogEvents(Engine.AdvanceAway(gap).Events);
            LogEvents(Engine.RevealOnLoad());   // an older save may already have earned The Workbench
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
    public bool StorageIsFull => State.Honey >= Engine.HoneyStorage;

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
    public bool WaspApproaching => Engine.WaspApproaching;
    public decimal WaspSecondsLeft => State.WaspCountdown;
    public decimal RepellentSecondsLeft => State.RepellentSecondsLeft;
    public decimal BribeCost => Engine.BribeCost;
    public IReadOnlyList<BeekeeperUpgrade> ShopUpgrades => Engine.ShopUpgrades;
    public bool CanBuyUpgrade(string id) => Engine.CanBuyUpgrade(id);
    public bool CanCraftBeeswax => Engine.CanCraftBeeswax;
    public bool CanCraftRepellent => Engine.CanCraftRepellent;
    public bool CanTradeCandles => Engine.CanTradeCandles;
    public bool CanThrowShoe => Engine.WaspApproaching;
    public bool CanBribe => Engine.CanBribe;
    public bool CanLightRepellent => Engine.CanLightRepellent;

    // Stage 3
    /// <summary>Everything a successful click catches right now (tool, Practice and the slice).</summary>
    public decimal BeesPerCatch => Engine.BeesPerCatch;
    public bool HasSmoker => Engine.Owns(BeekeeperUpgrades.Smoker);
    public int CalmMeter => State.CalmMeter;
    public int CalmMeterClicks => Config.CalmMeterClicks;
    public bool IsCalm => Engine.IsCalm;
    public decimal CalmSecondsLeft => State.CalmSecondsLeft;
    public bool CanPuff => Engine.CanPuff;

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
            // reopening the app says "While you were away" (Leah, 2026-11-07).
            LogEvents(Engine.AdvanceAway(gap).Events.Where(e =>
                e.Key is not (BeekeeperEvents.WelcomeBack or BeekeeperEvents.WelcomeBackNothing)));
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
    /// "wasp time" passes, unless No Stress Mode is on; that stops new wasps and pauses a
    /// burning candle, but a wasp already here still plays out (spec 010, Story 7).
    /// </summary>
    private void AdvanceWasps(decimal gap, bool away, DateTime now)
    {
        bool watching = IsWatched && (decimal)(now - _lastActivityUtc).TotalSeconds <= Config.IdleSeconds;
        if (Engine.WaspApproaching)
        {
            LogEvents(away || !watching ? Engine.WaspLeaves() : Engine.AdvanceWaspCountdown(gap));
            return;
        }
        if (!away && watching && !_noStressMode()) LogEvents(Engine.AdvanceWaspTime(gap));
    }

    /// <summary>Writes the game to disk now (also done every few seconds, on New Game and on close).</summary>
    public bool SaveNow()
    {
        _secondsSinceSave = 0m;
        return _savePath is not null && BeekeeperSaveService.Save(State, _savePath, _clock());
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
