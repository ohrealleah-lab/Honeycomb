using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Threading;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using SoliBee.Desktop.Services;
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
    private bool _overlayDismissed = false;
    private bool _showRematchPrompt = false;
    private bool _bannerActive = false;

    private int _lastEmptyCells = 9;
    private bool _resultSoundPlayed = false;


    // Pointer-capture drag state (same approach as CardView)
    private Point? _dragStartPoint;
    private bool _isDragging;
    private int _dragHandIndex = -1;        // which hand card is being dragged
    private int _dragBoardIndex = -1;       // which board card is being dragged (steal mode)
    private Border? _dragGhost;             // floating ghost card shown during drag
    private Canvas? _dragCanvas;            // top-level overlay canvas

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
                Background = new SolidColorBrush(Color.Parse("#59000000")),
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
        
        RuleToast.OnDismissed += () => {
            _bannerActive = false;
            if (_vm != null) Refresh(_vm);
        };

        Loaded += (s, e) =>
        {
            _vm = DataContext as HoneycombViewModel;
            if (_vm != null)
            {
                _vm.PropertyChanged += Vm_PropertyChanged;
                _vm.OnFlashBanner += Vm_OnFlashBanner;
                Refresh(_vm);
            }
        };
    }
    
    private void Vm_OnFlashBanner(string message)
    {
        Dispatcher.UIThread.Post(() => {
            _bannerActive = true;
            RuleToast.Flash(message);
        });
    }

    private void Vm_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        Dispatcher.UIThread.Post(() => { if (_vm != null) Refresh(_vm); });
    }

    public async void Refresh(HoneycombViewModel vm)
    {
        var state = vm.State;
        
        if (vm.IsPlaying) 
        {
            _overlayDismissed = false;
            _resultSoundPlayed = false;
        }

        int currentEmptyCells = state.Board.Cells.Count(c => c.IsEmpty);
        if (currentEmptyCells < _lastEmptyCells)
        {
            SoundService.PlaySnap();
        }
        _lastEmptyCells = currentEmptyCells;

        
        OverlayPanel.IsVisible = !vm.IsPlaying && state.Phase == HoneycombPhase.Result && !_isStealingCard && !_overlayDismissed;
        if (!vm.IsPlaying && state.Phase == HoneycombPhase.Result)
        {
            OverlayTitle.IsVisible = true;
            OverlayLoseTitle.IsVisible = false;
            
            if (state.PlayerScore > state.OpponentScore) {
                OverlayTitle.Text = "You Win!";
            } else if (state.PlayerScore < state.OpponentScore) {
                OverlayTitle.IsVisible = false;
                OverlayLoseTitle.IsVisible = true;
            } else {
                OverlayTitle.Text = "Draw";
            }
            OverlaySubtitle.Text = $"Final Score: {state.PlayerScore} - {state.OpponentScore}";

            if (!_resultSoundPlayed)
            {
                _resultSoundPlayed = true;
                if (state.PlayerScore > state.OpponentScore)
                {
                    SoundService.PlaySolitaireWin();
                }
            }
            
            // Show Steal Card button if they haven't stolen, and card bank isn't full, and not no-stress, and they won.
            var globalOpts = SoliBee.Core.Services.SettingsService.LoadOptions();
            bool canSteal = !globalOpts.IsNoStressMode && !state.HasStolenThisMatch && state.PlayerScore > state.OpponentScore;
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
        
        StealInstructionBar.IsVisible = _isStealingCard;
        RulesBannerBar.IsVisible = !_isStealingCard;
        if (_isStealingCard)
        {
            StealInstructionText.Text = _stealBoardIndex.HasValue
                ? "Now tap one of your hand cards to replace it with the stolen card."
                : "Tap an opponent's card on the board to steal it.";
        }
        
        RematchPromptPanel.IsVisible = _showRematchPrompt;
        
        SwapConfirmationPanel.IsVisible = vm.PendingSwap != null || vm.SwapValidationError != null;
        if (vm.SwapValidationError != null)
        {
            SwapErrorText.Text = vm.SwapValidationError;
            SwapErrorText.IsVisible = true;
        }
        else
        {
            SwapErrorText.IsVisible = false;
        }
        
        OverlayPanel.IsVisible = !vm.IsPlaying && state.Phase == HoneycombPhase.Result && !_isStealingCard && !_overlayDismissed && !_showRematchPrompt && !_bannerActive;
        
        var ruleNames = state.ActiveRules.Select(r => 
        {
            var name = System.Text.RegularExpressions.Regex.Replace(r.ToString(), "(\\B[A-Z])", " $1");
            if ((r == HoneycombRule.Ascension || r == HoneycombRule.Descension) && state.Board.AscensionDescensionSuits.Count > 0)
            {
                return $"{name} Suit: {string.Join(", ", state.Board.AscensionDescensionSuits)}";
            }
            return name;
        }).ToList();
        if (ruleNames.Count == 0) ruleNames.Add("Normal");
        RulesList.ItemsSource = ruleNames;
        

        // Render Player Hand
        var displayPlayerHand = state.Phase == HoneycombPhase.Result ? state.PlayerStartingDeck : state.PlayerHand;
        var placeholderData = new HoneycombCardData { Name = "", Stars = 1, Stats = new[] { 1, 1, 1, 1 }, Suit = "S", Id = -1 };
        
        for (int i = 0; i < 5; i++)
        {
            if (state.Phase == HoneycombPhase.PreMatch)
            {
                var pCard = new HoneycombCard(placeholderData, 1);
                await _playerHandViews[i].RenderCard(pCard, faceDown: true, hIdx: i, cIdx: -1);
            }
            else if (i < displayPlayerHand.Count)
            {
                await _playerHandViews[i].RenderCard(displayPlayerHand[i], faceDown: false, hIdx: i, cIdx: -1);
            }
            else
            {
                await _playerHandViews[i].RenderCard(null);
            }
        }

        // Render Opponent Hand
        for (int i = 0; i < 5; i++)
        {
            if (state.Phase == HoneycombPhase.PreMatch)
            {
                var oCard = new HoneycombCard(placeholderData, 2);
                await _opponentHandViews[i].RenderCard(oCard, faceDown: true, hIdx: i, cIdx: -1);
            }
            else if (i < state.OpponentHand.Count)
            {
                bool isPostWinReveal = state.Phase == HoneycombPhase.Result && state.PlayerScore > state.OpponentScore;
                bool hidden = !isPostWinReveal 
                              && !state.ActiveRules.Contains(HoneycombRule.AllOpen) 
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
                    _boardCells[i].Background = new SolidColorBrush(Color.Parse("#59000000"));

                _boardCards[i].StealHighlight = false;
            }
            else
            {
                await _boardCards[i].RenderCard(cell.Card, faceDown: false, hIdx: -1, cIdx: i);
                
                // Highlight if selected for Stealing
                if (_isStealingCard)
                {
                    if (_stealBoardIndex == i)
                    {
                        _boardCells[i].Background = new SolidColorBrush(Color.Parse("#80FFFFFF"));
                        _boardCards[i].StealHighlight = false;
                    }
                    else if (cell.Card != null && cell.Card.OriginalOwner == -1 && cell.Card.Owner == 1 && !HoneycombProfileManager.Shared.UnlockedCardIds.Contains(cell.Card.Data.Id))
                    {
                        _boardCells[i].Background = new SolidColorBrush(Color.Parse("#59000000"));
                        _boardCards[i].StealHighlight = true;
                    }
                    else
                    {
                        _boardCells[i].Background = new SolidColorBrush(Color.Parse("#59000000"));
                        _boardCards[i].StealHighlight = false;
                    }
                }
                else
                {
                    _boardCells[i].Background = new SolidColorBrush(Color.Parse("#59000000"));
                    _boardCards[i].StealHighlight = false;
                }
            }
        }
        
        PlayerTurnIndicator.IsVisible = vm.IsPlaying && state.CurrentTurn == 1;
        OpponentTurnIndicator.IsVisible = vm.IsPlaying && state.CurrentTurn == -1;
        

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
                    var card = _vm.State.Board.Cells[cellIndex].Card;
                    if (card != null && card.OriginalOwner == -1 && card.Owner == 1 && !HoneycombProfileManager.Shared.UnlockedCardIds.Contains(card.Data.Id))
                    {
                        _stealBoardIndex = cellIndex;
                        Refresh(_vm);
                    }
                }
            }
        }
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
        if (_vm != null) {
            _vm.ConfirmPendingSwap();
            _isStealingCard = false;
            _stealBoardIndex = null;
            _showRematchPrompt = true;
            Refresh(_vm);
        }
    }
    
    private void CancelSwap_Click(object? sender, RoutedEventArgs e)
    {
        _vm?.CancelPendingSwap();
        if (_vm != null) Refresh(_vm);
    }

    private void NewGame_Click(object? sender, RoutedEventArgs e)
    {
        _overlayDismissed = false;
        _showRematchPrompt = false;
        _isStealingCard = false;
        _stealBoardIndex = null;
        if (_vm != null) {
            _vm.InitializeGame();
            SoundService.PlayShuffle();
        }
    }

    private void Rematch_Click(object? sender, RoutedEventArgs e)
    {
        _overlayDismissed = false;
        _showRematchPrompt = false;
        _isStealingCard = false;
        _stealBoardIndex = null;
        if (_vm != null) {
            _vm.RestartGame();
            SoundService.PlayShuffle();
        }
    }

    private void CloseOverlay_Click(object? sender, RoutedEventArgs e)
    {
        _overlayDismissed = true;
        OverlayPanel.IsVisible = false;
    }
    
    private void CloseRematchPrompt_Click(object? sender, RoutedEventArgs e)
    {
        _showRematchPrompt = false;
        _overlayDismissed = true;
        if (_vm != null) Refresh(_vm);
    }

    private void RematchPrompt_Rematch_Click(object? sender, RoutedEventArgs e)
    {
        _showRematchPrompt = false;
        if (_vm != null) {
            _vm.RestartGame();
            SoundService.PlayShuffle();
        }
    }

    private void RematchPrompt_NewGame_Click(object? sender, RoutedEventArgs e)
    {
        _showRematchPrompt = false;
        if (_vm != null) {
            _vm.InitializeGame();
            SoundService.PlayShuffle();
        }
    }

    private void SetupDragAndDrop()
    {
        // Player hand cards: pointer-capture drag to board cells
        foreach (var hv in _playerHandViews)
        {
            hv.PointerPressed  += Drag_PointerPressed;
            hv.PointerMoved    += Drag_PointerMoved;
            hv.PointerReleased += Drag_PointerReleased;
        }

        // Board cards: pointer-capture drag to hand slots (steal mode) + click
        foreach (var bc in _boardCards)
        {
            bc.PointerPressed  += Drag_PointerPressed;
            bc.PointerMoved    += Drag_PointerMoved;
            bc.PointerReleased += Drag_PointerReleased;
            bc.PointerPressed  += BoardCard_Clicked;
        }
    }

    private void Drag_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (!e.GetCurrentPoint(this).Properties.IsLeftButtonPressed) return;
        if (_vm == null) return;

        if (sender is HoneycombCardView hv && _playerHandViews.Contains(hv))
        {
            int handIdx = Array.IndexOf(_playerHandViews, hv);
            if (handIdx >= 0 && _vm.IsPlaying && _vm.State.CurrentTurn == 1
                && handIdx < _vm.State.PlayerHand.Count)
            {
                _dragStartPoint = e.GetPosition(this);
                _dragHandIndex  = handIdx;
                _dragBoardIndex = -1;
                _isDragging     = false; // becomes true once we exceed threshold in Moved
                e.Pointer.Capture(hv);
            }
        }
        else if (sender is HoneycombCardView bc && _boardCards.Contains(bc))
        {
            int cellIdx = Array.IndexOf(_boardCards, bc);
            if (cellIdx >= 0 && _isStealingCard && _vm.State.Phase == HoneycombPhase.Result
                && !_vm.State.Board.Cells[cellIdx].IsEmpty
                && _vm.State.Board.Cells[cellIdx].Card?.Owner == 1
                && _vm.State.Board.Cells[cellIdx].Card?.OriginalOwner == -1
                && !HoneycombProfileManager.Shared.UnlockedCardIds.Contains(_vm.State.Board.Cells[cellIdx].Card!.Data.Id))
            {
                _dragStartPoint = e.GetPosition(this);
                _dragBoardIndex = cellIdx;
                _dragHandIndex  = -1;
                _isDragging     = false;
                e.Pointer.Capture(bc);
            }
        }
    }

    private void Drag_PointerMoved(object? sender, PointerEventArgs e)
    {
        if (_dragStartPoint == null) return;

        var pos = e.GetPosition(this);
        double dx = Math.Abs(pos.X - _dragStartPoint.Value.X);
        double dy = Math.Abs(pos.Y - _dragStartPoint.Value.Y);

        // Activate drag once threshold is exceeded
        if (!_isDragging && (dx > 6 || dy > 6))
        {
            _isDragging = true;
            ShowDragGhost(pos);
        }

        if (_isDragging && _dragGhost != null && _dragCanvas != null)
        {
            Canvas.SetLeft(_dragGhost, pos.X - 98);
            Canvas.SetTop (_dragGhost, pos.Y - 138);
        }

        if (_isDragging) e.Handled = true;
    }

    private void Drag_PointerReleased(object? sender, PointerReleasedEventArgs e)
    {
        e.Pointer.Capture(null);

        bool wasDragging = _isDragging;
        _isDragging     = false;
        _dragStartPoint = null;
        HideDragGhost();

        if (!wasDragging || _vm == null) return;

        var dropPos = e.GetPosition(this);

        if (_dragHandIndex >= 0)
        {
            int dropCell = HitTestBoardCell(dropPos);
            if (dropCell >= 0 && _vm.IsPlaying && _vm.State.CurrentTurn == 1)
            {
                _vm.PlayCard(_dragHandIndex, dropCell);
            }
            _dragHandIndex = -1;
        }
        else if (_dragBoardIndex >= 0)
        {
            // Steal mode: dropped on a player hand slot?
            int dropHand = HitTestPlayerHandSlot(dropPos);
            if (dropHand >= 0 && _isStealingCard && _vm.State.Phase == HoneycombPhase.Result)
            {
                _vm.RequestSwap(_dragBoardIndex, dropHand);
                if (_vm != null) Refresh(_vm);
            }
            _dragBoardIndex = -1;
        }
    }

    // Returns the board cell index (0–8) that contains the point, or -1.
    private int HitTestBoardCell(Point p)
    {
        for (int i = 0; i < 9; i++)
        {
            var origin = _boardCells[i].TranslatePoint(new Point(0, 0), this);
            if (!origin.HasValue) continue;
            var r = new Rect(origin.Value, _boardCells[i].Bounds.Size);
            if (r.Contains(p)) return i;
        }
        return -1;
    }

    // Returns the player hand slot index (0–4) that contains the point, or -1.
    private int HitTestPlayerHandSlot(Point p)
    {
        for (int i = 0; i < _playerHandViews.Length; i++)
        {
            var origin = _playerHandViews[i].TranslatePoint(new Point(0, 0), this);
            if (!origin.HasValue) continue;
            var r = new Rect(origin.Value, _playerHandViews[i].Bounds.Size);
            if (r.Contains(p)) return i;
        }
        return -1;
    }

    private void ShowDragGhost(Point pos)
    {
        // Find (or lazily create) the overlay canvas — it lives in the root Grid
        if (_dragCanvas == null)
        {
            _dragCanvas = this.FindControl<Canvas>("HoneycombDragCanvas");
        }
        if (_dragCanvas == null || _vm == null) return;

        HideDragGhost();

        var ghostCard = new HoneycombCardView
        {
            Width = 195,
            Height = 276,
            IsHitTestVisible = false
        };

        // Determine which card we are dragging
        HoneycombCard? cardToRender = null;
        if (_dragHandIndex >= 0 && _dragHandIndex < _vm.State.PlayerHand.Count)
        {
            cardToRender = _vm.State.PlayerHand[_dragHandIndex];
        }
        else if (_dragBoardIndex >= 0 && !_vm.State.Board.Cells[_dragBoardIndex].IsEmpty)
        {
            cardToRender = _vm.State.Board.Cells[_dragBoardIndex].Card;
        }

        if (cardToRender != null)
        {
            _ = ghostCard.RenderCard(cardToRender);
        }

        _dragGhost = new Border
        {
            Child = ghostCard,
            IsHitTestVisible = false,
            BoxShadow = Avalonia.Media.BoxShadows.Parse("0 8 24 4 #80000000"),
            CornerRadius = new Avalonia.CornerRadius(8)
        };

        Canvas.SetLeft(_dragGhost, pos.X - 98);
        Canvas.SetTop (_dragGhost, pos.Y - 138);
        _dragCanvas.Children.Add(_dragGhost);
    }

    private void HideDragGhost()
    {
        if (_dragGhost != null && _dragCanvas != null)
        {
            _dragCanvas.Children.Remove(_dragGhost);
            _dragGhost = null;
        }
    }

    public void DebugShowResultBanner(string kind)
    {
        if (kind == "Same" || kind == "Plus" || kind == "FallenAce" || kind == "Combo")
        {
            _bannerActive = true;
            if (kind == "FallenAce") RuleToast.Flash("Fallen Ace!");
            else if (kind == "Combo") RuleToast.Flash("Combo x2!");
            else RuleToast.Flash($"{kind}!");
            return;
        }

        _overlayDismissed = false;
        OverlayPanel.IsVisible = true;
        
        switch (kind)
        {
            case "Win":
                OverlayTitle.IsVisible = true;
                OverlayLoseTitle.IsVisible = false;
                OverlayTitle.Text = "You Win!";
                OverlaySubtitle.Text = "Final Score: 10 - 5";
                break;
            case "Loss":
                OverlayTitle.IsVisible = false;
                OverlayLoseTitle.IsVisible = true;
                OverlaySubtitle.Text = "Final Score: 5 - 10";
                break;
            case "Draw":
                OverlayTitle.IsVisible = true;
                OverlayLoseTitle.IsVisible = false;
                OverlayTitle.Text = "Draw";
                OverlaySubtitle.Text = "Final Score: 7 - 7";
                break;
            case "SuddenDeath":
                OverlayTitle.IsVisible = true;
                OverlayLoseTitle.IsVisible = false;
                OverlayTitle.Text = "Sudden Death";
                OverlaySubtitle.Text = "Next capture wins!";
                break;
            default:
                OverlayTitle.IsVisible = true;
                OverlayLoseTitle.IsVisible = false;
                OverlayTitle.Text = kind;
                OverlaySubtitle.Text = "Debug preview";
                break;
        }
    }
}
