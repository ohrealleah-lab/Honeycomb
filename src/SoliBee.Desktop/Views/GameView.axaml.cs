using System;
using System.Collections.Generic;
using System.ComponentModel;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Threading;
using Avalonia.Input;
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
            vm.WasteCardDrawn += ViewModel_WasteCardDrawn;
            ApplyFeltColor(vm.Options);
            BindPiles(vm);
        }
        VictoryOverlay.PlayAgainRequested += VictoryOverlay_PlayAgainRequested;
        ArmDealNudgeTimer();
        TopLevel.GetTopLevel(this)?.AddHandler(InputElement.KeyDownEvent, OnKeyDown, RoutingStrategies.Tunnel);
    }

    private void GameView_Unloaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is GameViewModel vm)
        {
            vm.PropertyChanged -= ViewModel_PropertyChanged;
            vm.WasteCardDrawn -= ViewModel_WasteCardDrawn;
        }
        WeakReferenceMessenger.Default.Unregister<OptionsChangedMessage>(this);
        WeakReferenceMessenger.Default.Unregister<FaceCardArtChangedMessage>(this);
        VictoryOverlay.PlayAgainRequested -= VictoryOverlay_PlayAgainRequested;
        CardView.ClearPileViewCache(this);
        StopDealNudge();
        TopLevel.GetTopLevel(this)?.RemoveHandler(InputElement.KeyDownEvent, OnKeyDown);
    }

    // ── Keyboard cursor: per-game grid + hotkeys ────────────────────────────────────
    // Row 0: Stock, Waste, (gap — mirrors the visual layout's empty slot), Foundations
    // 0-3. Row 1: Tableaus 0-6.
    protected override List<List<PileView?>> BuildCursorGrid() => new()
    {
        new List<PileView?> { StockPileControl, WastePileControl, null, Foundation0, Foundation1, Foundation2, Foundation3 },
        new List<PileView?> { Tableau0, Tableau1, Tableau2, Tableau3, Tableau4, Tableau5, Tableau6 },
    };

    // Space/Return on the Stock pile draws, same as clicking it — Stock has no
    // selectable card of its own, so without this the cursor landing there just no-ops.
    protected override bool TryActivateEmptyCursorPile(PileView pile)
    {
        if (pile != StockPileControl || DataContext is not GameViewModel vm) return false;
        // Only arm a restore if the draw actually did something — DrawCard silently
        // no-ops on an empty, recycle-exhausted Stock (see the D-hotkey comment above).
        int movesBefore = vm.State.MovesCount;
        vm.DrawCard();
        if (vm.State.MovesCount != movesBefore) ArmCursorRestore(StockPileControl);
        SoundService.PlayShuffle();
        return true;
    }

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (DataContext is not GameViewModel vm) return;
        // Don't steal letter/symbol keystrokes while the user is typing in a TextBox
        // (e.g. the Save Theme name field). Tunnel handlers fire before the focused
        // control, so without this guard 'A'/'F' trigger game actions mid-typing.
        if (TopLevel.GetTopLevel(this)?.FocusManager?.GetFocusedElement() is TextBox) return;

        switch (e.Key)
        {
            case Key.Escape:
                if (!HasCursor && SelectedCardView == null) return; // let MainWindow handle closing dialogs
                ClearCursorAndSelection();
                e.Handled = true;
                break;
            case Key.Up:    MoveCursor(-1, 0); e.Handled = true; break;
            case Key.Down:  MoveCursor(1, 0);  e.Handled = true; break;
            case Key.Left:  MoveCursor(0, -1); e.Handled = true; break;
            case Key.Right: MoveCursor(0, 1);  e.Handled = true; break;
            case Key.Space: case Key.Enter:
                ActivateCursor(); e.Handled = true; break;
            case Key.D:
                {
                    // Draw doesn't touch wherever the cursor currently is, but Stock/Waste
                    // changing still fires the same clear-on-pile-change wiring other
                    // triggers rely on — arm a restore so the cursor doesn't vanish under
                    // it. Only if the draw actually did something: DrawCard silently
                    // no-ops on an empty, recycle-exhausted Stock, and arming for a no-op
                    // would leave a stale restore target that a later, unrelated pile
                    // change (even Undo) would wrongly consume.
                    int movesBefore = vm.State.MovesCount;
                    vm.DrawCard();
                    if (HasCursor && vm.State.MovesCount != movesBefore) ArmCursorRestore(CursorPile!);
                }
                SoundService.PlayShuffle(); e.Handled = true; break;
            case Key.F:
                if (CursorPile?.Pile != null && CursorCardIndex >= 0 && CursorCardIndex < CursorPile.Pile.Cards.Count)
                {
                    var pile = CursorPile;
                    if (TryAutoMoveToFoundation(pile.Pile.Cards[CursorCardIndex], pile.Pile))
                        ArmCursorRestore(pile);
                }
                e.Handled = true; break;
            case Key.A:
                vm.Autocomplete(); e.Handled = true; break;
        }
    }

    // Nudges a new/idle Klondike game: if the player hasn't made a single move within
    // 5s of a deal, pulse the stock pile twice, then clear the highlight when the last
    // pulse ends (matching the regular Hint feature's 2s auto-dismiss) rather than
    // leaving it lit until a move happens. Re-armed on every new deal (State change) and
    // canceled the instant any real move is made — polling MovesCount at tick time
    // (rather than wiring a dedicated "move made" event) means this stays correct even
    // though the initial deal itself raises the same Stock/Waste/Foundations/Tableaus
    // notifications a real move does. Respects HideHintButton, same as the regular Hint
    // feature — re-checked before each repeat pulse too, not just the initial one.
    private const int DealNudgePulseCount = 2;
    private static readonly TimeSpan DealNudgePulseDuration = TimeSpan.FromSeconds(2);
    private DispatcherTimer? _dealNudgeArmTimer;
    private DispatcherTimer? _dealNudgeClearTimer;
    private int _dealNudgePulsesRemaining;

    private void ArmDealNudgeTimer()
    {
        if (DataContext is GameViewModel vm0 && vm0.Options.HideHintButton) { StopDealNudge(); return; }

        _dealNudgeArmTimer = ArmOneShotTimer(_dealNudgeArmTimer, TimeSpan.FromSeconds(5), () =>
        {
            _dealNudgeArmTimer = null;
            if (DataContext is GameViewModel vm && !vm.Options.HideHintButton
                && vm.State.MovesCount == 0 && !vm.State.HasWon)
            {
                _dealNudgePulsesRemaining = DealNudgePulseCount;
                PulseDealNudge();
            }
        });
    }

    private void PulseDealNudge()
    {
        StockPileControl.ShowHint();
        _dealNudgePulsesRemaining--;
        _dealNudgeClearTimer = ArmOneShotTimer(_dealNudgeClearTimer, DealNudgePulseDuration, () =>
        {
            _dealNudgeClearTimer = null;
            if (_dealNudgePulsesRemaining > 0
                && DataContext is GameViewModel vm && !vm.Options.HideHintButton
                && vm.State.MovesCount == 0 && !vm.State.HasWon)
            {
                PulseDealNudge();
            }
            else
            {
                StockPileControl?.ClearHint();
            }
        });
    }

    private void StopDealNudge()
    {
        _dealNudgeArmTimer?.Stop();
        _dealNudgeArmTimer = null;
        _dealNudgeClearTimer?.Stop();
        _dealNudgeClearTimer = null;
        _dealNudgePulsesRemaining = 0;
        StockPileControl?.ClearHint();
    }

    private void VictoryOverlay_PlayAgainRequested(object? sender, EventArgs e)
    {
        if (DataContext is GameViewModel vm) vm.InitializeGame();
    }

    private void ViewModel_WasteCardDrawn(object? sender, EventArgs e)
    {
        Avalonia.Threading.Dispatcher.UIThread.InvokeAsync(() =>
        {
            AnimateTopWasteCard();
        });
    }

    private void ViewModel_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        Avalonia.Threading.Dispatcher.UIThread.InvokeAsync(() =>
        {
            if (e.PropertyName == nameof(GameViewModel.State))
            {
                // New game / restart — the pile contents underneath any cached cursor
                // position or pending selection are about to be entirely replaced.
                ClearCursorAndSelection();
                if (DataContext is GameViewModel vm && vm.State.HasWon)
                    TriggerVictoryCascade();
                else
                {
                    _winTriggered = false;
                    VictoryOverlay.StopAnimation();
                    VictoryOverlay.IsVisible = false;
                    ArmDealNudgeTimer();
                }
            }
            else if (e.PropertyName == nameof(GameViewModel.IsAutocompletable) ||
                     e.PropertyName == nameof(GameViewModel.IsAutoplayRunning))
            {
                if (DataContext is GameViewModel vm)
                {
                    if (vm.IsAutoplayRunning) ClearCursorAndSelection();
                    AutocompleteBanner.IsVisible = vm.IsAutocompletable && !vm.IsAutoplayRunning;
                }
            }
            else if (e.PropertyName == nameof(GameViewModel.Stock))
            {
                // Any move (or Undo) that touched Stock/Waste/Foundations/Tableaus can
                // shrink/replace the pile a cached cursor index points into, so the
                // cursor always clears — but the selection only clears if it's no
                // longer actually there, so drawing from Stock doesn't silently cancel
                // an unrelated pending Tableau selection (see CardGameView remarks).
                ClearStaleCursorAndSelection();
                StockPileControl.UpdateCardsLayout();
                if (DataContext is GameViewModel vm && vm.State.MovesCount > 0) StopDealNudge();
            }
            else if (e.PropertyName == nameof(GameViewModel.Waste))
            {
                ClearStaleCursorAndSelection();
                WastePileControl.UpdateCardsLayout();
                if (DataContext is GameViewModel vm && vm.State.MovesCount > 0) StopDealNudge();
            }
            else if (e.PropertyName == "Foundations")
            {
                ClearStaleCursorAndSelection();
                Foundation0.UpdateCardsLayout();
                Foundation1.UpdateCardsLayout();
                Foundation2.UpdateCardsLayout();
                Foundation3.UpdateCardsLayout();
                if (DataContext is GameViewModel vm && vm.State.HasWon) TriggerVictoryCascade();
                if (DataContext is GameViewModel vm2 && vm2.State.MovesCount > 0) StopDealNudge();
            }
            else if (e.PropertyName == "Tableaus")
            {
                ClearStaleCursorAndSelection();
                Tableau0.UpdateCardsLayout();
                Tableau1.UpdateCardsLayout();
                Tableau2.UpdateCardsLayout();
                Tableau3.UpdateCardsLayout();
                Tableau4.UpdateCardsLayout();
                Tableau5.UpdateCardsLayout();
                Tableau6.UpdateCardsLayout();
                if (DataContext is GameViewModel vm && vm.State.HasWon) TriggerVictoryCascade();
                if (DataContext is GameViewModel vm2 && vm2.State.MovesCount > 0) StopDealNudge();
            }
            else if (e.PropertyName == nameof(GameViewModel.HasNoMoves))
            {
                if (DataContext is GameViewModel vm)
                {
                    if (vm.HasNoMoves) NoMovesStatsLabel.Text = WinAnimationView.FormatStatsLine(vm.ScoreDisplay, vm.TimeDisplay);
                    NoMovesBanner.IsVisible = vm.HasNoMoves;
                }
            }
            else if (e.PropertyName == nameof(GameViewModel.ActiveHint))
            {
                if (DataContext is GameViewModel vm)
                    ApplyHint(vm.ActiveHint, AllPileViews());
            }
        });
    }

    protected override void ClearActiveHint()
    {
        if (DataContext is GameViewModel vm) vm.ClearHintCycle();
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

    private bool _winTriggered;

    private void ApplyFeltColor(GameOptions options)
    {
        // Transparent, not an opaque repaint: the window background behind (MainWindow.ApplyFeltColor)
        // already carries this same felt color, and staying transparent here lets the single
        // app-wide vignette overlay (rendered behind the board content) show through in the gaps.
        BoardFeltGrid.Background = Brushes.Transparent;
    }

    private void AutocompleteGame_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not GameViewModel vm) return;
        AutocompleteBanner.IsVisible = false;
        vm.Autocomplete();
        e.Handled = true;
    }

    private void NoMovesNewGame_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not GameViewModel vm) return;
        NoMovesBanner.IsVisible = false;
        AutocompleteBanner.IsVisible = false;
        vm.InitializeGame();
        SoundService.PlayShuffle();
        e.Handled = true;
    }

    private void NoMovesRestart_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not GameViewModel vm) return;
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

    private void StockPileControl_Clicked(object? sender, EventArgs e)
    {
        if (DataContext is GameViewModel vm)
        {
            vm.DrawCard();
            SoundService.PlayShuffle();
        }
    }

    private IEnumerable<PileView> AllPileViews() =>
        new PileView[] { StockPileControl, WastePileControl,
            Foundation0, Foundation1, Foundation2, Foundation3,
            Tableau0, Tableau1, Tableau2, Tableau3, Tableau4, Tableau5, Tableau6 };

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

    private void AnimateTopWasteCard()
    {
        var canvas = WastePileControl.FindControl<Avalonia.Controls.Canvas>("CardsCanvas");
        if (canvas == null || canvas.Children.Count == 0) return;
        if (canvas.Children[^1] is CardView cv && cv.Card?.IsFaceUp == true)
            cv.BeginSlideIn(-48, 0, 200);
    }

    private List<Point> ComputeFoundationSpawnPoints()
    {
        var views = new[] { Foundation0, Foundation1, Foundation2, Foundation3 };
        var pts = new List<Point>(views.Length);
        foreach (var fv in views)
        {
            var topLeft = fv.TranslatePoint(new Point(0, 0), this) ?? default;
            pts.Add(new Point(topLeft.X + fv.Bounds.Width / 2.0, topLeft.Y));
        }
        return pts;
    }

    private void TriggerVictoryCascade()
    {
        if (_winTriggered) return;
        _winTriggered = true;
        VictoryOverlay.IsVisible = true;
        if (DataContext is GameViewModel vm)
        {
            Dispatcher.UIThread.Post(() => {
                VictoryOverlay.StartAnimation(vm.Foundations, ComputeFoundationSpawnPoints(), vm.ScoreDisplay, !vm.Options.IsNoStressMode ? vm.TimeDisplay : "");
            }, DispatcherPriority.Loaded);
        }
        else
        {
            VictoryOverlay.StartAnimation();
        }
        SoundService.PlaySolitaireWin();
    }

    // Dev-only banner preview, wired to the toolbar's local-only "Banners" dropdown
    // (the dropdown itself is only made visible in DEBUG builds — see MainWindow).
    public void DebugShowWinBanner()
    {
        VictoryOverlay.IsVisible = true;
        if (DataContext is GameViewModel vm)
        {
            Dispatcher.UIThread.Post(() => {
                VictoryOverlay.StartAnimation(vm.Foundations, ComputeFoundationSpawnPoints(), vm.ScoreDisplay, !vm.Options.IsNoStressMode ? vm.TimeDisplay : "");
            }, DispatcherPriority.Loaded);
        }
        else
        {
            VictoryOverlay.StartAnimation();
        }
    }

    // Dev-only — always plays the full demo cascade (the no-arg overload's fake 52-card
    // deck) regardless of the real foundations' current contents, so the bouncing-card
    // animation itself can be reviewed even mid-game when few/no cards are actually up.
    public void DebugPlayWinAnimation()
    {
        VictoryOverlay.IsVisible = true;
        Dispatcher.UIThread.Post(() => {
            VictoryOverlay.StartAnimation(ComputeFoundationSpawnPoints());
        }, DispatcherPriority.Loaded);
        SoundService.PlaySolitaireWin();
    }

    public void DebugShowLossBanner()
    {
        if (DataContext is GameViewModel vm)
            NoMovesStatsLabel.Text = WinAnimationView.FormatStatsLine(vm.ScoreDisplay, vm.TimeDisplay);
        NoMovesBanner.IsVisible = true;
    }

    public void DebugShowAutocompleteBanner() => AutocompleteBanner.IsVisible = true;

}
