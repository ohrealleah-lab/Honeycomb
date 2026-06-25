using System;
using System.Collections.Generic;
using System.ComponentModel;
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
    private readonly Border[]    _holdBadges = null!;
    private Grid[]               _cardSlots = null!;
    private readonly Dictionary<string, Border> _payRowBorders = new();
    private TextBlock[] _payColHeaders = null!;
    private readonly List<TextBlock[]> _payValueBlocks = new();
    private DispatcherTimer? _resultFadeTimer;

    private static readonly Card _blankCard = new("__vp_blank__", CardSuit.Spades, 0, false);

    // Result caching — keeps result visible until next Deal
    private string _cachedResultText = "";
    private bool   _cachedHasWin = false;
    private VideoPokerPhase _prevPhase = VideoPokerPhase.Deal;

    private bool _variantInitializing = true;

    public VideoPokerView()
    {
        InitializeComponent();

        _cardViews  = new[] { Card0View,  Card1View,  Card2View,  Card3View,  Card4View  };
        _holdBadges = new[] { HoldBadge0, HoldBadge1, HoldBadge2, HoldBadge3, HoldBadge4 };
        _cardSlots     = new[] { CardSlot0,  CardSlot1,  CardSlot2,  CardSlot3,  CardSlot4  };
        _payColHeaders = new[] { PayColHdr1, PayColHdr2, PayColHdr3, PayColHdr4, PayColHdr5 };

        this.Loaded   += VideoPokerView_Loaded;
        this.Unloaded += VideoPokerView_Unloaded;
    }

    private void VideoPokerView_Loaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not VideoPokerViewModel vm) return;
        vm.PropertyChanged += Vm_PropertyChanged;

        TopLevel.GetTopLevel(this)?.AddHandler(
            InputElement.KeyDownEvent, OnKeyDown, RoutingStrategies.Tunnel);

        _variantInitializing = true;
        VariantComboBox.SelectedIndex = (int)vm.Options.Variant;
        _variantInitializing = false;

        BuildPayTable(vm);
        Refresh(vm);
    }

    private void VideoPokerView_Unloaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is VideoPokerViewModel vm)
            vm.PropertyChanged -= Vm_PropertyChanged;
        TopLevel.GetTopLevel(this)?.RemoveHandler(
            InputElement.KeyDownEvent, OnKeyDown);
        StopResultFade();
    }

    private void Vm_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        // Timer fires from a background thread — must marshal to UI thread
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
        bool anyHeld = vm.IsHolding && System.Array.Exists(vm.State.HeldSlots, h => h);
        for (int i = 0; i < 5; i++)
        {
            var card = vm.State.Hand.Count > i ? vm.State.Hand[i] : _blankCard;
            _cardViews[i].Card = card;

            // Only dim un-held cards once the player has held at least one card
            _cardViews[i].Opacity = (anyHeld && !vm.State.HeldSlots[i]) ? 0.65 : 1.0;
        }
    }

    private void UpdateHoldBadges(VideoPokerViewModel vm)
    {
        for (int i = 0; i < 5; i++)
        {
            bool held = vm.IsHolding && vm.State.HeldSlots[i];
            _holdBadges[i].Opacity = held ? 1.0 : 0.0;
            _cardSlots[i].RenderTransform = new TranslateTransform(0, held ? -20 : 0);
        }
    }

    private void UpdateControls(VideoPokerViewModel vm)
    {
        CreditsLabel.Text      = vm.CreditDisplay;
        BetLabel.Text          = vm.BetDisplay;
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
        var phase = vm.State.Phase;

        if (phase == VideoPokerPhase.Result)
        {
            StopResultFade();
            _cachedResultText = vm.ResultText;
            _cachedHasWin     = vm.HasWin;
        }
        else if (_prevPhase == VideoPokerPhase.Result && phase == VideoPokerPhase.Holding)
        {
            StartResultFade();
            _prevPhase = phase;
            return;
        }
        else if (_resultFadeTimer != null)
        {
            // Fade in progress — don't overwrite display
            _prevPhase = phase;
            return;
        }
        else
        {
            _cachedResultText = "";
            _cachedHasWin     = false;
        }

        _prevPhase = phase;

        ResultTextBlock.Text       = _cachedResultText;
        ResultTextBlock.Foreground = _cachedHasWin
            ? new SolidColorBrush(Color.Parse("#FFD700"))
            : new SolidColorBrush(Color.Parse("#AAAAAA"));
        ResultBanner.Background    = _cachedHasWin
            ? new SolidColorBrush(Color.Parse("#33FFD700"))
            : Brushes.Transparent;
    }

    private void StartResultFade()
    {
        _resultFadeTimer?.Stop();
        double opacity = 1.0;
        _resultFadeTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(20) };
        _resultFadeTimer.Tick += (_, _) =>
        {
            opacity -= 0.06; // ~330 ms total (17 steps × 20 ms)
            if (opacity <= 0)
            {
                _resultFadeTimer!.Stop();
                _resultFadeTimer = null;
                _cachedResultText = "";
                _cachedHasWin = false;
                ResultTextBlock.Text = "";
                ResultBanner.Background = Brushes.Transparent;
                ResultBanner.Opacity = 1.0;
                return;
            }
            ResultBanner.Opacity = opacity;
        };
        _resultFadeTimer.Start();
    }

    private void StopResultFade()
    {
        _resultFadeTimer?.Stop();
        _resultFadeTimer = null;
        ResultBanner.Opacity = 1.0;
    }

    // ── Pay table ─────────────────────────────────────────────────────────────

    private void BuildPayTable(VideoPokerViewModel vm)
    {
        PayTablePanel.Children.Clear();
        _payRowBorders.Clear();
        _payValueBlocks.Clear();

        foreach (var entry in vm.CurrentTable)
        {
            var border = new Border
            {
                Padding      = new Avalonia.Thickness(2, 2),
                CornerRadius = new Avalonia.CornerRadius(3),
                Background   = Brushes.Transparent,
            };

            var grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            for (int i = 0; i < 5; i++)
                grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(22) });

            var nameBlock = new TextBlock
            {
                Text         = entry.HandName,
                FontSize     = 9.5,
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
                    FontSize            = 9.5,
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
            PayTablePanel.Children.Add(border);
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
            _payColHeaders[col].Foreground = active
                ? new SolidColorBrush(Color.Parse("#FFD700"))
                : new SolidColorBrush(Color.FromArgb(0x60, 0xFF, 0xFF, 0xFF));
            foreach (var row in _payValueBlocks)
                row[col].Foreground = active
                    ? new SolidColorBrush(Color.Parse("#FFD700"))
                    : Brushes.White;
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

    // ── Keyboard ──────────────────────────────────────────────────────────────

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (DataContext is not VideoPokerViewModel vm) return;

        switch (e.Key)
        {
            case Key.Space:
            case Key.Enter:
                vm.DealOrDraw();
                Refresh(vm);
                SoundService.PlayShuffle();
                e.Handled = true;
                break;
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

    private void VariantComboBox_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (_variantInitializing) return;
        if (DataContext is not VideoPokerViewModel vm) return;
        if (VariantComboBox.SelectedIndex < 0) return;

        var variant = (VideoPokerVariant)VariantComboBox.SelectedIndex;
        vm.SetVariant(variant);
        BuildPayTable(vm);
    }

    private void CardSlot_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (sender is not Grid g) return;
        if (!int.TryParse(g.Tag?.ToString(), out var idx)) return;
        if (DataContext is not VideoPokerViewModel vm) return;
        if (!vm.IsHolding) return;

        vm.ToggleHold(idx);
        Refresh(vm);
        SoundService.PlaySnap();
        e.Handled = true;
    }

    private void DealDraw_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not VideoPokerViewModel vm) return;
        vm.DealOrDraw();
        Refresh(vm);
        SoundService.PlayShuffle();
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
