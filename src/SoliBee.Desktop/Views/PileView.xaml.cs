#if WINDOWS
using System;
using System.Collections.Generic;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using SoliBee.Core.Models;

namespace SoliBee.Desktop.Views;

public partial class PileView : UserControl
{
    public static readonly DependencyProperty PileProperty =
        DependencyProperty.Register(nameof(Pile), typeof(Pile), typeof(PileView), new PropertyMetadata(null, OnPileChanged));

    public Pile Pile
    {
        get => (Pile)GetValue(PileProperty);
        set => SetValue(PileProperty, value);
    }

    public event EventHandler Clicked;

    public PileView()
    {
        this.InitializeComponent();
    }

    private static void OnPileChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is PileView control)
        {
            control.UpdateCardsLayout();
        }
    }

    public void UpdateCardsLayout()
    {
        CardsCanvas.Children.Clear();

        if (Pile == null || Pile.Cards.Count == 0)
        {
            EmptyOutline.Visibility = Visibility.Visible;
            return;
        }

        EmptyOutline.Visibility = Visibility.Collapsed;

        double offset = 0;
        for (int i = 0; i < Pile.Cards.Count; i++)
        {
            var card = Pile.Cards[i];
            var cardView = new CardView { Card = card };

            Canvas.SetLeft(cardView, 0);
            Canvas.SetTop(cardView, offset);
            CardsCanvas.Children.Add(cardView);

            // Tableau piles are fanned downwards
            if (Pile.Type == PileType.Tableau)
            {
                offset += card.IsFaceUp ? 28 : 15;
            }
            // Waste is slightly fanned horizontally in standard Draw-3, but for simplicity, we stack with tiny offset
            else if (Pile.Type == PileType.Waste)
            {
                offset += 0.5; // Very minor stacking overlap
            }
        }

        // Adjust Canvas Height to accommodate fanning
        CardsCanvas.Height = 125 + offset;
    }

    private void PileView_PointerPressed(object sender, PointerRoutedEventArgs e)
    {
        if (Pile != null && Pile.Type == PileType.Stock)
        {
            Clicked?.Invoke(this, EventArgs.Empty);
        }
    }
}
#else
namespace SoliBee.Desktop.Views;

public class PileView
{
    // Dummy class for non-Windows compilation
}
#endif
