using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using Avalonia.Threading;
using Avalonia.VisualTree;
using SkiaSharp;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.ViewModels;
using SoliBee.Desktop.Services;

namespace SoliBee.Desktop.Views;

public partial class CardView : UserControl
{
    public void DisableBorderAndShadowsForStretch()
    {
        CardBack.CornerRadius = new Avalonia.CornerRadius(0);
        CardBack.BorderThickness = new Avalonia.Thickness(0);
        CardBack.BoxShadow = new Avalonia.Media.BoxShadows();
        
        InnerCardBack.CornerRadius = new Avalonia.CornerRadius(0);
    }

    private bool _isDragging;
    private Point _dragStartPoint;
    private List<CardView> _draggedStack = new();
    private PileView? _sourcePileView;
    private Dictionary<CardView, Point> _dragStartPositions = new();
    private Canvas? _dragCanvas;

    private int _lastPipRank = -1;
    private string _lastPipSuit = "";
    private uint _lastPipArgb;

    // Manual double-click tracking, keyed by card identity rather than CardView instance —
    // PointerReleased rebuilds the source pile's CardView children, so the second click of a
    // double-click usually lands on a brand-new instance, making e.ClickCount/instance-bound
    // state (_sourcePileView) unreliable for detecting the gesture.
    private static DateTime _lastCardClickTime;
    private static string?  _lastCardClickId;
    private static Point    _lastCardClickPos;

    private static readonly Dictionary<string, Bitmap> _bitmapCache = new();
    private static readonly Dictionary<string, Bitmap> _customBitmapCache = new();
    private static readonly Dictionary<string, Bitmap> _backgroundBitmapCache = new();
    private static readonly Dictionary<string, (Bitmap[] Frames, int[] Durations)> _gifFrameCache = new();

    private static GameOptions? _cachedOptions;

    private static readonly Dictionary<CardGameView, List<PileView>> _pileViewListCache = new();

    private static readonly IReadOnlyDictionary<string, string> _houliAssets =
        new Dictionary<string, string>
        {
            ["Forest"]       = "forest.png",
            ["On the Water"] = "onthewater.png",
            ["Pareidolic"]   = "pareidolic.png",
            ["Pareidolic 2"] = "pareidolic2.png",
            ["Red Sky"]      = "redsky.png",
            ["Sunset"]       = "sunset.png",
        };

    // Pre-allocated brushes — only ~5 combinations exist, no need to allocate per render
    // internal so ThemeEditorWindow can mutate .Color for live debug preview
    internal static readonly SolidColorBrush _brushFaceBackNormal   = new(Colors.White);
    internal static readonly SolidColorBrush _brushFaceBorderNormal = new(Color.Parse("#D9000000"));
    internal static readonly SolidColorBrush _brushTextRed          = new(Color.Parse("#CC1A1A"));
    internal static readonly SolidColorBrush _brushTextBlackNormal  = new(Color.Parse("#1A1A1A"));
    internal static Color _normalShadowColor = Color.Parse("#26000000");

    private const int CardBackCacheW = 256; // 128 * 2
    private const int CardBackCacheH = 362; // 181 * 2
    private const int FaceArtCacheW  = 140; // 70 * 2
    private const int FaceArtCacheH  = 120; // 60 * 2

    public static void ApplyThemeColors(SoliBee.Core.Models.GameOptions options)
    {
        _cachedOptions = options;
        _pipBitmapCache.Clear();
        _aceBitmapCache.Clear();
        _brushFaceBackNormal.Color  = options.ThemeFaceBackNormal  != null ? Color.Parse(options.ThemeFaceBackNormal)  : Colors.White;
        _brushFaceBorderNormal.Color = options.ThemeFaceBorderNormal != null ? Color.Parse(options.ThemeFaceBorderNormal) : Color.Parse("#D9000000");
        _brushTextRed.Color          = options.ThemeTextRed          != null ? Color.Parse(options.ThemeTextRed)          : Color.Parse("#CC1A1A");
        _brushTextBlackNormal.Color  = options.ThemeTextBlackNormal  != null ? Color.Parse(options.ThemeTextBlackNormal)  : Color.Parse("#1A1A1A");
        _normalShadowColor           = options.ThemeCardShadow       != null ? Color.Parse(options.ThemeCardShadow)       : Color.Parse("#26000000");
    }

    internal static double FaceLetterFontSize = 90.0;

    internal static void BroadcastThemeChange() =>
        WeakReferenceMessenger.Default.Send(new FaceCardArtChangedMessage());

    public static void InvalidateAllCardViews(Visual root)
    {
        if (root == null) return;
        foreach (var visual in root.GetVisualDescendants())
        {
            if (visual is CardView cv)
            {
                cv.UpdateCardFace();
            }
        }
    }

    // Deliberately does NOT Dispose() the removed Bitmap(s) — a live CardView on the
    // actual game board can still hold one as its Image.Source at this exact moment
    // (board refreshes are dispatched asynchronously via FaceCardArtChangedMessage,
    // e.g. GameView's Dispatcher.UIThread.InvokeAsync(UpdateAllPilesLayout)), so an
    // immediate Dispose() here raced a pending render pass and crashed the app. Just
    // drop our cache reference; the CLR reclaims the underlying Bitmap once nothing
    // else references it, after the board has had a chance to swap to fresh art.
    public static void InvalidateFaceArtCache(string? filePath = null)
    {
        if (filePath != null)
        {
            // Single-path eviction (background file deleted by the user): safe to dispose
            // here because the Delete confirm flow clears all UI references before calling in.
            if (_customBitmapCache.TryGetValue(filePath, out var bmp))
            {
                bmp.Dispose();
                _customBitmapCache.Remove(filePath);
            }
            // Background bitmaps live in their own cache; evict from there too.
            if (_backgroundBitmapCache.TryGetValue(filePath, out var bgBmp))
            {
                bgBmp.Dispose();
                _backgroundBitmapCache.Remove(filePath);
            }
        }
        else
        {
            // Full wipe (theme switch). Do NOT Dispose() here — async board refreshes
            // (FaceCardArtChangedMessage → Dispatcher.UIThread.InvokeAsync) may still
            // hold a just-cleared entry as Image.Source in a pending render pass.
            // Dropping the cache reference is enough; the CLR reclaims the Bitmap
            // once nothing else references it.
            // Background bitmaps are intentionally excluded: they live in
            // _backgroundBitmapCache and MainWindow.ApplyBoardBackground re-loads
            // from there on every OptionsChangedMessage, so they must survive the wipe.
            _customBitmapCache.Clear();
        }
    }

    // Slide-in animation state (deal / draw / move)
    private DispatcherTimer? _slideAnimTimer;
    private int              _slideStepsLeft;
    private double           _slideFromX, _slideFromY;
    private bool             _slideFadeIn;
    private readonly TranslateTransform _slideTx = new();
    private const int SlideSteps = 9;

