using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using Avalonia.Threading;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using SoliBee.Desktop.Services;

namespace SoliBee.Desktop.Views;

public partial class SpiderView : CardGameView
{
    public override bool CanMoveCards(List<Card> cards, Pile targetPile)
    {
        if (DataContext is not SpiderViewModel vm) return false;
        return vm.CanMoveSequence(cards, targetPile);
    }

    public override bool TryMoveCards(List<Card> cards, Pile sourcePile, Pile targetPile)
    {
        if (DataContext is not SpiderViewModel vm) return false;
        if (!vm.CanMoveSequence(cards, targetPile)) return false;
        vm.MoveSequence(cards, sourcePile, targetPile);
        SoundService.PlaySnap();
        return true;
    }

    public override bool TryAutoMoveToFoundation(Card card, Pile sourcePile)
    {
        // Spider auto-completes full runs; no manual double-click to foundation
        return false;
    }

    public SpiderView()
    {
        InitializeComponent();
        this.Loaded += SpiderView_Loaded;
        this.Unloaded += SpiderView_Unloaded;

        WeakReferenceMessenger.Default.Register<FaceCardArtChangedMessage>(this, (r, m) =>
            Dispatcher.UIThread.InvokeAsync(RefreshAllPiles));
    }

    private void RefreshAllPiles()
    {
        Tableau0.UpdateCardsLayout(); Tableau1.UpdateCardsLayout();
        Tableau2.UpdateCardsLayout(); Tableau3.UpdateCardsLayout();
        Tableau4.UpdateCardsLayout(); Tableau5.UpdateCardsLayout();
        Tableau6.UpdateCardsLayout(); Tableau7.UpdateCardsLayout();
        Tableau8.UpdateCardsLayout(); Tableau9.UpdateCardsLayout();
        Foundation0.UpdateCardsLayout(); Foundation1.UpdateCardsLayout();
        Foundation2.UpdateCardsLayout(); Foundation3.UpdateCardsLayout();
        Foundation4.UpdateCardsLayout(); Foundation5.UpdateCardsLayout();
        Foundation6.UpdateCardsLayout(); Foundation7.UpdateCardsLayout();
    }

