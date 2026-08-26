using System;
using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;

namespace SoliBee.Desktop.Views;

/// Pure-vector casino chip face — no image assets. Mirrors the SwiftUI PokerChipView
/// used by the iOS/mac Blackjack ports (shared/Views/PokerChipView.swift) so all three
/// platforms render the same chip design: a radial-gradient disc, 6 evenly-spaced edge
/// marks, a flat inner inlay disc, and centered denomination text. Purely visual —
/// wrap in a Button (see BlackjackView.axaml's "poker-chip" style) for click handling.
public class PokerChipFace : Control
{
    public static readonly StyledProperty<string> LabelProperty =
        AvaloniaProperty.Register<PokerChipFace, string>(nameof(Label), string.Empty);
    public static readonly StyledProperty<Color> BaseColorProperty =
        AvaloniaProperty.Register<PokerChipFace, Color>(nameof(BaseColor));
    public static readonly StyledProperty<Color> StripeColorProperty =
        AvaloniaProperty.Register<PokerChipFace, Color>(nameof(StripeColor));
    public static readonly StyledProperty<Color> TextColorProperty =
        AvaloniaProperty.Register<PokerChipFace, Color>(nameof(TextColor));
    public static readonly StyledProperty<double> DiameterProperty =
        AvaloniaProperty.Register<PokerChipFace, double>(nameof(Diameter), 46.0);

    public string Label { get => GetValue(LabelProperty); set => SetValue(LabelProperty, value); }
    public Color BaseColor { get => GetValue(BaseColorProperty); set => SetValue(BaseColorProperty, value); }
    public Color StripeColor { get => GetValue(StripeColorProperty); set => SetValue(StripeColorProperty, value); }
    public Color TextColor { get => GetValue(TextColorProperty); set => SetValue(TextColorProperty, value); }
    public double Diameter { get => GetValue(DiameterProperty); set => SetValue(DiameterProperty, value); }

    // Real casino chips have a fixed number of edge marks regardless of chip size — a
    // dashed circular stroke instead produces however many dash/gap segments happen to
    // fit the circumference at a given diameter (rarely a clean divisor of it, so the
    // pattern visibly seams where it wraps back to the start). Six explicit marks,
    // each drawn once and rotated around the center, always renders exactly six,
    // evenly spaced, at any diameter.
    private const int EdgeMarkCount = 6;

    static PokerChipFace()
    {
        AffectsRender<PokerChipFace>(LabelProperty, BaseColorProperty, StripeColorProperty, TextColorProperty, DiameterProperty);
        AffectsMeasure<PokerChipFace>(DiameterProperty);
    }

    protected override Size MeasureOverride(Size availableSize) => new(Diameter, Diameter);

    public override void Render(DrawingContext context)
    {
        var d = Diameter;
        var center = new Point(d / 2, d / 2);

        // 1. Base outer disc with a radial "3D depth" gradient — brighter center fading
        //    to the flat base color at the rim.
        var baseColor = BaseColor;
        var gradient = new RadialGradientBrush
        {
            GradientStops =
            {
                new GradientStop(Color.FromArgb((byte)(baseColor.A * 0.92), baseColor.R, baseColor.G, baseColor.B), 0),
                new GradientStop(baseColor, 1),
            },
        };
        context.DrawEllipse(gradient, null, center, d / 2, d / 2);

        // 2. Six evenly-spaced edge marks — draw once at 12 o'clock, then rotate the
        //    drawing surface around the chip's center for each of the remaining five.
        var stripeBrush = new SolidColorBrush(StripeColor);
        var markWidth = d * 0.10;
        var markHeight = d * 0.16;
        var markRect = new RoundedRect(
            new Rect(center.X - markWidth / 2, center.Y - d * 0.40 - markHeight / 2, markWidth, markHeight),
            d * 0.02);
        for (var i = 0; i < EdgeMarkCount; i++)
        {
            var angle = i * 2 * Math.PI / EdgeMarkCount;
            // Matrix.CreateRotation only rotates around the origin, so rotating around
            // the chip's own center is composed by hand: shift the center to the
            // origin, rotate, then shift back.
            var rotateAroundCenter = Matrix.CreateTranslation(-center.X, -center.Y)
                * Matrix.CreateRotation(angle)
                * Matrix.CreateTranslation(center.X, center.Y);
            using (context.PushTransform(rotateAroundCenter))
            {
                context.DrawRectangle(stripeBrush, null, markRect);
            }
        }

        // 3. Flat solid inner inlay disc.
        context.DrawEllipse(
            new SolidColorBrush(baseColor),
            new Pen(new SolidColorBrush(Color.FromArgb(64, 0, 0, 0)), 1),
            center, d * 0.31, d * 0.31);

        // 4. Ultra-bold denomination text, centered.
        var text = new FormattedText(
            Label,
            CultureInfo.InvariantCulture,
            FlowDirection.LeftToRight,
            new Typeface("Segoe UI", FontStyle.Normal, FontWeight.Black),
            d * 0.32,
            new SolidColorBrush(TextColor));
        context.DrawText(text, new Point(center.X - text.Width / 2, center.Y - text.Height / 2));
    }
}
