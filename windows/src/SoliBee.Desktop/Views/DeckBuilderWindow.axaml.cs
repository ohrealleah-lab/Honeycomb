using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Media;
using SoliBee.Core.Models;

namespace SoliBee.Desktop.Views;

public partial class DeckBuilderWindow : Window
{
    private int _deckSlotIndex = 0;
    private List<int> _currentCardIds = new List<int>();
    private List<HoneycombCardData> _bankCards = new List<HoneycombCardData>();
    
    // For editing an existing deck
    public DeckBuilderWindow(int deckSlotIndex)
    {
        InitializeComponent();
        _deckSlotIndex = deckSlotIndex;
        
        LoadData();
        RefreshUI();
    }
    
    // Default constructor for designer
    public DeckBuilderWindow() : this(0)
    {
    }

    private void LoadData()
    {
        var pm = HoneycombProfileManager.Shared;
        
        if (_deckSlotIndex >= 0 && _deckSlotIndex < pm.SavedDecks.Count)
        {
            var deckState = pm.SavedDecks[_deckSlotIndex];
            DeckNameTextBox.Text = deckState.Name;
            _currentCardIds = new List<int>(deckState.CardIds);
        }
        
        DeckNameTextBox.TextChanged += (s, e) => ValidateRealtime();
        
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
        // Refresh Deck Slots
        DeckSlotsPanel.Children.Clear();
        for (int i = 0; i < 5; i++)
        {
            var border = new Border
            {
                Width = 100, Height = 141,
                Background = new SolidColorBrush(Color.Parse("#D0D0D0")),
                CornerRadius = new Avalonia.CornerRadius(6),
                Margin = new Avalonia.Thickness(5)
            };
            
            if (i < _currentCardIds.Count)
            {
                var cardData = HoneycombDatabase.Shared.Card(_currentCardIds[i]);
                if (cardData != null)
                {
                    var cardObj = new HoneycombCard(cardData, 1);
                    var cardView = new HoneycombCardView { Width = 100, Height = 141 };
                    await cardView.RenderCard(cardObj);
                    
                    var b = new Button
                    {
                        Content = cardView,
                        Background = Brushes.Transparent,
                        Padding = new Avalonia.Thickness(0),
                        Tag = cardData.Id
                    };
                    b.Click += RemoveCard_Click;
                    border.Child = b;
                }
            }
            DeckSlotsPanel.Children.Add(border);
        }
        
        YourDeckTitle.Text = $"Your Deck ({_currentCardIds.Count}/5) - Tap to Remove";
        
        // Refresh Bank
        BankPanel.Children.Clear();
        
        int starsFilter = StarsFilter.SelectedIndex; // 0=All, 1=1Star, etc.
        int suitsFilter = SuitsFilter.SelectedIndex; // 0=All, 1=Spades, 2=Hearts, 3=Diamonds, 4=Clubs
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
            filtered = filtered.Where(c => HoneycombProfileManager.Shared.FavoriteCardIds.Contains(c.Id));
        }
        
        // Sort by Stars desc, then Suit, then Id
        filtered = filtered.OrderByDescending(c => c.Stars).ThenBy(c => c.Suit).ThenByDescending(c => c.Id);
        
        foreach (var c in filtered)
        {
            var cardObj = new HoneycombCard(c, 1);
            var cardView = new HoneycombCardView { Width = 110, Height = 155, Margin = new Avalonia.Thickness(5) };
            // Fire and forget render
            _ = cardView.RenderCard(cardObj);
            
            var b = new Button
            {
                Content = cardView,
                Background = Brushes.Transparent,
                Padding = new Avalonia.Thickness(0),
                Tag = c.Id
            };
            
            // Disable if already in deck
            if (_currentCardIds.Contains(c.Id))
            {
                b.IsEnabled = false;
                b.Opacity = 0.5;
            }
            
            b.Click += AddCard_Click;
            BankPanel.Children.Add(b);
        }
        
        ValidateRealtime();
    }
    
    private void ValidateRealtime()
    {
        var pm = HoneycombProfileManager.Shared;
        string deckName = DeckNameTextBox.Text?.Trim() ?? "";
        bool isValid = pm.ValidateDeck(_currentCardIds, deckName, out string err);
        
        ErrorText.Text = err;
        SaveButton.IsEnabled = isValid;
    }

    private void AddCard_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button b && b.Tag is int id)
        {
            if (_currentCardIds.Count < 5 && !_currentCardIds.Contains(id))
            {
                _currentCardIds.Add(id);
                RefreshUI();
            }
        }
    }
    
    private void RemoveCard_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button b && b.Tag is int id)
        {
            _currentCardIds.Remove(id);
            RefreshUI();
        }
    }

    private void FilterCombo_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        RefreshUI();
    }

    private void FilterToggle_CheckedChanged(object? sender, RoutedEventArgs e)
    {
        RefreshUI();
    }

    private void Save_Click(object? sender, RoutedEventArgs e)
    {
        var pm = HoneycombProfileManager.Shared;
        string deckName = DeckNameTextBox.Text?.Trim() ?? "";
        if (pm.ValidateDeck(_currentCardIds, deckName, out string err))
        {
            pm.SavedDecks[_deckSlotIndex].Name = deckName;
            pm.SavedDecks[_deckSlotIndex].CardIds = new List<int>(_currentCardIds);
            pm.SaveSavedDecks();
            
            Close();
        }
        else
        {
            ErrorText.Text = err;
        }
    }

    private void Cancel_Click(object? sender, RoutedEventArgs e)
    {
        Close();
    }
}
