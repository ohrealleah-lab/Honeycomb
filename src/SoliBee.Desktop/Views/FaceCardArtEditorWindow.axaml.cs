using System.Runtime.InteropServices;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using SkiaSharp;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

public partial class FaceCardArtEditorWindow : Window
{
    private readonly CustomFaceArt _art;
    private readonly FaceCardSlot _slot;

    public bool Saved { get; private set; }
    public CustomFaceArt Art => _art;

    public FaceCardArtEditorWindow(CustomFaceArt art, FaceCardSlot slot)
    {
        _art = new CustomFaceArt
        {
            Id = art.Id,
            Slot = art.Slot,
            RelativePath = art.RelativePath,
            Scale = art.Scale,
            OffsetX = art.OffsetX,
            OffsetY = art.OffsetY,
            IsEnabled = art.IsEnabled
        };
        _slot = slot;
        InitializeComponent();
        this.Loaded += OnLoaded;
    }

    private void OnLoaded(object? sender, RoutedEventArgs e)
    {
        bool isRed = _slot.GetIsRed();
        string rankLabel = _slot.GetRankLabel();
        string suitChar = _slot.GetSuitSymbol();
        var color = isRed ? Color.Parse("#CC1A1A") : Color.Parse("#1A1A1A");
        var brush = new SolidColorBrush(color);

        PreviewRankText.Text = rankLabel;
        PreviewRankTextBottom.Text = rankLabel;
        PreviewSuitText.Text = suitChar;
        PreviewSuitTextBottom.Text = suitChar;
        PreviewRankText.Foreground = brush;
        PreviewRankTextBottom.Foreground = brush;
        PreviewSuitText.Foreground = brush;
        PreviewSuitTextBottom.Foreground = brush;

        // Disable slider change events during init
        ScaleSlider.ValueChanged -= Slider_Changed;
        OffsetXSlider.ValueChanged -= Slider_Changed;
        OffsetYSlider.ValueChanged -= Slider_Changed;

        ScaleSlider.Value = _art.Scale;
        OffsetXSlider.Value = _art.OffsetX;
        OffsetYSlider.Value = _art.OffsetY;

        ScaleSlider.ValueChanged += Slider_Changed;
        OffsetXSlider.ValueChanged += Slider_Changed;
        OffsetYSlider.ValueChanged += Slider_Changed;

        // Load art image (first frame for GIFs)
        try
        {
            var path = FaceCardArtService.GetFullPath(_art);
            Bitmap? bmp = null;

            if (FaceCardArtService.IsGif(_art))
            {
                using var codec = SKCodec.Create(path);
                if (codec != null)
                {
                    var info = new SKImageInfo(codec.Info.Width, codec.Info.Height,
                        SKColorType.Bgra8888, SKAlphaType.Premul);
                    using var skBmp = new SKBitmap(info);
                    codec.GetPixels(info, skBmp.GetPixels(), new SKCodecOptions(0));
                    var wb = new WriteableBitmap(
                        new PixelSize(info.Width, info.Height),
                        new Vector(96, 96),
                        PixelFormat.Bgra8888, AlphaFormat.Premul);
                    using (var fb = wb.Lock())
                        Marshal.Copy(skBmp.Bytes, 0, fb.Address, skBmp.ByteCount);
                    bmp = wb;
                }
            }

            bmp ??= new Bitmap(path);
            PreviewImage.Source = bmp;
        }
        catch { }

        UpdatePreview();
    }

    private void Slider_Changed(object? sender, RangeBaseValueChangedEventArgs e) =>
        UpdatePreview();

    private void UpdatePreview()
    {
        if (ScaleSlider == null) return;

        double scale = ScaleSlider.Value;
        double offsetX = OffsetXSlider.Value;
        double offsetY = OffsetYSlider.Value;

        ScaleValueText.Text = scale.ToString("F2");
        OffsetXValueText.Text = ((int)offsetX).ToString();
        OffsetYValueText.Text = ((int)offsetY).ToString();

        PreviewImage.RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative);
        var tg = new TransformGroup();
        tg.Children.Add(new ScaleTransform(scale, scale));
        tg.Children.Add(new TranslateTransform(offsetX, offsetY));
        PreviewImage.RenderTransform = tg;
    }

    private void Save_Click(object? sender, RoutedEventArgs e)
    {
        _art.Scale = ScaleSlider.Value;
        _art.OffsetX = OffsetXSlider.Value;
        _art.OffsetY = OffsetYSlider.Value;
        Saved = true;
        Close();
    }

    private void Cancel_Click(object? sender, RoutedEventArgs e)
    {
        Saved = false;
        Close();
    }
}
