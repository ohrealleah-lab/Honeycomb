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
    // Column gap narrows above 1.0x zoom so columns don't overflow horizontally; floors at 4px.
    public void ApplyZoomGap(double zoom)
    {
        if (DataContext is not FreecellViewModel vm) return;
        const double baseGap = 6;
        double gap = zoom <= 1.0 ? baseGap : Math.Max(4, baseGap - (baseGap - 4) * (zoom - 1.0));
        for (int i = 1; i < TableauGrid.ColumnDefinitions.Count; i += 2)
            TableauGrid.ColumnDefinitions[i] = new ColumnDefinition(gap, GridUnitType.Pixel);

        int deckCount = vm.Options.FreecellDeckCount;
        int columns = deckCount == 2 ? 10 : 8;
        double width = columns * 128 + (columns - 1) * gap;
        BoardPanel.Width = width;
        TopRow1.Width = width;
        TopRow2.Width = width;
        TableauGrid.Width = width;
    }

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

        // Only allow auto-moving the top card of the pile
        if (sourcePile.Cards.Count == 0 || sourcePile.Cards[^1].Id != card.Id)
            return false;

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
        FreeCell4.UpdateCardsLayout(); FreeCell5.UpdateCardsLayout();
        FreeCell6.UpdateCardsLayout(); FreeCell7.UpdateCardsLayout();
        
        Foundation0.UpdateCardsLayout(); Foundation1.UpdateCardsLayout();
        Foundation2.UpdateCardsLayout(); Foundation3.UpdateCardsLayout();
        Foundation4.UpdateCardsLayout(); Foundation5.UpdateCardsLayout();
        Foundation6.UpdateCardsLayout(); Foundation7.UpdateCardsLayout();
        
        Tableau0.UpdateCardsLayout(); Tableau1.UpdateCardsLayout();
        Tableau2.UpdateCardsLayout(); Tableau3.UpdateCardsLayout();
        Tableau4.UpdateCardsLayout(); Tableau5.UpdateCardsLayout();
        Tableau6.UpdateCardsLayout(); Tableau7.UpdateCardsLayout();
        Tableau8.UpdateCardsLayout(); Tableau9.UpdateCardsLayout();
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
        VictoryOverlay.CloseRequested += VictoryOverlay_CloseRequested;
    }

    private void FreecellView_Unloaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is FreecellViewModel vm)
            vm.PropertyChanged -= ViewModel_PropertyChanged;
        VictoryOverlay.PlayAgainRequested -= VictoryOverlay_PlayAgainRequested;
        VictoryOverlay.CloseRequested -= VictoryOverlay_CloseRequested;
        WeakReferenceMessenger.Default.Unregister<FaceCardArtChangedMessage>(this);
        CardView.ClearPileViewCache(this);
    }

    private void VictoryOverlay_PlayAgainRequested(object? sender, EventArgs e)
    {
        if (DataContext is FreecellViewModel vm) vm.InitializeGame();
    }

    private void VictoryOverlay_CloseRequested(object? sender, EventArgs e)
    {
        VictoryOverlay.IsVisible = false;
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
            else if (e.PropertyName == "FreeCells" || e.PropertyName == "Foundations" || e.PropertyName == "Tableaus")
            {
                RefreshAllPiles();
                if (vm.State.HasWon) TriggerVictoryCascade();
            }
            else if (e.PropertyName == nameof(FreecellViewModel.Options))
            {
                ApplyFeltColor(vm.Options);
                BindPiles(vm);
                RefreshAllPiles();
            }
            else if (e.PropertyName == nameof(FreecellViewModel.IsAutocompletable) ||
                     e.PropertyName == nameof(FreecellViewModel.IsAutoplayRunning))
            {
                AutocompleteBanner.IsVisible = vm.IsAutocompletable && !vm.IsAutoplayRunning;
            }
            else if (e.PropertyName == nameof(FreecellViewModel.HasNoMoves))
            {
                if (vm.HasNoMoves) NoMovesStatsLabel.Text = WinAnimationView.FormatStatsLine(vm.ScoreDisplay, vm.TimeDisplay);
                NoMovesBanner.IsVisible = vm.HasNoMoves;
            }
            else if (e.PropertyName == nameof(FreecellViewModel.ActiveHint))
            {
                ApplyHint(vm.ActiveHint, AllPileViews());
            }
        });
    }

    protected override void ClearActiveHint()
    {
        if (DataContext is FreecellViewModel vm) vm.ClearHintCycle();
    }

    private IEnumerable<PileView> AllPileViews() =>
        new PileView[] { 
            FreeCell0, FreeCell1, FreeCell2, FreeCell3, FreeCell4, FreeCell5, FreeCell6, FreeCell7,
            Foundation0, Foundation1, Foundation2, Foundation3, Foundation4, Foundation5, Foundation6, Foundation7,
            Tableau0, Tableau1, Tableau2, Tableau3, Tableau4, Tableau5, Tableau6, Tableau7, Tableau8, Tableau9 
        };

    private void BindPiles(FreecellViewModel vm)
    {
        int deckCount = vm.Options.FreecellDeckCount;
        double width = deckCount == 2 ? 1334 : 1066;

        BoardPanel.Width = width;
        TopRow1.Width = width;
        TopRow2.Width = width;
        TableauGrid.Width = width;

        TopRow2.IsVisible = deckCount == 2;
        Tableau8.IsVisible = deckCount == 2;
        Tableau9.IsVisible = deckCount == 2;

        if (vm.FreeCells.Count >= 4)
        {
            FreeCell0.Pile = vm.FreeCells[0];
            FreeCell1.Pile = vm.FreeCells[1];
            FreeCell2.Pile = vm.FreeCells[2];
            FreeCell3.Pile = vm.FreeCells[3];
        }
        if (deckCount == 2 && vm.FreeCells.Count >= 8)
        {
            FreeCell4.Pile = vm.FreeCells[4];
            FreeCell5.Pile = vm.FreeCells[5];
            FreeCell6.Pile = vm.FreeCells[6];
            FreeCell7.Pile = vm.FreeCells[7];
        }

        if (vm.Foundations.Count >= 4)
        {
            Foundation0.Pile = vm.Foundations[0];
            Foundation1.Pile = vm.Foundations[1];
            Foundation2.Pile = vm.Foundations[2];
            Foundation3.Pile = vm.Foundations[3];
        }
        if (deckCount == 2 && vm.Foundations.Count >= 8)
        {
            Foundation4.Pile = vm.Foundations[4];
            Foundation5.Pile = vm.Foundations[5];
            Foundation6.Pile = vm.Foundations[6];
            Foundation7.Pile = vm.Foundations[7];
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
        if (deckCount == 2 && vm.Tableaus.Count >= 10)
        {
            Tableau8.Pile = vm.Tableaus[8];
            Tableau9.Pile = vm.Tableaus[9];
        }
    }

    private bool _winTriggered;

    private void TriggerVictoryCascade()
    {
        if (_winTriggered) return;
        _winTriggered = true;
        VictoryOverlay.IsVisible = true;
        if (DataContext is FreecellViewModel vm)
            VictoryOverlay.StartAnimation(vm.Foundations, vm.ScoreDisplay, vm.Options.IsTimed ? vm.TimeDisplay : "");
        else
            VictoryOverlay.StartAnimation();
        SoundService.PlaySolitaireWin();
    }

    // Dev-only banner preview, wired to the toolbar's local-only "Banners" dropdown
    // (the dropdown itself is only made visible in DEBUG builds — see MainWindow).
    public void DebugShowWinBanner()
    {
        VictoryOverlay.IsVisible = true;
        if (DataContext is FreecellViewModel vm)
            VictoryOverlay.StartAnimation(vm.Foundations, vm.ScoreDisplay, vm.Options.IsTimed ? vm.TimeDisplay : "");
        else
            VictoryOverlay.StartAnimation();
    }

    public void DebugShowLossBanner()
    {
        if (DataContext is FreecellViewModel vm)
            NoMovesStatsLabel.Text = WinAnimationView.FormatStatsLine(vm.ScoreDisplay, vm.TimeDisplay);
        NoMovesBanner.IsVisible = true;
    }

    public void DebugShowAutocompleteBanner() => AutocompleteBanner.IsVisible = true;

    private void AutocompleteGame_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not FreecellViewModel vm) return;
        AutocompleteBanner.IsVisible = false;
        vm.Autocomplete();
        e.Handled = true;
    }

    private void NoMovesNewGame_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not FreecellViewModel vm) return;
        NoMovesBanner.IsVisible = false;
        AutocompleteBanner.IsVisible = false;
        vm.InitializeGame();
        SoundService.PlayShuffle();
        e.Handled = true;
    }

    private void NoMovesRestart_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not FreecellViewModel vm) return;
        NoMovesBanner.IsVisible = false;
        AutocompleteBanner.IsVisible = false;
        vm.RestartGame();
        SoundService.PlayShuffle();
        e.Handled = true;
    }

    private void NoMovesDismiss_Click(object? sender, RoutedEventArgs e)
    {
        NoMovesBanner.IsVisible = false;
        e.Handled = true;
    }

    private void AutocompleteDismiss_Click(object? sender, RoutedEventArgs e)
    {
        AutocompleteBanner.IsVisible = false;
        e.Handled = true;
    }

    private static Bitmap? _ffEmblemBitmap;

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

        // Transparent, not an opaque repaint: the window background behind (MainWindow.ApplyFeltColor)
        // already carries this same felt color, and staying transparent here lets the single
        // app-wide vignette overlay (rendered behind the board content) show through in the gaps.
        BoardFeltGrid.Background = Brushes.Transparent;
    }
}
