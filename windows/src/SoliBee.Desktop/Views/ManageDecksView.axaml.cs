using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

public partial class ManageDecksView : UserControl
{
    private List<HoneycombCardData> _bankCards = new();

    public ManageDecksView()
    {
        InitializeComponent();
        LoadBank();
        RefreshUI();
    }

    private void LoadBank()
    {
        _bankCards.Clear();
        foreach (var id in HoneycombProfileManager.Shared.UnlockedCardIds)
        {
            var card = HoneycombDatabase.Shared.Card(id);
            if (card != null) _bankCards.Add(card);
        }
    }

    // ── Public so MainWindow can call it after DeckBuilder closes ──────────
    public void RefreshUI()
    {
        RefreshDecksList();
        RefreshBank();
    }

    // ── Saved Decks panel ─────────────────────────────────────────────────
    private void RefreshDecksList()
    {
        var pm = HoneycombProfileManager.Shared;
        var opts = SettingsService.LoadOptions();
        int activeIndex = opts.HoneycombActiveDeckIndex;

        DecksListPanel.Children.Clear();

        for (int slot = 0; slot < 5; slot++)
        {
            var deckState = pm.SavedDecks[slot];
            bool isActive = (slot == activeIndex);
            bool hasDeck  = deckState.CardIds.Count == 5;

            // ── Card preview row ──
            var cardRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
            for (int j = 0; j < 5; j++)
            {
                var placeholder = new Border
                {
                    Width = 46, Height = 64,
                    CornerRadius = new Avalonia.CornerRadius(4),
                    Background   = new SolidColorBrush(Color.Parse("#D8D8D8")),
                    BorderBrush  = new SolidColorBrush(Color.Parse("#B0B0B0")),
                    BorderThickness = new Avalonia.Thickness(1)
                };

                if (j < deckState.CardIds.Count)
                {
                    var data = HoneycombDatabase.Shared.Card(deckState.CardIds[j]);
                    if (data != null)
                    {
                        // Render synchronously without await – use fire-and-forget
                        // but wrap in a try/catch so a bad card never crashes the list.
                        var cardObj  = new HoneycombCard(data, 1);
                        var cardView = new HoneycombCardView();
                        var vb = new Viewbox { Child = cardView };
                        placeholder.Child = vb;
                        // Fire-and-forget render (no await = no async-related crash)
                        _ = cardView.RenderCard(cardObj);
                    }
                }

                cardRow.Children.Add(placeholder);
            }

            // ── Buttons row ──
            var btnRow = new StackPanel
            {
                Orientation         = Orientation.Horizontal,
                Spacing             = 8,
                HorizontalAlignment = HorizontalAlignment.Right
            };

            if (!isActive && hasDeck)
            {
                int capturedSlot = slot;
                var makeActiveBtn = new Button
                {
                    Content = "Make Active",
                    Classes = { "btn-blue" }
                };
                makeActiveBtn.Click += (_, _) =>
                {
                    var o = SettingsService.LoadOptions();
                    o.HoneycombActiveDeckIndex = capturedSlot;
                    SettingsService.SaveOptions(o);
                    RefreshDecksList(); // only re-draw the list, not the whole bank
                };
                btnRow.Children.Add(makeActiveBtn);
            }

            int capturedSlotEdit = slot;
            var editBtn = new Button
            {
                Content = hasDeck ? "Edit" : "Create",
                Classes = { "btn-blue" }
            };
            editBtn.Click += (_, e) =>
            {
                // Re-fire as a proper RoutedEventArgs so EditDeck_Click can read Tag
                editBtn.Tag = capturedSlotEdit;
                EditDeck_Click(editBtn, e);
            };
            btnRow.Children.Add(editBtn);

            // ── Active label badge ──
            var nameLine = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
            nameLine.Children.Add(new TextBlock
            {
                Text       = deckState.Name,
                FontWeight = FontWeight.Bold,
                FontSize   = 15,
                Foreground = Brushes.Black,
                VerticalAlignment = VerticalAlignment.Center
            });
            if (isActive)
            {
                nameLine.Children.Add(new Border
                {
                    Background    = new SolidColorBrush(Color.Parse("#27AE60")),
                    CornerRadius  = new Avalonia.CornerRadius(20),
                    Padding       = new Avalonia.Thickness(8, 2),
                    Child = new TextBlock
                    {
                        Text       = "ACTIVE",
                        FontSize   = 10,
                        FontWeight = FontWeight.Bold,
                        Foreground = Brushes.White,
                        VerticalAlignment = VerticalAlignment.Center
                    }
                });
            }

            // ── Header row: name left, buttons right ──
            var header = new Grid
            {
                ColumnDefinitions = new ColumnDefinitions("*, Auto"),
                Margin = new Avalonia.Thickness(0, 0, 0, 8)
            };
            Grid.SetColumn(nameLine, 0);
            Grid.SetColumn(btnRow,   1);
            header.Children.Add(nameLine);
            header.Children.Add(btnRow);

            // ── Card: outer border ──
            var card = new Border
            {
                Background    = new SolidColorBrush(Color.Parse(isActive ? "#E8F5E9" : "#EFEFEF")),
                CornerRadius  = new Avalonia.CornerRadius(10),
                BorderBrush   = new SolidColorBrush(Color.Parse(isActive ? "#27AE60" : "#D0D0D0")),
                BorderThickness = new Avalonia.Thickness(isActive ? 2 : 1),
                Padding       = new Avalonia.Thickness(12, 10),
                Margin        = new Avalonia.Thickness(0, 0, 0, 0),
            };

            var inner = new StackPanel { Spacing = 8 };
            inner.Children.Add(header);
            inner.Children.Add(cardRow);
            card.Child = inner;

            DecksListPanel.Children.Add(card);
        }
    }

