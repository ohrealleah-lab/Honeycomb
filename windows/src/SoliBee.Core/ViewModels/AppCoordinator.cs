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
    private object _activeViewModel;

    private static readonly string LastModeFile = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "SoliBee", "last_mode.txt");

    public AppCoordinator()
    {
        GameViewModel       = new GameViewModel();
        FreecellViewModel    = new FreecellViewModel();
        SpiderViewModel     = new SpiderViewModel();
        VideoPokerViewModel = new VideoPokerViewModel();
        BlackjackViewModel  = new BlackjackViewModel();

        ActiveViewModel = LoadLastMode() switch
        {
            "Freecell"    => (object)FreecellViewModel,
            "Spider"     => (object)SpiderViewModel,
            "VideoPoker" => (object)VideoPokerViewModel,
            "Blackjack"  => (object)BlackjackViewModel,
            _            => (object)GameViewModel
        };
    }

    public bool CanUndo => ActiveViewModel switch
    {
        GameViewModel gvm       => gvm.CanUndo,
        FreecellViewModel bvm    => bvm.CanUndo,
        SpiderViewModel svm     => svm.CanUndo,
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
        ActiveViewModel = VideoPokerViewModel;
        SaveLastMode("VideoPoker");
        OnPropertyChanged(nameof(CanUndo));
    }

    public void SwitchToBlackjack()
    {
        PauseTimer(ActiveViewModel);
        ActiveViewModel = BlackjackViewModel;
        SaveLastMode("Blackjack");
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
