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
using System.Threading.Tasks;

namespace SoliBee.Desktop.Views;


public partial class HoneycombView : UserControl
{
    private HoneycombViewModel? _vm;
    private int _selectedHandIndex = -1;
    
    // Keyboard Cursor State
    private enum CursorZone { PlayerHand, Board, OpponentHand }
    private CursorZone _cursorZone = CursorZone.PlayerHand;
    private int _cursorIndex = 0;
    private bool _isKeyboardCursorActive = false;

    private bool _isStealingCard = false;
    private bool _overlayDismissed = false;
    private bool _bannerActive = false;

    private int _lastEmptyCells = 9;
    private bool _resultSoundPlayed = false;


    // Pointer-capture drag state (same approach as CardView)
    private Point? _dragStartPoint;
    private bool _isDragging;
    private int _dragHandIndex = -1;        // which hand card is being dragged
    private Border? _dragGhost;             // floating ghost card shown during drag
    private Canvas? _dragCanvas;            // top-level overlay canvas
    // Static origin the ghost's Canvas.Left/Top is set to once at creation —
    // _dragGhostTx carries the per-mousemove delta from here instead of Canvas.Left/
    // Top being rewritten on every move, so tracking the cursor skips layout.
    private TranslateTransform? _dragGhostTx;
    private Point _dragGhostOrigin;

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
            cardView.OnRuleAnimationScaleChanged += (isAnimating) =>
            {
                cardView.ZIndex = isAnimating ? 100 : 0;
            };
            Grid.SetRow(cardView, i / 3);
            Grid.SetColumn(cardView, i % 3);
            BoardGrid.Children.Add(cardView);
            _boardCards[i] = cardView;
        }

        SetupDragAndDrop();
        
        RuleToast.OnDismissed += () => {
            _bannerActive = false;
            // Reveals whatever's queued behind the banner that just finished (if
            // anything) — Vm_OnFlashBanner picks it up via OnFlashBanner and flips
            // _bannerActive back to true, so the win/lose overlay (gated on
            // !_bannerActive) stays held back until the whole queue has drained.
            _vm?.AdvanceBannerQueue();
            if (_vm != null) Refresh(_vm);
        };

        Loaded += (s, e) =>
        {
            _vm = DataContext as HoneycombViewModel;
            if (_vm != null)
            {
                _vm.PropertyChanged += Vm_PropertyChanged;
                _vm.OnFlashBanner += Vm_OnFlashBanner;
                _vm.OnSwapLifting += Vm_OnSwapLifting;
                _vm.OnSwapLanded += Vm_OnSwapLanded;
                Refresh(_vm);
            }
        };
    }
    
    private void Vm_OnFlashBanner(string message)
    {
        Dispatcher.UIThread.Post(() => {
            _bannerActive = true;
            var duration = message.StartsWith("First Move:") ? TimeSpan.FromSeconds(2) : (TimeSpan?)null;
            RuleToast.Flash(message, duration);
        });
    }

    // Beat 1 (Lift) of the Nectar Exchange 3-beat sequence — scales the two
    // pre-swap cards up in place with a shadow, matching the Swift port's
    // SwapLiftEffect modifier (swapAnimationPhase == .lifting). Runs before any
    // data change, so it operates on the real hand-slot views, not ghosts.
    private void Vm_OnSwapLifting(int playerIndex, int opponentIndex)
    {
        Dispatcher.UIThread.Post(() =>
        {
            SoundService.PlayShuffle();
            if (playerIndex >= 0 && playerIndex < _playerHandViews.Length) ApplyLift(_playerHandViews[playerIndex]);
            if (opponentIndex >= 0 && opponentIndex < _opponentHandViews.Length) ApplyLift(_opponentHandViews[opponentIndex]);
        });
    }

    private static void ApplyLift(Control view, bool instant = false)
    {
        var scale = new ScaleTransform(instant ? 1.5 : 1.0, instant ? 1.5 : 1.0);
        view.RenderTransform = scale;
        view.ZIndex = 100;
        var effect = new Avalonia.Media.DropShadowEffect { Color = Colors.Black, OffsetX = 0, OffsetY = 0, BlurRadius = instant ? 20 : 0, Opacity = instant ? 0.5 : 0.0 };
        view.Effect = effect;

        if (!instant)
        {
            var liftEase = new Avalonia.Animation.Easings.CubicEaseInOut();
            scale.Transitions = new Avalonia.Animation.Transitions
            {
                new Avalonia.Animation.DoubleTransition { Property = ScaleTransform.ScaleXProperty, Duration = TimeSpan.FromMilliseconds(300), Easing = liftEase },
                new Avalonia.Animation.DoubleTransition { Property = ScaleTransform.ScaleYProperty, Duration = TimeSpan.FromMilliseconds(300), Easing = liftEase }
            };
            effect.Transitions = new Avalonia.Animation.Transitions
            {
                new Avalonia.Animation.DoubleTransition { Property = Avalonia.Media.DropShadowEffect.BlurRadiusProperty, Duration = TimeSpan.FromMilliseconds(300), Easing = liftEase },
                new Avalonia.Animation.DoubleTransition { Property = Avalonia.Media.DropShadowEffect.OpacityProperty, Duration = TimeSpan.FromMilliseconds(300), Easing = liftEase }
            };

            scale.ScaleX = 1.5;
            scale.ScaleY = 1.5;
            effect.BlurRadius = 20;
            effect.Opacity = 0.5;
        }
    }

    private static void ClearLift(Control view)
    {
        view.RenderTransform = null;
        view.ZIndex = 0;
        view.Effect = null;
    }

    // Nectar Exchange (Swap) trade landed — the ViewModel already applied it (and
    // NotifyStateChanged will snap the two real slots to their new content), so
    // this plays a floating ghost of each pre-swap card sliding across to the
    // other side's slot, matching the Swift port's matchedGeometryEffect-driven
    // cross-position animation (mac/shared HoneycombView.swift /
    // HoneycombViewModel.stageSwapAnimation) instead of Windows' previous in-place
    // flip, which didn't visually cross hands at all.
    private void Vm_OnSwapLanded(HoneycombCard preSwapPlayerCard, HoneycombCard preSwapOpponentCard, int playerIndex, int opponentIndex)
    {
        // Hide and un-scale the real slots synchronously before the UI thread can draw 
        // the newly swapped cards that the ViewModel just applied! 
        if (playerIndex >= 0 && playerIndex < _playerHandViews.Length) 
        {
            ClearLift(_playerHandViews[playerIndex]);
            _playerHandViews[playerIndex].Opacity = 0;
        }
        if (opponentIndex >= 0 && opponentIndex < _opponentHandViews.Length) 
        {
            ClearLift(_opponentHandViews[opponentIndex]);
            _opponentHandViews[opponentIndex].Opacity = 0;
        }
        _ = PlaySwapSlideAnimation(preSwapPlayerCard, preSwapOpponentCard, playerIndex, opponentIndex);
    }

    // Slides a floating ghost of each pre-swap card from its original hand slot to
    // the slot it now occupies in the other player's row — 0.9s ease-in-out,
    // matching the Swift port's withAnimation(.easeInOut(duration: 0.9)). The two
    // real slot views are hidden for the duration so the instant data-level swap
    // already applied by NotifyStateChanged isn't visible underneath, then revealed
    // once the ghosts land.
    private async Task PlaySwapSlideAnimation(HoneycombCard preSwapPlayerCard, HoneycombCard preSwapOpponentCard, int playerIndex, int opponentIndex)
    {
        if (_dragCanvas == null) _dragCanvas = this.FindControl<Canvas>("HoneycombDragCanvas");
        if (_dragCanvas == null) return;
        if (playerIndex < 0 || playerIndex >= _playerHandViews.Length) return;
        if (opponentIndex < 0 || opponentIndex >= _opponentHandViews.Length) return;

        var playerSlot = _playerHandViews[playerIndex];
        var opponentSlot = _opponentHandViews[opponentIndex];

        // Clear Lift FIRST so that TranslatePoint gets the true layout coordinates, 
        // avoiding a double-scale offset jerk when the ghost scales itself up.
        ClearLift(playerSlot);
        ClearLift(opponentSlot);

        var playerPos = playerSlot.TranslatePoint(new Point(0, 0), _dragCanvas);
        var opponentPos = opponentSlot.TranslatePoint(new Point(0, 0), _dragCanvas);
        if (playerPos == null || opponentPos == null) return;

        var size = playerSlot.Bounds.Size;

        HoneycombCardView MakeGhost(HoneycombCard card, Point start)
        {
            var ghost = new HoneycombCardView { Width = size.Width, Height = size.Height, IsHitTestVisible = false };
            _ = ghost.RenderCard(card);
            
            var scale = new ScaleTransform(1.5, 1.5);
            var translate = new TranslateTransform(0, 0);
            var group = new TransformGroup();
            group.Children.Add(scale);
            group.Children.Add(translate);
            ghost.RenderTransform = group;
            ghost.ZIndex = 100;
            ghost.Effect = new Avalonia.Media.DropShadowEffect { Color = Colors.Black, OffsetX = 0, OffsetY = 0, BlurRadius = 20, Opacity = 0.5 };

            Canvas.SetLeft(ghost, start.X);
            Canvas.SetTop(ghost, start.Y);
            _dragCanvas.Children.Add(ghost);
            return ghost;
        }

        var playerGhost = MakeGhost(preSwapPlayerCard, playerPos.Value);
        var opponentGhost = MakeGhost(preSwapOpponentCard, opponentPos.Value);

        playerSlot.Opacity = 0;
        opponentSlot.Opacity = 0;

        // Force a layout/render pass so the newly-spawned ghosts' initial positions 
        // are firmly established in the compositor before we attach Transitions and 
        // change their destination. This prevents Avalonia from flickering or 
        // skipping the animation if it processes creation and movement in the same frame.
        await Task.Delay(16);

        // Beat 2: Flight — ghosts glide across the board at full 1.5x lift scale.
        // We use TranslateTransform instead of Canvas.Left/Top so the transition runs
        // on the compositor (GPU) at 60+ FPS without forcing a CPU layout pass every frame.
        const int flightMs = 800;
        var flightEase = new Avalonia.Animation.Easings.CubicEaseInOut();

        var playerTranslate = (TranslateTransform)((TransformGroup)playerGhost.RenderTransform!).Children[1];
        var opponentTranslate = (TranslateTransform)((TransformGroup)opponentGhost.RenderTransform!).Children[1];

        playerTranslate.Transitions = new Avalonia.Animation.Transitions
        {
            new Avalonia.Animation.DoubleTransition { Property = TranslateTransform.XProperty, Duration = TimeSpan.FromMilliseconds(flightMs), Easing = flightEase },
            new Avalonia.Animation.DoubleTransition { Property = TranslateTransform.YProperty, Duration = TimeSpan.FromMilliseconds(flightMs), Easing = flightEase }
        };
        opponentTranslate.Transitions = new Avalonia.Animation.Transitions
        {
            new Avalonia.Animation.DoubleTransition { Property = TranslateTransform.XProperty, Duration = TimeSpan.FromMilliseconds(flightMs), Easing = flightEase },
            new Avalonia.Animation.DoubleTransition { Property = TranslateTransform.YProperty, Duration = TimeSpan.FromMilliseconds(flightMs), Easing = flightEase }
        };

        playerTranslate.X = opponentPos.Value.X - playerPos.Value.X;
        playerTranslate.Y = opponentPos.Value.Y - playerPos.Value.Y;

        opponentTranslate.X = playerPos.Value.X - opponentPos.Value.X;
        opponentTranslate.Y = playerPos.Value.Y - opponentPos.Value.Y;

        await Task.Delay(flightMs);

        // Beat 3: Touchdown — scale/shadow ease back down to normal at the
        // destination slot, with a landing "snap".
        SoundService.PlaySnap();
        const int landMs = 400;
        var landEase = new Avalonia.Animation.Easings.CubicEaseInOut();

        var playerScale = (ScaleTransform)((TransformGroup)playerGhost.RenderTransform!).Children[0];
        var opponentScale = (ScaleTransform)((TransformGroup)opponentGhost.RenderTransform!).Children[0];
        var playerEffect = (Avalonia.Media.DropShadowEffect)playerGhost.Effect!;
        var opponentEffect = (Avalonia.Media.DropShadowEffect)opponentGhost.Effect!;

        playerScale.Transitions = new Avalonia.Animation.Transitions
        {
            new Avalonia.Animation.DoubleTransition { Property = ScaleTransform.ScaleXProperty, Duration = TimeSpan.FromMilliseconds(landMs), Easing = landEase },
            new Avalonia.Animation.DoubleTransition { Property = ScaleTransform.ScaleYProperty, Duration = TimeSpan.FromMilliseconds(landMs), Easing = landEase }
        };
        opponentScale.Transitions = new Avalonia.Animation.Transitions
        {
            new Avalonia.Animation.DoubleTransition { Property = ScaleTransform.ScaleXProperty, Duration = TimeSpan.FromMilliseconds(landMs), Easing = landEase },
            new Avalonia.Animation.DoubleTransition { Property = ScaleTransform.ScaleYProperty, Duration = TimeSpan.FromMilliseconds(landMs), Easing = landEase }
        };

        playerEffect.Transitions = new Avalonia.Animation.Transitions
        {
            new Avalonia.Animation.DoubleTransition { Property = Avalonia.Media.DropShadowEffect.BlurRadiusProperty, Duration = TimeSpan.FromMilliseconds(landMs), Easing = landEase },
            new Avalonia.Animation.DoubleTransition { Property = Avalonia.Media.DropShadowEffect.OpacityProperty, Duration = TimeSpan.FromMilliseconds(landMs), Easing = landEase }
        };
        opponentEffect.Transitions = new Avalonia.Animation.Transitions
        {
            new Avalonia.Animation.DoubleTransition { Property = Avalonia.Media.DropShadowEffect.BlurRadiusProperty, Duration = TimeSpan.FromMilliseconds(landMs), Easing = landEase },
            new Avalonia.Animation.DoubleTransition { Property = Avalonia.Media.DropShadowEffect.OpacityProperty, Duration = TimeSpan.FromMilliseconds(landMs), Easing = landEase }
        };

        playerScale.ScaleX = 1.0;
        playerScale.ScaleY = 1.0;
        opponentScale.ScaleX = 1.0;
        opponentScale.ScaleY = 1.0;

        playerEffect.BlurRadius = 0;
        playerEffect.Opacity = 0;
        opponentEffect.BlurRadius = 0;
        opponentEffect.Opacity = 0;

        await Task.Delay(landMs);

        _dragCanvas.Children.Remove(playerGhost);
        _dragCanvas.Children.Remove(opponentGhost);
        playerSlot.Opacity = 1;
        opponentSlot.Opacity = 1;
    }

    private void Vm_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        Dispatcher.UIThread.Post(() => { if (_vm != null) Refresh(_vm); });
    }

    // NotifyStateChanged() fires several PropertyChanged events per call (State,
    // IsPlaying, CanUndo, ActiveHint, PlayerScoreDisplay, OpponentScoreDisplay), each
    // dispatching its own Refresh() call, and this method itself awaits per-cell flip
    // animations — so without this guard, multiple Refresh() passes can run
    // concurrently and race on the same card views. A stale, still-in-flight pass
    // finishing after a newer one has already rendered current state can clobber it
    // (e.g. re-applying a Point Highlight the newer pass had already cleared, leaving
    // it stuck on screen). Coalesce into a single pass at a time, queuing one more
    // to run immediately after if state changed again while a pass was in flight.
    private bool _isRefreshing = false;
    private bool _refreshQueued = false;

    public async void Refresh(HoneycombViewModel vm)
    {
        if (_isRefreshing)
        {
            _refreshQueued = true;
            return;
        }

        _isRefreshing = true;
        try
        {
            await RefreshCore(vm);
        }
        finally
        {
            _isRefreshing = false;
        }

        if (_refreshQueued)
        {
            _refreshQueued = false;
            Refresh(vm);
        }
    }

    private async Task RefreshCore(HoneycombViewModel vm)
    {
        var state = vm.State;
        
        if (vm.IsPlaying) 
        {
            _overlayDismissed = false;
            _resultSoundPlayed = false;
        }
        else if (state.Phase == HoneycombPhase.PreMatch)
        {
            _isStealingCard = false;
            _bannerActive = false;
            _selectedHandIndex = -1;
        }

        int currentEmptyCells = state.Board.Cells.Count(c => c.IsEmpty);
        if (currentEmptyCells < _lastEmptyCells)
        {
            SoundService.PlaySnap();
        }
        _lastEmptyCells = currentEmptyCells;

        
        OverlayPanel.IsVisible = !vm.IsPlaying && state.Phase == HoneycombPhase.Result && state.ShowPostGamePrompt && !_isStealingCard && !_overlayDismissed;
        if (!vm.IsPlaying && state.Phase == HoneycombPhase.Result && state.ShowPostGamePrompt)
        {
            OverlayTitle.IsVisible = true;
            OverlayLoseTitle.IsVisible = false;
            
            if (state.PlayerScore > state.OpponentScore) {
                // The win overlay reappears after a steal is confirmed (Steal Card is
                // now gone, since HasStolenThisMatch is true) — a repeat "You Win!" would
                // read as stale, so it confirms what just happened instead.
                OverlayTitle.FontSize = state.HasStolenThisMatch ? 28 : 40;
                OverlayTitle.Text = state.HasStolenThisMatch ? "Card added to card bank." : "You Win!";
            } else if (state.PlayerScore < state.OpponentScore) {
                OverlayTitle.IsVisible = false;
                OverlayLoseTitle.IsVisible = true;
            } else {
                // Sudden Death is now opt-in, so a tie with it off is a final result
                // (matches mac's "Tie!" wording) rather than the old always-continues
                // "Draw" that used to be unreachable here (SettleMatch used to route
                // every tie into TriggerSuddenDeathAsync before this could show).
                OverlayTitle.FontSize = 40;
                OverlayTitle.Text = "Tie!";
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
            bool won = state.PlayerScore > state.OpponentScore;
            bool canSteal = !globalOpts.IsNoStressMode && !state.HasStolenThisMatch && won;
            if (canSteal)
            {
                // Check if bank full — mirrors the Swift port's isCardBankFull
                // (unlockedCardIds.count >= allCards.count), not a hardcoded guess.
                bool bankFull = HoneycombProfileManager.Shared.UnlockedCardIds.Count >= HoneycombDatabase.Shared.AllCards.Count;

                // Also require at least one card on the board that's actually stealable
                // (originally the opponent's, currently captured by the player, and not
                // already unlocked) — otherwise the button led into a steal flow with
                // nothing on the board selectable.
                bool hasStealableCard = false;
                for (int i = 0; i < 9; i++)
                {
                    var cell = state.Board.Cells[i];
                    if (cell.IsEmpty) continue;
                    var card = cell.Card!;
                    if (card.OriginalOwner == -1 && card.Owner == 1
                        && !HoneycombProfileManager.Shared.UnlockedCardIds.Contains(card.Data.Id))
                    {
                        hasStealableCard = true;
                        break;
                    }
                }

                StealCardButton.IsVisible = !bankFull && hasStealableCard;
                BankFullWarningText.IsVisible = bankFull;
                AlreadyStolenWarningText.IsVisible = false;
            }
            else
            {
                StealCardButton.IsVisible = false;
                BankFullWarningText.IsVisible = false;
                // Only the "already stolen" scenario gets its own message — a loss/draw
                // or No Stress Mode has nothing steal-related to explain.
                AlreadyStolenWarningText.IsVisible = !globalOpts.IsNoStressMode && state.HasStolenThisMatch && won;
            }
        }
        
        StealInstructionBar.IsVisible = _isStealingCard;
        RulesBannerBar.IsVisible = !_isStealingCard;

        StealConfirmationPanel.IsVisible = vm.PendingSteal != null;

        OverlayPanel.IsVisible = !vm.IsPlaying && state.Phase == HoneycombPhase.Result && state.ShowPostGamePrompt && !_isStealingCard && !_overlayDismissed && !_bannerActive;
        
        List<string> ruleNames;
        if (vm.IsPlaying)
        {
            ruleNames = state.ActiveRules.Select(r =>
            {
                var name = r.DisplayName();
                if ((r == HoneycombRule.Ascension || r == HoneycombRule.Descension) && state.Board.AscensionDescensionSuits.Count > 0)
                {
                    var suitNames = state.Board.AscensionDescensionSuits.Select(HoneycombCardData.SuitDisplayName);
                    return $"{name} Suit: {string.Join(", ", suitNames)}";
                }
                return name;
            }).ToList();
            if (ruleNames.Count == 0) ruleNames.Add("Normal");
        }
        else if (vm.Options.ForceNormalRules)
        {
            ruleNames = new List<string> { "Normal" };
        }
        else if (vm.Options.ManualRules != null && vm.Options.ManualRules.Count > 0)
        {
            ruleNames = vm.Options.ManualRules
                .Select(r => r.DisplayName())
                .ToList();
        }
        else
        {
            ruleNames = new List<string> { "Roulette" };
        }
        RulesList.ItemsSource = ruleNames;
        

        bool isOrder = state.ActiveRules.Contains(HoneycombRule.Order);
        bool isChaos = state.ActiveRules.Contains(HoneycombRule.Chaos);

        // Render Player Hand
        var displayPlayerHand = state.Phase == HoneycombPhase.Result ? state.PlayerStartingDeck : state.PlayerHand;
        var placeholderData = new HoneycombCardData { Name = "", Stars = 1, Stats = new[] { 1, 1, 1, 1 }, Suit = "S", Id = -1 };
        
        for (int i = 0; i < 5; i++)
        {
            bool highlight = false;
            if (state.Phase == HoneycombPhase.PreMatch)
            {
                var pCard = new HoneycombCard(placeholderData, 1);
                await _playerHandViews[i].RenderCard(pCard, faceDown: true, hIdx: i, cIdx: -1);
            }
            else if (i < displayPlayerHand.Count)
            {
                await _playerHandViews[i].RenderCard(displayPlayerHand[i], faceDown: false, hIdx: i, cIdx: -1);
                
                if (state.Phase == HoneycombPhase.Playing)
                {
                    if (isOrder && i == 0) highlight = true;
                    else if (isChaos && state.PlayerChaosIndex.HasValue && state.PlayerChaosIndex.Value == i) highlight = true;
                }
                
                if (vm.ActiveHint.HasValue && vm.ActiveHint.Value.handIndex == i) highlight = true;
            }
            else
            {
                await _playerHandViews[i].RenderCard(null);
            }
            
            _playerHandViews[i].StealHighlight = highlight;
        }

        // Render Opponent Hand
        for (int i = 0; i < 5; i++)
        {
            bool highlight = false;
            if (state.Phase == HoneycombPhase.PreMatch)
            {
                var oCard = new HoneycombCard(placeholderData, 2);
                await _opponentHandViews[i].RenderCard(oCard, faceDown: true, hIdx: i, cIdx: -1);
            }
            else if (i < state.OpponentHand.Count)
            {
                bool isPostWinReveal = state.Phase == HoneycombPhase.Result && state.ShowPostGamePrompt && state.PlayerScore > state.OpponentScore;
                bool hidden = !isPostWinReveal 
                              && !state.ActiveRules.Contains(HoneycombRule.AllOpen) 
                              && !state.OpponentRevealedIds.Contains(state.OpponentHand[i].UniqueInstanceId);
                // In a real game, AI cards are hidden unless revealed. The spec says All Open / Three Open reveals symmetrically.
                // For now, render faceDown if hidden.
                await _opponentHandViews[i].RenderCard(state.OpponentHand[i], faceDown: hidden, hIdx: i, cIdx: -1);
                
                if (state.Phase == HoneycombPhase.Playing)
                {
                    if (isOrder && i == 0) highlight = true;
                    else if (isChaos && state.OpponentChaosIndex.HasValue && state.OpponentChaosIndex.Value == i) highlight = true;
                }
            }
            else
            {
                await _opponentHandViews[i].RenderCard(null);
            }
            
            _opponentHandViews[i].StealHighlight = highlight;
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
                _boardCards[i].SetStatHighlight(null);
            }
            else
            {
                await _boardCards[i].RenderCard(cell.Card, faceDown: cell.Card!.IsFaceDown, hIdx: -1, cIdx: i,
                    isCaptureAttacker: state.CaptureAttackerIds.Contains(cell.Card.UniqueInstanceId));

                // Highlight cards eligible to be double-clicked and stolen
                _boardCells[i].Background = new SolidColorBrush(Color.Parse("#59000000"));
                _boardCards[i].StealHighlight = _isStealingCard
                    && cell.Card != null && cell.Card.OriginalOwner == -1 && cell.Card.Owner == 1
                    && !HoneycombProfileManager.Shared.UnlockedCardIds.Contains(cell.Card.Data.Id);

                // Point Highlights: flash the just-placed card's winning stat edge(s)
                // for a beat before the capture visually flips (see ExecutePlacement).
                _boardCards[i].SetStatHighlight(state.PointHighlightCellIndex == i ? state.PointHighlightStatIndices : null);
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

    // Steal mode: double-click an eligible captured opponent card on the board to
    // steal it — a single step straight to the confirmation dialog, since stealing no
    // longer targets a hand slot to replace.
    private void BoardCard_Clicked(object? sender, PointerPressedEventArgs e)
    {
        if (_vm == null) return;
        var point = e.GetCurrentPoint(this);
        if (point.Properties.IsLeftButtonPressed && e.ClickCount == 2 && sender is HoneycombCardView cardView)
        {
            int cellIndex = Array.IndexOf(_boardCards, cardView);
            if (cellIndex >= 0 && _isStealingCard && _vm.State.Phase == HoneycombPhase.Result)
            {
                _vm.RequestSteal(cellIndex);
                Refresh(_vm);
            }
        }
    }

    private void StealCard_Click(object? sender, RoutedEventArgs e)
    {
        _isStealingCard = true;
        if (_vm != null) Refresh(_vm);
    }

    private void CancelSteal_Click(object? sender, RoutedEventArgs e)
    {
        _isStealingCard = false;
        if (_vm != null) Refresh(_vm);
    }

    private void ConfirmStealDialog_Click(object? sender, RoutedEventArgs e)
    {
        if (_vm != null) {
            _vm.ConfirmPendingSteal();
            _isStealingCard = false;
            // Falls straight back to the win overlay (still Result phase, nothing else
            // hides it) rather than the separate Rematch/New Game prompt — its title
            // switches to the steal confirmation below since Steal Card is now gone.
            Refresh(_vm);
        }
    }

    private void CancelStealDialog_Click(object? sender, RoutedEventArgs e)
    {
        _vm?.CancelPendingSteal();
        if (_vm != null) Refresh(_vm);
    }

    private void NewGame_Click(object? sender, RoutedEventArgs e)
    {
        _overlayDismissed = false;
        _isStealingCard = false;
        if (_vm != null) {
            _vm.InitializeGame();
            SoundService.PlayShuffle();
        }
    }

    private void Rematch_Click(object? sender, RoutedEventArgs e)
    {
        _overlayDismissed = false;
        _isStealingCard = false;
        if (_vm != null) {
            _vm.RematchGame();
            SoundService.PlayShuffle();
        }
    }

    private void CloseOverlay_Click(object? sender, RoutedEventArgs e)
    {
        _overlayDismissed = true;
        OverlayPanel.IsVisible = false;
    }

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);
        TopLevel.GetTopLevel(this)?.AddHandler(InputElement.KeyDownEvent, OnKeyDown, RoutingStrategies.Tunnel);
        if (DataContext is HoneycombViewModel vm)
        {
            Refresh(vm);
        }
    }

    protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnDetachedFromVisualTree(e);
        TopLevel.GetTopLevel(this)?.RemoveHandler(InputElement.KeyDownEvent, OnKeyDown);
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
                _isDragging     = false; // becomes true once we exceed threshold in Moved
                e.Pointer.Capture(hv);
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

        if (_isDragging && _dragGhost != null && _dragCanvas != null && _dragGhostTx != null)
        {
            _dragGhostTx.X = (pos.X - 98) - _dragGhostOrigin.X;
            _dragGhostTx.Y = (pos.Y - 138) - _dragGhostOrigin.Y;
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

        if (cardToRender != null)
        {
            _ = ghostCard.RenderCard(cardToRender);
        }

        _dragGhostTx = new TranslateTransform();
        _dragGhost = new Border
        {
            Child = ghostCard,
            IsHitTestVisible = false,
            BoxShadow = Avalonia.Media.BoxShadows.Parse("0 8 24 4 #80000000"),
            CornerRadius = new Avalonia.CornerRadius(8),
            RenderTransform = _dragGhostTx
        };

        _dragGhostOrigin = new Point(pos.X - 98, pos.Y - 138);
        Canvas.SetLeft(_dragGhost, _dragGhostOrigin.X);
        Canvas.SetTop (_dragGhost, _dragGhostOrigin.Y);
        _dragCanvas.Children.Add(_dragGhost);
    }

    private void HideDragGhost()
    {
        if (_dragGhost != null && _dragCanvas != null)
        {
            _dragCanvas.Children.Remove(_dragGhost);
            _dragGhost = null;
        }
        _dragGhostTx = null;
    }

    public void DebugShowResultBanner(string kind)
    {
        if (kind == "Same" || kind == "Plus" || kind == "FallenAce" || kind == "Combo" || kind == "SuddenDeath")
        {
            _bannerActive = true;
            if (kind == "FallenAce") RuleToast.Flash($"{HoneycombRule.FallenAce.DisplayName()}!");
            else if (kind == "Combo") RuleToast.Flash("Combo x2!");
            else if (kind == "SuddenDeath") RuleToast.Flash($"{HoneycombRule.SuddenDeath.DisplayName()}!");
            else if (kind == "Same") RuleToast.Flash($"{HoneycombRule.Same.DisplayName()}!");
            else if (kind == "Plus") RuleToast.Flash($"{HoneycombRule.Plus.DisplayName()}!");
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
                OverlayTitle.FontSize = 40;
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
                OverlayTitle.FontSize = 40;
                OverlayTitle.Text = "Tie!";
                OverlaySubtitle.Text = "Final Score: 7 - 7";
                break;
            default:
                OverlayTitle.IsVisible = true;
                OverlayLoseTitle.IsVisible = false;
                OverlayTitle.FontSize = 28;
                OverlayTitle.Text = kind;
                OverlaySubtitle.Text = "Debug preview";
                break;
        }
    }

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (DataContext is not HoneycombViewModel vm) return;
        if (TopLevel.GetTopLevel(this)?.FocusManager?.GetFocusedElement() is TextBox) return;

        switch (e.Key)
        {
            case Key.Escape:
                // Only claim Escape when it actually did something here (cancel steal
                // mode / clear hand selection) — marking it Handled unconditionally would
                // swallow it even when neither applies (e.g. Preferences/Rules open on
                // top of Honeycomb), silently blocking MainWindow's own Escape-closes-
                // overlay handling with nothing to show for it.
                if (_isStealingCard) { CancelSteal_Click(null, new RoutedEventArgs()); e.Handled = true; }
                else if (_selectedHandIndex != -1) { _selectedHandIndex = -1; Refresh(vm); e.Handled = true; }
                break;
            case Key.Up:    MoveCursor(-1, 0); e.Handled = true; break;
            case Key.Down:  MoveCursor(1, 0);  e.Handled = true; break;
            case Key.Left:  MoveCursor(0, -1); e.Handled = true; break;
            case Key.Right: MoveCursor(0, 1);  e.Handled = true; break;
            case Key.Space: case Key.Enter:
                ActivateCursor(); e.Handled = true; break;
        }
    }

    private void MoveCursor(int dy, int dx)
    {
        if (!_isKeyboardCursorActive)
        {
            _isKeyboardCursorActive = true;
            UpdateCursorVisual();
            return;
        }

        // Logic for navigation
        if (_cursorZone == CursorZone.PlayerHand)
        {
            if (dx > 0) { _cursorZone = CursorZone.Board; _cursorIndex = 0; }
            else if (dy != 0)
            {
                // Simple cycle 0-4
                _cursorIndex = (_cursorIndex + dy + 5) % 5;
            }
        }
        else if (_cursorZone == CursorZone.Board)
        {
            int r = _cursorIndex / 3;
            int c = _cursorIndex % 3;
            
            if (dx < 0 && c == 0) { _cursorZone = CursorZone.PlayerHand; _cursorIndex = 2; }
            else if (dx > 0 && c == 2 && _isStealingCard) { _cursorZone = CursorZone.OpponentHand; _cursorIndex = 2; }
            else
            {
                r = Math.Clamp(r + dy, 0, 2);
                c = Math.Clamp(c + dx, 0, 2);
                _cursorIndex = r * 3 + c;
            }
        }
        else if (_cursorZone == CursorZone.OpponentHand)
        {
            if (dx < 0) { _cursorZone = CursorZone.Board; _cursorIndex = 2; }
            else if (dy != 0)
            {
                _cursorIndex = (_cursorIndex + dy + 5) % 5;
            }
        }
        UpdateCursorVisual();
    }

    private void ActivateCursor()
    {
        if (!_isKeyboardCursorActive || _vm == null) return;
        
        if (_cursorZone == CursorZone.PlayerHand)
        {
            if (_cursorIndex < _vm.State.PlayerHand.Count && !_isStealingCard)
            {
                _selectedHandIndex = _cursorIndex;
                Refresh(_vm);
            }
        }
        else if (_cursorZone == CursorZone.Board)
        {
            if (_selectedHandIndex != -1 && !_isStealingCard)
            {
                _vm.PlayCard(_selectedHandIndex, _cursorIndex);
                _selectedHandIndex = -1;
                Refresh(_vm);
            }
            else if (_isStealingCard && _vm.State.Phase == HoneycombPhase.Result)
            {
                var card = _vm.State.Board.Cells[_cursorIndex].Card;
                if (card != null && card.OriginalOwner == -1 && card.Owner == 1 && !HoneycombProfileManager.Shared.UnlockedCardIds.Contains(card.Data.Id))
                {
                    _vm.RequestSteal(_cursorIndex);
                    Refresh(_vm);
                }
            }
        }
    }

    public class RuleExplanationItem
    {
        public string Name { get; set; } = "";
        public string Explanation { get; set; } = "";
    }

    private void RulesBannerBar_PointerEntered(object? sender, PointerEventArgs e)
    {
        if (_vm == null) return;

        bool isPreGame = _vm.State.Phase != HoneycombPhase.Playing;
        bool isRoulette = isPreGame && !_vm.Options.ForceNormalRules && _vm.Options.ManualRules.Count == 0;
        var effectiveRules = isPreGame && !isRoulette
            ? _vm.Options.ManualRules.ToList()
            : _vm.State.ActiveRules;

        var items = new List<RuleExplanationItem>();

        if (isRoulette)
        {
            items.Add(new RuleExplanationItem
            {
                Name = "Roulette",
                Explanation = "Rules are randomized at the start of the match."
            });
        }

        var activeSuits = new HashSet<string>(_vm.State.Board.AscensionDescensionSuits);
        foreach (var rule in effectiveRules)
        {
            items.Add(new RuleExplanationItem
            {
                Name = rule.DisplayName(),
                Explanation = rule.GetExplanation(activeSuits)
            });
        }
        
        if (items.Count > 0)
        {
            RulesExplanationList.ItemsSource = items;
            RulesExplanationPopup.IsOpen = true;
        }
    }

    private void RulesBannerBar_PointerExited(object? sender, PointerEventArgs e)
    {
        RulesExplanationPopup.IsOpen = false;
    }

    private void UpdateCursorVisual()
    {
        if (!_isKeyboardCursorActive)
        {
            CursorHighlightBorder.IsVisible = false;
            return;
        }

        Control? targetElement = null;
        if (_cursorZone == CursorZone.PlayerHand) targetElement = _playerHandViews[_cursorIndex];
        else if (_cursorZone == CursorZone.Board) targetElement = _boardCells[_cursorIndex];
        else if (_cursorZone == CursorZone.OpponentHand) targetElement = _opponentHandViews[_cursorIndex];

        if (targetElement != null)
        {
            CursorHighlightBorder.IsVisible = true;
            // Get position relative to the drag canvas (which covers the whole view)
            var p = targetElement.TranslatePoint(new Point(0, 0), HoneycombDragCanvas);
            if (p.HasValue)
            {
                CursorHighlightBorder.Width = targetElement.Bounds.Width;
                CursorHighlightBorder.Height = targetElement.Bounds.Height;
                Canvas.SetLeft(CursorHighlightBorder, p.Value.X);
                Canvas.SetTop(CursorHighlightBorder, p.Value.Y);
            }
        }
    }
}
