using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Layout;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

public partial class ManageDecksView : UserControl
{
    private List<HoneycombCardData> _bankCards = new List<HoneycombCardData>();
    
    public ManageDecksView()
    {
        InitializeComponent();
        LoadBank();
        RefreshUI();
    }
    
    private void LoadBank()
    {
        var pm = HoneycombProfileManager.Shared;
        _bankCards.Clear();
        foreach (var id in pm.UnlockedCardIds)
        {
            var card = HoneycombDatabase.Shared.Card(id);
            if (card != null)
                _bankCards.Add(card);
        }
    }

    private async void RefreshUI()
    {
        var pm = HoneycombProfileManager.Shared;
        var opts = SettingsService.LoadOptions();
        int activeIndex = opts.HoneycombActiveDeckIndex;
        
        // Refresh Decks List
        DecksListPanel.Children.Clear();
        for (int i = 0; i < 5; i++)
        {
            var deckState = pm.SavedDecks[i];
            bool isActive = (i == activeIndex);
            
            var border = new Border
            {
                Background = new SolidColorBrush(Color.Parse("#E0E0E0")),
                CornerRadius = new Avalonia.CornerRadius(8),
                Padding = new Avalonia.Thickness(15)
            };
            
            var grid = new Grid { RowDefinitions = new RowDefinitions("Auto, Auto") };
            
            var headerPanel = new DockPanel { Margin = new Avalonia.Thickness(0,0,0,10) };
            
            var titleStack = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 };
            titleStack.Children.Add(new TextBlock { Text = deckState.Name, FontWeight = Avalonia.Media.FontWeight.Bold, FontSize = 16, Foreground = Brushes.Black, VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center });
            
            if (isActive)
            {
                titleStack.Children.Add(new TextBlock { Text = "(Active)", Foreground = Brushes.Green, VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center });
            }
            
            DockPanel.SetDock(titleStack, Dock.Left);
            headerPanel.Children.Add(titleStack);
            
            var actionBtn = new Button 
            { 
                Content = deckState.CardIds.Count == 0 ? "Create" : "Edit",
                Classes = { "light-secondary" },
                Tag = i
            };
            actionBtn.Click += EditDeck_Click;
            DockPanel.SetDock(actionBtn, Dock.Right);
            actionBtn.HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right;
            headerPanel.Children.Add(actionBtn);
            
            if (!isActive && deckState.CardIds.Count == 5)
            {
                var activateBtn = new Button 
                { 
                    Content = "Make Active",
                    Classes = { "light-secondary" },
                    Tag = i,
                    Margin = new Avalonia.Thickness(0,0,10,0)
                };
                activateBtn.Click += (s, e) => {
                    var o = SettingsService.LoadOptions();
                    o.HoneycombActiveDeckIndex = i;
                    SettingsService.SaveOptions(o);
                    RefreshUI();
                };
                DockPanel.SetDock(activateBtn, Dock.Right);
                headerPanel.Children.Add(activateBtn);
            }
            
            Grid.SetRow(headerPanel, 0);
            grid.Children.Add(headerPanel);
            
            var cardsPanel = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 };
            for (int j = 0; j < 5; j++)
            {
                var cardContainer = new Border
                {
                    Width = 60, Height = 84,
                    Background = Brushes.White,
                    CornerRadius = new Avalonia.CornerRadius(4),
                    BorderBrush = Brushes.Gray,
                    BorderThickness = new Avalonia.Thickness(1)
                };
                
                if (j < deckState.CardIds.Count)
                {
                    var cardData = HoneycombDatabase.Shared.Card(deckState.CardIds[j]);
                    if (cardData != null)
                    {
                        var cardObj = new HoneycombCard(cardData, 1);
                        var cardView = new HoneycombCardView();
                        await cardView.RenderCard(cardObj);
                        var vb = new Viewbox { Child = cardView };
                        cardContainer.Child = vb;
                    }
                }
                cardsPanel.Children.Add(cardContainer);
            }
            
            Grid.SetRow(cardsPanel, 1);
            grid.Children.Add(cardsPanel);
            
            border.Child = grid;
            
            if (isActive)
            {
                var activeBorder = new Border
                {
                    BorderBrush = Brushes.Green,
                    BorderThickness = new Avalonia.Thickness(2),
                    CornerRadius = new Avalonia.CornerRadius(10),
                    Child = border,
                    Padding = new Avalonia.Thickness(2)
                };
                DecksListPanel.Children.Add(activeBorder);
            }
            else
            {
                DecksListPanel.Children.Add(border);
            }
        }
        
        // Refresh Bank
        BankPanel.Children.Clear();
        
        int starsFilter = StarsFilter.SelectedIndex;
        int suitsFilter = SuitsFilter.SelectedIndex;
        bool favsOnly = FavoritesFilter.IsChecked == true;
        
        var filtered = _bankCards.AsEnumerable();
        
        if (starsFilter > 0)
            filtered = filtered.Where(c => c.Stars == starsFilter);
            
        if (suitsFilter > 0)
        {
            var suitEnum = (CardSuit)(suitsFilter - 1);
            var suitStr = suitEnum.ToString();
            filtered = filtered.Where(c => c.Suit == suitStr);
        }
        
        if (favsOnly)
        {
            filtered = filtered.Where(c => pm.FavoriteCardIds.Contains(c.Id));
        }
        
        filtered = filtered.OrderByDescending(c => c.Stars).ThenBy(c => c.Suit).ThenByDescending(c => c.Id);
        
        var filteredList = filtered.ToList();
        
        CardCountText.Text = $"{filteredList.Count}/{pm.UnlockedCardIds.Count} shown";
        
        foreach (var c in filteredList)
        {
            var cardObj = new HoneycombCard(c, 1);
            var cardView = new HoneycombCardView();
            _ = cardView.RenderCard(cardObj);
            
            var vb = new Viewbox { Width = 85, Height = 120, Margin = new Avalonia.Thickness(5), Child = cardView };
            
            var b = new Border
            {
                Child = vb,
                Background = Brushes.Transparent,
            };
            
            BankPanel.Children.Add(b);
        }
    }

    private async void EditDeck_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button b && b.Tag is int slotIndex)
        {
            var builder = new DeckBuilderWindow(slotIndex);
            var window = TopLevel.GetTopLevel(this) as Window;
            if (window != null)
            {
                await builder.ShowDialog(window);
                RefreshUI();
            }
        }
    }

    private void StartOver_Click(object? sender, RoutedEventArgs e)
    {
        var pm = HoneycombProfileManager.Shared;
        pm.StartOver();
        
        var opts = SettingsService.LoadOptions();
        opts.HoneycombActiveDeckIndex = 0;
        opts.PlayerDeckIds = new List<int>(pm.SavedDecks[0].CardIds);
        SettingsService.SaveOptions(opts);
        
        LoadBank();
        RefreshUI();
    }

    private void FilterCombo_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (BankPanel != null)
        {
            RefreshUI();
        }
    }

    private void FilterToggle_CheckedChanged(object? sender, RoutedEventArgs e)
    {
        if (BankPanel != null)
        {
            RefreshUI();
        }
    }
}
