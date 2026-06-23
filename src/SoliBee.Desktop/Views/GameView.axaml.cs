using System;
using System.ComponentModel;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Media;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using SoliBee.Desktop.Services;

namespace SoliBee.Desktop.Views;

public partial class GameView : UserControl
{
    public CardView? SelectedCardView { get; set; }

    public GameView()
    {
        InitializeComponent();
        
        this.Loaded += GameView_Loaded;
        this.Unloaded += GameView_Unloaded;

        // WeakReferenceMessenger registration for options synchronization
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            ApplyFeltColor(m.Options.FeltColor);
            UpdateAllPilesLayout();
        });
    }

    private void GameView_Loaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is GameViewModel vm)
        {
            vm.PropertyChanged += ViewModel_PropertyChanged;
            ApplyFeltColor(vm.Options.FeltColor);
            BindPiles(vm);
        }
    }

    private void GameView_Unloaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is GameViewModel vm)
        {
            vm.PropertyChanged -= ViewModel_PropertyChanged;
        }
    }

    private void ViewModel_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(GameViewModel.State))
        {
            if (DataContext is GameViewModel vm && vm.State.HasWon)
            {
                TriggerVictoryCascade();
            }
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
        }
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

    private void ApplyFeltColor(FeltColorTheme feltColor)
    {
        string hexColor = "#008000";
        if (feltColor == FeltColorTheme.Custom)
        {
            var options = SettingsService.LoadOptions();
            hexColor = options.CustomFeltColorHex;
        }
        else
        {
            hexColor = feltColor switch
            {
                FeltColorTheme.FeltGreen => "#008000",
                FeltColorTheme.Crimson => "#8C0C26",
                FeltColorTheme.RoyalBlue => "#1A3380",
                FeltColorTheme.Charcoal => "#2E2E2E",
                FeltColorTheme.Desert => "#C2967A",
                _ => "#008000"
            };
        }

        try
        {
            BoardFeltGrid.Background = new SolidColorBrush(Color.Parse(hexColor));
        }
        catch
        {
            // Default Green Felt if parse fails
            BoardFeltGrid.Background = new SolidColorBrush(Colors.DarkGreen);
        }
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
        VictoryOverlay.IsVisible = true;
        VictoryOverlay.StartAnimation();
        SoundService.PlayVictory();
    }

}
