using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using Avalonia.Media.Imaging;
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
    // instead of a slower-looking animation.
    private const double Gravity           = 980; // px/s²
    private const double Elasticity        = 0.85;
    private const double HorizontalFriction = 0.97; // applied on each real floor bounce
    // Below this incoming vertical speed, a "bounce" is just gravity re-triggering the
    // floor clamp on an already-settled card (happens almost every frame once resting,
    // since gravity keeps nudging Vy positive) — snap Vy to 0 and skip Elasticity/
    // HorizontalFriction in that case, or Vx would decay to zero every single frame
    // instead of once per real bounce, leaving the card stuck on screen forever and
    // the animation timer never stopping.
    private const double MinBounceVelocity = 80; // px/s
    private const int CardWidth  = 128;
    private const int CardHeight = 181;

    // Solid trail of ghost CardViews per bouncing card, at full opacity (no fade) —
    // matching the Mac original's ~0.83s Canvas trail.
    // Set to match Mac exactly: 50 trail points, recorded every frame.
    private const int TrailLength = 50;
    private const int TrailStride = 1;
    // Foundations sit at a top margin of only 10-30px across GameView/FreecellView/
    // SpiderView (their BoardPanel/BoardGrid top margins), and the foundation card
    // display itself is 181px tall — Mac's own SpawnY=80 (tuned to its own board's
    // margins) landed well inside that span here, so cards visually spawned from
    // partway down inside the foundation graphic and fell straight through it into the
    // tableau area below instead of appearing to launch from the top of the pile.
    private const double SpawnY = 20;

    // Caps concurrent bouncing cards directly (independent of TrailLength) so each
    // active card's 1 main view + TrailLength ghost views stays a bounded, known cost.
    // Set dynamically based on the number of foundations in the current game.
    private int _maxActiveCards = 6;

    // A card only frees its slot by drifting past the X bounds — Vx is a random draw
    // (-240..240 px/s) that can be small, and once "settled" (see MinBounceVelocity) it
    // never speeds up again. An unlucky low-Vx card could occupy a slot for a very long
    // time, and once all MaxActiveCards slots are stuck like that the whole queue stalls.
    // This hard cap guarantees every card frees its slot in bounded time regardless of
    // its Vx draw — set generously (~6-7 real bounces at Elasticity=0.85 before this
    // fires) so cards actually reach the floor and visibly bounce several times, like
    // the classic Windows Solitaire cascade, and so the whole cascade takes a while to
    // finish (matching the Mac original's pace) instead of feeling rushed.
    private const double MaxCardLifetimeSeconds = 9.0;

    // Each queued entry remembers which foundation pile it came from, so a card spawns
    // above that pile's own screen column instead of a single shared point — cards
    // visibly come out of all four (or eight) foundation stacks, not just one spot.
    //
    // The spawn X itself matches the Mac original exactly: a flat offset from screen
    // center per foundation index, not a real geometry lookup (Mac's own WinAnimationView.swift
    // never queries the foundation piles' actual on-screen positions — it only reads
    // which pile a card came from, then spawns at screenWidth*0.5 + index*98 + 40).
    // An earlier TranslatePoint-based version tried to compute each foundation's exact
    // real position instead, but never lined up correctly in practice (across Klondike's
    // fixed grid, Freecell's Auto/Star-column layout, and Spider's) and needed a
    // Dispatcher.Post workaround for the debug menu to avoid racing layout — matching
    // Mac's simpler formula sidesteps all of that.
    private readonly Queue<(Card Card, int FoundationIndex)> _spawnQueue = new();
    // Scaled from Mac's own (98, 40) by CardWidth's ratio to Mac's cardWidth (80).
    private const double FoundationSpawnOffsetX = 104.0;
    private const double FoundationSpawnNudgeX  = 42.5;
    private double _timeSinceLastSpawn = 0;
    // Set dynamically based on the number of foundations in the current game.
    private double _spawnInterval = 0.4;
    private IReadOnlyList<Point>? _foundationPoints;
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

    public void StartAnimation(IEnumerable<Pile> foundations, IReadOnlyList<Point>? foundationPoints = null,
        string scoreText = "", string timeText = "")
    {
        StopAnimation();
        _foundationPoints = foundationPoints;

        var foundationList = foundations.ToList();
        int numFoundations = foundationList.Count;

        // Adjust pace and concurrency based on deck size (e.g. Spider has 8 foundations, 104 cards)
        // so that the animation takes the same total time (~21s) and feels appropriately grand.
        if (numFoundations > 4)
        {
            _spawnInterval = 0.2;
            _maxActiveCards = 12;
        }
        else
        {
            _spawnInterval = 0.4;
            _maxActiveCards = 6;
        }

        // Show win info panel with score and time
        WinStatsLabel.Text = FormatStatsLine(scoreText, timeText);
        WinInfoPanel.IsVisible = true;
        // Blocks board interaction while the banner is up; Close_Click releases this
        // once the player dismisses the banner (see Close_Click).
        AnimationCanvas.IsHitTestVisible = true;
        WinParticleSystem.Burst(ParticleCanvas);

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

    // Backward-compatible overload — builds a fake full 52-card deck across 4
    // demo foundations, for the debug "Play Win Animation" menu.
    public void StartAnimation(IReadOnlyList<Point>? foundationPoints = null)
    {
        var suits = new[] { CardSuit.Spades, CardSuit.Hearts, CardSuit.Diamonds, CardSuit.Clubs };
        var foundations = new List<Pile>();
        for (int i = 0; i < 4; i++)
        {
            var pile = new Pile($"Foundation_{i}", PileType.Foundation);
            for (int rank = 13; rank >= 1; rank--)
                pile.Cards.Add(new Card($"demo_{i}_{rank}", suits[i], rank, true));
            foundations.Add(pile);
        }
        StartAnimation(foundations, foundationPoints);
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
        if (_spawnQueue.Count > 0 && _timeSinceLastSpawn >= _spawnInterval)
        {
            if (_activeCards.Count < _maxActiveCards)
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

            // Capture a visual snapshot of the card once it is laid out and fully rendered,
            // and assign it as the Source for the trail ghosts.
            if (card.TrailViews.Count > 0 && card.TrailViews[0] is Image firstGhost && firstGhost.Source == null && card.Age >= 0.1)
            {
                card.View.Measure(new Size(CardWidth, CardHeight));
                card.View.Arrange(new Rect(0, 0, CardWidth, CardHeight));

                var rtb = new RenderTargetBitmap(new PixelSize(CardWidth, CardHeight));
                rtb.Render(card.View);
                foreach (var ghost in card.TrailViews)
                {
                    if (ghost is Image img) img.Source = rtb;
                }
            }

            // Record the pre-move position for the trail before advancing.
            card.TrailHistory.Enqueue((card.X, card.Y));
            while (card.TrailHistory.Count > TrailLength * TrailStride) card.TrailHistory.Dequeue();

            card.Age += dt;
            card.X   += card.Vx * dt;
            card.Y   += card.Vy * dt;
            card.Vy  += Gravity * dt;

            if (card.Y + CardHeight >= canvasHeight && card.Vy > 0)
            {
                card.Y = canvasHeight - CardHeight;
                if (card.Vy > MinBounceVelocity)
                {
                    card.Vy  = -card.Vy * Elasticity;
                    card.Vx *= HorizontalFriction;
                }
                else
                {
                    // Settled — freeze the vertical bounce instead of letting gravity
                    // keep re-triggering this branch (and draining Vx) every frame.
                    // Vx keeps its last value so the card still drifts off-screen.
                    card.Vy = 0;
                }
            }

            // A hard floor impact can reflect upward with more speed than the card's own
            // launch velocity (e.g. a long fall followed by a bounce at Elasticity=0.85),
            // so without this it can fly up past the top of the canvas with nothing to
            // stop it. Snap to the top edge and zero the upward velocity — no artificial
            // "ceiling bounce", just let gravity pull it back down from there.
            if (card.Y < 0 && card.Vy < 0)
            {
                card.Y  = 0;
                card.Vy = 0;
            }

            if (card.X + CardWidth < 0 || card.X > canvasWidth || card.Y > canvasHeight + 10
                || card.Age >= MaxCardLifetimeSeconds)
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
                    ghost.Opacity = 1.0;
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
        var cardView = new CardView { Card = card };

        // Trail ghosts are created once per bouncing card as lightweight Image controls
        // with their Source assigned dynamically in the ticker once the main card is laid out.
        // This avoids the overhead of rendering hundreds of full templated CardView controls.
        var trailViews = new List<Control>(TrailLength);
        for (int i = 0; i < TrailLength; i++)
        {
            var ghost = new Image
            {
                Width = CardWidth,
                Height = CardHeight,
                IsHitTestVisible = false,
                Opacity = 0
            };
            trailViews.Add(ghost);
            AnimationCanvas.Children.Add(ghost);
        }

        AnimationCanvas.Children.Add(cardView);

        double startX;
        double startY;
        if (_foundationPoints != null && foundationIndex < _foundationPoints.Count)
        {
            startX = _foundationPoints[foundationIndex].X - CardWidth / 2.0;
            startY = _foundationPoints[foundationIndex].Y;
        }
        else
        {
            // Matches the Mac original exactly: a flat offset from screen center per
            // foundation index (see the field comments above _spawnQueue).
            double centerX = AnimationCanvas.Bounds.Width * 0.5
                + foundationIndex * FoundationSpawnOffsetX + FoundationSpawnNudgeX;
            startX = centerX - CardWidth / 2.0;
            startY = SpawnY;
        }

        var bouncingCard = new BouncingCard
        {
            View = cardView,
            X    = startX,
            Y    = startY,
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

    // Dismisses the win banner without stopping the card animation — cards keep
    // bouncing, but the board becomes interactive again immediately (AnimationCanvas
    // otherwise blocks every click over the whole board indefinitely, since nothing
    // else hides it until the next new game/restart).
    private void Close_Click(object? sender, RoutedEventArgs e)
    {
        WinInfoPanel.IsVisible = false;
        AnimationCanvas.IsHitTestVisible = false;
    }
}

public class BouncingCard
{
    public required CardView View { get; set; }
    public double X   { get; set; }
    public double Y   { get; set; }
    public double Vx  { get; set; }
    public double Vy  { get; set; }
    public double Age { get; set; }
    public List<Control> TrailViews { get; set; } = new();
    public Queue<(double X, double Y)> TrailHistory { get; } = new();
}
