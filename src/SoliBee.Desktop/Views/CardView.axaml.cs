using System;
using System.Collections.Generic;
using System.IO;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using Avalonia.VisualTree;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using SoliBee.Desktop.Services;

namespace SoliBee.Desktop.Views;

public partial class CardView : UserControl
{
    private bool _isDragging;
    private Point _dragStartPoint;
    private List<CardView> _draggedStack = new();
    private PileView? _sourcePileView;
    private Dictionary<CardView, Point> _dragStartPositions = new();

    private static readonly Dictionary<string, Bitmap> _bitmapCache = new();
    private static readonly Dictionary<string, Bitmap> _customBitmapCache = new();

    private static Bitmap GetCachedBitmap(string resourcePath)
    {
        if (!_bitmapCache.TryGetValue(resourcePath, out var bitmap))
        {
            bitmap = new Bitmap(AssetLoader.Open(new Uri(resourcePath)));
            _bitmapCache[resourcePath] = bitmap;
        }
        return bitmap;
    }

    private static Bitmap GetCachedCustomBitmap(string filePath)
    {
        if (!_customBitmapCache.TryGetValue(filePath, out var bitmap))
        {
            bitmap = new Bitmap(filePath);
            _customBitmapCache[filePath] = bitmap;
        }
        return bitmap;
    }

    public static readonly StyledProperty<Card?> CardProperty =
        AvaloniaProperty.Register<CardView, Card?>(nameof(Card), defaultValue: null);

    public Card? Card
    {
        get => GetValue(CardProperty);
        set => SetValue(CardProperty, value);
    }

    static CardView()
    {
        CardProperty.Changed.AddClassHandler<CardView>((x, e) => x.OnCardChanged(e));
    }

    public CardView()
    {
        InitializeComponent();
        this.Loaded += (s, e) => UpdateCardFace();
    }

    private void OnCardChanged(AvaloniaPropertyChangedEventArgs e)
    {
        UpdateCardFace();
    }

    public void UpdateCardFace()
    {
        if (Card == null || CardFace == null || CardBack == null || CardBackImage == null || SuitCanvas == null) return;

        if (Card.IsFaceUp)
        {
            CardFace.IsVisible = true;
            CardBack.IsVisible = false;

            // Update rank text (Top-left & Bottom-right)
            string rankStr = Card.Rank switch
            {
                1 => "A",
                11 => "J",
                12 => "Q",
                13 => "K",
                _ => Card.Rank.ToString()
            };
            RankText.Text = rankStr;
            RankTextBottom.Text = rankStr;

            // Update suit character & color
            bool isRed = Card.Suit == CardSuit.Hearts || Card.Suit == CardSuit.Diamonds;
            var colorHex = isRed ? "#CC1A1A" : "#1A1A1A"; // Deep crimson and dark charcoal black
            var color = Color.Parse(colorHex);
            var brush = new SolidColorBrush(color);
            RankText.Foreground = brush;
            RankTextBottom.Foreground = brush;
            MiniSuitText.Foreground = brush;
            MiniSuitTextBottom.Foreground = brush;

            string suitChar = Card.Suit switch
            {
                CardSuit.Spades => "♠",
                CardSuit.Hearts => "♥",
                CardSuit.Diamonds => "♦",
                CardSuit.Clubs => "♣",
                _ => ""
            };
            MiniSuitText.Text = suitChar;
            MiniSuitTextBottom.Text = suitChar;

            // Hide/Reset center components
            SuitCanvas.IsVisible = false;
            LargeAceText.IsVisible = false;
            FaceCardImage.IsVisible = false;

            if (Card.Rank == 1)
            {
                // Ace
                LargeAceText.IsVisible = true;
                LargeAceText.Text = suitChar;
                LargeAceText.Foreground = brush;
            }
            else if (Card.Rank >= 11 && Card.Rank <= 13)
            {
                // Face Cards (J, Q, K)
                FaceCardImage.IsVisible = true;
                string filename = Card.Rank switch
                {
                    11 => isRed ? "red j.png" : "J.png",
                    12 => isRed ? "red q.png" : "Q.png",
                    13 => isRed ? "red k.png" : "K.png",
                    _ => ""
                };
                
                try
                {
                    string resourceUri = $"avares://SoliBee.Desktop/Assets/{filename}";
                    FaceCardImage.Source = GetCachedBitmap(resourceUri);
                }
                catch
                {
                    // Fallback to text rank representation
                    FaceCardImage.IsVisible = false;
                    LargeAceText.IsVisible = true;
                    LargeAceText.Text = rankStr;
                    LargeAceText.Foreground = brush;
                }
            }
            else
            {
                // Numbered Cards (2-10)
                SuitCanvas.IsVisible = true;
                PopulateSuitCanvas(Card.Rank, suitChar, brush);
            }
        }
        else
        {
            CardFace.IsVisible = false;
            CardBack.IsVisible = true;

            ApplyCardBackTheme();
        }
    }

