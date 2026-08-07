using System;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Threading;

namespace SoliBee.Desktop.Views;

public partial class FlashToast : UserControl
{
    // Matches Mac's non-"First Move:" banner duration (HoneycombView.swift) — "First
    // Move:" itself passes an explicit 2s from Vm_OnFlashBanner instead of using this.
    private static readonly TimeSpan DefaultDuration = TimeSpan.FromSeconds(1.2);

    private DispatcherTimer? _dismissTimer;

    public FlashToast()
    {
        InitializeComponent();
    }

    public event Action? OnDismissed;

    public void Flash(string message, TimeSpan? duration = null)
    {
        MessageText.Text = message;
        MessageText.Foreground = Avalonia.Media.SolidColorBrush.Parse("#FFD600");

        // MainWindow scales each game's board (LayoutTransform on MainContentWrapper) to
        // fit its own natural size into the window — this control lives inside that same
        // scaled subtree, so without correction the identical markup would render larger
        // or smaller depending on which game's zoom happens to be in effect. Counter-scale
        // by the inverse so the toast always reads at its designed size, centered the same
        // way RenderTransform's default center origin already keeps it in place.
        double zoom = (TopLevel.GetTopLevel(this) as MainWindow)?.ContentZoom ?? 1.0;
        RenderTransform = zoom > 0 ? new ScaleTransform(1.0 / zoom, 1.0 / zoom) : null;

        IsVisible = true;
        
        // Use a tiny delay to allow Avalonia to process IsVisible=true before setting Opacity,
        // so the transition engine picks it up.
        Dispatcher.UIThread.Post(() => {
            Opacity = 1;
        }, DispatcherPriority.Render);

        _dismissTimer?.Stop();
        
        // Subtract 0.2s from the wait to account for the fade out time
        var waitDuration = (duration ?? DefaultDuration) - TimeSpan.FromSeconds(0.2);
        if (waitDuration.TotalSeconds <= 0) waitDuration = TimeSpan.FromSeconds(0.1);
        
        _dismissTimer = new DispatcherTimer { Interval = waitDuration };
        _dismissTimer.Tick += (_, _) =>
        {
            _dismissTimer!.Stop();
            Opacity = 0;
            
            var hideTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(0.25) };
            hideTimer.Tick += (s, e) => {
                hideTimer.Stop();
                IsVisible = false;
                _dismissTimer = null;
                OnDismissed?.Invoke();
            };
            hideTimer.Start();
        };
        _dismissTimer.Start();
    }
}