    private void SpiderView_Loaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is SpiderViewModel vm)
        {
            vm.PropertyChanged += ViewModel_PropertyChanged;
            ApplyFeltColor(vm.Options);
            BindPiles(vm);
            UpdateStockDisplay(vm);
        }
        VictoryOverlay.PlayAgainRequested += VictoryOverlay_PlayAgainRequested;
    }

    private void SpiderView_Unloaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is SpiderViewModel vm)
            vm.PropertyChanged -= ViewModel_PropertyChanged;
        VictoryOverlay.PlayAgainRequested -= VictoryOverlay_PlayAgainRequested;
    }

    private void VictoryOverlay_PlayAgainRequested(object? sender, EventArgs e)
    {
        if (DataContext is SpiderViewModel vm) vm.InitializeGame();
    }

    private void ViewModel_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        Avalonia.Threading.Dispatcher.UIThread.InvokeAsync(() =>
        {
            if (DataContext is not SpiderViewModel vm) return;

            if (e.PropertyName == nameof(SpiderViewModel.State))
            {
                if (vm.State.HasWon) TriggerVictoryCascade();
                else
                {
                    _winTriggered = false;
                    VictoryOverlay.StopAnimation();
                    VictoryOverlay.IsVisible = false;
                }
            }
            else if (e.PropertyName == "Tableaus")
            {
                Tableau0.UpdateCardsLayout();
                Tableau1.UpdateCardsLayout();
                Tableau2.UpdateCardsLayout();
                Tableau3.UpdateCardsLayout();
                Tableau4.UpdateCardsLayout();
                Tableau5.UpdateCardsLayout();
                Tableau6.UpdateCardsLayout();
                Tableau7.UpdateCardsLayout();
                Tableau8.UpdateCardsLayout();
                Tableau9.UpdateCardsLayout();
                if (vm.State.HasWon) TriggerVictoryCascade();
            }
            else if (e.PropertyName == "Foundations")
            {
                Foundation0.UpdateCardsLayout();
                Foundation1.UpdateCardsLayout();
                Foundation2.UpdateCardsLayout();
                Foundation3.UpdateCardsLayout();
                Foundation4.UpdateCardsLayout();
                Foundation5.UpdateCardsLayout();
                Foundation6.UpdateCardsLayout();
                Foundation7.UpdateCardsLayout();
                if (vm.State.HasWon) TriggerVictoryCascade();
            }
            else if (e.PropertyName == "StockPiles")
            {
                UpdateStockDisplay(vm);
            }
            else if (e.PropertyName == nameof(SpiderViewModel.HasNoMoves))
            {
                NoMovesBanner.IsVisible = vm.HasNoMoves;
            }
            else if (e.PropertyName == nameof(SpiderViewModel.ActiveHint))
            {
                ApplyHint(vm.ActiveHint, AllPileViews());
            }
            else if (e.PropertyName == nameof(SpiderViewModel.Options))
            {
                ApplyFeltColor(vm.Options);
                Tableau0.UpdateCardsLayout();
                Tableau1.UpdateCardsLayout();
                Tableau2.UpdateCardsLayout();
                Tableau3.UpdateCardsLayout();
                Tableau4.UpdateCardsLayout();
                Tableau5.UpdateCardsLayout();
                Tableau6.UpdateCardsLayout();
                Tableau7.UpdateCardsLayout();
                Tableau8.UpdateCardsLayout();
                Tableau9.UpdateCardsLayout();
                Foundation0.UpdateCardsLayout();
                Foundation1.UpdateCardsLayout();
                Foundation2.UpdateCardsLayout();
                Foundation3.UpdateCardsLayout();
                Foundation4.UpdateCardsLayout();
                Foundation5.UpdateCardsLayout();
                Foundation6.UpdateCardsLayout();
                Foundation7.UpdateCardsLayout();
            }
        });
    }

    private IEnumerable<PileView> AllPileViews() =>
        new PileView[] { Tableau0, Tableau1, Tableau2, Tableau3, Tableau4,
            Tableau5, Tableau6, Tableau7, Tableau8, Tableau9,
            Foundation0, Foundation1, Foundation2, Foundation3,
            Foundation4, Foundation5, Foundation6, Foundation7 };

    private void BindPiles(SpiderViewModel vm)
    {
        Foundation0.Pile = vm.Foundations[0];
        Foundation1.Pile = vm.Foundations[1];
        Foundation2.Pile = vm.Foundations[2];
        Foundation3.Pile = vm.Foundations[3];
        Foundation4.Pile = vm.Foundations[4];
        Foundation5.Pile = vm.Foundations[5];
        Foundation6.Pile = vm.Foundations[6];
        Foundation7.Pile = vm.Foundations[7];

        Tableau0.Pile = vm.Tableaus[0];
        Tableau1.Pile = vm.Tableaus[1];
        Tableau2.Pile = vm.Tableaus[2];
        Tableau3.Pile = vm.Tableaus[3];
        Tableau4.Pile = vm.Tableaus[4];
        Tableau5.Pile = vm.Tableaus[5];
        Tableau6.Pile = vm.Tableaus[6];
        Tableau7.Pile = vm.Tableaus[7];
        Tableau8.Pile = vm.Tableaus[8];
        Tableau9.Pile = vm.Tableaus[9];
    }

    private void UpdateStockDisplay(SpiderViewModel vm)
    {
        int remaining = vm.StockPiles.Count;

        // Remove old card views from the canvas
        var toRemove = SpiderStockCanvas.Children.OfType<CardView>().ToList();
        foreach (var cv in toRemove)
            SpiderStockCanvas.Children.Remove(cv);

        SpiderStockEmptyOutline.IsVisible = (remaining == 0);
        SpiderStockOverlay.Cursor = remaining > 0
            ? new Cursor(StandardCursorType.Hand)
            : new Cursor(StandardCursorType.Arrow);

        if (remaining == 0) return;

        int stackCount = Math.Min(remaining, 5);
        var dummyCard = new Card("__stock__", CardSuit.Spades, 0, false);

        for (int i = 0; i < stackCount; i++)
        {
            var cv = new CardView { IsHitTestVisible = false };
            if (i == stackCount - 1) cv.IsAnimated = true; // top card only
            cv.Card = dummyCard;
            Avalonia.Controls.Canvas.SetLeft(cv, 0);
            Avalonia.Controls.Canvas.SetTop(cv, i * 4);
            SpiderStockCanvas.Children.Add(cv);
        }
    }

    private void StockButton_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (DataContext is not SpiderViewModel vm) return;
        if (!vm.CanDealFromStock) return;
        vm.DealFromStock();
        SoundService.PlayShuffle();
        e.Handled = true;
    }

    private bool _winTriggered;

    private void TriggerVictoryCascade()
    {
        if (_winTriggered) return;
        _winTriggered = true;
        VictoryOverlay.IsVisible = true;
        if (DataContext is SpiderViewModel vm)
            VictoryOverlay.StartAnimation(vm.Foundations, vm.ScoreDisplay, vm.TimeDisplay);
        else
            VictoryOverlay.StartAnimation();
        SoundService.PlayVictory();
    }

    private void NoMovesNewGame_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not SpiderViewModel vm) return;
        NoMovesBanner.IsVisible = false;
        vm.InitializeGame();
        SoundService.PlayShuffle();
        e.Handled = true;
    }

    private void NoMovesRestart_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not SpiderViewModel vm) return;
        NoMovesBanner.IsVisible = false;
        vm.RestartGame();
        SoundService.PlayShuffle();
        e.Handled = true;
    }

    private static Bitmap? _ffEmblemBitmap;

    private void ApplyFeltColor(GameOptions options)
    {
        if (VignetteRect != null) VignetteRect.IsVisible = options.IsVignetteEnabled;
        if (options.IsFinalFantasyMode)
        {
            try
            {
                _ffEmblemBitmap ??= new Bitmap(AssetLoader.Open(new Uri("avares://SoliBee.Desktop/Assets/ff7-emblem.png")));
                BoardFeltGrid.Background = new ImageBrush(_ffEmblemBitmap)
                {
                    Stretch = Stretch.Uniform,
                    AlignmentX = AlignmentX.Center,
                    AlignmentY = AlignmentY.Center,
                    TileMode = TileMode.None,
                    DestinationRect = new RelativeRect(0.05, 0.55, 0.9, 0.45, RelativeUnit.Relative)
                };
            }
            catch { BoardFeltGrid.Background = new SolidColorBrush(Avalonia.Media.Colors.Black); }
            return;
        }

        string hexColor = options.FeltColor switch
        {
            FeltColorTheme.FeltGreen => "#008000",
            FeltColorTheme.Crimson => "#8C0C26",
            FeltColorTheme.RoyalBlue => "#1A3380",
            FeltColorTheme.Charcoal => "#2E2E2E",
            FeltColorTheme.Desert => "#C2967A",
            FeltColorTheme.Custom => options.CustomFeltColorHex,
            _ => "#008000"
        };
        try { BoardFeltGrid.Background = new SolidColorBrush(Avalonia.Media.Color.Parse(hexColor)); }
        catch { BoardFeltGrid.Background = new SolidColorBrush(Avalonia.Media.Colors.DarkGreen); }
    }
}