    private readonly HintPulseAnimation _hintPulse = new();
    private SolidColorBrush? _hintPulseBrush;

    public void BeginSlideIn(double fromX, double fromY, int durationMs = 180, bool fadeIn = false)
    {
        _slideAnimTimer?.Stop();
        _slideFromX  = fromX;
        _slideFromY  = fromY;
        _slideFadeIn = fadeIn;
        if (fadeIn) Opacity = 0;
        _slideStepsLeft = SlideSteps;
        RenderTransform = _slideTx;
        ApplySlideFrame();
        _slideAnimTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(Math.Max(1, durationMs / SlideSteps))
        };
        _slideAnimTimer.Tick += (_, _) =>
        {
            _slideStepsLeft--;
            ApplySlideFrame();
            if (_slideStepsLeft <= 0)
            {
                _slideAnimTimer!.Stop();
                _slideAnimTimer = null;
                RenderTransform = null;
                if (_slideFadeIn) { Opacity = 1.0; _slideFadeIn = false; }
            }
        };
        _slideAnimTimer.Start();
    }

    private void ApplySlideFrame()
    {
        double t      = 1.0 - (double)_slideStepsLeft / SlideSteps;
        double eased  = 1.0 - Math.Pow(1.0 - t, 3.0);
        _slideTx.X    = _slideFromX * (1.0 - eased);
        _slideTx.Y    = _slideFromY * (1.0 - eased);
        if (_slideFadeIn) Opacity = eased;
    }

    // GIF animation state — shared timer so all animated backs tick together
    private bool _isAnimated;
    private bool _isGifListener;
    private static DispatcherTimer? _sharedGifTimer;
    private static Bitmap[]? _sharedGifFrames;
    private static int[] _sharedGifDurations = Array.Empty<int>();
    private static int _sharedGifFrameIndex;
    private static readonly List<CardView> _gifListeners = new();

    public bool IsAnimated
    {
        get => _isAnimated;
        set
        {
            if (_isAnimated == value) return;
            _isAnimated = value;
            if (Card != null && !Card.IsFaceUp)
                ApplyCardBackTheme();
        }
    }

    private static Bitmap GetCachedBitmap(string resourcePath)
    {
        if (!_bitmapCache.TryGetValue(resourcePath, out var bitmap))
        {
            bitmap = new Bitmap(AssetLoader.Open(new Uri(resourcePath)));
            _bitmapCache[resourcePath] = bitmap;
        }
        return bitmap;
    }

    // Card backs (non-GIF) — cached at 2× render resolution
    private static Bitmap GetCachedCustomBitmap(string filePath, double scale, double offsetX, double offsetY)
    {
        string cacheKey = $"{filePath}_{scale}_{offsetX}_{offsetY}";
        if (!_customBitmapCache.TryGetValue(cacheKey, out var bitmap))
        {
            bitmap = CropAndScaleToDisplay(filePath, CardBackCacheW, CardBackCacheH, scale, offsetX, offsetY);
            _customBitmapCache[cacheKey] = bitmap;
        }
        return bitmap;
    }

    internal static Bitmap GetCachedFaceArtBitmap(string filePath, double scale, double offsetX, double offsetY)
    {
        string cacheKey = $"{filePath}_{scale}_{offsetX}_{offsetY}";
        if (_customBitmapCache.TryGetValue(cacheKey, out var cached)) return cached;
        var bitmap = LoadAndScaleFaceArt(filePath, scale, offsetX, offsetY);
        _customBitmapCache[cacheKey] = bitmap;
        return bitmap;
    }

    // Board background art — kept in its own cache (separate from face-art / card-backs)
    // so that InvalidateFaceArtCache() full-clears on theme switch never touch a bitmap
    // that is still assigned to MainWindow.BoardBackgroundImage.Source.
    internal static Bitmap GetCachedBackgroundBitmap(string filePath)
    {
        if (_backgroundBitmapCache.TryGetValue(filePath, out var cached)) return cached;
        var bitmap = new Bitmap(filePath);
        _backgroundBitmapCache[filePath] = bitmap;
        return bitmap;
    }

    private static Bitmap LoadAndScaleFaceArt(string filePath, double scale, double offsetX, double offsetY)
    {
        if (filePath.EndsWith(".gif", StringComparison.OrdinalIgnoreCase))
        {
            try
            {
                using var codec = SKCodec.Create(filePath);
                if (codec != null)
                {
                    var frameInfo = new SKImageInfo(codec.Info.Width, codec.Info.Height,
                        SKColorType.Bgra8888, SKAlphaType.Premul);
                    using var skBmp = new SKBitmap(frameInfo);
                    codec.GetPixels(frameInfo, skBmp.GetPixels(), new SKCodecOptions(0));
                    return CropAndScaleToDisplay(skBmp, FaceArtCacheW, FaceArtCacheH, scale, offsetX, offsetY, true);
                }
            }
            catch { }
            return new Bitmap(filePath);
        }
        return CropAndScaleToDisplay(filePath, FaceArtCacheW, FaceArtCacheH, scale, offsetX, offsetY, true);
    }

    private static Bitmap CropAndScaleToDisplay(string filePath, int targetW, int targetH, double scale, double offsetX, double offsetY, bool isFaceArt = false)
    {
        try
        {
            using var src = SKBitmap.Decode(filePath);
            if (src == null) return new Bitmap(filePath);
            return CropAndScaleToDisplay(src, targetW, targetH, scale, offsetX, offsetY, isFaceArt);
        }
        catch { return new Bitmap(filePath); }
    }

    private static Bitmap CropAndScaleToDisplay(SKBitmap src, int targetW, int targetH, double scale, double offsetX, double offsetY, bool isFaceArt = false)
    {
        try
        {
            using var surface = SKSurface.Create(new SKImageInfo(targetW, targetH, SKColorType.Bgra8888, SKAlphaType.Premul));
            var canvas = surface.Canvas;
            canvas.Clear(SKColors.Transparent);
            canvas.SetMatrix(SKMatrix.CreateIdentity());

            // The logical size of the container in the UI
            float logicalW = isFaceArt ? 70f : 128f;
            float logicalH = isFaceArt ? 60f : 181f;

            // Scale from logical size to target high-res size
            float ratioW = targetW / logicalW;
            float ratioH = targetH / logicalH;
            canvas.Scale(ratioW, ratioH);

            float cx = logicalW / 2f;
            float cy = logicalH / 2f;

            // Apply RenderTransform (Scale & Translate) around center
            canvas.Translate(cx, cy);
            canvas.Translate((float)offsetX, (float)offsetY);
            canvas.Scale((float)scale, (float)scale);
            canvas.Translate(-cx, -cy);

            // Apply Stretch="Uniform" which scales the image to fit inside the logical bounds, centered
            float uniformScale = Math.Min(logicalW / src.Width, logicalH / src.Height);
            canvas.Translate(cx, cy);
            canvas.Scale(uniformScale, uniformScale);
            canvas.Translate(-src.Width / 2f, -src.Height / 2f);

            using var paint = new SKPaint { FilterQuality = SKFilterQuality.High, IsAntialias = true };
            canvas.DrawImage(SKImage.FromBitmap(src), 0, 0, paint);

            using var snap = surface.Snapshot();
            using var work = SKBitmap.FromImage(snap);
            var wb = new WriteableBitmap(
                new PixelSize(work.Width, work.Height),
                new Vector(96, 96),
                PixelFormat.Bgra8888, AlphaFormat.Premul);
            using (var fb = wb.Lock())
                Marshal.Copy(work.Bytes, 0, fb.Address, work.ByteCount);
            return wb;
        }
        catch { return new WriteableBitmap(new PixelSize(1, 1), new Vector(96, 96), PixelFormat.Bgra8888, AlphaFormat.Premul); } // Fallback if crop fails
    }

    // ── Background preloaders ─────────────────────────────────────────────────

    // Warm the face-art cache for every stored art entry.
    // Already-cached paths are skipped. Safe to call repeatedly.
    public static void PreloadFaceArt()
    {
        foreach (var art in FaceCardArtService.GetAllArts())
        {
            var path = FaceCardArtService.GetFullPath(art);
            string cacheKey = $"{path}_{art.Scale}_{art.OffsetX}_{art.OffsetY}";
            if (_customBitmapCache.ContainsKey(cacheKey) || !File.Exists(path)) continue;

            var capturedPath = path;
            double s = art.Scale;
            double ox = art.OffsetX;
            double oy = art.OffsetY;
            Task.Run(() =>
            {
                try
                {
                    var bmp = LoadAndScaleFaceArt(capturedPath, s, ox, oy);
                    Dispatcher.UIThread.InvokeAsync(() =>
                    {
                        if (!_customBitmapCache.ContainsKey(cacheKey))
                            _customBitmapCache[cacheKey] = bmp;
                    });
                }
                catch { }
            });
        }
    }

    // Warm the card-back cache for every non-GIF custom back in options.
    public static void PreloadCardBacks(GameOptions options)
    {
        var backDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "SoliBee", "CardBacks");

        foreach (var cb in options.CustomCardBacks)
        {
            if (cb.FileName.EndsWith(".gif", StringComparison.OrdinalIgnoreCase)) continue;

            var path = Path.Combine(backDir, cb.FileName);
            string cacheKey = $"{path}_{cb.Scale}_{cb.OffsetX}_{cb.OffsetY}";
            if (_customBitmapCache.ContainsKey(cacheKey) || !File.Exists(path)) continue;

            var capturedPath = path;
            double s = cb.Scale;
            double ox = cb.OffsetX;
            double oy = cb.OffsetY;
            Task.Run(() =>
            {
                try
                {
                    var bmp = CropAndScaleToDisplay(capturedPath, CardBackCacheW, CardBackCacheH, s, ox, oy);
                    Dispatcher.UIThread.InvokeAsync(() =>
                    {
                        if (!_customBitmapCache.ContainsKey(cacheKey))
                            _customBitmapCache[cacheKey] = bmp;
                    });
                }
                catch { }
            });
        }
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
        this.Unloaded += (s, e) =>
        {
            StopGifAnimation();
            _slideAnimTimer?.Stop();
            _slideAnimTimer = null;
            RenderTransform = null;
            _hintPulse.Stop();
        };
    }

    private void OnCardChanged(AvaloniaPropertyChangedEventArgs e)
    {
        UpdateCardFace();
    }

    public void UpdateCardFace()
    {
        if (Card == null || CardFace == null || CardBack == null || CardBackImage == null || SuitCanvas == null || AcePipImage == null) return;

        if (Card.IsFaceUp)
        {
            CardFace.IsVisible = true;
            CardBack.IsVisible = false;

            CardFace.Background       = _brushFaceBackNormal;
            CardFace.BorderBrush      = _brushFaceBorderNormal;
            CardFace.BorderThickness  = new Avalonia.Thickness(0.75);
            CardFace.BoxShadow        = new BoxShadows(new BoxShadow { OffsetX = 0, OffsetY = 1.5, Blur = 1.5, Spread = 0, Color = _normalShadowColor });

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

            bool isRed = Card.Suit == CardSuit.Hearts || Card.Suit == CardSuit.Diamonds;
            var brush = isRed ? _brushTextRed : _brushTextBlackNormal;
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
            FaceLetterText.IsVisible = false;
            FaceCardImage.IsVisible = false;
            AcePipImage.IsVisible = false;

            // Custom face art takes priority over all other rendering for A/J/Q/K.
            // Any art loaded for a slot is always considered active — there's no
            // separate enable/disable state, only loaded-or-not.
            var faceSlot = FaceCardSlotExtensions.SlotFor(Card.Rank, Card.Suit);
            var customFaceArt = faceSlot.HasValue ? FaceCardArtService.GetArt(faceSlot.Value) : null;

            if (customFaceArt != null)
            {
                FaceCardImage.IsVisible = true;
                string fullPath = FaceCardArtService.GetFullPath(customFaceArt);
                if (fullPath.EndsWith(".gif", StringComparison.OrdinalIgnoreCase))
                {
                    FaceCardImage.Stretch = Avalonia.Media.Stretch.Uniform;
                    var tg = new TransformGroup();
                    tg.Children.Add(new ScaleTransform(customFaceArt.Scale, customFaceArt.Scale));
                    tg.Children.Add(new TranslateTransform(customFaceArt.OffsetX, customFaceArt.OffsetY));
                    FaceCardImage.RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative);
                    FaceCardImage.RenderTransform = tg;
                }
                else
                {
                    FaceCardImage.Stretch = Avalonia.Media.Stretch.Fill;
                    FaceCardImage.RenderTransform = null;
                }
                
                FaceCardImage.Width  = 70;
                FaceCardImage.Height = 60;
                CenterGrid.ClipToBounds = true;

                try
                {
                    FaceCardImage.Source = GetCachedFaceArtBitmap(fullPath, customFaceArt.Scale, customFaceArt.OffsetX, customFaceArt.OffsetY);
                }
                catch
                {
                    FaceCardImage.IsVisible = false;
                    if (Card.Rank == 1)
                    {
                        AcePipImage.Source = GetOrCreateAceBitmap(suitChar, brush);
                        AcePipImage.IsVisible = true;
                    }
                    else
                    {
                        LargeAceText.IsVisible = true;
                        LargeAceText.Text = rankStr;
                        LargeAceText.Foreground = brush;
                    }
                }
            }
            else
            {
                // Clear any leftover custom transforms
                FaceCardImage.RenderTransform = null;
                CenterGrid.ClipToBounds = false;

                if (Card.Rank == 1)
                {
                    AcePipImage.Source = GetOrCreateAceBitmap(suitChar, brush);
                    AcePipImage.IsVisible = true;
                }
                else if (Card.Rank >= 11 && Card.Rank <= 13)
                {
                    FaceLetterText.IsVisible  = true;
                    FaceLetterText.FontSize   = FaceLetterFontSize;
                    FaceLetterText.Text       = rankStr;
                    FaceLetterText.Foreground = brush;

                    double offsetX = 0;
                    double offsetY = 0;
                    if (Card.Rank == 11) // J
                    {
                        offsetX = -4;
                        offsetY = -10;
                    }
                    else if (Card.Rank == 12) // Q
                    {
                        offsetX = -5;
                    }
                    else if (Card.Rank == 13) // K
                    {
                        offsetX = -6;
                    }
                    FaceLetterText.RenderTransform = new TranslateTransform(offsetX, offsetY);
                }
                else
                {
                    // Numbered Cards (2-10)
                    SuitCanvas.IsVisible = true;
                    PopulateSuitCanvas(Card.Rank, suitChar, brush);
                }
            }
        }
        else
        {
            CardFace.IsVisible = false;
            CardBack.IsVisible = true;

            CardBack.Background       = _brushFaceBackNormal;
            CardBack.BorderBrush      = _brushFaceBorderNormal;
            CardBack.BorderThickness  = new Avalonia.Thickness(0.75);

            ApplyCardBackTheme();
        }
    }

    private static readonly Dictionary<(string suitChar, uint argb), Bitmap> _pipBitmapCache = new();
    private static readonly Dictionary<(string suitChar, uint argb), Bitmap> _aceBitmapCache  = new();

    private static float _pipFontSize = 87.5f;
    private static float _aceFontSize = 187.5f;

    public static void SetAceFontSize(float size)
    {
        _aceFontSize = size;
        _aceBitmapCache.Clear();
    }

    internal static Bitmap GetOrCreateAceBitmap(string suitChar, IBrush brush)
    {
        var color = brush is SolidColorBrush scb ? scb.Color : Colors.Black;
        uint argb = ((uint)color.A << 24) | ((uint)color.R << 16) | ((uint)color.G << 8) | color.B;
        var key = (suitChar, argb);
        if (_aceBitmapCache.TryGetValue(key, out var cached))
            return cached;

        const int bitmapSize = 215; // 2.5× for HiDPI; larger for crisp rendering at 1.25× card scale
        float fontSize = _aceFontSize;

        using var surface = SKSurface.Create(new SKImageInfo(bitmapSize, bitmapSize, SKColorType.Bgra8888, SKAlphaType.Premul));
        var skCanvas = surface.Canvas;
        skCanvas.Clear(SKColors.Transparent);

        var skColor = new SKColor(color.R, color.G, color.B, color.A);
        using var paint = new SKPaint
        {
            Color = skColor,
            IsAntialias = true,
            TextSize = fontSize,
            Typeface = SKTypeface.FromFamilyName("Segoe UI Symbol"),
        };

        var bounds = new SKRect();
        paint.MeasureText(suitChar, ref bounds);

        float x = bitmapSize / 2f - (bounds.Left + bounds.Right) / 2f;
        float y = bitmapSize / 2f - (bounds.Top + bounds.Bottom) / 2f;

        skCanvas.DrawText(suitChar, x, y, paint);

        using var skBmp = SKBitmap.FromImage(surface.Snapshot());
        var wb = new WriteableBitmap(
            new PixelSize(bitmapSize, bitmapSize),
            new Vector(96, 96),
            PixelFormat.Bgra8888, AlphaFormat.Premul);
        using (var fb = wb.Lock())
            Marshal.Copy(skBmp.Bytes, 0, fb.Address, skBmp.ByteCount);
        _aceBitmapCache[key] = wb;
        return wb;
    }

    private static Bitmap GetOrCreatePipBitmap(string suitChar, IBrush brush)
    {
        var color = brush is SolidColorBrush scb ? scb.Color : Colors.Black;
        uint argb = ((uint)color.A << 24) | ((uint)color.R << 16) | ((uint)color.G << 8) | color.B;
        var key = (suitChar, argb);
        if (_pipBitmapCache.TryGetValue(key, out var cached))
            return cached;

        const int bitmapSize = 90; // 2.5× resolution; larger for crisp rendering at 1.25× card scale
        float fontSize = _pipFontSize;

        using var surface = SKSurface.Create(new SKImageInfo(bitmapSize, bitmapSize, SKColorType.Bgra8888, SKAlphaType.Premul));
        var skCanvas = surface.Canvas;
        skCanvas.Clear(SKColors.Transparent);

        var skColor = new SKColor(color.R, color.G, color.B, color.A);
        using var paint = new SKPaint
        {
            Color = skColor,
            IsAntialias = true,
            TextSize = fontSize,
            Typeface = SKTypeface.FromFamilyName("Segoe UI Symbol"),
        };

        // Measure actual ink bounds relative to the baseline at the origin
        var bounds = new SKRect();
        paint.MeasureText(suitChar, ref bounds);

        // Place the baseline so the glyph's ink center lands exactly at the bitmap center
        float x = bitmapSize / 2f - (bounds.Left + bounds.Right) / 2f;
        float y = bitmapSize / 2f - (bounds.Top + bounds.Bottom) / 2f;

        skCanvas.DrawText(suitChar, x, y, paint);

        using var skBmp = SKBitmap.FromImage(surface.Snapshot());
        var wb = new WriteableBitmap(
            new PixelSize(bitmapSize, bitmapSize),
            new Vector(96, 96),
            PixelFormat.Bgra8888, AlphaFormat.Premul);
        using (var fb = wb.Lock())
            Marshal.Copy(skBmp.Bytes, 0, fb.Address, skBmp.ByteCount);
        _pipBitmapCache[key] = wb;
        return wb;
    }

    private void PopulateSuitCanvas(int rank, string suitChar, IBrush brush)
    {
        var color = brush is SolidColorBrush scb ? scb.Color : Colors.Black;
        uint argb = ((uint)color.A << 24) | ((uint)color.R << 16) | ((uint)color.G << 8) | color.B;
        if (rank == _lastPipRank && suitChar == _lastPipSuit && argb == _lastPipArgb) return;
        _lastPipRank = rank;
        _lastPipSuit = suitChar;
        _lastPipArgb = argb;

        SuitCanvas.Children.Clear();

        var positions = positionsFor(rank);
        foreach (var pos in positions)
        {
            var bitmap = GetOrCreatePipBitmap(suitChar, brush);
            var pipImage = new Image
            {
                Source = bitmap,
                Width = 36,
                Height = 36,
                Stretch = Stretch.Uniform,
            };

            var container = new Grid
            {
                Width = 36,
                Height = 36,
                Children = { pipImage },
                RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative)
            };

            if (pos.isUpsideDown)
                container.RenderTransform = new RotateTransform(180);

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
        // Canvas: 86×138, center (43,69), container 36×36 (half=18).
        // ALL ranks: outer ±44 → consistent top pip height, 7px from canvas edge.
        // 36px container with 26pt font gives 5px margin on each side of the glyph,
        // so ascender overflow (e.g. ♥ at top) and inverted tips both have clearance.
        // Ranks 8/10: inner ±15 → ~29px row spacing (near-uniform across 4 rows).
        // Rank 9:     inner ±22 → exactly 22px row spacing across all 5 rows.
        // Rank 10:    center extras ±30 → midpoint of outer/inner rows.
        return rank switch
        {
            2 => new()
            {
                new(0, -44, false),
                new(0,  44, true)
            },
            3 => new()
            {
                new(0, -44, false),
                new(0,   0, false),
                new(0,  44, true)
            },
            4 => new()
            {
                new(-26, -44, false),
                new( 26, -44, false),
                new(-26,  44, true),
                new( 26,  44, true)
            },
            5 => new()
            {
                new(-26, -44, false),
                new( 26, -44, false),
                new(  0,   0, false),
                new(-26,  44, true),
                new( 26,  44, true)
            },
            6 => new()
            {
                new(-26, -44, false),
                new( 26, -44, false),
                new(-26,   0, false),
                new( 26,   0, false),
                new(-26,  44, true),
                new( 26,  44, true)
            },
            7 => new()
            {
                new(-26, -44, false),
                new( 26, -44, false),
                new(-26,   0, false),
                new( 26,   0, false),
                new(-26,  44, true),
                new( 26,  44, true),
                new(  0, -22, false)   // extra pip between top row and middle
            },
            8 => new()
            {
                new(-26, -44, false),
                new( 26, -44, false),
                new(-26, -15, false),
                new( 26, -15, false),
                new(-26,  15, true),
                new( 26,  15, true),
                new(-26,  44, true),
                new( 26,  44, true)
            },
            9 => new()
            {
                new(-26, -44, false),
                new( 26, -44, false),
                new(-26, -15, false),
                new( 26, -15, false),
                new(  0,   0, false),
                new(-26,  15, true),
                new( 26,  15, true),
                new(-26,  44, true),
                new( 26,  44, true)
            },
            10 => new()
            {
                new(-26, -44, false),
                new( 26, -44, false),
                new(-26, -15, false),
                new( 26, -15, false),
                new(  0, -30, false),
                new(  0,  30, true),
                new(-26,  15, true),
                new( 26,  15, true),
                new(-26,  44, true),
                new( 26,  44, true)
            },
            _ => new()
        };
    }

    private void ApplyCardBackTheme()
    {
        var options = _cachedOptions ?? SettingsService.LoadOptions();
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
        else if (_houliAssets.TryGetValue(theme, out var houliFile))
        {
            filename   = houliFile;
            isDingwall = true; // fill the card boundary, same as Dingwall
        }
        else
        {
            var customBack = options.CustomCardBacks.Find(c => c.Name == theme);
            if (customBack != null && PathSafety.IsSafeFileName(customBack.FileName))
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
                if (customPath.EndsWith(".gif", StringComparison.OrdinalIgnoreCase))
                {
                    var (frames, durations) = GetCachedGifFrames(customPath);
                    if (frames.Length > 0)
                    {
                        CardBackImage.Source = frames[0];
                        if (_isAnimated && frames.Length > 1)
                            StartGifAnimation(frames, durations);
                        else
                            StopGifAnimation();
                    }
                }
                else
                {
                    StopGifAnimation();
                    CardBackImage.Source = GetCachedCustomBitmap(customPath, scale, offsetX, offsetY);
                }
            }
            else
            {
                StopGifAnimation();
                string resourceUri = $"avares://Honeycomb/Assets/{filename}";
                CardBackImage.Source = GetCachedBitmap(resourceUri);
            }
        }
        catch
        {
            StopGifAnimation();
        }

        if (isDingwall || (isCustom && customPath != null && !customPath.EndsWith(".gif", StringComparison.OrdinalIgnoreCase)))
        {
            CardBackImage.Width = 128;
            CardBackImage.Height = 181;
            CardBackImage.Stretch = Stretch.Fill;
            CardBackImage.RenderTransform = null;
        }
        else
        {
            // For Moogle/Vulpera and GIFs
            CardBackImage.Width  = isCustom ? 128 : 120;
            CardBackImage.Height = isCustom ? 181 : 173;
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

    private static Bitmap GetCachedBitmapNoBackground(string resourceUri, int tolerance = 25)
    {
        string cacheKey = resourceUri + "__nobg";
        if (_bitmapCache.TryGetValue(cacheKey, out var cached)) return cached;
        try
        {
            using var stream = AssetLoader.Open(new Uri(resourceUri));
            using var codec = SKCodec.Create(stream);
            if (codec == null) return GetCachedBitmap(resourceUri);

            var info = new SKImageInfo(codec.Info.Width, codec.Info.Height, SKColorType.Bgra8888, SKAlphaType.Unpremul);
            using var bmp = new SKBitmap(info);
            codec.GetPixels(info, bmp.GetPixels());

            int w = bmp.Width, h = bmp.Height;
            byte[] bytes = bmp.Bytes;

            // Sample background from top-left corner (BGRA order)
            byte bgB = bytes[0], bgG = bytes[1], bgR = bytes[2];

            // BFS flood fill from all 4 corners to identify background pixels
            var visited = new bool[w * h];
            var queue = new Queue<int>();

            bool IsBg(int idx)
            {
                int o = idx * 4;
                return Math.Abs(bytes[o]     - bgB) <= tolerance &&
                       Math.Abs(bytes[o + 1] - bgG) <= tolerance &&
                       Math.Abs(bytes[o + 2] - bgR) <= tolerance;
            }

            void Enqueue(int x, int y)
            {
                if (x < 0 || x >= w || y < 0 || y >= h) return;
                int i = y * w + x;
                if (!visited[i] && IsBg(i)) { visited[i] = true; queue.Enqueue(i); }
            }

            Enqueue(0, 0); Enqueue(w - 1, 0); Enqueue(0, h - 1); Enqueue(w - 1, h - 1);
            while (queue.Count > 0)
            {
                int i = queue.Dequeue();
                int x = i % w, y = i / w;
                Enqueue(x + 1, y); Enqueue(x - 1, y); Enqueue(x, y + 1); Enqueue(x, y - 1);
            }

            // Erase background pixels and find tight bounding box of remaining content
            int minX = w, maxX = 0, minY = h, maxY = 0;
            for (int i = 0; i < w * h; i++)
            {
                if (visited[i])
                {
                    int o = i * 4;
                    bytes[o] = bytes[o+1] = bytes[o+2] = bytes[o+3] = 0;
                }
                else
                {
                    int x = i % w, y = i / w;
                    if (x < minX) minX = x;
                    if (x > maxX) maxX = x;
                    if (y < minY) minY = y;
                    if (y > maxY) maxY = y;
                }
            }

            // Crop to the tight bounding box so the character fills the image slot
            if (minX > maxX || minY > maxY) return GetCachedBitmap(resourceUri);
            int cropW = maxX - minX + 1, cropH = maxY - minY + 1;
            var cropped = new byte[cropW * cropH * 4];
            for (int row = 0; row < cropH; row++)
                Array.Copy(bytes, ((minY + row) * w + minX) * 4, cropped, row * cropW * 4, cropW * 4);

            var wb = new WriteableBitmap(
                new PixelSize(cropW, cropH), new Vector(96, 96),
                PixelFormat.Bgra8888, AlphaFormat.Unpremul);
            using (var fb = wb.Lock())
                Marshal.Copy(cropped, 0, fb.Address, cropped.Length);

            _bitmapCache[cacheKey] = wb;
            return wb;
        }
        catch { return GetCachedBitmap(resourceUri); }
    }

    // Removes near-transparent noise pixels and auto-crops to the tight content bounding box.
    // Use for images that already have transparency but have anti-aliasing/noise at the edges.
    private static Bitmap GetCachedBitmapTrimmed(string resourceUri, byte alphaThreshold = 40)
    {
        string cacheKey = resourceUri + "__trimmed";
        if (_bitmapCache.TryGetValue(cacheKey, out var cached)) return cached;
        try
        {
            using var stream = AssetLoader.Open(new Uri(resourceUri));
            using var codec = SKCodec.Create(stream);
            if (codec == null) return GetCachedBitmap(resourceUri);

            var info = new SKImageInfo(codec.Info.Width, codec.Info.Height, SKColorType.Bgra8888, SKAlphaType.Unpremul);
            using var bmp = new SKBitmap(info);
            codec.GetPixels(info, bmp.GetPixels());

            int w = bmp.Width, h = bmp.Height;
            byte[] bytes = bmp.Bytes;

            // Zero noise pixels (alpha below threshold) and track content bounding box
            int minX = w, maxX = 0, minY = h, maxY = 0;
            for (int i = 0; i < w * h; i++)
            {
                int o = i * 4;
                if (bytes[o + 3] <= alphaThreshold)
                {
                    bytes[o] = bytes[o+1] = bytes[o+2] = bytes[o+3] = 0;
                }
                else
                {
                    int x = i % w, y = i / w;
                    if (x < minX) minX = x;
                    if (x > maxX) maxX = x;
                    if (y < minY) minY = y;
                    if (y > maxY) maxY = y;
                }
            }

            if (minX > maxX || minY > maxY) return GetCachedBitmap(resourceUri);
            int cropW = maxX - minX + 1, cropH = maxY - minY + 1;
            var cropped = new byte[cropW * cropH * 4];
            for (int row = 0; row < cropH; row++)
                Array.Copy(bytes, ((minY + row) * w + minX) * 4, cropped, row * cropW * 4, cropW * 4);

            var wb = new WriteableBitmap(
                new PixelSize(cropW, cropH), new Vector(96, 96),
                PixelFormat.Bgra8888, AlphaFormat.Unpremul);
            using (var fb = wb.Lock())
                Marshal.Copy(cropped, 0, fb.Address, cropped.Length);

            _bitmapCache[cacheKey] = wb;
            return wb;
        }
        catch { return GetCachedBitmap(resourceUri); }
    }

    private static (Bitmap[] Frames, int[] Durations) GetCachedGifFrames(string filePath)
    {
        if (_gifFrameCache.TryGetValue(filePath, out var cached)) return cached;

        try
        {
            using var codec = SKCodec.Create(filePath);
            if (codec == null) return (Array.Empty<Bitmap>(), Array.Empty<int>());

            var frameInfos = codec.FrameInfo;
            int frameCount = frameInfos.Length > 0 ? frameInfos.Length : 1;
            var info = new SKImageInfo(codec.Info.Width, codec.Info.Height, SKColorType.Bgra8888, SKAlphaType.Premul);

            var frames = new List<Bitmap>(frameCount);
            var durations = new List<int>(frameCount);

            for (int i = 0; i < frameCount; i++)
            {
                durations.Add(frameInfos.Length > i ? Math.Max(50, frameInfos[i].Duration) : 100);

                using var skBitmap = new SKBitmap(info);
                var opts = new SKCodecOptions(i);
                var result = codec.GetPixels(info, skBitmap.GetPixels(), opts);
                if (result != SKCodecResult.Success && result != SKCodecResult.IncompleteInput) continue;

                var wb = new WriteableBitmap(
                    new PixelSize(info.Width, info.Height),
                    new Vector(96, 96),
                    PixelFormat.Bgra8888,
                    AlphaFormat.Premul);
                using (var fb = wb.Lock())
                    Marshal.Copy(skBitmap.Bytes, 0, fb.Address, skBitmap.ByteCount);
                frames.Add(wb);
            }

            var result2 = (frames.ToArray(), durations.ToArray());
            _gifFrameCache[filePath] = result2;
            return result2;
        }
        catch
        {
            return (Array.Empty<Bitmap>(), Array.Empty<int>());
        }
    }

    private void StartGifAnimation(Bitmap[] frames, int[] durations)
    {
        StopGifAnimation();
        _sharedGifFrames = frames;
        _sharedGifDurations = durations;
        _sharedGifFrameIndex = 0;

        _gifListeners.Add(this);
        _isGifListener = true;

        if (_sharedGifTimer == null)
        {
            _sharedGifTimer = new DispatcherTimer(DispatcherPriority.Render);
            _sharedGifTimer.Tick += SharedGifTick;
        }
        _sharedGifTimer.Interval = TimeSpan.FromMilliseconds(durations.Length > 0 ? durations[0] : 100);
        _sharedGifTimer.Start();
    }

    private static void SharedGifTick(object? sender, EventArgs e)
    {
        if (_sharedGifFrames == null || _sharedGifFrames.Length == 0) return;
        _sharedGifFrameIndex = (_sharedGifFrameIndex + 1) % _sharedGifFrames.Length;
        if (_sharedGifTimer != null && _sharedGifDurations.Length > _sharedGifFrameIndex)
            _sharedGifTimer.Interval = TimeSpan.FromMilliseconds(_sharedGifDurations[_sharedGifFrameIndex]);
        var frame = _sharedGifFrames[_sharedGifFrameIndex];
        for (int i = 0; i < _gifListeners.Count; i++)
            _gifListeners[i].CardBackImage.Source = frame;
    }

    private void StopGifAnimation()
    {
        if (!_isGifListener) return;
        _gifListeners.Remove(this);
        _isGifListener = false;
        if (_gifListeners.Count == 0)
        {
            _sharedGifTimer?.Stop();
            _sharedGifFrames = null;
            _sharedGifFrameIndex = 0;
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
        if (SelectionHighlightBorder != null) SelectionHighlightBorder.IsVisible = true;
    }

    public void ShowCursor()
    {
        if (CursorHighlightBorder != null) CursorHighlightBorder.IsVisible = true;
    }

    public void ClearCursor()
    {
        if (CursorHighlightBorder != null) CursorHighlightBorder.IsVisible = false;
    }

    public void ShowHint()
    {
        if (CardFace == null || Card == null || !Card.IsFaceUp) return;
        _hintPulseBrush = new SolidColorBrush(Color.Parse("#FFD700"));
        CardFace.BorderBrush     = _hintPulseBrush;
        CardFace.BorderThickness = new Thickness(3.5);
        _hintPulse.Start(alpha =>
        {
            byte a = (byte)(160 + (int)(95 * alpha));
            _hintPulseBrush!.Color = Color.FromArgb(a, 0xFF, 0xD7, 0x00);
            CardFace.BoxShadow = new BoxShadows(new BoxShadow
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
        if (CardFace == null || Card == null || !Card.IsFaceUp) return;
        CardFace.BorderBrush     = _brushFaceBorderNormal;
        CardFace.BorderThickness = new Thickness(0.75);
        CardFace.BoxShadow       = new BoxShadows(new BoxShadow { OffsetX = 0, OffsetY = 1.5, Blur = 1.5, Spread = 0, Color = _normalShadowColor });
    }

    public void ClearSelection()
    {
        if (SelectionHighlightBorder != null) SelectionHighlightBorder.IsVisible = false;
    }

    // Point Highlights: purely a dumb visual setter — timing (the ~1s auto-clear) is
    // owned entirely by the ViewModel's own generation-guarded timer, which the caller
    // (CardGameView.ApplyPointPopup) reacts to by calling ShowPointPopup/HidePointPopup
    // here in response. No independent timer on this side to avoid it drifting from that
    // one, or racing a second popup landing on the same card before the first clears.
    public void ShowPointPopup(string text)
    {
        if (PointPopupRoot == null || PointPopupText == null || PointPopupTextGlow == null) return;
        // Avalonia's field codegen doesn't expose x:Name'd non-Control objects nested
        // this deep in property-element syntax (RenderTransform/Effect) as fields, so
        // these are found by casting instead.
        if (PointPopupRoot.RenderTransform is not ScaleTransform scale) return;
        if (PointPopupText.Effect is not DropShadowEffect colorGlow) return;

        // Same suit-color source UpdateCardFace uses for rank/suit text — automatically
        // respects any custom card-color theme without duplicating that logic.
        bool isRed = Card != null && (Card.Suit == CardSuit.Hearts || Card.Suit == CardSuit.Diamonds);
        var brush = isRed ? _brushTextRed : _brushTextBlackNormal;

        PointPopupText.Text = text;
        PointPopupTextGlow.Text = text;
        PointPopupText.Foreground = brush;
        colorGlow.Color = brush.Color;

        PointPopupRoot.Opacity = 1;
        scale.ScaleX = 1;
        scale.ScaleY = 1;
    }

    public void HidePointPopup()
    {
        if (PointPopupRoot == null) return;
        PointPopupRoot.Opacity = 0;
        if (PointPopupRoot.RenderTransform is ScaleTransform scale)
        {
            scale.ScaleX = 0.6;
            scale.ScaleY = 0.6;
        }
    }

    private static List<Card> GetCardsFromCard(Card fromCard, Pile pile)
    {
        int idx = pile.Cards.IndexOf(fromCard);
        return idx < 0 ? new List<Card> { fromCard } : pile.Cards.GetRange(idx, pile.Cards.Count - idx);
    }

    private CardGameView? FindParentGameView() => CardGameView.FindAncestorGameView(this.Parent);

    private void CardView_PointerPressed(object sender, PointerPressedEventArgs e)
    {
        if (Card == null || !Card.IsFaceUp) return;

        var gameView = FindParentGameView();
        if (gameView == null) return;

        // Any direct mouse interaction relinquishes the keyboard focus cursor — the two
        // input modes never fight over the same state (pending selection is untouched;
        // this only clears the arrow-key focus indicator).
        gameView.RelinquishKeyboardCursor();

        PileView? pileView = null;
        Avalonia.StyledElement? parent = this.Parent;
        while (parent != null)
        {
            if (parent is PileView pv) { pileView = pv; break; }
            parent = parent.Parent;
        }
        if (pileView == null || pileView.Pile == null) return;

        // Waste only ever plays its single actual top card — in Draw-3 mode the two
        // older cards behind it are shown fanned out for visibility only. Without this,
        // clicking one of those buried cards would drag it (and everything after it in
        // the pile) along as a group, which Waste never allows.
        if (pileView.Pile.Type == PileType.Waste && Card.Id != pileView.Pile.Cards[^1].Id)
            return;

        // Manual double-click detection keyed by card identity, not CardView instance —
        // PointerReleased rebuilds the source pile's CardView children, so the second
        // click usually lands on a brand-new instance, making e.ClickCount unreliable.
        var clickNow = DateTime.UtcNow;
        var clickPos = e.GetPosition(this);
        double ddx = clickPos.X - _lastCardClickPos.X;
        double ddy = clickPos.Y - _lastCardClickPos.Y;
        bool isDoubleClick = _lastCardClickId == Card.Id
                              && (clickNow - _lastCardClickTime) < TimeSpan.FromMilliseconds(500)
                              && (ddx * ddx + ddy * ddy) < 400;

        if (isDoubleClick)
        {
            _lastCardClickId   = null;
            _lastCardClickTime = DateTime.MinValue;

            // A double-click is its own independent quick-move action — drop any
            // pending keyboard selection unconditionally (not only on success), so it
            // can't linger and confuse a later keyboard/mouse action.
            if (gameView.SelectedCardView != null)
            {
                gameView.SelectedCardView.ClearSelection();
                gameView.SelectedCardView = null;
                gameView.SelectedSourcePile = null;
            }

            var sourcePile = pileView.Pile;
            if (gameView.TryHandleDoubleClick(Card, sourcePile))
            {
                e.Pointer.Capture(null);
                _isDragging = false;
                ResetDraggedStack(gameView);
                e.Handled = true;
            }
            return;
        }

        _lastCardClickId   = Card.Id;
        _lastCardClickTime = clickNow;
        _lastCardClickPos  = clickPos;

        {
            // Capture the source pile NOW, before drag setup detaches this card from its canvas
            var thisPile = pileView.Pile;

            // Single-click / Start Drag
            var dragCanvas = gameView.FindControl<Canvas>("DragCanvas");
            if (dragCanvas != null)
            {
                gameView.SizeDragCanvasToWindow(dragCanvas);
                _isDragging = true;
                _dragCanvas = dragCanvas;
                _dragStartPoint = e.GetPosition(dragCanvas);
                _sourcePileView = pileView;

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
                            if (foundThis) _draggedStack.Add(cv);
                        }
                    }
                }

                foreach (var cv in _draggedStack)
                {
                    var pos = cv.TranslatePoint(new Point(0, 0), dragCanvas);
                    _dragStartPositions[cv] = pos ?? new Point(0, 0);
                }

                foreach (var cv in _draggedStack)
                {
                    (cv.Parent as Canvas)?.Children.Remove(cv);
                    dragCanvas.Children.Add(cv);
                    Canvas.SetLeft(cv, _dragStartPositions[cv].X);
                    Canvas.SetTop(cv, _dragStartPositions[cv].Y);
                }

                e.Pointer.Capture(this);
            }

            // Click-to-select / click-to-move. Deliberately no Highlight() here — the
            // blue selection border is reserved for keyboard-driven selection
            // (CardGameView.ActivateCursor); a mouse click still tracks SelectedCardView/
            // SelectedSourcePile for the click-again-to-move logic below, it just isn't
            // drawn, since the click itself is already the player's visual feedback.
            if (gameView.SelectedCardView == null)
            {
                gameView.SelectedCardView = this;
                gameView.SelectedSourcePile = thisPile;
            }
            else
            {
                var selectedCard = gameView.SelectedCardView.Card;
                // Use SelectedSourcePile (captured at selection time) not ParentPile,
                // because after PointerReleased the old CardView is orphaned.
                var sourcePile = gameView.SelectedSourcePile;
                if (selectedCard != null && sourcePile != null && pileView.Pile != sourcePile)
                {
                    var cardsToMove = GetCardsFromCard(selectedCard, sourcePile);
                    if (gameView.CanMoveCards(cardsToMove, pileView.Pile))
                    {
                        gameView.TryMoveCards(cardsToMove, sourcePile, pileView.Pile);
                        gameView.SelectedCardView.ClearSelection();
                        gameView.SelectedCardView = null;
                        gameView.SelectedSourcePile = null;
                        e.Pointer.Capture(null);
                        _isDragging = false;
                        ResetDraggedStack(gameView);
                    }
                    else
                    {
                        gameView.SelectedCardView.ClearSelection();
                        gameView.SelectedCardView = this;
                        gameView.SelectedSourcePile = thisPile;
                    }
                }
                else
                {
                    var previousSelection = gameView.SelectedCardView;
                    previousSelection.ClearSelection();
                    if (previousSelection != this)
                    {
                        gameView.SelectedCardView = this;
                        gameView.SelectedSourcePile = thisPile;
                    }
                    else
                    {
                        gameView.SelectedCardView = null;
                        gameView.SelectedSourcePile = null;
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
        if (!_isDragging || Card == null || _dragCanvas == null) return;

        var gameView = FindParentGameView();
        if (gameView == null) return;

        var currentPoint = e.GetPosition(_dragCanvas);
        double dx = currentPoint.X - _dragStartPoint.X;
        double dy = currentPoint.Y - _dragStartPoint.Y;

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

        var gameView = FindParentGameView();
        if (gameView == null)
        {
            ResetDraggedStack(null);
            return;
        }

        var dropPoint = e.GetPosition(gameView);
        var targetPileView = FindTargetPileView(gameView, dropPoint);

        bool moved = false;
        if (targetPileView != null && targetPileView != _sourcePileView && targetPileView.Pile != null && _sourcePileView?.Pile != null)
        {
            var cardsToMove = GetCardsFromCard(Card!, _sourcePileView.Pile);
            moved = gameView.TryMoveCards(cardsToMove, _sourcePileView.Pile, targetPileView.Pile);

            // Smart Drop: the exact card the player grabbed usually isn't a whole-stack
            // miss but a slightly-too-high click on a tightly packed column — they meant
            // to grab the valid run just below it. Rather than reject the drop outright,
            // peel leading cards off the grabbed stack one at a time and retry; the first
            // (largest) remaining tail that's a legal move wins, and whatever was peeled
            // off stays behind in the source pile — ResetDraggedStack below re-lays it out
            // there exactly as if it had never left, same as any other rejected drag.
            if (!moved)
            {
                for (int skip = 1; skip < cardsToMove.Count; skip++)
                {
                    var subStack = cardsToMove.GetRange(skip, cardsToMove.Count - skip);
                    if (gameView.TryMoveCards(subStack, _sourcePileView.Pile, targetPileView.Pile))
                    {
                        moved = true;
                        break;
                    }
                }
            }

            if (moved && gameView.SelectedCardView != null)
            {
                gameView.SelectedCardView.ClearSelection();
                gameView.SelectedCardView = null;
                gameView.SelectedSourcePile = null;
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
                gameView.SelectedSourcePile = null;
            }
        }

        e.Handled = true;
    }

    private void ResetDraggedStack(CardGameView? gameView)
    {
        if (gameView != null)
        {
            var dragCanvas = gameView.FindControl<Canvas>("DragCanvas");
            if (dragCanvas != null)
            {
                foreach (var cv in _draggedStack)
                    dragCanvas.Children.Remove(cv);
            }
        }

        _sourcePileView?.UpdateCardsLayout();
        _draggedStack.Clear();
        _dragStartPositions.Clear();
        _sourcePileView = null;
        _dragCanvas = null;
    }

    // MainWindow constructs a brand-new GameView/FreecellView/SpiderView on every
    // game switch (deck-count/draw-mode/suit-count change included), so without this
    // the cache below would keep a strong reference to every discarded CardGameView
    // (plus its full pile list) forever. Call from each view's Unloaded handler.
    public static void ClearPileViewCache(CardGameView gameView) => _pileViewListCache.Remove(gameView);

    private PileView? FindTargetPileView(CardGameView gameView, Point dropPoint)
    {
        // TranslatePoint/Bounds below reflect the last completed layout pass, not
        // necessarily the pile positions as of right now — if a Tableaus/FreeCells/
        // Foundations change (a deck-count switch's fresh deal, an Undo, or even the
        // move that's currently in flight) queued an invalidation that Avalonia hasn't
        // processed yet, TranslatePoint can return null or stale bounds for every pile,
        // making every drop look like "no target found" (the dragged card silently
        // reverts to its source). Force any pending layout to complete first so the hit
        // test below is always against current positions.
        gameView.UpdateLayout();

        if (!_pileViewListCache.TryGetValue(gameView, out var piles))
        {
            piles = new List<PileView>();
            FindPileViewsRecursive(gameView, piles);
            _pileViewListCache[gameView] = piles;
        }

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
