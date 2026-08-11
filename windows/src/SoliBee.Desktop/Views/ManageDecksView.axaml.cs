using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Avalonia;
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

    // ── Card Bank virtualization ────────────────────────────────────────────
    // Same rationale as DeckBuilderView: with a full unlocked collection
    // (~550 cards), eagerly building every card as a full control tree made
    // scrolling laggy. Cells are shells (empty Border, correctly sized) until
    // they scroll near the viewport, at which point their real card visual gets
    // built once — favoriting a card mutates that built visual in place
    // afterward, so unlike DeckBuilderView there's no separate "reapply on
    // state change" path needed here.
    private readonly Dictionary<int, HoneycombCardData> _bankCardById = new();
    private readonly Dictionary<int, Border> _bankCellById = new();
    private readonly HashSet<int> _builtBankCellIds = new();

    // Freeform stat search: which cards are only a "near" (±2, not exact) match on
    // at least one filled-in side — read by BuildBankCell to dim those cells once
    // built, so exact matches visually stand out without a second sort pass at
    // render time.
    private readonly HashSet<int> _bankCellNearMatchIds = new();

    public ManageDecksView()
    {
        InitializeComponent();
        LoadBank();
        RefreshUI();
    }

    // Mirrors MainWindow.ApplyFeltColor's primary-hex mapping (the app-wide felt
    // setting, shared across all games including Honeycomb) — duplicated rather
    // than shared since it's a tiny switch and the existing copies (MainWindow,
    // PreferencesView, DeckBuilderView) already live in separate files with no
    // common helper.
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

    // When a custom background image is active (instead of a felt color), the active-
    // deck tint below is sampled from that image instead of falling back to whatever
    // felt color happens to be set — same idea as PreferencesView.SwatchColorForTheme.
    private static string BackgroundsDir => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        AppDataMigration.FolderName, "Backgrounds");

    private static Color CurrentSwatchColor()
    {
        var options = SettingsService.LoadOptions();
        if (!string.IsNullOrEmpty(options.BackgroundName))
        {
            var bg = options.CustomBackgrounds.Find(b => b.Name == options.BackgroundName);
            if (bg != null && PathSafety.IsSafeFileName(bg.FileName))
            {
                var path = Path.Combine(BackgroundsDir, bg.FileName);
                if (File.Exists(path)) return CardView.SampleDominantColor(path);
            }
        }

        try { return Color.Parse(CurrentFeltHex()); } catch { return Colors.Green; }
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
                // Empty-slot placeholder gets the flat gray box; a filled slot renders
                // real card art via HoneycombCardView (which already draws its own
                // border/shadow), so keeping the gray background+border underneath it
                // too just left a mismatched sliver visible around the rounded corners.
                var placeholder = new Border
                {
                    Width = 46, Height = 64,
                    CornerRadius = new Avalonia.CornerRadius(4)
                };

                HoneycombCardData? data = j < deckState.CardIds.Count
                    ? HoneycombDatabase.Shared.Card(deckState.CardIds[j])
                    : null;

                if (data != null)
                {
                    // Render synchronously without await – use fire-and-forget
                    // but wrap in a try/catch so a bad card never crashes the list.
                    var cardObj  = new HoneycombCard(data, 1);
                    var cardView = new HoneycombCardView { UseOwnershipColoring = false };
                    var vb = new Viewbox { Child = cardView };
                    placeholder.Child = vb;
                    // Fire-and-forget render (no await = no async-related crash)
                    _ = cardView.RenderCard(cardObj);
                }
                else
                {
                    placeholder.Background   = new SolidColorBrush(Color.Parse("#D8D8D8"));
                    placeholder.BorderBrush  = new SolidColorBrush(Color.Parse("#B0B0B0"));
                    placeholder.BorderThickness = new Avalonia.Thickness(1);
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

            // Always shown (not just when inactive) — reads "Active" and disables
            // itself when this is the active deck, instead of disappearing, so the
            // active state is signaled in the same spot every deck's button sits in.
            if (hasDeck)
            {
                int capturedSlot = slot;
                var makeActiveBtn = new Button
                {
                    Content    = isActive ? "Active" : "Make Active",
                    IsEnabled  = !isActive,
                    Classes    = { "light-secondary" }
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
                Classes = { "light-secondary" }
            };
            editBtn.Click += (_, e) =>
            {
                // Re-fire as a proper RoutedEventArgs so EditDeck_Click can read Tag
                editBtn.Tag = capturedSlotEdit;
                EditDeck_Click(editBtn, e);
            };
            btnRow.Children.Add(editBtn);

            // No separate "(Active)" label — the disabled "Active" button state
            // (below) plus the card's felt-tinted background/border already say it.
            var nameLine = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
            nameLine.Children.Add(new TextBlock
            {
                Text       = deckState.Name,
                FontWeight = FontWeight.Bold,
                FontSize   = 15,
                Foreground = Brushes.Black,
                VerticalAlignment = VerticalAlignment.Center
            });

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
            // Active deck uses the current felt/background swatch color (light tint for
            // the fill, full strength for the border) instead of a fixed green, matching
            // the same treatment as the Deck Builder's "Your Deck" tray.
            var activeSwatch = isActive ? CurrentSwatchColor() : default;
            var card = new Border
            {
                Background    = isActive
                    ? new SolidColorBrush(activeSwatch) { Opacity = 0.5 }
                    : new SolidColorBrush(Color.Parse("#EFEFEF")),
                CornerRadius  = new Avalonia.CornerRadius(10),
                BorderBrush   = new SolidColorBrush(isActive ? activeSwatch : Color.Parse("#D0D0D0")),
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

        CardBankTitle.Text = $"CARD BANK ({pm.UnlockedCardIds.Count}/{HoneycombDatabase.Shared.AllCards.Count})";

        BankPanel.Children.Clear();
        _bankCardById.Clear();
        _bankCellById.Clear();
        _builtBankCellIds.Clear();
        _bankCellNearMatchIds.Clear();
        EmptyFilterMessage.IsVisible = false;

        int starsFilter = StarsFilter.SelectedIndex;
        int suitsFilter = SuitsFilter.SelectedIndex;
        bool favsOnly   = FavoritesFilter.IsChecked == true;

        // Stats[0..3] = Top, Right, Bottom, Left (see HoneycombCardView.RenderCard).
        int?[] statFilters =
        {
            ParseStatBox(StatSearchTop),
            ParseStatBox(StatSearchRight),
            ParseStatBox(StatSearchBottom),
            ParseStatBox(StatSearchLeft)
        };
        bool anyStatFilter = statFilters.Any(f => f != null);

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

        // AND across every filled-in side: a card survives only if each filled side
        // is within ±2 of its stat (exact or near). isNearMatch is set per surviving
        // card so exact-only matches (every filled side dead-on) sort first and
        // render at full strength, while anything relying on the ±2 tolerance sorts
        // after and renders dimmed.
        var nearMatchByCard = new Dictionary<int, bool>();
        if (anyStatFilter)
        {
            var survivors = new List<HoneycombCardData>();
            foreach (var c in filtered)
            {
                bool isNear = false;
                bool matches = true;
                for (int i = 0; i < 4; i++)
                {
                    if (statFilters[i] is not int target) continue;
                    int diff = Math.Abs(c.Stats[i] - target);
                    if (diff == 0) continue;
                    if (diff <= 2) { isNear = true; continue; }
                    matches = false;
                    break;
                }
                if (!matches) continue;
                survivors.Add(c);
                nearMatchByCard[c.Id] = isNear;
            }
            filtered = survivors;
        }

        var results = filtered
            .OrderBy(c => anyStatFilter && nearMatchByCard.GetValueOrDefault(c.Id) ? 1 : 0)
            .ThenByDescending(c => c.Stars)
            .ThenBy(c => c.Suit)
            .ThenByDescending(c => c.Id)
            .ToList();

        foreach (var id in nearMatchByCard.Where(kv => kv.Value).Select(kv => kv.Key))
            _bankCellNearMatchIds.Add(id);

        EmptyFilterMessage.IsVisible = results.Count == 0;

        foreach (var c in results)
        {
            _bankCardById[c.Id] = c;

            // Shell only — sized to match the real content (96x136 card + 7px
            // margin all round = 110x150, matching BankPanel's ItemWidth/Height so
            // 5 columns fit at the dialog's fixed width instead of 4), so the
            // WrapPanel/scrollbar size correctly before any card visual exists.
            // UpdateVisibleBankCells builds the real HoneycombCardView tree lazily,
            // only for cells near the viewport.
            var shell = new Border
            {
                Width      = 110,
                Height     = 150,
                Background = Brushes.Transparent,
                Tag        = c.Id
            };

            _bankCellById[c.Id] = shell;
            BankPanel.Children.Add(shell);
        }

        // No ScrollChanged event fires for the very first paint, so kick off one
        // visibility pass once this layout settles; ScrollChanged covers every
        // scroll from here on.
        Avalonia.Threading.Dispatcher.UIThread.Post(UpdateVisibleBankCells,
            Avalonia.Threading.DispatcherPriority.Loaded);
    }

    // Builds one bank cell's real card visual (art + favorite heart) and wires
    // it into an already-placed shell — called once, the first time that shell
    // scrolls near the viewport.
    private void BuildBankCell(int cardId, Border shell)
    {
        var pm = HoneycombProfileManager.Shared;
        var c  = _bankCardById[cardId];

        var cardObj  = new HoneycombCard(c, 1);
        var cardView = new HoneycombCardView { UseOwnershipColoring = false };
        _ = cardView.RenderCard(cardObj); // fire-and-forget, no await

        var vb = new Viewbox
        {
            Width  = 96,
            Height = 136,
            Child  = cardView,
            Margin = new Avalonia.Thickness(7)
        };

        bool isFav = pm.FavoriteCardIds.Contains(c.Id);

        // Use a TextBlock as the button content so we can directly mutate its
        // Foreground — setting Foreground on the ToggleButton itself doesn't
        // propagate through Avalonia's ContentPresenter to the rendered text.
        var heartText = new TextBlock
        {
            Text       = "♥",
            FontSize   = 18,
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
            // heartBtn lives in cellGrid at full native size, alongside (not
            // inside) the Viewbox that scales the card art down — so its margin
            // has to clear both the Viewbox's own 7px outer margin AND the card
            // face's rounded corner, or it lands right on the card's edge instead
            // of sitting on its face. Scaled down from (0,14,16,0) to match the
            // smaller 96x136 card (was 112x157).
            Margin              = new Avalonia.Thickness(0, 12, 14, 0),
            // Unfavorited hearts sit at a faint-but-visible 0.35 rather than fully
            // invisible — at 0 opacity the favorite affordance didn't exist at all
            // until you happened to hover a card, so there was no way to discover
            // it just by looking at the grid.
            Opacity             = isFav ? 1.0 : 0.35,
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
                btn.Opacity          = 0.35;
            }
            pm.SaveFavoriteCards();
        };

        var cellGrid = new Grid();
        cellGrid.Children.Add(vb);
        cellGrid.Children.Add(heartBtn);

        // Freeform stat search: cards that only matched via the ±2 tolerance (not
        // an exact hit on every filled-in side) render dimmed, so exact matches
        // stand out even though both are already sorted exact-first.
        if (_bankCellNearMatchIds.Contains(cardId))
            vb.Opacity = 0.4;

        shell.Child = cellGrid;
        shell.PointerEntered += (_, _) => { if (heartBtn.IsChecked != true) heartBtn.Opacity = 0.8; };
        shell.PointerExited  += (_, _) => { if (heartBtn.IsChecked != true) heartBtn.Opacity = 0.35; };

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

            Point? pos;
            try { pos = shell.TranslatePoint(new Point(0, 0), BankScrollViewer); }
            catch { continue; }
            if (pos == null) continue;

            double top    = pos.Value.Y;
            double bottom = top + shell.Height;

            if (bottom >= -buffer && top <= viewportHeight + buffer)
                BuildBankCell(cardId, shell);
        }
    }

    private void BankScrollViewer_ScrollChanged(object? sender, ScrollChangedEventArgs e)
    {
        UpdateVisibleBankCells();
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

    private void StatSearch_TextChanged(object? sender, TextChangedEventArgs e)
    {
        if (BankPanel != null) RefreshBank();
    }

    // Empty box = "don't filter this side". "A"/"a" = 10 (matches HoneycombCardView's
    // own FormatStat), 1-9 parse directly; anything else (a stray letter, "0", etc.)
    // is treated the same as empty rather than blocking the keystroke — keeps the
    // input simple with no separate validation/rejection path.
    private static int? ParseStatBox(TextBox box)
    {
        var text = box.Text?.Trim();
        if (string.IsNullOrEmpty(text)) return null;
        if (text.Equals("A", StringComparison.OrdinalIgnoreCase)) return 10;
        if (int.TryParse(text, out var v) && v is >= 1 and <= 9) return v;
        return null;
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
