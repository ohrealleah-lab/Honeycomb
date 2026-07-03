using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Media.Imaging;

namespace SoliBee.Desktop.Views;

public partial class CardBackEditorWindow : Window
{
    private readonly bool _isFill;

    public bool Saved { get; private set; }
    public double NewScale { get; private set; } = 1.0;
    public double NewOffsetX { get; private set; }
    public double NewOffsetY { get; private set; }

    // isFill: true for themes that stretch to fill (Dingwall) — sliders are irrelevant
    public CardBackEditorWindow(Bitmap image, bool isFill, double scale, double offsetX, double offsetY)
    {
        _isFill = isFill;
        InitializeComponent();
        this.Loaded += (_, _) => OnLoaded(image, scale, offsetX, offsetY);
    }

    private void OnLoaded(Bitmap image, double scale, double offsetX, double offsetY)
    {
        if (_isFill)
        {
            PreviewImage.Source = image;
            PreviewImage.Stretch = Stretch.Fill;
            PreviewImage.Width = 128;
            PreviewImage.Height = 181;
            SliderPanel.IsVisible = false;
            FillNote.IsVisible = true;
        }
        else
        {
            PreviewImage.Source = image;
            PreviewImage.Stretch = Stretch.Uniform;
            PreviewImage.Width = 120;
            PreviewImage.Height = 173;

            // Set initial slider values without triggering the change handler
            ScaleSlider.ValueChanged -= Slider_Changed;
            OffsetXSlider.ValueChanged -= Slider_Changed;
            OffsetYSlider.ValueChanged -= Slider_Changed;
            ScaleSlider.Value = scale;
            OffsetXSlider.Value = offsetX;
            OffsetYSlider.Value = offsetY;
            ScaleSlider.ValueChanged += Slider_Changed;
            OffsetXSlider.ValueChanged += Slider_Changed;
            OffsetYSlider.ValueChanged += Slider_Changed;
        }

        UpdatePreview();
    }

    private void Slider_Changed(object? sender, RangeBaseValueChangedEventArgs e) =>
        UpdatePreview();

    private void UpdatePreview()
    {
        if (ScaleSlider == null || _isFill) return;

        double scale = ScaleSlider.Value;
        double offsetX = OffsetXSlider.Value;
        double offsetY = OffsetYSlider.Value;

        ScaleValueText.Text = scale.ToString("F2");
        OffsetXValueText.Text = ((int)offsetX).ToString();
        OffsetYValueText.Text = ((int)offsetY).ToString();

        if (Math.Abs(scale - 1.0) > 0.01 || Math.Abs(offsetX) > 0.01 || Math.Abs(offsetY) > 0.01)
        {
            PreviewImage.RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative);
            var tg = new TransformGroup();
            tg.Children.Add(new ScaleTransform(scale, scale));
            tg.Children.Add(new TranslateTransform(offsetX, offsetY));
            PreviewImage.RenderTransform = tg;
        }
        else
        {
            PreviewImage.RenderTransform = null;
        }
    }

    private void Save_Click(object? sender, RoutedEventArgs e)
    {
        NewScale = _isFill ? 1.0 : ScaleSlider.Value;
        NewOffsetX = _isFill ? 0.0 : OffsetXSlider.Value;
        NewOffsetY = _isFill ? 0.0 : OffsetYSlider.Value;
        Saved = true;
        Close();
    }

    private void Cancel_Click(object? sender, RoutedEventArgs e)
    {
        Saved = false;
        Close();
    }
}
