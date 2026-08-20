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
        int count = 72; // Increased to match Mac/iOS

        var els  = new Shape[count];
        var tx   = new TranslateTransform[count];
        var rot  = new RotateTransform[count];
        var posX = new double[count];
        var posY = new double[count];
        var velX = new double[count];
        var velY = new double[count];
        var rotSpeed = new double[count];

        for (int i = 0; i < count; i++)
        {
            double angle  = rng.NextDouble() * Math.PI * 2;
            bool isBackground = rng.NextDouble() > 0.5;
            double speedMultiplier = isBackground ? 0.8 : 1.0;
            double speed  = (rng.NextDouble() * 7 + 3) * speedMultiplier;
            double baseScale = rng.NextDouble() * 1.0 + 0.6; // 0.6 to 1.6
            double scale = baseScale * (isBackground ? 0.7 : 1.0);
            double blur = isBackground ? rng.NextDouble() * 1.5 + 0.5 : 0;
            
            var color = _palette[rng.Next(_palette.Length)];
            var brush = new SolidColorBrush(color);

            Shape el;
            int shapeType = rng.Next(5);
            if (shapeType == 0 || shapeType == 1) // Rectangles
            {
                el = new Rectangle
                {
                    Width = 10 * scale,
                    Height = 4 * scale,
                    RadiusX = 2,
                    RadiusY = 2,
                    Fill = brush
                };
            }
            else if (shapeType == 2) // Circles
            {
                el = new Ellipse
                {
                    Width = 6 * scale,
                    Height = 6 * scale,
                    Fill = brush
                };
            }
            else if (shapeType == 3) // Ribbons
            {
                el = new Rectangle
                {
                    Width = 14 * scale,
                    Height = 2 * scale,
                    RadiusX = 1,
                    RadiusY = 1,
                    Fill = brush
                };
            }
            else // Stars
            {
                el = new Avalonia.Controls.Shapes.Path
                {
                    Data = Geometry.Parse("M 5,0 L 6.5,3.5 L 10,3.5 L 7,5.5 L 8.5,9.5 L 5,7 L 1.5,9.5 L 3,5.5 L 0,3.5 L 3.5,3.5 Z"),
                    Fill = brush,
                    Width = 10 * scale,
                    Height = 10 * scale,
                    Stretch = Stretch.Uniform
                };
            }

            el.Opacity = 1.0;
            if (blur > 0)
            {
                el.Effect = new BlurEffect { Radius = blur };
            }

            var tgroup = new TransformGroup();
            var rotateTransform = new RotateTransform { Angle = angle * 180 / Math.PI };
            var translateTransform = new TranslateTransform();
            
            // Set render transform origin to center for proper tumbling
            el.RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative);
            
            tgroup.Children.Add(rotateTransform);
            tgroup.Children.Add(translateTransform);
            el.RenderTransform = tgroup;

            Canvas.SetLeft(el, px - el.Width / 2);
            Canvas.SetTop(el,  py - el.Height / 2);
            canvas.Children.Add(el);

            els[i]  = el;
            tx[i]   = translateTransform;
            rot[i]  = rotateTransform;
            posX[i] = px;
            posY[i] = py;
            velX[i] = Math.Cos(angle) * speed;
            velY[i] = Math.Sin(angle) * speed - 2.5; // bias upward
            
            // Tumbling speed
            rotSpeed[i] = (rng.NextDouble() * 20 - 10);
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
                rot[i].Angle += rotSpeed[i];
                
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
