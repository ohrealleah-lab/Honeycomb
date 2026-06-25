using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public partial class MainWindow : Window
{
    private AppCoordinator _coordinator;
    private ThemeEditorWindow? _themeEditor;

    public MainWindow()
    {
        InitializeComponent();
        
        _coordinator = new AppCoordinator();
        
        // Select correct Klondike mode on startup based on options
        bool isDrawThree = _coordinator.GameViewModel.Options.IsDrawConstraintsEnabled;
        GameSelectionBox.SelectedIndex = isDrawThree ? 2 : 1;

        this.MainContent.Content = new GameView { DataContext = _coordinator.GameViewModel };
        this.DataContext = _coordinator.GameViewModel;

        // Register to listen to OptionsChangedMessage to keep Window background color in sync
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            ApplyFeltColor(m.Options);
        });

        // Set initial background color
        ApplyFeltColor(_coordinator.GameViewModel.Options);

        // Apply any saved theme color overrides before first render
        CardView.ApplyThemeColors(_coordinator.GameViewModel.Options);

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
        {
            klondikeVm.InitializeGame();
        }
        else if (this.DataContext is BeecellViewModel freecellVm)
        {
            freecellVm.InitializeGame();
        }
        else if (this.DataContext is SpiderViewModel spiderVm)
        {
            spiderVm.InitializeGame();
        }
    }

    private void RestartGame_Click(object? sender, RoutedEventArgs e)
    {
        if (this.DataContext is GameViewModel klondikeVm)
        {
            klondikeVm.RestartGame();
        }
        else if (this.DataContext is BeecellViewModel freecellVm)
        {
            freecellVm.RestartGame();
        }
        else if (this.DataContext is SpiderViewModel spiderVm)
        {
            spiderVm.RestartGame();
        }
    }

    private void Undo_Click(object? sender, RoutedEventArgs e)
    {
        if (this.DataContext is GameViewModel klondikeVm)
            klondikeVm.UndoCommand.Execute(null);
        else if (this.DataContext is BeecellViewModel beecellVm)
            beecellVm.Undo();
        else if (this.DataContext is SpiderViewModel spiderVm)
            spiderVm.Undo();
    }

    private void Autocomplete_Click(object? sender, RoutedEventArgs e)
    {
        if (this.DataContext is GameViewModel klondikeVm)
        {
            klondikeVm.AutocompleteCommand.Execute(null);
        }
    }

    private void Preferences_Click(object? sender, RoutedEventArgs e)
    {
        GameOptions? options = this.DataContext switch
        {
            GameViewModel vm => vm.Options,
            BeecellViewModel vm => vm.Options,
            SpiderViewModel vm => vm.Options,
            _ => null
        };

        if (options != null)
        {
            var preferencesView = new PreferencesView();
            preferencesView.DataContext = options;
            preferencesView.ShowVegasOption = this.DataContext is GameViewModel;
            this.PreferencesContent.Content = preferencesView;
            this.PreferencesOverlay.IsVisible = true;
        }
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

    private void ResizeWindowForGame(string tag)
    {
        (double width, double minWidth) = tag switch
        {
            "Beecell"       => (1200, 1140),
            "Spider"        => (1460, 1420),
            _               => (1120, 1080),  // Klondike Draw1/Draw3
        };
        this.Width    = Math.Max(this.Width,    width);
        this.MinWidth = minWidth;
        if (this.Width < width) this.Width = width;
    }

    private void GameSelectionBox_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (GameSelectionBox == null || _coordinator == null) return;

        if (GameSelectionBox.SelectedItem is ComboBoxItem item && item.Tag != null)
        {
            var tag = item.Tag.ToString();
            ResizeWindowForGame(tag ?? "");
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

            this.DataContext = _coordinator.ActiveViewModel;

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
        }
    }
}
