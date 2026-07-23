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
        InstallUpdateButton.IsVisible = false;
        UpdateStatusText.IsVisible = true;
        UpdateStatusText.Text = "Checking for updates…";

        try
        {
            var outcome = await UpdateCheckService.CheckNowAsync();
            _lastOutcome = outcome;

            if (outcome.IsNewer && outcome.UpdateInfo != null)
            {
                UpdateStatusText.Text = $"Version {outcome.UpdateInfo.TargetFullRelease.Version} is available.";
                InstallUpdateButton.IsVisible = true;
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

    private async void InstallUpdate_Click(object? sender, RoutedEventArgs e)
    {
        if (_lastOutcome?.UpdateInfo == null) return;
        
        InstallUpdateButton.IsEnabled = false;
        UpdateStatusText.Text = "Downloading update...";

        try
        {
            await UpdateCheckService.DownloadAndApplyUpdatesAsync(_lastOutcome.UpdateInfo, progress => 
            {
                // Must marshal to UI thread if we want to show real-time progress
                Avalonia.Threading.Dispatcher.UIThread.Post(() => 
                {
                    UpdateStatusText.Text = $"Downloading update... {progress}%";
                });
            });
        }
        catch
        {
            Avalonia.Threading.Dispatcher.UIThread.Post(() => 
            {
                UpdateStatusText.Text = "Failed to download the update.";
                InstallUpdateButton.IsEnabled = true;
            });
        }
    }
}
