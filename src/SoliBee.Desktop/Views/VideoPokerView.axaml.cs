using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Threading;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Threading;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using SoliBee.Desktop.Services;

namespace SoliBee.Desktop.Views;

public partial class VideoPokerView : UserControl
{
    private readonly CardView[]  _cardViews = null!;
    private Grid[]               _cardSlots = null!;
    private readonly Dictionary<string, Border> _payRowBorders = new();
    private TextBlock[] _payColHeaders      = null!;
    private TextBlock[] _payColHeadersRight = null!;
    private readonly List<TextBlock[]> _payValueBlocks = new();

    private static readonly Card _blankCard = new("__vp_blank__", CardSuit.Spades, 0, false);

    // Animation state
    private CancellationTokenSource? _dealAnimCts;

    // Deal / draw slide animation — track previous hand IDs to detect new cards
    private readonly string[] _prevVpHandIds = new string[]
        { "__vp_blank__", "__vp_blank__", "__vp_blank__", "__vp_blank__", "__vp_blank__" };
    private readonly DispatcherTimer?[] _dealStaggerTimers = new DispatcherTimer?[5];
    private DispatcherTimer? _creditAnimTimer;
    private int _displayedCredits = -1;

    // Banner fade state
    private Control? _activeBanner;
    private DispatcherTimer? _resultShowTimer;
    private bool _resultRevealed;
    private DispatcherTimer? _bannerDelayTimer;
    private DispatcherTimer? _bannerFadeTimer;

    // Cards fade state
    private DispatcherTimer? _cardsFadeTimer;

    // Hold lift animation
    private readonly double[] _holdLiftY = new double[5];
    private readonly DispatcherTimer?[] _holdLiftTimers = new DispatcherTimer?[5];

    // Hold wobble animation
    private readonly bool[] _prevHeldSlots = new bool[5];
    private readonly DispatcherTimer?[] _holdWobbleTimers = new DispatcherTimer?[5];

    // Pay row pulse
    private DispatcherTimer? _payRowPulseTimer;
    private double _payRowPulsePhase;
    private string? _pulsingPayRow;

    // Idle nudge
    private DispatcherTimer? _idleTimer;
    private DispatcherTimer? _idleFadeTimer;

    public VideoPokerView()
    {
        InitializeComponent();

        _cardViews = new[] { Card0View, Card1View, Card2View, Card3View, Card4View };
        _cardSlots = new[] { CardSlot0, CardSlot1, CardSlot2, CardSlot3, CardSlot4 };
        _payColHeaders      = new[] { PayColHdr1,  PayColHdr2,  PayColHdr3,  PayColHdr4,  PayColHdr5  };
        _payColHeadersRight = new[] { PayColHdrR1, PayColHdrR2, PayColHdrR3, PayColHdrR4, PayColHdrR5 };

        this.Loaded   += VideoPokerView_Loaded;
        this.Unloaded += VideoPokerView_Unloaded;
    }

