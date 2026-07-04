using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Layout;
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
    private bool _revertingGameMode;
    private int _confirmedGameModeIndex = -1;
    private Bitmap? _cardBackPreviewBitmap;
    private List<SoliBeeTheme> _themes = new();
    private SoliBeeTheme? _themeToDelete;

    public string ActiveGameFamily { get; set; } = "";
    public VideoPokerViewModel? VideoPokerVm { get; set; }
    public event EventHandler<string>? GameModeChangeRequested;

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

        CardBackComboBox.Items.Add(new ComboBoxItem { Content = "Vulpera",         Tag = "Vulpera" });
        CardBackComboBox.Items.Add(new ComboBoxItem { Content = "Dingwall",         Tag = "Dingwall" });
        CardBackComboBox.Items.Add(new ComboBoxItem { Content = "Moogle",           Tag = "Moogle" });
        CardBackComboBox.Items.Add(new ComboBoxItem { Content = "Forest",           Tag = "Forest" });
        CardBackComboBox.Items.Add(new ComboBoxItem { Content = "On the Water",     Tag = "On the Water" });
        CardBackComboBox.Items.Add(new ComboBoxItem { Content = "Pareidolic",       Tag = "Pareidolic" });
        CardBackComboBox.Items.Add(new ComboBoxItem { Content = "Pareidolic 2",     Tag = "Pareidolic 2" });
        CardBackComboBox.Items.Add(new ComboBoxItem { Content = "Red Sky",          Tag = "Red Sky" });
        CardBackComboBox.Items.Add(new ComboBoxItem { Content = "Sunset",           Tag = "Sunset" });

        foreach (var cb in options.CustomCardBacks)
        {
            CardBackComboBox.Items.Add(new ComboBoxItem { Content = cb.Name, Tag = cb.Name });
        }
    }

    // ── Themes panel navigation ───────────────────────────────────────────────

    // Video Poker's top-level DataContext is its own VideoPokerOptions, but Visual
    // Themes (felt, card back, face art, colors) is shared GameOptions state that
    // already propagates into VideoPokerOptions via OptionsChangedMessage — so while
    // the sub-panel is open we swap DataContext to a fresh GameOptions clone, then
    // swap back (and re-sync the main panel) on the way out.
    private VideoPokerOptions? _vpOptionsBeforeThemes;

    private void OpenThemes_Click(object? sender, RoutedEventArgs e)
    {
        MainPanel.IsVisible   = false;
        ThemesPanel.IsVisible = true;

        if (DataContext is VideoPokerOptions vpOptions)
        {
            _vpOptionsBeforeThemes = vpOptions;
            DataContext = SettingsService.LoadOptions();
        }

        if (DataContext is GameOptions opts)
        {
            _initializing = true;
            SyncUIFromOptions(opts);
            _initializing = false;
            RefreshThemeList();
        }
    }

    private void CloseThemes_Click(object? sender, RoutedEventArgs e)
    {
        ThemesPanel.IsVisible = false;
        MainPanel.IsVisible   = true;

        if (_vpOptionsBeforeThemes != null)
        {
            DataContext = _vpOptionsBeforeThemes;
            _vpOptionsBeforeThemes = null;
            _initializing = true;
            SyncUIFromVideoPokerOptions((VideoPokerOptions)DataContext);
            _initializing = false;
        }
    }

    // Syncs all UI controls to match the provided options. Call inside _initializing guard.
    private void SyncUIFromOptions(GameOptions options)
    {
        TimedCheckBox.IsChecked        = options.IsTimed;
        SoundCheckBox.IsChecked        = options.IsSoundEnabled;
        VegasCheckBox.IsChecked        = options.IsVegasScoring;
        FinalFantasyCheckBox.IsChecked = options.IsFinalFantasyMode;
        VignetteCheckBox.IsChecked     = options.IsVignetteEnabled;
        HideHintCheckBox.IsChecked     = options.HideHintButton;
        HideStatsCheckBox.IsChecked    = options.HideStatsButton;
        HideZoomCheckBox.IsChecked     = options.HideZoomControls;

        foreach (var item in FeltColorComboBox.Items.OfType<ComboBoxItem>())
        {
            if (item.Tag?.ToString() == options.FeltColor.ToString())
            {
                FeltColorComboBox.SelectedItem = item;
                break;
            }
        }

        CustomColorPanel.IsVisible = options.FeltColor == FeltColorTheme.Custom;
        if (options.FeltColor == FeltColorTheme.Custom && Color.TryParse(options.CustomFeltColorHex, out var parsedColor))
            FeltColorPicker.Color = parsedColor;

        PopulateCardBacks(options);

        foreach (var item in CardBackComboBox.Items.OfType<ComboBoxItem>())
        {
            if (item.Tag?.ToString() == options.CardBackTheme)
            {
                CardBackComboBox.SelectedItem = item;
                DeleteCustomCardBackButton.IsEnabled = !IsBuiltInCardBack(options.CardBackTheme);
                break;
            }
        }

        UpdateCardBackPreview(options);

        // Custom Card Color Pickers
        CardBgColorPicker.Color = Color.Parse(options.ThemeFaceBackNormal ?? "#FFFFFF");
        CardOutlineColorPicker.Color = Color.Parse(options.ThemeFaceBorderNormal ?? "#D9000000");
        CardTextBlackColorPicker.Color = Color.Parse(options.ThemeTextBlackNormal ?? "#1A1A1A");
        CardTextRedColorPicker.Color = Color.Parse(options.ThemeTextRed ?? "#CC1A1A");

        // Game Mode section
        if (!string.IsNullOrEmpty(ActiveGameFamily) && ActiveGameFamily != "Freecell" && ActiveGameFamily != "VideoPoker")
        {
            PopulateGameModeCombo(options, ActiveGameFamily);
            GameModeSection.IsVisible = true;
        }
        else
        {
            GameModeSection.IsVisible = false;
        }
    }

    private void PreferencesView_Loaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is GameOptions options)
        {
            SyncUIFromOptions(options);
            RefreshThemeList();
        }
        else if (DataContext is VideoPokerOptions vpOptions)
        {
            SyncUIFromVideoPokerOptions(vpOptions);
        }
        _initializing = false;
    }

    // Video Poker has its own separate options model — only a handful of settings
    // (sound, bet-board visibility) are VP-specific; Hide Hint/Stats are global
    // (shared GameOptions) and Visual Themes is available same as every other game.
    private void SyncUIFromVideoPokerOptions(VideoPokerOptions options)
    {
        TimedCheckBox.IsVisible        = false;
        VegasCheckBox.IsVisible        = false;
        FinalFantasyCheckBox.IsVisible = false;
        HideBetBoardCheckBox.IsVisible = true;

        SoundCheckBox.IsChecked        = options.IsSoundEnabled;
        HideBetBoardCheckBox.IsChecked = options.HideBetBoard;

        var shared = SettingsService.LoadOptions();
        HideHintCheckBox.IsChecked     = shared.HideHintButton;
        HideStatsCheckBox.IsChecked    = shared.HideStatsButton;
        HideZoomCheckBox.IsChecked     = shared.HideZoomControls;
    }

    // ── Game Mode ─────────────────────────────────────────────────────────────

    private void PopulateGameModeCombo(GameOptions options, string family)
    {
        GameModeCombo.Items.Clear();
        string currentTag;
        switch (family)
        {
            case "Klondike":
                GameModeCombo.Items.Add(new ComboBoxItem { Content = "Draw 1", Tag = "SolitaireDraw1" });
                GameModeCombo.Items.Add(new ComboBoxItem { Content = "Draw 3", Tag = "SolitaireDraw3" });
                currentTag = options.IsDrawConstraintsEnabled ? "SolitaireDraw3" : "SolitaireDraw1";
                break;
            case "Freecell":
                GameModeCombo.Items.Add(new ComboBoxItem { Content = "1 Deck", Tag = "Freecell1" });
                currentTag = "Freecell1";
                break;
            case "Spider":
                GameModeCombo.Items.Add(new ComboBoxItem { Content = "1 Suit",  Tag = "Spider1" });
                GameModeCombo.Items.Add(new ComboBoxItem { Content = "2 Suits", Tag = "Spider2" });
                GameModeCombo.Items.Add(new ComboBoxItem { Content = "4 Suits", Tag = "Spider4" });
                currentTag = options.SpiderSuitCount switch { 2 => "Spider2", 4 => "Spider4", _ => "Spider1" };
                break;
            default: return;
        }
        foreach (var item in GameModeCombo.Items.OfType<ComboBoxItem>())
        {
            if (item.Tag?.ToString() == currentTag) { GameModeCombo.SelectedItem = item; break; }
        }
        _confirmedGameModeIndex = GameModeCombo.SelectedIndex;
    }

    private void GameMode_Changed(object? sender, SelectionChangedEventArgs e)
    {
        if (_initializing || _revertingGameMode) return;
        if (GameModeCombo.SelectedItem is not ComboBoxItem item || item.Tag == null) return;
        GameModeChangeRequested?.Invoke(this, item.Tag.ToString() ?? "");
    }

    public void RevertGameModeCombo()
    {
        _revertingGameMode = true;
        GameModeCombo.SelectedIndex = _confirmedGameModeIndex;
        _revertingGameMode = false;
    }

    public void CommitGameModeCombo()
    {
        _confirmedGameModeIndex = GameModeCombo.SelectedIndex;
    }

    // ── Theme List ────────────────────────────────────────────────────────────

    private void RefreshThemeList()
    {
        _themes = ThemeService.LoadThemes();
        ThemeListPanel.Children.Clear();
        NoThemesLabel.IsVisible = _themes.Count == 0;

        foreach (var theme in _themes)
            ThemeListPanel.Children.Add(BuildThemeRow(theme));
    }

    private Grid BuildThemeRow(SoliBeeTheme theme)
    {
        var grid = new Grid { Margin = new Thickness(0, 2, 0, 2) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(18) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var swatchHex = FeltSwatchHex(theme);
        Color swatchColor;
        try { swatchColor = Color.Parse(swatchHex); } catch { swatchColor = Colors.Green; }

        var swatch = new Border
        {
            Width = 14, Height = 14,
            CornerRadius = new CornerRadius(2),
            Background = new SolidColorBrush(swatchColor),
            VerticalAlignment = VerticalAlignment.Center
        };
        Grid.SetColumn(swatch, 0);
        grid.Children.Add(swatch);

        var nameBlock = new TextBlock
        {
            Text = theme.Name,
            Foreground = Brushes.White,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(6, 0, 0, 0)
        };
        Grid.SetColumn(nameBlock, 1);
        grid.Children.Add(nameBlock);

        var applyBtn = new Button
        {
            Content = "Apply",
            Tag = theme,
            Background = new SolidColorBrush(Color.Parse("#1155AA")),
            Foreground = Brushes.White,
            Padding = new Thickness(8, 3),
            Margin = new Thickness(0, 0, 4, 0)
        };
        applyBtn.Click += ApplyTheme_Click;
        Grid.SetColumn(applyBtn, 2);
        grid.Children.Add(applyBtn);

        var deleteBtn = new Button
        {
            Content = "✕",
            Tag = theme,
            Background = new SolidColorBrush(Color.Parse("#662222")),
            Foreground = Brushes.White,
            Padding = new Thickness(6, 3)
        };
        deleteBtn.Click += DeleteTheme_Click;
        Grid.SetColumn(deleteBtn, 3);
        grid.Children.Add(deleteBtn);

        return grid;
    }

    private static string FeltSwatchHex(SoliBeeTheme theme) => theme.FeltColor switch
    {
        FeltColorTheme.FeltGreen => "#008000",
        FeltColorTheme.Crimson   => "#8C0C26",
        FeltColorTheme.RoyalBlue => "#1A3380",
        FeltColorTheme.Charcoal  => "#2E2E2E",
        FeltColorTheme.Desert    => "#C2967A",
        FeltColorTheme.Custom    => theme.CustomFeltColorHex,
        _                        => "#008000"
    };

    private void SaveTheme_Click(object? sender, RoutedEventArgs e)
    {
        ThemeNameInput.Text = "";
        SaveThemeOverlay.IsVisible = true;
    }

    private void CancelSaveTheme_Click(object? sender, RoutedEventArgs e)
    {
        SaveThemeOverlay.IsVisible = false;
    }

    private void ConfirmSaveTheme_Click(object? sender, RoutedEventArgs e)
    {
        SaveThemeOverlay.IsVisible = false;
        var name = ThemeNameInput.Text?.Trim();
        if (string.IsNullOrEmpty(name)) return;
        if (DataContext is not GameOptions options) return;
        var theme = ThemeService.SnapshotFromOptions(name, options);
        ThemeService.AddTheme(theme);
        RefreshThemeList();
    }

    private void ApplyTheme_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is not Button btn || btn.Tag is not SoliBeeTheme theme) return;
        if (DataContext is not GameOptions options) return;

        ThemeService.ApplyTheme(theme, options);

        _initializing = true;
        SyncUIFromOptions(options);
        _initializing = false;

        NotifySettingsChanged(options);
        CardView.ApplyThemeColors(options);
        CardView.InvalidateFaceArtCache();
        CardView.PreloadFaceArt();
        CardView.PreloadCardBacks(options);
        WeakReferenceMessenger.Default.Send(new FaceCardArtChangedMessage());
    }

    private void DeleteTheme_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is not Button btn || btn.Tag is not SoliBeeTheme theme) return;
        _themeToDelete = theme;
        DeleteThemeConfirmText.Text = $"Delete \"{theme.Name}\"? This cannot be undone.";
        ConfirmDeleteThemeOverlay.IsVisible = true;
    }

    private void CancelDeleteTheme_Click(object? sender, RoutedEventArgs e)
    {
        _themeToDelete = null;
        ConfirmDeleteThemeOverlay.IsVisible = false;
    }

    private void ConfirmDeleteTheme_Click(object? sender, RoutedEventArgs e)
    {
        ConfirmDeleteThemeOverlay.IsVisible = false;
        if (_themeToDelete == null) return;
        ThemeService.DeleteTheme(_themeToDelete.Id);
        _themeToDelete = null;
        RefreshThemeList();
    }

    // ── Felt Color ────────────────────────────────────────────────────────────

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

    // ── Card Back ─────────────────────────────────────────────────────────────

    private void CardBackComboBox_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (_initializing) return;

        if (DataContext is GameOptions options && CardBackComboBox.SelectedItem is ComboBoxItem item && item.Tag != null)
        {
            var selectedTag = item.Tag.ToString()!;
            options.CardBackTheme = selectedTag;

            bool isCustom = !IsBuiltInCardBack(selectedTag);
            DeleteCustomCardBackButton.IsEnabled = isCustom;

            var customBack = options.CustomCardBacks.Find(c => c.Name == selectedTag);
            if (customBack != null)
            {
                options.CardBackScale = customBack.Scale;
                options.CardBackOffsetX = customBack.OffsetX;
                options.CardBackOffsetY = customBack.OffsetY;
            }
            else
            {
                (options.CardBackScale, options.CardBackOffsetX, options.CardBackOffsetY) = BuiltInCardBackDefaults(selectedTag);
            }

            UpdateCardBackPreview(options);
            NotifySettingsChanged(options);
        }
    }

    // ── Checkboxes ────────────────────────────────────────────────────────────

    private void Option_Changed(object? sender, RoutedEventArgs e)
    {
        if (_initializing) return;

        if (DataContext is GameOptions options)
        {
            options.IsTimed            = TimedCheckBox.IsChecked        ?? false;
            options.IsSoundEnabled     = SoundCheckBox.IsChecked        ?? false;
            options.IsVegasScoring     = VegasCheckBox.IsChecked        ?? false;
            options.IsVignetteEnabled  = VignetteCheckBox.IsChecked     ?? true;
            options.HideHintButton     = HideHintCheckBox.IsChecked     ?? false;
            options.HideStatsButton    = HideStatsCheckBox.IsChecked    ?? false;
            options.HideZoomControls   = HideZoomCheckBox.IsChecked     ?? false;

            bool wasFF = options.IsFinalFantasyMode;
            options.IsFinalFantasyMode = FinalFantasyCheckBox.IsChecked ?? false;

            if (!wasFF && options.IsFinalFantasyMode)
                ApplyCardBackSelection("Vulpera", options);

            NotifySettingsChanged(options);
        }
        else if (DataContext is VideoPokerOptions vpOptions)
        {
            vpOptions.IsSoundEnabled  = SoundCheckBox.IsChecked        ?? false;
            vpOptions.HideBetBoard    = HideBetBoardCheckBox.IsChecked ?? false;

            // Hide Hint/Stats/Zoom are global — write to the shared GameOptions so every
            // game (Klondike/Freecell/Spider/Blackjack too) picks up the change too.
            var shared = SettingsService.LoadOptions();
            shared.HideHintButton    = HideHintCheckBox.IsChecked  ?? false;
            shared.HideStatsButton   = HideStatsCheckBox.IsChecked ?? false;
            shared.HideZoomControls  = HideZoomCheckBox.IsChecked  ?? false;
            NotifySettingsChanged(shared);

            // vpOptions is the live VideoPokerViewModel.Options instance, so mutations
            // above already apply — SaveOptions() persists to disk and notifies the view.
            VideoPokerVm?.SaveOptions();
        }
    }

    // ── Card Back helpers ─────────────────────────────────────────────────────

    private void ApplyCardBackSelection(string name, GameOptions options)
    {
        var customBack = options.CustomCardBacks.Find(c => c.Name == name);
        if (customBack != null)
        {
            options.CardBackScale = customBack.Scale;
            options.CardBackOffsetX = customBack.OffsetX;
            options.CardBackOffsetY = customBack.OffsetY;
        }
        else if (IsBuiltInCardBack(name))
        {
            (options.CardBackScale, options.CardBackOffsetX, options.CardBackOffsetY) = BuiltInCardBackDefaults(name);
        }
        else return;

        options.CardBackTheme = name;

        _initializing = true;
        foreach (var item in CardBackComboBox.Items.OfType<ComboBoxItem>())
        {
            if (item.Tag?.ToString() == name)
            {
                CardBackComboBox.SelectedItem = item;
                DeleteCustomCardBackButton.IsEnabled = !IsBuiltInCardBack(name);
                break;
            }
        }
        _initializing = false;

        UpdateCardBackPreview(options);
    }

    private static bool IsBuiltInCardBack(string name) =>
        name is "Vulpera" or "Dingwall" or "Moogle"
             or "Forest" or "On the Water" or "Pareidolic" or "Pareidolic 2"
             or "Red Sky" or "Sunset";

    private static (double Scale, double OffsetX, double OffsetY) BuiltInCardBackDefaults(string name) => name switch
    {
        "Moogle"           => (1.25,               0, 0),
        _                  => (1.0,                 0, 0),
    };

    private static readonly IReadOnlyDictionary<string, string> _houliAssets =
        new Dictionary<string, string>
        {
            ["Forest"]       = "forest.png",
            ["On the Water"] = "onthewater.png",
            ["Pareidolic"]   = "pareidolic.png",
            ["Pareidolic 2"] = "pareidolic2.png",
            ["Red Sky"]      = "redsky.png",
            ["Sunset"]       = "sunset.png",
        };

    private void UpdateCardBackPreview(GameOptions options)
    {
        bool isDingwall = options.CardBackTheme == "Dingwall" || _houliAssets.ContainsKey(options.CardBackTheme);
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
            if (_houliAssets.TryGetValue(theme, out var assetFile))
                return new Bitmap(AssetLoader.Open(new Uri($"avares://SoliBee.Desktop/Assets/{assetFile}")));

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

    // ── Add / Delete Custom Card Back ─────────────────────────────────────────

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

        var destDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "SoliBee", "CardBacks");
        var filePath = Path.Combine(destDir, customBack.FileName);
        try { if (File.Exists(filePath)) File.Delete(filePath); } catch { }

        options.CustomCardBacks.Remove(customBack);
        options.CardBackTheme = "Vulpera";

        _initializing = true;
        PopulateCardBacks(options);

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
                "SoliBee", "CardBacks");
            if (!Directory.Exists(destDir))
                Directory.CreateDirectory(destDir);

            bool isGif = file.Name.EndsWith(".gif", StringComparison.OrdinalIgnoreCase);
            string uniqueFileName = Guid.NewGuid().ToString() + (isGif ? ".gif" : ".png");
            string destPath = Path.Combine(destDir, uniqueFileName);

            using (var sourceStream = await file.OpenReadAsync())
            {
                if (isGif)
                {
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

    // ── About / Help ──────────────────────────────────────────────────

    private void Help_Click(object? sender, RoutedEventArgs e)
    {
        var owner = (Window?)TopLevel.GetTopLevel(this);
        var help = new HelpWindow();
        if (owner != null)
            help.Show(owner);
        else
            help.Show();
    }

    private void About_Click(object? sender, RoutedEventArgs e)        => new AboutWindow().Show();

    // ── Custom Card Colors ────────────────────────────────────────────────────

    private void CardColorPicker_ColorChanged(object? sender, ColorChangedEventArgs e)
    {
        if (_initializing || DataContext is not GameOptions options) return;

        if (sender == CardBgColorPicker)
            options.ThemeFaceBackNormal = e.NewColor.ToString();
        else if (sender == CardOutlineColorPicker)
            options.ThemeFaceBorderNormal = e.NewColor.ToString();
        else if (sender == CardTextBlackColorPicker)
            options.ThemeTextBlackNormal = e.NewColor.ToString();
        else if (sender == CardTextRedColorPicker)
            options.ThemeTextRed = e.NewColor.ToString();

        CardView.ApplyThemeColors(options);
        NotifySettingsChanged(options);
        CardView.BroadcastThemeChange();
    }

    private void ResetCardColors_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not GameOptions options) return;

        options.ThemeFaceBackNormal = null;
        options.ThemeFaceBorderNormal = null;
        options.ThemeTextBlackNormal = null;
        options.ThemeTextRed = null;
        options.ThemeCardShadow = null;

        _initializing = true;
        CardBgColorPicker.Color = Colors.White;
        CardOutlineColorPicker.Color = Color.Parse("#D9000000");
        CardTextBlackColorPicker.Color = Color.Parse("#1A1A1A");
        CardTextRedColorPicker.Color = Color.Parse("#CC1A1A");
        _initializing = false;

        CardView.ApplyThemeColors(options);
        NotifySettingsChanged(options);
        CardView.BroadcastThemeChange();
    }



    // ── Settings broadcast ────────────────────────────────────────────────────

    private void NotifySettingsChanged(GameOptions options)
    {
        SettingsService.SaveOptions(options);
        WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(options));
    }
}
