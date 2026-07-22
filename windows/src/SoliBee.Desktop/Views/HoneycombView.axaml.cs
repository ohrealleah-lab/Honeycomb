using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Threading;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;

namespace SoliBee.Desktop.Views;

public partial class HoneycombView : UserControl
{
    private HoneycombViewModel? _vm;
    private int _selectedHandIndex = -1;
    private bool _isStealingCard = false;
    private int? _stealBoardIndex = null;
    
    private Point? _dragStartPoint;
    private bool _isDragging;

    private readonly Border[] _boardCells = new Border[9];
    private readonly HoneycombCardView[] _boardCards = new HoneycombCardView[9];
    
    private readonly HoneycombCardView[] _playerHandViews;
    private readonly HoneycombCardView[] _opponentHandViews;

    public HoneycombView()
    {
        InitializeComponent();

        _playerHandViews = new[] { PlayerHand0, PlayerHand1, PlayerHand2, PlayerHand3, PlayerHand4 };
        _opponentHandViews = new[] { OpponentHand0, OpponentHand1, OpponentHand2, OpponentHand3, OpponentHand4 };

        for (int i = 0; i < 5; i++)
        {
            _playerHandViews[i].OnCardClicked += HandCard_Clicked;
            _opponentHandViews[i].OnCardClicked += HandCard_Clicked;
        }

        for (int i = 0; i < 9; i++)
        {
            var cellBorder = new Border
            {
                Background = new SolidColorBrush(Color.Parse("#20000000")),
                CornerRadius = new Avalonia.CornerRadius(8),
                Margin = new Avalonia.Thickness(4),
                Tag = i
            };
            cellBorder.PointerPressed += Cell_PointerPressed;
            Grid.SetRow(cellBorder, i / 3);
            Grid.SetColumn(cellBorder, i % 3);
            BoardGrid.Children.Add(cellBorder);
            _boardCells[i] = cellBorder;

            var cardView = new HoneycombCardView
            {
                Margin = new Avalonia.Thickness(4),
                IsHitTestVisible = true // Changed to allow pointer events on board cards for Steal flow
            };
            Grid.SetRow(cardView, i / 3);
            Grid.SetColumn(cardView, i % 3);
            BoardGrid.Children.Add(cardView);
            _boardCards[i] = cardView;
        }

        SetupDragAndDrop();

        Loaded += (s, e) =>
        {
            _vm = DataContext as HoneycombViewModel;
            if (_vm != null)
            {
                _vm.PropertyChanged += Vm_PropertyChanged;
                Refresh(_vm);
            }
        };
    }

