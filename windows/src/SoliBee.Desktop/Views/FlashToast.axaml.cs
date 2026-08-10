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

    // "Manually Dismiss Banners": when true, the toast accepts a click (IsHitTestVisible
    // — normally False so toasts never block board clicks) and skips the auto-dismiss
    // timer entirely, staying up until Dismiss() is called explicitly (from this click,
    // or from the game view's own board-wide tap-catcher — see each Vm_OnFlashBanner).
    public void Flash(string message, TimeSpan? duration = null, bool manualDismiss = false)
    {
        MessageText.Text = message;
        MessageText.Foreground = Avalonia.Media.SolidColorBrush.Parse("#FFD600");

        IsVisible = true;
        IsHitTestVisible = manualDismiss;

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
