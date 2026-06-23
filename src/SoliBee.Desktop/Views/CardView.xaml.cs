#if WINDOWS
using System;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

public partial class CardView : UserControl
{
    public static readonly DependencyProperty CardProperty =
        DependencyProperty.Register(nameof(Card), typeof(Card), typeof(CardView), new PropertyMetadata(null, OnCardChanged));

    public Card Card
    {
        get => (Card)GetValue(CardProperty);
        set => SetValue(CardProperty, value);
    }

    // Standard vector path definitions for card suits (SVG data format)
    private const string HeartPath = "M 12,5 C 10,2 6,2 4,5 2,8 2,12 12,21 22,12 22,8 20,5 18,2 14,2 12,5 Z";
    private const string DiamondPath = "M 12,2 22,12 12,22 2,12 Z";
    private const string SpadePath = "M 12,2 C 10.5,3.5 5,10.5 5,13.5 A 5,5 0 0,0 15,13.5 C 15,10.5 9.5,3.5 12,2 Z M 12,17 L 12,22 M 8,22 L 16,22";
    private const string ClubPath = "M 12,6 A 3.5,3.5 0 1 0 8.5,9.5 A 3.5,3.5 0 1 0 12,6 Z M 12,6 A 3.5,3.5 0 1 0 15.5,9.5 A 3.5,3.5 0 1 0 12,6 Z M 12,6 A 3.5,3.5 0 1 0 12,2.5 A 3.5,3.5 0 1 0 12,6 Z M 12,9 L 12,14 M 9,14 L 15,14";

    public CardView()
    {
        this.InitializeComponent();
    }

    private static void OnCardChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is CardView control)
        {
            control.UpdateCardFace();
        }
    }

    public void UpdateCardFace()
    {
        if (Card == null) return;

        if (Card.IsFaceUp)
        {
            CardFace.Visibility = Visibility.Visible;
            CardBack.Visibility = Visibility.Collapsed;

            // Update rank text
            RankText.Text = Card.Rank switch
            {
                1 => "A",
                11 => "J",
                12 => "Q",
                13 => "K",
                _ => Card.Rank.ToString()
            };

            // Update suit character & color
            bool isRed = Card.Suit == CardSuit.Hearts || Card.Suit == CardSuit.Diamonds;
            var brush = new SolidColorBrush(isRed ? Colors.Crimson : Colors.Black);
            RankText.Foreground = brush;
            MiniSuitText.Foreground = brush;

            MiniSuitText.Text = Card.Suit switch
            {
                CardSuit.Spades => "♠",
                CardSuit.Hearts => "♥",
                CardSuit.Diamonds => "♦",
                CardSuit.Clubs => "♣",
                _ => ""
            };

            // Programmatically assign the central vector geometry path
            var pathString = Card.Suit switch
            {
                CardSuit.Hearts => HeartPath,
                CardSuit.Diamonds => DiamondPath,
                CardSuit.Spades => SpadePath,
                CardSuit.Clubs => ClubPath,
                _ => ""
            };

            try
            {
                SuitVector.Data = (Geometry)Microsoft.UI.Xaml.Markup.XamlBindingHelper.ConvertValue(typeof(Geometry), pathString);
                SuitVector.Fill = brush;
            }
            catch
            {
                // Fallback if geometry parse fails
            }
        }
        else
        {
            CardFace.Visibility = Visibility.Collapsed;
            CardBack.Visibility = Visibility.Visible;

            ApplyCardBackTheme();
        }
    }

    private void ApplyCardBackTheme()
    {
        var options = SettingsService.LoadOptions();
        var theme = options.CardBackTheme;

        // Custom gradients and vector drawing for CardBack based on theme selections
        if (theme == "Dingwall")
        {
            // Celtic Knot Theme: Deep Forest green and Gold vector
            var gradient = new LinearGradientBrush();
            gradient.StartPoint = new Windows.Foundation.Point(0, 0);
            gradient.EndPoint = new Windows.Foundation.Point(1, 1);
            gradient.GradientStops.Add(new GradientStop { Color = Microsoft.UI.ColorHelper.FromArgb(255, 11, 72, 33), Offset = 0 });
            gradient.GradientStops.Add(new GradientStop { Color = Microsoft.UI.ColorHelper.FromArgb(255, 19, 115, 54), Offset = 1 });
            CardBack.Background = gradient;

            // Celtic knot pattern vector
            CardBackPattern.Data = (Geometry)Microsoft.UI.Xaml.Markup.XamlBindingHelper.ConvertValue(
                typeof(Geometry), 
                "M 10,10 L 75,10 L 75,115 L 10,115 Z M 20,20 L 65,20 M 20,105 L 65,105 M 20,20 L 20,105 M 65,20 L 65,105"
            );
            CardBackPattern.Stroke = new SolidColorBrush(Colors.Gold);
        }
        else if (theme == "Moogle")
        {
            // Moogle Theme: Bright Royal Violet and Pink gradient
            var gradient = new LinearGradientBrush();
            gradient.StartPoint = new Windows.Foundation.Point(0, 0);
            gradient.EndPoint = new Windows.Foundation.Point(1, 1);
            gradient.GradientStops.Add(new GradientStop { Color = Microsoft.UI.ColorHelper.FromArgb(255, 142, 68, 173), Offset = 0 });
            gradient.GradientStops.Add(new GradientStop { Color = Microsoft.UI.ColorHelper.FromArgb(255, 236, 112, 99), Offset = 1 });
            CardBack.Background = gradient;

            // Balloon and cute angel wings vector paths
            CardBackPattern.Data = (Geometry)Microsoft.UI.Xaml.Markup.XamlBindingHelper.ConvertValue(
                typeof(Geometry), 
                "M 42.5,40 A 10,10 0 1,1 42.5,60 A 10,10 0 1,1 42.5,40 Z M 42.5,60 L 42.5,85"
            );
            CardBackPattern.Stroke = new SolidColorBrush(Colors.LightPink);
        }
        else // Vulpera (Default)
        {
            // Vulpera Theme: Geometric Wolf-head pattern & Midnight Blue and Red Gradient
            var gradient = new LinearGradientBrush();
            gradient.StartPoint = new Windows.Foundation.Point(0, 0);
            gradient.EndPoint = new Windows.Foundation.Point(1, 1);
            gradient.GradientStops.Add(new GradientStop { Color = Microsoft.UI.ColorHelper.FromArgb(255, 28, 40, 51), Offset = 0 });
            gradient.GradientStops.Add(new GradientStop { Color = Microsoft.UI.ColorHelper.FromArgb(255, 231, 76, 60), Offset = 1 });
            CardBack.Background = gradient;

            // Geometric sharp line wolf motif vector paths
            CardBackPattern.Data = (Geometry)Microsoft.UI.Xaml.Markup.XamlBindingHelper.ConvertValue(
                typeof(Geometry), 
                "M 42.5,35 L 25,65 L 60,65 Z M 25,65 L 35,95 L 42.5,80 L 50,95 L 60,65 Z"
            );
            CardBackPattern.Stroke = new SolidColorBrush(Colors.White);
        }
    }

    private void CardView_PointerPressed(object sender, PointerRoutedEventArgs e)
    {
        // Handle drag start or double-click to foundation
        if (Card == null || !Card.IsFaceUp) return;

        // Visual feedback / dynamic dragging snaps
        e.Handled = true;
    }
}
#else
namespace SoliBee.Desktop.Views;

public class CardView
{
    // Dummy class for non-Windows compilation
}
#endif
