using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using SoliBee.Desktop.Services;

namespace SoliBee.Desktop.Views;

public partial class PileView : UserControl
{
    public static readonly StyledProperty<Pile?> PileProperty =
        AvaloniaProperty.Register<PileView, Pile?>(nameof(Pile), defaultValue: null);

    public Pile? Pile
    {
        get => GetValue(PileProperty);
        set => SetValue(PileProperty, value);
    }

    public event EventHandler? Clicked;

    private readonly HintPulseAnimation _hintPulse = new();
    private SolidColorBrush? _hintPulseBrush;

    static PileView()
    {
        PileProperty.Changed.AddClassHandler<PileView>((x, e) => x.OnPileChanged(e));
    }

    public PileView()
    {
        InitializeComponent();
        this.Loaded += (s, e) => UpdateCardsLayout();
        this.Unloaded += (s, e) => _hintPulse.Stop();
    }

    // Whole-pile hint highlight — used for foundation / free cell / stock / waste,
    // which hold at most one playable card at a time and don't need per-card granularity.
    public void ShowHint()
    {
        if (HintHighlightBorder == null) return;
        // Match the fanned waste-pile canvas width (draw-three mode) instead of the
        // fixed single-card size, so the highlight surrounds every fanned card.
        if (CardsCanvas != null)
        {
            HintHighlightBorder.Width  = CardsCanvas.Width;
            HintHighlightBorder.Height = CardsCanvas.Height;
        }
        HintHighlightBorder.IsVisible = true;
        _hintPulseBrush = new SolidColorBrush(Color.Parse("#FFD700"));
        HintHighlightBorder.BorderBrush = _hintPulseBrush;
        _hintPulse.Start(alpha =>
        {
            byte a = (byte)(160 + (int)(95 * alpha));
            _hintPulseBrush!.Color = Color.FromArgb(a, 0xFF, 0xD7, 0x00);
            HintHighlightBorder.BoxShadow = new BoxShadows(new BoxShadow
            {
                OffsetX = 0, OffsetY = 0, Blur = 4, Spread = 0,
                Color = Color.FromArgb((byte)(a * 0.8), 0xFF, 0xD7, 0x00)
            });
        });
    }

    public void ClearHint()
    {
        _hintPulse.Stop();
        _hintPulseBrush = null;
        if (HintHighlightBorder == null) return;
        HintHighlightBorder.IsVisible = false;
        HintHighlightBorder.BoxShadow = default;
    }

    // Whole-pile keyboard cursor outline — steady (no pulse), for when the focus cursor
    // is on a pile with no specific CardView to outline (empty, or a non-tableau pile).
    public void ShowCursor()
    {
        if (CursorHighlightBorder == null) return;
        if (CardsCanvas != null)
        {
            CursorHighlightBorder.Width  = CardsCanvas.Width;
            CursorHighlightBorder.Height = CardsCanvas.Height;
        }
        CursorHighlightBorder.IsVisible = true;
    }

    public void ClearCursor()
    {
        if (CursorHighlightBorder == null) return;
        CursorHighlightBorder.IsVisible = false;
    }

    private void OnPileChanged(AvaloniaPropertyChangedEventArgs e)
    {
        UpdateCardsLayout();
    }

