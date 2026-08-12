using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Media;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

public partial class DeckBuilderView : UserControl
{
    private int _deckSlotIndex;
    private List<int> _currentCardIds = new();
    private List<HoneycombCardData> _bankCards = new();

    // ── Card Bank virtualization ────────────────────────────────────────────
    // With a full unlocked collection (~550 cards), eagerly building every card
    // as a full HoneycombCardView control tree (animated transforms, star Paths,
    // suit image, etc.) up front made both scrolling and add/remove noticeably
    // laggy. These three track: what card each cell represents, the lightweight
    // Button "shell" that reserves its WrapPanel cell (so scroll extent/layout
    // stays correct immediately), and which shells have actually had their real
    // card visual built yet.
    private readonly Dictionary<int, HoneycombCardData> _bankCardById = new();
    private readonly Dictionary<int, Button> _bankCellById = new();
    private readonly HashSet<int> _builtBankCellIds = new();

    // Opens for editing an existing slot (Create = empty slot, Edit = populated slot)
    public DeckBuilderView(int deckSlotIndex)
    {
        InitializeComponent();
        ApplyLocalization();
        _deckSlotIndex = deckSlotIndex;
        LoadData();
        RefreshUI();
    }

    // Parameterless ctor required by Avalonia designer
    public DeckBuilderView()
    {
        InitializeComponent();
        ApplyLocalization();
        LoadData();
        RefreshUI();
    }

    private void ApplyLocalization()
    {
        var language = SettingsService.LoadOptions().Language;

        DeckNameTextBox.Watermark = Strings.Get(StringKey.DeckNamePlaceholder, language);
        CardBankTapToAddText.Text = Strings.Get(StringKey.CardBankTapToAdd, language);
        DeckRulesHintText.Text = Strings.Get(StringKey.DeckRulesHint, language);

        AllStarsItem.Content = Strings.Get(StringKey.AllStarsFilter, language);
        var starWord = Strings.Get(StringKey.StarCountFilterFmt, language);
        OneStarItem.Content    = starWord.Replace("%d", "1").Replace("%@", "");
        TwoStarsItem.Content   = starWord.Replace("%d", "2").Replace("%@", "s");
        ThreeStarsItem.Content = starWord.Replace("%d", "3").Replace("%@", "s");
        FourStarsItem.Content  = starWord.Replace("%d", "4").Replace("%@", "s");
        FiveStarsItem.Content  = starWord.Replace("%d", "5").Replace("%@", "s");

        AllSuitsItem.Content = Strings.Get(StringKey.AllSuitsFilter, language);
        SpadesItem.Content   = HoneycombCardData.LocalizedSuitName("S", language);
        HeartsItem.Content   = HoneycombCardData.LocalizedSuitName("H", language);
        DiamondsItem.Content = HoneycombCardData.LocalizedSuitName("D", language);
        ClubsItem.Content    = HoneycombCardData.LocalizedSuitName("C", language);

        FavoritesFilter.Content = "♡ " + Strings.Get(StringKey.FavoritesFilter, language);

        CancelButton.Content = Strings.Get(StringKey.Cancel, language);
        SaveButton.Content = Strings.Get(StringKey.BtnSaveDeck, language);
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

        YourDeckTray.Background = new SolidColorBrush(Color.Parse(CurrentFeltHex())) { Opacity = 0.5 };

        _bankCards.Clear();
        foreach (var id in pm.UnlockedCardIds)
        {
            var c = HoneycombDatabase.Shared.Card(id);
            if (c != null) _bankCards.Add(c);
        }
    }

