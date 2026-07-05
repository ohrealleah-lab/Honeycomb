using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Threading;
using SoliBee.Core.Models;

namespace SoliBee.Desktop.Views;

public partial class WinAnimationView : UserControl
{
    public event EventHandler? PlayAgainRequested;
    public event EventHandler? CloseRequested;

    private DispatcherTimer? _timer;
    private readonly List<BouncingCard> _activeCards = new();
    private readonly Random _random = new();
    private const double Gravity = 0.6;
    private const double Elasticity = 0.82;
    private const int CardWidth = 85;
    private const int CardHeight = 125;

    private readonly Queue<Card> _spawnQueue = new();
    private int _spawnTicks = 0;
    private int _spawnIndex = 0;
    private int _foundationCount = 4;

    public WinAnimationView()
    {
        InitializeComponent();
    }

    // Shared by the win banner here and the "No Moves Remaining" banners in
    // GameView/FreecellView/SpiderView, so the score/time line always reads the same way.
    public static string FormatStatsLine(string scoreText, string timeText)
    {
        bool hasScore = !string.IsNullOrEmpty(scoreText);
        bool hasTime  = !string.IsNullOrEmpty(timeText);
        return (hasScore, hasTime) switch
        {
            (true, true)   => $"Score: {scoreText}  |  Time: {timeText}",
            (true, false)  => $"Score: {scoreText}",
            (false, true)  => $"Time: {timeText}",
            _              => ""
        };
    }

    public void StartAnimation(IEnumerable<Pile> foundations, string scoreText = "", string timeText = "")
    {
        StopAnimation();

        // Show win info panel with score and time
        WinStatsLabel.Text = FormatStatsLine(scoreText, timeText);
        WinInfoPanel.IsVisible = true;

        var foundationList = foundations.ToList();
        _foundationCount = Math.Max(1, foundationList.Count);
        _spawnIndex = 0;

        foreach (var f in foundationList)
        {
            var cards = new List<Card>(f.Cards);
            cards.Reverse();
            foreach (var card in cards)
                _spawnQueue.Enqueue(card);
        }

        _timer = new DispatcherTimer();
        _timer.Interval = TimeSpan.FromMilliseconds(16.66);
        _timer.Tick += Timer_Tick;
        _timer.Start();
    }

    // Backward-compatible no-arg overload
    public void StartAnimation()
    {
        var foundations = new List<Pile>();
        for (int i = 0; i < 4; i++)
        {
            var pile = new Pile($"Foundation_{i}", PileType.Foundation);
            var suits = new[] { CardSuit.Spades, CardSuit.Hearts, CardSuit.Diamonds, CardSuit.Clubs };
            for (int rank = 13; rank >= 1; rank--)
                pile.Cards.Add(new Card($"demo_{i}_{rank}", suits[i], rank, true));
            foundations.Add(pile);
        }
        StartAnimation(foundations);
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
            AnimationCanvas.Children.Remove(c.View);
        _activeCards.Clear();
        _spawnQueue.Clear();
        AnimationCanvas.Children.Clear();
        _spawnTicks  = 0;
        _spawnIndex  = 0;

        WinInfoPanel.IsVisible = false;
    }

    private void Timer_Tick(object? sender, EventArgs e)
    {
        _spawnTicks++;
        if (_spawnQueue.Count > 0 && _spawnTicks >= 12)
        {
            _spawnTicks = 0;
            var card = _spawnQueue.Dequeue();
            SpawnCard(card);
        }

        double canvasWidth  = AnimationCanvas.Bounds.Width;
        double canvasHeight = AnimationCanvas.Bounds.Height;

        for (int i = _activeCards.Count - 1; i >= 0; i--)
        {
            var card = _activeCards[i];
            card.Vy += Gravity;
            card.X  += card.Vx;
            card.Y  += card.Vy;

            if (card.Y + CardHeight >= canvasHeight && card.Vy > 0)
            {
                card.Y  = canvasHeight - CardHeight;
                card.Vy = -card.Vy * Elasticity;
            }

            if (card.X + CardWidth < 0 || card.X > canvasWidth || card.Y > canvasHeight + 10)
            {
                AnimationCanvas.Children.Remove(card.View);
                _activeCards.RemoveAt(i);
                continue;
            }

            Canvas.SetLeft(card.View, card.X);
            Canvas.SetTop(card.View,  card.Y);
        }

        // When all cards have left the screen, stop the ticker but keep the win panel visible
        if (_spawnQueue.Count == 0 && _activeCards.Count == 0)
        {
            _timer?.Stop();
            _timer = null;
        }
    }

    private void SpawnCard(Card card)
    {
        var cardView = new CardView { Card = card };
        AnimationCanvas.Children.Add(cardView);

        double sectionWidth = AnimationCanvas.Bounds.Width / _foundationCount;
        double startX = sectionWidth * (_spawnIndex % _foundationCount) + sectionWidth / 2.0 - CardWidth / 2.0;
        _spawnIndex++;

        var bouncingCard = new BouncingCard
        {
            View = cardView,
            X    = startX,
            Y    = 40,
            Vx   = _random.NextDouble() * 6 - 3,
            Vy   = -_random.NextDouble() * 4 - 1,
        };

        _activeCards.Add(bouncingCard);
    }

    private void PlayAgain_Click(object? sender, RoutedEventArgs e)
    {
        PlayAgainRequested?.Invoke(this, EventArgs.Empty);
    }

    // Dismisses the win banner without starting a new game — same "look but don't
    // force a decision" pattern as the No Moves Remaining banner's close button.
    private void Close_Click(object? sender, RoutedEventArgs e)
    {
        StopAnimation();
        CloseRequested?.Invoke(this, EventArgs.Empty);
    }
}

public class BouncingCard
{
    public required CardView View { get; set; }
    public double X  { get; set; }
    public double Y  { get; set; }
    public double Vx { get; set; }
    public double Vy { get; set; }
}
