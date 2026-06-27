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
    private BeecellViewModel _beecellViewModel;

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
        BeecellViewModel    = new BeecellViewModel();
        SpiderViewModel     = new SpiderViewModel();
        VideoPokerViewModel = new VideoPokerViewModel();
        BlackjackViewModel  = new BlackjackViewModel();

        ActiveViewModel = LoadLastMode() switch
        {
            "Beecell"    => (object)BeecellViewModel,
            "Spider"     => (object)SpiderViewModel,
            "VideoPoker" => (object)VideoPokerViewModel,
            "Blackjack"  => (object)BlackjackViewModel,
            _            => (object)GameViewModel
        };
    }

    public bool CanUndo => ActiveViewModel switch
    {
        GameViewModel gvm       => gvm.CanUndo,
        BeecellViewModel bvm    => bvm.CanUndo,
        SpiderViewModel svm     => svm.CanUndo,
        VideoPokerViewModel _   => false,
        BlackjackViewModel _    => false,
        _                       => false
    };

    public void SwitchToGame()
    {
        ActiveViewModel = GameViewModel;
        SaveLastMode("Klondike");
        OnPropertyChanged(nameof(CanUndo));
    }

    public void SwitchToBeecell()
    {
        ActiveViewModel = BeecellViewModel;
        SaveLastMode("Beecell");
        OnPropertyChanged(nameof(CanUndo));
    }

    public void SwitchToSpider()
    {
        ActiveViewModel = SpiderViewModel;
        SaveLastMode("Spider");
        OnPropertyChanged(nameof(CanUndo));
    }

    public void SwitchToVideoPoker()
    {
        ActiveViewModel = VideoPokerViewModel;
        SaveLastMode("VideoPoker");
        OnPropertyChanged(nameof(CanUndo));
    }

    public void SwitchToBlackjack()
    {
        ActiveViewModel = BlackjackViewModel;
        SaveLastMode("Blackjack");
        OnPropertyChanged(nameof(CanUndo));
    }

    [RelayCommand]
    public void Undo()
    {
        if (ActiveViewModel is GameViewModel gvm) gvm.Undo();
        else if (ActiveViewModel is BeecellViewModel bvm) bvm.Undo();
        else if (ActiveViewModel is SpiderViewModel svm) svm.Undo();
        OnPropertyChanged(nameof(CanUndo));
    }

    [RelayCommand]
    public void ResetStatistics()
    {
        if (ActiveViewModel is GameViewModel gvm)
        {
            gvm.Stats = new GameStatistics();
            StatsService.SaveStats(gvm.Stats);
        }
        else if (ActiveViewModel is BeecellViewModel bvm)
            bvm.ResetStatistics();
        else if (ActiveViewModel is SpiderViewModel svm)
            svm.ResetStatistics();
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
        else if (ActiveViewModel is BeecellViewModel bvm) bvm.State.HasWon = true;
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
