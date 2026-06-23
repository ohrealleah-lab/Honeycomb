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
            ApplyFeltColor(m.Options.FeltColor);
        });

        // Set initial background color
        ApplyFeltColor(_coordinator.GameViewModel.Options.FeltColor);
    }

    private void ApplyFeltColor(FeltColorTheme feltColor)
    {
        string primaryHex = "#008000";
        string statusHex = "#007300";

        if (feltColor == FeltColorTheme.Custom)
        {
            var options = SettingsService.LoadOptions();
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
        {
            klondikeVm.UndoCommand.Execute(null);
        }
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
        if (this.DataContext is GameViewModel klondikeVm)
        {
            var preferencesView = new PreferencesView();
            preferencesView.DataContext = klondikeVm.Options;
            this.PreferencesContent.Content = preferencesView;
            this.PreferencesOverlay.IsVisible = true;
        }
    }

    private void ClosePreferences_Click(object? sender, RoutedEventArgs e)
    {
        this.PreferencesOverlay.IsVisible = false;
        this.PreferencesContent.Content = null;
    }

    private void GameSelectionBox_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (GameSelectionBox == null || _coordinator == null) return;

        if (GameSelectionBox.SelectedItem is ComboBoxItem item && item.Tag != null)
        {
            var tag = item.Tag.ToString();
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
                this.MainContent.Content = new TextBlock
                {
                    Text = "Freecell - Coming Soon!",
                    Foreground = Avalonia.Media.Brushes.White,
                    FontSize = 24,
                    FontWeight = Avalonia.Media.FontWeight.Bold,
                    HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
                    VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center
                };
            }
            else if (tag == "Spider")
            {
                _coordinator.SwitchToSpider();
                this.MainContent.Content = new TextBlock
                {
                    Text = "Spider Solitaire - Coming Soon!",
                    Foreground = Avalonia.Media.Brushes.White,
                    FontSize = 24,
                    FontWeight = Avalonia.Media.FontWeight.Bold,
                    HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
                    VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center
                };
            }

            this.DataContext = _coordinator.ActiveViewModel;

            // Apply felt color of the active VM
            if (_coordinator.ActiveViewModel is GameViewModel klondikeVm)
            {
                ApplyFeltColor(klondikeVm.Options.FeltColor);
            }
            else if (_coordinator.ActiveViewModel is BeecellViewModel freecellVm)
            {
                ApplyFeltColor(freecellVm.Options.FeltColor);
            }
            else if (_coordinator.ActiveViewModel is SpiderViewModel spiderVm)
            {
                ApplyFeltColor(spiderVm.Options.FeltColor);
            }
        }
    }
}
