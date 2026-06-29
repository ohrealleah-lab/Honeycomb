using System;
using System.Collections.Generic;
using System.ComponentModel;
using Avalonia;
using Avalonia.Controls;
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

public partial class FreecellView : CardGameView
{
    public override bool CanMoveCards(List<Card> cards, Pile targetPile)
    {
        if (DataContext is not FreecellViewModel vm) return false;
        return vm.CanMoveCards(cards, targetPile);
    }

    public override bool TryMoveCards(List<Card> cards, Pile sourcePile, Pile targetPile)
    {
        if (DataContext is not FreecellViewModel vm) return false;
        if (!vm.CanMoveCards(cards, targetPile)) return false;
        vm.MoveCards(cards, sourcePile, targetPile);
        SoundService.PlaySnap();
        return true;
    }

    public override bool TryAutoMoveToFoundation(Card card, Pile sourcePile)
    {
        if (DataContext is not FreecellViewModel vm) return false;
        var single = new List<Card> { card };
        foreach (var f in vm.Foundations)
        {
            if (vm.CanMoveCards(single, f))
            {
                vm.MoveCards(single, sourcePile, f);
                SoundService.PlaySnap();
                return true;
            }
        }
        foreach (var fc in vm.FreeCells)
        {
            if (vm.CanMoveCards(single, fc))
            {
                vm.MoveCards(single, sourcePile, fc);
                SoundService.PlaySnap();
                return true;
            }
        }
        return false;
    }

    public FreecellView()
    {
        InitializeComponent();
        this.Loaded += FreecellView_Loaded;
        this.Unloaded += FreecellView_Unloaded;

        WeakReferenceMessenger.Default.Register<FaceCardArtChangedMessage>(this, (r, m) =>
            Dispatcher.UIThread.InvokeAsync(RefreshAllPiles));
    }

    private void RefreshAllPiles()
    {
        FreeCell0.UpdateCardsLayout(); FreeCell1.UpdateCardsLayout();
        FreeCell2.UpdateCardsLayout(); FreeCell3.UpdateCardsLayout();
        Foundation0.UpdateCardsLayout(); Foundation1.UpdateCardsLayout();
        Foundation2.UpdateCardsLayout(); Foundation3.UpdateCardsLayout();
        Tableau0.UpdateCardsLayout(); Tableau1.UpdateCardsLayout();
        Tableau2.UpdateCardsLayout(); Tableau3.UpdateCardsLayout();
        Tableau4.UpdateCardsLayout(); Tableau5.UpdateCardsLayout();
        Tableau6.UpdateCardsLayout(); Tableau7.UpdateCardsLayout();
    }

