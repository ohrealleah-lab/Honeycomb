using System.Diagnostics;
using Avalonia.Controls;
using Avalonia.Interactivity;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

public partial class UpdateAvailableWindow : Window
{
    private readonly UpdateCheckOutcome _outcome;

    public UpdateAvailableWindow(UpdateCheckOutcome outcome)
    {
        InitializeComponent();
        _outcome = outcome;
        MessageText.Text = $"Version {outcome.LatestVersion} of Honeycomb is available. You're on {UpdateCheckService.CurrentVersion}.";
    }

    private void DeclineUpdate_Click(object? sender, RoutedEventArgs e)
    {
        UpdateCheckService.DeclineUpdate();
        Close();
    }

    private void ViewRelease_Click(object? sender, RoutedEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo(_outcome.ReleaseUrl) { UseShellExecute = true });
        }
        catch
        {
            // Best-effort — nothing sensible to do if the OS can't hand off to a browser.
        }
        Close();
    }
}
