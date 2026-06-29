using System;
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
    private DispatcherTimer? _prefSlideTimer;
    private string _pendingAction = "";
    private bool _revertingSelection = false;
    private PreferencesView? _preferencesView;

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

        // Register to listen to OptionsChangedMessage to keep Window background color in sync
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            ApplyFeltColor(m.Options);
            CardView.ApplyThemeColors(m.Options);
            CardView.InvalidateAllCardViews(this);
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
            {
                TopBarBorder.Background = new Avalonia.Media.SolidColorBrush(Avalonia.Media.Color.Parse(statusHex));
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
        }
        _pendingAction = "";
    }

    private void CancelConfirmAction_Click(object? sender, RoutedEventArgs e)
    {
        ConfirmActionOverlay.IsVisible = false;
        _pendingAction = "";
    }

    private void OnGameModeChangeRequested(object? sender, string newTag)
    {
        if (!IsGameInProgress())
        {
            ApplyGameModeChange(newTag);
            return;
        }
        _preferencesView?.RevertGameModeCombo();
        _pendingAction = "GameMode:" + newTag;
        ConfirmActionTitle.Text   = "Change Game Mode?";
        ConfirmActionMessage.Text = "Are you sure you want to abandon the current game and change mode?";
        ConfirmActionButton.Content = "Change Mode";
        ConfirmActionOverlay.IsVisible = true;
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

    private void Preferences_Click(object? sender, RoutedEventArgs e)
    {
        GameOptions options = this.DataContext switch
        {
            GameViewModel vm        => vm.Options,
            FreecellViewModel vm     => vm.Options,
            SpiderViewModel vm      => vm.Options,
            VideoPokerViewModel _   => _coordinator.GameViewModel.Options,
            _                       => _coordinator.GameViewModel.Options
        };

        _preferencesView = new PreferencesView();
        _preferencesView.DataContext = options;
        _preferencesView.ShowVegasOption = this.DataContext is GameViewModel;
        _preferencesView.ActiveGameFamily = this.DataContext switch
        {
            GameViewModel _      => "Klondike",
            FreecellViewModel _  => "Freecell",
            SpiderViewModel _    => "Spider",
            _                    => "",
        };
        _preferencesView.GameModeChangeRequested += OnGameModeChangeRequested;
        this.PreferencesContent.Content = _preferencesView;
        this.PreferencesOverlay.IsVisible = true;
        SlideInPreferences();
    }

    private void SlideInPreferences()
    {
        _prefSlideTimer?.Stop();
        PreferencesPanel.RenderTransform = new TranslateTransform(360, 0);
        double elapsed = 0;
        _prefSlideTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _prefSlideTimer.Tick += (_, _) =>
        {
            elapsed += 16;
            double t    = Math.Min(1.0, elapsed / 220.0);
            double ease = 1 - Math.Pow(1 - t, 3);
            if (PreferencesPanel.RenderTransform is TranslateTransform tx) tx.X = 360 * (1.0 - ease);
            if (t >= 1.0) { _prefSlideTimer!.Stop(); _prefSlideTimer = null; }
        };
        _prefSlideTimer.Start();
    }

    private void SlideOutAndClosePreferences()
    {
        _prefSlideTimer?.Stop();
        double startX   = PreferencesPanel.RenderTransform is TranslateTransform tx0 ? tx0.X : 0;
        double elapsed  = 0;
        _prefSlideTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _prefSlideTimer.Tick += (_, _) =>
        {
            elapsed += 16;
            double t    = Math.Min(1.0, elapsed / 160.0);
            double ease = t * t;
            if (PreferencesPanel.RenderTransform is TranslateTransform tx) tx.X = startX + (360 - startX) * ease;
            if (t >= 1.0)
            {
                _prefSlideTimer!.Stop();
                _prefSlideTimer = null;
                this.PreferencesOverlay.IsVisible = false;
                this.PreferencesContent.Content   = null;
                if (PreferencesPanel.RenderTransform is TranslateTransform tx2) tx2.X = 0;
            }
        };
        _prefSlideTimer.Start();
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
        => SlideOutAndClosePreferences();

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
        string baseTag = GetBaseGameTag(tag);
        this.MinWidth = baseTag switch
        {
            "Freecell"   => tag == "Freecell2" ? 1420 : 1140,
            "Spider"     => 1420,
            "VideoPoker" => 1050,
            "Blackjack"  => 1000,
            _            => 1080,
        };
        
        this.MinHeight = tag switch
        {
            "Blackjack" => 920,
            "Freecell2" => 950,
            "Freecell1" => 850,
            "Spider1"   => 850,
            "Spider2"   => 850,
            "Spider4"   => 850,
            _           => 750
        };
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
            "Freecell" => opts.FreecellDeckCount == 2   ? "Freecell2"      : "Freecell1",
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
        ResizeWindowForGame(tag);

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
            if (_coordinator.GameViewModel.Options.IsDrawConstraintsEnabled != wantDrawThree
                || _coordinator.ActiveViewModel != _coordinator.GameViewModel)
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
            if (opts.FreecellDeckCount != deckCount || _coordinator.ActiveViewModel != _coordinator.FreecellViewModel)
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
            if (opts.SpiderSuitCount != suitCount || _coordinator.ActiveViewModel != _coordinator.SpiderViewModel)
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
            this.MainContent.Content = new BlackjackView { DataContext = _coordinator.BlackjackViewModel };
        }

        this.DataContext = _coordinator.ActiveViewModel;
        ApplyZoom(GetGameZoom(tag));
        RestoreWindowSizeForGame(tag);

        bool isCardGame = tag != "VideoPoker" && tag != "Blackjack";
        if (HintButton != null)    HintButton.IsVisible    = isCardGame;
        if (UndoButton != null)    UndoButton.IsVisible    = isCardGame;
        if (TimeStatPanel != null) TimeStatPanel.IsVisible = isCardGame;
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

    private void ApplyZoom(double zoom)
    {
        zoom = Math.Clamp(zoom, 0.5, 1.5);
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
    }

    private void OnPointerWheelChanged(object? sender, PointerWheelEventArgs e)
    {
        if ((e.KeyModifiers & KeyModifiers.Control) == 0) return;
        e.Handled = true;
        double step = e.Delta.Y > 0 ? 0.05 : -0.05;
        ApplyZoom(GetGameZoom(_currentGameTag) + step);
    }

    private void OnWindowKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            if (ConfirmActionOverlay != null && ConfirmActionOverlay.IsVisible)
            {
                e.Handled = true;
                ConfirmActionOverlay.IsVisible = false;
                _pendingAction = "";
                return;
            }
            if (PreferencesOverlay != null && PreferencesOverlay.IsVisible)
            {
                e.Handled = true;
                SlideOutAndClosePreferences();
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
                ApplyZoom(GetGameZoom(_currentGameTag) + 0.05);
            }
            else if (e.Key == Key.OemMinus || e.Key == Key.Subtract)
            {
                e.Handled = true;
                ApplyZoom(GetGameZoom(_currentGameTag) - 0.05);
            }
            else if (e.Key == Key.D0 || e.Key == Key.NumPad0)
            {
                e.Handled = true;
                ApplyZoom(1.0);
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
                if (isCardGame)
                {
                    e.Handled = true;
                    Undo_Click(null, new RoutedEventArgs());
                }
            }
            else if (e.Key == Key.H)
            {
                bool isCardGame = _currentGameTag != "VideoPoker" && _currentGameTag != "Blackjack";
                if (isCardGame)
                {
                    e.Handled = true;
                    Hint_Click(null, new RoutedEventArgs());
                }
            }
        }
    }
}