    // Mirrors MainWindow.ApplyFeltColor's primary-hex mapping (the app-wide felt
    // setting, shared across all games including Honeycomb — see that method's
    // comments) — duplicated rather than shared since it's a tiny switch and the
    // existing two copies (MainWindow, PreferencesView) already live in separate
    // files with no common helper.
    private static string CurrentFeltHex()
    {
        var options = SettingsService.LoadOptions();
        if (options.FeltColor == FeltColorTheme.Custom) return options.CustomFeltColorHex;
        return options.FeltColor switch
        {
            FeltColorTheme.FeltGreen => "#008000",
            FeltColorTheme.Crimson   => "#8C0C26",
            FeltColorTheme.RoyalBlue => "#1A3380",
            FeltColorTheme.Charcoal  => "#2E2E2E",
            FeltColorTheme.Desert    => "#C2967A",
            _                        => "#008000"
        };
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
                    var cardView = new HoneycombCardView { UseOwnershipColoring = false };
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

        YourDeckTitle.Text = Strings.Get(StringKey.YourDeckCountFmt, SettingsService.LoadOptions().Language).Replace("%d", _currentCardIds.Count.ToString());
    }

    private void RefreshBank()
    {
        BankPanel.Children.Clear();
        _bankCardById.Clear();
        _bankCellById.Clear();
        _builtBankCellIds.Clear();

        int  starsFilter = StarsFilter.SelectedIndex;
        int  suitsFilter = SuitsFilter.SelectedIndex;
        bool favsOnly    = FavoritesFilter.IsChecked == true;
        var  pm          = HoneycombProfileManager.Shared;

        var filtered = _bankCards.AsEnumerable();

        if (starsFilter > 0)
            filtered = filtered.Where(c => c.Stars == starsFilter);

        if (suitsFilter > 0)
        {
            // HoneycombCardData.Suit stores single-letter codes ("S"/"H"/"D"/"C"), not
            // CardSuit's full-word ToString() — comparing against the raw enum name
            // never matched anything, silently emptying the bank for every suit filter.
            var suit = ((CardSuit)(suitsFilter - 1)).ToString()[..1];
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
            _bankCardById[c.Id] = c;

            // Shell only — sized to match what the real content (90x127 card +
            // 4px margin all round) settles to, so the WrapPanel lays out and the
            // scrollbar sizes correctly even before any real card visual exists.
            // The actual HoneycombCardView tree is built lazily by
            // UpdateVisibleBankCells, only for cells near the viewport.
            var shell = new Button
            {
                Width      = 98,
                Height     = 135,
                Background = Brushes.Transparent,
                Padding    = new Avalonia.Thickness(0),
                Tag        = c.Id
                // Left enabled even when already in the deck (not IsEnabled = !inDeck
                // like before) — a disabled Button also stops receiving right-click
                // input, which would have silently broken the context menu.
                // AddCard_Click already no-ops for a card already in _currentCardIds,
                // so left-click behavior is unaffected.
            };
            shell.Click += AddCard_Click;

            _bankCellById[c.Id] = shell;
            BankPanel.Children.Add(shell);
        }

        // No ScrollChanged event fires for the very first paint, so kick off one
        // visibility pass once this layout settles; ScrollChanged covers every
        // scroll from here on.
        Avalonia.Threading.Dispatcher.UIThread.Post(UpdateVisibleBankCells,
            Avalonia.Threading.DispatcherPriority.Loaded);
    }

    // Builds the actual card visual (Viewbox + HoneycombCardView, plus the
    // "already in deck" gray scrim) for one card — used both by the lazy
    // just-in-time build below and by the single-cell refresh after an add/remove.
    private Control BuildBankCellVisual(HoneycombCardData c)
    {
        var cardObj  = new HoneycombCard(c, 1);
        var cardView = new HoneycombCardView { UseOwnershipColoring = false };
        var vb = new Viewbox
        {
            Width  = 90,
            Height = 127,
            Child  = cardView,
            Margin = new Avalonia.Thickness(4)
        };
        _ = cardView.RenderCard(cardObj); // fire-and-forget

        // A gray scrim reads as "used" the way Mac's genuinely desaturated card
        // does; plain Opacity alone just faded the card's own color toward the
        // white dialog background, which for red-suited cards washed out to a
        // pink tint instead of gray.
        if (!_currentCardIds.Contains(c.Id)) return vb;

        return new Grid
        {
            Children =
            {
                vb,
                new Border
                {
                    Background       = new SolidColorBrush(Color.Parse("#99EEEEEE")),
                    CornerRadius     = new Avalonia.CornerRadius(6),
                    IsHitTestVisible = false
                }
            }
        };
    }

