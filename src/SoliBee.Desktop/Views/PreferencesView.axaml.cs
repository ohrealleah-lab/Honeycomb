using System;
using System.IO;
using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform.Storage;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public partial class PreferencesView : UserControl
{
    private bool _initializing = true;

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
            foreach (ComboBoxItem item in FeltColorComboBox.Items)
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
            foreach (ComboBoxItem item in CardBackComboBox.Items)
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

            OffsetXSlider.Value = options.CardBackOffsetX;
            OffsetYSlider.Value = options.CardBackOffsetY;
            ScaleSlider.Value = options.CardBackScale;

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
            var selectedTag = item.Tag.ToString();
            options.CardBackTheme = selectedTag;

            bool isCustom = selectedTag != "Vulpera" && selectedTag != "Dingwall" && selectedTag != "Moogle";
            DeleteCustomCardBackButton.IsEnabled = isCustom;

            var customBack = options.CustomCardBacks.Find(c => c.Name == selectedTag);
            if (customBack != null)
            {
                _initializing = true;
                options.CardBackScale = customBack.Scale;
                options.CardBackOffsetX = customBack.OffsetX;
                options.CardBackOffsetY = customBack.OffsetY;

                ScaleSlider.Value = customBack.Scale;
                OffsetXSlider.Value = customBack.OffsetX;
                OffsetYSlider.Value = customBack.OffsetY;
                _initializing = false;
            }
            else
            {
                if (selectedTag == "Moogle")
                {
                    _initializing = true;
                    options.CardBackScale = 1.25;
                    options.CardBackOffsetX = 0;
                    options.CardBackOffsetY = 0;
                    ScaleSlider.Value = 1.25;
                    OffsetXSlider.Value = 0;
                    OffsetYSlider.Value = 0;
                    _initializing = false;
                }
                else
                {
                    _initializing = true;
                    options.CardBackScale = 1.0;
                    options.CardBackOffsetX = 0;
                    options.CardBackOffsetY = 0;
                    ScaleSlider.Value = 1.0;
                    OffsetXSlider.Value = 0;
                    OffsetYSlider.Value = 0;
                    _initializing = false;
                }
            }

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
            NotifySettingsChanged(options);
        }
    }

    private void Slider_ValueChanged(object? sender, RangeBaseValueChangedEventArgs e)
    {
        if (_initializing) return;

        if (DataContext is GameOptions options)
        {
            options.CardBackOffsetX = OffsetXSlider.Value;
            options.CardBackOffsetY = OffsetYSlider.Value;
            options.CardBackScale = ScaleSlider.Value;

            var customBack = options.CustomCardBacks.Find(c => c.Name == options.CardBackTheme);
            if (customBack != null)
            {
                customBack.Scale = options.CardBackScale;
                customBack.OffsetX = options.CardBackOffsetX;
                customBack.OffsetY = options.CardBackOffsetY;
            }

            NotifySettingsChanged(options);
        }
    }

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

        var files = await topLevel.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "Select Card Back Image",
            AllowMultiple = false,
            FileTypeFilter = new[] { FilePickerFileTypes.ImageAll }
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

            string uniqueFileName = Guid.NewGuid().ToString() + ".png";
            string destPath = Path.Combine(destDir, uniqueFileName);

            using (var sourceStream = await file.OpenReadAsync())
            {
                using (var bitmap = Bitmap.DecodeToWidth(sourceStream, 512))
                {
                    bitmap.Save(destPath);
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
            
            foreach (ComboBoxItem item in CardBackComboBox.Items)
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
            ScaleSlider.Value = 1.0;
            OffsetXSlider.Value = 0.0;
            OffsetYSlider.Value = 0.0;
            DeleteCustomCardBackButton.IsEnabled = true;

            _initializing = false;

            NotifySettingsChanged(options);
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
        foreach (ComboBoxItem item in CardBackComboBox.Items)
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
        ScaleSlider.Value = 1.0;
        OffsetXSlider.Value = 0;
        OffsetYSlider.Value = 0;
        DeleteCustomCardBackButton.IsEnabled = false;
        _initializing = false;

        NotifySettingsChanged(options);
    }
}
