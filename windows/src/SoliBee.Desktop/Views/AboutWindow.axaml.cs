using Avalonia.Controls;
using Avalonia.Interactivity;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

public partial class AboutWindow : Window
{
    public AboutWindow()
    {
        InitializeComponent();

        VersionText.Text = $"Version {UpdateCheckService.CurrentVersion}";
    }

    private void Close_Click(object? sender, RoutedEventArgs e) => Close();

    private async void CheckForUpdates_Click(object? sender, RoutedEventArgs e)
    {
        CheckForUpdatesButton.IsVisible = false;
        UpdateActionsPanel.IsVisible = false;
        UpdateStatusText.IsVisible = true;
        UpdateStatusText.Text = "Checking for updates…";

        try
        {
            var outcome = await UpdateCheckService.CheckNowAsync();

            if (outcome.IsNewer)
            {
                UpdateStatusText.Text = $"Version {outcome.LatestVersion} is available.";
                UpdateActionsPanel.IsVisible = true;
            }
            else
            {
                UpdateStatusText.Text = "You're up to date.";
                CheckForUpdatesButton.Content = "Check Again";
                CheckForUpdatesButton.IsVisible = true;
            }
        }
        catch
        {
            UpdateStatusText.Text = "Couldn't check for updates. Check your internet connection.";
            CheckForUpdatesButton.Content = "Try Again";
            CheckForUpdatesButton.IsVisible = true;
        }
    }

    private void DeclineUpdate_Click(object? sender, RoutedEventArgs e)
    {
        UpdateCheckService.DeclineUpdate();
        UpdateActionsPanel.IsVisible = false;
        UpdateStatusText.IsVisible = false;
        CheckForUpdatesButton.Content = "Check for Updates…";
        CheckForUpdatesButton.IsVisible = true;
    }

    // Downloads and applies the update found by CheckForUpdates_Click above, then restarts
    // the app — no browser hand-off anymore, Velopack handles the whole install in place.
    private async void InstallUpdate_Click(object? sender, RoutedEventArgs e)
    {
        DeclineUpdateButton.IsEnabled = false;
        InstallUpdateButton.IsEnabled = false;
        UpdateStatusText.Text = "Downloading update…";

        try
        {
            await UpdateCheckService.InstallUpdateAsync();
            // ApplyUpdatesAndRestart above exits and relaunches the process — nothing
            // after this point normally runs.
        }
        catch
        {
            UpdateStatusText.Text = "Couldn't download the update. Check your internet connection.";
            DeclineUpdateButton.IsEnabled = true;
            InstallUpdateButton.IsEnabled = true;
        }
    }
}
