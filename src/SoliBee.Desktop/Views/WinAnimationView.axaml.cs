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

    private DispatcherTimer? _timer;
    private readonly List<BouncingCard> _activeCards = new();
    private readonly Random _random = new();

    // Physics is expressed per-second (not per-tick) and scaled by measured dt each
    // tick, so the cascade looks the same regardless of how reliably the 60fps
    // DispatcherTimer actually fires — a stalled UI thread produces a bigger dt jump
    // instead of a slower-looking animation. Values below are carried over from the
    // previous fixed-per-tick constants (×60, since those assumed a 16.66ms tick).
    private const double Gravity           = 980; // px/s²
    private const double Elasticity        = 0.82;
    private const double HorizontalFriction = 0.97; // applied on each floor bounce
    private const int CardWidth  = 85;
    private const int CardHeight = 125;

    // Fading trail — a long, solid stack of ghost CardViews per bouncing card, sampled using
    // a stride of ticks to drastically reduce control overhead and prevent unresponsiveness.
    private const int TrailLength      = 35;
    private const int TrailStride      = 4;
    private const double MaxTrailOpacity = 1.0;
    private const double SpawnY        = 80;

    // Each queued entry remembers which foundation pile it came from, so a card spawns
    // above that pile's own screen column instead of a single shared point — cards
    // visibly come out of all four (or eight) foundation stacks, not just one spot.
    private readonly Queue<(Card Card, int FoundationIndex)> _spawnQueue = new();
    private int _foundationCount = 4;
    // Real center-X of each foundation pile, in this control's own coordinate space —
    // supplied by the caller (it's the one that knows its board layout). Null/short
    // falls back to spreading spawns evenly across the canvas width.
    private IReadOnlyList<double>? _foundationX;
    private double _timeSinceLastSpawn = 0;
    private const double SpawnIntervalSeconds = 0.18;
    private DateTime? _lastTickTime;

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

    public void StartAnimation(IEnumerable<Pile> foundations, IReadOnlyList<double>? foundationX = null,
        string scoreText = "", string timeText = "")
    {
        StopAnimation();

        // Show win info panel with score and time
        WinStatsLabel.Text = FormatStatsLine(scoreText, timeText);
        WinInfoPanel.IsVisible = true;
        WinParticleSystem.Burst(ParticleCanvas);

        var foundationList = foundations.ToList();
        _foundationCount = Math.Max(1, foundationList.Count);
        _foundationX = foundationX;

        // Highest rank first, one per pile per pass — an interleaved wave (all four
        // Kings, then all four Queens, ...) rather than draining one whole foundation
        // before starting the next, so the cascade visibly comes out of every
        // foundation stack instead of reading as "grouped by suit".
        for (int rank = 13; rank >= 1; rank--)
        {
            for (int pileIdx = 0; pileIdx < foundationList.Count; pileIdx++)
            {
                var card = foundationList[pileIdx].Cards.FirstOrDefault(c => c.Rank == rank);
                if (card != null) _spawnQueue.Enqueue((card, pileIdx));
            }
        }

        _timer = new DispatcherTimer();
        _timer.Interval = TimeSpan.FromMilliseconds(16.66);
        _timer.Tick += Timer_Tick;
        _timer.Start();
    }

    // Backward-compatible overload supporting foundation X positions
    public void StartAnimation(IReadOnlyList<double>? foundationX = null)
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
        StartAnimation(foundations, foundationX);
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
            foreach (var ghost in c.TrailViews) AnimationCanvas.Children.Remove(ghost);
        }
        _activeCards.Clear();
        _spawnQueue.Clear();
        AnimationCanvas.Children.Clear();
        ParticleCanvas.Children.Clear();
        _timeSinceLastSpawn = 0;
        _lastTickTime       = null;

        WinInfoPanel.IsVisible = false;
    }

    private void Timer_Tick(object? sender, EventArgs e)
    {
        var now = DateTime.UtcNow;
        // Clamp like the spec does — caps the jump after a UI-thread stall instead of
        // letting one giant dt teleport every card.
        double dt = _lastTickTime.HasValue
            ? Math.Min((now - _lastTickTime.Value).TotalSeconds, 1.0 / 30.0)
            : 1.0 / 60.0;
        _lastTickTime = now;

        _timeSinceLastSpawn += dt;
        if (_spawnQueue.Count > 0 && _timeSinceLastSpawn >= SpawnIntervalSeconds)
        {
            // Limit the spawn rate dynamically so we never have more than 150 card views on screen.
            // Each active card has 1 card view + TrailLength ghost views.
            if ((_activeCards.Count + 1) * (TrailLength + 1) <= 150)
            {
                _timeSinceLastSpawn = 0;
                var (card, foundationIndex) = _spawnQueue.Dequeue();
                SpawnCard(card, foundationIndex);
            }
        }

        double canvasWidth  = AnimationCanvas.Bounds.Width;
        double canvasHeight = AnimationCanvas.Bounds.Height;

        for (int i = _activeCards.Count - 1; i >= 0; i--)
        {
            var card = _activeCards[i];

            // Record the pre-move position for the fading trail before advancing.
            card.TrailHistory.Enqueue((card.X, card.Y));
            while (card.TrailHistory.Count > TrailLength * TrailStride) card.TrailHistory.Dequeue();

            card.Vy += Gravity * dt;
            card.X  += card.Vx * dt;
            card.Y  += card.Vy * dt;

            if (card.Y + CardHeight >= canvasHeight && card.Vy > 0)
            {
                card.Y   = canvasHeight - CardHeight;
                card.Vy  = -card.Vy * Elasticity;
                card.Vx *= HorizontalFriction;
            }

            if (card.X + CardWidth < 0 || card.X > canvasWidth || card.Y > canvasHeight + 10)
            {
                AnimationCanvas.Children.Remove(card.View);
                foreach (var ghost in card.TrailViews) AnimationCanvas.Children.Remove(ghost);
                _activeCards.RemoveAt(i);
                continue;
            }

            Canvas.SetLeft(card.View, card.X);
            Canvas.SetTop(card.View,  card.Y);

            var history = card.TrailHistory.ToArray(); // oldest first
            for (int gi = 0; gi < TrailLength; gi++)
            {
                var ghost = card.TrailViews[gi];
                int historyIndex = gi * TrailStride;
                if (historyIndex < history.Length)
                {
                    var (hx, hy) = history[historyIndex];
                    Canvas.SetLeft(ghost, hx);
                    Canvas.SetTop(ghost, hy);
                    // Classic solitaire solid stack look: keep cards fully opaque,
                    // and only fade out the oldest 15% of the trail smoothly.
                    double opacity = MaxTrailOpacity;
                    int fadeLength = Math.Min(6, TrailLength / 5);
                    if (gi < fadeLength)
                    {
                        opacity = MaxTrailOpacity * gi / fadeLength;
                    }
                    ghost.Opacity = opacity;
                }
                else
                {
                    ghost.Opacity = 0;
                }
            }
        }

        // When all cards have left the screen, stop the ticker but keep the win panel visible
        if (_spawnQueue.Count == 0 && _activeCards.Count == 0)
        {
            _timer?.Stop();
            _timer = null;
        }
    }

    private void SpawnCard(Card card, int foundationIndex)
    {
        // Trail ghosts are created once per bouncing card and just repositioned/faded
        // every tick (never reallocated), added before the main view so they render
        // behind it.
        var trailViews = new List<CardView>(TrailLength);
        for (int i = 0; i < TrailLength; i++)
        {
            var ghost = new CardView { Card = card, IsHitTestVisible = false, Opacity = 0 };
            trailViews.Add(ghost);
            AnimationCanvas.Children.Add(ghost);
        }

        var cardView = new CardView { Card = card };
        AnimationCanvas.Children.Add(cardView);

        // Spawn above this card's own foundation pile's real screen position when the
        // caller supplied one; otherwise fall back to spreading spawns evenly across
        // the canvas width (used by the parameterless demo overload).
        double startX;
        if (_foundationX != null && foundationIndex < _foundationX.Count)
        {
            startX = _foundationX[foundationIndex] - CardWidth / 2.0;
        }
        else
        {
            double sectionWidth = AnimationCanvas.Bounds.Width / _foundationCount;
            startX = sectionWidth * foundationIndex + sectionWidth / 2.0 - CardWidth / 2.0;
        }

        var bouncingCard = new BouncingCard
        {
            View = cardView,
            X    = startX,
            Y    = SpawnY,
            Vx   = _random.NextDouble() * 480 - 240,          // -240..240 px/s
            Vy   = -(_random.NextDouble() * 240 + 120),       // -360..-120 px/s
            TrailViews = trailViews,
        };

        _activeCards.Add(bouncingCard);
    }

    private void PlayAgain_Click(object? sender, RoutedEventArgs e)
    {
        PlayAgainRequested?.Invoke(this, EventArgs.Empty);
    }

    // Dismisses the win banner without stopping the card animation.
    private void Close_Click(object? sender, RoutedEventArgs e)
    {
        WinInfoPanel.IsVisible = false;
    }
}

public class BouncingCard
{
    public required CardView View { get; set; }
    public double X  { get; set; }
    public double Y  { get; set; }
    public double Vx { get; set; }
    public double Vy { get; set; }
    public List<CardView> TrailViews { get; set; } = new();
    public Queue<(double X, double Y)> TrailHistory { get; } = new();
}