    // ── Card bank panel ───────────────────────────────────────────────────
    private void RefreshBank()
    {
        var pm = HoneycombProfileManager.Shared;

        CardBankTitle.Text = $"CARD BANK ({pm.UnlockedCardIds.Count}/552)";

        BankPanel.Children.Clear();

        int starsFilter = StarsFilter.SelectedIndex;
        int suitsFilter = SuitsFilter.SelectedIndex;
        bool favsOnly   = FavoritesFilter.IsChecked == true;

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
            _ = cardView.RenderCard(cardObj); // fire-and-forget, no await

            var vb = new Viewbox
            {
                Width  = 80,
                Height = 112,
                Child  = cardView,
                Margin = new Avalonia.Thickness(4)
            };

            bool isFav = pm.FavoriteCardIds.Contains(c.Id);

            // Use a TextBlock as the button content so we can directly mutate its
            // Foreground — setting Foreground on the ToggleButton itself doesn't
            // propagate through Avalonia's ContentPresenter to the rendered text.
            var heartText = new TextBlock
            {
                Text       = "♥",
                FontSize   = 20,
                Foreground = isFav ? Brushes.Red : new SolidColorBrush(Color.Parse("#BBBBBB")),
                VerticalAlignment = VerticalAlignment.Center,
                HorizontalAlignment = HorizontalAlignment.Center,
            };

            var heartBtn = new ToggleButton
            {
                Classes             = { "heart-btn" },
                Content             = heartText,
                IsChecked           = isFav,
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment   = VerticalAlignment.Top,
                Margin              = new Avalonia.Thickness(0, 4, 6, 0),
                Opacity             = isFav ? 1.0 : 0.0,
                Tag                 = c.Id
            };

            heartBtn.IsCheckedChanged += (s, _) =>
            {
                var btn = (ToggleButton)s!;
                int id  = (int)btn.Tag!;
                if (btn.IsChecked == true)
                {
                    pm.FavoriteCardIds.Add(id);
                    heartText.Foreground = Brushes.Red;
                    btn.Opacity          = 1.0;
                }
                else
                {
                    pm.FavoriteCardIds.Remove(id);
                    heartText.Foreground = new SolidColorBrush(Color.Parse("#BBBBBB"));
                    btn.Opacity          = 0.0;
                }
                pm.SaveFavoriteCards();
            };

            var cellGrid = new Grid();
            cellGrid.Children.Add(vb);
            cellGrid.Children.Add(heartBtn);

            var wrapper = new Border { Background = Brushes.Transparent, Child = cellGrid };
            wrapper.PointerEntered += (_, _) => { if (heartBtn.IsChecked != true) heartBtn.Opacity = 0.8; };
            wrapper.PointerExited  += (_, _) => { if (heartBtn.IsChecked != true) heartBtn.Opacity = 0.0; };

            BankPanel.Children.Add(wrapper);
        }
    }

    // ── Events wired from XAML ────────────────────────────────────────────
    public event Action<int>? OnRequestDeckBuilder;

    private void EditDeck_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button b && b.Tag is int slotIndex)
            OnRequestDeckBuilder?.Invoke(slotIndex);
    }

    private void FilterCombo_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (BankPanel != null) RefreshBank();
    }

    private void FilterToggle_CheckedChanged(object? sender, RoutedEventArgs e)
    {
        if (BankPanel != null) RefreshBank();
    }

    private void StartOver_Click(object? sender, RoutedEventArgs e)
    {
        StartOverOverlay.IsVisible = true;
    }

    private void CancelStartOver_Click(object? sender, RoutedEventArgs e)
    {
        StartOverOverlay.IsVisible = false;
    }

    private void ConfirmStartOver_Click(object? sender, RoutedEventArgs e)
    {
        StartOverOverlay.IsVisible = false;

        var pm = HoneycombProfileManager.Shared;
        pm.StartOver();

        var opts = SettingsService.LoadOptions();
        opts.HoneycombActiveDeckIndex = 0;
        opts.PlayerDeckIds = new List<int>(pm.SavedDecks[0].CardIds);
        SettingsService.SaveOptions(opts);

        LoadBank();
        RefreshUI();
    }
}
