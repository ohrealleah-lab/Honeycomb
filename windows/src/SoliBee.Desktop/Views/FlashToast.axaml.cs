using System;
using Avalonia.Controls;
using Avalonia.Threading;

namespace SoliBee.Desktop.Views;

public partial class FlashToast : UserControl
{
    // All toasts across every game display for the same 2.0s — deliberately uniform,
    // not tiered by banner "importance." Matches Mac's flashQueuedBanner/
    // flashRuleBannerTrigger, which also always pass 2.0s.
    private static readonly TimeSpan DefaultDuration = TimeSpan.FromSeconds(2.0);

    private DispatcherTimer? _dismissTimer;

    public FlashToast()
    {
        InitializeComponent();
        PointerPressed += (_, _) => { if (IsHitTestVisible) Dismiss(); };
    }

    public event Action? OnDismissed;

    // "Manually Dismiss Banners": when true, skips the auto-dismiss timer entirely,
    // staying up until Dismiss() is called explicitly. The toast is ALWAYS clickable
    // (IsHitTestVisible=true) regardless of manualDismiss's value here — it used to be
    // gated on it, but if the player turned the option off while a manually-shown toast
    // (no timer was ever scheduled for it) was still on screen, the toast became
    // permanently stuck: not clickable anymore, and nothing left to time it out either.
    // Clicking to dismiss now always works, so a toast can never end up in a state
    // where nothing can close it.
    public void Flash(string message, TimeSpan? duration = null, bool manualDismiss = false)
    {
        MessageText.Text = message;
        MessageText.Foreground = Avalonia.Media.SolidColorBrush.Parse("#FFD600");

        IsVisible = true;
        IsHitTestVisible = true;

        // Use a tiny delay to allow Avalonia to process IsVisible=true before setting Opacity,
        // so the transition engine picks it up.
        Dispatcher.UIThread.Post(() => {
            Opacity = 1;
        }, DispatcherPriority.Render);

        _dismissTimer?.Stop();
        _dismissTimer = null;

        if (manualDismiss) return;

        // Subtract 0.2s from the wait to account for the fade out time
        var waitDuration = (duration ?? DefaultDuration) - TimeSpan.FromSeconds(0.2);
        if (waitDuration.TotalSeconds <= 0) waitDuration = TimeSpan.FromSeconds(0.1);

        _dismissTimer = new DispatcherTimer { Interval = waitDuration };
        _dismissTimer.Tick += (_, _) =>
        {
            _dismissTimer!.Stop();
            Dismiss();
        };
        _dismissTimer.Start();
    }

    // Fades out and hides the toast, then fires OnDismissed — shared by the auto-dismiss
    // timer and manual-dismiss triggers (toast click, board tap-catcher).
    public void Dismiss()
    {
        _dismissTimer?.Stop();
        _dismissTimer = null;
        Opacity = 0;

        var hideTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(0.25) };
        hideTimer.Tick += (s, e) => {
            hideTimer.Stop();
            IsVisible = false;
            IsHitTestVisible = false;
            OnDismissed?.Invoke();
        };
        hideTimer.Start();
    }
}
