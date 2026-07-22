using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

public partial class BackgroundEditorWindow : Window
{
    // Offsets are stored/edited in "reference-width" units (see MainWindow.BackgroundReferenceWidth)
    // so they scale consistently between this small preview and the real, resizable window.
    private const double ReferenceWidth = 1120.0;
    private const double PreviewWidth = 280.0;
    private static readonly double PreviewRatio = PreviewWidth / ReferenceWidth;

    private readonly bool _isNew;
    // The window takes ownership of the bitmap passed to it and disposes it on close.
    // This ensures the underlying native file handle is released before the caller's
    // File.Delete on the cancel path (fixing the file-handle leak from the code review).
    private Bitmap? _image;

    public bool Saved { get; private set; }
    public string NewName { get; private set; } = "";
    public double NewScale { get; private set; } = 1.0;
    public double NewOffsetX { get; private set; }
    public double NewOffsetY { get; private set; }

    // isNew: true when this is a freshly-imported background (name is editable); false when
    // re-editing an existing one (name is locked — renaming isn't supported, matching the
    // card-back/face-art precedent).
    public BackgroundEditorWindow(Bitmap image, bool isNew, string initialName,
        double scale, double offsetX, double offsetY)
    {
        _isNew = isNew;
        _image = image;
        InitializeComponent();
        this.Closed += (_, _) => { _image?.Dispose(); _image = null; };
        this.Loaded += (_, _) => OnLoaded(image, initialName, scale, offsetX, offsetY);
    }

    private void OnLoaded(Bitmap image, string initialName, double scale, double offsetX, double offsetY)
    {
        Title = _isNew ? "Add Background" : "Edit Background";

        NameTextBox.Text = initialName;
        NameTextBox.IsEnabled = _isNew;

        PreviewImage.Source = image;

        // Read-only snapshot of the shared vignette toggle — never written back from here.
        // Assigning it once here (rather than binding it) avoids the exact bug class the
        // macOS build hit: a two-way-observed property that fires on load as well as on
        // genuine user changes, silently overwriting settings on relaunch.
        bool vignetteEnabled = SettingsService.LoadOptions().IsVignetteEnabled;
        PreviewVignette.IsVisible = vignetteEnabled;

        ScaleSlider.ValueChanged -= Slider_Changed;
        OffsetXSlider.ValueChanged -= Slider_Changed;
        OffsetYSlider.ValueChanged -= Slider_Changed;
        ScaleSlider.Value = scale;
        OffsetXSlider.Value = offsetX;
        OffsetYSlider.Value = offsetY;
        ScaleSlider.ValueChanged += Slider_Changed;
        OffsetXSlider.ValueChanged += Slider_Changed;
        OffsetYSlider.ValueChanged += Slider_Changed;

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
        tg.Children.Add(new TranslateTransform(offsetX * PreviewRatio, offsetY * PreviewRatio));
        PreviewImage.RenderTransform = tg;
    }

    private void Save_Click(object? sender, RoutedEventArgs e)
    {
        if (_isNew)
        {
            var name = NameTextBox.Text?.Trim();
            if (string.IsNullOrEmpty(name)) return;
            NewName = name;
        }

        NewScale = ScaleSlider.Value;
        NewOffsetX = OffsetXSlider.Value;
        NewOffsetY = OffsetYSlider.Value;
        Saved = true;
        Close();
    }

    private void Cancel_Click(object? sender, RoutedEventArgs e)
    {
        Saved = false;
        Close();
    }
}
