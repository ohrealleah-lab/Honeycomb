using System;
using System.Collections.Generic;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Shapes;
using Avalonia.Media;
using Avalonia.Threading;

namespace SoliBee.Desktop.Views;

internal static class WinParticleSystem
{
    private static readonly Color[] _palette =
    {
        Color.Parse("#FFD700"), Color.Parse("#FFB300"), Color.Parse("#FF6B6B"),
        Color.Parse("#4FC3F7"), Color.Parse("#81C784"), Color.Parse("#FF8A65"),
        Color.Parse("#CE93D8"), Color.Parse("#FFFFFF"),
    };

    public static void Burst(Canvas canvas)
    {
        Dispatcher.UIThread.Post(() => DoBurst(canvas));
    }

    private static void DoBurst(Canvas canvas)
    {
        double w = canvas.Bounds.Width;
        double h = canvas.Bounds.Height;
        if (w < 1) { w = 600; h = 400; }

        double px = w / 2;
        double py = h * 0.40;

        var rng   = new Random();
        int count = rng.Next(20, 26);

        var els  = new Ellipse[count];
        var tx   = new TranslateTransform[count];
        var posX = new double[count];
        var posY = new double[count];
        var velX = new double[count];
        var velY = new double[count];

        for (int i = 0; i < count; i++)
        {
            double angle  = rng.NextDouble() * Math.PI * 2;
            double speed  = rng.NextDouble() * 7 + 3;
            double radius = rng.NextDouble() * 4 + 3;
            var color     = _palette[rng.Next(_palette.Length)];

            var particleTx = new TranslateTransform();
            var el = new Ellipse
            {
                Width           = radius * 2,
                Height          = radius * 2,
                Fill            = new SolidColorBrush(color),
                Opacity         = 1.0,
                RenderTransform = particleTx,
            };
            // Left/Top are set once here (the particle's static origin, radius offset
            // baked in) and never touched again — the tick loop below drives motion
            // entirely through RenderTransform so it skips layout every frame instead
            // of re-arranging the Canvas on each of the ~87 ticks in a burst.
            Canvas.SetLeft(el, px - radius);
            Canvas.SetTop(el,  py - radius);
            canvas.Children.Add(el);

            els[i]  = el;
            tx[i]   = particleTx;
            posX[i] = px;
            posY[i] = py;
            velX[i] = Math.Cos(angle) * speed;
            velY[i] = Math.Sin(angle) * speed - 2.5; // bias upward
        }

        const int totalMs = 1400;
        int elapsed = 0;

        var timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        timer.Tick += (_, _) =>
        {
            elapsed += 16;
            bool any = false;
            for (int i = 0; i < count; i++)
            {
                if (els[i].Opacity <= 0) continue;
                velX[i] *= 0.97;
                velY[i] = velY[i] * 0.97 + 0.4; // drag + gravity
                posX[i] += velX[i];
                posY[i] += velY[i];
                tx[i].X = posX[i] - px;
                tx[i].Y = posY[i] - py;
                double life = Math.Max(0, 1.0 - elapsed / (double)totalMs);
                els[i].Opacity = life;
                if (life > 0) any = true;
            }
            if (!any)
            {
                timer.Stop();
                foreach (var el in els)
                    canvas.Children.Remove(el);
            }
        };
        timer.Start();
    }
}
