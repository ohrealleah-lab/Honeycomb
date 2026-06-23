#if WINDOWS
using System;
using System.ComponentModel;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using SoliBee.Desktop.Services;

namespace SoliBee.Desktop.Views;

public partial class GameView : UserControl
{
    public GameView()
    {
        this.InitializeComponent();
        this.Loaded += GameView_Loaded;
        this.Unloaded += GameView_Unloaded;

        // WeakReferenceMessenger registration for options synchronization
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            ApplyFeltColor(m.Options.FeltColor);
        });
    }

    private void GameView_Loaded(object sender, RoutedEventArgs e)
    {
        if (DataContext is GameViewModel vm)
        {
            vm.PropertyChanged += ViewModel_PropertyChanged;
            ApplyFeltColor(vm.Options.FeltColor);
            BindPiles(vm);
        }
    }

    private void GameView_Unloaded(object sender, RoutedEventArgs e)
    {
        if (DataContext is GameViewModel vm)
        {
            vm.PropertyChanged -= ViewModel_PropertyChanged;
        }
    }

    private void ViewModel_PropertyChanged(object sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(GameViewModel.State))
        {
            if (DataContext is GameViewModel vm && vm.State.HasWon)
            {
                TriggerVictoryCascade();
            }
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
        var hexColor = feltColor switch
        {
            FeltColorTheme.FeltGreen => "#0F5A1C",
            FeltColorTheme.Crimson => "#7A1C1C",
            FeltColorTheme.RoyalBlue => "#1C3D7A",
            FeltColorTheme.Charcoal => "#2E2E2E",
            FeltColorTheme.Desert => "#C2A26B", // Tan sand Desert theme
            _ => "#4E3629" // Custom dark brown felt
        };

        try
        {
            var color = (Windows.UI.Color)Microsoft.UI.ColorHelper.FromArgb(
                255,
                Convert.ToByte(hexColor.Substring(1, 2), 16),
                Convert.ToByte(hexColor.Substring(3, 2), 16),
                Convert.ToByte(hexColor.Substring(5, 2), 16)
            );
            BoardFeltGrid.Background = new SolidColorBrush(color);
        }
        catch
        {
            // Default Green Felt if parse fails
            BoardFeltGrid.Background = new SolidColorBrush(Colors.DarkGreen);
        }
    }

    private void StockPileControl_Clicked(object sender, EventArgs e)
    {
        if (DataContext is GameViewModel vm)
        {
            vm.DrawCard();
            SoundService.PlayShuffle();
        }
    }

    private void TriggerVictoryCascade()
    {
        VictoryOverlay.Visibility = Visibility.Visible;
        VictoryOverlay.StartAnimation();
        SoundService.PlayVictory();
    }
}
#else
namespace SoliBee.Desktop.Views;

public class GameView
{
    // Dummy class for non-Windows compilation
}
#endif