    private void VideoPokerView_Loaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not VideoPokerViewModel vm) return;
        vm.PropertyChanged += Vm_PropertyChanged;

        TopLevel.GetTopLevel(this)?.AddHandler(
            InputElement.KeyDownEvent, OnKeyDown, RoutingStrategies.Tunnel);

        WeakReferenceMessenger.Default.Register<FaceCardArtChangedMessage>(this, (r, m) =>
            Dispatcher.UIThread.InvokeAsync(() => { foreach (var cv in _cardViews) cv.UpdateCardFace(); }));

        BuildPayTable(vm);
        Refresh(vm);
    }

    private void VideoPokerView_Unloaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is VideoPokerViewModel vm)
            vm.PropertyChanged -= Vm_PropertyChanged;
        TopLevel.GetTopLevel(this)?.RemoveHandler(
            InputElement.KeyDownEvent, OnKeyDown);
        WeakReferenceMessenger.Default.Unregister<FaceCardArtChangedMessage>(this);
        _resultShowTimer?.Stop(); _resultShowTimer = null;
        HideActiveBanner();
        StopCardsFade();
        StopPayRowPulse();
        _dealAnimCts?.Cancel();
        _creditAnimTimer?.Stop();
        CancelDealStaggerTimers();
        CancelHoldLiftTimers();
        CancelHoldWobbleTimers();
        _idleTimer?.Stop();     _idleTimer    = null;
        _idleFadeTimer?.Stop(); _idleFadeTimer = null;
    }

    private void Vm_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        Dispatcher.UIThread.Post(() =>
        {
            if (DataContext is not VideoPokerViewModel vm) return;
            Refresh(vm);
        });
    }

    // ── Full refresh ─────────────────────────────────────────────────────────

    private void Refresh(VideoPokerViewModel vm)
    {
        // No Stress Mode's free play has no bet to place, so the pay table (whose
        // payouts scale with bet), credits/bet readout, and betting controls all
        // disappear — only Hold/Clear/Deal remain (see UpdateControls).
        PayTableBar.IsVisible = !vm.Options.IsNoStressMode;
        BidBar.IsVisible      = !vm.Options.IsNoStressMode;
        UpdateCards(vm);
        UpdateHoldBadges(vm);
        UpdateControls(vm);
        UpdateResult(vm);
        HighlightPayRow(vm.WinningHandName);
        UpdatePayColumnHighlight(vm.State.CurrentBet);
        ApplyFeltColor(vm);
        ResetIdleTimer(vm);
    }

    private void UpdateCards(VideoPokerViewModel vm)
    {
        bool[] isNew = new bool[5];
        bool anyNew = false;

        for (int i = 0; i < 5; i++)
        {
            var card = vm.State.Hand.Count > i ? vm.State.Hand[i] : _blankCard;
            string newId = card.Id;
            isNew[i] = newId != _prevVpHandIds[i];
            _prevVpHandIds[i] = newId;
            _cardViews[i].Card    = card;
            _cardViews[i].Opacity = 1.0;
            if (isNew[i]) anyNew = true;
        }

        if (anyNew) TriggerVpDealAnimation(isNew);
    }

    private void TriggerVpDealAnimation(bool[] isNew)
    {
        CancelDealStaggerTimers();
        int stagger = 0;
        for (int i = 0; i < 5; i++)
        {
            if (!isNew[i]) continue;
            int slot    = i;
            int delayMs = stagger++ * 75;
            if (delayMs == 0)
            {
                _cardViews[slot].BeginSlideIn(0, 38, 185);
            }
            else
            {
                var t = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(delayMs) };
                _dealStaggerTimers[slot] = t;
                t.Tick += (_, _) =>
                {
                    t.Stop();
                    _dealStaggerTimers[slot] = null;
                    _cardViews[slot].BeginSlideIn(0, 38, 185);
                };
                t.Start();
            }
        }
    }

    private void CancelDealStaggerTimers()
    {
        for (int i = 0; i < 5; i++)
        {
            _dealStaggerTimers[i]?.Stop();
            _dealStaggerTimers[i] = null;
        }
    }

    private void UpdateHoldBadges(VideoPokerViewModel vm)
    {
        for (int i = 0; i < 5; i++)
        {
            bool held    = vm.IsHolding && vm.State.HeldSlots[i];
            bool wasHeld = _prevHeldSlots[i];
            AnimateCardLift(i, held ? -20 : 0);
            if (held != wasHeld) StartHoldWobble(i);
            _prevHeldSlots[i] = held;
        }
    }

    private void AnimateCardLift(int slot, double targetY)
    {
        double startY = _holdLiftY[slot];
        if (Math.Abs(startY - targetY) < 0.5)
        {
            _holdLiftY[slot] = targetY;
            if (_cardSlots[slot].RenderTransform is TranslateTransform tx0) tx0.Y = targetY;
            else _cardSlots[slot].RenderTransform = new TranslateTransform(0, targetY);
            return;
        }
        _holdLiftTimers[slot]?.Stop();
        if (_cardSlots[slot].RenderTransform is not TranslateTransform slotTx)
        {
            slotTx = new TranslateTransform(0, startY);
            _cardSlots[slot].RenderTransform = slotTx;
        }
        double elapsed = 0;
        const double durationMs = 150.0;
        _holdLiftTimers[slot] = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _holdLiftTimers[slot]!.Tick += (_, _) =>
        {
            elapsed += 16;
            double t = Math.Min(1.0, elapsed / durationMs);
            double ease = t < 0.5 ? 4 * t * t * t : 1 - Math.Pow(-2 * t + 2, 3) / 2;
            double y = startY + (targetY - startY) * ease;
            _holdLiftY[slot] = y;
            if (_cardSlots[slot].RenderTransform is TranslateTransform tx) tx.Y = y;
            if (t >= 1.0) { _holdLiftTimers[slot]!.Stop(); _holdLiftTimers[slot] = null; }
        };
        _holdLiftTimers[slot]!.Start();
    }

    private void CancelHoldLiftTimers()
    {
        for (int i = 0; i < 5; i++)
        {
            _holdLiftTimers[i]?.Stop();
            _holdLiftTimers[i] = null;
        }
    }

    private void StartHoldWobble(int slot)
    {
        _holdWobbleTimers[slot]?.Stop();
        _cardViews[slot].RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative);
        var rotTx = new RotateTransform(0);
        _cardViews[slot].RenderTransform = rotTx;
        double phase = 0;
        double amplitude = 10.0;
        _holdWobbleTimers[slot] = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _holdWobbleTimers[slot]!.Tick += (_, _) =>
        {
            phase     += 0.35;
            amplitude *= 0.90;
            rotTx.Angle = Math.Sin(phase) * amplitude;
            if (amplitude < 0.4)
            {
                _holdWobbleTimers[slot]!.Stop();
                _holdWobbleTimers[slot] = null;
                _cardViews[slot].RenderTransform = null;
            }
        };
        _holdWobbleTimers[slot]!.Start();
    }

    private void CancelHoldWobbleTimers()
    {
        for (int i = 0; i < 5; i++)
        {
            _holdWobbleTimers[i]?.Stop();
            _holdWobbleTimers[i] = null;
            _cardViews[i].RenderTransform = null;
        }
    }

    private void UpdateControls(VideoPokerViewModel vm)
    {
        AnimateCreditsTo(vm.CreditDisplay);
        BetLabel.Text          = vm.BetDisplay;
        HandsLabel.Text        = vm.Stats.TotalHands.ToString();
        RebuyButton.IsVisible  = vm.NeedsRebuy;
        BetButtonRow.IsVisible = !vm.Options.IsNoStressMode;

        var slotCursor = vm.IsHolding
            ? new Cursor(StandardCursorType.Hand)
            : new Cursor(StandardCursorType.Arrow);
        for (int i = 0; i < 5; i++)
            _cardSlots[i].Cursor = slotCursor;
    }

    private void UpdateResult(VideoPokerViewModel vm)
    {
        bool isWin   = vm.State.Phase == VideoPokerPhase.Result && vm.HasWin;
        bool isNoWin = vm.State.Phase == VideoPokerPhase.Result && vm.ShowNoWin;

        if (isWin || isNoWin)
        {
            // The banner/fade sequence already fully played for this result in a
            // previous View instance (e.g. the player switched to another game and
            // back — MainWindow recreates VideoPokerView on every switch, so none of
            // this view's own fields remember that). Jump straight to the settled
            // card-back state instead of replaying the whole reveal from scratch.
            if (vm.State.ResultBannerShown)
            {
                _resultRevealed = true;
                for (int i = 0; i < 5; i++)
                {
                    _cardViews[i].Card = _blankCard;
                    _prevVpHandIds[i]  = _blankCard.Id;
                }
                CardsRow.Opacity = 1.0;
                return;
            }

            // Already counting down to reveal (or already revealed) this same result —
            // Refresh() re-runs UpdateResult on every property change while Result phase
            // persists, so don't restart the countdown each time.
            if (_resultShowTimer != null || _resultRevealed) return;

            _resultShowTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(1500) };
            _resultShowTimer.Tick += (_, _) =>
            {
                _resultShowTimer!.Stop();
                _resultShowTimer = null;
                _resultRevealed  = true;

                if (isWin)
                {
                    WinHandNameBlock.Text  = $"{vm.State.LastHandName}!";
                    // No Stress Mode's free play still announces the winning hand, just
                    // without a credit amount attached (no credits are ever earned).
                    WinPayoutBlock.IsVisible = !vm.Options.IsNoStressMode;
                    WinPayoutBlock.Text      = $"+{vm.State.LastPayout} credits";
                    ShowBanner(WinBanner);
                    StartPayRowPulse(vm.WinningHandName);
                }
                else
                {
                    // No Stress Mode's free play never actually wagers the bet, so the
                    // "-{bet} credits" line would be misleading — hide it here too.
                    NoWinPayoutRow.IsVisible = !vm.Options.IsNoStressMode;
                    ShowBanner(NoWinOverlay);
                    StopPayRowPulse();
                }
            };
            _resultShowTimer.Start();
        }
        else
        {
            _resultShowTimer?.Stop();
            _resultShowTimer = null;
            _resultRevealed  = false;
            HideActiveBanner();
        }
    }

    // Dev-only banner preview, wired to the toolbar's local-only "Banners" dropdown
    // (the dropdown itself is only made visible in DEBUG builds — see MainWindow).
    public void DebugShowWinBanner()
    {
        _resultShowTimer?.Stop();
        _resultShowTimer = null;
        WinHandNameBlock.Text = "Royal Flush!";
        WinPayoutBlock.Text   = "+250 credits";
        ShowBanner(WinBanner);
    }

    public void DebugShowLossBanner()
    {
        _resultShowTimer?.Stop();
        _resultShowTimer = null;
        ShowBanner(NoWinOverlay);
    }

    private void ShowBanner(Control banner)
    {
        if (_activeBanner == banner)
        {
            // Already visible — restart the delay so player has a fresh 5 s
            StartBannerDelay();
            return;
        }
        HideActiveBanner();
        _activeBanner = banner;
        banner.Opacity = 1.0;
        banner.IsVisible = true;
        if (banner == WinBanner)
            WinParticleSystem.Burst(ParticleCanvas);
        StartBannerDelay();
    }

    private void StartBannerDelay()
    {
        _bannerDelayTimer?.Stop();
        _bannerDelayTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(5000) };
        _bannerDelayTimer.Tick += (_, _) =>
        {
            _bannerDelayTimer!.Stop();
            _bannerDelayTimer = null;
            StartBannerFade();
        };
        _bannerDelayTimer.Start();
    }

    private void StartBannerFade()
    {
        _bannerFadeTimer?.Stop();
        double opacity = 1.0;
        _bannerFadeTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _bannerFadeTimer.Tick += (_, _) =>
        {
            opacity -= 0.05; // ~320 ms total
            if (opacity <= 0)
            {
                _bannerFadeTimer!.Stop();
                _bannerFadeTimer = null;
                if (_activeBanner != null)
                {
                    _activeBanner.IsVisible = false;
                    _activeBanner.Opacity   = 1.0;
                    _activeBanner = null;
                }
                StartCardsFade();
                return;
            }
            if (_activeBanner != null)
                _activeBanner.Opacity = opacity;
        };
        _bannerFadeTimer.Start();
    }

    private void HideActiveBanner()
    {
        _bannerDelayTimer?.Stop();
        _bannerDelayTimer = null;
        _bannerFadeTimer?.Stop();
        _bannerFadeTimer = null;
        if (_activeBanner != null)
        {
            _activeBanner.IsVisible = false;
            _activeBanner.Opacity   = 1.0;
            _activeBanner = null;
        }
        StopPayRowPulse();
        StopCardsFade();
    }

    private void StartCardsFade()
    {
        _cardsFadeTimer?.Stop();
        double opacity = 1.0;
        _cardsFadeTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _cardsFadeTimer.Tick += (_, _) =>
        {
            opacity -= 0.025; // ~640 ms total
            if (opacity <= 0)
            {
                _cardsFadeTimer!.Stop();
                _cardsFadeTimer = null;

                // Reload the card-back placeholders (same as the initial "ready to
                // draw" screen) instead of leaving the row blank until the next deal.
                for (int i = 0; i < 5; i++)
                {
                    _cardViews[i].Card    = _blankCard;
                    _prevVpHandIds[i]     = _blankCard.Id;
                }
                CardsRow.Opacity = 1.0;

                // Mark this result as fully presented on the ViewModel (not just this
                // View instance) so switching games and back doesn't replay the banner.
                if (DataContext is VideoPokerViewModel vm) vm.State.ResultBannerShown = true;
                return;
            }
            CardsRow.Opacity = opacity;
        };
        _cardsFadeTimer.Start();
    }

    private void StopCardsFade()
    {
        _cardsFadeTimer?.Stop();
        _cardsFadeTimer = null;
        CardsRow.Opacity = 1.0;
    }

    // ── Pay table ─────────────────────────────────────────────────────────────

    private void BuildPayTable(VideoPokerViewModel vm)
    {
        PayTablePanelLeft.Children.Clear();
        PayTablePanelRight.Children.Clear();
        _payRowBorders.Clear();
        _payValueBlocks.Clear();

        var entries  = vm.CurrentTable;
        int leftCount = (entries.Length + 1) / 2;

        for (int entryIdx = 0; entryIdx < entries.Length; entryIdx++)
        {
            var entry = entries[entryIdx];
            var panel = entryIdx < leftCount ? PayTablePanelLeft : PayTablePanelRight;

            var border = new Border
            {
                Padding      = new Avalonia.Thickness(2, 2),
                CornerRadius = new Avalonia.CornerRadius(3),
                Background   = Brushes.Transparent,
            };

            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            for (int i = 0; i < 5; i++)
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(32) });

            var nameBlock = new TextBlock
            {
                Text         = entry.HandName,
                FontSize     = 12,
                Foreground   = Brushes.White,
                FontFamily   = new FontFamily("Segoe UI"),
                TextTrimming = Avalonia.Media.TextTrimming.CharacterEllipsis,
            };
            Grid.SetColumn(nameBlock, 0);
            grid.Children.Add(nameBlock);

            var rowBlocks = new TextBlock[5];
            for (int i = 0; i < 5; i++)
            {
                var valBlock = new TextBlock
                {
                    Text                = entry.Payout(i + 1).ToString(),
                    FontSize            = 12,
                    Foreground          = Brushes.White,
                    FontFamily          = new FontFamily("Segoe UI"),
                    HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
                };
                Grid.SetColumn(valBlock, i + 1);
                grid.Children.Add(valBlock);
                rowBlocks[i] = valBlock;
            }

            _payValueBlocks.Add(rowBlocks);
            border.Child = grid;
            _payRowBorders[entry.HandName] = border;
            panel.Children.Add(border);
        }
    }

    private void HighlightPayRow(string handName)
    {
        foreach (var (name, border) in _payRowBorders)
        {
            border.Background = (name == handName && !string.IsNullOrEmpty(handName))
                ? new SolidColorBrush(Color.Parse("#99FFD700"))
                : Brushes.Transparent;
        }
    }

    private void UpdatePayColumnHighlight(int currentBet)
    {
        for (int col = 0; col < 5; col++)
        {
            bool active = (col + 1) == currentBet;
            var activeFg  = new SolidColorBrush(Color.Parse("#FFD700"));
            var dimFg     = new SolidColorBrush(Color.FromArgb(0x60, 0xFF, 0xFF, 0xFF));
            _payColHeaders[col].Foreground      = active ? activeFg : dimFg;
            _payColHeadersRight[col].Foreground = active ? activeFg : dimFg;
            foreach (var row in _payValueBlocks)
                row[col].Foreground = active ? new SolidColorBrush(Color.Parse("#FFD700")) : Brushes.White;
        }
    }

    // ── Felt color ────────────────────────────────────────────────────────────

    private void ApplyFeltColor(VideoPokerViewModel vm)
    {
        // BoardFeltGrid and PayTableBar no longer paint their own background — they let
        // the shared window-level felt color + vignette (see MainWindow.ApplyFeltColor)
        // show through underneath, so the same continuous gradient spans the title bar,
        // pay table, board, and legend with no seams. BidBar keeps its own darker panel
        // for text contrast.
        if (vm.Options.IsFinalFantasyMode)
        {
            BidBar.Background = new SolidColorBrush(Color.Parse("#1A1A1A"));
            return;
        }

        string hex = vm.Options.FeltColor switch
        {
            "Crimson"   => "#8C0C26",
            "RoyalBlue" => "#1A3380",
            "Charcoal"  => "#2E2E2E",
            "Desert"    => "#C2967A",
            "Custom"    => vm.Options.CustomFeltColorHex,
            _           => "#008000",
        };
        try
        {
            var felt = Color.Parse(hex);
            // Bid bar uses a darkened shade of the felt color for text contrast
            var bar = new Color(255, (byte)(felt.R / 2), (byte)(felt.G / 2), (byte)(felt.B / 2));
            BidBar.Background = new SolidColorBrush(bar);
        }
        catch
        {
            BidBar.Background = new SolidColorBrush(Color.Parse("#004000"));
        }
    }

    // ── Deal animation ────────────────────────────────────────────────────────

    private void DoDealOrDraw(VideoPokerViewModel vm)
    {
        bool[] prevHeld = vm.State.Phase == VideoPokerPhase.Holding
            ? (bool[])vm.State.HeldSlots.Clone()
            : new bool[5];

        vm.DealOrDraw();
        Refresh(vm);
        SoundService.PlayShuffle();

        bool[] toAnimate = new bool[5];
        for (int i = 0; i < 5; i++)
            toAnimate[i] = !prevHeld[i];

        _ = StartDealAnimationAsync(toAnimate);
    }

    private async Task StartDealAnimationAsync(bool[] toAnimate)
    {
        _dealAnimCts?.Cancel();
        _dealAnimCts = new CancellationTokenSource();
        var ct = _dealAnimCts.Token;

        StopCardsFade();
        CancelHoldLiftTimers();
        CancelHoldWobbleTimers();
        for (int i = 0; i < 5; i++) _prevHeldSlots[i] = false;

        // Set new cards to starting position (above, invisible)
        for (int i = 0; i < 5; i++)
        {
            if (!toAnimate[i]) continue;
            _holdLiftY[i] = 0;
            _cardSlots[i].RenderTransform = new TranslateTransform(0, -55);
            _cardViews[i].Opacity = 0;
        }

        const int staggerMs  = 70;
        const int durationMs = 190;
        const int frameMs    = 15;
        const int steps      = durationMs / frameMs;

        var tasks = new List<Task>();
        int cardIndex = 0;
        for (int i = 0; i < 5; i++)
        {
            if (!toAnimate[i]) continue;
            int capturedI = i;
            int delay     = cardIndex * staggerMs;
            cardIndex++;

            tasks.Add(Task.Run(async () =>
            {
                try
                {
                    if (delay > 0) await Task.Delay(delay, ct);

                    for (int step = 0; step <= steps; step++)
                    {
                        if (ct.IsCancellationRequested) break;
                        double t    = step / (double)steps;
                        double ease = 1.0 - Math.Pow(1.0 - t, 3); // cubic ease-out

                        await Dispatcher.UIThread.InvokeAsync(() =>
                        {
                            if (_cardSlots[capturedI].RenderTransform is TranslateTransform tt)
                                tt.Y = -55 * (1.0 - ease);
                            _cardViews[capturedI].Opacity = ease;
                        }, DispatcherPriority.Render);

                        if (step < steps) await Task.Delay(frameMs, ct);
                    }

                    if (!ct.IsCancellationRequested)
                    {
                        await Dispatcher.UIThread.InvokeAsync(() =>
                        {
                            _cardSlots[capturedI].RenderTransform = new TranslateTransform(0, 0);
                            _cardViews[capturedI].Opacity = 1.0;
                        });
                    }
                }
                catch (OperationCanceledException) { }
            }, ct));
        }

        try { await Task.WhenAll(tasks); }
        catch (OperationCanceledException) { }
    }

    // ── Pay row pulse ─────────────────────────────────────────────────────────

    private void StartPayRowPulse(string handName)
    {
        StopPayRowPulse();
        if (string.IsNullOrEmpty(handName) || !_payRowBorders.TryGetValue(handName, out var border)) return;
        _pulsingPayRow    = handName;
        _payRowPulsePhase = 0;
        _payRowPulseTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _payRowPulseTimer.Tick += (_, _) =>
        {
            _payRowPulsePhase += 0.06;
            byte alpha = (byte)(60 + (int)(110 * (0.5 + 0.5 * Math.Sin(_payRowPulsePhase))));
            border.Background = new SolidColorBrush(Color.FromArgb(alpha, 0xFF, 0xD7, 0x00));
        };
        _payRowPulseTimer.Start();
    }

    private void StopPayRowPulse()
    {
        _payRowPulseTimer?.Stop();
        _payRowPulseTimer = null;
        if (_pulsingPayRow != null && _payRowBorders.TryGetValue(_pulsingPayRow, out var b))
            b.Background = Brushes.Transparent;
        _pulsingPayRow = null;
    }

    // ── Credit roll-up ────────────────────────────────────────────────────────

    private void AnimateCreditsTo(string newDisplay)
    {
        if (!int.TryParse(newDisplay, out int target)) { CreditsLabel.Text = newDisplay; return; }
        if (_displayedCredits < 0) { _displayedCredits = target; CreditsLabel.Text = newDisplay; return; }
        if (_displayedCredits == target) return;

        _creditAnimTimer?.Stop();
        int start   = _displayedCredits;
        int delta   = target - start;
        int totalMs = Math.Min(600, Math.Abs(delta) * 4);
        totalMs     = Math.Max(totalMs, 120);
        int elapsed = 0;

        _creditAnimTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _creditAnimTimer.Tick += (_, _) =>
        {
            elapsed += 16;
            double t    = Math.Min(1.0, elapsed / (double)totalMs);
            double ease = 1.0 - Math.Pow(1.0 - t, 2); // quadratic ease-out
            _displayedCredits = start + (int)(delta * ease);
            CreditsLabel.Text = _displayedCredits.ToString();
            if (t >= 1.0)
            {
                _displayedCredits = target;
                CreditsLabel.Text = target.ToString();
                _creditAnimTimer!.Stop();
                _creditAnimTimer = null;
            }
        };
        _creditAnimTimer.Start();
    }

    // ── Keyboard ──────────────────────────────────────────────────────────────

    private DateTime _lastDealDrawTime = DateTime.MinValue;

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (DataContext is not VideoPokerViewModel vm) return;

        switch (e.Key)
        {
            case Key.D:
            case Key.Space:
            case Key.Enter:
                if ((DateTime.UtcNow - _lastDealDrawTime).TotalMilliseconds < 400) { e.Handled = true; break; }
                _lastDealDrawTime = DateTime.UtcNow;
                DoDealOrDraw(vm); e.Handled = true; break;
            case Key.H:
                if (vm.IsHolding) { vm.HoldAll(); Refresh(vm); } e.Handled = true; break;
            case Key.Q:
                if (vm.IsHolding) { vm.ClearHolds(); Refresh(vm); } e.Handled = true; break;
            case Key.D1: case Key.NumPad1: HoldByKey(vm, 0); e.Handled = true; break;
            case Key.D2: case Key.NumPad2: HoldByKey(vm, 1); e.Handled = true; break;
            case Key.D3: case Key.NumPad3: HoldByKey(vm, 2); e.Handled = true; break;
            case Key.D4: case Key.NumPad4: HoldByKey(vm, 3); e.Handled = true; break;
            case Key.D5: case Key.NumPad5: HoldByKey(vm, 4); e.Handled = true; break;
        }
    }

    private void HoldByKey(VideoPokerViewModel vm, int index)
    {
        if (!vm.IsHolding) return;
        vm.ToggleHold(index);
        Refresh(vm);
        SoundService.PlaySnap();
    }

    // ── Event handlers ────────────────────────────────────────────────────────

    public void OnVariantChanged()
    {
        if (DataContext is not VideoPokerViewModel vm) return;
        BuildPayTable(vm);
        Refresh(vm);
    }

    private void DealFromResult()
    {
        if (DataContext is not VideoPokerViewModel vm) return;
        DoDealOrDraw(vm);
    }

    private void NoWinOverlay_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        DealFromResult();
        e.Handled = true;
    }

    private void WinBanner_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        DealFromResult();
        e.Handled = true;
    }

    private void BannerDismiss_Click(object? sender, RoutedEventArgs e)
    {
        HideActiveBanner();
    }

    private void CardSlot_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (sender is not Grid g) return;
        if (!int.TryParse(g.Tag?.ToString(), out var idx)) return;
        if (DataContext is not VideoPokerViewModel vm) return;

        if (vm.State.Phase == VideoPokerPhase.Result || vm.State.Phase == VideoPokerPhase.Deal)
        {
            DealFromResult();
            e.Handled = true;
            return;
        }

        if (!vm.IsHolding) return;
        vm.ToggleHold(idx);
        Refresh(vm);
        SoundService.PlaySnap();
        e.Handled = true;
    }

    private void HoldAll_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not VideoPokerViewModel vm) return;
        if (!vm.IsHolding) return;
        vm.HoldAll();
        Refresh(vm);
    }

    private void ClearAll_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not VideoPokerViewModel vm) return;
        if (!vm.IsHolding) return;
        vm.ClearHolds();
        Refresh(vm);
    }

    private void DealDraw_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not VideoPokerViewModel vm) return;
        if ((DateTime.UtcNow - _lastDealDrawTime).TotalMilliseconds < 400) return;
        _lastDealDrawTime = DateTime.UtcNow;
        DoDealOrDraw(vm);
    }

    private void DecreaseBet_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not VideoPokerViewModel vm) return;
        vm.DecreaseBet();
        Refresh(vm);
    }

    private void IncreaseBet_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not VideoPokerViewModel vm) return;
        vm.IncreaseBet();
        Refresh(vm);
    }

    private void BetMax_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not VideoPokerViewModel vm) return;
        vm.BetMax();
        Refresh(vm);
    }

    private void Rebuy_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not VideoPokerViewModel vm) return;
        vm.Rebuy();
        Refresh(vm);
    }

    // ── Idle nudge ────────────────────────────────────────────────────────────

    private void ResetIdleTimer(VideoPokerViewModel vm)
    {
        _idleTimer?.Stop();
        _idleTimer = null;
        if (IdlePrompt.Opacity > 0) FadeOutIdlePrompt();
        if (vm.State.Phase != VideoPokerPhase.Deal) return;
        _idleTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(5) };
        _idleTimer.Tick += (_, _) =>
        {
            _idleTimer!.Stop();
            _idleTimer = null;
            if (DataContext is VideoPokerViewModel v && v.State.Phase == VideoPokerPhase.Deal)
                FadeInIdlePrompt();
        };
        _idleTimer.Start();
    }

    private void FadeInIdlePrompt()
    {
        _idleFadeTimer?.Stop();
        double opacity = IdlePrompt.Opacity;
        _idleFadeTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _idleFadeTimer.Tick += (_, _) =>
        {
            opacity = Math.Min(1.0, opacity + 16.0 / 600.0);
            IdlePrompt.Opacity = opacity;
            if (opacity >= 1.0) { _idleFadeTimer!.Stop(); _idleFadeTimer = null; }
        };
        _idleFadeTimer.Start();
    }

    private void FadeOutIdlePrompt()
    {
        _idleFadeTimer?.Stop();
        double opacity = IdlePrompt.Opacity;
        if (opacity <= 0) return;
        double speed = opacity / (300.0 / 16.0);
        _idleFadeTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _idleFadeTimer.Tick += (_, _) =>
        {
            opacity = Math.Max(0, opacity - speed);
            IdlePrompt.Opacity = opacity;
            if (opacity <= 0) { _idleFadeTimer!.Stop(); _idleFadeTimer = null; IdlePrompt.Opacity = 0; }
        };
        _idleFadeTimer.Start();
    }
}
