using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Threading;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using SoliBee.Desktop.Views;

namespace SoliBee.Desktop.Views;

public partial class MainWindow : Window
{
    private AppCoordinator _coordinator;
    private ThemeEditorWindow? _themeEditor;
    private HelpWindow? _helpWindow;
    private readonly ScaleTransform _contentScale = new(1.0, 1.0);
    private string _currentGameTag = "SolitaireDraw1";
    private bool _variantInitializing;
    private DispatcherTimer? _gameSwitchTimer;
    private string _pendingAction = "";
    private bool _revertingSelection = false;
    private PreferencesView? _preferencesView;
    private ManageDecksView? _manageDecksView;
    private bool _closePreferencesAfterModeConfirm;
    private INotifyPropertyChanged? _hintTrackedVm;
    private AppLanguage _language = AppLanguage.English;
    // Keyed by game family ("Game"/"Freecell"/"Spider"/...), not by tag — variants like
    // SolitaireDraw1/SolitaireDraw3 share one GameView instance since they're the same
    // ViewModel/View with different Options, not different views.
    private readonly Dictionary<string, Control> _cachedViews = new();
    // Tracks which game views/banners currently want the toolbar-covering scrim shown, keyed
    // by BoardScrimRequestMessage.Source — a HashSet rather than a single bool so one banner
    // hiding doesn't clear a scrim another still-visible banner (e.g. a view's own banner
    // plus its embedded WinAnimationView) still needs. See BoardScrimRequestMessage.
    private readonly HashSet<object> _activeScrimSources = new();

