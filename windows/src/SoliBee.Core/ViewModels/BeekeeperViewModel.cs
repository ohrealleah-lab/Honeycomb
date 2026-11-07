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

    public BeekeeperEngine Engine { get; private set; }
    public BeekeeperState State => Engine.State;
    public BeekeeperConfig Config => Engine.Config;

    /// <param name="isHeadless">True means no timer (tests call <see cref="Tick"/> themselves).</param>
    /// <param name="persist">False means never touch the disk.</param>
    /// <param name="savePath">Where to save; null uses the app's data folder.</param>
    /// <param name="initialState">Start from this instead of loading a save (tests).</param>
    public BeekeeperViewModel(
        bool isHeadless = false,
        BeekeeperConfig? config = null,
        IRandomSource? rng = null,
        Func<DateTime>? clock = null,
        bool persist = true,
        string? savePath = null,
        BeekeeperState? initialState = null)
    {
        _clock = clock ?? (() => DateTime.UtcNow);
        _syncContext = SynchronizationContext.Current;
        _savePath = persist ? (savePath ?? BeekeeperSaveService.SaveFilePath) : null;

        var loaded = initialState ?? (_savePath is null ? null : BeekeeperSaveService.Load(_savePath));
        Engine = new BeekeeperEngine(config, loaded, rng);

        var now = _clock();
        _lastTickUtc = now;

        if (loaded is null)
        {
            LogEvents(new[] { new BeekeeperEvent(BeekeeperEvents.NewGame) });
        }
        else
        {
            // Time since the last save counts as time away (closing the app, a long gap, etc.).
            decimal gap = BeekeeperSaveService.SecondsSinceSaved(loaded, now);
            if (Engine.IsAway(gap)) LogEvents(Engine.AdvanceAway(gap).Events);
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
    public decimal HoneyPerSecond => Engine.HoneyPerSecond;
    public decimal Wax => State.Wax;
    public decimal WaxProgress => State.WaxProgress;
    public decimal HoneyPerWax => Config.HoneyPerWax;
    public decimal Beebits => State.Beebits;
    public int ToolLevel => State.ToolLevel;
    public int BeesPerClick => Engine.BeesPerClick;
    public bool HasWaxCatcher => State.HasWaxCatcher;
    public int Combs => State.Combs;
    public decimal CombCost => Engine.CombCost;
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

    private void Apply(ActionResult result)
    {
        if (result.Done) LogEvents(result.Events);
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
        LogEvents(events);
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

        if (Engine.IsAway(gap))
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

        _secondsSinceSave += gap;
        if (_secondsSinceSave >= AutosaveEverySeconds) SaveNow();

        Refresh();
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

            State.Log.Insert(0, new BeekeeperLogEntry { Key = e.Key, Value = e.Value, Text = e.Text });
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
