using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public partial class MainWindow : Window
{
    private AppCoordinator _coordinator;
    private ThemeEditorWindow? _themeEditor;
    private readonly ScaleTransform _contentScale = new(1.0, 1.0);
    private string _currentGameTag = "SolitaireDraw1";

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

    private void NewGame_Click(object? sender, RoutedEventArgs e)
    {
        if (this.DataContext is GameViewModel klondikeVm)
            klondikeVm.InitializeGame();
        else if (this.DataContext is BeecellViewModel freecellVm)
            freecellVm.InitializeGame();
        else if (this.DataContext is SpiderViewModel spiderVm)
            spiderVm.InitializeGame();
        else if (this.DataContext is VideoPokerViewModel vpVm)
            vpVm.StartNewGame();
    }

    private void RestartGame_Click(object? sender, RoutedEventArgs e)
    {
        if (this.DataContext is GameViewModel klondikeVm)
            klondikeVm.RestartGame();
        else if (this.DataContext is BeecellViewModel freecellVm)
            freecellVm.RestartGame();
        else if (this.DataContext is SpiderViewModel spiderVm)
            spiderVm.RestartGame();
        else if (this.DataContext is VideoPokerViewModel vpVm)
            vpVm.StartNewGame();
    }

    private void Undo_Click(object? sender, RoutedEventArgs e)
    {
        if (this.DataContext is GameViewModel klondikeVm)
            klondikeVm.UndoCommand.Execute(null);
        else if (this.DataContext is BeecellViewModel beecellVm)
            beecellVm.Undo();
        else if (this.DataContext is SpiderViewModel spiderVm)
            spiderVm.Undo();
        // Video Poker has no undo
    }

    private void Hint_Click(object? sender, RoutedEventArgs e)
    {
        if (this.DataContext is GameViewModel klondikeVm)
            klondikeVm.FindHint();
        else if (this.DataContext is BeecellViewModel beecellVm)
            beecellVm.FindHint();
        else if (this.DataContext is SpiderViewModel spiderVm)
            spiderVm.FindHint();
        // Video Poker has no hint
    }

    private void Preferences_Click(object? sender, RoutedEventArgs e)
    {
        GameOptions options = this.DataContext switch
        {
            GameViewModel vm        => vm.Options,
            BeecellViewModel vm     => vm.Options,
            SpiderViewModel vm      => vm.Options,
            VideoPokerViewModel _   => _coordinator.GameViewModel.Options,
            _                       => _coordinator.GameViewModel.Options
        };

        var preferencesView = new PreferencesView();
        preferencesView.DataContext = options;
        preferencesView.ShowVegasOption = this.DataContext is GameViewModel;
        this.PreferencesContent.Content = preferencesView;
        this.PreferencesOverlay.IsVisible = true;
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
        this.PreferencesOverlay.IsVisible = false;
        this.PreferencesContent.Content = null;
    }

    private static int GameModeToIndex(string tag) => tag switch
    {
        "SolitaireDraw3" => 2,
        "Beecell"        => 3,
        "Spider"         => 4,
        "VideoPoker"     => 5,
        _                => 1,
    };

    private void ResizeWindowForGame(string tag)
    {
        this.MinWidth = tag switch
        {
            "Beecell"    => 1140,
            "Spider"     => 1420,
            "VideoPoker" => 1050,
            _            => 1080,
        };
    }

    private void GameSelectionBox_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (GameSelectionBox == null || _coordinator == null) return;

        if (GameSelectionBox.SelectedItem is ComboBoxItem item && item.Tag != null)
        {
            var tag = item.Tag.ToString() ?? "SolitaireDraw1";
            SaveCurrentWindowSize();   // capture size of the game we're leaving
            _currentGameTag = tag;
            ResizeWindowForGame(tag);  // sets MinWidth only
            if (tag == "SolitaireDraw1" || tag == "SolitaireDraw3")
            {
                bool wantDrawThree = (tag == "SolitaireDraw3");
                if (_coordinator.GameViewModel.Options.IsDrawConstraintsEnabled != wantDrawThree || _coordinator.ActiveViewModel != _coordinator.GameViewModel)
                {
                    _coordinator.GameViewModel.Options.IsDrawConstraintsEnabled = wantDrawThree;
                    SettingsService.SaveOptions(_coordinator.GameViewModel.Options);
                    _coordinator.GameViewModel.InitializeGame();
                }

                _coordinator.SwitchToGame();
                this.MainContent.Content = new GameView { DataContext = _coordinator.GameViewModel };
            }
            else if (tag == "Beecell")
            {
                _coordinator.SwitchToBeecell();
                this.MainContent.Content = new BeecellView { DataContext = _coordinator.BeecellViewModel };
            }
            else if (tag == "Spider")
            {
                _coordinator.SwitchToSpider();
                this.MainContent.Content = new SpiderView { DataContext = _coordinator.SpiderViewModel };
            }
            else if (tag == "VideoPoker")
            {
                _coordinator.SwitchToVideoPoker();
                this.MainContent.Content = new VideoPokerView { DataContext = _coordinator.VideoPokerViewModel };
            }

            this.DataContext = _coordinator.ActiveViewModel;

            // Restore zoom and window size for the newly selected game
            ApplyZoom(GetGameZoom(tag));
            RestoreWindowSizeForGame(tag);

            if (HintButton != null)
                HintButton.IsVisible = tag != "VideoPoker";
            if (UndoButton != null)
                UndoButton.IsVisible = tag != "VideoPoker";

            _coordinator.GameViewModel.Options.LastGameMode = tag;
            SettingsService.SaveOptions(_coordinator.GameViewModel.Options);

            // Apply felt color of the active VM
            if (_coordinator.ActiveViewModel is GameViewModel klondikeVm)
            {
                ApplyFeltColor(klondikeVm.Options);
            }
            else if (_coordinator.ActiveViewModel is BeecellViewModel freecellVm)
            {
                ApplyFeltColor(freecellVm.Options);
            }
            else if (_coordinator.ActiveViewModel is SpiderViewModel spiderVm)
            {
                ApplyFeltColor(spiderVm.Options);
            }
            else if (_coordinator.ActiveViewModel is VideoPokerViewModel)
            {
                ApplyFeltColor(_coordinator.GameViewModel.Options);
            }
        }
    }

    // ── Per-game window size ──────────────────────────────────────────────────

    private void SaveCurrentWindowSize()
    {
        if (_coordinator == null) return;
        var opts = _coordinator.GameViewModel.Options;
        bool maximized = WindowState == WindowState.Maximized;
        switch (_currentGameTag)
        {
            case "Beecell":
                if (!maximized) { opts.BeecellWidth = Width; opts.BeecellHeight = Height; }
                opts.BeecellMaximized = maximized;
                break;
            case "Spider":
                if (!maximized) { opts.SpiderWidth = Width; opts.SpiderHeight = Height; }
                opts.SpiderMaximized = maximized;
                break;
            case "VideoPoker":
                if (!maximized) { opts.VideoPokerWidth = Width; opts.VideoPokerHeight = Height; }
                opts.VideoPokerMaximized = maximized;
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
        (double w, double h, bool max) = tag switch
        {
            "Beecell"    => (opts.BeecellWidth,    opts.BeecellHeight,    opts.BeecellMaximized),
            "Spider"     => (opts.SpiderWidth,     opts.SpiderHeight,     opts.SpiderMaximized),
            "VideoPoker" => (opts.VideoPokerWidth, opts.VideoPokerHeight, opts.VideoPokerMaximized),
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

    private double GetGameZoom(string tag) => tag switch
    {
        "Beecell"    => _coordinator.GameViewModel.Options.BeecellZoom,
        "Spider"     => _coordinator.GameViewModel.Options.SpiderZoom,
        "VideoPoker" => _coordinator.GameViewModel.Options.VideoPokerZoom,
        _            => _coordinator.GameViewModel.Options.KlondikeZoom,
    };

    private void ApplyZoom(double zoom)
    {
        zoom = Math.Clamp(zoom, 0.5, 1.5);
        var opts = _coordinator.GameViewModel.Options;
        switch (_currentGameTag)
        {
            case "Beecell":    opts.BeecellZoom    = zoom; break;
            case "Spider":     opts.SpiderZoom     = zoom; break;
            case "VideoPoker": opts.VideoPokerZoom = zoom; break;
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
        if (e.Key == Key.Escape && PreferencesOverlay.IsVisible)
        {
            e.Handled = true;
            PreferencesOverlay.IsVisible = false;
            PreferencesContent.Content = null;
            return;
        }

        if ((e.KeyModifiers & KeyModifiers.Control) == 0) return;
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
    }
}
