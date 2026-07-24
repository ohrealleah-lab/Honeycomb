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

    public event Action? OnDismissed;

    public void Flash(string message, TimeSpan? duration = null)
    {
        MessageText.Text = message;
        MessageText.Foreground = Avalonia.Media.SolidColorBrush.Parse("#FFD600");
            
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
