using System;
using System.Collections.Generic;
using System.ComponentModel;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Threading;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using SoliBee.Desktop.Services;

namespace SoliBee.Desktop.Views;

public partial class GameView : CardGameView
{
    public override bool CanMoveCards(List<Card> cards, Pile targetPile)
    {
        if (DataContext is not GameViewModel vm || cards.Count == 0) return false;
        return vm.CanMoveCard(cards[0], targetPile);
    }

    public override bool TryMoveCards(List<Card> cards, Pile sourcePile, Pile targetPile)
    {
        if (DataContext is not GameViewModel vm || cards.Count == 0) return false;
        if (!vm.CanMoveCard(cards[0], targetPile)) return false;
        vm.MoveCard(cards[0], targetPile);
        SoundService.PlaySnap();
        return true;
    }

    public override bool TryAutoMoveToFoundation(Card card, Pile sourcePile)
    {
        if (DataContext is not GameViewModel vm) return false;
        foreach (var f in vm.Foundations)
        {
            if (vm.CanMoveCard(card, f))
            {
                vm.MoveCard(card, f);
                SoundService.PlaySnap();
                return true;
            }
        }
        return false;
    }

    public GameView()
    {
        InitializeComponent();
        
        this.Loaded += GameView_Loaded;
        this.Unloaded += GameView_Unloaded;

        // WeakReferenceMessenger registration for options synchronization
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            ApplyFeltColor(m.Options);
            UpdateAllPilesLayout();
        });

        WeakReferenceMessenger.Default.Register<FaceCardArtChangedMessage>(this, (r, m) =>
            Dispatcher.UIThread.InvokeAsync(UpdateAllPilesLayout));
    }

    private void GameView_Loaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is GameViewModel vm)
        {
            vm.PropertyChanged += ViewModel_PropertyChanged;
            ApplyFeltColor(vm.Options);
            BindPiles(vm);
        }
    }

    private void GameView_Unloaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is GameViewModel vm)
            vm.PropertyChanged -= ViewModel_PropertyChanged;
        WeakReferenceMessenger.Default.Unregister<OptionsChangedMessage>(this);
    }

    private void ViewModel_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        Avalonia.Threading.Dispatcher.UIThread.InvokeAsync(() =>
        {
            if (e.PropertyName == nameof(GameViewModel.State))
            {
                _winTriggered = false;
                if (DataContext is GameViewModel vm && vm.State.HasWon)
                    TriggerVictoryCascade();
            }
            else if (e.PropertyName == nameof(GameViewModel.Stock))
            {
                StockPileControl.UpdateCardsLayout();
            }
            else if (e.PropertyName == nameof(GameViewModel.Waste))
            {
                WastePileControl.UpdateCardsLayout();
            }
            else if (e.PropertyName == "Foundations")
            {
                Foundation0.UpdateCardsLayout();
                Foundation1.UpdateCardsLayout();
                Foundation2.UpdateCardsLayout();
                Foundation3.UpdateCardsLayout();
                if (DataContext is GameViewModel vm && vm.State.HasWon) TriggerVictoryCascade();
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
                if (DataContext is GameViewModel vm && vm.State.HasWon) TriggerVictoryCascade();
            }
            else if (e.PropertyName == nameof(GameViewModel.HasNoMoves))
            {
                if (DataContext is GameViewModel vm) NoMovesBanner.IsVisible = vm.HasNoMoves;
            }
        });
    }

    private void BindPiles(GameViewModel vm)
    {
        StockPileControl.Pile = vm.Stock;
        WastePileControl.Pile = vm.Waste;

        Foundation0.Pile = vm.Foundations[0];
        Foundation1.Pile = vm.Foundations[1];
        Foundation2.Pile = vm.Foundations[2];
        Foundation3.Pile = vm.Foundations[3];

        Tableau0.Pile = vm.Tableaus[0];
        Tableau1.Pile = vm.Tableaus[1];
        Tableau2.Pile = vm.Tableaus[2];
        Tableau3.Pile = vm.Tableaus[3];
        Tableau4.Pile = vm.Tableaus[4];
        Tableau5.Pile = vm.Tableaus[5];
        Tableau6.Pile = vm.Tableaus[6];
    }

    private static Bitmap? _ffEmblemBitmap;
    private bool _winTriggered;

    private void ApplyFeltColor(GameOptions options)
    {
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
        try { BoardFeltGrid.Background = new SolidColorBrush(Color.Parse(hexColor)); }
        catch { BoardFeltGrid.Background = new SolidColorBrush(Colors.DarkGreen); }
    }

    private void StockPileControl_Clicked(object? sender, EventArgs e)
    {
        if (DataContext is GameViewModel vm)
        {
            vm.DrawCard();
            SoundService.PlayShuffle();
        }
    }

    private void UpdateAllPilesLayout()
    {
        StockPileControl.UpdateCardsLayout();
        WastePileControl.UpdateCardsLayout();
        
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
    }

    private void TriggerVictoryCascade()
    {
        if (_winTriggered) return;
        _winTriggered = true;
        VictoryOverlay.IsVisible = true;
        VictoryOverlay.StartAnimation();
        SoundService.PlayVictory();
    }

}
