using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using SoliBee.Desktop.Services;

namespace SoliBee.Desktop.Views;

public partial class BlackjackView : UserControl
{
    private DispatcherTimer? _bannerDelayTimer;
    private DispatcherTimer? _bannerFadeTimer;
    private DispatcherTimer? _winPulseTimer;
    private DispatcherTimer? _bustFlashTimer;
    private double           _winPulsePhase;

    private BlackjackPhase _lastPhase         = BlackjackPhase.Betting;
    private bool           _resultSoundPlayed = false;
    private int            _prevBustCount     = 0;

    // Deal animation — track card IDs to detect newly-added cards each refresh
    private List<string>       _prevDealerIds  = new();
    private List<List<string>> _prevPlayerIds  = new();

    // Active chip button highlight tracking
    private static readonly SolidColorBrush _chipHighlight = new(Color.FromArgb(0x50, 0xFF, 0xFF, 0xFF));

    public BlackjackView()
    {
        InitializeComponent();
        this.Loaded   += OnLoaded;
        this.Unloaded += OnUnloaded;
    }

    private void OnLoaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;
        vm.PropertyChanged += Vm_PropertyChanged;
        TopLevel.GetTopLevel(this)?.AddHandler(InputElement.KeyDownEvent, OnKeyDown, RoutingStrategies.Tunnel);
        if (vm.CanDeal) vm.Deal();
        Refresh(vm);
    }

    private void OnUnloaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is BlackjackViewModel vm)
            vm.PropertyChanged -= Vm_PropertyChanged;
        TopLevel.GetTopLevel(this)?.RemoveHandler(InputElement.KeyDownEvent, OnKeyDown);
        StopTimers();
    }

    private void Vm_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        Dispatcher.UIThread.Post(() =>
        {
            if (DataContext is BlackjackViewModel vm) Refresh(vm);
        });
    }

    // ── Full refresh ─────────────────────────────────────────────────────────

    private void Refresh(BlackjackViewModel vm)
    {
        CreditsLabel.Text = vm.CreditDisplay;
        BetLabel.Text     = vm.BetDisplay;
        HandsLabel.Text   = vm.HandsDisplay;

        // Phase-transition sounds
        PlayTransitionSounds(vm);

        RebuildDealerCards(vm);
        RebuildPlayerHands(vm);
        UpdateButtons(vm);
        UpdateChipHighlight(vm);
        UpdateResult(vm);
        ApplyFeltColor(vm);

        _lastPhase = vm.State.Phase;
    }

    private void PlayTransitionSounds(BlackjackViewModel vm)
    {
        var phase = vm.State.Phase;

        // Hole card flips when dealer starts playing
        if (_lastPhase == BlackjackPhase.Playing && phase == BlackjackPhase.DealerTurn)
            SoundService.PlaySnap();

        // Win/loss sound fires once on result
        if (phase == BlackjackPhase.Result && !_resultSoundPlayed)
        {
            _resultSoundPlayed = true;
            bool anyWin = vm.State.PlayerHands.Any(h =>
                h.Result is BlackjackHandResult.Won or BlackjackHandResult.Blackjack);
            if (anyWin) SoundService.PlayVictory();
        }

        if (phase == BlackjackPhase.Playing)
            _resultSoundPlayed = false;
    }

    // ── Deal animation helper ─────────────────────────────────────────────────

    private static void ScheduleCardSlideIn(CardView cv, double fromX, double fromY, int durationMs, int delayMs)
    {
        if (delayMs == 0) { cv.BeginSlideIn(fromX, fromY, durationMs); return; }
        var t = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(delayMs) };
        t.Tick += (_, _) => { t.Stop(); cv.BeginSlideIn(fromX, fromY, durationMs); };
        t.Start();
    }

    // ── Dealer cards ──────────────────────────────────────────────────────────

    private void RebuildDealerCards(BlackjackViewModel vm)
    {
        DealerCardsPanel.Children.Clear();

        var cards   = vm.State.DealerHand.Cards;
        var newIds  = cards.Select(c => c.Id).ToList();
        int stagger = 0;

        for (int i = 0; i < cards.Count; i++)
        {
            var cv = new CardView { Card = cards[i], IsHitTestVisible = false };
            var vb = new Viewbox { Stretch = Stretch.Uniform, Width = 160, Height = 226, Child = cv };
            if (i > 0) vb.Margin = new Avalonia.Thickness(-30, 0, 0, 0);
            DealerCardsPanel.Children.Add(vb);

            bool isNew = i >= _prevDealerIds.Count || _prevDealerIds[i] != newIds[i];
            if (isNew) ScheduleCardSlideIn(cv, 0, -42, 185, stagger++ * 110);
        }

        _prevDealerIds = newIds;

        bool isDuringPlay = vm.State.Phase == BlackjackPhase.Playing;
        var (visVal, visSoft)   = vm.State.DealerHand.ComputeVisibleValue();
        var (fullVal, fullSoft) = vm.State.DealerHand.ComputeValue();

        if (cards.Count == 0)
        {
            DealerValuePill.IsVisible = false;
        }
        else if (isDuringPlay)
        {
            DealerValuePill.IsVisible = visVal > 0;
            DealerValueLabel.Text = $"{visVal}{(visSoft ? "*" : "")}";
            DealerValueLabel.Foreground = Brushes.White;
        }
        else
        {
            DealerValuePill.IsVisible = true;
            bool bust = fullVal > 21;
            DealerValueLabel.Text = bust ? $"{fullVal}  BUST" : $"{fullVal}{(fullSoft ? "*" : "")}";
            DealerValueLabel.Foreground = bust
                ? new SolidColorBrush(Color.Parse("#FF6666"))
                : Brushes.White;
        }
    }

    // ── Player hands ──────────────────────────────────────────────────────────

    private void RebuildPlayerHands(BlackjackViewModel vm)
    {
        PlayerHandsContainer.Children.Clear();

        // Grow tracking list as needed
        while (_prevPlayerIds.Count < vm.State.PlayerHands.Count)
            _prevPlayerIds.Add(new List<string>());

        int bustCount = 0;
        Border? newBustBorder = null;

        for (int hi = 0; hi < vm.State.PlayerHands.Count; hi++)
        {
            var hand    = vm.State.PlayerHands[hi];
            bool active = vm.State.Phase == BlackjackPhase.Playing && hi == vm.State.ActiveHandIndex;
            bool result = vm.State.Phase == BlackjackPhase.Result;

            var (val, soft) = hand.ComputeValue();
            bool bust = val > 21;
            if (bust) bustCount++;

            string valueText = bust ? $"{val}  BUST"
                             : soft ? $"{val}*"
                                    : $"{val}";

            var prevIds = hi < _prevPlayerIds.Count ? _prevPlayerIds[hi] : new List<string>();
            var newIds  = hand.Cards.Select(c => c.Id).ToList();
            int stagger = 0;

            // Cards row
            var cardRow = new StackPanel { Orientation = Orientation.Horizontal };
            for (int ci = 0; ci < hand.Cards.Count; ci++)
            {
                var cv = new CardView { Card = hand.Cards[ci], IsHitTestVisible = false };
                var vb = new Viewbox { Stretch = Stretch.Uniform, Width = 160, Height = 226, Child = cv };
                if (ci > 0) vb.Margin = new Avalonia.Thickness(-30, 0, 0, 0);
                cardRow.Children.Add(vb);

                bool isNew = ci >= prevIds.Count || prevIds[ci] != newIds[ci];
                if (isNew) ScheduleCardSlideIn(cv, 0, 42, 185, stagger++ * 110);
            }

            if (hi < _prevPlayerIds.Count) _prevPlayerIds[hi] = newIds;
            else _prevPlayerIds.Add(newIds);

            // Value pill
            var valuePill = new Border
            {
                Background   = bust
                    ? new SolidColorBrush(Color.FromArgb(0xCC, 0xAA, 0x00, 0x00))
                    : new SolidColorBrush(Color.FromArgb(0x99, 0x00, 0x00, 0x00)),
                CornerRadius = new Avalonia.CornerRadius(10),
                Padding      = new Avalonia.Thickness(12, 3),
                HorizontalAlignment = HorizontalAlignment.Center,
                IsVisible    = hand.Cards.Count > 0,
                Child = new TextBlock
                {
                    Text       = valueText,
                    FontSize   = 14,
                    FontWeight = FontWeight.Bold,
                    Foreground = bust
                        ? new SolidColorBrush(Color.Parse("#FF9999"))
                        : Brushes.White,
                    FontFamily = new FontFamily("Courier New, Consolas, monospace"),
                }
            };

            // Result badge (shown after hand ends)
            Border? resultBadge = null;
            if (result && hand.Result != BlackjackHandResult.Pending)
            {
                string badgeText = hand.Result switch
                {
                    BlackjackHandResult.Blackjack => "BLACKJACK",
                    BlackjackHandResult.Won       => $"+{hand.Bet}",
                    BlackjackHandResult.Push      => "PUSH",
                    BlackjackHandResult.Lost      => $"-{hand.Bet}",
                    _                             => "",
                };
                var badgeFg = hand.Result switch
                {
                    BlackjackHandResult.Blackjack or BlackjackHandResult.Won
                        => new SolidColorBrush(Color.Parse("#FFD700")),
                    BlackjackHandResult.Push
                        => (IBrush)Brushes.White,
                    _   => new SolidColorBrush(Color.Parse("#FF6666")),
                };
                resultBadge = new Border
                {
                    Background   = new SolidColorBrush(Color.FromArgb(0xCC, 0x00, 0x00, 0x00)),
                    CornerRadius = new Avalonia.CornerRadius(8),
                    Padding      = new Avalonia.Thickness(10, 2),
                    HorizontalAlignment = HorizontalAlignment.Center,
                    Child = new TextBlock
                    {
                        Text       = badgeText,
                        FontSize   = 13,
                        FontWeight = FontWeight.Bold,
                        Foreground = badgeFg,
                        FontFamily = new FontFamily("Courier New, Consolas, monospace"),
                    }
                };
            }

            var inner = new StackPanel { Spacing = 5 };
            inner.Children.Add(cardRow);
            inner.Children.Add(valuePill);
            if (resultBadge != null) inner.Children.Add(resultBadge);

            var container = new Border
            {
                Child           = inner,
                Padding         = new Avalonia.Thickness(6, 4),
                CornerRadius    = new Avalonia.CornerRadius(6),
                BorderThickness = new Avalonia.Thickness(0),
                Background      = null,
            };

            // Track the bust border for the flash animation
            if (bust) newBustBorder = container;

            // Outer column — includes "YOUR TURN" indicator for split
            var outer = new StackPanel { Spacing = 3, HorizontalAlignment = HorizontalAlignment.Center };
            if (active && vm.State.IsSplit)
            {
                outer.Children.Add(new TextBlock
                {
                    Text                = "▶  YOUR TURN",
                    FontSize            = 10,
                    FontWeight          = FontWeight.Bold,
                    Foreground          = new SolidColorBrush(Color.FromArgb(0xCC, 0xFF, 0xFF, 0x44)),
                    HorizontalAlignment = HorizontalAlignment.Center,
                    FontFamily          = new FontFamily("Courier New, Consolas, monospace"),
                    LetterSpacing       = 1,
                });
            }
            outer.Children.Add(container);
            PlayerHandsContainer.Children.Add(outer);
        }

        // Trigger bust flash if a new bust just appeared
        if (bustCount > _prevBustCount && newBustBorder != null && vm.State.Phase == BlackjackPhase.Playing)
            AnimateBustFlash(newBustBorder);

        _prevBustCount = bustCount;
    }

    // ── Bust flash ────────────────────────────────────────────────────────────

    private void AnimateBustFlash(Border target)
    {
        _bustFlashTimer?.Stop();
        int ticks = 0;
        var bustRed = new SolidColorBrush(Color.FromArgb(0x60, 0xFF, 0x00, 0x00));
        var clear   = new SolidColorBrush(Color.FromArgb(0x00, 0x00, 0x00, 0x00));
        _bustFlashTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(110) };
        _bustFlashTimer.Tick += (_, _) =>
        {
            ticks++;
            target.Background = ticks % 2 == 1 ? bustRed : clear;
            if (ticks >= 6)
            {
                _bustFlashTimer!.Stop();
                _bustFlashTimer = null;
                target.Background = clear;
            }
        };
        _bustFlashTimer.Start();
        SoundService.PlaySnap();
    }

    // ── Buttons ───────────────────────────────────────────────────────────────

    private void UpdateButtons(BlackjackViewModel vm)
    {
        bool playing = vm.State.Phase == BlackjackPhase.Playing;
        bool canDeal = vm.CanDeal;

        HitButton.IsVisible    = playing;
        StandButton.IsVisible  = playing;
        DoubleButton.IsVisible = playing;
        SplitButton.IsVisible  = playing;
        DealButton.IsVisible   = canDeal || vm.State.Phase == BlackjackPhase.Betting;
        RebuyButton.IsVisible  = vm.NeedsRebuy && canDeal;

        if (playing)
        {
            HitButton.IsEnabled    = vm.CanHit;
            StandButton.IsEnabled  = vm.CanStand;
            DoubleButton.IsEnabled = vm.CanDouble;
            SplitButton.IsEnabled  = vm.CanSplit;
        }

        DealButton.Content = vm.State.Phase == BlackjackPhase.Result ? "Deal Again" : "Deal";

        // Show keyboard hints only when betting/result (not during play — avoid clutter)
        KeyHintLabel.Opacity = playing ? 0.0 : 1.0;
    }

    // ── Chip highlight ────────────────────────────────────────────────────────

    private void UpdateChipHighlight(BlackjackViewModel vm)
    {
        int bet = vm.State.CurrentBet;
        SetChipSelected(ChipBtn1, bet == 1);
        SetChipSelected(ChipBtn2, bet == 2);
        SetChipSelected(ChipBtn3, bet == 3);
        SetChipSelected(ChipBtn4, bet == 4);
        SetChipSelected(ChipBtn5, bet == 5);
    }

    private static void SetChipSelected(Button btn, bool selected)
    {
        if (selected)
        {
            btn.BorderThickness = new Avalonia.Thickness(3);
            btn.Opacity = 1.0;
        }
        else
        {
            btn.BorderThickness = new Avalonia.Thickness(2);
            btn.Opacity = 0.65;
        }
    }

    // ── Result overlay ────────────────────────────────────────────────────────

    private void UpdateResult(BlackjackViewModel vm)
    {
        if (vm.State.Phase != BlackjackPhase.Result)
        {
            if (_lastPhase == BlackjackPhase.Result) HideBanner();
            return;
        }

        // Don't restart the banner if we're already showing it for this result
        if (_lastPhase == BlackjackPhase.Result) return;

        int net = vm.State.LastNetResult;
        bool anyBJ   = vm.State.PlayerHands.Any(h => h.Result == BlackjackHandResult.Blackjack);
        bool anyWin  = vm.State.PlayerHands.Any(h => h.Result is BlackjackHandResult.Won or BlackjackHandResult.Blackjack);
        bool allPush = vm.State.PlayerHands.All(h => h.Result == BlackjackHandResult.Push);

        string netStr = net > 0 ? $"+{net} credits" : net < 0 ? $"{net} credits" : "Even";

        if (anyBJ)
        {
            ResultHeadline.Text = "BLACKJACK!";
            ResultSubline.Text  = netStr;
            ResultOverlay.BoxShadow = BoxShadows.Parse("0 0 28 8 #90FFD700, 0 4 18 0 #AA000000");
            ShowBanner(win: true, vm.ConsecutiveWins);
        }
        else if (anyWin)
        {
            ResultHeadline.Text = "YOU WIN!";
            ResultSubline.Text  = netStr;
            ResultOverlay.BoxShadow = BoxShadows.Parse("0 0 28 8 #90FFD700, 0 4 18 0 #AA000000");
            ShowBanner(win: true, vm.ConsecutiveWins);
        }
        else if (allPush)
        {
            ResultHeadline.Text = "PUSH";
            ResultSubline.Text  = "Bets returned";
            ResultOverlay.BoxShadow = BoxShadows.Parse("0 4 18 0 #AA000000");
            ShowBanner(win: false, 0);
        }
        else
        {
            ResultHeadline.Text = "DEALER WINS";
            ResultSubline.Text  = netStr;
            ResultOverlay.BoxShadow = BoxShadows.Parse("0 4 18 0 #AA000000");
            ShowBanner(win: false, 0);
        }
    }

    private void ShowBanner(bool win, int streak)
    {
        if (streak >= 2)
        {
            ResultStreak.Text      = streak >= 5 ? $"*** {streak} WIN STREAK ***"
                                   : streak >= 3 ? $"** {streak} WIN STREAK **"
                                   :               $"{streak} wins in a row!";
            ResultStreak.IsVisible = true;
        }
        else
        {
            ResultStreak.IsVisible = false;
        }

        ResultOverlay.Opacity   = 1.0;
        ResultOverlay.IsVisible = true;

        if (win) StartWinPulse();
        else StopWinPulse();

        _bannerDelayTimer?.Stop();
        _bannerDelayTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(2000) };
        _bannerDelayTimer.Tick += (_, _) =>
        {
            _bannerDelayTimer!.Stop();
            _bannerDelayTimer = null;
            FadeBanner();
        };
        _bannerDelayTimer.Start();
    }

    private void FadeBanner()
    {
        _bannerFadeTimer?.Stop();
        double opacity = 1.0;
        _bannerFadeTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _bannerFadeTimer.Tick += (_, _) =>
        {
            opacity -= 0.04;
            if (opacity <= 0)
            {
                _bannerFadeTimer!.Stop();
                _bannerFadeTimer = null;
                ResultOverlay.IsVisible = false;
                ResultOverlay.Opacity   = 1.0;
                StopWinPulse();
                return;
            }
            ResultOverlay.Opacity = opacity;
        };
        _bannerFadeTimer.Start();
    }

    private void HideBanner()
    {
        _bannerDelayTimer?.Stop(); _bannerDelayTimer = null;
        _bannerFadeTimer?.Stop();  _bannerFadeTimer  = null;
        ResultOverlay.IsVisible = false;
        ResultOverlay.Opacity   = 1.0;
        StopWinPulse();
    }

    private void StartWinPulse()
    {
        _winPulseTimer?.Stop();
        _winPulsePhase = 0;
        ResultOverlay.RenderTransform = new ScaleTransform(1.0, 1.0);
        _winPulseTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _winPulseTimer.Tick += (_, _) =>
        {
            _winPulsePhase += 0.045;
            double scale = 1.0 + Math.Sin(_winPulsePhase) * 0.025;
            if (ResultOverlay.RenderTransform is ScaleTransform st)
            { st.ScaleX = scale; st.ScaleY = scale; }
        };
        _winPulseTimer.Start();
    }

    private void StopWinPulse()
    {
        _winPulseTimer?.Stop(); _winPulseTimer = null;
        ResultOverlay.RenderTransform = null;
    }

    private void StopTimers()
    {
        _bannerDelayTimer?.Stop(); _bannerDelayTimer = null;
        _bannerFadeTimer?.Stop();  _bannerFadeTimer  = null;
        _winPulseTimer?.Stop();    _winPulseTimer    = null;
        _bustFlashTimer?.Stop();   _bustFlashTimer   = null;
    }

    // ── Felt color ────────────────────────────────────────────────────────────

    private void ApplyFeltColor(BlackjackViewModel vm)
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
        try { BoardFeltGrid.Background = new SolidColorBrush(Color.Parse(hex)); }
        catch { BoardFeltGrid.Background = new SolidColorBrush(Colors.DarkGreen); }
    }

    // ── Keyboard ──────────────────────────────────────────────────────────────

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;
        switch (e.Key)
        {
            case Key.Space: case Key.Enter:
                if (vm.CanDeal) { vm.Deal(); SoundService.PlayShuffle(); }
                e.Handled = true; break;
            case Key.H:
                if (vm.CanHit) { vm.Hit(); SoundService.PlaySnap(); }
                e.Handled = true; break;
            case Key.S:
                if (vm.CanStand) { vm.Stand(); }
                e.Handled = true; break;
            case Key.D:
                if (vm.CanDouble) { vm.DoubleDown(); SoundService.PlaySnap(); }
                e.Handled = true; break;
            case Key.P:
                if (vm.CanSplit) { vm.Split(); SoundService.PlaySnap(); }
                e.Handled = true; break;
        }
    }

    // ── Event handlers ────────────────────────────────────────────────────────

    private void Deal_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;
        vm.Deal();
        SoundService.PlayShuffle();
    }

    private void Hit_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm || !vm.CanHit) return;
        vm.Hit();
        SoundService.PlaySnap();
    }

    private void Stand_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm || !vm.CanStand) return;
        vm.Stand();
    }

    private void Double_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm || !vm.CanDouble) return;
        vm.DoubleDown();
        SoundService.PlaySnap();
    }

    private void Split_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm || !vm.CanSplit) return;
        vm.Split();
        SoundService.PlaySnap();
    }

    private void Chip_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;
        if (sender is Button btn && btn.Tag is string tagStr && int.TryParse(tagStr, out int amount))
        {
            vm.SetBet(amount);
            SoundService.PlaySnap();
        }
    }

    private void Rebuy_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;
        vm.Rebuy();
        SoundService.PlaySnap();
    }

    private void ResultOverlay_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;
        HideBanner();
        if (vm.CanDeal) { vm.Deal(); SoundService.PlayShuffle(); }
        e.Handled = true;
    }
}