    // (Re)builds one bank cell's content + context menu to match current
    // _currentCardIds state — called once when a cell first scrolls into view,
    // and again whenever that specific card's in-deck state changes, instead of
    // RefreshBank() tearing down and rebuilding all ~550 cells for a one-card change.
    private void ApplyBankCellState(int cardId)
    {
        if (!_bankCellById.TryGetValue(cardId, out var shell)) return;
        if (!_bankCardById.TryGetValue(cardId, out var c)) return;

        shell.Content = BuildBankCellVisual(c);

        if (_currentCardIds.Contains(cardId))
        {
            var removeItem = new MenuItem { Header = Strings.Get(StringKey.RemoveFromDeckContextMenu, SettingsService.LoadOptions().Language) };
            removeItem.Click += (_, _) =>
            {
                _currentCardIds.Remove(cardId);
                RefreshDeckSlots();
                ValidateRealtime();
                ApplyBankCellState(cardId);
            };
            shell.ContextMenu = new ContextMenu { Items = { removeItem } };
        }
        else
        {
            shell.ContextMenu = null;
        }

        _builtBankCellIds.Add(cardId);
    }

    // Builds any not-yet-built cell whose shell is within viewport + a buffer,
    // so scrolling stays smooth (cells are ready slightly before they're seen)
    // without ever building the full ~550-card set up front.
    private void UpdateVisibleBankCells()
    {
        double viewportHeight = BankScrollViewer.Viewport.Height;
        if (viewportHeight <= 0) return; // not laid out yet

        const double buffer = 400;

        foreach (var (cardId, shell) in _bankCellById)
        {
            if (_builtBankCellIds.Contains(cardId)) continue;

            Avalonia.Point? pos;
            try { pos = shell.TranslatePoint(new Avalonia.Point(0, 0), BankScrollViewer); }
            catch { continue; }
            if (pos == null) continue;

            double top    = pos.Value.Y;
            double bottom = top + shell.Height;

            if (bottom >= -buffer && top <= viewportHeight + buffer)
                ApplyBankCellState(cardId);
        }
    }

    private void BankScrollViewer_ScrollChanged(object? sender, ScrollChangedEventArgs e)
    {
        UpdateVisibleBankCells();
    }

    private void ValidateRealtime()
    {
        string name = DeckNameTextBox.Text?.Trim() ?? "";
        bool ok = HoneycombProfileManager.Shared.ValidateDeck(_currentCardIds, name, out string err);
        ErrorText.Text          = err;
        SaveButton.IsEnabled    = ok;
    }

    // ── Card interactions ─────────────────────────────────────────────────
    // Neither handler calls RefreshUI()/RefreshBank() anymore — with a large
    // unlocked collection, tearing down and rebuilding every bank cell on every
    // single add/remove was the main source of "adding a card feels slow".
    // Only the deck-slot row (5 items, cheap) and the one affected bank cell
    // need to change.
    private void AddCard_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button b && b.Tag is int id)
        {
            if (_currentCardIds.Count < 5 && !_currentCardIds.Contains(id))
            {
                _currentCardIds.Add(id);
                RefreshDeckSlots();
                ValidateRealtime();
                ApplyBankCellState(id);
            }
        }
    }

    private void RemoveCard_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is Button b && b.Tag is int id)
        {
            _currentCardIds.Remove(id);
            RefreshDeckSlots();
            ValidateRealtime();
            ApplyBankCellState(id);
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
