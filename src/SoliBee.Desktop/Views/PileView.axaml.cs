using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
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

    static PileView()
    {
        PileProperty.Changed.AddClassHandler<PileView>((x, e) => x.OnPileChanged(e));
    }

    public PileView()
    {
        InitializeComponent();
        this.Loaded += (s, e) => UpdateCardsLayout();
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
                    // Batch exhausted — prompt user to draw again
                    CardsCanvas.Children.Clear();
                    EmptyOutline.IsVisible = true;
                    CardsCanvas.Width  = 128;
                    CardsCanvas.Height = 181;
                    return;
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

    private void PileView_PointerPressed(object sender, PointerPressedEventArgs e)
    {
        if (Pile == null) return;

        if (Pile.Type == PileType.Stock)
        {
            Clicked?.Invoke(this, EventArgs.Empty);
            return;
        }

        CardGameView? gameView = null;
        Avalonia.StyledElement? parent = this.Parent;
        while (parent != null)
        {
            if (parent is CardGameView cgv) { gameView = cgv; break; }
            parent = parent.Parent;
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
