using System;
using System.IO;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

public partial class AppCoordinator : ObservableObject
{
    [ObservableProperty]
    private GameViewModel _gameViewModel;

    [ObservableProperty]
    private FreecellViewModel _freecellViewModel;

    [ObservableProperty]
    private SpiderViewModel _spiderViewModel;

    [ObservableProperty]
    private VideoPokerViewModel _videoPokerViewModel;

    [ObservableProperty]
    private BlackjackViewModel _blackjackViewModel;

    [ObservableProperty]
    private HoneycombViewModel _honeycombViewModel;

    [ObservableProperty]
    private object _activeViewModel;

    private static readonly string LastModeFile = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        AppDataMigration.FolderName, "last_mode.txt");

    public AppCoordinator()
    {
        GameViewModel       = new GameViewModel();
        FreecellViewModel    = new FreecellViewModel();
        SpiderViewModel     = new SpiderViewModel();
        VideoPokerViewModel = new VideoPokerViewModel();
        BlackjackViewModel  = new BlackjackViewModel();
        HoneycombViewModel  = new HoneycombViewModel(isHeadless: false);

        ActiveViewModel = LoadLastMode() switch
        {
            "Freecell"    => (object)FreecellViewModel,
            "Spider"     => (object)SpiderViewModel,
            "VideoPoker" => (object)VideoPokerViewModel,
            "Blackjack"  => (object)BlackjackViewModel,
            "Honeycomb"  => (object)HoneycombViewModel,
            _            => (object)GameViewModel
        };

        // OptionsChangedMessage is broadcast from many places (Preferences, MainWindow,
        // and each timer-having ViewModel's own No-Stress-Mode toggle) and every
        // registered listener receives it regardless of which game is actually on
        // screen — including the two ViewModels PauseTimer/ResumeTimerForSwitch above
        // never touch (only the outgoing and incoming game are paused/resumed on a
        // switch). If a third, backgrounded Klondike/Freecell/Spider still has an
        // abandoned, unfinished hand (MovesCount > 0, !HasWon) when No Stress Mode gets
        // switched off elsewhere, that ViewModel's own OptionsChangedMessage handler sets
        // State.IsTimerActive = true for itself — silently resuming its already-running
        // background _gameTimer for a screen nobody is looking at, corrupting
        // ShortestWinSeconds/TotalWinSeconds if the player returns to it later. Re-pause
        // every non-active timer-having ViewModel after any options broadcast to
        // guarantee only the active game can have a running timer, regardless of what
        // each one's own handler decided to do.
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            if (ActiveViewModel != GameViewModel)      GameViewModel.PauseTimerForSwitch();
            if (ActiveViewModel != FreecellViewModel)   FreecellViewModel.PauseTimerForSwitch();
            if (ActiveViewModel != SpiderViewModel)     SpiderViewModel.PauseTimerForSwitch();
        });
    }

    public bool CanUndo => ActiveViewModel switch
    {
        GameViewModel gvm       => gvm.CanUndo,
        FreecellViewModel bvm    => bvm.CanUndo,
        SpiderViewModel svm     => svm.CanUndo,
        HoneycombViewModel hvm  => hvm.CanUndo,
        VideoPokerViewModel _   => false,
        BlackjackViewModel _    => false,
        _                       => false
    };

    public void SwitchToGame()
    {
        PauseTimer(ActiveViewModel);
        ActiveViewModel = GameViewModel;
        GameViewModel.ResumeTimerForSwitch();
        SaveLastMode("Klondike");
        OnPropertyChanged(nameof(CanUndo));
    }

    public void SwitchToFreecell()
    {
        PauseTimer(ActiveViewModel);
        ActiveViewModel = FreecellViewModel;
        FreecellViewModel.ResumeTimerForSwitch();
        SaveLastMode("Freecell");
        OnPropertyChanged(nameof(CanUndo));
    }

    public void SwitchToSpider()
    {
        PauseTimer(ActiveViewModel);
        ActiveViewModel = SpiderViewModel;
        SpiderViewModel.ResumeTimerForSwitch();
        SaveLastMode("Spider");
        OnPropertyChanged(nameof(CanUndo));
    }

    public void SwitchToVideoPoker()
    {
        PauseTimer(ActiveViewModel);
        // A finished hand still sitting in Result phase (e.g. left mid-banner on a
        // previous visit) resets the board instead of showing — and replaying the
        // banner for — a round that's already over.
        VideoPokerViewModel.ResetIfRoundOver();
        ActiveViewModel = VideoPokerViewModel;
        SaveLastMode("VideoPoker");
        OnPropertyChanged(nameof(CanUndo));
    }

    public void SwitchToBlackjack()
    {
        PauseTimer(ActiveViewModel);
        BlackjackViewModel.ResetIfRoundOver();
        ActiveViewModel = BlackjackViewModel;
        SaveLastMode("Blackjack");
        OnPropertyChanged(nameof(CanUndo));
    }

    public void SwitchToHoneycomb()
    {
        PauseTimer(ActiveViewModel);
        ActiveViewModel = HoneycombViewModel;
        SaveLastMode("Honeycomb");
        OnPropertyChanged(nameof(CanUndo));
    }

    // The background game timer in GameViewModel/FreecellViewModel/SpiderViewModel keeps
    // ticking regardless of which game's View is on screen, so it must be explicitly
    // paused whenever we're about to switch away from whichever game is currently active.
    private static void PauseTimer(object? viewModel)
    {
        switch (viewModel)
        {
            case GameViewModel gvm: gvm.PauseTimerForSwitch(); break;
            case FreecellViewModel bvm: bvm.PauseTimerForSwitch(); break;
            case SpiderViewModel svm: svm.PauseTimerForSwitch(); break;
        }
    }

    [RelayCommand]
    public void Undo()
    {
        if (ActiveViewModel is GameViewModel gvm) gvm.Undo();
        else if (ActiveViewModel is FreecellViewModel bvm) bvm.Undo();
        else if (ActiveViewModel is SpiderViewModel svm) svm.Undo();
        else if (ActiveViewModel is HoneycombViewModel hvm) hvm.Undo();
        OnPropertyChanged(nameof(CanUndo));
    }

    [RelayCommand]
    public void ResetStatistics()
    {
        if (ActiveViewModel is GameViewModel gvm)
            gvm.ResetStats();
        else if (ActiveViewModel is FreecellViewModel bvm)
            bvm.ResetStats();
        else if (ActiveViewModel is SpiderViewModel svm)
            svm.ResetStats();
        else if (ActiveViewModel is BlackjackViewModel bjvm)
            bjvm.ResetStats();
        else if (ActiveViewModel is VideoPokerViewModel vpvm)
            vpvm.ResetStats();
    }

    [RelayCommand]
    public void ApplyTheme(SoliBeeTheme theme)
    {
        var options = SettingsService.LoadOptions();

        // Mirrors PreferencesView.ApplyThemeNow's two fixes for the theme-switch data-loss
        // bugs, so this second entry point into ThemeService.ApplyTheme can't reintroduce
        // them if it's ever wired up to UI: persist the outgoing theme's live face art
        // before switching, and reconstruct from a fresh disk read of `theme` rather than
        // whatever (possibly stale) object reference the caller handed in.
        if (options.ActiveThemeId.HasValue)
            ThemeService.UpdateTheme(options.ActiveThemeId.Value, options);
        theme = ThemeService.LoadThemes().Find(t => t.Id == theme.Id) ?? theme;

        ThemeService.ApplyTheme(theme, options);
        SettingsService.SaveOptions(options);
        WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(options));
    }

    [RelayCommand]
    public void TriggerWinAnimation()
    {
        if (ActiveViewModel is GameViewModel gvm) gvm.State.HasWon = true;
        else if (ActiveViewModel is FreecellViewModel bvm) bvm.State.HasWon = true;
        else if (ActiveViewModel is SpiderViewModel svm) svm.State.HasWon = true;
    }

    private static string LoadLastMode()
    {
        try { return File.Exists(LastModeFile) ? File.ReadAllText(LastModeFile).Trim() : "Klondike"; }
        catch { return "Klondike"; }
    }

    private static void SaveLastMode(string mode)
    {
        try
        {
            var dir = Path.GetDirectoryName(LastModeFile)!;
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
            File.WriteAllText(LastModeFile, mode);
        }
        catch { }
    }
}
