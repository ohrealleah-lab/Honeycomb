using System;
using Avalonia.Threading;

namespace SoliBee.Desktop.Views;

// Shared pulse driver for hint highlights: an ease-in/out glow that completes
// exactly 4 pulses over a 2-second window, used by both CardView (per-card
// highlight) and PileView (whole-pile highlight) so the two stay in sync.
internal sealed class HintPulseAnimation
{
    private const double TotalMs = 2000;
    private const int Pulses = 4;

    private DispatcherTimer? _timer;
    private double _elapsedMs;

    public void Start(Action<double> onAlpha)
    {
        Stop();
        _elapsedMs = 0;
        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _timer.Tick += (_, _) =>
        {
            _elapsedMs += 16;
            if (_elapsedMs >= TotalMs)
            {
                Stop();
                return;
            }
            double phase = _elapsedMs / TotalMs * Pulses * 2 * Math.PI;
            double alpha = (1 - Math.Cos(phase)) / 2; // eases 0 -> 1 -> 0, 4 times over the window
            onAlpha(alpha);
        };
        _timer.Start();
    }

    public void Stop()
    {
        _timer?.Stop();
        _timer = null;
    }
}
