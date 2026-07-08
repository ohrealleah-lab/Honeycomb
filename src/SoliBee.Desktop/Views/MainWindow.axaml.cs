using System;
using System.Collections.Generic;
using System.ComponentModel;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Threading;
using CommunityToolkit.Mvvm.Messaging;
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
    private bool _closePreferencesAfterModeConfirm;
    private INotifyPropertyChanged? _hintTrackedVm;

    public MainWindow()
    {
        InitializeComponent();

        MainContentWrapper.LayoutTransform = _contentScale;

        _coordinator = new AppCoordinator();

        // One-time migration: if FF mode was on before themes existed, seed a "Final Fantasy" theme
        ThemeService.MigrateFFModeIfNeeded(_coordinator.GameViewModel.Options);

        // First launch: apply Pareidolic 2 as the default visual theme
        if (ThemeService.ApplyDefaultThemeIfNeeded(_coordinator.GameViewModel.Options))
            SettingsService.SaveOptions(_coordinator.GameViewModel.Options);

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
            CardView.ApplyThemeColors(m.Options);
            CardView.InvalidateAllCardViews(this);
            bool isCardGame = _currentGameTag != "VideoPoker" && _currentGameTag != "Blackjack";
            if (TimeStatPanel != null) TimeStatPanel.IsVisible = isCardGame && !m.Options.IsNoStressMode;
            // Hint is solitaire-only (no hint logic exists for VP/Blackjack).
            if (HintButton != null)    HintButton.IsVisible    = isCardGame && !m.Options.HideHintButton;
            if (ZoomButton != null)    ZoomButton.IsVisible    = !m.Options.HideZoomControls;
        });

        // Also listen to FaceCardArtChangedMessage to keep all cards in sync
        WeakReferenceMessenger.Default.Register<FaceCardArtChangedMessage>(this, (r, m) =>
        {
            CardView.InvalidateAllCardViews(this);
        });

        // Set initial background color
        ApplyFeltColor(_coordinator.GameViewModel.Options);

        // Apply any saved theme color overrides before first render
        CardView.ApplyThemeColors(_coordinator.GameViewModel.Options);

        this.AddHandler(PointerWheelChangedEvent, OnPointerWheelChanged, RoutingStrategies.Tunnel);
        this.KeyDown += OnWindowKeyDown;
        this.Closing += (_, _) => SaveCurrentWindowSize();

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
        };

        // Preload custom art into display-resolution cache before first scroll
        this.Loaded += (_, _) =>
        {
            CardView.PreloadFaceArt();
            CardView.PreloadCardBacks(_coordinator.GameViewModel.Options);
        };
    }

    private void ApplyFeltColor(GameOptions options)
    {
        var feltColor = options.FeltColor;
        string primaryHex = "#008000";
        string statusHex = "#007300";

        if (options.IsFinalFantasyMode)
        {
            primaryHex = "#000000";
            statusHex  = "#111111";
        }
        else if (feltColor == FeltColorTheme.Custom)
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
                if (VignetteOverlay.Fill is Avalonia.Media.RadialGradientBrush rgb)
                    rgb.Radius = options.VignetteScale * 0.8;
            }
        }
        catch
        {
            this.Background = new Avalonia.Media.SolidColorBrush(Avalonia.Media.Colors.DarkGreen);
        }
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
            ConfirmActionButton.Content = "New Game";
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
            ConfirmActionButton.Content = "Restart";
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
        else if (_pendingAction.StartsWith("SwitchGame:"))
        {
            string targetTag = _pendingAction.Substring("SwitchGame:".Length);
            _currentGameTag = targetTag;
            _revertingSelection = true;
            GameSelectionBox.SelectedIndex = GameModeToIndex(targetTag);
            _revertingSelection = false;
            ApplyGameSwitch(targetTag);
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
        // Video Poker has no undo
    }

    private void Hint_Click(object? sender, RoutedEventArgs e)
    {
        if (this.DataContext is GameViewModel klondikeVm)
            klondikeVm.FindHint();
        else if (this.DataContext is FreecellViewModel freecellVm)
            freecellVm.FindHint();
        else if (this.DataContext is SpiderViewModel spiderVm)
            spiderVm.FindHint();
        // Video Poker has no hint
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
        ConfirmActionTitle.Text     = "Reset Statistics?";
        ConfirmActionMessage.Text   = "This will permanently clear all statistics. This cannot be undone.";
        ConfirmActionButton.Content = "Reset";
        ConfirmActionOverlay.IsVisible = true;
    }

    private static string FormatKlondikeScore(int rawScore, bool vegas)
    {
        if (!vegas) return rawScore.ToString();
        int dollars = rawScore / 100;
        int abs     = Math.Abs(dollars);
        return dollars < 0 ? $"-${abs}.00" : $"${abs}.00";
    }

    private static Grid BuildStatRow(string label, string value)
    {
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        grid.Children.Add(new TextBlock { Text = label, Foreground = Brushes.White });
        var valueBlock = new TextBlock { Text = value, Foreground = Brushes.White, FontWeight = FontWeight.Bold };
        Grid.SetColumn(valueBlock, 1);
        grid.Children.Add(valueBlock);
        return grid;
    }

    private void PopulateBlackjackStats(BlackjackViewModel vm)
    {
        StatsFixedRows.IsVisible   = false;
        StatsDynamicRows.IsVisible = true;
        StatsTitleText.Text = "Blackjack Statistics";

        var s = vm.Stats;
        double winRate = s.HandsPlayed > 0 ? 100.0 * s.HandsWon / s.HandsPlayed : 0.0;
        double rtp     = s.TotalCreditsWagered > 0 ? 100.0 * s.TotalCreditsWon / s.TotalCreditsWagered : 0.0;

        StatsDynamicRows.Children.Clear();
        StatsDynamicRows.Children.Add(BuildStatRow("Hands Played",  s.HandsPlayed.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("Hands Won",     s.HandsWon.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("Hands Lost",    s.HandsLost.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("Pushes",        s.HandsPushed.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("Blackjacks",    s.Blackjacks.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("Win Rate",      $"{winRate:0.0}%"));
        StatsDynamicRows.Children.Add(BuildStatRow("Total Wagered", s.TotalCreditsWagered.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("Total Paid",    s.TotalCreditsWon.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("Biggest Pay",   s.BiggestPay.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("RTP",           $"{rtp:0.0}%"));
        StatsDynamicRows.Children.Add(BuildStatRow("Rebuys",        s.Rebuys.ToString()));
    }

    private void PopulateVideoPokerStats(VideoPokerViewModel vm)
    {
        StatsFixedRows.IsVisible   = false;
        StatsDynamicRows.IsVisible = true;
        StatsTitleText.Text = "Video Poker Statistics";

        var s = vm.Stats;
        double winRate      = s.TotalHands > 0 ? 100.0 * s.WinningHands / s.TotalHands : 0.0;
        double rtp          = s.TotalCreditsWagered > 0 ? 100.0 * s.TotalCreditsWon / s.TotalCreditsWagered : 0.0;
        int    royalFlushes = s.HandCounts.GetValueOrDefault("Royal Flush");

        StatsDynamicRows.Children.Clear();
        StatsDynamicRows.Children.Add(BuildStatRow("Hands Played",   s.TotalHands.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("Hands Won",      s.WinningHands.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("Win Rate",       $"{winRate:0.0}%"));
        StatsDynamicRows.Children.Add(BuildStatRow("Biggest Pay",    s.BiggestPay.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("Total Wagered",  s.TotalCreditsWagered.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("Total Paid",     s.TotalCreditsWon.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("RTP",            $"{rtp:0.0}%"));
        StatsDynamicRows.Children.Add(BuildStatRow("Royal Flushes",  royalFlushes.ToString()));
        StatsDynamicRows.Children.Add(BuildStatRow("Rebuys",         s.Rebuys.ToString()));
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

        StatsFixedRows.IsVisible   = true;
        StatsDynamicRows.IsVisible = false;

        string title;
        int gamesPlayed, gamesWon, currentStreak, longestStreak, fastestWinSec, totalWinSec;
        string highScoreText;

        if (this.DataContext is GameViewModel klondikeVm)
        {
            title = "Klondike Statistics";
            var s = klondikeVm.Stats;
            gamesPlayed   = s.GamesPlayed;
            gamesWon      = s.GamesWon;
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
            string deckLabel = freecellVm.Options.FreecellDeckCount == 2 ? "2-Decks" : "1-Deck";
            title = $"Freecell Statistics ({deckLabel})";
            // Freecell has no Vegas mode of its own — always the "standard" bucket (see FreecellViewModel.ModeKey).
            string modeKey = $"standard_{freecellVm.Options.FreecellDeckCount}deck";
            var ms = freecellVm.Stats.FreecellStatsByMode.TryGetValue(modeKey, out var m) ? m : new ModeStats();
            gamesPlayed   = ms.GamesPlayed;
            gamesWon      = ms.GamesWon;
            currentStreak = ms.CurrentStreak;
            longestStreak = ms.LongestStreak;
            fastestWinSec = ms.ShortestWinSeconds;
            totalWinSec   = ms.TotalWinSeconds;
            highScoreText = ms.HighScore.ToString();
        }
        else if (this.DataContext is SpiderViewModel spiderVm)
        {
            string suitLabel = spiderVm.Options.SpiderSuitCount switch { 2 => "2 Suits", 4 => "4 Suits", _ => "1 Suit" };
            title = $"Spider Statistics ({suitLabel})";
            string suitKey = spiderVm.Options.SpiderSuitCount.ToString();
            var ms = spiderVm.Stats.SpiderStatsBySuit.TryGetValue(suitKey, out var m) ? m : new ModeStats();
            gamesPlayed   = ms.GamesPlayed;
            gamesWon      = ms.GamesWon;
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
        StatsAvgWinTimeText.Text   = gamesWon > 0 ? $"{totalWinSec / gamesWon}s" : "--";
        StatsFastestWinText.Text  = gamesWon > 0 ? $"{fastestWinSec}s" : "--";
    }

    private void Preferences_Click(object? sender, RoutedEventArgs e)
    {
        _preferencesView = new PreferencesView();

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
        else
        {
            GameOptions options = this.DataContext switch
            {
                GameViewModel vm      => vm.Options,
                FreecellViewModel vm  => vm.Options,
                SpiderViewModel vm    => vm.Options,
                _                     => _coordinator.GameViewModel.Options
            };
            // Clone, don't share the live instance — otherwise each ViewModel's
            // OptionsChangedMessage handler compares the object to itself and never
            // detects a change for whichever game is currently active.
            _preferencesView.DataContext = options.Clone();
            _preferencesView.ActiveGameFamily = this.DataContext switch
            {
                GameViewModel _      => "Klondike",
                FreecellViewModel _  => "Freecell",
                SpiderViewModel _    => "Spider",
                _                    => "",
            };
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
            ConfirmActionButton.Content = "Yes";
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
        _                                                   => 0,
    };

    private void ResizeWindowForGame(string tag)
    {
        var (minW, minH) = ComputeBoardMinSize(tag, GetGameZoom(tag));
        this.MinWidth = minW;
        this.MinHeight = minH;
    }

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
            "Freecell" => "Freecell1",
            "Spider"   => opts.SpiderSuitCount switch { 2 => "Spider2", 4 => "Spider4", _ => "Spider1" },
            _          => baseTag,
        };

        if (GetBaseGameTag(tag) != GetBaseGameTag(_currentGameTag) && IsGameInProgress())
        {
            _revertingSelection = true;
            GameSelectionBox.SelectedIndex = GameModeToIndex(_currentGameTag);
            _revertingSelection = false;

            _pendingAction = "SwitchGame:" + tag;
            ConfirmActionTitle.Text = "Switch Game?";
            ConfirmActionMessage.Text = "Are you sure you want to abandon the current game and switch to another?";
            ConfirmActionButton.Content = "Switch Game";
            ConfirmActionOverlay.IsVisible = true;
            return;
        }

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
        if (tag == "SolitaireDraw1" || tag == "SolitaireDraw3")
        {
            bool wantDrawThree = (tag == "SolitaireDraw3");
            if (_coordinator.GameViewModel.Options.IsDrawConstraintsEnabled != wantDrawThree)
            {
                _coordinator.GameViewModel.Options.IsDrawConstraintsEnabled = wantDrawThree;
                SettingsService.SaveOptions(_coordinator.GameViewModel.Options);
                _coordinator.GameViewModel.InitializeGame();
            }
            _coordinator.SwitchToGame();
            this.MainContent.Content = new GameView { DataContext = _coordinator.GameViewModel };
        }
        else if (tag == "Freecell1" || tag == "Freecell2")
        {
            int deckCount = tag == "Freecell2" ? 2 : 1;
            var opts = _coordinator.GameViewModel.Options;
            if (opts.FreecellDeckCount != deckCount)
            {
                opts.FreecellDeckCount = deckCount;
                SettingsService.SaveOptions(opts);
                _coordinator.FreecellViewModel.InitializeGame();
            }
            _coordinator.SwitchToFreecell();
            this.MainContent.Content = new FreecellView { DataContext = _coordinator.FreecellViewModel };
        }
        else if (tag == "Spider1" || tag == "Spider2" || tag == "Spider4")
        {
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
                _coordinator.SpiderViewModel.InitializeGame();
            }
            _coordinator.SwitchToSpider();
            this.MainContent.Content = new SpiderView { DataContext = _coordinator.SpiderViewModel };
        }
        else if (tag == "VideoPoker")
        {
            _coordinator.SwitchToVideoPoker();
            this.MainContent.Content = new VideoPokerView { DataContext = _coordinator.VideoPokerViewModel };
        }
        else if (tag == "Blackjack")
        {
            _coordinator.SwitchToBlackjack();
            _coordinator.BlackjackViewModel.PrepareForResume();
            this.MainContent.Content = new BlackjackView { DataContext = _coordinator.BlackjackViewModel };
        }

        this.DataContext = _coordinator.ActiveViewModel;
        ResizeWindowForGame(tag);
        ApplyZoom(GetGameZoom(tag));
        RestoreWindowSizeForGame(tag);

        // Re-point the hint-availability tracker at whichever viewmodel is now active,
        // so the Hint button disables itself the moment a deadlock leaves no legal moves.
        if (_hintTrackedVm != null) _hintTrackedVm.PropertyChanged -= OnHintTrackedVmPropertyChanged;
        _hintTrackedVm = _coordinator.ActiveViewModel as INotifyPropertyChanged;
        if (_hintTrackedVm != null) _hintTrackedVm.PropertyChanged += OnHintTrackedVmPropertyChanged;
        UpdateHintButtonEnabled();

        bool isCardGame = tag != "VideoPoker" && tag != "Blackjack";
        // Hint is solitaire-only (no hint logic exists for VP/Blackjack).
        if (HintButton != null)    HintButton.IsVisible    = isCardGame && !_coordinator.GameViewModel.Options.HideHintButton;
        if (ZoomButton != null)    ZoomButton.IsVisible    = !_coordinator.GameViewModel.Options.HideZoomControls;
        if (UndoButton != null)    UndoButton.IsVisible    = isCardGame;
        if (TimeStatPanel != null) TimeStatPanel.IsVisible = isCardGame && !_coordinator.GameViewModel.Options.IsNoStressMode;
        if (RestartButton != null) RestartButton.IsVisible = isCardGame;
        if (StatsBarPanel != null) StatsBarPanel.IsVisible = isCardGame;
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

        switch (MainContent.Content)
        {
            case GameView gv:
                if (kind == "Win") gv.DebugShowWinBanner();
                else if (kind == "Loss") gv.DebugShowLossBanner();
                else if (kind == "Autocomplete") gv.DebugShowAutocompleteBanner();
                break;
            case FreecellView fv:
                if (kind == "Win") fv.DebugShowWinBanner();
                else if (kind == "Loss") fv.DebugShowLossBanner();
                else if (kind == "Autocomplete") fv.DebugShowAutocompleteBanner();
                break;
            case SpiderView sv:
                if (kind == "Win") sv.DebugShowWinBanner();
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
        }
    }

    private void OnHintTrackedVmPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(GameViewModel.HasNoMoves))
            UpdateHintButtonEnabled();
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
            default:
                if (!maximized) { opts.KlondikeWidth = Width; opts.KlondikeHeight = Height; }
                opts.KlondikeMaximized = maximized;
                break;
        }
        SettingsService.SaveOptions(opts);
    }

    private void RestoreWindowSizeForGame(string tag)
    {
        // Cancel any in-flight zoom-driven resize animation from ApplyZoom above —
        // the game-switch restore takes precedence and should apply immediately.
        _windowResizeTimer?.Stop();
        _windowResizeTimer = null;

        var opts = _coordinator.GameViewModel.Options;
        (double w, double h, bool max) = GetBaseGameTag(tag) switch
        {
            "Freecell"   => (opts.FreecellWidth,    opts.FreecellHeight,    opts.FreecellMaximized),
            "Spider"     => (opts.SpiderWidth,     opts.SpiderHeight,     opts.SpiderMaximized),
            "VideoPoker" => (opts.VideoPokerWidth, opts.VideoPokerHeight, opts.VideoPokerMaximized),
            "Blackjack"  => (opts.BlackjackWidth,  opts.BlackjackHeight,  opts.BlackjackMaximized),
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
        }
    }

    // ── Per-game zoom ─────────────────────────────────────────────────────────

    private double GetGameZoom(string tag) => GetBaseGameTag(tag) switch
    {
        "Freecell"   => _coordinator.GameViewModel.Options.FreecellZoom,
        "Spider"     => _coordinator.GameViewModel.Options.SpiderZoom,
        "VideoPoker" => _coordinator.GameViewModel.Options.VideoPokerZoom,
        "Blackjack"  => _coordinator.GameViewModel.Options.BlackjackZoom,
        _            => _coordinator.GameViewModel.Options.KlondikeZoom,
    };

    private double GetGameDefaultZoom(string tag) => GetBaseGameTag(tag) switch
    {
        "Freecell"   => _coordinator.GameViewModel.Options.FreecellDefaultZoom,
        "Spider"     => _coordinator.GameViewModel.Options.SpiderDefaultZoom,
        "VideoPoker" => _coordinator.GameViewModel.Options.VideoPokerDefaultZoom,
        "Blackjack"  => _coordinator.GameViewModel.Options.BlackjackDefaultZoom,
        _            => _coordinator.GameViewModel.Options.KlondikeDefaultZoom,
    };

    private void MakeCurrentZoomDefault()
    {
        var opts = _coordinator.GameViewModel.Options;
        double zoom = GetGameZoom(_currentGameTag);
        switch (GetBaseGameTag(_currentGameTag))
        {
            case "Freecell":   opts.FreecellDefaultZoom    = zoom; break;
            case "Spider":     opts.SpiderDefaultZoom     = zoom; break;
            case "VideoPoker": opts.VideoPokerDefaultZoom = zoom; break;
            case "Blackjack":  opts.BlackjackDefaultZoom  = zoom; break;
            default:           opts.KlondikeDefaultZoom   = zoom; break;
        }
        SettingsService.SaveOptions(opts);
    }

    private (double minWidth, double minHeight) ComputeBoardMinSize(string tag, double zoom)
    {
        // Base minimums are the same values used before the zoom feature existed —
        // scaling them by zoom keeps the 1.0x defaults exactly as they were (avoids
        // ballooning the window/pushing the title bar off-screen at startup) while
        // still growing the floor at higher zoom levels.
        string baseTag = GetBaseGameTag(tag);
        double baseMinWidth = baseTag switch
        {
            "Freecell"   => tag == "Freecell2" ? 1390 : 1120,
            "Spider"     => 1450,
            "VideoPoker" => 700,
            "Blackjack"  => 700,
            _            => 1060,
        };
        double baseMinHeight = baseTag switch
        {
            "VideoPoker" => 580,
            // Must match GameOptions.BlackjackHeight's default (950) — that's the actual
            // content height needed to fit dealer/player cards + action buttons without
            // clipping; a lower floor let the window (and saved BlackjackHeight) shrink
            // below what the board needs.
            "Blackjack"  => 950,
            // These three floors are sized so a maxed-out tableau column — a full
            // King-to-2 run (12 face-up cards) for Klondike/Freecell, or a completed
            // 13-card same-suit run for Spider — fits under the toolbar without being
            // clipped or scrolled out of view. Math.Max(MinHeight, saved height) in
            // RestoreWindowSizeForGame means this also repairs any already-saved
            // window height that was set before this floor existed.
            "Klondike"   => 900,
            "Freecell"   => 1050,
            "Spider"     => 950,
            _            => 640,
        };
        return (baseMinWidth * zoom, baseMinHeight * zoom);
    }

    private DispatcherTimer? _windowResizeTimer;

    // Scales the window's *current* size by the zoom delta (rather than jumping to an
    // absolute size), so whatever aspect ratio the window currently has — the default,
    // or one the user manually resized to — is preserved as zoom changes, growing on
    // zoom-in and shrinking on zoom-out.
    private void SnapWindowToZoom(double oldZoom, double newZoom)
    {
        var (minW, minH) = ComputeBoardMinSize(_currentGameTag, newZoom);
        this.MinWidth = minW;
        this.MinHeight = minH;

        if (WindowState == WindowState.Maximized) return;

        double ratio = oldZoom > 0 ? newZoom / oldZoom : 1.0;
        double targetW = Math.Max(minW, Width * ratio);
        double targetH = Math.Max(minH, Height * ratio);
        if (targetW == Width && targetH == Height) return;

        double startW = Width, startH = Height;

        _windowResizeTimer?.Stop();
        double elapsed = 0;
        const double durationMs = 200;
        _windowResizeTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _windowResizeTimer.Tick += (_, _) =>
        {
            elapsed += 16;
            double t = Math.Min(1.0, elapsed / durationMs);
            Width  = startW + (targetW - startW) * t;
            Height = startH + (targetH - startH) * t;
            if (t >= 1.0)
            {
                _windowResizeTimer!.Stop();
                _windowResizeTimer = null;
            }
        };
        _windowResizeTimer.Start();
    }

    private void ApplyZoom(double zoom)
    {
        zoom = Math.Clamp(zoom, 0.6, 2.0);
        double oldZoom = GetGameZoom(_currentGameTag);
        var opts = _coordinator.GameViewModel.Options;
        switch (GetBaseGameTag(_currentGameTag))
        {
            case "Freecell":   opts.FreecellZoom    = zoom; break;
            case "Spider":     opts.SpiderZoom     = zoom; break;
            case "VideoPoker": opts.VideoPokerZoom = zoom; break;
            case "Blackjack":  opts.BlackjackZoom  = zoom; break;
            default:           opts.KlondikeZoom   = zoom; break;
        }
        _contentScale.ScaleX = zoom;
        _contentScale.ScaleY = zoom;
        SettingsService.SaveOptions(opts);
        ApplyZoomGap(zoom);
        SnapWindowToZoom(oldZoom, zoom);
    }

    private void ApplyZoomGap(double zoom)
    {
        switch (GetBaseGameTag(_currentGameTag))
        {
            case "Klondike":
                (MainContent.Content as GameView)?.ApplyZoomGap(zoom);
                break;
            case "Freecell":
                (MainContent.Content as FreecellView)?.ApplyZoomGap(zoom);
                break;
            case "Spider":
                (MainContent.Content as SpiderView)?.ApplyZoomGap(zoom);
                break;
        }
    }

    private void ZoomIn_Click(object? sender, RoutedEventArgs e) =>
        ApplyZoom(GetGameZoom(_currentGameTag) + 0.1);

    private void ZoomOut_Click(object? sender, RoutedEventArgs e) =>
        ApplyZoom(GetGameZoom(_currentGameTag) - 0.1);

    private void ResetZoom_Click(object? sender, RoutedEventArgs e) =>
        ApplyZoom(GetGameDefaultZoom(_currentGameTag));

    private void MakeCurrentZoomDefault_Click(object? sender, RoutedEventArgs e) =>
        MakeCurrentZoomDefault();

    private void OnPointerWheelChanged(object? sender, PointerWheelEventArgs e)
    {
        if ((e.KeyModifiers & KeyModifiers.Control) == 0) return;
        e.Handled = true;
        double step = e.Delta.Y > 0 ? 0.1 : -0.1;
        ApplyZoom(GetGameZoom(_currentGameTag) + step);
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
            if (e.Key == Key.OemPlus || e.Key == Key.Add)
            {
                e.Handled = true;
                ApplyZoom(GetGameZoom(_currentGameTag) + 0.1);
            }
            else if (e.Key == Key.OemMinus || e.Key == Key.Subtract)
            {
                e.Handled = true;
                ApplyZoom(GetGameZoom(_currentGameTag) - 0.1);
            }
            else if (e.Key == Key.D0 || e.Key == Key.NumPad0)
            {
                e.Handled = true;
                ApplyZoom(GetGameDefaultZoom(_currentGameTag));
            }
            else if (e.Key == Key.N)
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
                if (isCardGame && HintButton?.IsEnabled != false)
                {
                    e.Handled = true;
                    Hint_Click(null, new RoutedEventArgs());
                }
            }
        }
    }
}