    private void PopulateSuitCanvas(int rank, string suitChar, IBrush brush)
    {
        SuitCanvas.Children.Clear();

        var positions = positionsFor(rank);
        foreach (var pos in positions)
        {
            var textBlock = new TextBlock
            {
                Text = suitChar,
                FontSize = 32,
                FontWeight = FontWeight.Bold,
                Foreground = brush,
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
                VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center,
                TextAlignment = TextAlignment.Center
            };

            var container = new Grid
            {
                Width = 36,
                Height = 36,
                Children = { textBlock },
                RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative)
            };

            if (pos.isUpsideDown)
            {
                container.RenderTransform = new RotateTransform(180);
            }

            // Center of Canvas: (43, 69). Container is 36x36.
            // Center the container exactly at (43 + pos.x, 69 + pos.y).
            double left = 43 + pos.x - 18;
            double top = 69 + pos.y - 18;

            Canvas.SetLeft(container, left);
            Canvas.SetTop(container, top);
            SuitCanvas.Children.Add(container);
        }
    }

    private struct SuitPosition
    {
        public double x;
        public double y;
        public bool isUpsideDown;
        public SuitPosition(double x, double y, bool isUpsideDown)
        {
            this.x = x;
            this.y = y;
            this.isUpsideDown = isUpsideDown;
        }
    }

    private List<SuitPosition> positionsFor(int rank)
    {
        return rank switch
        {
            2 => new()
            {
                new(0, -42, false),
                new(0, 42, true)
            },
            3 => new()
            {
                new(0, -42, false),
                new(0, 0, false),
                new(0, 42, true)
            },
            4 => new()
            {
                new(-26, -42, false),
                new(26, -42, false),
                new(-26, 42, true),
                new(26, 42, true)
            },
            5 => new()
            {
                new(-26, -42, false),
                new(26, -42, false),
                new(0, 0, false),
                new(-26, 42, true),
                new(26, 42, true)
            },
            6 => new()
            {
                new(-26, -42, false),
                new(26, -42, false),
                new(-26, 0, false),
                new(26, 0, false),
                new(-26, 42, true),
                new(26, 42, true)
            },
            7 => new()
            {
                new(-26, -42, false),
                new(26, -42, false),
                new(-26, 0, false),
                new(26, 0, false),
                new(-26, 42, true),
                new(26, 42, true),
                new(0, -21, false)
            },
            8 => new()
            {
                new(-26, -42, false),
                new(26, -42, false),
                new(-26, 0, false),
                new(26, 0, false),
                new(-26, 42, true),
                new(26, 42, true),
                new(0, -21, false),
                new(0, 21, true)
            },
            9 => new()
            {
                new(-26, -42, false),
                new(26, -42, false),
                new(-26, -14, false),
                new(26, -14, false),
                new(-26, 14, true),
                new(26, 14, true),
                new(-26, 42, true),
                new(26, 42, true),
                new(0, 0, false)
            },
            10 => new()
            {
                new(-26, -42, false),
                new(26, -42, false),
                new(-26, -14, false),
                new(26, -14, false),
                new(-26, 14, true),
                new(26, 14, true),
                new(-26, 42, true),
                new(26, 42, true),
                new(0, -27, false),
                new(0, 27, true)
            },
            _ => new()
        };
    }

    private void ApplyCardBackTheme()
    {
        var options = SettingsService.LoadOptions();
        var theme = options.CardBackTheme;

        string filename = "vulpera.png";
        double scale = 1.0;
        double offsetX = 0;
        double offsetY = 0;
        bool isDingwall = false;
        bool isCustom = false;
        string? customPath = null;

        if (theme == "Dingwall")
        {
            filename = "dingwall.jpg";
            isDingwall = true;
        }
        else if (theme == "Moogle")
        {
            filename = "moogle.jpg";
            scale = 1.25;
            offsetX = options.CardBackOffsetX;
            offsetY = options.CardBackOffsetY;
        }
        else if (theme == "Vulpera")
        {
            filename = "vulpera.png";
        }
        else
        {
            var customBack = options.CustomCardBacks.Find(c => c.Name == theme);
            if (customBack != null)
            {
                isCustom = true;
                customPath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "SoliBee",
                    "CardBacks",
                    customBack.FileName
                );
                scale = customBack.Scale;
                offsetX = customBack.OffsetX;
                offsetY = customBack.OffsetY;
            }
            else
            {
                filename = "vulpera.png";
            }
        }

        try
        {
            if (isCustom && customPath != null && File.Exists(customPath))
            {
                CardBackImage.Source = GetCachedCustomBitmap(customPath);
            }
            else
            {
                string resourceUri = $"avares://SoliBee.Desktop/Assets/{filename}";
                CardBackImage.Source = GetCachedBitmap(resourceUri);
            }
        }
        catch
        {
            // Fallback
        }

        if (isDingwall)
        {
            CardBackImage.Width = 128;
            CardBackImage.Height = 181;
            CardBackImage.Stretch = Stretch.Fill;
            CardBackImage.RenderTransform = null;
        }
        else
        {
            CardBackImage.Width = 120;
            CardBackImage.Height = 173;
            CardBackImage.Stretch = Stretch.Uniform;
            
            if (Math.Abs(scale - 1.0) > 0.01 || Math.Abs(offsetX) > 0.01 || Math.Abs(offsetY) > 0.01)
            {
                var group = new TransformGroup();
                group.Children.Add(new ScaleTransform(scale, scale));
                group.Children.Add(new TranslateTransform(offsetX, offsetY));
                CardBackImage.RenderTransform = group;
            }
            else
            {
                CardBackImage.RenderTransform = null;
            }
        }
    }

    public Pile? ParentPile
    {
        get
        {
            var parent = this.Parent;
            while (parent != null)
            {
                if (parent is PileView pv) return pv.Pile;
                parent = parent.Parent;
            }
            return null;
        }
    }

    public void Highlight()
    {
        if (CardFace != null)
        {
            CardFace.BorderBrush = new SolidColorBrush(Colors.Gold);
            CardFace.BorderThickness = new Thickness(3);
        }
    }

    public void ClearSelection()
    {
        if (CardFace != null)
        {
            CardFace.BorderBrush = new SolidColorBrush(Color.Parse("#D9000000"));
            CardFace.BorderThickness = new Thickness(0.75);
        }
    }

    private void CardView_PointerPressed(object sender, PointerPressedEventArgs e)
    {
        if (Card == null || !Card.IsFaceUp) return;

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

        if (gameView == null || gameView.DataContext is not GameViewModel vm) return;

        // Find parent PileView
        PileView? pileView = null;
        parent = this.Parent;
        while (parent != null)
        {
            if (parent is PileView pv)
            {
                pileView = pv;
                break;
            }
            parent = parent.Parent;
        }
        if (pileView == null || pileView.Pile == null) return;

        var clickCount = e.ClickCount;

        if (clickCount == 2)
        {
            // Double-click: try to move to foundation
            foreach (var f in vm.Foundations)
            {
                if (vm.CanMoveCard(Card, f))
                {
                    vm.MoveCard(Card, f);
                    SoundService.PlaySnap();
                    if (gameView.SelectedCardView != null)
                    {
                        gameView.SelectedCardView.ClearSelection();
                        gameView.SelectedCardView = null;
                    }
                    e.Handled = true;
                    return;
                }
            }
        }
        else
        {
            // Single-click / Start Drag
            var dragCanvas = gameView.FindControl<Canvas>("DragCanvas");
            if (dragCanvas != null)
            {
                _isDragging = true;
                _dragStartPoint = e.GetPosition(gameView);
                _sourcePileView = pileView;

                // Build the dragged stack (this card and any cards on top of it in the same pile)
                _draggedStack.Clear();
                _dragStartPositions.Clear();
                var canvas = pileView.FindControl<Canvas>("CardsCanvas");
                if (canvas != null)
                {
                    bool foundThis = false;
                    foreach (var child in canvas.Children)
                    {
                        if (child is CardView cv)
                        {
                            if (cv == this) foundThis = true;
                            if (foundThis)
                            {
                                _draggedStack.Add(cv);
                            }
                        }
                    }
                }

                // Record visual positions before detaching from parent canvas
                foreach (var cv in _draggedStack)
                {
                    var pos = cv.TranslatePoint(new Point(0, 0), gameView);
                    _dragStartPositions[cv] = pos ?? new Point(0, 0);
                }

                // Temporarily detach from original pile canvas and attach to DragCanvas
                foreach (var cv in _draggedStack)
                {
                    var originalCanvas = cv.Parent as Canvas;
                    if (originalCanvas != null)
                    {
                        originalCanvas.Children.Remove(cv);
                    }
                    dragCanvas.Children.Add(cv);

                    // Set coordinates directly on the DragCanvas
                    Canvas.SetLeft(cv, _dragStartPositions[cv].X);
                    Canvas.SetTop(cv, _dragStartPositions[cv].Y);
                }

                // Capture pointer on this reparented control
                e.Pointer.Capture(this);
            }

            // Click handling selection
            if (gameView.SelectedCardView == null)
            {
                // Select this card
                gameView.SelectedCardView = this;
                this.Highlight();
            }
            else
            {
                // Try to move previously selected card to this card's pile
                var selectedCard = gameView.SelectedCardView.Card;
                if (selectedCard != null && pileView.Pile != gameView.SelectedCardView.ParentPile)
                {
                    if (vm.CanMoveCard(selectedCard, pileView.Pile))
                    {
                        vm.MoveCard(selectedCard, pileView.Pile);
                        SoundService.PlaySnap();
                        gameView.SelectedCardView.ClearSelection();
                        gameView.SelectedCardView = null;
                        
                        // Cancel drag state
                        e.Pointer.Capture(null);
                        _isDragging = false;
                        ResetDraggedStack(gameView);
                    }
                    else
                    {
                        // Select this new card instead
                        gameView.SelectedCardView.ClearSelection();
                        gameView.SelectedCardView = this;
                        this.Highlight();
                    }
                }
                else
                {
                    // Clicked same pile: if it's a different card, select it instead. Otherwise deselect.
                    var previousSelection = gameView.SelectedCardView;
                    previousSelection.ClearSelection();
                    if (previousSelection != this)
                    {
                        gameView.SelectedCardView = this;
                        this.Highlight();
                    }
                    else
                    {
                        gameView.SelectedCardView = null;
                        // Cancel drag state
                        e.Pointer.Capture(null);
                        _isDragging = false;
                        ResetDraggedStack(gameView);
                    }
                }
            }
        }

        e.Handled = true;
    }

    private void CardView_PointerMoved(object sender, PointerEventArgs e)
    {
        if (!_isDragging || Card == null) return;

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
        if (gameView == null) return;

        var currentPoint = e.GetPosition(gameView);
        double dx = currentPoint.X - _dragStartPoint.X;
        double dy = currentPoint.Y - _dragStartPoint.Y;

        // Move all cards in the stack directly on the DragCanvas
        foreach (var cv in _draggedStack)
        {
            if (_dragStartPositions.TryGetValue(cv, out var startPos))
            {
                Canvas.SetLeft(cv, startPos.X + dx);
                Canvas.SetTop(cv, startPos.Y + dy);
            }
        }

        e.Handled = true;
    }

    private void CardView_PointerReleased(object sender, PointerReleasedEventArgs e)
    {
        if (!_isDragging) return;

        e.Pointer.Capture(null);
        _isDragging = false;

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
        if (gameView == null || gameView.DataContext is not GameViewModel vm)
        {
            ResetDraggedStack(gameView);
            return;
        }

        var dropPoint = e.GetPosition(gameView);

        // Detect target pile by finding which pile contains the drop point
        PileView? targetPileView = FindTargetPileView(gameView, dropPoint);

        bool moved = false;
        if (targetPileView != null && targetPileView != _sourcePileView && targetPileView.Pile != null)
        {
            if (vm.CanMoveCard(Card!, targetPileView.Pile))
            {
                vm.MoveCard(Card!, targetPileView.Pile);
                SoundService.PlaySnap();
                moved = true;

                if (gameView.SelectedCardView != null)
                {
                    gameView.SelectedCardView.ClearSelection();
                    gameView.SelectedCardView = null;
                }
            }
        }

        ResetDraggedStack(gameView);

        var dx = Math.Abs(dropPoint.X - _dragStartPoint.X);
        var dy = Math.Abs(dropPoint.Y - _dragStartPoint.Y);
        if (!moved && (dx > 5 || dy > 5))
        {
            if (gameView.SelectedCardView != null)
            {
                gameView.SelectedCardView.ClearSelection();
                gameView.SelectedCardView = null;
            }
        }

        e.Handled = true;
    }

    private void ResetDraggedStack(GameView? gameView)
    {
        if (gameView != null)
        {
            var dragCanvas = gameView.FindControl<Canvas>("DragCanvas");
            if (dragCanvas != null)
            {
                foreach (var cv in _draggedStack)
                {
                    dragCanvas.Children.Remove(cv);
                }
            }
        }

        if (_sourcePileView != null)
        {
            _sourcePileView.UpdateCardsLayout();
        }

        _draggedStack.Clear();
        _dragStartPositions.Clear();
        _sourcePileView = null;
    }

    private PileView? FindTargetPileView(GameView gameView, Point dropPoint)
    {
        var piles = new List<PileView>();
        FindPileViewsRecursive(gameView, piles);

        foreach (var pv in piles)
        {
            var localPos = gameView.TranslatePoint(dropPoint, pv);
            if (localPos.HasValue)
            {
                var width = pv.Bounds.Width > 0 ? pv.Bounds.Width : 128;
                var height = pv.Bounds.Height > 0 ? pv.Bounds.Height : 181;
                if (localPos.Value.X >= 0 && localPos.Value.X <= width &&
                    localPos.Value.Y >= 0 && localPos.Value.Y <= height)
                {
                    return pv;
                }
            }
        }

        return null;
    }

    private void FindPileViewsRecursive(Visual parent, List<PileView> result)
    {
        foreach (var child in parent.GetVisualChildren())
        {
            if (child is PileView pv)
            {
                result.Add(pv);
            }
            else
            {
                FindPileViewsRecursive(child, result);
            }
        }
    }
}