    private void FreecellView_Loaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is FreecellViewModel vm)
        {
            vm.PropertyChanged += ViewModel_PropertyChanged;
            ApplyFeltColor(vm.Options);
            BindPiles(vm);
        }
        VictoryOverlay.PlayAgainRequested += VictoryOverlay_PlayAgainRequested;
    }

    private void FreecellView_Unloaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is FreecellViewModel vm)
            vm.PropertyChanged -= ViewModel_PropertyChanged;
        VictoryOverlay.PlayAgainRequested -= VictoryOverlay_PlayAgainRequested;
    }

    private void VictoryOverlay_PlayAgainRequested(object? sender, EventArgs e)
    {
        if (DataContext is FreecellViewModel vm) vm.InitializeGame();
    }

    private void ViewModel_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        Avalonia.Threading.Dispatcher.UIThread.InvokeAsync(() =>
        {
            if (DataContext is not FreecellViewModel vm) return;

            if (e.PropertyName == nameof(FreecellViewModel.State))
            {
                BindPiles(vm);
                RefreshAllPiles();

                if (vm.State.HasWon) TriggerVictoryCascade();
                else
                {
                    _winTriggered = false;
                    VictoryOverlay.StopAnimation();
                    VictoryOverlay.IsVisible = false;
                }
            }
            else if (e.PropertyName == "FreeCells")
            {
                FreeCell0.UpdateCardsLayout();
                FreeCell1.UpdateCardsLayout();
                FreeCell2.UpdateCardsLayout();
                FreeCell3.UpdateCardsLayout();
                if (vm.State.HasWon) TriggerVictoryCascade();
            }
            else if (e.PropertyName == "Foundations")
            {
                Foundation0.UpdateCardsLayout();
                Foundation1.UpdateCardsLayout();
                Foundation2.UpdateCardsLayout();
                Foundation3.UpdateCardsLayout();
                if (vm.State.HasWon) TriggerVictoryCascade();
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
            }
            else if (e.PropertyName == nameof(FreecellViewModel.Options))
            {
                ApplyFeltColor(vm.Options);
                FreeCell0.UpdateCardsLayout();
                FreeCell1.UpdateCardsLayout();
                FreeCell2.UpdateCardsLayout();
                FreeCell3.UpdateCardsLayout();
                Foundation0.UpdateCardsLayout();
                Foundation1.UpdateCardsLayout();
                Foundation2.UpdateCardsLayout();
                Foundation3.UpdateCardsLayout();
                Tableau0.UpdateCardsLayout();
                Tableau1.UpdateCardsLayout();
                Tableau2.UpdateCardsLayout();
                Tableau3.UpdateCardsLayout();
                Tableau4.UpdateCardsLayout();
                Tableau5.UpdateCardsLayout();
                Tableau6.UpdateCardsLayout();
                Tableau7.UpdateCardsLayout();
            }
            else if (e.PropertyName == nameof(FreecellViewModel.HasNoMoves))
            {
                NoMovesBanner.IsVisible = vm.HasNoMoves;
            }
            else if (e.PropertyName == nameof(FreecellViewModel.ActiveHint))
            {
                ApplyHint(vm.ActiveHint, AllPileViews());
            }
        });
    }

    private IEnumerable<PileView> AllPileViews() =>
        new PileView[] { FreeCell0, FreeCell1, FreeCell2, FreeCell3,
            Foundation0, Foundation1, Foundation2, Foundation3,
            Tableau0, Tableau1, Tableau2, Tableau3, Tableau4, Tableau5, Tableau6, Tableau7 };

    private void BindPiles(FreecellViewModel vm)
    {
        if (vm.FreeCells.Count >= 4)
        {
            FreeCell0.Pile = vm.FreeCells[0];
            FreeCell1.Pile = vm.FreeCells[1];
            FreeCell2.Pile = vm.FreeCells[2];
            FreeCell3.Pile = vm.FreeCells[3];
        }
        if (vm.Foundations.Count >= 4)
        {
            Foundation0.Pile = vm.Foundations[0];
            Foundation1.Pile = vm.Foundations[1];
            Foundation2.Pile = vm.Foundations[2];
            Foundation3.Pile = vm.Foundations[3];
        }
        if (vm.Tableaus.Count >= 8)
        {
            Tableau0.Pile = vm.Tableaus[0];
            Tableau1.Pile = vm.Tableaus[1];
            Tableau2.Pile = vm.Tableaus[2];
            Tableau3.Pile = vm.Tableaus[3];
            Tableau4.Pile = vm.Tableaus[4];
            Tableau5.Pile = vm.Tableaus[5];
            Tableau6.Pile = vm.Tableaus[6];
            Tableau7.Pile = vm.Tableaus[7];
        }
    }

    private bool _winTriggered;

    private void TriggerVictoryCascade()
    {
        if (_winTriggered) return;
        _winTriggered = true;
        VictoryOverlay.IsVisible = true;
        if (DataContext is FreecellViewModel vm)
            VictoryOverlay.StartAnimation(vm.Foundations, vm.ScoreDisplay, vm.TimeDisplay);
        else
            VictoryOverlay.StartAnimation();
        SoundService.PlayVictory();
    }

    private void NoMovesNewGame_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not FreecellViewModel vm) return;
        NoMovesBanner.IsVisible = false;
        vm.InitializeGame();
        SoundService.PlayShuffle();
        e.Handled = true;
    }

    private void NoMovesRestart_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not FreecellViewModel vm) return;
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
            catch { BoardFeltGrid.Background = new SolidColorBrush(Colors.Black); }
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
