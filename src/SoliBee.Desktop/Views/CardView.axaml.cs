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
    private bool _isDragging;
    private Point _dragStartPoint;
    private List<CardView> _draggedStack = new();
    private PileView? _sourcePileView;
    private Dictionary<CardView, Point> _dragStartPositions = new();
    private Canvas? _dragCanvas;

    private int _lastPipRank = -1;
    private string _lastPipSuit = "";
    private uint _lastPipArgb;

    private static readonly Dictionary<string, Bitmap> _bitmapCache = new();
    private static readonly Dictionary<string, Bitmap> _customBitmapCache = new();
    private static readonly Dictionary<string, (Bitmap[] Frames, int[] Durations)> _gifFrameCache = new();

    private static GameOptions? _cachedOptions;

    private CardGameView? _cachedParentGameView;
    private bool _parentGameViewSearched;
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

    // FF mode default face art — empty; assets removed, falls back to LargeAceText rank display.
    private static readonly Dictionary<FaceCardSlot, (string Uri, double Scale)> _ffDefaultArt = new();

    // Pre-allocated brushes — only ~5 combinations exist, no need to allocate per render
    // internal so ThemeEditorWindow can mutate .Color for live debug preview
    internal static readonly SolidColorBrush _brushFaceBackNormal   = new(Colors.White);
    internal static readonly SolidColorBrush _brushFaceBackFF       = new(Color.Parse("#333333"));
    internal static readonly SolidColorBrush _brushFaceBorderNormal = new(Color.Parse("#D9000000"));
    internal static readonly SolidColorBrush _brushFaceBorderFF     = new(Color.Parse("#00000000"));
    internal static readonly SolidColorBrush _brushFaceBorderFFCard = new(Colors.White);
    internal static readonly SolidColorBrush _brushTextRed          = new(Color.Parse("#CC1A1A"));
    internal static readonly SolidColorBrush _brushTextRedFF        = new(Color.Parse("#FF4444"));
    internal static readonly SolidColorBrush _brushTextBlackNormal  = new(Color.Parse("#1A1A1A"));
    internal static readonly SolidColorBrush _brushTextBlackFF      = new(Color.Parse("#C0C0C0"));
    internal static Color _ffShadowColor = Color.Parse("#B3FFD700");
    internal static Color _normalShadowColor = Color.Parse("#26000000");

    // 2× render size: card backs render at 120×173, face art at 70×60
    private const int CardBackCacheW = 240;
    private const int CardBackCacheH = 346;
    private const int FaceArtCacheW  = 140;
    private const int FaceArtCacheH  = 120;

    public static void ApplyThemeColors(SoliBee.Core.Models.GameOptions options)
    {
        _cachedOptions = options;
        _pipBitmapCache.Clear();
        _aceBitmapCache.Clear();
        _brushFaceBackNormal.Color  = options.ThemeFaceBackNormal  != null ? Color.Parse(options.ThemeFaceBackNormal)  : Colors.White;
        _brushFaceBackFF.Color       = options.ThemeFaceBackFF       != null ? Color.Parse(options.ThemeFaceBackFF)       : Color.Parse("#333333");
        _brushFaceBorderNormal.Color = options.ThemeFaceBorderNormal != null ? Color.Parse(options.ThemeFaceBorderNormal) : Color.Parse("#D9000000");
        _brushFaceBorderFF.Color     = options.ThemeFaceBorderFF     != null ? Color.Parse(options.ThemeFaceBorderFF)     : Color.Parse("#00000000");
        _brushFaceBorderFFCard.Color = options.ThemeFaceBorderFFCard != null ? Color.Parse(options.ThemeFaceBorderFFCard) : Colors.White;
        _brushTextRed.Color          = options.ThemeTextRed          != null ? Color.Parse(options.ThemeTextRed)          : Color.Parse("#CC1A1A");
        _brushTextRedFF.Color        = options.ThemeTextRedFF        != null ? Color.Parse(options.ThemeTextRedFF)        : Color.Parse("#FF4444");
        _brushTextBlackNormal.Color  = options.ThemeTextBlackNormal  != null ? Color.Parse(options.ThemeTextBlackNormal)  : Color.Parse("#1A1A1A");
        _brushTextBlackFF.Color      = options.ThemeTextBlackFF      != null ? Color.Parse(options.ThemeTextBlackFF)      : Color.Parse("#C0C0C0");
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

    public static void InvalidateFaceArtCache(string? filePath = null)
    {
        if (filePath != null)
        {
            if (_customBitmapCache.TryGetValue(filePath, out var bmp))
            {
                _customBitmapCache.Remove(filePath);
                bmp.Dispose();
            }
        }
        else
        {
            foreach (var bmp in _customBitmapCache.Values) bmp.Dispose();
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

    private DispatcherTimer? _hintPulseTimer;
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
    private static Bitmap GetCachedCustomBitmap(string filePath)
    {
        if (!_customBitmapCache.TryGetValue(filePath, out var bitmap))
        {
            bitmap = ScaleToDisplay(filePath, CardBackCacheW, CardBackCacheH);
            _customBitmapCache[filePath] = bitmap;
        }
        return bitmap;
    }

    // Face card art — cached at 2× render resolution, first-frame for GIFs
    internal static Bitmap GetCachedFaceArtBitmap(string filePath)
    {
        if (_customBitmapCache.TryGetValue(filePath, out var cached)) return cached;
        var bitmap = LoadAndScaleFaceArt(filePath);
        _customBitmapCache[filePath] = bitmap;
        return bitmap;
    }

    // Handles GIF first-frame extraction + downscale to face-art display size
    private static Bitmap LoadAndScaleFaceArt(string filePath)
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
                    return ScaleToDisplay(skBmp, FaceArtCacheW, FaceArtCacheH);
                }
            }
            catch { }
            return new Bitmap(filePath);
        }
        return ScaleToDisplay(filePath, FaceArtCacheW, FaceArtCacheH);
    }

    // Downscale a file to maxW×maxH (preserving aspect ratio) with high-quality filtering.
    // If the image already fits within the target, it is returned at its original size.
    // Falls back to a plain Bitmap load on any failure.
    private static Bitmap ScaleToDisplay(string filePath, int maxW, int maxH)
    {
        try
        {
            using var skBmp = SKBitmap.Decode(filePath);
            if (skBmp == null) return new Bitmap(filePath);
            return ScaleToDisplay(skBmp, maxW, maxH);
        }
        catch { return new Bitmap(filePath); }
    }

    private static Bitmap ScaleToDisplay(SKBitmap src, int maxW, int maxH)
    {
        float scaleX = (float)maxW / src.Width;
        float scaleY = (float)maxH / src.Height;
        float scale  = Math.Min(scaleX, scaleY);

        SKBitmap work;
        if (scale < 1.0f)
        {
            int w = Math.Max(1, (int)(src.Width  * scale));
            int h = Math.Max(1, (int)(src.Height * scale));
            work = src.Resize(new SKImageInfo(w, h, SKColorType.Bgra8888, SKAlphaType.Premul),
                              SKFilterQuality.High);
        }
        else
        {
            work = src.Copy(SKColorType.Bgra8888);
        }

        try
        {
            var wb = new WriteableBitmap(
                new PixelSize(work.Width, work.Height),
                new Vector(96, 96),
                PixelFormat.Bgra8888, AlphaFormat.Premul);
            using (var fb = wb.Lock())
                Marshal.Copy(work.Bytes, 0, fb.Address, work.ByteCount);
            return wb;
        }
        finally { work.Dispose(); }
    }

    // ── Background preloaders ─────────────────────────────────────────────────

    // Warm the face-art cache for every stored art entry.
    // Already-cached paths are skipped. Safe to call repeatedly.
    public static void PreloadFaceArt()
    {
        foreach (var art in FaceCardArtService.GetAllArts())
        {
            var path = FaceCardArtService.GetFullPath(art);
            if (_customBitmapCache.ContainsKey(path) || !File.Exists(path)) continue;

            var capturedPath = path;
            Task.Run(() =>
            {
                try
                {
                    var bmp = LoadAndScaleFaceArt(capturedPath);
                    Dispatcher.UIThread.InvokeAsync(() =>
                    {
                        if (!_customBitmapCache.ContainsKey(capturedPath))
                            _customBitmapCache[capturedPath] = bmp;
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
            if (_customBitmapCache.ContainsKey(path) || !File.Exists(path)) continue;

            var capturedPath = path;
            Task.Run(() =>
            {
                try
                {
                    var bmp = ScaleToDisplay(capturedPath, CardBackCacheW, CardBackCacheH);
                    Dispatcher.UIThread.InvokeAsync(() =>
                    {
                        if (!_customBitmapCache.ContainsKey(capturedPath))
                            _customBitmapCache[capturedPath] = bmp;
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
            _hintPulseTimer?.Stop();
            _hintPulseTimer = null;
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

            bool ffMode = (_cachedOptions ?? SettingsService.LoadOptions()).IsFinalFantasyMode;
            // Card face background and border adapt to FF mode
            CardFace.Background       = ffMode ? _brushFaceBackFF       : _brushFaceBackNormal;
            CardFace.BorderBrush      = ffMode ? _brushFaceBorderFFCard : _brushFaceBorderNormal;
            CardFace.BorderThickness  = new Avalonia.Thickness(ffMode ? 2.5 : 0.75);
            CardFace.BoxShadow        = ffMode
                ? new BoxShadows(new BoxShadow { OffsetX = 0, OffsetY = -5, Blur = 6, Spread = 0, Color = _ffShadowColor })
                : new BoxShadows(new BoxShadow { OffsetX = 0, OffsetY = 1.5, Blur = 1.5, Spread = 0, Color = _normalShadowColor });

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

            // Suit color: red suits keep crimson; black suits go metallic silver in FF mode
            bool isRed = Card.Suit == CardSuit.Hearts || Card.Suit == CardSuit.Diamonds;
            var brush = isRed ? (ffMode ? _brushTextRedFF : _brushTextRed) : (ffMode ? _brushTextBlackFF : _brushTextBlackNormal);
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
            // In FF mode any configured art is used as the default (enabled flag is ignored);
            // in normal mode the enabled flag still gates display.
            var faceSlot = FaceCardSlotExtensions.SlotFor(Card.Rank, Card.Suit);
            var customFaceArt = faceSlot.HasValue
                ? (ffMode ? FaceCardArtService.GetArt(faceSlot.Value) : FaceCardArtService.GetEnabledArt(faceSlot.Value))
                : null;

            if (customFaceArt != null)
            {
                FaceCardImage.IsVisible = true;
                FaceCardImage.Stretch = Avalonia.Media.Stretch.Uniform;
                FaceCardImage.Width  = 70;
                FaceCardImage.Height = 60;
                FaceCardImage.RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative);
                var tg = new TransformGroup();
                tg.Children.Add(new ScaleTransform(customFaceArt.Scale, customFaceArt.Scale));
                tg.Children.Add(new TranslateTransform(customFaceArt.OffsetX, customFaceArt.OffsetY));
                FaceCardImage.RenderTransform = tg;
                CenterGrid.ClipToBounds = true;

                try
                {
                    FaceCardImage.Source = GetCachedFaceArtBitmap(FaceCardArtService.GetFullPath(customFaceArt));
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

                // In FF mode: use bundled default art for all face/ace slots
                if (ffMode && faceSlot.HasValue && _ffDefaultArt.TryGetValue(faceSlot.Value, out var ffDefault))
                {
                    FaceCardImage.IsVisible = true;
                    FaceCardImage.Stretch = Avalonia.Media.Stretch.Uniform;
                    FaceCardImage.Width  = 70;
                    FaceCardImage.Height = 60;
                    FaceCardImage.RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative);
                    var tg = new TransformGroup();
                    tg.Children.Add(new ScaleTransform(ffDefault.Scale, ffDefault.Scale));
                    FaceCardImage.RenderTransform = tg;
                    CenterGrid.ClipToBounds = true;
                    try { FaceCardImage.Source = GetCachedBitmap(ffDefault.Uri); }
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
                else if (Card.Rank == 1)
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

            bool ffMode = (_cachedOptions ?? SettingsService.LoadOptions()).IsFinalFantasyMode;
            CardBack.Background       = ffMode ? _brushFaceBorderFF     : _brushFaceBackNormal;
            CardBack.BorderBrush      = ffMode ? _brushFaceBorderFF     : _brushFaceBorderNormal;
            CardBack.BorderThickness  = new Avalonia.Thickness(ffMode ? 4 : 0.75);

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

    private static Bitmap GetOrCreateAceBitmap(string suitChar, IBrush brush)
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
        else if (theme == "Priest")
        {
            filename = "priest.png";
            scale = options.CardBackScale;
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
                    CardBackImage.Source = GetCachedCustomBitmap(customPath);
                }
            }
            else
            {
                StopGifAnimation();
                string resourceUri = $"avares://SoliBee.Desktop/Assets/{filename}";
                CardBackImage.Source = GetCachedBitmap(resourceUri);
            }
        }
        catch
        {
            StopGifAnimation();
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
            bool ffMode = options.IsFinalFantasyMode;
            CardBackImage.Width  = 120;
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

    private PileView? _cachedParentPileView;
    private bool _parentPileViewSearched;

    public Pile? ParentPile
    {
        get
        {
            if (!_parentPileViewSearched)
            {
                var parent = this.Parent;
                while (parent != null)
                {
                    if (parent is PileView pv) { _cachedParentPileView = pv; break; }
                    parent = parent.Parent;
                }
                _parentPileViewSearched = true;
            }
            return _cachedParentPileView?.Pile;
        }
    }

    public void Highlight() { }

    public void ShowHint()
    {
        if (CardFace == null || Card == null || !Card.IsFaceUp) return;
        _hintPulseTimer?.Stop();
        _hintPulseBrush = new SolidColorBrush(Color.Parse("#FFD700"));
        CardFace.BorderBrush     = _hintPulseBrush;
        CardFace.BorderThickness = new Thickness(3);
        double phase = 0;
        _hintPulseTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _hintPulseTimer.Tick += (_, _) =>
        {
            phase += 0.08;
            byte alpha = (byte)(160 + (int)(95 * Math.Sin(phase)));
            _hintPulseBrush!.Color = Color.FromArgb(alpha, 0xFF, 0xD7, 0x00);
        };
        _hintPulseTimer.Start();
    }

    public void ClearHint()
    {
        _hintPulseTimer?.Stop();
        _hintPulseTimer = null;
        _hintPulseBrush = null;
        if (CardFace == null || Card == null || !Card.IsFaceUp) return;
        bool ffMode = (_cachedOptions ?? SettingsService.LoadOptions()).IsFinalFantasyMode;
        CardFace.BorderBrush     = ffMode ? _brushFaceBorderFFCard : _brushFaceBorderNormal;
        CardFace.BorderThickness = new Thickness(ffMode ? 2.5 : 0.75);
    }

    public void ClearSelection()
    {
        if (CardFace != null)
        {
            bool ffMode = (_cachedOptions ?? SettingsService.LoadOptions()).IsFinalFantasyMode;
            CardFace.BorderBrush     = ffMode ? _brushFaceBorderFF    : _brushFaceBorderNormal;
            CardFace.BorderThickness = new Thickness(ffMode ? 2.0 : 0.75);
        }
    }

    private static List<Card> GetCardsFromCard(Card fromCard, Pile pile)
    {
        int idx = pile.Cards.IndexOf(fromCard);
        return idx < 0 ? new List<Card> { fromCard } : pile.Cards.GetRange(idx, pile.Cards.Count - idx);
    }

    private CardGameView? FindParentGameView()
    {
        if (_parentGameViewSearched) return _cachedParentGameView;
        Avalonia.StyledElement? parent = this.Parent;
        while (parent != null)
        {
            if (parent is CardGameView cgv) { _cachedParentGameView = cgv; break; }
            parent = parent.Parent;
        }
        _parentGameViewSearched = true;
        return _cachedParentGameView;
    }

    private void CardView_PointerPressed(object sender, PointerPressedEventArgs e)
    {
        if (Card == null || !Card.IsFaceUp) return;

        var gameView = FindParentGameView();
        if (gameView == null) return;

        PileView? pileView = null;
        Avalonia.StyledElement? parent = this.Parent;
        while (parent != null)
        {
            if (parent is PileView pv) { pileView = pv; break; }
            parent = parent.Parent;
        }
        if (pileView == null || pileView.Pile == null) return;

        var clickCount = e.ClickCount;

        if (clickCount == 2)
        {
            var sourcePile = this.ParentPile;
            if (sourcePile != null && gameView.TryAutoMoveToFoundation(Card, sourcePile))
            {
                if (gameView.SelectedCardView != null)
                {
                    gameView.SelectedCardView.ClearSelection();
                    gameView.SelectedCardView = null;
                }
                e.Handled = true;
                return;
            }
        }
        else
        {
            // Capture the source pile NOW, before drag setup detaches this card from its canvas
            var thisPile = pileView.Pile;

            // Single-click / Start Drag
            var dragCanvas = gameView.FindControl<Canvas>("DragCanvas");
            if (dragCanvas != null)
            {
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

            // Click-to-select / click-to-move
            if (gameView.SelectedCardView == null)
            {
                gameView.SelectedCardView = this;
                gameView.SelectedSourcePile = thisPile;
                this.Highlight();
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
                        this.Highlight();
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
                        this.Highlight();
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
            if (gameView.TryMoveCards(cardsToMove, _sourcePileView.Pile, targetPileView.Pile))
            {
                moved = true;
                if (gameView.SelectedCardView != null)
                {
                    gameView.SelectedCardView.ClearSelection();
                    gameView.SelectedCardView = null;
                    gameView.SelectedSourcePile = null;
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

    private PileView? FindTargetPileView(CardGameView gameView, Point dropPoint)
    {
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
