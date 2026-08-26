using System;
using System.Globalization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;

namespace SoliBee.Desktop.Views;

/// Pure-vector casino chip face — no image assets. Mirrors the SwiftUI PokerChipView
/// used by the iOS/mac Blackjack ports (shared/Views/PokerChipView.swift) so all three
/// platforms render the same chip design: a soft drop shadow, a radial-gradient disc,
/// 6 evenly-spaced edge marks, a flat inner inlay disc, and centered denomination text.
/// Purely visual — wrap in a Button (see BlackjackView.axaml's "poker-chip" style) for
/// click handling.
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

    // Shared across every chip instance — these never depend on this control's own
    // BaseColor/StripeColor/TextColor, so there's nothing to rebuild per-instance.
    private static readonly IBrush ShadowBrushOuter = new SolidColorBrush(Colors.Black, 0.12);
    private static readonly IBrush ShadowBrushInner = new SolidColorBrush(Colors.Black, 0.18);
    private static readonly IPen InlayStrokePen = new Pen(new SolidColorBrush(Color.FromArgb(64, 0, 0, 0)), 1);

    // Per-instance brushes derived from BaseColor/StripeColor/TextColor, rebuilt only
    // when one of those actually changes (OnPropertyChanged below) rather than
    // allocated fresh on every Render() call — Render() can run on any invalidation,
    // not just a real color change, so allocating IBrush instances there is wasted GC
    // pressure for values that in practice change rarely if ever. Matches this
    // project's established static/cached-brush convention (see CardView.axaml.cs).
    private IBrush _outerGradientBrush = Brushes.Transparent;
    private IBrush _stripeBrush = Brushes.Transparent;
    private IBrush _inlayBrush = Brushes.Transparent;
    private IBrush _textBrush = Brushes.Transparent;

    static PokerChipFace()
    {
        AffectsRender<PokerChipFace>(LabelProperty, BaseColorProperty, StripeColorProperty, TextColorProperty, DiameterProperty);
        AffectsMeasure<PokerChipFace>(DiameterProperty);
    }

    public PokerChipFace()
    {
        RebuildColorBrushes();
    }

    protected override void OnPropertyChanged(AvaloniaPropertyChangedEventArgs change)
    {
        base.OnPropertyChanged(change);
        if (change.Property == BaseColorProperty || change.Property == StripeColorProperty || change.Property == TextColorProperty)
        {
            RebuildColorBrushes();
        }
    }

    private void RebuildColorBrushes()
    {
        var baseColor = BaseColor;
        _outerGradientBrush = new RadialGradientBrush
        {
            GradientStops =
            {
                new GradientStop(Color.FromArgb((byte)(baseColor.A * 0.92), baseColor.R, baseColor.G, baseColor.B), 0),
                new GradientStop(baseColor, 1),
            },
        };
        _stripeBrush = new SolidColorBrush(StripeColor);
        _inlayBrush = new SolidColorBrush(baseColor);
        _textBrush = new SolidColorBrush(TextColor);
    }

    // The drop shadow (below) is drawn a few px larger than the disc itself, so the
    // control needs to measure a bit bigger than Diameter or that overshoot gets
    // clipped flat at the control's own (square) layout bounds by the containing
    // ContentPresenter — a circle cropped by a square edge reads as a rounded square,
    // not a shadow. This padding gives the shadow room without affecting the disc's
    // own drawn size.
    private const double ShadowPadding = 4;

    protected override Size MeasureOverride(Size availableSize) =>
        new(Diameter + ShadowPadding * 2, Diameter + ShadowPadding * 2);

    public override void Render(DrawingContext context)
    {
        var d = Diameter;
        var center = new Point(ShadowPadding + d / 2, ShadowPadding + d / 2);

        // 0. Soft drop shadow behind the disc — matches the SwiftUI original's
        //    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2). DrawingContext
        //    has no blur primitive, so this approximates the blur with two progressively
        //    larger, progressively fainter offset ellipses instead of one hard-edged one.
        var shadowCenter = new Point(center.X, center.Y + 2);
        context.DrawEllipse(ShadowBrushOuter, null, shadowCenter, d / 2 + 3, d / 2 + 3);
        context.DrawEllipse(ShadowBrushInner, null, shadowCenter, d / 2 + 1.5, d / 2 + 1.5);

        // 1. Base outer disc with a radial "3D depth" gradient — brighter center fading
        //    to the flat base color at the rim.
        context.DrawEllipse(_outerGradientBrush, null, center, d / 2, d / 2);

        // 2. Six evenly-spaced edge marks — draw once at 12 o'clock, then rotate the
        //    drawing surface around the chip's center for each of the remaining five.
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
                context.DrawRectangle(_stripeBrush, null, markRect);
            }
        }

        // 3. Flat solid inner inlay disc.
        context.DrawEllipse(_inlayBrush, InlayStrokePen, center, d * 0.31, d * 0.31);

        // 4. Ultra-bold denomination text, centered.
        var text = new FormattedText(
            Label,
            CultureInfo.InvariantCulture,
            FlowDirection.LeftToRight,
            new Typeface("Segoe UI", FontStyle.Normal, FontWeight.Black),
            d * 0.32,
            _textBrush);
        context.DrawText(text, new Point(center.X - text.Width / 2, center.Y - text.Height / 2));
    }
}