    public MainWindow()
    {
        InitializeComponent();

        MainContentWrapper.LayoutTransform = _contentScale;

        // The authoritative trigger for the responsive scale-to-fit calculation: fires
        // once per completed layout pass with GameAreaGrid's real, final Bounds, whether
        // that's from an OS window resize, the initial show, or a game switch resizing
        // the window programmatically. Other call sites (SizeChanged, the post-game-switch
        // Dispatcher.Post, Opened) fire eagerly too, but this is the one that can't read a
        // stale/mid-transition size, since Bounds by definition only updates from a real
        // layout pass.
        GameAreaGrid.PropertyChanged += (_, e) =>
        {
            if (e.Property == Visual.BoundsProperty) UpdateResponsiveLayout();
        };

        _coordinator = new AppCoordinator();

        // First launch: apply the "Default" theme (Solibee + Felt Green) as the default visual theme
        if (ThemeService.ApplyDefaultThemeIfNeeded(_coordinator.GameViewModel.Options))
            SettingsService.SaveOptions(_coordinator.GameViewModel.Options);

        // Every launch: converge the saved themes list with the current preset
        // definitions (adds any new presets, corrects colors on existing ones by name)
        // without touching anything else the user has saved.
        ThemeService.MergeInDefaultThemes();

        // Restore the last game the user had open; SelectionChanged handler sets content + DataContext
        GameSelectionBox.SelectedIndex = GameModeToIndex(_coordinator.GameViewModel.Options.LastGameMode);

#if DEBUG
        // Local-dev-only banner review menu — never visible in a published Release build.
        DebugBannerButton.IsVisible = true;
#endif

        // Register to listen to OptionsChangedMessage to keep Window background color in sync
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            ApplyFeltColor(m.Options);
            ApplyBoardBackground(m.Options);
            CardView.ApplyThemeColors(m.Options);
            CardView.InvalidateAllCardViews(this);
            bool isCardGame = _currentGameTag != "VideoPoker" && _currentGameTag != "Blackjack" && _currentGameTag != "Honeycomb";
            if (TimeStatPanel != null)  TimeStatPanel.IsVisible  = isCardGame && !m.Options.IsNoStressMode;
            if (ScoreStatPanel != null) ScoreStatPanel.IsVisible = isCardGame && !m.Options.IsNoStressMode;
            if (MovesStatPanel != null) MovesStatPanel.IsVisible = isCardGame && !m.Options.IsNoStressMode;
            // Hint is solitaire-only (no hint logic exists for VP/Blackjack).
            if (HintButton != null)    HintButton.IsVisible    = isCardGame && !m.Options.HideHintButton;
            this.Topmost = m.Options.IsAlwaysOnTop;

            if (m.Options.Language != _language)
            {
                _language = m.Options.Language;
                ApplyLocalization();
                // OpponentNameDisplay (bound in the Honeycomb status bar) reads
                // HoneycombRuleLocalization.LocalizedDifficultyName at get-time, but
                // that binding only re-pulls the value on an explicit change
                // notification — nothing else triggers one on a pure language switch.
                _coordinator.HoneycombViewModel.NotifyOptionsChanged();
            }
        });

        // Also listen to FaceCardArtChangedMessage to keep all cards in sync
        WeakReferenceMessenger.Default.Register<FaceCardArtChangedMessage>(this, (r, m) =>
        {
            CardView.InvalidateAllCardViews(this);
        });

        // Extends whichever game view's own local banner-scrim (Win/Stuck/Autocomplete/
        // round-result) up over the toolbar — the local scrims live inside GameAreaGrid and
        // are sized to that game's own board content, so they can never reach the toolbar
        // strip themselves (root Grid.Row="0", a separate row from GameAreaGrid's Row="1").
        WeakReferenceMessenger.Default.Register<BoardScrimRequestMessage>(this, (r, m) =>
        {
            if (m.Active) _activeScrimSources.Add(m.Source);
            else _activeScrimSources.Remove(m.Source);
            GlobalBannerScrim.IsVisible = _activeScrimSources.Count > 0;
        });

        // Set initial background color
        ApplyFeltColor(_coordinator.GameViewModel.Options);
        ApplyBoardBackground(_coordinator.GameViewModel.Options);
        this.Topmost = _coordinator.GameViewModel.Options.IsAlwaysOnTop;

        _language = SettingsService.LoadOptions().Language;
        ApplyLocalization();

        // Apply any saved theme color overrides before first render
        CardView.ApplyThemeColors(_coordinator.GameViewModel.Options);

        // Tunnel (not the default Bubble) so Escape/Ctrl+Z/Ctrl+H/F1 are seen here first,
        // before a focused child control gets a chance to consume them — a ComboBox
        // (e.g. the difficulty/felt-color/card-back pickers in Preferences) handles
        // Escape internally, which silently swallowed it before it could bubble up to
        // close the Preferences/Rules panel.
        this.AddHandler(KeyDownEvent, OnWindowKeyDown, RoutingStrategies.Tunnel);
        this.Closing += (_, _) => SaveCurrentWindowSize();
        // Re-scale the background image's offset transform to stay proportionally correct
        // as the window is resized (offsets are stored in fixed reference-width units).
        this.SizeChanged += OnWindowSizeChanged;

        // Ensure the window has OS focus/activation immediately — without this, the
        // first click after launch can get consumed by window activation itself,
        // which leaves BeginMoveDrag's native move-loop from registering cleanly and
        // breaks double-click-to-maximize until some other click "wakes" the window.
        this.Opened += (_, _) =>
        {
            this.Activate();

            // Anchor to the top of the screen (horizontally centered) instead of
            // full-screen centering — the taller default board heights otherwise
            // push the title bar above the visible screen area on smaller displays.
            var screen = Screens.ScreenFromWindow(this) ?? Screens.Primary;
            if (screen != null && WindowState != WindowState.Maximized)
            {
                var wa = screen.WorkingArea;
                double x = wa.X + (wa.Width - Width) / 2;
                Position = new PixelPoint((int)x, wa.Y);
            }

            // Safety net for the very first game switch: it runs from the constructor,
            // before the window is shown, so Bounds is still invalid the whole way through
            // and the posted UpdateResponsiveLayout() in ApplyGameSwitch can end up racing
            // an early/incomplete layout pass instead of the fully-shown one. A single call
            // here (Opened firing once the window is genuinely up) wasn't reliable enough in
            // practice — the exact frame the active game view's content finishes populating
            // relative to Opened firing has proven inconsistent.
            //
            // MainContentWrapper starts at Opacity=0 (see MainWindow.axaml) specifically so
            // this settling process isn't visible — once SettleResponsiveLayout below
            // decides it's stable, reveal it via the Opacity transition already defined there.
            SettleResponsiveLayout(() => MainContentWrapper.Opacity = 1);
        };

        // Preload custom art into display-resolution cache before first scroll
        this.Loaded += (_, _) =>
        {
            CardView.PreloadFaceArt();
            CardView.PreloadCardBacks(_coordinator.GameViewModel.Options);
        };
    }

    // Applies the current language to every static toolbar/overlay/dialog string in this
    // window. Runs once at construction and again whenever OptionsChangedMessage reports a
    // language change, so switching language mid-session updates the main window without a
    // restart. Dynamic strings assembled elsewhere in this file (stats titles, confirm-dialog
    // text, the solitaire key-hint row, etc.) also read Strings.Get(..., _language) at the
    // point they're built, so they pick up the current language too.
    private void ApplyLocalization()
    {
        NewGameButton.Content = Strings.Get(StringKey.NewGame, _language);
        RestartButton.Content = Strings.Get(StringKey.Restart, _language);
        HoneycombStartMatchButton.Content = Strings.Get(StringKey.ToolbarStartMatch, _language);
        HoneycombRematchButton.Content = Strings.Get(StringKey.Rematch, _language);
        HoneycombQuitMatchButton.Content = Strings.Get(StringKey.ToolbarQuitMatch, _language);
        OptionsButton.Content = Strings.Get(StringKey.Options, _language);
        HoneycombRulesButton.Content = Strings.Get(StringKey.ToolbarRules, _language);
        HoneycombManageDecksButton.Content = Strings.Get(StringKey.ManageDecks, _language);
        HintButton.Content = Strings.Get(StringKey.Hint, _language);
        UndoButton.Content = Strings.Get(StringKey.Undo, _language);
        DebugBannerButton.Content = Strings.Get(StringKey.DebugBannersMenu, _language);

        // Deliberately NOT translated, in any language — "Jacks or Better", "Deuces
        // Wild", and "Bonus Poker" are the actual names of these casino game variants,
        // and Spanish-speaking players expect to see them in English (the same way
        // "Blackjack" itself isn't translated) rather than a literal translation of the
        // phrase. Left as the static AXAML-authored English literal (see JacksOrBetterItem
        // etc. in MainWindow.axaml) instead of routing through Strings.Get.

        // Beecell/Video Poker/Video Blackjack/Honeycomb are proper nouns the
        // translator kept identical in both languages — still routed through
        // Strings.Get (not left as static AXAML literals) so a future retranslation
        // doesn't require another code change.
        KlondikeSolibeeItem.Content = Strings.Get(StringKey.GamemodeKlondikeDisplay, _language);
        BeecellItem.Content = Strings.Get(StringKey.GamemodeBeecellDisplay, _language);
        SpiderSolibeeItem.Content = Strings.Get(StringKey.GamemodeSpiderDisplay, _language);
        VideoPokerModeItem.Content = Strings.Get(StringKey.HelpVideopokerTitle, _language);
        VideoBlackjackItem.Content = Strings.Get(StringKey.HelpBlackjackTitle, _language);
        HoneycombModeItem.Content = Strings.Get(StringKey.AppName, _language);

        ScoreLabelText.Text = Strings.Get(StringKey.ScoreLabel, _language);
        MovesLabelText.Text = Strings.Get(StringKey.MovesLabel, _language);
        TimeLabelText.Text = Strings.Get(StringKey.TimeLabel, _language);
        HoneycombYouLabelText.Text = Strings.Get(StringKey.StatusYouLabel, _language);

        HoneycombRulesTitleText.Text = Strings.Get(StringKey.HoneycombRulesTitle, _language);

        PreferencesBackLabelText.Text = Strings.Get(StringKey.Back, _language);
        PreferencesTitleText.Text = Strings.Get(StringKey.Preferences, _language);
        ViewStatsText.Text = Strings.Get(StringKey.ViewStats, _language);
        CancelPreferencesButton.Content = Strings.Get(StringKey.Cancel, _language);
        OkPreferencesButton.Content = Strings.Get(StringKey.Ok, _language);

        ManageDecksTitleText.Text = Strings.Get(StringKey.ManageDecks, _language);
        DoneManageDecksButton.Content = Strings.Get(StringKey.Done, _language);

        StatsGamesPlayedLabel.Text = Strings.Get(StringKey.GamesPlayed, _language);
        StatsGamesWonLabel.Text = Strings.Get(StringKey.GamesWon, _language);
        StatsHighScoreLabel.Text = Strings.Get(StringKey.HighScore, _language);
        StatsWinPctLabel.Text = Strings.Get(StringKey.WinPercentage, _language);
        StatsCurrentStreakLabel.Text = Strings.Get(StringKey.CurrentStreak, _language);
        StatsLongestStreakLabel.Text = Strings.Get(StringKey.LongestStreak, _language);
        StatsAvgWinTimeLabel.Text = Strings.Get(StringKey.AvgWinningTime, _language);
        StatsFastestWinLabel.Text = Strings.Get(StringKey.FastestWin, _language);
        ResetStatsButton.Content = Strings.Get(StringKey.ResetStats, _language);
        CloseStatsButton.Content = Strings.Get(StringKey.Close, _language);
        CancelConfirmActionButton.Content = Strings.Get(StringKey.Cancel, _language);

        // Refresh whatever's currently showing in the stats overlay title/rows and the
        // solitaire key-hint row, since both are built from literals elsewhere in this file.
        if (StatsOverlay.IsVisible) PopulateStatsPanel();
        UpdateSolitaireKeyHint(_currentGameTag, _currentGameTag != "VideoPoker" && _currentGameTag != "Blackjack" && _currentGameTag != "Honeycomb");
    }

    private void ApplyFeltColor(GameOptions options)
    {
        var feltColor = options.FeltColor;
        string primaryHex = "#008000";
        string statusHex = "#007300";

        if (feltColor == FeltColorTheme.Custom)
        {
            primaryHex = options.CustomFeltColorHex;
            
            try
            {
                var color = Avalonia.Media.Color.Parse(primaryHex);
                var darkerColor = Avalonia.Media.Color.FromArgb(
                    color.A,
                    (byte)Math.Max(0, color.R * 0.85),
                    (byte)Math.Max(0, color.G * 0.85),
                    (byte)Math.Max(0, color.B * 0.85)
                );
                statusHex = darkerColor.ToString();
            }
            catch
            {
                statusHex = primaryHex;
            }
        }
        else
        {
            (primaryHex, statusHex) = feltColor switch
            {
                FeltColorTheme.FeltGreen => ("#008000", "#007300"),
                FeltColorTheme.Crimson => ("#8C0C26", "#7A071E"),
                FeltColorTheme.RoyalBlue => ("#1A3380", "#14296B"),
                FeltColorTheme.Charcoal => ("#2E2E2E", "#242424"),
                FeltColorTheme.Desert => ("#C2967A", "#B58A6E"),
                _ => ("#008000", "#007300")
            };
        }

        try
        {
            this.Background = new Avalonia.Media.SolidColorBrush(Avalonia.Media.Color.Parse(primaryHex));

            if (TopBarBorder != null)
                TopBarBorder.Background = Avalonia.Media.Brushes.Transparent;

            // Always sits behind everything (negative ZIndex) and only shows through in
            // the gaps — the title bar row never has anything opaque over it, so the
            // vignette shows there for every game. Row 1 (the board) is transparent for
            // solitaire, so it shows there too; Video Poker/Blackjack paint an opaque
            // board over it instead, which naturally hides this row-1 portion — those
            // two games render their own local vignette rectangle behind their board's
            // button rows instead (see BlackjackView/VideoPokerView).
            if (VignetteOverlay != null)
            {
                VignetteOverlay.IsVisible = options.IsVignetteEnabled;
                VignetteOverlay.ZIndex = -5;
                UpdateVignetteSizeAndIntensity(options);
            }
        }
        catch
        {
            this.Background = new Avalonia.Media.SolidColorBrush(Avalonia.Media.Colors.DarkGreen);
        }
    }

    private void UpdateVignetteSizeAndIntensity(GameOptions options)
    {
        if (VignetteOverlay == null || !VignetteOverlay.IsVisible) return;

        double w = this.Bounds.Width > 0 ? this.Bounds.Width : 1000;
        double h = this.Bounds.Height > 0 ? this.Bounds.Height : 700;
        double diagonal = Math.Sqrt(w * w + h * h);
        
        VignetteOverlay.Width = diagonal;
        VignetteOverlay.Height = diagonal;

        if (VignetteOverlay.Fill is Avalonia.Media.RadialGradientBrush rgb)
        {
            double targetRadius = 680.0 * options.VignetteScale;
            rgb.Radius = targetRadius / diagonal;

            double intensity = 0.45;
            byte alpha = (byte)(intensity * 255);

            if (rgb.GradientStops.Count > 1)
            {
                rgb.GradientStops[1].Color = Avalonia.Media.Color.FromArgb(alpha, 0, 0, 0);
            }
        }
    }

    // Offsets are stored in "reference-width" units (see BackgroundEditorWindow) so a background
    // set up at one window size looks proportionally the same after a resize — both the small
    // editor preview and this real board rescale offsets by (their own width / this constant).
    private const double BackgroundReferenceWidth = 1120.0;
    private GameOptions? _lastBoardBackgroundOptions;

    private void ApplyBoardBackground(GameOptions options)
    {
        _lastBoardBackgroundOptions = options;

        var customBg = string.IsNullOrEmpty(options.BackgroundName)
            ? null
            : options.CustomBackgrounds.Find(b => b.Name == options.BackgroundName);

        if (customBg == null || !PathSafety.IsSafeFileName(customBg.FileName))
        {
            BoardBackgroundImage.IsVisible = false;
            return;
        }

        var path = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            AppDataMigration.FolderName, "Backgrounds", customBg.FileName);

        if (!File.Exists(path))
        {
            BoardBackgroundImage.IsVisible = false;
            return;
        }

        try
        {
            BoardBackgroundImage.Source = CardView.GetCachedBackgroundBitmap(path);
            BoardBackgroundImage.IsVisible = true;
            BoardBackgroundImage.ZIndex = -10;
            ApplyBoardBackgroundTransform(options);
        }
        catch
        {
            BoardBackgroundImage.IsVisible = false;
        }
    }

    // Reads scale/offset from the live options fields (kept in sync with the matching
    // CustomBackgrounds entry by every UI mutation, and — crucially — the only copy
    // ThemeService.ApplyTheme actually updates) rather than the CustomBackground list
    // entry directly, matching how card backs are rendered (CardView reads
    // options.CardBackScale/OffsetX/OffsetY, not the CustomCardBack list entry) so a
    // theme's saved background positioning actually takes effect on the real board.
    private void ApplyBoardBackgroundTransform(GameOptions options)
    {
        double ratio = Math.Max(1.0, Width) / BackgroundReferenceWidth;
        double scale = options.BackgroundScale;
        double offsetX = options.BackgroundOffsetX * ratio;
        double offsetY = options.BackgroundOffsetY * ratio;

        BoardBackgroundImage.RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative);
        var tg = new TransformGroup();
        tg.Children.Add(new ScaleTransform(scale, scale));
        tg.Children.Add(new TranslateTransform(offsetX, offsetY));
        BoardBackgroundImage.RenderTransform = tg;
    }

    private bool IsGameInProgress()
    {
        if (this.DataContext is GameViewModel klondikeVm)
            return klondikeVm.State != null && klondikeVm.State.MovesCount > 0 && !klondikeVm.State.HasWon;
        if (this.DataContext is FreecellViewModel freecellVm)
            return freecellVm.State != null && freecellVm.State.MovesCount > 0 && !freecellVm.State.HasWon;
        if (this.DataContext is SpiderViewModel spiderVm)
            return spiderVm.State != null && spiderVm.State.MovesCount > 0 && !spiderVm.State.HasWon;
        if (this.DataContext is VideoPokerViewModel vpVm)
            return vpVm.State != null && vpVm.State.Phase == VideoPokerPhase.Holding;
        if (this.DataContext is BlackjackViewModel bjVm)
            return bjVm.State != null && bjVm.IsPlaying;
        if (this.DataContext is HoneycombViewModel hVm)
            return hVm.State != null && hVm.State.Phase == HoneycombPhase.Playing;
        return false;
    }

    private void AnimateGameReset(Action resetAction)
    {
        if (_gameSwitchTimer != null)
        {
            resetAction();
            return;
        }

        double elapsed = 0;
        bool resetDone = false;
        const double outMs = 120, inMs = 180;

        _gameSwitchTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _gameSwitchTimer.Tick += (_, _) =>
        {
            elapsed += 16;
            if (!resetDone)
            {
                double t = Math.Min(1.0, elapsed / outMs);
                MainContent.Opacity = 1.0 - t;
                if (t >= 1.0)
                {
                    resetDone = true;
                    elapsed = 0;
                    resetAction();
                }
            }
            else
            {
                double t = Math.Min(1.0, elapsed / inMs);
                MainContent.Opacity = t;
                if (t >= 1.0)
                {
                    _gameSwitchTimer!.Stop();
                    _gameSwitchTimer = null;
                    MainContent.Opacity = 1.0;
                }
            }
        };
        _gameSwitchTimer.Start();
    }

    private void ExecuteNewGame()
    {
        AnimateGameReset(() =>
        {
            if (this.DataContext is GameViewModel klondikeVm)
                klondikeVm.InitializeGame();
            else if (this.DataContext is FreecellViewModel freecellVm)
                freecellVm.InitializeGame();
            else if (this.DataContext is SpiderViewModel spiderVm)
                spiderVm.InitializeGame();
            else if (this.DataContext is VideoPokerViewModel vpVm)
                vpVm.StartNewGame();
            else if (this.DataContext is BlackjackViewModel bjVm)
                bjVm.StartNewGame();
            else if (this.DataContext is HoneycombViewModel hVm)
                hVm.InitializeGame();
        });
    }

    private void ExecuteRestartGame()
    {
        AnimateGameReset(() =>
        {
            if (this.DataContext is GameViewModel klondikeVm)
                klondikeVm.RestartGame();
            else if (this.DataContext is FreecellViewModel freecellVm)
                freecellVm.RestartGame();
            else if (this.DataContext is SpiderViewModel spiderVm)
                spiderVm.RestartGame();
            else if (this.DataContext is VideoPokerViewModel vpVm)
                vpVm.StartNewGame();
            else if (this.DataContext is BlackjackViewModel bjVm)
                bjVm.StartNewGame();
            else if (this.DataContext is HoneycombViewModel hVm)
                hVm.RestartGame();
        });
    }

    private DateTime _lastTopBarClickTime;
    private Avalonia.Point _lastTopBarClickPos;

    private void TopBar_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (!e.GetCurrentPoint(this).Properties.IsLeftButtonPressed) return;
        // Don't drag/maximize when the click originated inside an interactive control
        var src = e.Source as Avalonia.Controls.Control;
        while (src != null && src != TopBarBorder)
        {
            if (src is Button || src is ComboBox || src is ComboBoxItem) return;
            src = src.Parent as Avalonia.Controls.Control;
        }

        // Manual double-click detection: BeginMoveDrag below runs a blocking native
        // move-loop on the first click, which can desync Avalonia's own ClickCount
        // tracking for the second click. Track timing/position ourselves instead.
        var now = DateTime.UtcNow;
        var pos = e.GetPosition(this);
        double dx = pos.X - _lastTopBarClickPos.X;
        double dy = pos.Y - _lastTopBarClickPos.Y;
        bool isDoubleClick = (now - _lastTopBarClickTime) < TimeSpan.FromMilliseconds(500)
                              && (dx * dx + dy * dy) < 64;

        if (isDoubleClick)
        {
            _lastTopBarClickTime = DateTime.MinValue;
            e.Pointer.Capture(null);
            WindowState = WindowState == WindowState.Maximized
                ? WindowState.Normal
                : WindowState.Maximized;
            return;
        }

        _lastTopBarClickTime = now;
        _lastTopBarClickPos  = pos;
        // Release any implicit pointer capture before starting the native move-drag —
        // otherwise the capture can linger and swallow the next click's PointerPressed.
        e.Pointer.Capture(null);
        BeginMoveDrag(e);
    }

    private void NewGame_Click(object? sender, RoutedEventArgs e)
    {
        if (IsGameInProgress())
        {
            _pendingAction = "NewGame";
            ConfirmActionTitle.Text = "Start New Game?";
            ConfirmActionMessage.Text = "Are you sure you want to abandon the current game and start a new one?";
            ConfirmActionButton.Content = Strings.Get(StringKey.NewGame, _language);
            ConfirmActionOverlay.IsVisible = true;
        }
        else
        {
            ExecuteNewGame();
        }
    }

    private void RestartGame_Click(object? sender, RoutedEventArgs e)
    {
        if (IsGameInProgress())
        {
            _pendingAction = "RestartGame";
            ConfirmActionTitle.Text = "Restart Game?";
            ConfirmActionMessage.Text = "Are you sure you want to restart the current game?";
            ConfirmActionButton.Content = Strings.Get(StringKey.Restart, _language);
            ConfirmActionOverlay.IsVisible = true;
        }
        else
        {
            ExecuteRestartGame();
        }
    }

    private void ConfirmAction_Click(object? sender, RoutedEventArgs e)
    {
        ConfirmActionOverlay.IsVisible = false;
        if (_pendingAction == "NewGame")
        {
            ExecuteNewGame();
        }
        else if (_pendingAction == "RestartGame")
        {
            ExecuteRestartGame();
        }
        else if (_pendingAction.StartsWith("GameMode:"))
        {
            string newTag = _pendingAction.Substring("GameMode:".Length);
            _preferencesView?.CommitGameModeCombo();
            ApplyGameModeChange(newTag);
            if (_closePreferencesAfterModeConfirm)
            {
                _closePreferencesAfterModeConfirm = false;
                SlideOutAndClosePreferences();
            }
        }
        else if (_pendingAction.StartsWith("SwitchVariant:"))
        {
            int idx = int.Parse(_pendingAction.Substring("SwitchVariant:".Length));
            _variantInitializing = true;
            PokerVariantBox.SelectedIndex = idx;
            _variantInitializing = false;
            ApplyVariantSwitch((VideoPokerVariant)idx);
        }
        else if (_pendingAction == "CancelPreferences")
        {
            ExecuteCancelPreferences();
        }
        else if (_pendingAction == "ResetStats")
        {
            if (this.DataContext is GameViewModel klondikeVm) klondikeVm.ResetStats();
            else if (this.DataContext is FreecellViewModel freecellVm) freecellVm.ResetStats();
            else if (this.DataContext is SpiderViewModel spiderVm) spiderVm.ResetStats();
            else if (this.DataContext is BlackjackViewModel blackjackVm) blackjackVm.ResetStats();
            else if (this.DataContext is VideoPokerViewModel videoPokerVm) videoPokerVm.ResetStats();
            else if (this.DataContext is HoneycombViewModel hVm) hVm.ResetStats();
            PopulateStatsPanel();
        }

        _pendingAction = "";
    }

    private void CancelConfirmAction_Click(object? sender, RoutedEventArgs e)
    {
        ConfirmActionOverlay.IsVisible = false;
        if (_pendingAction.StartsWith("GameMode:"))
        {
            // The Preferences panel is still open behind this dialog (see
            // ClosePreferences_Click) — just snap the combo back, keep it open.
            _preferencesView?.RevertGameModeCombo();
            _closePreferencesAfterModeConfirm = false;
        }
        _pendingAction = "";
    }

    private void ApplyGameModeChange(string tag)
    {
        var opts = _coordinator.GameViewModel.Options;
        if (tag == "SolitaireDraw1" || tag == "SolitaireDraw3")
        {
            opts.IsDrawConstraintsEnabled = (tag == "SolitaireDraw3");
            opts.LastGameMode = tag;
            SettingsService.SaveOptions(opts);
            _coordinator.GameViewModel.InitializeGame();
            WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(opts));
        }
        else if (tag == "Freecell1" || tag == "Freecell2")
        {
            opts.FreecellDeckCount = tag == "Freecell2" ? 2 : 1;
            opts.LastGameMode = tag;
            SettingsService.SaveOptions(opts);
            _coordinator.FreecellViewModel.InitializeGame();
            WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(opts));
            // Unlike Klondike Draw1/3 and Spider's suit-count modes, a Freecell deck-count
            // change actually alters the board's own footprint (extra FreeCells+Foundations
            // row, extra tableau columns) — grow the window if it's now too small for it.
            EnsureWindowFitsBoard(tag);
        }
        else if (tag == "Spider1" || tag == "Spider2" || tag == "Spider4")
        {
            opts.SpiderSuitCount = tag switch { "Spider2" => 2, "Spider4" => 4, _ => 1 };
            opts.LastGameMode = tag;
            SettingsService.SaveOptions(opts);
            _coordinator.SpiderViewModel.InitializeGame();
            WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(opts));
        }
        _currentGameTag = tag;
        _preferencesView?.CommitGameModeCombo();
    }

    private void Undo_Click(object? sender, RoutedEventArgs e)
    {
        if (this.DataContext is GameViewModel klondikeVm)
            klondikeVm.UndoCommand.Execute(null);
        else if (this.DataContext is FreecellViewModel freecellVm)
            freecellVm.Undo();
        else if (this.DataContext is SpiderViewModel spiderVm)
            spiderVm.Undo();
        else if (this.DataContext is HoneycombViewModel hVm)
            hVm.Undo();
        // Video Poker has no undo
    }

    private void Hint_Click(object? sender, RoutedEventArgs e)
    {
        HintMove? activeHint = null;
        if (this.DataContext is GameViewModel klondikeVm)
        {
            klondikeVm.FindHint();
            activeHint = klondikeVm.ActiveHint;
        }
        else if (this.DataContext is FreecellViewModel freecellVm)
        {
            freecellVm.FindHint();
            activeHint = freecellVm.ActiveHint;
        }
        else if (this.DataContext is SpiderViewModel spiderVm)
        {
            spiderVm.FindHint();
            activeHint = spiderVm.ActiveHint;
        }
        else if (this.DataContext is HoneycombViewModel honeycombVm)
        {
            honeycombVm.FindHint();
            // Honeycomb hint always falls back to random, never shows unavailable toast
        }
        // Video Poker has no hint

        if (activeHint?.Card.Id == "no_move" && MainContent.Content is CardGameView gameView)
            gameView.FlashHintUnavailable();
    }

    private void ShowStatsPanel()
    {
        PopulateStatsPanel();
        StatsOverlay.IsVisible = true;
    }

    private void CloseStats_Click(object? sender, RoutedEventArgs e)
    {
        StatsOverlay.IsVisible = false;
    }

    private void ResetStats_Click(object? sender, RoutedEventArgs e)
    {
        _pendingAction = "ResetStats";
        ConfirmActionTitle.Text     = Strings.Get(StringKey.ResetStatisticsTitle, _language);
        ConfirmActionMessage.Text   = Strings.Get(StringKey.ResetStatisticsBodyGeneric, _language);
        ConfirmActionButton.Content = Strings.Get(StringKey.Reset, _language);
        ConfirmActionOverlay.IsVisible = true;
    }

    private static string FormatKlondikeScore(int rawScore, bool vegas)
    {
        if (!vegas) return rawScore.ToString();
        int dollars = rawScore / 100;
        int abs     = Math.Abs(dollars);
        return dollars < 0 ? $"-${abs}.00" : $"${abs}.00";
    }

    private static readonly SolidColorBrush _statRowForeground = new(Color.Parse("#1A1A1A"));

    private static Grid BuildStatRow(string label, string value)
    {
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        grid.Children.Add(new TextBlock { Text = label, Foreground = _statRowForeground });
        var valueBlock = new TextBlock { Text = value, Foreground = _statRowForeground, FontWeight = FontWeight.Bold };
        Grid.SetColumn(valueBlock, 1);
        grid.Children.Add(valueBlock);
        return grid;
    }

    private void PopulateBlackjackStats(BlackjackViewModel vm)
    {
        StatsFixedRows.IsVisible   = false;
        StatsDynamicRows.IsVisible = true;
        StatsDynamicRowsCol2.IsVisible = false;
        StatsPanelRoot.Width = 300;
        StatsTitleText.Text = Strings.Get(StringKey.BlackjackStatistics, _language);

        var s = vm.Stats;
        double winRate = s.HandsPlayed > 0 ? 100.0 * s.HandsWon / s.HandsPlayed : 0.0;
        double rtp     = s.TotalCreditsWagered > 0 ? 100.0 * s.TotalCreditsWon / s.TotalCreditsWagered : 0.0;

        StatsDynamicRowsCol1.Children.Clear();
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.HandsPlayed, _language),  s.HandsPlayed.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.HandsWon, _language),     s.HandsWon.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatHandsLost, _language),    s.HandsLost.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatPushes, _language),        s.HandsPushed.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatBlackjacks, _language),    s.Blackjacks.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.WinRate, _language),      $"{winRate:0.0}%"));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.TotalWagered, _language), s.TotalCreditsWagered.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.TotalPaid, _language),    s.TotalCreditsWon.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.BiggestPay, _language),   s.BiggestPay.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.RtpStat, _language),           $"{rtp:0.0}%"));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.RebuysStat, _language),        s.Rebuys.ToString()));
    }

    private void PopulateVideoPokerStats(VideoPokerViewModel vm)
    {
        StatsFixedRows.IsVisible   = false;
        StatsDynamicRows.IsVisible = true;
        StatsDynamicRowsCol2.IsVisible = false;
        StatsPanelRoot.Width = 300;
        StatsTitleText.Text = Strings.Get(StringKey.VideoPokerStatistics, _language);

        var s = vm.Stats;
        double winRate      = s.TotalHands > 0 ? 100.0 * s.WinningHands / s.TotalHands : 0.0;
        double rtp          = s.TotalCreditsWagered > 0 ? 100.0 * s.TotalCreditsWon / s.TotalCreditsWagered : 0.0;
        int    royalFlushes = s.RoyalFlushCount;

        StatsDynamicRowsCol1.Children.Clear();
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.HandsPlayed, _language),   s.TotalHands.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.HandsWon, _language),      s.WinningHands.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.WinRate, _language),       $"{winRate:0.0}%"));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.BiggestPay, _language),    s.BiggestPay.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.TotalWagered, _language),  s.TotalCreditsWagered.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.TotalPaid, _language),     s.TotalCreditsWon.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.RtpStat, _language),            $"{rtp:0.0}%"));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.RoyalFlushes, _language),  royalFlushes.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.RebuysStat, _language),         s.Rebuys.ToString()));
    }

    // Formats "%d/%d (%@)" (StatCardsUnlockedValueFmt) by replacing each placeholder
    // occurrence in order — same technique as ManageDecksView's CardBankCountFmt
    // handling, since a blanket .Replace("%d", ...) can't put two different numbers
    // into two identical tokens.
    private static string FormatCardsUnlockedValue(string fmt, int unlocked, int total, string percentText)
    {
        int firstD = fmt.IndexOf("%d", StringComparison.Ordinal);
        fmt = fmt.Remove(firstD, 2).Insert(firstD, unlocked.ToString());
        int secondD = fmt.IndexOf("%d", firstD, StringComparison.Ordinal);
        fmt = fmt.Remove(secondD, 2).Insert(secondD, total.ToString());
        return fmt.Replace("%@", percentText);
    }

    private static Avalonia.Controls.Shapes.Rectangle BuildStatsDivider() => new()
    {
        Height = 1,
        Fill = new SolidColorBrush(Color.Parse("#DDDDDD")),
        Margin = new Avalonia.Thickness(0, 4)
    };

    // Mirrors Mac's HoneycombStatsView field-for-field (same HoneycombStats model,
    // shared/Honeycomb/Models/HoneycombStats.swift) — same rows, same order, same
    // labels/keys, including the computed Win Rate and the card-collection section
    // (per-suit/per-star unlock progress), so the two platforms report identical
    // numbers for identical play. Suit names route through
    // HoneycombCardData.LocalizedSuitName instead of Mac's hardcoded English suit
    // labels — an improvement (the counts still match), not a deviation.
    private void PopulateHoneycombStats(HoneycombViewModel vm)
    {
        StatsFixedRows.IsVisible   = false;
        StatsDynamicRows.IsVisible = true;
        StatsDynamicRowsCol2.IsVisible = true;
        // Two columns — Col1 is match/streak/gameplay stats, Col2 is card-collection
        // progress — instead of one long single column, which stretched this popup
        // much taller than every other game's stats panel.
        StatsPanelRoot.Width = 620;
        StatsTitleText.Text = Strings.Get(StringKey.HoneycombStatistics, _language);

        var s = vm.Stats;
        int decisiveGames = s.GamesPlayed - s.MatchesDrawn;
        double winRate = decisiveGames > 0 ? 100.0 * s.MatchesWon / decisiveGames : 0.0;

        StatsDynamicRowsCol1.Children.Clear();
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.GamesPlayed, _language),            s.GamesPlayed.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatMatchesWon, _language),         s.MatchesWon.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatMatchesLost, _language),        s.MatchesLost.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatMatchesDrawn, _language),       s.MatchesDrawn.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatSwarmsToDeath, _language),      s.SuddenDeathCount.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.WinRate, _language),                $"{winRate:0.0}%"));

        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatCurrentWinStreak, _language),       s.CurrentWinStreak.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatLongestWinStreak, _language),       s.LongestWinStreak.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatFlawlessVictoriesMac, _language),   s.FlawlessVictories.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatBabyBeeWins, _language),         s.EasyWins.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatHoneyBeeWins, _language),        s.MediumWins.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatQueenBeeWins, _language),        s.HardWins.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatKillerBeeWins, _language),       s.UltraHardWins.ToString()));

        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatTotalCardsFlipped, _language),   s.CardsCaptured.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatQueensFalls, _language),         s.FallenAces.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatHiveMindsTriggered, _language),  s.SamePlusTriggers.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatCardsStolen, _language),         s.CardsStolen.ToString()));
        StatsDynamicRowsCol1.Children.Add(BuildStatRow(Strings.Get(StringKey.StatTimesStartedOver, _language),    s.TimesStartedOver.ToString()));

        StatsDynamicRowsCol2.Children.Clear();

        var allCards = HoneycombDatabase.Shared.AllCards;
        var unlockedIds = HoneycombProfileManager.Shared.UnlockedCardIds;
        int totalUnlocked = unlockedIds.Count;
        int totalCards = allCards.Count;
        double unlockedPercent = totalCards > 0 ? 100.0 * totalUnlocked / totalCards : 0.0;
        string unlockedValue = FormatCardsUnlockedValue(
            Strings.Get(StringKey.StatCardsUnlockedValueFmt, _language), totalUnlocked, totalCards, $"{unlockedPercent:0}%");
        StatsDynamicRowsCol2.Children.Add(BuildStatRow(Strings.Get(StringKey.StatCardsUnlockedLabel, _language), unlockedValue));

        var suitCodes = new[] { "S", "H", "D", "C" };
        foreach (var suitCode in suitCodes)
        {
            var suitCards = allCards.Where(c => c.Suit == suitCode).ToList();
            int suitUnlocked = suitCards.Count(c => unlockedIds.Contains(c.Id));
            string suitLabel = Strings.Get(StringKey.StatSuitUnlockedFmt, _language).Replace("%@", HoneycombCardData.LocalizedSuitName(suitCode, _language));
            StatsDynamicRowsCol2.Children.Add(BuildStatRow(suitLabel, $"{suitUnlocked}/{suitCards.Count}"));
        }

        StatsDynamicRowsCol2.Children.Add(BuildStatsDivider());

        for (int star = 1; star <= 5; star++)
        {
            var starCards = allCards.Where(c => c.Stars == star).ToList();
            int starUnlocked = starCards.Count(c => unlockedIds.Contains(c.Id));
            string starLabel = Strings.Get(StringKey.StatStarUnlockedFmt, _language).Replace("%d", star.ToString());
            StatsDynamicRowsCol2.Children.Add(BuildStatRow(starLabel, $"{starUnlocked}/{starCards.Count}"));
        }
    }

    private void PopulateStatsPanel()
    {
        if (this.DataContext is BlackjackViewModel blackjackVm)
        {
            PopulateBlackjackStats(blackjackVm);
            return;
        }
        if (this.DataContext is VideoPokerViewModel videoPokerVm)
        {
            PopulateVideoPokerStats(videoPokerVm);
            return;
        }
        if (this.DataContext is HoneycombViewModel hVm)
        {
            PopulateHoneycombStats(hVm);
            return;
        }

        StatsFixedRows.IsVisible   = true;
        StatsDynamicRows.IsVisible = false;
        StatsPanelRoot.Width = 300;

        string title;
        int gamesPlayed, gamesWon, timedGamesWon, currentStreak, longestStreak, fastestWinSec, totalWinSec;
        string highScoreText;

        if (this.DataContext is GameViewModel klondikeVm)
        {
            title = Strings.Get(StringKey.KlondikeStatisticsTitle, _language);
            var s = klondikeVm.Stats;
            gamesPlayed   = s.GamesPlayed;
            gamesWon      = s.GamesWon;
            timedGamesWon = gamesWon;
            currentStreak = s.CurrentStreak;
            longestStreak = s.LongestStreak;
            fastestWinSec = s.ShortestWinSeconds;
            totalWinSec   = s.TotalWinSeconds;
            highScoreText = FormatKlondikeScore(
                klondikeVm.Options.IsVegasScoring ? s.VegasHighScore : s.StandardHighScore,
                klondikeVm.Options.IsVegasScoring);
        }
        else if (this.DataContext is FreecellViewModel freecellVm)
        {
            string deckLabel = freecellVm.Options.FreecellDeckCount == 2
                ? Strings.Get(StringKey.DeckCount2, _language)
                : Strings.Get(StringKey.DeckCount1, _language);
            title = Strings.Get(StringKey.FreecellStatisticsFmt, _language).Replace("%@", deckLabel);
            // Freecell has no Vegas mode of its own — always the "standard" bucket (see FreecellViewModel.ModeKey).
            string modeKey = $"standard_{freecellVm.Options.FreecellDeckCount}deck";
            var ms = freecellVm.Stats.FreecellStatsByMode.TryGetValue(modeKey, out var m) ? m : new ModeStats();
            gamesPlayed   = ms.GamesPlayed;
            gamesWon      = ms.GamesWon;
            timedGamesWon = gamesWon;
            currentStreak = ms.CurrentStreak;
            longestStreak = ms.LongestStreak;
            fastestWinSec = ms.ShortestWinSeconds;
            totalWinSec   = ms.TotalWinSeconds;
            highScoreText = ms.HighScore.ToString();
        }
        else if (this.DataContext is SpiderViewModel spiderVm)
        {
            int suitCount = spiderVm.Options.SpiderSuitCount;
            string suitWord = suitCount == 1
                ? Strings.Get(StringKey.LabelSuitSingular, _language)
                : Strings.Get(StringKey.LabelSuitPlural, _language);
            title = Strings.Get(StringKey.SpiderStatisticsFmt, _language)
                .Replace("%d", suitCount.ToString())
                .Replace("%@", suitWord);
            string suitKey = spiderVm.Options.SpiderSuitCount.ToString();
            var ms = spiderVm.Stats.SpiderStatsBySuit.TryGetValue(suitKey, out var m) ? m : new ModeStats();
            gamesPlayed   = ms.GamesPlayed;
            gamesWon      = ms.GamesWon;
            timedGamesWon = ms.TimedGamesWon;
            currentStreak = ms.CurrentStreak;
            longestStreak = ms.LongestStreak;
            fastestWinSec = ms.ShortestWinSeconds;
            totalWinSec   = ms.TotalWinSeconds;
            // Spider has no Vegas mode of its own (see SpiderViewModel.ScoreDisplay) —
            // always the plain score.
            highScoreText = ms.HighScore.ToString();
        }
        else
        {
            return; // Video Poker / Blackjack have no stats panel
        }

        StatsTitleText.Text        = title;
        StatsGamesPlayedText.Text  = gamesPlayed.ToString();
        StatsGamesWonText.Text     = gamesWon.ToString();
        StatsHighScoreText.Text    = highScoreText;
        double winPct = gamesPlayed > 0 ? 100.0 * gamesWon / gamesPlayed : 0.0;
        StatsWinPctText.Text       = $"{winPct:0.0}%";
        StatsCurrentStreakText.Text = currentStreak.ToString();
        StatsLongestStreakText.Text = longestStreak.ToString();
        StatsAvgWinTimeText.Text   = timedGamesWon > 0 ? $"{totalWinSec / timedGamesWon}s" : Strings.Get(StringKey.NoTimePlaceholder, _language);
        StatsFastestWinText.Text  = timedGamesWon > 0 ? $"{fastestWinSec}s" : Strings.Get(StringKey.NoTimePlaceholder, _language);
    }

    private void SetupHoneycombMode()
    {
        HoneycombStartMatchButton.IsVisible  = true;
        HoneycombManageDecksButton.IsVisible = true;
        HoneycombQuitMatchButton.IsVisible   = true;
        HoneycombRulesButton.IsVisible       = true;
    }

    private void SetupNormalMode()
    {
        HoneycombStartMatchButton.IsVisible  = false;
        HoneycombRematchButton.IsVisible     = false;
        HoneycombManageDecksButton.IsVisible = false;
        HoneycombQuitMatchButton.IsVisible   = false;
        HoneycombRulesButton.IsVisible       = false;
    }

    private void HoneycombRules_Click(object? sender, RoutedEventArgs e)
    {
        if (this.DataContext is HoneycombViewModel hVm)
        {
            this.TopBarBorder.IsEnabled = false;
            HoneycombRulesViewControl.Initialize(hVm);
            
            EventHandler<bool>? closeHandler = null;
            closeHandler = (s, result) =>
            {
                HoneycombRulesViewControl.OnCloseRequested -= closeHandler;
                this.HoneycombRulesOverlay.IsVisible = false;
                this.TopBarBorder.IsEnabled = true;
            };
            
            HoneycombRulesViewControl.OnCloseRequested += closeHandler;
            this.HoneycombRulesOverlay.IsVisible = true;
        }
    }

    private void Preferences_Click(object? sender, RoutedEventArgs e)
    {
        _preferencesView = new PreferencesView();
        PreferencesBackButton.IsVisible = false;
        _preferencesView.SubPanelVisibilityChanged += (_, _) =>
            PreferencesBackButton.IsVisible = _preferencesView?.IsSubPanelOpen ?? false;

        if (this.DataContext is VideoPokerViewModel vpVm)
        {
            // Video Poker's Options has a single consumer (this ViewModel), unlike the
            // card games' shared GameOptions/OptionsChangedMessage broadcast — so there's
            // no old-vs-new diffing to break by sharing the live instance directly.
            // PreferencesView calls vpVm.SaveOptions() to persist and refresh the view.
            _preferencesView.DataContext = vpVm.Options;
            _preferencesView.VideoPokerVm = vpVm;
            _preferencesView.ActiveGameFamily = "VideoPoker";
        }
        else if (this.DataContext is BlackjackViewModel bjVm)
        {
            // Same shape as Video Poker above — Blackjack's Options is its own
            // single-consumer model, not the card games' shared GameOptions.
            _preferencesView.DataContext = bjVm.Options;
            _preferencesView.BlackjackVm = bjVm;
            _preferencesView.ActiveGameFamily = "Blackjack";
        }
        else
        {
            GameOptions options = this.DataContext switch
            {
                GameViewModel vm      => vm.Options,
                FreecellViewModel vm  => vm.Options,
                SpiderViewModel vm    => vm.Options,
                HoneycombViewModel vm => _coordinator.GameViewModel.Options,
                _                     => _coordinator.GameViewModel.Options
            };
            // Clone, don't share the live instance
            _preferencesView.DataContext = options.Clone();
            _preferencesView.ActiveGameFamily = this.DataContext switch
            {
                GameViewModel _      => "Klondike",
                FreecellViewModel _  => "Freecell",
                SpiderViewModel _    => "Spider",
                HoneycombViewModel _ => "Honeycomb",
                _                    => "",
            };
            
            if (this.DataContext is HoneycombViewModel hVm)
            {
                _preferencesView.HoneycombOptions = hVm.Options;
            }
        }

        _preferencesView.ShowVegasOption = this.DataContext is GameViewModel;
        this.PreferencesContent.Content = _preferencesView;
        this.PreferencesOverlay.IsVisible = true;
        // The overlay only covers the game area (Grid.Row="1"), not the toolbar
        // (its own Grid.Row="0" with ZIndex="100"), so toolbar buttons stay
        // clickable underneath unless explicitly disabled here.
        this.TopBarBorder.IsEnabled = false;
        SlideInPreferences();
    }

    private void SlideInPreferences()
    {
        // Just appear centered — PreferencesPanel is already Horizontal/VerticalAlignment="Center".
        PreferencesPanel.RenderTransform = null;
    }

    private void SlideOutAndClosePreferences()
    {
        this.PreferencesOverlay.IsVisible = false;
        this.PreferencesContent.Content   = null;
        this.TopBarBorder.IsEnabled = true;
    }

    private void ManageDecks_Click(object? sender, RoutedEventArgs e)
    {
        _manageDecksView = new ManageDecksView();
        _manageDecksView.OnRequestDeckBuilder += (slotIndex) => {
            var deckBuilder = new DeckBuilderView(slotIndex);
            deckBuilder.OnDismiss += () => {
                this.DeckBuilderOverlay.IsVisible = false;
                this.DeckBuilderContent.Content = null;
                _manageDecksView?.RefreshUI();
            };
            this.DeckBuilderContent.Content = deckBuilder;
            this.DeckBuilderOverlay.IsVisible = true;
        };
        this.ManageDecksContent.Content = _manageDecksView;
        this.ManageDecksOverlay.IsVisible = true;
        this.TopBarBorder.IsEnabled = false;
    }

    private void CloseManageDecks_Click(object? sender, RoutedEventArgs e)
    {
        var pm = HoneycombProfileManager.Shared;
        var opts = SettingsService.LoadOptions();
        
        // Ensure active deck is valid, otherwise fallback
        var activeDeck = pm.SavedDecks[opts.HoneycombActiveDeckIndex];
        if (activeDeck.CardIds.Count != 5)
        {
            opts.HoneycombActiveDeckIndex = 0;
            activeDeck = pm.SavedDecks[0];
        }
        
        opts.PlayerDeckIds = new List<int>(activeDeck.CardIds);
        SettingsService.SaveOptions(opts);

        this.ManageDecksOverlay.IsVisible = false;
        this.ManageDecksContent.Content = null;
        this.TopBarBorder.IsEnabled = true;
        _manageDecksView = null;
        
        // Refresh Honeycomb View in case decks were changed
        if (this.DataContext is HoneycombViewModel hVm)
        {
            if (MainContent.Content is HoneycombView hv)
            {
                hv.Refresh(hVm);
            }
        }
    }

    private void Help_Click(object? sender, RoutedEventArgs e)
    {
        if (_helpWindow != null) { _helpWindow.Activate(); return; }
        _helpWindow = new HelpWindow();
        _helpWindow.Closed += (_, _) => _helpWindow = null;
        _helpWindow.Show(this);
    }

    private void Exit_Click(object? sender, RoutedEventArgs e)
    {
        Close();
    }

    private void About_Click(object? sender, RoutedEventArgs e)
    {
        var about = new AboutWindow();
        about.Show(this);
    }

    private void ThemeEditor_Click(object? sender, RoutedEventArgs e)
    {
        if (_themeEditor != null)
        {
            _themeEditor.Activate();
            return;
        }
        _themeEditor = new ThemeEditorWindow();
        _themeEditor.Closed += (_, _) => _themeEditor = null;
        _themeEditor.Show();
    }

    private void PreferencesBackButton_Click(object? sender, RoutedEventArgs e)
    {
        _preferencesView?.GoBack();
    }

    private void ClosePreferences_Click(object? sender, RoutedEventArgs e)
    {
        // The game-mode dropdown (Draw 1/3, deck/suit count) only records the pending
        // selection live — actually applying it (and confirming abandonment of an
        // in-progress game, if needed) is deferred until OK is clicked here, so picking
        // a different mode while browsing Preferences doesn't itself trigger a reset.
        if (_preferencesView != null && _preferencesView.TryGetPendingGameModeChange(out string? newTag))
        {
            if (!IsGameInProgress())
            {
                _preferencesView.CommitGameModeCombo();
                ApplyGameModeChange(newTag!);
                SlideOutAndClosePreferences();
            }
            else
            {
                _closePreferencesAfterModeConfirm = true;
                _pendingAction = "GameMode:" + newTag;
                ConfirmActionTitle.Text     = "Change Game Mode?";
                ConfirmActionMessage.Text   = "Are you sure you want to abandon the current game and change mode?";
                ConfirmActionButton.Content = "Change Mode";
                ConfirmActionOverlay.IsVisible = true;
            }
            return;
        }

        // Blackjack/VideoPoker/Honeycomb are the only games where No Stress Mode doesn't
        // already apply live (a Blackjack/VideoPoker hand can't retroactively become free
        // play, and Honeycomb's deck composition is only decided at match start) — so
        // enabling it while one of those is in progress silently ends it and deals fresh,
        // no confirmation. Klondike/Freecell/Spider apply it live with no reset needed.
        if (_preferencesView != null && _preferencesView.DidEnableNoStressMode() && IsGameInProgress()
            && (this.DataContext is BlackjackViewModel || this.DataContext is VideoPokerViewModel || this.DataContext is HoneycombViewModel))
        {
            ExecuteNewGame();
        }

        SlideOutAndClosePreferences();
    }

    // Discards any pending (unconfirmed) game-mode selection and restores whatever
    // options were on disk when the panel opened — every other control here saves
    // live as you change it (see PreferencesView.RevertSettingsChanges), so "cancel"
    // means writing that snapshot back over the session's live edits, not skipping
    // an apply step. If anything was actually changed during this session, confirm
    // first since those live-saved edits are about to be thrown away.
    private void CancelPreferences_Click(object? sender, RoutedEventArgs e)
    {
        if (_preferencesView != null && _preferencesView.HasPendingChanges())
        {
            _pendingAction = "CancelPreferences";
            ConfirmActionTitle.Text     = "Discard Changes?";
            ConfirmActionMessage.Text   = "You have pending changes which will be lost. Are you sure you want to cancel?";
            ConfirmActionButton.Content = Strings.Get(StringKey.Yes, _language);
            ConfirmActionOverlay.IsVisible = true;
            return;
        }
        ExecuteCancelPreferences();
    }

    private void ExecuteCancelPreferences()
    {
        _preferencesView?.RevertGameModeCombo();
        _preferencesView?.RevertSettingsChanges();
        SlideOutAndClosePreferences();
    }

    private void ViewStats_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        SlideOutAndClosePreferences();
        var timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(150) };
        timer.Tick += (_, _) =>
        {
            timer.Stop();
            ShowStatsPanel();
        };
        timer.Start();
    }

    private void PokerVariantBox_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (_variantInitializing) return;
        if (PokerVariantBox.SelectedIndex < 0) return;
        var variant = (VideoPokerVariant)PokerVariantBox.SelectedIndex;

        var vpVm = _coordinator.VideoPokerViewModel;
        if (vpVm.State != null && vpVm.State.Phase == VideoPokerPhase.Holding)
        {
            // A hand is in progress (dealt but not yet drawn) — switching variants here
            // calls StartNewGame(), which silently resets SessionCredits back to
            // Options.StartingCredits and discards the wagered bet with no confirmation.
            // Snap the box back and ask first, same as every other game-abandoning action.
            int currentIndex = (int)vpVm.Options.Variant;
            _variantInitializing = true;
            PokerVariantBox.SelectedIndex = currentIndex;
            _variantInitializing = false;

            _pendingAction = "SwitchVariant:" + (int)variant;
            ConfirmActionTitle.Text     = "Switch Variant?";
            ConfirmActionMessage.Text   = "Are you sure you want to abandon the current hand and switch variants?";
            ConfirmActionButton.Content = "Switch Variant";
            ConfirmActionOverlay.IsVisible = true;
            return;
        }

        ApplyVariantSwitch(variant);
    }

    private void ApplyVariantSwitch(VideoPokerVariant variant)
    {
        _coordinator.VideoPokerViewModel.SetVariant(variant);
        if (MainContent.Content is VideoPokerView vpView)
            vpView.OnVariantChanged();
    }

    private static string GetBaseGameTag(string tag)
    {
        if (tag == "SolitaireDraw1" || tag == "SolitaireDraw3") return "Klondike";
        if (tag == "Freecell1" || tag == "Freecell2") return "Freecell";
        if (tag == "Spider1" || tag == "Spider2" || tag == "Spider4") return "Spider";
        return tag;
    }

    private static int GameModeToIndex(string tag) => tag switch
    {
        "SolitaireDraw1" or "SolitaireDraw3" or "Klondike" => 0,
        "Freecell1"  or "Freecell2"  or "Freecell"         => 1,
        "Spider1"    or "Spider2"    or "Spider4" or "Spider" => 2,
        "VideoPoker"                                        => 3,
        "Blackjack"                                         => 4,
        "Honeycomb"                                         => 5,
        _                                                   => 0,
    };

    private void GameSelectionBox_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (GameSelectionBox == null || _coordinator == null || _revertingSelection) return;
        if (GameSelectionBox.SelectedItem is not ComboBoxItem item || item.Tag == null) return;

        var baseTag = item.Tag.ToString() ?? "Klondike";
        // Expand base game name to the last-used mode tag for that game
        var opts = _coordinator.GameViewModel.Options;
        var tag = baseTag switch
        {
            "Klondike" => opts.IsDrawConstraintsEnabled ? "SolitaireDraw3" : "SolitaireDraw1",
            "Freecell" => opts.FreecellDeckCount == 2 ? "Freecell2" : "Freecell1",
            "Spider"   => opts.SpiderSuitCount switch { 2 => "Spider2", 4 => "Spider4", _ => "Spider1" },
            _          => baseTag,
        };

        SaveCurrentWindowSize();
        _currentGameTag = tag;

        // No existing content → switch immediately (first load, no flash)
        if (MainContent.Content == null)
        {
            ApplyGameSwitch(tag);
            return;
        }

        _gameSwitchTimer?.Stop();
        double elapsed = 0;
        bool switched  = false;
        const double outMs = 150, inMs = 200;

        _gameSwitchTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _gameSwitchTimer.Tick += (_, _) =>
        {
            elapsed += 16;
            if (!switched)
            {
                double t = Math.Min(1.0, elapsed / outMs);
                MainContent.Opacity = 1.0 - t;
                if (t >= 1.0) { switched = true; elapsed = 0; ApplyGameSwitch(tag); }
            }
            else
            {
                double t = Math.Min(1.0, elapsed / inMs);
                MainContent.Opacity = t;
                if (t >= 1.0)
                {
                    _gameSwitchTimer!.Stop();
                    _gameSwitchTimer = null;
                    MainContent.Opacity = 1.0;
                }
            }
        };
        _gameSwitchTimer.Start();
    }

    private void ApplyGameSwitch(string tag)
    {
        string cacheKey;

        if (tag == "SolitaireDraw1" || tag == "SolitaireDraw3")
        {
            cacheKey = "Game";
            bool wantDrawThree = (tag == "SolitaireDraw3");
            if (_coordinator.GameViewModel.Options.IsDrawConstraintsEnabled != wantDrawThree)
            {
                _coordinator.GameViewModel.Options.IsDrawConstraintsEnabled = wantDrawThree;
                SettingsService.SaveOptions(_coordinator.GameViewModel.Options);
                try { _coordinator.GameViewModel.InitializeGame(); }
                catch (Exception ex) { CrashLogger.Log(ex, "ApplyGameSwitch(Klondike).InitializeGame"); }
            }
            _coordinator.SwitchToGame();
        }
        else if (tag == "Freecell1" || tag == "Freecell2")
        {
            cacheKey = "Freecell";
            int deckCount = tag == "Freecell2" ? 2 : 1;
            var opts = _coordinator.GameViewModel.Options;
            if (opts.FreecellDeckCount != deckCount)
            {
                opts.FreecellDeckCount = deckCount;
                SettingsService.SaveOptions(opts);
                try { _coordinator.FreecellViewModel.InitializeGame(); }
                catch (Exception ex) { CrashLogger.Log(ex, "ApplyGameSwitch(Freecell).InitializeGame"); }
            }
            _coordinator.SwitchToFreecell();
        }
        else if (tag == "Spider1" || tag == "Spider2" || tag == "Spider4")
        {
            cacheKey = "Spider";
            int suitCount = tag switch
            {
                "Spider2" => 2,
                "Spider4" => 4,
                _ => 1
            };
            var opts = _coordinator.GameViewModel.Options;
            if (opts.SpiderSuitCount != suitCount)
            {
                opts.SpiderSuitCount = suitCount;
                SettingsService.SaveOptions(opts);
                try { _coordinator.SpiderViewModel.InitializeGame(); }
                catch (Exception ex) { CrashLogger.Log(ex, "ApplyGameSwitch(Spider).InitializeGame"); }
            }
            _coordinator.SwitchToSpider();
        }
        else if (tag == "VideoPoker")
        {
            cacheKey = "VideoPoker";
            _coordinator.SwitchToVideoPoker();
        }
        else if (tag == "Blackjack")
        {
            cacheKey = "Blackjack";
            _coordinator.SwitchToBlackjack();
        }
        else if (tag == "Honeycomb")
        {
            cacheKey = "Honeycomb";
            _coordinator.SwitchToHoneycomb();
        }
        else
        {
            return;
        }

        bool isNewView = !_cachedViews.TryGetValue(cacheKey, out var activeView);
        if (isNewView)
        {
            // A view's construction/binding pass (not just the InitializeGame() calls
            // above) is exactly where a half-initialized State from a caught
            // InitializeGame() failure would surface as a second exception — guard it
            // too, and bail out leaving whatever was on screen before rather than
            // crash the whole app on a broken new view.
            try
            {
                activeView = cacheKey switch
                {
                    "Game" => new GameView { DataContext = _coordinator.GameViewModel },
                    "Freecell" => new FreecellView { DataContext = _coordinator.FreecellViewModel },
                    "Spider" => new SpiderView { DataContext = _coordinator.SpiderViewModel },
                    "VideoPoker" => new VideoPokerView { DataContext = _coordinator.VideoPokerViewModel },
                    "Blackjack" => new BlackjackView { DataContext = _coordinator.BlackjackViewModel },
                    "Honeycomb" => new HoneycombView { DataContext = _coordinator.HoneycombViewModel },
                    _ => throw new InvalidOperationException($"Unhandled cache key: {cacheKey}")
                };
            }
            catch (Exception ex)
            {
                CrashLogger.Log(ex, $"ApplyGameSwitch({cacheKey}).ConstructView");
                return;
            }
            _cachedViews[cacheKey] = activeView;
        }
        this.MainContent.Content = activeView;

        // Blackjack/VideoPoker (and likely the others) populate their card visuals from
        // their own Loaded handler, not synchronously on construction — DealerCardsPanel /
        // PlayerHandsContainer etc. start out with zero children. If UpdateResponsiveLayout
        // measures MainContent before that Loaded fires (which it did in the fast, no-fade
        // first-launch switch below, before the fade-transition switch had time to let a
        // few frames pass), it captures an undersized "natural" height — no card row yet —
        // and computes too large a scale from it, which nothing then corrects since the
        // window's own size doesn't change again once the cards actually appear. Re-run the
        // calc once that view's Loaded fires so it measures the fully-populated board.
        // Only wired up the first time a view enters the cache — Loaded fires on every
        // reattach, so subscribing unconditionally here would stack a duplicate handler
        // onto the same cached instance on every subsequent switch back to this game.
        if (isNewView && activeView is Control newView)
            newView.Loaded += (_, _) => UpdateResponsiveLayout();

        this.DataContext = _coordinator.ActiveViewModel;
        RestoreWindowSizeForGame(tag);
        // RestoreWindowSizeForGame is the authoritative final size for this game switch,
        // but setting Window.Width/Height doesn't update this.Bounds synchronously — the
        // platform applies the resize asynchronously, and Bounds (and the SizeChanged that
        // OnWindowSizeChanged listens for) only reflect it after the next layout pass. A
        // synchronous UpdateResponsiveLayout() call here would still read the *old* Bounds
        // and scale the board for the previous game's window size, which is exactly what
        // made Blackjack look "zoomed in" until the user grabbed the resize handle (an OS
        // resize that *does* update Bounds immediately). SettleResponsiveLayout retries
        // until it stabilizes instead of a single deferred call, since even a Loaded-
        // priority deferral hasn't proven reliable enough on its own (see its own comment).
        SettleResponsiveLayout();

        // Re-point the hint-availability tracker at whichever viewmodel is now active,
        // so the Hint button disables itself the moment a deadlock leaves no legal moves.
        if (_hintTrackedVm != null) _hintTrackedVm.PropertyChanged -= OnHintTrackedVmPropertyChanged;
        _hintTrackedVm = _coordinator.ActiveViewModel as INotifyPropertyChanged;
        if (_hintTrackedVm != null) _hintTrackedVm.PropertyChanged += OnHintTrackedVmPropertyChanged;
        UpdateHintButtonEnabled();

        bool isCardGame = tag != "VideoPoker" && tag != "Blackjack" && tag != "Honeycomb";
        UpdateSolitaireKeyHint(tag, isCardGame);
        // Hint is solitaire-only (no hint logic exists for VP/Blackjack/Honeycomb).
        if (HintButton != null)    HintButton.IsVisible    = isCardGame && !_coordinator.GameViewModel.Options.HideHintButton || tag == "Honeycomb";
        if (UndoButton != null)    UndoButton.IsVisible    = isCardGame || tag == "Honeycomb";
        if (TimeStatPanel != null)  TimeStatPanel.IsVisible  = isCardGame && !_coordinator.GameViewModel.Options.IsNoStressMode;
        if (ScoreStatPanel != null) ScoreStatPanel.IsVisible = isCardGame && tag != "Honeycomb" && !_coordinator.GameViewModel.Options.IsNoStressMode;
        if (MovesStatPanel != null) MovesStatPanel.IsVisible = isCardGame && tag != "Honeycomb" && !_coordinator.GameViewModel.Options.IsNoStressMode;
        if (RestartButton != null) RestartButton.IsVisible = isCardGame;
        if (NewGameButton != null) NewGameButton.IsVisible = tag != "Honeycomb" && tag != "Blackjack" && tag != "VideoPoker";
        if (StatsBarPanel != null) StatsBarPanel.IsVisible = isCardGame || tag == "Honeycomb";
        var hcYou = this.FindControl<StackPanel>("HoneycombYouStatPanel");
        var hcOpp = this.FindControl<StackPanel>("HoneycombOpponentStatPanel");
        if (hcYou != null) hcYou.IsVisible = tag == "Honeycomb";
        if (hcOpp != null) hcOpp.IsVisible = tag == "Honeycomb";
        if (tag == "Honeycomb")
        {
            SetupHoneycombMode();
            UpdateHoneycombButtons();
        }
        else
        {
            SetupNormalMode();
            if (HoneycombStartMatchButton != null) HoneycombStartMatchButton.IsVisible = false;
            if (HoneycombRematchButton != null) HoneycombRematchButton.IsVisible = false;
            if (HoneycombManageDecksButton != null) HoneycombManageDecksButton.IsVisible = false;
            if (HoneycombQuitMatchButton != null) HoneycombQuitMatchButton.IsVisible = false;
            if (HoneycombRulesButton != null) HoneycombRulesButton.IsVisible = false;
        }
        var options = SettingsService.LoadOptions();
        string baseTag = GetBaseGameTag(tag);

        if (PokerVariantBox != null)
        {
            if (tag == "VideoPoker")
            {
                _variantInitializing = true;
                PokerVariantBox.SelectedIndex = (int)_coordinator.VideoPokerViewModel.Options.Variant;
                _variantInitializing = false;
                PokerVariantBox.IsVisible = true;
            }
            else
            {
                PokerVariantBox.IsVisible = false;
            }
        }

        _coordinator.GameViewModel.Options.LastGameMode = tag;
        SettingsService.SaveOptions(_coordinator.GameViewModel.Options);

        if (_coordinator.ActiveViewModel is GameViewModel klondikeVm)
            ApplyFeltColor(klondikeVm.Options);
        else if (_coordinator.ActiveViewModel is FreecellViewModel freecellVm)
            ApplyFeltColor(freecellVm.Options);
        else if (_coordinator.ActiveViewModel is SpiderViewModel spiderVm)
            ApplyFeltColor(spiderVm.Options);
        else
            ApplyFeltColor(_coordinator.GameViewModel.Options);
    }

    // Local-dev-only banner review menu — switches to the requested game (if needed)
    // and fires the requested banner on it, so every win/loss/autocomplete banner can
    // be eyeballed without having to actually play each game into that state. The
    // dropdown that invokes this is only made visible in DEBUG builds (see constructor).
    private void DebugBanner_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is not MenuItem menuItem || menuItem.Tag is not string tag) return;
        var parts = tag.Split(':');
        if (parts.Length != 2) return;
        string game = parts[0], kind = parts[1];

        string gameTag = game switch
        {
            "Klondike"   => _coordinator.GameViewModel.Options.IsDrawConstraintsEnabled ? "SolitaireDraw3" : "SolitaireDraw1",
            "Freecell"   => "Freecell1",
            "Spider"     => _coordinator.GameViewModel.Options.SpiderSuitCount switch { 2 => "Spider2", 4 => "Spider4", _ => "Spider1" },
            _            => game,
        };

        if (GetBaseGameTag(gameTag) != GetBaseGameTag(_currentGameTag))
        {
            SaveCurrentWindowSize();
            _currentGameTag = gameTag;
            ApplyGameSwitch(gameTag);
            _revertingSelection = true;
            GameSelectionBox.SelectedIndex = GameModeToIndex(gameTag);
            _revertingSelection = false;
        }

        FireDebugBanner(kind);
    }

    private void FireDebugBanner(string kind)
    {
        switch (MainContent.Content)
        {
            case GameView gv:
                if (kind == "Win") gv.DebugShowWinBanner();
                else if (kind == "PlayWinAnimation") gv.DebugPlayWinAnimation();
                else if (kind == "Loss") gv.DebugShowLossBanner();
                else if (kind == "Autocomplete") gv.DebugShowAutocompleteBanner();
                break;
            case FreecellView fv:
                if (kind == "Win") fv.DebugShowWinBanner();
                else if (kind == "PlayWinAnimation") fv.DebugPlayWinAnimation();
                else if (kind == "Loss") fv.DebugShowLossBanner();
                else if (kind == "Autocomplete") fv.DebugShowAutocompleteBanner();
                break;
            case SpiderView sv:
                if (kind == "Win") sv.DebugShowWinBanner();
                else if (kind == "PlayWinAnimation") sv.DebugPlayWinAnimation();
                else if (kind == "Loss") sv.DebugShowLossBanner();
                else if (kind == "Autocomplete") sv.DebugShowAutocompleteBanner();
                break;
            case VideoPokerView vpv:
                if (kind == "Win") vpv.DebugShowWinBanner();
                else if (kind == "Loss") vpv.DebugShowLossBanner();
                break;
            case BlackjackView bjv:
                if (kind == "Win") bjv.DebugShowResultBanner(true);
                else if (kind == "Loss") bjv.DebugShowResultBanner(false);
                break;
            case HoneycombView hv:
                hv.DebugShowResultBanner(kind);
                break;
        }
    }

    // Dev-only banner-catalog preview — the full BannerId catalog (~55 entries) is far
    // too many to list individually, so each category gets one MenuItem instead: a
    // click shows the next banner in that category on the currently active game's
    // toast, wrapping back to the first after the last, instead of a five-times-longer
    // flyout with every banner spelled out.
    private static readonly Dictionary<string, List<BannerId>> _debugBannerCategories = BuildDebugBannerCategories();
    private readonly Dictionary<string, int> _debugBannerCategoryIndex = new();

    private static Dictionary<string, List<BannerId>> BuildDebugBannerCategories()
    {
        // Keys match BannerCatalog's own Category field (see HoneycombBannerCatalog.json)
        // so the header text lines up with the spreadsheet's naming.
        var result = new Dictionary<string, List<BannerId>>
        {
            ["Loading"] = new(),
            ["Idle Action"] = new(),
            ["Gameplay"] = new(),
            ["Milestones"] = new(),
            ["Rule-Specific"] = new(),
        };
        foreach (BannerId id in Enum.GetValues(typeof(BannerId)))
        {
            var name = id.ToString();
            if (name.StartsWith("Loading")) result["Loading"].Add(id);
            else if (name.StartsWith("Idle")) result["Idle Action"].Add(id);
            else if (name.StartsWith("Gameplay")) result["Gameplay"].Add(id);
            else if (name.StartsWith("Milestones")) result["Milestones"].Add(id);
            else if (name.StartsWith("RuleSpecific")) result["Rule-Specific"].Add(id);
        }
        return result;
    }

    // Debug-only text substitution — real gameplay fills these from actual match state
    // (see HoneycombViewModel's EnqueueBanner call sites), but the catalog cycler has no
    // live match to pull an opponent name/combo count/suit from, so it always shows the
    // same stand-in values. Good enough for proofreading copy; not meant to look "real."
    private static string ApplyDebugBannerTokens(string text) => text
        .Replace("{OpponentName}", "Baby Bee")
        .Replace("{ComboCount}", "4")
        .Replace("{AscensionSuit}", "Spades")
        .Replace(BannerCatalog.RuleNameSentinel, "Math Bee");

    private void DebugBannerCategory_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is not MenuItem menuItem || menuItem.Tag is not string category) return;
        if (!_debugBannerCategories.TryGetValue(category, out var ids) || ids.Count == 0) return;

        int next = (_debugBannerCategoryIndex.TryGetValue(category, out var i) ? i + 1 : 0) % ids.Count;
        _debugBannerCategoryIndex[category] = next;
        var id = ids[next];

        var def = BannerCatalog.Definition(id);
        // Always the primary (first) message rather than routing through Fire()'s random
        // gate roll — a review tool should show every entry deterministically, not
        // silently skip to a fallback because the dice didn't cooperate this click.
        string text = def != null && def.Messages.Count > 0 ? def.Messages[0] : def?.Fallback ?? id.ToString();
        text = ApplyDebugBannerTokens(text);

        // Left as the static category name in XAML; updated here so reopening the
        // flyout shows exactly where the cycle left off.
        menuItem.Header = $"{category} ({next + 1}/{ids.Count})";

        switch (MainContent.Content)
        {
            case GameView gv: gv.DebugFlashToast(text); break;
            case FreecellView fv: fv.DebugFlashToast(text); break;
            case SpiderView sv: sv.DebugFlashToast(text); break;
            case VideoPokerView vpv: vpv.DebugFlashToast(text); break;
            case BlackjackView bjv: bjv.DebugFlashToast(text); break;
            case HoneycombView hv: hv.DebugFlashToast(text); break;
        }
    }

    private void OnHintTrackedVmPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(GameViewModel.HasNoMoves))
            UpdateHintButtonEnabled();

        if (this.DataContext is HoneycombViewModel hVm)
        {
            if (e.PropertyName == nameof(HoneycombViewModel.State) ||
                e.PropertyName == nameof(HoneycombViewModel.IsPlaying) ||
                e.PropertyName == nameof(HoneycombViewModel.Options))
            {
                UpdateHoneycombButtons();
            }
        }
    }
    
    private void UpdateHoneycombButtons()
    {
        if (this.DataContext is HoneycombViewModel hVm && hVm.State != null)
        {
            var phase = hVm.State.Phase;
            bool isResult = phase == HoneycombPhase.Result;
            bool isPreMatch = phase == HoneycombPhase.PreMatch;
            bool isPlaying = phase == HoneycombPhase.Playing;

            if (HoneycombStartMatchButton != null) HoneycombStartMatchButton.IsVisible = isPreMatch || isResult;
            if (HoneycombRematchButton != null) HoneycombRematchButton.IsVisible = isResult;
            // Manage Decks edits the player's active deck composition — meaningless under
            // No Stress Mode, which always deals a fixed/random hand instead of that deck.
            bool noStressMode = SettingsService.LoadOptions().IsNoStressMode;
            if (HoneycombManageDecksButton != null) HoneycombManageDecksButton.IsVisible = (isPreMatch || isResult) && !noStressMode;
            // Hidden if the player opted out, or on Ultra Hard (where a hint would trivialize
            // the hardest difficulty) — matches Mac's HoneycombView hint-button condition.
            if (HintButton != null) HintButton.IsVisible = isPlaying && !hVm.Options.HideHintButton && hVm.Options.Difficulty != HoneycombDifficulty.UltraHard;
            if (UndoButton != null) UndoButton.IsVisible = isPlaying;
            if (HoneycombQuitMatchButton != null) 
            {
                HoneycombQuitMatchButton.IsVisible = isPlaying;
                HoneycombQuitMatchButton.Content = Strings.Get(StringKey.ToolbarQuitMatch, _language);
            }
        }
    }

    private void HoneycombStartMatch_Click(object? sender, RoutedEventArgs e)
    {
        if (this.DataContext is HoneycombViewModel hVm)
        {
            hVm.StartNewMatch();
        }
    }

    private void HoneycombRematch_Click(object? sender, RoutedEventArgs e)
    {
        if (this.DataContext is HoneycombViewModel hVm)
        {
            hVm.RematchGame();
        }
    }

    private void HoneycombQuitMatch_Click(object? sender, RoutedEventArgs e)
    {
        if (this.DataContext is HoneycombViewModel hVm)
        {
            hVm.QuitMatch();
        }
    }

    private void UpdateHintButtonEnabled()
    {
        bool hasNoMoves = _coordinator.ActiveViewModel switch
        {
            GameViewModel g     => g.HasNoMoves,
            FreecellViewModel f => f.HasNoMoves,
            SpiderViewModel s   => s.HasNoMoves,
            _                   => false,
        };
        if (HintButton != null) HintButton.IsEnabled = !hasNoMoves;
    }

    // ── Per-game window size ──────────────────────────────────────────────────

    private void SaveCurrentWindowSize()
    {
        if (_coordinator == null) return;
        var opts = _coordinator.GameViewModel.Options;
        bool maximized = WindowState == WindowState.Maximized;
        switch (GetBaseGameTag(_currentGameTag))
        {
            case "Freecell":
                if (!maximized) { opts.FreecellWidth = Width; opts.FreecellHeight = Height; }
                opts.FreecellMaximized = maximized;
                break;
            case "Spider":
                if (!maximized) { opts.SpiderWidth = Width; opts.SpiderHeight = Height; }
                opts.SpiderMaximized = maximized;
                break;
            case "VideoPoker":
                if (!maximized) { opts.VideoPokerWidth = Width; opts.VideoPokerHeight = Height; }
                opts.VideoPokerMaximized = maximized;
                break;
            case "Blackjack":
                if (!maximized) { opts.BlackjackWidth = Width; opts.BlackjackHeight = Height; }
                opts.BlackjackMaximized = maximized;
                break;
            case "Honeycomb":
                if (!maximized) { opts.HoneycombWidth = Width; opts.HoneycombHeight = Height; }
                opts.HoneycombMaximized = maximized;
                break;
            default:
                if (!maximized) { opts.KlondikeWidth = Width; opts.KlondikeHeight = Height; }
                opts.KlondikeMaximized = maximized;
                break;
        }
        SettingsService.SaveOptions(opts);
    }


    // Keeps the window from growing/restoring larger than the actual screen and from
    // sitting partially off-screen afterward — without this, a size restored from a
    // different/bigger monitor (RestoreWindowSizeForGame) could leave the window's
    // bottom/right edge rendered
    // off-screen, with no way to reach controls anchored there (e.g. Preferences' OK
    // button). Mirrors the same Screens.ScreenFromWindow/WorkingArea pattern already
    // used to keep the window's position on-screen in the constructor's Opened handler.
    private void ClampWindowToScreen()
    {
        var screen = Screens.ScreenFromWindow(this) ?? Screens.Primary;
        if (screen == null) return;
        var wa = screen.WorkingArea;

        Width  = Math.Min(Width, wa.Width);
        Height = Math.Min(Height, wa.Height);

        double x = Position.X, y = Position.Y;
        if (x + Width  > wa.X + wa.Width)  x = wa.X + wa.Width  - Width;
        if (y + Height > wa.Y + wa.Height) y = wa.Y + wa.Height - Height;
        if (x < wa.X) x = wa.X;
        if (y < wa.Y) y = wa.Y;
        Position = new PixelPoint((int)x, (int)y);
    }

    // Called when the board's own footprint changes at a fixed zoom level (currently
    // just Freecell 1-deck ↔ 2-deck, which adds a whole extra FreeCells+Foundations row).
    // Standing rule: switching games or game modes never resizes the window — the
    // window size is the user's, and content always scales to fit whatever size it
    // currently is. So this only refreshes the Min floor (2-deck's own minimum may
    // differ) and re-triggers the responsive scale-to-fit for the new, bigger board —
    // it does NOT touch Width/Height. SettleResponsiveLayout retries until stable rather
    // than a single deferred call — this is a reproducible case where one recompute
    // (even deferred past FreecellView's own Options-changed layout update) can still
    // land on a wrong scale that only a later resize would otherwise correct.
    private void EnsureWindowFitsBoard(string tag)
    {
        var (minW, minH) = ComputeBoardMinSize(tag);
        this.MinWidth = minW;
        this.MinHeight = minH;
        SettleResponsiveLayout();
    }

    // Set once the first game of this run has had its saved size restored — deliberately
    // in-memory only (not a GameOptions field), so it's true for "the rest of this
    // process" but resets to false on every fresh launch. Restoring a differently-sized
    // saved Width/Height on every in-session game switch fought the responsive-scaling
    // feature: shrink the window down to work with a small board, switch games, and the
    // window would snap back to whatever size was last saved for the new game instead of
    // staying put and letting that game's content scale to fit the size you're already
    // at. Restoring once per launch (so re-opening the app still remembers your last
    // size) while leaving the window alone on every later switch — updating only
    // MinWidth/MinHeight, still per-game — gets both: a remembered size across restarts,
    // and free responsive resizing within a session.
    private bool _hasRestoredWindowSizeThisSession = false;

    private void RestoreWindowSizeForGame(string tag)
    {
        var opts = _coordinator.GameViewModel.Options;

        var (minW, minH) = ComputeBoardMinSize(tag);
        this.MinWidth = minW;
        this.MinHeight = minH;

        if (_hasRestoredWindowSizeThisSession) return;
        _hasRestoredWindowSizeThisSession = true;

        (double w, double h, bool max) = GetBaseGameTag(tag) switch
        {
            "Freecell"   => (opts.FreecellWidth,    opts.FreecellHeight,    opts.FreecellMaximized),
            "Spider"     => (opts.SpiderWidth,     opts.SpiderHeight,     opts.SpiderMaximized),
            "VideoPoker" => (opts.VideoPokerWidth, opts.VideoPokerHeight, opts.VideoPokerMaximized),
            "Blackjack"  => (opts.BlackjackWidth,  opts.BlackjackHeight,  opts.BlackjackMaximized),
            "Honeycomb"  => (opts.HoneycombWidth,  opts.HoneycombHeight,  opts.HoneycombMaximized),
            _            => (opts.KlondikeWidth,   opts.KlondikeHeight,   opts.KlondikeMaximized),
        };

        if (max)
        {
            WindowState = WindowState.Maximized;
        }
        else
        {
            WindowState = WindowState.Normal;
            Width  = Math.Max(MinWidth, w);
            Height = Math.Max(MinHeight, h);
            ClampWindowToScreen();
        }
    }

    private (double minWidth, double minHeight) ComputeBoardMinSize(string tag)
    {
        // These floors are deliberately small — matching the original Mac app's actual
        // minimum window sizes — not "big enough that nothing ever needs to shrink to
        // fit." That was the old assumption (this method predates the responsive
        // scale-to-fit system): the board's content used to render at a fixed size, so
        // the floor had to be tall/wide enough that a worst-case board (a fully cascaded
        // King-to-2 tableau column, a maxed-out 2-deck Freecell layout, etc.) never
        // clipped. Now UpdateResponsiveLayout scales the whole board down to fit
        // whatever size the window actually is, so the floor only needs to be "small
        // enough to still be usable," not "tall enough to avoid ever scaling."
        string baseTag = GetBaseGameTag(tag);
        double baseMinWidth = baseTag switch
        {
            "VideoPoker" => 520,
            "Blackjack"  => 340,
            _            => 600, // Klondike, Freecell (both deck counts), Spider
        };
        double baseMinHeight = baseTag switch
        {
            "VideoPoker" => 450,
            "Blackjack"  => 403,
            _            => 330, // Klondike, Freecell (both deck counts), Spider
        };

        double minWidth  = baseMinWidth;
        double minHeight = baseMinHeight;

        // Never require a minimum bigger than the actual screen — Avalonia enforces
        // MinWidth/MinHeight as a hard floor on the window, with no way for
        // ClampWindowToScreen (which only adjusts Width/Height, not the Min values) to
        // override it afterward.
        var screen = Screens.ScreenFromWindow(this) ?? Screens.Primary;
        if (screen != null)
        {
            var wa = screen.WorkingArea;
            minWidth  = Math.Min(minWidth, wa.Width);
            minHeight = Math.Min(minHeight, wa.Height);
        }

        return (minWidth, minHeight);
    }

    // The board's win-celebration overlay (WinAnimationView, hosted per-game as
    // VictoryOverlay) lives inside the scaled subtree, so ordinary Stretch alignment
    // only ever fills the *board's own natural content size* — never the actual window
    // — since LayoutTransformControl arranges its child at that natural size, not the
    // window's. That's usually fine, but right at a win the tableau piles have mostly
    // drained into the foundations, so the board's natural height shrinks well below
    // the window's, leaving the overlay's dimmed background and bouncing-card cascade
    // confined to a smaller area than the window with a visible edge where the dimming
    // stops. Callers explicitly size VictoryOverlay to this (the real window's game
    // area, converted back to the board's own pre-scale coordinate space) instead.
    public Size GetUnscaledGameAreaSize()
    {
        double scale = _contentScale.ScaleX > 0 ? _contentScale.ScaleX : 1.0;
        return new Size(GameAreaGrid.Bounds.Width / scale, GameAreaGrid.Bounds.Height / scale);
    }

    private void OnWindowSizeChanged(object? sender, SizeChangedEventArgs e)
    {
        if (BoardBackgroundImage.IsVisible && _lastBoardBackgroundOptions != null)
            ApplyBoardBackground(_lastBoardBackgroundOptions);

        if (_coordinator?.GameViewModel?.Options != null)
            UpdateVignetteSizeAndIntensity(_coordinator.GameViewModel.Options);

        UpdateResponsiveLayout();
    }

    private void UpdateSolitaireKeyHint(string tag, bool isCardGame)
    {
        if (SolitaireKeyHintLabel == null) return;
        SolitaireKeyHintLabel.IsVisible = isCardGame;
        if (!isCardGame) return;
        SolitaireKeyHintLabel.Text = GetBaseGameTag(tag) switch
        {
            "Freecell" => Strings.Get(StringKey.HotkeyLegendBeecell, _language),
            "Spider"   => Strings.Get(StringKey.HotkeyLegendSpider, _language),
            _          => Strings.Get(StringKey.HotkeyLegendKlondike, _language),
        };
    }

    // Retries UpdateResponsiveLayout every 100ms (up to 1s) until two consecutive
    // attempts agree on the same scale. A single recompute right after a game/mode
    // switch has repeatedly proven unreliable — Freecell 1-deck→2-deck switched while
    // the window is already at its minimum size is a reproducible example: the first
    // attempt sometimes measures a not-yet-settled layout and computes a wrong scale
    // that nothing else corrects, even though a plain window resize afterward (which
    // re-runs UpdateResponsiveLayout with fresh data) fixes it instantly. Rather than
    // keep chasing the exact single right moment to recompute, retry until the result
    // stops changing — whichever attempt lands after everything has actually settled is
    // what sticks. onSettled (optional) runs once, when the loop stops for any reason.
    private void SettleResponsiveLayout(Action? onSettled = null)
    {
        int attempts = 0;
        double? lastScale = null;
        var settleTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(100) };
        settleTimer.Tick += (_, _) =>
        {
            UpdateResponsiveLayout();
            attempts++;
            bool stable = lastScale.HasValue && Math.Abs(lastScale.Value - _contentScale.ScaleX) < 0.001;
            lastScale = _contentScale.ScaleX;
            if (stable || attempts >= 10)
            {
                settleTimer.Stop();
                onSettled?.Invoke();
            }
        };
        settleTimer.Start();
    }

    private void UpdateResponsiveLayout()
    {
        // GameAreaGrid *is* row 1's actual content area (below the toolbar row), so its
        // Bounds only ever reflect a completed layout pass — unlike this.Window's own
        // Bounds/Width/Height, which can be read stale mid-game-switch (see the Bounds
        // subscription wired up in the constructor: setting Window.Width/Height doesn't
        // update Window.Bounds synchronously, so a same-tick read of it here reproduced
        // the old game's — or, at first launch, no game's — sizing instead of the new
        // one's). Bail out only if a layout genuinely hasn't happened yet at all.
        if (GameAreaGrid.Bounds.Width <= 0 || GameAreaGrid.Bounds.Height <= 0) return;

        // 1. Dynamic Scaling
        //
        // The board's natural (unscaled) footprint is measured directly off MainContent
        // rather than read from ComputeBoardMinSize's per-game constants. Those constants
        // are tuned as a worst-case clipping floor (e.g. Klondike's 930 assumes a fully
        // cascaded King-to-2 tableau column, which the initial deal never has), so using
        // them as the "natural size" reference here made the board shrink well below 1.0x
        // — and hence leave a large unused margin — any time the window wasn't tall enough
        // to fit that worst case, even though the actual dealt board fit comfortably.
        // Layout is otherwise deferred to the next frame, which would read a stale size
        // right after a game switch (e.g. Blackjack/Video Poker populate their card
        // panels from their own Loaded handler, after any earlier measurement ran with
        // those panels still empty). InvalidateMeasure() before Measure() — not after —
        // is the standard "force a guaranteed-fresh measurement right now" idiom:
        // invalidating first means Avalonia's own layout manager doesn't consider
        // MainContent's old measurement valid anymore, so the immediately-following
        // Measure(Infinity) can't be short-circuited by a stale cached result, and
        // MainContent is left in a properly-validated state afterward instead of one
        // that needs a second invalidation to undo. Measure(Infinity) also reports
        // MainContent's true desired size unaffected by the current LayoutTransform scale.
        MainContent.InvalidateMeasure();
        MainContent.Measure(Size.Infinity);
        double naturalW = MainContent.DesiredSize.Width;
        double naturalH = MainContent.DesiredSize.Height;
        if (naturalW <= 0 || naturalH <= 0)
        {
            // Not measured yet (e.g. content not attached) — fall back to the tuned floor.
            var (boardMinW, boardMinH) = ComputeBoardMinSize(_currentGameTag);
            naturalW = boardMinW;
            naturalH = boardMinH - (TopBarBorder != null && TopBarBorder.Bounds.Height > 0 ? TopBarBorder.Bounds.Height : 80);
        }

        double availableH = Math.Max(1, GameAreaGrid.Bounds.Height);
        // MainContentWrapper carries a 30px Margin on each side (see MainWindow.axaml) so
        // scaled cards never touch the window edge — match that here, otherwise scale-to-fit
        // sizes the board to the full window width and the margin clips the edge cards instead.
        double availableW = Math.Max(1, GameAreaGrid.Bounds.Width - 60);

        double scaleX = availableW / naturalW;
        double scaleY = availableH / naturalH;

        // Remove configuredZoom cap entirely: cards now perfectly scale
        // up OR down to fill whatever space the window provides.
        double effectiveZoom = Math.Min(scaleX, scaleY);

        _contentScale.ScaleX = effectiveZoom;
        _contentScale.ScaleY = effectiveZoom;

        // 2. Responsive Toolbar
        bool isCompact = GameAreaGrid.Bounds.Width < 700;
        
        if (NewGameButton != null) NewGameButton.Content = isCompact ? "➕" : Strings.Get(StringKey.NewGame, _language);
        if (RestartButton != null) RestartButton.Content = isCompact ? "🔄" : Strings.Get(StringKey.Restart, _language);
        if (OptionsButton != null) OptionsButton.Content = isCompact ? "⚙️" : Strings.Get(StringKey.Options, _language);
        if (HintButton != null)    HintButton.Content    = isCompact ? "💡" : Strings.Get(StringKey.Hint, _language);
        if (UndoButton != null)    UndoButton.Content    = isCompact ? "↩️" : Strings.Get(StringKey.Undo, _language);
    }

    private void OnWindowKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            if (ConfirmActionOverlay != null && ConfirmActionOverlay.IsVisible)
            {
                e.Handled = true;
                // Route through the same handler as the Cancel button so a pending
                // game-mode change (see ClosePreferences_Click) gets reverted here too,
                // instead of just hiding the overlay and leaving the combo/flag stale.
                CancelConfirmAction_Click(sender, e);
                return;
            }
            if (PreferencesOverlay != null && PreferencesOverlay.IsVisible)
            {
                e.Handled = true;
                CancelPreferences_Click(sender, e);
                return;
            }
            if (HoneycombRulesOverlay != null && HoneycombRulesOverlay.IsVisible)
            {
                e.Handled = true;
                HoneycombRulesViewControl.Cancel_Click(sender, e);
                return;
            }
            if (ManageDecksOverlay != null && ManageDecksOverlay.IsVisible)
            {
                e.Handled = true;
                CloseManageDecks_Click(sender, e);
                return;
            }
        }

        if (e.Key == Key.F1)
        {
            e.Handled = true;
            Help_Click(null, new RoutedEventArgs());
            return;
        }
        if (e.Key == Key.F2)
        {
            e.Handled = true;
            Preferences_Click(null, new RoutedEventArgs());
            return;
        }

        if ((e.KeyModifiers & KeyModifiers.Control) != 0)
        {
            if (e.Key == Key.N)
            {
                e.Handled = true;
                NewGame_Click(null, new RoutedEventArgs());
            }
            else if (e.Key == Key.R)
            {
                e.Handled = true;
                RestartGame_Click(null, new RoutedEventArgs());
            }
            else if (e.Key == Key.Z)
            {
                bool isCardGame = _currentGameTag != "VideoPoker" && _currentGameTag != "Blackjack";
                if (isCardGame && UndoButton?.IsEnabled != false)
                {
                    e.Handled = true;
                    Undo_Click(null, new RoutedEventArgs());
                }
            }
            else if (e.Key == Key.H)
            {
                bool isCardGame = _currentGameTag != "VideoPoker" && _currentGameTag != "Blackjack";
                if (isCardGame && HintButton?.IsEnabled != false && HintButton?.IsVisible != false)
                {
                    e.Handled = true;
                    Hint_Click(null, new RoutedEventArgs());
                }
            }
        }
    }
}
