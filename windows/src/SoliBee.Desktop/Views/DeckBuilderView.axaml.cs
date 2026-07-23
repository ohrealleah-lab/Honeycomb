using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Media;
using SoliBee.Core.Models;

namespace SoliBee.Desktop.Views;

public partial class DeckBuilderView : UserControl
{
    private int _deckSlotIndex;
    private List<int> _currentCardIds = new();
    private List<HoneycombCardData> _bankCards = new();

    // Opens for editing an existing slot (Create = empty slot, Edit = populated slot)
    public DeckBuilderView(int deckSlotIndex)
    {
        InitializeComponent();
        _deckSlotIndex = deckSlotIndex;
        LoadData();
        RefreshUI();
    }

    // Parameterless ctor required by Avalonia designer
    public DeckBuilderView()
    {
        InitializeComponent();
        LoadData();
        RefreshUI();
    }

    private void LoadData()
    {
        var pm = HoneycombProfileManager.Shared;

        if (_deckSlotIndex >= 0 && _deckSlotIndex < pm.SavedDecks.Count)
        {
            var deck = pm.SavedDecks[_deckSlotIndex];
            DeckNameTextBox.Text = deck.Name;
            _currentCardIds = new List<int>(deck.CardIds);
        }

        // Subscribe after setting initial text so we don't validate on load
        DeckNameTextBox.TextChanged += (_, _) => ValidateRealtime();

        _bankCards.Clear();
        foreach (var id in pm.UnlockedCardIds)
        {
            var c = HoneycombDatabase.Shared.Card(id);
            if (c != null) _bankCards.Add(c);
        }
    }

    // ── Synchronous refresh — no async, no await, no crash ────────────────
    private void RefreshUI()
    {
        RefreshDeckSlots();
        RefreshBank();
        ValidateRealtime();
    }

    private void RefreshDeckSlots()
    {
        DeckSlotsPanel.Children.Clear();

        for (int i = 0; i < 5; i++)
        {
            var slot = new Border
            {
                Width           = 90,
                Height          = 127,
                CornerRadius    = new Avalonia.CornerRadius(6),
                Background      = new SolidColorBrush(Color.Parse("#D8D8D8")),
                BorderBrush     = new SolidColorBrush(Color.Parse("#B0B0B0")),
                BorderThickness = new Avalonia.Thickness(1),
                Margin          = new Avalonia.Thickness(4)
            };

            if (i < _currentCardIds.Count)
            {
                var data = HoneycombDatabase.Shared.Card(_currentCardIds[i]);
                if (data != null)
                {
                    var cardObj  = new HoneycombCard(data, 1);
                    var cardView = new HoneycombCardView();
                    var vb = new Viewbox { Child = cardView };
                    _ = cardView.RenderCard(cardObj); // fire-and-forget

                    int captured = _currentCardIds[i];
                    var removeBtn = new Button
                    {
                        Content    = vb,
                        Background = Brushes.Transparent,
                        Padding    = new Avalonia.Thickness(0),
                        Tag        = captured
                    };
                    removeBtn.Click += RemoveCard_Click;
                    slot.Child = removeBtn;
                }
            }

            DeckSlotsPanel.Children.Add(slot);
        }

        YourDeckTitle.Text = $"Your Deck ({_currentCardIds.Count}/5) — Tap to Remove";
    }

    private void RefreshBank()
    {
        BankPanel.Children.Clear();

        int  starsFilter = StarsFilter.SelectedIndex;
        int  suitsFilter = SuitsFilter.SelectedIndex;
        bool favsOnly    = FavoritesFilter.IsChecked == true;
        var  pm          = HoneycombProfileManager.Shared;

        var filtered = _bankCards.AsEnumerable();

        if (starsFilter > 0)
            filtered = filtered.Where(c => c.Stars == starsFilter);

        if (suitsFilter > 0)
        {
            var suit = ((CardSuit)(suitsFilter - 1)).ToString();
            filtered = filtered.Where(c => c.Suit == suit);
        }

        if (favsOnly)
            filtered = filtered.Where(c => pm.FavoriteCardIds.Contains(c.Id));

        filtered = filtered
            .OrderByDescending(c => c.Stars)
            .ThenBy(c => c.Suit)
            .ThenByDescending(c => c.Id);

        foreach (var c in filtered)
        {
            var cardObj  = new HoneycombCard(c, 1);
            var cardView = new HoneycombCardView();
            var vb = new Viewbox
            {
                Width  = 90,
                Height = 127,
                Child  = cardView,
                Margin = new Avalonia.Thickness(4)
            };
            _ = cardView.RenderCard(cardObj); // fire-and-forget

            bool inDeck = _currentCardIds.Contains(c.Id);
            var addBtn = new Button
            {
                Content    = vb,
                Background = Brushes.Transparent,
                Padding    = new Avalonia.Thickness(0),
                Tag        = c.Id,
                IsEnabled  = !inDeck,
                Opacity    = inDeck ? 0.45 : 1.0
            };
            addBtn.Click += AddCard_Click;
            BankPanel.Children.Add(addBtn);
        }
    }

    private void ValidateRealtime()
    {
        string name = DeckNameTextBox.Text?.Trim() ?? "";
        bool ok = HoneycombProfileManager.Shared.ValidateDeck(_currentCardIds, name, out string err);
        ErrorText.Text          = err;
        SaveButton.IsEnabled    = ok;
    }

    // ── Card interactions ─────────────────────────────────────────────────
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

    // ── Filters ───────────────────────────────────────────────────────────
    private void FilterCombo_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (BankPanel != null) RefreshBank();
    }

    private void FilterToggle_CheckedChanged(object? sender, RoutedEventArgs e)
    {
        if (BankPanel != null) RefreshBank();
    }

    // ── Save / Cancel ─────────────────────────────────────────────────────
    public event Action? OnDismiss;

    private void Save_Click(object? sender, RoutedEventArgs e)
    {
        var pm   = HoneycombProfileManager.Shared;
        string name = DeckNameTextBox.Text?.Trim() ?? "";

        if (!pm.ValidateDeck(_currentCardIds, name, out string err))
        {
            ErrorText.Text = err;
            return;
        }

        pm.SavedDecks[_deckSlotIndex].Name    = name;
        pm.SavedDecks[_deckSlotIndex].CardIds = new List<int>(_currentCardIds);
        pm.SaveSavedDecks();

        // Post dismiss so the current click handler finishes before the
        // parent removes this view from the visual tree.
        Avalonia.Threading.Dispatcher.UIThread.Post(() => OnDismiss?.Invoke());
    }

    private void Cancel_Click(object? sender, RoutedEventArgs e)
    {
        OnDismiss?.Invoke();
    }
}