    public void UpdateCardsLayout()
    {
        if (CardsCanvas == null || EmptyOutline == null || EmptySymbolText == null) return;
        EmptySymbolText.Text = "";

        // Find parent GameView
        GameView? gameView = null;
        var parent = this.Parent;
        while (parent != null)
        {
            if (parent is GameView gv)
            {
                gameView = gv;
                break;
            }
            parent = parent.Parent;
        }

        bool isDrawThree = false;
        GameViewModel? vm = null;
        if (gameView != null && gameView.DataContext is GameViewModel gvm)
        {
            vm = gvm;
            isDrawThree = vm.State.Mode == DrawMode.DrawThree;
        }

        if (Pile == null || Pile.Cards.Count == 0)
        {
            CardsCanvas.Children.Clear();
            EmptyOutline.IsVisible = true;

            // Set symbols for empty slots
            if (Pile != null)
            {
                if (Pile.Type == PileType.Foundation)
                {
                    EmptySymbolText.Text = "A";
                }
                else if (Pile.Type == PileType.Stock && vm != null && vm.Waste.Cards.Count > 0)
                {
                    EmptySymbolText.Text = "↺";
                }
            }

            CardsCanvas.Width = 128;
            CardsCanvas.Height = 181;
            return;
        }

        EmptyOutline.IsVisible = false;

        double offset = 0;

        if (Pile.Type == PileType.Waste)
        {
            if (isDrawThree)
            {
                // Draw 3 mode: show only cards from the current draw batch
                int batchSize   = vm?.State.WasteDrawBatchSize ?? 0;
                int cardsToShow = Math.Min(batchSize, Pile.Cards.Count);

                if (cardsToShow == 0)
                {
                    if (Pile.Cards.Count == 0)
                    {
                        // Waste is genuinely empty — prompt user to draw again
                        CardsCanvas.Children.Clear();
                        EmptyOutline.IsVisible = true;
                        CardsCanvas.Width  = 128;
                        CardsCanvas.Height = 181;
                        return;
                    }

                    // Current draw batch fully played — peel back to the older waste
                    // layer underneath and expose just its top card (no new 3-fan).
                    cardsToShow = 1;
                }

                int startIndex = Pile.Cards.Count - cardsToShow;

                for (int slot = 0; slot < cardsToShow; slot++)
                {
                    int pileIndex = startIndex + slot;
                    var card = Pile.Cards[pileIndex];

                    CardView cardView;
                    if (slot < CardsCanvas.Children.Count && CardsCanvas.Children[slot] is CardView cv)
                        cardView = cv;
                    else
                    {
                        cardView = new CardView();
                        if (slot < CardsCanvas.Children.Count) { CardsCanvas.Children.RemoveAt(slot); CardsCanvas.Children.Insert(slot, cardView); }
                        else CardsCanvas.Children.Add(cardView);
                    }

                    if (!ReferenceEquals(cardView.Card, card)) cardView.Card = card;
                    Canvas.SetLeft(cardView, slot * 42);
                    Canvas.SetTop(cardView, 0);
                }

                while (CardsCanvas.Children.Count > cardsToShow)
                    CardsCanvas.Children.RemoveAt(cardsToShow);

                CardsCanvas.Width  = 128 + Math.Max(0, cardsToShow - 1) * 42;
                CardsCanvas.Height = 181;
            }
            else
            {
                // Draw 1 mode: just show top card — reuse existing CardView if present
                var card = Pile.Cards[^1];
                CardView cardView;
                if (CardsCanvas.Children.Count > 0 && CardsCanvas.Children[0] is CardView cv)
                    cardView = cv;
                else
                {
                    cardView = new CardView();
                    CardsCanvas.Children.Clear();
                    CardsCanvas.Children.Add(cardView);
                }
                if (!ReferenceEquals(cardView.Card, card)) cardView.Card = card;
                while (CardsCanvas.Children.Count > 1) CardsCanvas.Children.RemoveAt(1);
                Canvas.SetLeft(cardView, 0);
                Canvas.SetTop(cardView, 0);
                CardsCanvas.Width  = 128;
                CardsCanvas.Height = 181;
            }
        }
        else
        {
            CardsCanvas.Width = 128;
            int cardCount = Pile.Cards.Count;

            for (int i = 0; i < cardCount; i++)
            {
                var card = Pile.Cards[i];
                bool isTopOfStock = Pile.Type == PileType.Stock && i == cardCount - 1;

                CardView cardView;
                if (i < CardsCanvas.Children.Count && CardsCanvas.Children[i] is CardView cv)
                {
                    cardView = cv;
                }
                else
                {
                    cardView = new CardView();
                    if (i < CardsCanvas.Children.Count)
                    {
                        CardsCanvas.Children.RemoveAt(i);
                        CardsCanvas.Children.Insert(i, cardView);
                    }
                    else
                    {
                        CardsCanvas.Children.Add(cardView);
                    }
                }

                // Set IsAnimated before Card so ApplyCardBackTheme picks it up
                cardView.IsAnimated = isTopOfStock;
                if (!ReferenceEquals(cardView.Card, card))
                    cardView.Card = card;

                Canvas.SetLeft(cardView, 0);
                Canvas.SetTop(cardView, offset);

                if (Pile.Type == PileType.Tableau)
                    offset += card.IsFaceUp ? 32 : 20;
            }

            // Remove excess reused children
            while (CardsCanvas.Children.Count > cardCount)
                CardsCanvas.Children.RemoveAt(cardCount);

            // Adjust Canvas Height to accommodate fanning
            CardsCanvas.Height = 181 + offset;
        }
    }

    private static List<Card> GetCardsFromCard(Card fromCard, Pile pile)
    {
        int idx = pile.Cards.IndexOf(fromCard);
        return idx < 0 ? new List<Card> { fromCard } : pile.Cards.GetRange(idx, pile.Cards.Count - idx);
    }

    private CardGameView? FindParentGameView() => CardGameView.FindAncestorGameView(this.Parent);

    private void PileView_PointerPressed(object sender, PointerPressedEventArgs e)
    {
        if (Pile == null) return;

        // Any direct mouse interaction relinquishes the keyboard focus cursor (pending
        // selection, shared with the keyboard, is untouched — see CardGameView remarks).
        var gameView = FindParentGameView();
        gameView?.RelinquishKeyboardCursor();

        if (Pile.Type == PileType.Stock)
        {
            Clicked?.Invoke(this, EventArgs.Empty);
            return;
        }

        if (gameView == null) return;

        if (gameView.SelectedCardView != null)
        {
            var selectedCard = gameView.SelectedCardView.Card;
            var sourcePile = gameView.SelectedSourcePile;
            if (selectedCard != null && sourcePile != null && Pile != sourcePile)
            {
                var cardsToMove = GetCardsFromCard(selectedCard, sourcePile);
                if (gameView.CanMoveCards(cardsToMove, Pile))
                {
                    gameView.TryMoveCards(cardsToMove, sourcePile, Pile);
                }
            }
            gameView.SelectedCardView.ClearSelection();
            gameView.SelectedCardView = null;
            gameView.SelectedSourcePile = null;
        }
    }
}
