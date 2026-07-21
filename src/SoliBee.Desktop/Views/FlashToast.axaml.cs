using System;
using Avalonia.Controls;
using Avalonia.Threading;

namespace SoliBee.Desktop.Views;

public partial class FlashToast : UserControl
{
    private static readonly TimeSpan DefaultDuration = TimeSpan.FromSeconds(1.6);

    private DispatcherTimer? _dismissTimer;

    public FlashToast()
    {
        InitializeComponent();
    }

    // Shows message, then hides itself again after duration (default 1.6s) — callers
    // don't need to track or clear their own timer for this. A second Flash() call
    // while one is still showing just restarts the clock with the new message.
    public void Flash(string message, TimeSpan? duration = null)
    {
        MessageText.Text = message;
        IsVisible = true;

        _dismissTimer?.Stop();
        _dismissTimer = new DispatcherTimer { Interval = duration ?? DefaultDuration };
        _dismissTimer.Tick += (_, _) =>
        {
            _dismissTimer!.Stop();
            _dismissTimer = null;
            IsVisible = false;
        };
        _dismissTimer.Start();
    }
}
