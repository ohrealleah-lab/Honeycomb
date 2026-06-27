using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Threading;
using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Threading;
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
    private DispatcherTimer? _winPulseTimer;
    private double _winPulsePhase;
    private DispatcherTimer? _creditAnimTimer;
    private int _displayedCredits = -1;

    // Banner fade state
    private Border? _activeBanner;
    private DispatcherTimer? _bannerDelayTimer;
    private DispatcherTimer? _bannerFadeTimer;

    // Cards fade state
    private DispatcherTimer? _cardsFadeTimer;

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

        BuildPayTable(vm);
        Refresh(vm);
    }

    private void VideoPokerView_Unloaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is VideoPokerViewModel vm)
            vm.PropertyChanged -= Vm_PropertyChanged;
        TopLevel.GetTopLevel(this)?.RemoveHandler(
            InputElement.KeyDownEvent, OnKeyDown);
        HideActiveBanner();
        StopCardsFade();
        _dealAnimCts?.Cancel();
        _creditAnimTimer?.Stop();
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
        UpdateCards(vm);
        UpdateHoldBadges(vm);
        UpdateControls(vm);
        UpdateResult(vm);
        HighlightPayRow(vm.WinningHandName);
        UpdatePayColumnHighlight(vm.State.CurrentBet);
        ApplyFeltColor(vm);
    }

    private void UpdateCards(VideoPokerViewModel vm)
    {
        for (int i = 0; i < 5; i++)
        {
            var card = vm.State.Hand.Count > i ? vm.State.Hand[i] : _blankCard;
            _cardViews[i].Card = card;
            _cardViews[i].Opacity = 1.0;
        }
    }

    private void UpdateHoldBadges(VideoPokerViewModel vm)
    {
        for (int i = 0; i < 5; i++)
        {
            bool held = vm.IsHolding && vm.State.HeldSlots[i];
            _cardSlots[i].RenderTransform = new TranslateTransform(0, held ? -20 : 0);
        }
    }

    private void UpdateControls(VideoPokerViewModel vm)
    {
        AnimateCreditsTo(vm.CreditDisplay);
        BetLabel.Text          = vm.BetDisplay;
        HandsLabel.Text        = vm.Stats.TotalHands.ToString();
        DealDrawButton.Content = vm.DealDrawLabel;
        RebuyButton.IsVisible  = vm.NeedsRebuy;

        var slotCursor = vm.IsHolding
            ? new Cursor(StandardCursorType.Hand)
            : new Cursor(StandardCursorType.Arrow);
        for (int i = 0; i < 5; i++)
            _cardSlots[i].Cursor = slotCursor;
    }

    private void UpdateResult(VideoPokerViewModel vm)
    {
        if (vm.State.Phase == VideoPokerPhase.Result && vm.HasWin)
        {
            WinHandNameBlock.Text = vm.State.LastHandName;
            WinPayoutBlock.Text   = $"+{vm.State.LastPayout}";
            ShowBanner(WinBanner);
            StartWinPulse();
        }
        else if (vm.State.Phase == VideoPokerPhase.Result && vm.ShowNoWin)
        {
            ShowBanner(NoWinOverlay);
            StopWinPulse();
        }
        else
        {
            HideActiveBanner();
        }
    }

    private void ShowBanner(Border banner)
    {
        if (_activeBanner == banner)
        {
            // Already visible — restart the delay so player has a fresh 1.5 s
            StartBannerDelay();
            return;
        }
        HideActiveBanner();
        _activeBanner = banner;
        banner.Opacity = 1.0;
        banner.IsVisible = true;
        StartBannerDelay();
    }

    private void StartBannerDelay()
    {
        _bannerDelayTimer?.Stop();
        _bannerDelayTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(1500) };
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
                StopWinPulse();
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
        StopWinPulse();
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
                CardsRow.Opacity = 0;
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
                FontFamily   = new FontFamily("Courier New, Consolas, monospace"),
                TextTrimming = Avalonia.Media.TextTrimming.CharacterEllipsis,
            };
            Grid.SetColumn(nameBlock, 0);
            grid.Children.Add(nameBlock);

            var rowBlocks = new TextBlock[5];
            for (int i = 0; i < 5; i++)
            {
                var valBlock = new TextBlock
                {
                    Text                = entry.Multipliers[i].ToString(),
                    FontSize            = 12,
                    Foreground          = Brushes.White,
                    FontFamily          = new FontFamily("Courier New, Consolas, monospace"),
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
        if (vm.Options.IsFinalFantasyMode)
        {
            BoardFeltGrid.Background = new SolidColorBrush(Colors.Black);
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
            BoardFeltGrid.Background = new SolidColorBrush(Color.Parse(hex));
        }
        catch
        {
            BoardFeltGrid.Background = new SolidColorBrush(Colors.DarkGreen);
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

        // Set new cards to starting position (above, invisible)
        for (int i = 0; i < 5; i++)
        {
            if (!toAnimate[i]) continue;
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

    // ── Win pulse ─────────────────────────────────────────────────────────────

    private void StartWinPulse()
    {
        _winPulseTimer?.Stop();
        _winPulsePhase = 0;
        WinBanner.RenderTransform = new ScaleTransform(1.0, 1.0);

        _winPulseTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _winPulseTimer.Tick += (_, _) =>
        {
            _winPulsePhase += 0.045;
            double scale = 1.0 + Math.Sin(_winPulsePhase) * 0.028;
            if (WinBanner.RenderTransform is ScaleTransform st)
            {
                st.ScaleX = scale;
                st.ScaleY = scale;
            }
        };
        _winPulseTimer.Start();
    }

    private void StopWinPulse()
    {
        _winPulseTimer?.Stop();
        _winPulseTimer = null;
        if (WinBanner != null)
            WinBanner.RenderTransform = null;
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

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (DataContext is not VideoPokerViewModel vm) return;

        switch (e.Key)
        {
            case Key.Space:
            case Key.Enter:
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

    private void CardSlot_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (sender is not Grid g) return;
        if (!int.TryParse(g.Tag?.ToString(), out var idx)) return;
        if (DataContext is not VideoPokerViewModel vm) return;

        if (vm.State.Phase == VideoPokerPhase.Result)
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
}
