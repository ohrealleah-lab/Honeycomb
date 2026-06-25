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
        CardsCanvas.Children.Clear();
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
                // Draw 3 mode: show top 3 cards fanned horizontally by 42px
                int cardsToShow = Math.Min(3, Pile.Cards.Count);
                int startIndex = Pile.Cards.Count - cardsToShow;
                
                for (int i = startIndex; i < Pile.Cards.Count; i++)
                {
                    if (i < 0) continue;
                    var card = Pile.Cards[i];
                    var cardView = new CardView { Card = card };
                    
                    double xOffset = (i - startIndex) * 42;
                    Canvas.SetLeft(cardView, xOffset);
                    Canvas.SetTop(cardView, 0);
                    CardsCanvas.Children.Add(cardView);
                }

                CardsCanvas.Width = 128 + Math.Max(0, cardsToShow - 1) * 42;
                CardsCanvas.Height = 181;
            }
            else
            {
                // Draw 1 mode: just show top card
                var card = Pile.Cards[^1];
                var cardView = new CardView { Card = card };
                Canvas.SetLeft(cardView, 0);
                Canvas.SetTop(cardView, 0);
                CardsCanvas.Children.Add(cardView);
                
                CardsCanvas.Width = 128;
                CardsCanvas.Height = 181;
            }
        }
        else
        {
            CardsCanvas.Width = 128;

            for (int i = 0; i < Pile.Cards.Count; i++)
            {
                var card = Pile.Cards[i];
                var cardView = new CardView();
                // Set IsAnimated before Card so ApplyCardBackTheme picks it up
                if (Pile.Type == PileType.Stock && i == Pile.Cards.Count - 1)
                    cardView.IsAnimated = true;
                cardView.Card = card;

                Canvas.SetLeft(cardView, 0);
                Canvas.SetTop(cardView, offset);
                CardsCanvas.Children.Add(cardView);

                // Tableau piles are fanned downwards (matches reference: faceUp ? 32 : 20)
                if (Pile.Type == PileType.Tableau)
                {
                    offset += card.IsFaceUp ? 32 : 20;
                }
            }

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
                    SoundService.PlaySnap();
                }
            }
            gameView.SelectedCardView.ClearSelection();
            gameView.SelectedCardView = null;
            gameView.SelectedSourcePile = null;
        }
    }
}
