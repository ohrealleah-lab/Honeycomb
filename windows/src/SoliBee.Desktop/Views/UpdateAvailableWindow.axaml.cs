using Avalonia.Controls;
using Avalonia.Interactivity;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

public partial class UpdateAvailableWindow : Window
{
    public UpdateAvailableWindow(UpdateCheckOutcome outcome)
    {
        InitializeComponent();
        MessageText.Text = $"Version {outcome.LatestVersion} of Honeycomb is available. You're on {UpdateCheckService.CurrentVersion}.";
    }

    private void DeclineUpdate_Click(object? sender, RoutedEventArgs e)
    {
        UpdateCheckService.DeclineUpdate();
        Close();
    }

    // Downloads and applies the update, then restarts the app — no browser hand-off,
    // Velopack handles the whole install in place.
    private async void InstallUpdate_Click(object? sender, RoutedEventArgs e)
    {
        DeclineUpdateButton.IsEnabled = false;
        InstallUpdateButton.IsEnabled = false;
        MessageText.Text = "Downloading update…";

        try
        {
            await UpdateCheckService.InstallUpdateAsync();
            // ApplyUpdatesAndRestart above exits and relaunches the process — nothing
            // after this point normally runs.
        }
        catch
        {
            MessageText.Text = "Couldn't download the update. Check your internet connection.";
            DeclineUpdateButton.IsEnabled = true;
            InstallUpdateButton.IsEnabled = true;
        }
    }
}
