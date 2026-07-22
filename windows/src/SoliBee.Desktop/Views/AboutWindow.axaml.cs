using System;
using System.Diagnostics;
using Avalonia.Controls;
using Avalonia.Interactivity;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

public partial class AboutWindow : Window
{
    private UpdateCheckOutcome? _lastOutcome;

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
            _lastOutcome = outcome;

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

    private void ViewRelease_Click(object? sender, RoutedEventArgs e)
    {
        if (_lastOutcome == null) return;
        try
        {
            Process.Start(new ProcessStartInfo(_lastOutcome.ReleaseUrl) { UseShellExecute = true });
        }
        catch
        {
            // Best-effort — nothing sensible to do if the OS can't hand off to a browser.
        }
    }
}
