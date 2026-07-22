using Avalonia.Controls;
using Avalonia.Interactivity;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public partial class HoneycombStatsWindow : Window
{
    public HoneycombStatsWindow()
    {
        InitializeComponent();
        
        var stats = HoneycombViewModel.LoadStats();
        
        GamesPlayedText.Text = stats.GamesPlayed.ToString();
        MatchesWonText.Text = stats.MatchesWon.ToString();
        MatchesLostText.Text = stats.MatchesLost.ToString();
        MatchesDrawnText.Text = stats.MatchesDrawn.ToString();
        
        CardsCapturedText.Text = stats.CardsCaptured.ToString();
        CardsStolenText.Text = stats.CardsStolen.ToString();
        FallenAcesText.Text = stats.FallenAces.ToString();
        SuddenDeathCountText.Text = stats.SuddenDeathCount.ToString();
        FlawlessVictoriesText.Text = stats.FlawlessVictories.ToString();
        
        CurrentWinStreakText.Text = stats.CurrentWinStreak.ToString();
        LongestWinStreakText.Text = stats.LongestWinStreak.ToString();
    }

    private void Close_Click(object? sender, RoutedEventArgs e)
    {
        Close();
    }
}
