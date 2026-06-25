using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using Avalonia.Platform.Storage;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public partial class PreferencesView : UserControl
{
    private bool _initializing = true;
    private Bitmap? _cardBackPreviewBitmap;

    public bool ShowVegasOption
    {
        get => VegasCheckBox.IsVisible;
        set => VegasCheckBox.IsVisible = value;
    }

    public PreferencesView()
    {
        InitializeComponent();
        this.Loaded += PreferencesView_Loaded;
    }

    private void PopulateCardBacks(GameOptions options)
    {
        CardBackComboBox.Items.Clear();
        
        CardBackComboBox.Items.Add(new ComboBoxItem { Content = "Vulpera", Tag = "Vulpera" });
        CardBackComboBox.Items.Add(new ComboBoxItem { Content = "Dingwall", Tag = "Dingwall" });
        CardBackComboBox.Items.Add(new ComboBoxItem { Content = "Moogle", Tag = "Moogle" });

        foreach (var cb in options.CustomCardBacks)
        {
            CardBackComboBox.Items.Add(new ComboBoxItem { Content = cb.Name, Tag = cb.Name });
        }
    }

    private void PreferencesView_Loaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is GameOptions options)
        {
            // Select FeltColor in ComboBox
            foreach (var item in FeltColorComboBox.Items.OfType<ComboBoxItem>())
            {
                if (item.Tag?.ToString() == options.FeltColor.ToString())
                {
                    FeltColorComboBox.SelectedItem = item;
                    break;
                }
            }

            // Populate CardBacks
            PopulateCardBacks(options);

            // Select CardBackTheme
            foreach (var item in CardBackComboBox.Items.OfType<ComboBoxItem>())
            {
                if (item.Tag?.ToString() == options.CardBackTheme)
                {
                    CardBackComboBox.SelectedItem = item;
                    bool isCustom = options.CardBackTheme != "Vulpera" && options.CardBackTheme != "Dingwall" && options.CardBackTheme != "Moogle";
                    DeleteCustomCardBackButton.IsEnabled = isCustom;
                    break;
                }
            }

            TimedCheckBox.IsChecked = options.IsTimed;
            SoundCheckBox.IsChecked = options.IsSoundEnabled;
            VegasCheckBox.IsChecked = options.IsVegasScoring;
            FinalFantasyCheckBox.IsChecked = options.IsFinalFantasyMode;

            UpdateCardBackPreview(options);

            if (options.FeltColor == FeltColorTheme.Custom)
            {
                CustomColorPanel.IsVisible = true;
                if (Color.TryParse(options.CustomFeltColorHex, out var parsedColor))
                {
                    FeltColorPicker.Color = parsedColor;
                }
            }
            else
            {
                CustomColorPanel.IsVisible = false;
            }
        }
        _initializing = false;
    }

    private void FeltColorComboBox_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (_initializing) return;

        if (DataContext is GameOptions options && FeltColorComboBox.SelectedItem is ComboBoxItem item && item.Tag != null)
        {
            if (Enum.TryParse<FeltColorTheme>(item.Tag.ToString(), out var feltTheme))
            {
                options.FeltColor = feltTheme;

                if (feltTheme == FeltColorTheme.Custom)
                {
                    CustomColorPanel.IsVisible = true;
                    if (Color.TryParse(options.CustomFeltColorHex, out var parsedColor))
                    {
                        FeltColorPicker.Color = parsedColor;
                    }
                }
                else
                {
                    CustomColorPanel.IsVisible = false;
                }

                options.CustomFeltColorRevision++;
                NotifySettingsChanged(options);
            }
        }
    }

    private void FeltColorPicker_ColorChanged(object? sender, ColorChangedEventArgs e)
    {
        if (_initializing) return;

        if (DataContext is GameOptions options)
        {
            options.CustomFeltColorHex = e.NewColor.ToString();
            options.CustomFeltColorRevision++;
            NotifySettingsChanged(options);
        }
    }

    private void CardBackComboBox_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (_initializing) return;

        if (DataContext is GameOptions options && CardBackComboBox.SelectedItem is ComboBoxItem item && item.Tag != null)
        {
            var selectedTag = item.Tag.ToString()!;
            options.CardBackTheme = selectedTag;

            bool isCustom = selectedTag != "Vulpera" && selectedTag != "Dingwall" && selectedTag != "Moogle";
            DeleteCustomCardBackButton.IsEnabled = isCustom;

            var customBack = options.CustomCardBacks.Find(c => c.Name == selectedTag);
            if (customBack != null)
            {
                options.CardBackScale = customBack.Scale;
                options.CardBackOffsetX = customBack.OffsetX;
                options.CardBackOffsetY = customBack.OffsetY;
            }
            else if (selectedTag == "Moogle")
            {
                options.CardBackScale = 1.25;
                options.CardBackOffsetX = 0;
                options.CardBackOffsetY = 0;
            }
            else
            {
                options.CardBackScale = 1.0;
                options.CardBackOffsetX = 0;
                options.CardBackOffsetY = 0;
            }

            UpdateCardBackPreview(options);
            NotifySettingsChanged(options);
        }
    }

    private void Option_Changed(object? sender, RoutedEventArgs e)
    {
        if (_initializing) return;

        if (DataContext is GameOptions options)
        {
            options.IsTimed = TimedCheckBox.IsChecked ?? false;
            options.IsSoundEnabled = SoundCheckBox.IsChecked ?? false;
            options.IsVegasScoring = VegasCheckBox.IsChecked ?? false;
            options.IsFinalFantasyMode = FinalFantasyCheckBox.IsChecked ?? false;
            NotifySettingsChanged(options);
        }
    }

    private void UpdateCardBackPreview(GameOptions options)
    {
        bool isDingwall = options.CardBackTheme == "Dingwall";
        var old = _cardBackPreviewBitmap;
        _cardBackPreviewBitmap = LoadCardBackBitmapForPreview(options);
        CardBackPreviewImage.Source = _cardBackPreviewBitmap;
        old?.Dispose();

        if (isDingwall)
        {
            CardBackPreviewImage.Stretch = Stretch.Fill;
            CardBackPreviewImage.RenderTransform = null;
        }
        else
        {
            CardBackPreviewImage.Stretch = Stretch.Uniform;
            double scale = options.CardBackScale;
            double tileRatio = 80.0 / 128.0;
            double offsetX = options.CardBackOffsetX * tileRatio;
            double offsetY = options.CardBackOffsetY * tileRatio;

            if (Math.Abs(scale - 1.0) > 0.01 || Math.Abs(offsetX) > 0.01 || Math.Abs(offsetY) > 0.01)
            {
                CardBackPreviewImage.RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative);
                var tg = new TransformGroup();
                tg.Children.Add(new ScaleTransform(scale, scale));
                tg.Children.Add(new TranslateTransform(offsetX, offsetY));
                CardBackPreviewImage.RenderTransform = tg;
            }
            else
            {
                CardBackPreviewImage.RenderTransform = null;
            }
        }
    }

    private static Bitmap? LoadCardBackBitmapForPreview(GameOptions options)
    {
        try
        {
            string theme = options.CardBackTheme;
            if (theme == "Dingwall")
                return new Bitmap(AssetLoader.Open(new Uri("avares://SoliBee.Desktop/Assets/dingwall.jpg")));
            if (theme == "Moogle")
                return new Bitmap(AssetLoader.Open(new Uri("avares://SoliBee.Desktop/Assets/moogle.jpg")));
            if (theme == "Vulpera")
                return new Bitmap(AssetLoader.Open(new Uri("avares://SoliBee.Desktop/Assets/vulpera.png")));

            var customBack = options.CustomCardBacks.Find(c => c.Name == theme);
            if (customBack != null)
            {
                var path = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "SoliBee", "CardBacks", customBack.FileName);
                if (File.Exists(path))
                    return new Bitmap(path);
            }
            return new Bitmap(AssetLoader.Open(new Uri("avares://SoliBee.Desktop/Assets/vulpera.png")));
        }
        catch { return null; }
    }

    private bool _isEditorOpen;

    private async void CardBackPreview_Click(object? sender, PointerPressedEventArgs e)
    {
        // Release implicit pointer capture immediately so the dialog and parent window
        // don't have stale capture state after the dialog closes — without this, all
        // subsequent pointer events are routed back to this border (re-opening the editor).
        e.Handled = true;
        e.Pointer.Capture(null);

        if (_isEditorOpen) return;
        if (DataContext is not GameOptions options) return;

        _isEditorOpen = true;
        try
        {
            bool isDingwall = options.CardBackTheme == "Dingwall";
            var bmp = _cardBackPreviewBitmap ?? LoadCardBackBitmapForPreview(options);
            if (bmp == null) return;

            var owner = (Window?)TopLevel.GetTopLevel(this);
            var editor = new CardBackEditorWindow(bmp, isDingwall,
                options.CardBackScale, options.CardBackOffsetX, options.CardBackOffsetY);

            if (owner != null)
                await editor.ShowDialog(owner);
            else
                editor.Show();

            if (editor.Saved && !isDingwall)
            {
                options.CardBackScale = editor.NewScale;
                options.CardBackOffsetX = editor.NewOffsetX;
                options.CardBackOffsetY = editor.NewOffsetY;

                var customBack = options.CustomCardBacks.Find(c => c.Name == options.CardBackTheme);
                if (customBack != null)
                {
                    customBack.Scale = editor.NewScale;
                    customBack.OffsetX = editor.NewOffsetX;
                    customBack.OffsetY = editor.NewOffsetY;
                }

                UpdateCardBackPreview(options);
                NotifySettingsChanged(options);
            }
        }
        finally
        {
            _isEditorOpen = false;
        }
    }

    private void HelpKlondike_Click(object? sender, RoutedEventArgs e) => new HelpWindow("Klondike").Show();
    private void HelpBeecell_Click(object? sender, RoutedEventArgs e)  => new HelpWindow("Beecell").Show();
    private void HelpSpider_Click(object? sender, RoutedEventArgs e)   => new HelpWindow("Spider").Show();
    private void About_Click(object? sender, RoutedEventArgs e)        => new AboutWindow().Show();

    private void NotifySettingsChanged(GameOptions options)
    {
        SettingsService.SaveOptions(options);
        WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(options));
    }

    private async void AddCustomCardBack_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not GameOptions options) return;

        var topLevel = TopLevel.GetTopLevel(this);
        if (topLevel == null) return;

        var gifType = new FilePickerFileType("Animated GIF") { Patterns = new[] { "*.gif" } };
        var files = await topLevel.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "Select Card Back Image",
            AllowMultiple = false,
            FileTypeFilter = new[] { FilePickerFileTypes.ImageAll, gifType }
        });

        if (files == null || files.Count == 0) return;

        var file = files[0];
        try
        {
            string displayName = Path.GetFileNameWithoutExtension(file.Name);
            
            if (options.CustomCardBacks.Exists(c => c.Name.Equals(displayName, StringComparison.OrdinalIgnoreCase)) ||
                displayName == "Vulpera" || displayName == "Dingwall" || displayName == "Moogle")
            {
                displayName += "_" + Guid.NewGuid().ToString().Substring(0, 4);
            }

            var destDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "SoliBee",
                "CardBacks"
            );
            if (!Directory.Exists(destDir))
            {
                Directory.CreateDirectory(destDir);
            }

            bool isGif = file.Name.EndsWith(".gif", StringComparison.OrdinalIgnoreCase);
            string uniqueFileName = Guid.NewGuid().ToString() + (isGif ? ".gif" : ".png");
            string destPath = Path.Combine(destDir, uniqueFileName);

            using (var sourceStream = await file.OpenReadAsync())
            {
                if (isGif)
                {
                    // Preserve raw GIF bytes so animation frames are not lost
                    using var destStream = File.Create(destPath);
                    await sourceStream.CopyToAsync(destStream);
                }
                else
                {
                    using (var bitmap = Bitmap.DecodeToWidth(sourceStream, 512))
                    {
                        bitmap.Save(destPath);
                    }
                }
            }

            var newBack = new CustomCardBack
            {
                Name = displayName,
                FileName = uniqueFileName,
                Scale = 1.0,
                OffsetX = 0.0,
                OffsetY = 0.0
            };
            options.CustomCardBacks.Add(newBack);
            options.CardBackTheme = displayName;

            _initializing = true;
            
            PopulateCardBacks(options);
            
            foreach (var item in CardBackComboBox.Items.OfType<ComboBoxItem>())
            {
                if (item.Tag?.ToString() == displayName)
                {
                    CardBackComboBox.SelectedItem = item;
                    break;
                }
            }

            options.CardBackScale = 1.0;
            options.CardBackOffsetX = 0.0;
            options.CardBackOffsetY = 0.0;
            DeleteCustomCardBackButton.IsEnabled = true;

            _initializing = false;

            UpdateCardBackPreview(options);
            NotifySettingsChanged(options);
            CardView.PreloadCardBacks(options);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Failed to add custom card back: {ex}");
        }
    }

    private void DeleteCustomCardBack_Click(object? sender, RoutedEventArgs e)
    {
        ConfirmDeleteOverlay.IsVisible = true;
    }

    private void CancelDelete_Click(object? sender, RoutedEventArgs e)
    {
        ConfirmDeleteOverlay.IsVisible = false;
    }

    private void ConfirmDelete_Click(object? sender, RoutedEventArgs e)
    {
        ConfirmDeleteOverlay.IsVisible = false;

        if (DataContext is not GameOptions options) return;

        var selectedItem = CardBackComboBox.SelectedItem as ComboBoxItem;
        if (selectedItem == null || selectedItem.Tag == null) return;

        var themeToDelete = selectedItem.Tag.ToString();
        var customBack = options.CustomCardBacks.Find(c => c.Name == themeToDelete);
        if (customBack == null) return;

        // Delete the image file if it exists
        var destDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "SoliBee",
            "CardBacks"
        );
        var filePath = Path.Combine(destDir, customBack.FileName);
        try
        {
            if (File.Exists(filePath))
            {
                File.Delete(filePath);
            }
        }
        catch {}

        // Remove from list
        options.CustomCardBacks.Remove(customBack);

        // Fallback to Vulpera theme
        options.CardBackTheme = "Vulpera";

        // Refresh UI
        _initializing = true;
        PopulateCardBacks(options);

        // Reselect Vulpera
        foreach (var item in CardBackComboBox.Items.OfType<ComboBoxItem>())
        {
            if (item.Tag?.ToString() == "Vulpera")
            {
                CardBackComboBox.SelectedItem = item;
                break;
            }
        }

        options.CardBackScale = 1.0;
        options.CardBackOffsetX = 0;
        options.CardBackOffsetY = 0;
        DeleteCustomCardBackButton.IsEnabled = false;
        _initializing = false;
        UpdateCardBackPreview(options);

        NotifySettingsChanged(options);
        CardView.PreloadCardBacks(options);
    }
}
