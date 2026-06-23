#if WINDOWS
using System;
using System.Collections.Generic;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public partial class WinAnimationView : UserControl
{
    private DispatcherTimer _timer;
    private readonly List<BouncingCard> _activeCards = new();
    private readonly Random _random = new();
    private const double Gravity = 0.6;
    private const double Elasticity = 0.82;
    private const int CardWidth = 85;
    private const int CardHeight = 125;

    // Queue of cards to spawn cascade from foundation piles
    private readonly Queue<Card> _spawnQueue = new();
    private int _spawnTicks = 0;

    public WinAnimationView()
    {
        this.InitializeComponent();
    }

    public void StartAnimation()
    {
        StopAnimation();

        // Queue all 52 cards from foundations to spawn
        if (Parent is Grid boardGrid && boardGrid.Parent is GameView gameView && gameView.DataContext is GameViewModel vm)
        {
            foreach (var f in vm.Foundations)
            {
                // Put them in reverse order to slide off top down
                var cards = new List<Card>(f.Cards);
                cards.Reverse();
                foreach (var card in cards)
                {
                    _spawnQueue.Enqueue(card);
                }
            }
        }
        else
        {
            // Dummy card fallbacks if no VM is active
            for (int i = 0; i < 52; i++)
            {
                _spawnQueue.Enqueue(new Card($"card_{i}", CardSuit.Spades, (i % 13) + 1, true));
            }
        }

        _timer = new DispatcherTimer();
        _timer.Interval = TimeSpan.FromMilliseconds(16.66); // ~60 FPS
        _timer.Tick += Timer_Tick;
        _timer.Start();
    }

    public void StopAnimation()
    {
        if (_timer != null)
        {
            _timer.Stop();
            _timer.Tick -= Timer_Tick;
            _timer = null;
        }

        foreach (var c in _activeCards)
        {
            AnimationCanvas.Children.Remove(c.View);
        }
        _activeCards.Clear();
        _spawnQueue.Clear();
        AnimationCanvas.Children.Clear();
    }

    private void Timer_Tick(object sender, object e)
    {
        // Check if we should spawn the next card from foundations
        _spawnTicks++;
        if (_spawnQueue.Count > 0 && _spawnTicks >= 12) // Spawn every ~200ms
        {
            _spawnTicks = 0;
            var card = _spawnQueue.Dequeue();
            SpawnCard(card);
        }

        // Update bouncing positions
        double canvasWidth = AnimationCanvas.ActualWidth;
        double canvasHeight = AnimationCanvas.ActualHeight;

        for (int i = _activeCards.Count - 1; i >= 0; i--)
        {
            var card = _activeCards[i];
            card.Vy += Gravity;
            card.X += card.Vx;
            card.Y += card.Vy;

            // Bounce off bottom
            if (card.Y + CardHeight >= canvasHeight && card.Vy > 0)
            {
                card.Y = canvasHeight - CardHeight;
                card.Vy = -card.Vy * Elasticity;
            }

            // Remove card if it goes completely off left/right/bottom bounds
            if (card.X + CardWidth < 0 || card.X > canvasWidth || card.Y > canvasHeight + 10)
            {
                AnimationCanvas.Children.Remove(card.View);
                _activeCards.RemoveAt(i);
                continue;
            }

            // Position UI Element
            Canvas.SetLeft(card.View, card.X);
            Canvas.SetTop(card.View, card.Y);
        }

        // If animation is complete and all cards are gone, shut down timer
        if (_spawnQueue.Count == 0 && _activeCards.Count == 0)
        {
            StopAnimation();
            this.Visibility = Visibility.Collapsed;
        }
    }

    private void SpawnCard(Card card)
    {
        var cardView = new CardView { Card = card };
        AnimationCanvas.Children.Add(cardView);

        // Start coordinates from foundation top-right area
        double startX = AnimationCanvas.ActualWidth * 0.7; // ~Foundation area
        double startY = 40; // Top row

        var bouncingCard = new BouncingCard
        {
            View = cardView,
            X = startX,
            Y = startY,
            Vx = _random.NextDouble() * 6 - 3, // Initial horizontal speed
            Vy = -_random.NextDouble() * 4 - 1  // Initial upward kick
        };

        _activeCards.Add(bouncingCard);
    }
}

public class BouncingCard
{
    public CardView View { get; set; }
    public double X { get; set; }
    public double Y { get; set; }
    public double Vx { get; set; }
    public double Vy { get; set; }
}
#else
namespace SoliBee.Desktop.Views;

public class WinAnimationView
{
    public void StartAnimation() {}
    public void StopAnimation() {}
}
#endif
