using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
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
using SkiaSharp;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public partial class PreferencesView : UserControl
{
    private bool _initializing = true;
    private int _confirmedGameModeIndex = -1;
    private Bitmap? _cardBackPreviewBitmap;
    private List<SoliBeeTheme> _themes = new();
    private SoliBeeTheme? _themeToDelete;
    private SoliBeeTheme? _themeToRename;
    private bool _isBackgroundEditorOpen;
    private string? _backgroundToDelete;

    // Snapshots taken when the panel opens, so Cancel can restore whatever was actually
    // on disk beforehand — every individual control here saves+broadcasts immediately
    // on change (see NotifySettingsChanged/Option_Changed), there's no separate "staged"
    // state, so reverting means writing this snapshot back over whatever was live-saved
    // during the session. Doesn't cover the Theme library (Save/Delete Theme) or the
    // Custom Card Back / Face Card Art libraries — those already have their own
    // dedicated confirm dialogs and are treated as already-committed actions.
    private GameOptions? _originalGameOptions;
    private VideoPokerOptions? _originalVideoPokerOptions;
    private GameOptions? _originalSharedOptionsForVideoPoker;
    private BlackjackOptions? _originalBlackjackOptions;
    private GameOptions? _originalSharedOptionsForBlackjack;

    public static readonly StyledProperty<string> ActiveGameFamilyProperty =
        AvaloniaProperty.Register<PreferencesView, string>(nameof(ActiveGameFamily), "Klondike");

    public static readonly StyledProperty<HoneycombOptions?> HoneycombOptionsProperty =
        AvaloniaProperty.Register<PreferencesView, HoneycombOptions?>(nameof(HoneycombOptions), null);

    public string ActiveGameFamily
    {
        get => GetValue(ActiveGameFamilyProperty);
        set => SetValue(ActiveGameFamilyProperty, value);
    }
    
    public HoneycombOptions? HoneycombOptions
    {
        get => GetValue(HoneycombOptionsProperty);
        set => SetValue(HoneycombOptionsProperty, value);
    }

    public VideoPokerViewModel? VideoPokerVm { get; set; }
    public BlackjackViewModel? BlackjackVm { get; set; }

    public bool ShowVegasOption
    {
        get => VegasCheckBox.IsVisible;
        set => VegasCheckBox.IsVisible = value;
    }

    public PreferencesView()
    {
        InitializeComponent();
        this.Loaded += PreferencesView_Loaded;

        // Face card art edits (FaceCardArtSectionView, inside FaceCardsPanel) go through
        // FaceCardArtService directly and never call NotifySettingsChanged, so they were
        // the one live-apply surface that didn't live-save into the active theme — upload
        // or adjust art, then Apply a different theme or close the app, and the edit was
        // silently lost. This mirrors NotifySettingsChanged's own live-save block below,
        // just triggered by the message FaceCardArtSectionView already sends after every
        // upload/adjust/remove instead of by an options field changing.
        WeakReferenceMessenger.Default.Register<FaceCardArtChangedMessage>(this, (r, m) =>
        {
            if (DataContext is GameOptions options && options.ActiveThemeId.HasValue)
                ThemeService.UpdateTheme(options.ActiveThemeId.Value, options);
        });
    }

    private void PopulateCardBacks(GameOptions options)
    {
        CardBackComboBox.Items.Clear();

        foreach (var name in _builtInCardBackNames)
        {
            if (options.HiddenDefaultCardBacks.Contains(name)) continue;
            CardBackComboBox.Items.Add(new ComboBoxItem { Content = name, Tag = name });
        }

        // If the current card back is "Dingwall" (which was removed from built-in),
        // we add it dynamically so existing users keep it visible and selected.
        if (options.CardBackTheme == "Dingwall")
        {
            CardBackComboBox.Items.Add(new ComboBoxItem { Content = "Dingwall", Tag = "Dingwall" });
        }

        foreach (var cb in options.CustomCardBacks)
        {
            CardBackComboBox.Items.Add(new ComboBoxItem { Content = cb.Name, Tag = cb.Name });
        }
    }

    // Felt colors and the image background live in one merged dropdown — both control
    // what's behind the cards, and this avoids the two separate combos needing manual
    // mutual-exclusion resets (picking one used to have to reach into the other and
    // clear its selection). Tags are prefixed ("felt:"/"bg:") so a user-named background
    // (e.g. one literally named "Custom" or "FeltGreen") can never collide with a felt
    // preset's tag.
    private static readonly (string Label, string FeltTag)[] _feltPresets =
    {
        ("Green Felt", "FeltGreen"),
        ("Crimson", "Crimson"),
        ("Royal Blue", "RoyalBlue"),
        ("Charcoal", "Charcoal"),
        ("Desert", "Desert"),
        ("Custom Color", "Custom"),
    };

    private void PopulateBackgrounds(GameOptions options)
    {
        BackgroundComboBox.Items.Clear();

        foreach (var (label, feltTag) in _feltPresets)
        {
            BackgroundComboBox.Items.Add(new ComboBoxItem { Content = label, Tag = "felt:" + feltTag });
        }

        BackgroundComboBox.Items.Add(new ComboBoxItem { Content = "──────────", IsEnabled = false });

        BackgroundComboBox.Items.Add(new ComboBoxItem { Content = "None (Felt Color)", Tag = "bg:" });
        foreach (var bg in options.CustomBackgrounds)
        {
            BackgroundComboBox.Items.Add(new ComboBoxItem { Content = bg.Name, Tag = "bg:" + bg.Name });
        }
    }

    // ── Themes panel navigation ───────────────────────────────────────────────

    // Video Poker/Blackjack's top-level DataContext is their own separate Options
    // model, but Visual Themes (felt, card back, face art, colors) is shared
    // GameOptions state that already propagates into both via OptionsChangedMessage —
    // so while the sub-panel is open we swap DataContext to a fresh GameOptions clone,
    // then swap back (and re-sync the main panel) on the way out.
    private VideoPokerOptions? _vpOptionsBeforeThemes;
    private BlackjackOptions? _bjOptionsBeforeThemes;

    private void OpenThemes_Click(object? sender, RoutedEventArgs e)
    {
        MainPanel.IsVisible   = false;
        ThemesPanel.IsVisible = true;

        if (DataContext is VideoPokerOptions vpOptions)
        {
            _vpOptionsBeforeThemes = vpOptions;
            DataContext = SettingsService.LoadOptions();
        }
        else if (DataContext is BlackjackOptions bjOptions)
        {
            _bjOptionsBeforeThemes = bjOptions;
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

    private void OpenFaceCards_Click(object? sender, RoutedEventArgs e)
    {
        ThemesPanel.IsVisible    = false;
        FaceCardsPanel.IsVisible = true;
    }

    private void CloseFaceCards_Click(object? sender, RoutedEventArgs e)
    {
        FaceCardsPanel.IsVisible = false;
        ThemesPanel.IsVisible    = true;
    }

    private bool _cardColorPreviewBuilt;
    private SolidColorBrush? _cardColorPreviewRingBrush;

    private void OpenCardColorsPanel_Click(object? sender, RoutedEventArgs e)
    {
        if (!_cardColorPreviewBuilt)
        {
            BuildCardColorPreview();
            _cardColorPreviewBuilt = true;
        }
        RefreshCardColorPreviewBackdrop();
        CardView.InvalidateAllCardViews(CardColorPreviewStack);

        ThemesPanel.IsVisible     = false;
        CardColorsPanel.IsVisible = true;
    }

    private void CloseCardColorsPanel_Click(object? sender, RoutedEventArgs e)
    {
        CardColorsPanel.IsVisible = false;
        ThemesPanel.IsVisible     = true;
    }

    // Builds the 3 mock cards once and reuses them for the panel's lifetime — CardView
    // repaints itself from the same static theme brushes the color pickers mutate
    // (CardView.ApplyThemeColors), so it never needs to be rebuilt, only invalidated.
    private void BuildCardColorPreview()
    {
        var blackAce = new CardView { Card = new Card("mock-clubs", CardSuit.Clubs, 1, true) };
        var redAce = new CardView { Card = new Card("mock-hearts", CardSuit.Hearts, 1, true) };
        var back = new CardView { Card = new Card("mock-back", CardSuit.Spades, 1, false) };

        _cardColorPreviewRingBrush = new SolidColorBrush(CardView._hintHighlightColor);
        var backWithRing = new Border
        {
            Child = back,
            BorderBrush = _cardColorPreviewRingBrush,
            BorderThickness = new Thickness(4),
            CornerRadius = new CornerRadius(10)
        };

        CardColorPreviewStack.Children.Clear();
        CardColorPreviewStack.Children.Add(blackAce);
        CardColorPreviewStack.Children.Add(redAce);
        CardColorPreviewStack.Children.Add(backWithRing);
    }

    // Recomputes the preview backdrop — the theme's felt color, or a sampled dominant
    // color from the background image when one is set — and refreshes the hint ring
    // (Hint Highlight has no dedicated ColorChanged branch of its own to hook, so this
    // just re-reads the current static color every call, matching how the rest of the
    // live preview already just re-reads current state rather than diffing it).
    private void RefreshCardColorPreviewBackdrop()
    {
        if (DataContext is not GameOptions options || CardColorPreviewBackdrop == null) return;

        Color backdropColor;
        if (string.IsNullOrEmpty(options.BackgroundName))
        {
            backdropColor = Color.TryParse(FeltHexForOptions(options), out var felt) ? felt : Colors.DarkGreen;
        }
        else
        {
            var bg = options.CustomBackgrounds.Find(b => b.Name == options.BackgroundName);
            var path = bg != null && PathSafety.IsSafeFileName(bg.FileName)
                ? Path.Combine(BackgroundsDir, bg.FileName)
                : null;
            backdropColor = path != null && File.Exists(path) ? SampleDominantColor(path) : Colors.Gray;
        }

        CardColorPreviewBackdrop.Background = new SolidColorBrush(backdropColor);

        if (_cardColorPreviewRingBrush != null)
            _cardColorPreviewRingBrush.Color = CardView._hintHighlightColor;
    }

    private static string FeltHexForOptions(GameOptions options) => options.FeltColor switch
    {
        FeltColorTheme.FeltGreen => "#008000",
        FeltColorTheme.Crimson   => "#8C0C26",
        FeltColorTheme.RoyalBlue => "#1A3380",
        FeltColorTheme.Charcoal  => "#2E2E2E",
        FeltColorTheme.Desert    => "#C2967A",
        FeltColorTheme.Custom    => options.CustomFeltColorHex,
        _                        => "#008000"
    };

    // Downsamples the background image to a small thumbnail and averages its pixels —
    // cheap enough to run on every backdrop refresh (user-paced edits, not a hot path).
    private static Color SampleDominantColor(string filePath)
    {
        try
        {
            using var bitmap = SKBitmap.Decode(filePath);
            if (bitmap == null) return Colors.Gray;
            using var small = bitmap.Resize(new SKImageInfo(16, 16), SKFilterQuality.Low);
            if (small == null) return Colors.Gray;

            long r = 0, g = 0, b = 0;
            int count = small.Width * small.Height;
            for (int y = 0; y < small.Height; y++)
            {
                for (int x = 0; x < small.Width; x++)
                {
                    var px = small.GetPixel(x, y);
                    r += px.Red; g += px.Green; b += px.Blue;
                }
            }
            if (count == 0) return Colors.Gray;
            return Color.FromRgb((byte)(r / count), (byte)(g / count), (byte)(b / count));
        }
        catch { return Colors.Gray; }
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
        else if (_bjOptionsBeforeThemes != null)
        {
            DataContext = _bjOptionsBeforeThemes;
            _bjOptionsBeforeThemes = null;
            _initializing = true;
            SyncUIFromBlackjackOptions((BlackjackOptions)DataContext);
            _initializing = false;
        }
    }


    // Hide Hint Button: a single shared GameOptions field for every solitaire/casino
    // game, but Honeycomb keeps its own HoneycombOptions.HideHintButton (matching
    // Mac, where Honeycomb's hideHintButton is independent of the other games'
    // shared field) — same one-checkbox-many-backing-fields split as Point
    // Highlights above.
    private bool GetHideHintButton(GameOptions options) => ActiveGameFamily == "Honeycomb"
        ? (HoneycombOptions?.HideHintButton ?? false)
        : options.HideHintButton;

    private void SetHideHintButton(GameOptions options, bool value)
    {
        if (ActiveGameFamily == "Honeycomb")
        {
            if (HoneycombOptions != null) HoneycombOptions.HideHintButton = value;
        }
        else
        {
            options.HideHintButton = value;
        }
    }

    // Syncs all UI controls to match the provided options. Call inside _initializing guard.
    private void SyncUIFromOptions(GameOptions options)
    {
        NoStressModeCheckBox.IsChecked = options.IsNoStressMode;
        SoundCheckBox.IsChecked        = options.IsSoundEnabled;
        VegasCheckBox.IsChecked        = options.IsVegasScoring;
        VignetteCheckBox.IsChecked     = options.IsVignetteEnabled;
        HideHintCheckBox.IsChecked     = GetHideHintButton(options);
        ManuallyDismissBannersCheckBox.IsChecked = options.ManuallyDismissBanners;
        AlwaysOnTopCheckBox.IsChecked  = options.IsAlwaysOnTop;

        PopulateCardBacks(options);

        foreach (var item in CardBackComboBox.Items.OfType<ComboBoxItem>())
        {
            if (item.Tag?.ToString() == options.CardBackTheme)
            {
                CardBackComboBox.SelectedItem = item;
                DeleteCustomCardBackButton.IsEnabled = true;
                break;
            }
        }

        UpdateCardBackPreview(options);

        PopulateBackgrounds(options);
        // A background image, if set, takes priority for selection purposes over the
        // felt color — matches the in-game rendering priority (an image covers the felt).
        string selectedTag = !string.IsNullOrEmpty(options.BackgroundName)
            ? "bg:" + options.BackgroundName
            : "felt:" + options.FeltColor;
        foreach (var item in BackgroundComboBox.Items.OfType<ComboBoxItem>())
        {
            if ((item.Tag?.ToString() ?? "") == selectedTag)
            {
                BackgroundComboBox.SelectedItem = item;
                break;
            }
        }
        DeleteCustomBackgroundButton.IsEnabled = !string.IsNullOrEmpty(options.BackgroundName);
        CustomColorPanel.IsVisible = string.IsNullOrEmpty(options.BackgroundName) && options.FeltColor == FeltColorTheme.Custom;
        if (CustomColorPanel.IsVisible && Color.TryParse(options.CustomFeltColorHex, out var parsedColor))
            FeltColorPicker.Color = parsedColor;
        UpdateBackgroundPreview(options);

        // Custom Card Color Pickers
        CardBgColorPicker.Color = Color.Parse(options.ThemeFaceBackNormal ?? "#FFFFFF");
        CardOutlineColorPicker.Color = Color.Parse(options.ThemeFaceBorderNormal ?? "#D9000000");
        CardTextBlackColorPicker.Color = Color.Parse(options.ThemeTextBlackNormal ?? "#1A1A1A");
        CardTextRedColorPicker.Color = Color.Parse(options.ThemeTextRed ?? "#CC1A1A");
        HintHighlightColorPicker.Color = Color.Parse(options.ThemeHintHighlight ?? "#FFD700");

        // Honey Mode (Flavor) — global, shared across all 6 games.
        PointHighlightsCheckBox.IsVisible = true;
        PointHighlightsCheckBox.IsChecked = options.HoneyMode;

        // Game Mode section
        if (ActiveGameFamily is "Klondike" or "Freecell" or "Spider")
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
            _originalGameOptions = options.Clone();
            

            SyncUIFromOptions(options);
            RefreshThemeList();
        }
        else if (DataContext is VideoPokerOptions vpOptions)
        {
            _originalVideoPokerOptions          = vpOptions.Clone();
            _originalSharedOptionsForVideoPoker  = SettingsService.LoadOptions().Clone();
            SyncUIFromVideoPokerOptions(vpOptions);
        }
        else if (DataContext is BlackjackOptions bjOptions)
        {
            _originalBlackjackOptions          = bjOptions.Clone();
            _originalSharedOptionsForBlackjack  = SettingsService.LoadOptions().Clone();
            SyncUIFromBlackjackOptions(bjOptions);
        }
        _initializing = false;
    }

    // Restores whatever was on disk when the panel opened, undoing any settings changed
    // during this session (see the snapshot fields' comment for exactly what this
    // does/doesn't cover). Called by MainWindow's Cancel button.
    public void RevertSettingsChanges()
    {
        if (_originalGameOptions != null)
        {
            NotifySettingsChanged(_originalGameOptions);
        }
        else if (_originalVideoPokerOptions != null && DataContext is VideoPokerOptions vpOptions)
        {
            var orig = _originalVideoPokerOptions;
            vpOptions.Variant            = orig.Variant;
            vpOptions.StartingCredits    = orig.StartingCredits;
            vpOptions.BetPerHand         = orig.BetPerHand;
            vpOptions.IsSoundEnabled     = orig.IsSoundEnabled;
            vpOptions.CardBackTheme      = orig.CardBackTheme;
            vpOptions.FeltColor          = orig.FeltColor;
            vpOptions.CustomFeltColorHex = orig.CustomFeltColorHex;
            vpOptions.IsVignetteEnabled  = orig.IsVignetteEnabled;
            vpOptions.IsNoStressMode     = orig.IsNoStressMode;
            vpOptions.HideBetBoard       = orig.HideBetBoard;
            VideoPokerVm?.SaveOptions();

            if (_originalSharedOptionsForVideoPoker != null)
                NotifySettingsChanged(_originalSharedOptionsForVideoPoker);
        }
        else if (_originalBlackjackOptions != null && DataContext is BlackjackOptions bjOptions)
        {
            var orig = _originalBlackjackOptions;
            bjOptions.StartingCredits    = orig.StartingCredits;
            bjOptions.BetPerHand         = orig.BetPerHand;
            bjOptions.IsSoundEnabled     = orig.IsSoundEnabled;
            bjOptions.CardBackTheme      = orig.CardBackTheme;
            bjOptions.FeltColor          = orig.FeltColor;
            bjOptions.CustomFeltColorHex = orig.CustomFeltColorHex;
            bjOptions.IsVignetteEnabled  = orig.IsVignetteEnabled;
            bjOptions.IsNoStressMode     = orig.IsNoStressMode;
            BlackjackVm?.SaveOptions();

            if (_originalSharedOptionsForBlackjack != null)
                NotifySettingsChanged(_originalSharedOptionsForBlackjack);
        }
    }

    // True if anything has changed since the panel opened — a live-saved settings
    // edit, an applied Theme, or an unconfirmed game-mode dropdown selection. Used
    // by MainWindow's Cancel button / Escape key to decide whether to warn before
    // discarding (see CancelPreferences_Click in MainWindow.axaml.cs).
    public bool HasPendingChanges()
    {
        if (TryGetPendingGameModeChange(out _)) return true;

        if (_originalGameOptions != null && DataContext is GameOptions options)
        {
            return JsonSerializer.Serialize(options) != JsonSerializer.Serialize(_originalGameOptions);
        }

        if (_originalVideoPokerOptions != null && DataContext is VideoPokerOptions vpOptions)
        {
            if (JsonSerializer.Serialize(vpOptions) != JsonSerializer.Serialize(_originalVideoPokerOptions))
                return true;

            if (_originalSharedOptionsForVideoPoker != null)
            {
                var currentShared = SettingsService.LoadOptions();
                return JsonSerializer.Serialize(currentShared) != JsonSerializer.Serialize(_originalSharedOptionsForVideoPoker);
            }
        }

        if (_originalBlackjackOptions != null && DataContext is BlackjackOptions bjOptions)
        {
            if (JsonSerializer.Serialize(bjOptions) != JsonSerializer.Serialize(_originalBlackjackOptions))
                return true;

            if (_originalSharedOptionsForBlackjack != null)
            {
                var currentShared = SettingsService.LoadOptions();
                return JsonSerializer.Serialize(currentShared) != JsonSerializer.Serialize(_originalSharedOptionsForBlackjack);
            }
        }

        return false;
    }

    // True if No Stress Mode was off when the panel opened and is on now — used by
    // MainWindow's OK button to decide whether to silently end/restart Blackjack,
    // VideoPoker, or a Honeycomb match, since those are the only games where the
    // setting doesn't already apply live to a game in progress.
    public bool DidEnableNoStressMode()
    {
        if (_originalGameOptions != null && DataContext is GameOptions options)
            return !_originalGameOptions.IsNoStressMode && options.IsNoStressMode;

        if (_originalSharedOptionsForVideoPoker != null)
        {
            var currentShared = SettingsService.LoadOptions();
            return !_originalSharedOptionsForVideoPoker.IsNoStressMode && currentShared.IsNoStressMode;
        }

        if (_originalSharedOptionsForBlackjack != null)
        {
            var currentShared = SettingsService.LoadOptions();
            return !_originalSharedOptionsForBlackjack.IsNoStressMode && currentShared.IsNoStressMode;
        }

        return false;
    }

    // Video Poker has its own separate options model — only a handful of settings
    // (sound) are VP-specific; No Stress Mode/Hide Hint are global (shared
    // GameOptions) and Visual Themes is available same as every other game.
    private void SyncUIFromVideoPokerOptions(VideoPokerOptions options)
    {
        VegasCheckBox.IsVisible        = false;
        HideBetBoardCheckBox.IsVisible = true;
        PointHighlightsCheckBox.IsVisible = true;

        HideBetBoardCheckBox.IsChecked = options.HideBetBoard;
        SoundCheckBox.IsChecked        = options.IsSoundEnabled;

        var shared = SettingsService.LoadOptions();
        NoStressModeCheckBox.IsChecked = shared.IsNoStressMode;
        HideHintCheckBox.IsChecked     = shared.HideHintButton;
        AlwaysOnTopCheckBox.IsChecked  = shared.IsAlwaysOnTop;
        PointHighlightsCheckBox.IsChecked = shared.HoneyMode;
        ManuallyDismissBannersCheckBox.IsChecked = shared.ManuallyDismissBanners;
    }

    // Blackjack has its own separate options model, same shape as Video Poker above —
    // only sound is Blackjack-specific; No Stress Mode/Hide Hint/Honey Mode are global
    // (shared GameOptions) and Visual Themes is available same as every other game.
    // Blackjack has no Hide Bet Board concept, unlike Video Poker.
    private void SyncUIFromBlackjackOptions(BlackjackOptions options)
    {
        VegasCheckBox.IsVisible        = false;
        HideBetBoardCheckBox.IsVisible = false;
        PointHighlightsCheckBox.IsVisible = true;

        SoundCheckBox.IsChecked = options.IsSoundEnabled;

        var shared = SettingsService.LoadOptions();
        NoStressModeCheckBox.IsChecked = shared.IsNoStressMode;
        HideHintCheckBox.IsChecked     = shared.HideHintButton;
        AlwaysOnTopCheckBox.IsChecked  = shared.IsAlwaysOnTop;
        PointHighlightsCheckBox.IsChecked = shared.HoneyMode;
        ManuallyDismissBannersCheckBox.IsChecked = shared.ManuallyDismissBanners;
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
                GameModeCombo.Items.Add(new ComboBoxItem { Content = "1 Deck Freecell", Tag = "Freecell1" });
                GameModeCombo.Items.Add(new ComboBoxItem { Content = "2 Deck Freecell", Tag = "Freecell2" });
                currentTag = options.FreecellDeckCount == 2 ? "Freecell2" : "Freecell1";
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

    // The dropdown only records the pending selection here — the actual game-mode
    // change (and its "abandon current game?" confirmation, if needed) is deferred
    // until the user clicks OK on the Preferences panel. See MainWindow.ClosePreferences_Click.
    private void GameMode_Changed(object? sender, SelectionChangedEventArgs e)
    {
    }

    // Returns true and the newly-selected tag if the game-mode combo's selection
    // differs from what was in effect when Preferences was opened (or last committed).
    public bool TryGetPendingGameModeChange(out string? newTag)
    {
        newTag = null;
        if (GameModeCombo.SelectedItem is not ComboBoxItem item || item.Tag == null) return false;
        if (GameModeCombo.SelectedIndex == _confirmedGameModeIndex) return false;
        newTag = item.Tag.ToString();
        return true;
    }

    public void RevertGameModeCombo()
    {
        GameModeCombo.SelectedIndex = _confirmedGameModeIndex;
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

        Guid? activeThemeId = DataContext is GameOptions options ? options.ActiveThemeId : null;

        foreach (var theme in _themes)
            ThemeListPanel.Children.Add(BuildThemeRow(theme, theme.Id == activeThemeId));
    }

    // The sidebar is only 180px wide, so this stacks vertically (header row, optional
    // "Active" caption, then a full-width action button) instead of the old single-line
    // Grid layout, which was sized for the previous ~290px-wide column and overlapped
    // buttons on top of the theme name at this width.
    private Border BuildThemeRow(SoliBeeTheme theme, bool isActive)
    {
        var swatchHex = FeltSwatchHex(theme);
        Color swatchColor;
        try { swatchColor = Color.Parse(swatchHex); } catch { swatchColor = Colors.Green; }

        var swatch = new Border
        {
            Width = 14, Height = 14,
            CornerRadius = new CornerRadius(7),
            Background = new SolidColorBrush(swatchColor),
            VerticalAlignment = VerticalAlignment.Center
        };

        var nameBlock = new TextBlock
        {
            Text = theme.Name,
            Foreground = new SolidColorBrush(Color.Parse("#1A1A1A")),
            TextTrimming = TextTrimming.CharacterEllipsis,
            Margin = new Thickness(6, 0, 0, 0),
            VerticalAlignment = VerticalAlignment.Center,
            Cursor = new Cursor(StandardCursorType.Hand)
        };
        nameBlock.DoubleTapped += (_, _) => OpenRenameTheme(theme);

        var headerRow = new Grid { ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto") };
        Grid.SetColumn(swatch, 0);
        headerRow.Children.Add(swatch);
        Grid.SetColumn(nameBlock, 1);
        headerRow.Children.Add(nameBlock);

        var deleteBtn = new Button
        {
            Content = "✕",
            Tag = theme,
            Background = new SolidColorBrush(Color.Parse("#7C2D22")),
            Foreground = Brushes.White,
            Padding = new Thickness(6, 2),
            FontSize = 10,
            CornerRadius = new CornerRadius(6)
        };
        deleteBtn.Click += DeleteTheme_Click;
        Grid.SetColumn(deleteBtn, 2);
        headerRow.Children.Add(deleteBtn);

        var rowStack = new StackPanel { Spacing = 6 };
        rowStack.Children.Add(headerRow);

        // Live-save (NotifySettingsChanged) keeps the active theme's saved preset
        // continuously up to date now, so there's nothing left to resave — the button
        // just states the row's status instead of offering an action.
        if (isActive)
        {
            var activeBtn = new Button
            {
                Content = "Active",
                IsEnabled = false,
                Background = new SolidColorBrush(Color.Parse("#DDDDDD")),
                Foreground = new SolidColorBrush(Color.Parse("#777777")),
                Padding = new Thickness(8, 4),
                CornerRadius = new CornerRadius(8),
                HorizontalAlignment = HorizontalAlignment.Stretch,
                HorizontalContentAlignment = HorizontalAlignment.Center
            };
            rowStack.Children.Add(activeBtn);
        }
        else
        {
            var applyBtn = new Button
            {
                Content = "Apply",
                Tag = theme,
                Background = new SolidColorBrush(Color.Parse("#E5E5E5")),
                Foreground = new SolidColorBrush(Color.Parse("#1A1A1A")),
                Padding = new Thickness(8, 4),
                CornerRadius = new CornerRadius(8),
                HorizontalAlignment = HorizontalAlignment.Stretch,
                HorizontalContentAlignment = HorizontalAlignment.Center
            };
            applyBtn.Click += ApplyTheme_Click;
            rowStack.Children.Add(applyBtn);
        }

        // Active row gets a light tint of the theme's own felt color instead of plain
        // white — a second, at-a-glance cue for which theme is active beyond the
        // checkmark/"Active" button, using a color already tied to that specific theme.
        var cellBackground = isActive ? LightenTowardsWhite(swatchColor, 0.5) : Colors.White;

        return new Border
        {
            Child = rowStack,
            Background = new SolidColorBrush(cellBackground),
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(8, 6),
            Margin = new Thickness(0, 2, 0, 2)
        };
    }

    // Blends a color towards white by the given fraction (0 = no change, 1 = pure white)
    // so the active theme's swatch hue tints its row without washing out the text.
    private static Color LightenTowardsWhite(Color color, double fraction)
    {
        byte Blend(byte channel) => (byte)(channel + (255 - channel) * fraction);
        return Color.FromRgb(Blend(color.R), Blend(color.G), Blend(color.B));
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

    private void OpenRenameTheme(SoliBeeTheme theme)
    {
        _themeToRename = theme;
        RenameThemeInput.Text = theme.Name;
        RenameThemeOverlay.IsVisible = true;
    }

    private void CancelRenameTheme_Click(object? sender, RoutedEventArgs e)
    {
        _themeToRename = null;
        RenameThemeOverlay.IsVisible = false;
    }

    private void ConfirmRenameTheme_Click(object? sender, RoutedEventArgs e)
    {
        RenameThemeOverlay.IsVisible = false;
        var name = RenameThemeInput.Text?.Trim();
        if (string.IsNullOrEmpty(name) || _themeToRename == null)
        {
            _themeToRename = null;
            return;
        }

        ThemeService.RenameTheme(_themeToRename.Id, name);
        _themeToRename = null;
        RefreshThemeList();
    }

    private void ConfirmSaveTheme_Click(object? sender, RoutedEventArgs e)
    {
        SaveThemeOverlay.IsVisible = false;
        var name = ThemeNameInput.Text?.Trim();
        if (string.IsNullOrEmpty(name)) return;
        if (DataContext is not GameOptions options) return;
        var theme = ThemeService.SnapshotFromOptions(name, options);
        ThemeService.AddTheme(theme);
        options.ActiveThemeId = theme.Id;
        NotifySettingsChanged(options);
        // Save Theme is an already-committed action, like the theme file itself — keep the
        // Cancel-revert snapshot in sync so a later Cancel doesn't undo just this one field
        // while the permanently-saved theme it refers to stays in themes.json.
        if (_originalGameOptions != null) _originalGameOptions.ActiveThemeId = theme.Id;
        RefreshThemeList();
    }

    // Applying used to risk silently discarding custom face art, so this warned first —
    // now moot: live-save (NotifySettingsChanged, plus the FaceCardArtChangedMessage
    // hook in the constructor) keeps whichever theme is currently active continuously in
    // sync with the live state, Default included (ThemeService.UpdateTheme has no
    // special-casing by theme origin). By the time Apply is clicked, the theme you're
    // leaving already has your current art saved under its own name — switching away
    // never loses it.
    private void ApplyTheme_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is not Button btn || btn.Tag is not SoliBeeTheme theme) return;
        if (DataContext is not GameOptions options) return;

        ApplyThemeNow(theme, options);
    }

    private void ApplyThemeNow(SoliBeeTheme theme, GameOptions options)
    {
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

        RefreshThemeList();
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
            DeleteCustomCardBackButton.IsEnabled = true;

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
            options.IsNoStressMode     = NoStressModeCheckBox.IsChecked ?? false;
            options.IsSoundEnabled     = SoundCheckBox.IsChecked        ?? false;
            options.IsVegasScoring     = VegasCheckBox.IsChecked        ?? false;
            options.IsVignetteEnabled  = VignetteCheckBox.IsChecked     ?? true;
            SetHideHintButton(options, HideHintCheckBox.IsChecked ?? false);
            options.IsAlwaysOnTop      = AlwaysOnTopCheckBox.IsChecked  ?? false;
            options.HoneyMode          = PointHighlightsCheckBox.IsChecked  ?? true;
            options.ManuallyDismissBanners = ManuallyDismissBannersCheckBox.IsChecked ?? false;

            NotifySettingsChanged(options);
            if (ActiveGameFamily == "Honeycomb") SaveHoneycombOptionsAndNotify();
        }
        else if (DataContext is VideoPokerOptions vpOptions)
        {
            vpOptions.IsSoundEnabled  = SoundCheckBox.IsChecked        ?? false;
            vpOptions.HideBetBoard    = HideBetBoardCheckBox.IsChecked ?? false;

            // No Stress Mode/Hide Hint are global — write to the shared GameOptions
            // so every game (Klondike/Freecell/Spider/Blackjack too) picks up the change.
            var shared = SettingsService.LoadOptions();
            shared.IsNoStressMode    = NoStressModeCheckBox.IsChecked ?? false;
            shared.HideHintButton    = HideHintCheckBox.IsChecked  ?? false;
            shared.IsAlwaysOnTop     = AlwaysOnTopCheckBox.IsChecked ?? false;
            shared.HoneyMode         = PointHighlightsCheckBox.IsChecked ?? true;
            shared.ManuallyDismissBanners = ManuallyDismissBannersCheckBox.IsChecked ?? false;
            NotifySettingsChanged(shared);

            // vpOptions is the live VideoPokerViewModel.Options instance, so mutations
            // above already apply — SaveOptions() persists to disk and notifies the view.
            VideoPokerVm?.SaveOptions();
        }
        else if (DataContext is BlackjackOptions bjOptions)
        {
            bjOptions.IsSoundEnabled  = SoundCheckBox.IsChecked ?? false;

            // No Stress Mode/Hide Hint are global — write to the shared GameOptions
            // so every game (Klondike/Freecell/Spider/VideoPoker too) picks up the change.
            var shared = SettingsService.LoadOptions();
            shared.IsNoStressMode    = NoStressModeCheckBox.IsChecked ?? false;
            shared.HideHintButton    = HideHintCheckBox.IsChecked  ?? false;
            shared.IsAlwaysOnTop     = AlwaysOnTopCheckBox.IsChecked ?? false;
            shared.HoneyMode         = PointHighlightsCheckBox.IsChecked ?? true;
            shared.ManuallyDismissBanners = ManuallyDismissBannersCheckBox.IsChecked ?? false;
            NotifySettingsChanged(shared);

            // bjOptions is the live BlackjackViewModel.Options instance, so mutations
            // above already apply — SaveOptions() persists to disk and notifies the view.
            BlackjackVm?.SaveOptions();
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
                DeleteCustomCardBackButton.IsEnabled = true;
                break;
            }
        }
        _initializing = false;

        UpdateCardBackPreview(options);
    }

    private static readonly string[] _builtInCardBackNames =
    {
        "Vulpera", "Moogle", "Forest", "On the Water",
        "Pareidolic", "Pareidolic 2", "Red Sky", "Sunset", "Solibee",
    };

    private static bool IsBuiltInCardBack(string name) => _builtInCardBackNames.Contains(name);

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
            ["Solibee"]      = "solibee.png",
        };

    // Keeps _cardBackPreviewBitmap warm for AdjustCardBack_Click's editor flow (it falls
    // back to LoadCardBackBitmapForPreview when this is null, so staying fresh here is an
    // optimization, not a correctness requirement) and refreshes the merged card+backdrop
    // mockup — the mockup itself is a real CardView, which already renders the current
    // CardBackTheme/scale/offset from GameOptions on its own, so no manual transform math
    // is needed here the way the old standalone Image preview required.
    private void UpdateCardBackPreview(GameOptions options)
    {
        var old = _cardBackPreviewBitmap;
        _cardBackPreviewBitmap = LoadCardBackBitmapForPreview(options);
        old?.Dispose();

        RefreshDeckBackgroundPreview();
    }

    private static Bitmap? LoadCardBackBitmapForPreview(GameOptions options)
    {
        try
        {
            string theme = options.CardBackTheme;
            if (theme == "Dingwall")
                return new Bitmap(AssetLoader.Open(new Uri("avares://Honeycomb/Assets/dingwall.jpg")));
            if (theme == "Moogle")
                return new Bitmap(AssetLoader.Open(new Uri("avares://Honeycomb/Assets/moogle.jpg")));
            if (theme == "Vulpera")
                return new Bitmap(AssetLoader.Open(new Uri("avares://Honeycomb/Assets/vulpera.png")));
            if (_houliAssets.TryGetValue(theme, out var assetFile))
                return new Bitmap(AssetLoader.Open(new Uri($"avares://Honeycomb/Assets/{assetFile}")));

            var customBack = options.CustomCardBacks.Find(c => c.Name == theme);
            if (customBack != null && PathSafety.IsSafeFileName(customBack.FileName))
            {
                var path = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    AppDataMigration.FolderName, "CardBacks", customBack.FileName);
                if (File.Exists(path))
                    return new Bitmap(path);
            }
            return new Bitmap(AssetLoader.Open(new Uri("avares://Honeycomb/Assets/vulpera.png")));
        }
        catch { return null; }
    }

    private bool _isEditorOpen;

    private async void AdjustCardBack_Click(object? sender, RoutedEventArgs e)
    {
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
        var selectedItem = CardBackComboBox.SelectedItem as ComboBoxItem;
        var cardBackName = selectedItem?.Tag?.ToString();
        if (cardBackName == null) return;

        // Themes store their card back by name (SoliBeeTheme.CardBackTheme), not by a
        // reference to the CustomCardBack object — deleting the file out from under a
        // saved theme would silently leave that theme pointing at nothing, so block it.
        var themeNames = ThemeService.LoadThemes()
            .Where(t => t.CardBackTheme == cardBackName)
            .Select(t => t.Name)
            .ToList();

        if (themeNames.Count > 0)
        {
            CardBackInUseText.Text = $"This card back is used by {string.Join(", ", themeNames)}. " +
                $"Please delete the theme{(themeNames.Count > 1 ? "s" : "")} first.";
            CardBackInUseOverlay.IsVisible = true;
            return;
        }

        // There must always be at least one card deck design to choose from — built-in
        // or custom — so the last remaining one (of either kind) can't be removed.
        if (CardBackComboBox.Items.Count <= 1)
        {
            CardBackInUseText.Text = "At least one card deck design must remain — you can't delete the last one.";
            CardBackInUseOverlay.IsVisible = true;
            return;
        }

        ConfirmDeleteOverlay.IsVisible = true;
    }

    private void CardBackInUseOk_Click(object? sender, RoutedEventArgs e)
    {
        CardBackInUseOverlay.IsVisible = false;
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
        var nameToDelete = selectedItem.Tag.ToString()!;

        var customBack = options.CustomCardBacks.Find(c => c.Name == nameToDelete);
        if (customBack != null)
        {
            if (PathSafety.IsSafeFileName(customBack.FileName))
            {
                var destDir = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    AppDataMigration.FolderName, "CardBacks");
                var filePath = Path.Combine(destDir, customBack.FileName);
                try { if (File.Exists(filePath)) File.Delete(filePath); } catch { }
            }
            options.CustomCardBacks.Remove(customBack);
        }
        else if (IsBuiltInCardBack(nameToDelete))
        {
            // The bundled asset stays on disk — just hide this design from the picker.
            if (!options.HiddenDefaultCardBacks.Contains(nameToDelete))
                options.HiddenDefaultCardBacks.Add(nameToDelete);
        }
        else return;

        _initializing = true;
        PopulateCardBacks(options);
        _initializing = false;

        // Fall back to whatever's first in the repopulated list — not hardcoded
        // "Vulpera", since the user may have just deleted/hidden Vulpera itself.
        var fallback = CardBackComboBox.Items.OfType<ComboBoxItem>().FirstOrDefault();
        if (fallback?.Tag != null)
            ApplyCardBackSelection(fallback.Tag.ToString()!, options);

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
                AppDataMigration.FolderName, "CardBacks");
            if (!Directory.Exists(destDir))
                Directory.CreateDirectory(destDir);

            bool isGif = file.Name.EndsWith(".gif", StringComparison.OrdinalIgnoreCase);
            string uniqueFileName = Guid.NewGuid().ToString() + (isGif ? ".gif" : ".png");
            string destPath = Path.Combine(destDir, uniqueFileName);

            using (var sourceStream = await file.OpenReadAsync())
            {
                if (isGif)
                {
                    // The ".gif" extension alone doesn't guarantee the picked file is
                    // actually a GIF — check the standard GIF87a/GIF89a magic header
                    // before writing it into the app's data folder.
                    using var memStream = new MemoryStream();
                    await sourceStream.CopyToAsync(memStream);
                    memStream.Position = 0;

                    var header = new byte[6];
                    int read = await memStream.ReadAsync(header, 0, header.Length);
                    string signature = read == header.Length ? System.Text.Encoding.ASCII.GetString(header) : "";
                    if (signature != "GIF87a" && signature != "GIF89a")
                        throw new InvalidDataException("Selected file is not a valid GIF image.");

                    memStream.Position = 0;
                    using var destStream = File.Create(destPath);
                    await memStream.CopyToAsync(destStream);
                }
                else
                {
                    using var destStream = File.Create(destPath);
                    await sourceStream.CopyToAsync(destStream);
                }
            }

            Bitmap editorBmp;
            using (var stream = File.OpenRead(destPath))
            {
                if (isGif)
                    editorBmp = new Bitmap(stream);
                else
                    editorBmp = Bitmap.DecodeToWidth(stream, 1024);
            }

            var owner = (Window?)TopLevel.GetTopLevel(this);
            var editor = new CardBackEditorWindow(editorBmp, false, 1.0, 0.0, 0.0);

            if (owner != null)
                await editor.ShowDialog(owner);
            else
                editor.Show();

            if (editor.Saved)
            {
                var newBack = new CustomCardBack
                {
                    Name = displayName,
                    FileName = uniqueFileName,
                    Scale = editor.NewScale,
                    OffsetX = editor.NewOffsetX,
                    OffsetY = editor.NewOffsetY
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

                options.CardBackScale = editor.NewScale;
                options.CardBackOffsetX = editor.NewOffsetX;
                options.CardBackOffsetY = editor.NewOffsetY;
                DeleteCustomCardBackButton.IsEnabled = true;

                _initializing = false;

                UpdateCardBackPreview(options);
                NotifySettingsChanged(options);
                CardView.PreloadCardBacks(options);
            }
            else
            {
                try { File.Delete(destPath); } catch { }
            }
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Failed to add custom card back: {ex}");
        }
    }

    // ── Background ────────────────────────────────────────────────────────────

    private static readonly byte[] _pngMagic = { 0x89, 0x50, 0x4E, 0x47 };
    private static readonly byte[] _jpegMagic = { 0xFF, 0xD8, 0xFF };
    private const long MaxBackgroundFileSizeBytes = 25L * 1024 * 1024;

    private static string BackgroundsDir => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        AppDataMigration.FolderName, "Backgrounds");

    // Handles both halves of the merged dropdown — a "felt:" tag picks a felt preset
    // (or reveals the Custom Color flyout) and clears any background image; a "bg:" tag
    // picks a background image (or "None", clearing back to the felt color) and enables
    // Delete only for a real named image, not "None".
    private void BackgroundComboBox_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (_initializing) return;
        if (DataContext is not GameOptions options) return;
        if (BackgroundComboBox.SelectedItem is not ComboBoxItem item) return;
        var tag = item.Tag?.ToString();
        if (string.IsNullOrEmpty(tag)) return;

        if (tag.StartsWith("felt:"))
        {
            var feltTag = tag.Substring("felt:".Length);
            if (!Enum.TryParse<FeltColorTheme>(feltTag, out var feltTheme)) return;

            options.FeltColor = feltTheme;
            options.BackgroundName = null;
            options.BackgroundScale = 1.0;
            options.BackgroundOffsetX = 0.0;
            options.BackgroundOffsetY = 0.0;
            DeleteCustomBackgroundButton.IsEnabled = false;

            if (feltTheme == FeltColorTheme.Custom)
            {
                CustomColorPanel.IsVisible = true;
                if (Color.TryParse(options.CustomFeltColorHex, out var parsedColor))
                    FeltColorPicker.Color = parsedColor;
            }
            else
            {
                CustomColorPanel.IsVisible = false;
            }

            options.CustomFeltColorRevision++;
        }
        else if (tag.StartsWith("bg:"))
        {
            var bgName = tag.Substring("bg:".Length);
            options.BackgroundName = string.IsNullOrEmpty(bgName) ? null : bgName;
            DeleteCustomBackgroundButton.IsEnabled = !string.IsNullOrEmpty(bgName);
            CustomColorPanel.IsVisible = false;

            var bg = options.CustomBackgrounds.Find(b => b.Name == bgName);
            if (bg != null)
            {
                options.BackgroundScale = bg.Scale;
                options.BackgroundOffsetX = bg.OffsetX;
                options.BackgroundOffsetY = bg.OffsetY;
            }
            else
            {
                options.BackgroundScale = 1.0;
                options.BackgroundOffsetX = 0.0;
                options.BackgroundOffsetY = 0.0;
            }
        }
        else
        {
            return;
        }

        UpdateBackgroundPreview(options);
        NotifySettingsChanged(options);
    }

    private void UpdateBackgroundPreview(GameOptions options)
    {
        RefreshDeckBackgroundPreview();
    }

    private bool _deckBackgroundMockBuilt;

    // Builds (once) and refreshes the merged Card Deck + Background mockup: the real
    // configured card back rendered on top of the real configured backdrop (felt color,
    // or the actual background image when one is set — shown directly, not sampled,
    // since it's meaningful and visible here unlike the Custom Card Colors preview).
    private void RefreshDeckBackgroundPreview()
    {
        if (DataContext is not GameOptions options) return;

        if (!_deckBackgroundMockBuilt)
        {
            var mockCard = new CardView
            {
                Card = new Card("mock-deck-back", CardSuit.Spades, 1, false),
                Cursor = new Cursor(StandardCursorType.Hand)
            };
            // Handled=true stops this from also triggering the backdrop Border's own
            // DoubleTapped (background adjust) — double-clicking the card should only
            // ever open the card-back editor, never both.
            mockCard.DoubleTapped += (s, e) => { e.Handled = true; AdjustCardBack_Click(s, e); };
            DeckBackgroundCardMockHost.Content = mockCard;
            _deckBackgroundMockBuilt = true;
        }


        var bmp = LoadBackgroundBitmapForPreview(options);
        if (bmp != null)
        {
            DeckBackgroundImage.Source = bmp;
            DeckBackgroundImage.IsVisible = true;
            DeckBackgroundBackdrop.Background = null;
        }
        else
        {
            DeckBackgroundImage.IsVisible = false;
            DeckBackgroundImage.Source = null;
            DeckBackgroundBackdrop.Background = Color.TryParse(FeltHexForOptions(options), out var felt)
                ? new SolidColorBrush(felt)
                : new SolidColorBrush(Colors.DarkGreen);
        }

        CardView.InvalidateAllCardViews(DeckBackgroundCardMockHost);
    }

    private static Bitmap? LoadBackgroundBitmapForPreview(GameOptions options)
    {
        if (string.IsNullOrEmpty(options.BackgroundName)) return null;
        var bg = options.CustomBackgrounds.Find(b => b.Name == options.BackgroundName);
        if (bg == null || !PathSafety.IsSafeFileName(bg.FileName)) return null;
        try
        {
            var path = Path.Combine(BackgroundsDir, bg.FileName);
            // Use the shared cache so MainWindow and the preview panel decode the image once.
            return File.Exists(path) ? CardView.GetCachedBackgroundBitmap(path) : null;
        }
        catch { return null; }
    }

    // Double-clicking the backdrop (anywhere the mock card itself doesn't already
    // consume the tap — see the Handled=true in RefreshDeckBackgroundPreview) opens the
    // same background editor the old small preview thumbnail used to.
    private void DeckBackgroundBackdrop_DoubleTapped(object? sender, TappedEventArgs e) =>
        AdjustBackground_Click(sender, e);

    private async void AdjustBackground_Click(object? sender, RoutedEventArgs e)
    {
        if (_isBackgroundEditorOpen) return;
        if (DataContext is not GameOptions options) return;
        if (string.IsNullOrEmpty(options.BackgroundName)) return;

        var bg = options.CustomBackgrounds.Find(b => b.Name == options.BackgroundName);
        if (bg == null) return;

        _isBackgroundEditorOpen = true;
        try
        {
            // Load a fresh full-resolution bitmap from disk for the editor so it renders at
            // full quality in the 280 px preview. We must not reuse the shared-cache bitmap
            // directly here because BackgroundEditorWindow now owns and disposes whatever
            // bitmap it receives on close — passing the cache entry would evict it.
            var bgFile = options.CustomBackgrounds.Find(b => b.Name == options.BackgroundName);
            if (bgFile == null || !PathSafety.IsSafeFileName(bgFile.FileName)) return;
            var bgPath = Path.Combine(BackgroundsDir, bgFile.FileName);
            if (!File.Exists(bgPath)) return;
            Bitmap bmp;
            try { bmp = new Bitmap(bgPath); }
            catch { return; }

            var owner = (Window?)TopLevel.GetTopLevel(this);
            var editor = new BackgroundEditorWindow(bmp, isNew: false, bg.Name,
                options.BackgroundScale, options.BackgroundOffsetX, options.BackgroundOffsetY);

            if (owner != null)
                await editor.ShowDialog(owner);
            else
                editor.Show();

            if (editor.Saved)
            {
                options.BackgroundScale = editor.NewScale;
                options.BackgroundOffsetX = editor.NewOffsetX;
                options.BackgroundOffsetY = editor.NewOffsetY;

                bg.Scale = editor.NewScale;
                bg.OffsetX = editor.NewOffsetX;
                bg.OffsetY = editor.NewOffsetY;

                UpdateBackgroundPreview(options);
                NotifySettingsChanged(options);
            }
        }
        finally
        {
            _isBackgroundEditorOpen = false;
        }
    }

    private async void AddCustomBackground_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not GameOptions options) return;

        var topLevel = TopLevel.GetTopLevel(this);
        if (topLevel == null) return;

        var files = await topLevel.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "Select Background Image",
            AllowMultiple = false,
            FileTypeFilter = new[] { FilePickerFileTypes.ImageAll }
        });

        if (files == null || files.Count == 0) return;

        var file = files[0];
        string? destPath = null;
        try
        {
            using var memStream = new MemoryStream();
            using (var sourceStream = await file.OpenReadAsync())
            {
                var buffer = new byte[81920];
                long total = 0;
                int read;
                while ((read = await sourceStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
                {
                    total += read;
                    if (total > MaxBackgroundFileSizeBytes)
                    {
                        BackgroundAlertText.Text = "That image is larger than 25 MB. Please choose a smaller file.";
                        BackgroundAlertOverlay.IsVisible = true;
                        return;
                    }
                    memStream.Write(buffer, 0, read);
                }
            }

            var bytes = memStream.ToArray();
            bool isPng = bytes.Length >= _pngMagic.Length && bytes.AsSpan(0, _pngMagic.Length).SequenceEqual(_pngMagic);
            bool isJpeg = bytes.Length >= _jpegMagic.Length && bytes.AsSpan(0, _jpegMagic.Length).SequenceEqual(_jpegMagic);
            if (!isPng && !isJpeg)
            {
                BackgroundAlertText.Text = "Selected file is not a valid PNG or JPEG image.";
                BackgroundAlertOverlay.IsVisible = true;
                return;
            }

            string ext = isPng ? ".png" : ".jpg";
            if (!Directory.Exists(BackgroundsDir))
                Directory.CreateDirectory(BackgroundsDir);

            string uniqueFileName = Guid.NewGuid().ToString() + ext;
            destPath = Path.Combine(BackgroundsDir, uniqueFileName);
            await File.WriteAllBytesAsync(destPath, bytes);

            string displayName = Path.GetFileNameWithoutExtension(file.Name);
            if (string.IsNullOrWhiteSpace(displayName)) displayName = "Background";
            // Loop until we have a unique display name — a single suffix attempt could still
            // collide if the user has already imported a file with that same suffix.
            while (options.CustomBackgrounds.Exists(b => b.Name.Equals(displayName, StringComparison.OrdinalIgnoreCase)))
                displayName = Path.GetFileNameWithoutExtension(file.Name) + "_" + Guid.NewGuid().ToString("N")[..6];

            // Construct the Bitmap from the already-buffered bytes (seeked back to the start)
            // rather than re-reading from disk, eliminating a redundant I/O round-trip.
            memStream.Seek(0, SeekOrigin.Begin);
            var bmp = new Bitmap(memStream);
            var owner = (Window?)TopLevel.GetTopLevel(this);
            var editor = new BackgroundEditorWindow(bmp, isNew: true, displayName, 1.0, 0.0, 0.0);

            if (owner != null)
                await editor.ShowDialog(owner);
            else
                editor.Show();

            if (!editor.Saved)
            {
                // User backed out of the "name it" editor — nothing left orphaned.
                try { File.Delete(destPath); } catch { }
                return;
            }

            var newBg = new CustomBackground
            {
                Name = editor.NewName,
                FileName = uniqueFileName,
                Scale = editor.NewScale,
                OffsetX = editor.NewOffsetX,
                OffsetY = editor.NewOffsetY
            };
            options.CustomBackgrounds.Add(newBg);
            options.BackgroundName = newBg.Name;
            options.BackgroundScale = newBg.Scale;
            options.BackgroundOffsetX = newBg.OffsetX;
            options.BackgroundOffsetY = newBg.OffsetY;

            _initializing = true;
            PopulateBackgrounds(options);
            foreach (var item in BackgroundComboBox.Items.OfType<ComboBoxItem>())
            {
                if (item.Tag?.ToString() == "bg:" + newBg.Name)
                {
                    BackgroundComboBox.SelectedItem = item;
                    break;
                }
            }
            DeleteCustomBackgroundButton.IsEnabled = true;
            CustomColorPanel.IsVisible = false;
            _initializing = false;

            UpdateBackgroundPreview(options);
            NotifySettingsChanged(options);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"Failed to add custom background: {ex}");
            if (destPath != null) { try { File.Delete(destPath); } catch { } }
        }
    }

    private void DeleteCustomBackground_Click(object? sender, RoutedEventArgs e)
    {
        var selectedItem = BackgroundComboBox.SelectedItem as ComboBoxItem;
        var selectedTag = selectedItem?.Tag?.ToString();
        if (string.IsNullOrEmpty(selectedTag) || !selectedTag.StartsWith("bg:")) return;
        var backgroundName = selectedTag.Substring("bg:".Length);
        if (string.IsNullOrEmpty(backgroundName)) return;

        // Themes store their background by name (SoliBeeTheme.BackgroundName), not by a
        // reference to the CustomBackground object — deleting the file out from under a
        // saved theme would silently leave that theme pointing at nothing, so block it.
        var themeNames = ThemeService.LoadThemes()
            .Where(t => t.BackgroundName == backgroundName)
            .Select(t => t.Name)
            .ToList();

        if (themeNames.Count > 0)
        {
            BackgroundAlertText.Text = $"This background is used by \"{themeNames[0]}\". " +
                "Please delete the theme first.";
            BackgroundAlertOverlay.IsVisible = true;
            return;
        }

        _backgroundToDelete = backgroundName;
        ConfirmDeleteBackgroundOverlay.IsVisible = true;
    }

    private void BackgroundAlertOk_Click(object? sender, RoutedEventArgs e)
    {
        BackgroundAlertOverlay.IsVisible = false;
    }

    private void CancelDeleteBackground_Click(object? sender, RoutedEventArgs e)
    {
        _backgroundToDelete = null;
        ConfirmDeleteBackgroundOverlay.IsVisible = false;
    }

    private void ConfirmDeleteBackground_Click(object? sender, RoutedEventArgs e)
    {
        ConfirmDeleteBackgroundOverlay.IsVisible = false;
        if (_backgroundToDelete == null) return;
        if (DataContext is not GameOptions options) return;

        var bg = options.CustomBackgrounds.Find(b => b.Name == _backgroundToDelete);
        if (bg != null)
        {
            if (PathSafety.IsSafeFileName(bg.FileName))
            {
                var filePath = Path.Combine(BackgroundsDir, bg.FileName);
                try { if (File.Exists(filePath)) File.Delete(filePath); } catch { }
                CardView.InvalidateFaceArtCache(filePath);
            }
            options.CustomBackgrounds.Remove(bg);
        }

        if (options.BackgroundName == _backgroundToDelete)
        {
            options.BackgroundName = null;
            options.BackgroundScale = 1.0;
            options.BackgroundOffsetX = 0.0;
            options.BackgroundOffsetY = 0.0;
        }

        _backgroundToDelete = null;

        _initializing = true;
        PopulateBackgrounds(options);
        string selectedTag = !string.IsNullOrEmpty(options.BackgroundName)
            ? "bg:" + options.BackgroundName
            : "felt:" + options.FeltColor;
        foreach (var item in BackgroundComboBox.Items.OfType<ComboBoxItem>())
        {
            if ((item.Tag?.ToString() ?? "") == selectedTag) { BackgroundComboBox.SelectedItem = item; break; }
        }
        DeleteCustomBackgroundButton.IsEnabled = !string.IsNullOrEmpty(options.BackgroundName);
        _initializing = false;

        UpdateBackgroundPreview(options);
        NotifySettingsChanged(options);
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
        else if (sender == HintHighlightColorPicker)
            options.ThemeHintHighlight = e.NewColor.ToString();

        CardView.ApplyThemeColors(options);
        NotifySettingsChanged(options);
        CardView.BroadcastThemeChange();
    }

    private void ResetCardColors_Click(object? sender, RoutedEventArgs e)
    {
        ConfirmResetCardColorsOverlay.IsVisible = true;
    }

    private void CancelResetCardColors_Click(object? sender, RoutedEventArgs e)
    {
        ConfirmResetCardColorsOverlay.IsVisible = false;
    }

    private void ConfirmResetCardColors_Click(object? sender, RoutedEventArgs e)
    {
        ConfirmResetCardColorsOverlay.IsVisible = false;
        if (DataContext is not GameOptions options) return;

        options.ThemeFaceBackNormal = null;
        options.ThemeFaceBorderNormal = null;
        options.ThemeTextBlackNormal = null;
        options.ThemeTextRed = null;
        options.ThemeCardShadow = null;
        options.ThemeHintHighlight = null;

        _initializing = true;
        CardBgColorPicker.Color = Colors.White;
        CardOutlineColorPicker.Color = Color.Parse("#D9000000");
        CardTextBlackColorPicker.Color = Color.Parse("#1A1A1A");
        CardTextRedColorPicker.Color = Color.Parse("#CC1A1A");
        HintHighlightColorPicker.Color = Color.Parse("#FFD700");
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

        // Live-save: keep the active theme's saved preset in sync with every live edit,
        // so there's never a "Resave" step to remember — the "Active" row is always
        // already up to date. Cheap enough to call unconditionally (small JSON file,
        // user-paced edits, not a hot path).
        if (options.ActiveThemeId.HasValue)
        {
            ThemeService.UpdateTheme(options.ActiveThemeId.Value, options);
            if (ThemesPanel.IsVisible) RefreshThemeList();
        }

        // Keep the card-color mock preview in sync with every live edit — felt/background
        // changes affect the backdrop, card-back/color changes affect the mock cards
        // themselves (InvalidateAllCardViews repaints every CardView under this root).
        if (CardColorsPanel.IsVisible)
        {
            RefreshCardColorPreviewBackdrop();
            CardView.InvalidateAllCardViews(CardColorPreviewStack);
        }

        // Card Deck + Background mockup is always inline whenever ThemesPanel is open.
        if (ThemesPanel.IsVisible) RefreshDeckBackgroundPreview();
    }

        

    private void SaveHoneycombOptionsAndNotify()
    {
        if (HoneycombOptions == null) return;
        
        SettingsService.SaveHoneycombOptions(HoneycombOptions);
        if (App.Current?.ApplicationLifetime is Avalonia.Controls.ApplicationLifetimes.IClassicDesktopStyleApplicationLifetime desktop)
        {
            if (desktop.MainWindow is MainWindow mw && mw.DataContext is HoneycombViewModel hVm)
            {
                hVm.Options = HoneycombOptions;
                // HoneycombOptions here is already the same live reference as hVm.Options
                // (see Preferences_Click), so the assignment above is a no-op under
                // ObservableProperty's reference-equality check and won't raise
                // PropertyChanged(Options) — explicitly notify so live listeners (e.g.
                // MainWindow's Hint-button-visibility update) still pick up the change.
                hVm.NotifyOptionsChanged();
            }
        }
    }
}
