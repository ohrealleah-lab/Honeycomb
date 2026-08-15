using System;
using System.Diagnostics;
using Avalonia.Controls;
using Avalonia.Interactivity;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Localization;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public partial class AboutWindow : Window
{
    private UpdateCheckOutcome? _lastOutcome;
    private AppLanguage _language;

    public AboutWindow()
    {
        InitializeComponent();

        _language = SettingsService.LoadOptions().Language;
        ApplyLocalization();

        // Shown non-modally (Show, not ShowDialog — see MainWindow's About_Click), so
        // Preferences stays reachable while this window is open. Without this, changing
        // the language while About is already open would leave it stuck in the old
        // language until closed and reopened.
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            if (m.Options.Language == _language) return;
            _language = m.Options.Language;
            ApplyLocalization();
        });
        Closed += (_, _) => WeakReferenceMessenger.Default.Unregister<OptionsChangedMessage>(this);
    }

    private void ApplyLocalization()
    {
        VersionText.Text = string.Format(Strings.Get(StringKey.VersionFmt, _language).Replace("%@", "{0}"), UpdateCheckService.CurrentVersion);
        CardSuiteText.Text = Strings.Get(StringKey.CardSuiteLabel, _language);
        CopyrightText.Text = Strings.Get(StringKey.CopyrightNotice, _language);
        DedicationText.Text = Strings.Get(StringKey.Dedication, _language);
        CheckForUpdatesButton.Content = Strings.Get(StringKey.CheckForUpdates, _language);
        InstallUpdateButton.Content = Strings.Get(StringKey.InstallAndRestart, _language);
        CloseButton.Content = Strings.Get(StringKey.Close, _language);
    }

    private void Close_Click(object? sender, RoutedEventArgs e) => Close();

    private async void CheckForUpdates_Click(object? sender, RoutedEventArgs e)
    {
        CheckForUpdatesButton.IsVisible = false;
        InstallUpdateButton.IsVisible = false;
        UpdateStatusText.IsVisible = true;
        UpdateStatusText.Text = Strings.Get(StringKey.CheckingForUpdates, _language);

        try
        {
            var outcome = await UpdateCheckService.CheckNowAsync();
            _lastOutcome = outcome;

            if (outcome.IsNewer && outcome.UpdateInfo != null)
            {
                UpdateStatusText.Text = Strings.Get(StringKey.NewerVersionAvailableFmt, _language).Replace("%@", outcome.UpdateInfo.TargetFullRelease.Version.ToString());
                InstallUpdateButton.IsVisible = true;
            }
            else
            {
                UpdateStatusText.Text = Strings.Get(StringKey.UpToDate, _language);
                CheckForUpdatesButton.Content = Strings.Get(StringKey.CheckAgain, _language);
                CheckForUpdatesButton.IsVisible = true;
            }
        }
        catch
        {
            UpdateStatusText.Text = Strings.Get(StringKey.UpdateCheckFailed, _language);
            CheckForUpdatesButton.Content = Strings.Get(StringKey.TryAgain, _language);
            CheckForUpdatesButton.IsVisible = true;
        }
    }

    private async void InstallUpdate_Click(object? sender, RoutedEventArgs e)
    {
        if (_lastOutcome?.UpdateInfo == null) return;

        InstallUpdateButton.IsEnabled = false;
        UpdateStatusText.Text = Strings.Get(StringKey.AboutDownloadingUpdate, _language);

        try
        {
            await UpdateCheckService.DownloadAndApplyUpdatesAsync(_lastOutcome.UpdateInfo, progress =>
            {
                // Must marshal to UI thread if we want to show real-time progress
                Avalonia.Threading.Dispatcher.UIThread.Post(() =>
                {
                    UpdateStatusText.Text = Strings.Get(StringKey.AboutDownloadingUpdatePctFmt, _language).Replace("%d", progress.ToString());
                });
            });
        }
        catch
        {
            Avalonia.Threading.Dispatcher.UIThread.Post(() =>
            {
                UpdateStatusText.Text = Strings.Get(StringKey.AboutUpdateDownloadFailed, _language);
                InstallUpdateButton.IsEnabled = true;
            });
        }
    }
}