    private void Vm_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        Dispatcher.UIThread.Post(() => { if (_vm != null) Refresh(_vm); });
    }

    private async void Refresh(HoneycombViewModel vm)
    {
        var state = vm.State;
        
        OverlayPanel.IsVisible = !vm.IsPlaying;
        if (!vm.IsPlaying)
        {
            if (state.Phase == HoneycombPhase.PreMatch)
            {
                OverlayTitle.Text = "Honeycomb";
                OverlaySubtitle.Text = "Ready to play?";
                StartMatchButton.IsVisible = true;
            }
            else if (state.Phase == HoneycombPhase.Result)
            {
                OverlayTitle.Text = state.PlayerScore > state.OpponentScore ? "Victory!" : (state.PlayerScore < state.OpponentScore ? "Defeat..." : "Draw");
                OverlaySubtitle.Text = $"Final Score: {state.PlayerScore} - {state.OpponentScore}";
                StartMatchButton.IsVisible = true;
                StartMatchButton.Content = "Play Again";
            }
        }
        else
        {
            PlayerScoreText.Text = CountPlayerCards(state).ToString();
            OpponentScoreText.Text = CountOpponentCards(state).ToString();
            
            if (state.Phase == HoneycombPhase.Result)
            {
                // Show Steal Card button if they haven't stolen, and card bank isn't full, and not no-stress
                var globalOpts = SoliBee.Core.Services.SettingsService.LoadOptions();
                bool canSteal = !globalOpts.IsNoStressMode && !state.HasStolenThisMatch;
                if (canSteal)
                {
                    // Check if bank full
                    bool bankFull = false;
                    int maxCap = 74; // Assuming 74 total cards in DB
                    if (HoneycombProfileManager.Shared.UnlockedCardIds.Count >= maxCap)
                        bankFull = true;
                        
                    StealCardButton.IsVisible = !bankFull;
                    BankFullWarningText.IsVisible = bankFull;
                }
                else
                {
                    StealCardButton.IsVisible = false;
                    BankFullWarningText.IsVisible = false;
                }
            }
        }
        
        StealInstructionBar.IsVisible = _isStealingCard;
        OverlayPanel.IsVisible = !vm.IsPlaying && !_isStealingCard;
        
        if (vm.PendingSwap != null)
        {
            SwapConfirmationPanel.IsVisible = true;
            SwapConfirmationText.Text = $"Trade {vm.PendingSwap.OutgoingCardName} for {vm.PendingSwap.IncomingCardName}?";
            if (!string.IsNullOrEmpty(vm.SwapValidationError))
            {
                SwapErrorText.IsVisible = true;
                SwapErrorText.Text = vm.SwapValidationError;
            }
            else
            {
                SwapErrorText.IsVisible = false;
            }
        }
        else
        {
            SwapConfirmationPanel.IsVisible = false;
        }

        for (int i = 0; i < 5; i++)
        {
            if (i < state.PlayerHand.Count)
            {
                bool hidden = !state.ActiveRules.Contains(HoneycombRule.AllOpen) 
                              && !state.PlayerRevealedIds.Contains(state.PlayerHand[i].UniqueInstanceId);
                await _playerHandViews[i].RenderCard(state.PlayerHand[i], faceDown: false, hIdx: i, cIdx: -1);
                
                // Highlight if selected
                _playerHandViews[i].Opacity = (i == _selectedHandIndex) ? 0.7 : 1.0;
            }
            else
            {
                await _playerHandViews[i].RenderCard(null);
            }

            if (i < state.OpponentHand.Count)
            {
                bool hidden = !state.ActiveRules.Contains(HoneycombRule.AllOpen) 
                              && !state.OpponentRevealedIds.Contains(state.OpponentHand[i].UniqueInstanceId);
                // In a real game, AI cards are hidden unless revealed. The spec says All Open / Three Open reveals symmetrically.
                // For now, render faceDown if hidden.
                await _opponentHandViews[i].RenderCard(state.OpponentHand[i], faceDown: hidden, hIdx: i, cIdx: -1);
            }
            else
            {
                await _opponentHandViews[i].RenderCard(null);
            }
        }

        for (int i = 0; i < 9; i++)
        {
            var cell = state.Board.Cells[i];
            if (cell.IsEmpty)
            {
                await _boardCards[i].RenderCard(null);
                
                // Highlight Hint if applicable
                if (vm.ActiveHint.HasValue && vm.ActiveHint.Value.cellIndex == i)
                    _boardCells[i].Background = new SolidColorBrush(Color.Parse("#80FFFF00"));
                else
                    _boardCells[i].Background = new SolidColorBrush(Color.Parse("#20000000"));
            }
            else
            {
                await _boardCards[i].RenderCard(cell.Card, faceDown: false, hIdx: -1, cIdx: i);
                
                // Highlight if selected for Stealing
                if (_isStealingCard && _stealBoardIndex == i)
                    _boardCells[i].Background = new SolidColorBrush(Color.Parse("#80FFFFFF"));
            }
        }
        
        PlayerTurnIndicator.IsVisible = vm.IsPlaying && state.CurrentTurn == 1;
        OpponentTurnIndicator.IsVisible = vm.IsPlaying && state.CurrentTurn == -1;
        
        UndoButton.IsEnabled = vm.CanUndo;
    }

    private int CountPlayerCards(HoneycombState state)
    {
        int total = state.PlayerHand.Count;
        for (int i=0; i<9; i++)
            if (!state.Board.Cells[i].IsEmpty && state.Board.Cells[i].Card!.Owner == 1) total++;
        return total;
    }

    private int CountOpponentCards(HoneycombState state)
    {
        int total = state.OpponentHand.Count;
        for (int i=0; i<9; i++)
            if (!state.Board.Cells[i].IsEmpty && state.Board.Cells[i].Card!.Owner == -1) total++;
        return total;
    }

    private void HandCard_Clicked(object? sender, (int handIndex, int cellIndex) args)
    {
        if (_vm == null) return;
        
        if (_vm.IsPlaying && _vm.State.CurrentTurn == 1)
        {
            if (args.handIndex >= 0 && args.cellIndex == -1)
            {
                if (_playerHandViews.Contains(sender))
                {
                    _selectedHandIndex = args.handIndex;
                    Refresh(_vm);
                }
            }
        }
        else if (_isStealingCard && _vm.State.Phase == HoneycombPhase.Result)
        {
            if (args.handIndex >= 0 && args.cellIndex == -1 && _playerHandViews.Contains(sender))
            {
                if (_stealBoardIndex.HasValue)
                {
                    _vm.RequestSwap(_stealBoardIndex.Value, args.handIndex);
                    Refresh(_vm);
                }
            }
        }
    }

    private void Cell_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (_vm == null) return;
        
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed && sender is Border b && b.Tag is int cellIndex)
        {
            if (_vm.IsPlaying && _vm.State.CurrentTurn == 1)
            {
                if (_selectedHandIndex >= 0)
                {
                    _vm.PlayCard(_selectedHandIndex, cellIndex);
                    _selectedHandIndex = -1;
                }
            }
        }
    }

    private void BoardCard_Clicked(object? sender, PointerPressedEventArgs e)
    {
        if (_vm == null) return;
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed && sender is HoneycombCardView cardView)
        {
            int cellIndex = Array.IndexOf(_boardCards, cardView);
            if (cellIndex >= 0)
            {
                if (_isStealingCard && _vm.State.Phase == HoneycombPhase.Result)
                {
                    _stealBoardIndex = cellIndex;
                    Refresh(_vm);
                }
            }
        }
    }

    private void StartMatch_Click(object? sender, RoutedEventArgs e)
    {
        _vm?.StartNewMatch();
    }

    private void Quit_Click(object? sender, RoutedEventArgs e)
    {
        // Go back to main menu or something
    }

    private void Undo_Click(object? sender, RoutedEventArgs e)
    {
        _vm?.Undo();
    }

    private void Hint_Click(object? sender, RoutedEventArgs e)
    {
        _vm?.FindHint();
    }
    
    private void StealCard_Click(object? sender, RoutedEventArgs e)
    {
        _isStealingCard = true;
        _stealBoardIndex = null;
        if (_vm != null) Refresh(_vm);
    }
    
    private void CancelSteal_Click(object? sender, RoutedEventArgs e)
    {
        _isStealingCard = false;
        _stealBoardIndex = null;
        if (_vm != null) Refresh(_vm);
    }
    
    private void ConfirmSwap_Click(object? sender, RoutedEventArgs e)
    {
        _vm?.ConfirmPendingSwap();
        _isStealingCard = false;
        _stealBoardIndex = null;
        if (_vm != null) Refresh(_vm);
    }
    
    private void CancelSwap_Click(object? sender, RoutedEventArgs e)
    {
        _vm?.CancelPendingSwap();
        if (_vm != null) Refresh(_vm);
    }

    private void SetupDragAndDrop()
    {
        foreach (var hv in _playerHandViews)
        {
            hv.PointerPressed += Drag_PointerPressed;
            hv.PointerMoved += Drag_PointerMoved;
            DragDrop.SetAllowDrop(hv, true);
            hv.AddHandler(DragDrop.DragOverEvent, HandSlot_DragOver);
            hv.AddHandler(DragDrop.DropEvent, HandSlot_Drop);
        }

        foreach (var cell in _boardCells)
        {
            DragDrop.SetAllowDrop(cell, true);
            cell.AddHandler(DragDrop.DragOverEvent, BoardCell_DragOver);
            cell.AddHandler(DragDrop.DropEvent, BoardCell_Drop);
        }
        
        foreach (var bc in _boardCards)
        {
            bc.PointerPressed += Drag_PointerPressed;
            bc.PointerMoved += Drag_PointerMoved;
            bc.PointerPressed += BoardCard_Clicked;
        }
    }

    private void Drag_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        {
            _dragStartPoint = e.GetPosition(this);
            _isDragging = true;
        }
    }

    private async void Drag_PointerMoved(object? sender, PointerEventArgs e)
    {
        if (_isDragging && _dragStartPoint.HasValue)
        {
            var p = e.GetPosition(this);
            if (Math.Abs(p.X - _dragStartPoint.Value.X) > 3 || Math.Abs(p.Y - _dragStartPoint.Value.Y) > 3)
            {
                _isDragging = false;
                if (_vm == null) return;

                if (sender is HoneycombCardView hv && _playerHandViews.Contains(hv))
                {
                    int handIdx = Array.IndexOf(_playerHandViews, hv);
                    if (handIdx >= 0 && _vm.IsPlaying && _vm.State.CurrentTurn == 1)
                    {
                        var data = new DataObject();
                        data.Set("HandIndex", handIdx);
                        await DragDrop.DoDragDrop(e, data, DragDropEffects.Move);
                    }
                }
                else if (sender is HoneycombCardView bc && _boardCards.Contains(bc))
                {
                    int cellIdx = Array.IndexOf(_boardCards, bc);
                    if (cellIdx >= 0 && _isStealingCard && _vm.State.Phase == HoneycombPhase.Result)
                    {
                        var data = new DataObject();
                        data.Set("StealBoardIndex", cellIdx);
                        await DragDrop.DoDragDrop(e, data, DragDropEffects.Link);
                    }
                }
            }
        }
    }

    private void BoardCell_DragOver(object? sender, DragEventArgs e)
    {
        if (e.Data.Contains("HandIndex") && sender is Border)
            e.DragEffects = DragDropEffects.Move;
        else
            e.DragEffects = DragDropEffects.None;
    }

    private void BoardCell_Drop(object? sender, DragEventArgs e)
    {
        if (_vm != null && e.Data.Contains("HandIndex") && sender is Border b && b.Tag is int cellIdx)
        {
            if (e.Data.Get("HandIndex") is int handIdx)
            {
                if (_vm.IsPlaying && _vm.State.CurrentTurn == 1)
                {
                    _vm.PlayCard(handIdx, cellIdx);
                }
            }
        }
    }

    private void HandSlot_DragOver(object? sender, DragEventArgs e)
    {
        if (e.Data.Contains("StealBoardIndex") && sender is HoneycombCardView)
            e.DragEffects = DragDropEffects.Link;
        else
            e.DragEffects = DragDropEffects.None;
    }

    private void HandSlot_Drop(object? sender, DragEventArgs e)
    {
        if (_vm != null && e.Data.Contains("StealBoardIndex") && sender is HoneycombCardView hv)
        {
            if (e.Data.Get("StealBoardIndex") is int boardIdx)
            {
                int handIdx = Array.IndexOf(_playerHandViews, hv);
                if (handIdx >= 0 && _isStealingCard && _vm.State.Phase == HoneycombPhase.Result)
                {
                    _vm.RequestSwap(boardIdx, handIdx);
                    Refresh(_vm);
                }
            }
        }
    }
}
