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
    // Column gap narrows above 1.0x zoom so columns don't overflow horizontally; floors at 4px.
    public void ApplyZoomGap(double zoom)
    {
        const double baseGap = 12;
        double gap = zoom <= 1.0 ? baseGap : Math.Max(4, baseGap - (baseGap - 4) * (zoom - 1.0));
        for (int i = 1; i < BoardGrid.ColumnDefinitions.Count; i += 2)
            BoardGrid.ColumnDefinitions[i] = new ColumnDefinition(gap, GridUnitType.Pixel);
        BoardGrid.Width = 10 * 128 + 9 * gap;
    }

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
        // Spider auto-completes full runs to foundations itself; there's no manual
        // move-to-foundation action for the F hotkey (which Spider doesn't have) to call.
        // Double-click uses TryHandleDoubleClick below instead, not this method.
        return false;
    }

    // Double-click moves the clicked card (and everything stacked below it) to the best
    // available tableau target: a same-suit build first (keeps the run completable to a
    // foundation later), then any other legal rank-matching target, then an empty column
    // — matching the Mac original's double-click priority order exactly.
    public override bool TryHandleDoubleClick(Card card, Pile sourcePile)
    {
        if (DataContext is not SpiderViewModel vm) return false;
        if (sourcePile.Type != PileType.Tableau) return false;

        int idx = sourcePile.Cards.IndexOf(card);
        if (idx < 0) return false;
        var cardsToMove = sourcePile.Cards.GetRange(idx, sourcePile.Cards.Count - idx);

        Pile? sameSuitTarget = null;
        Pile? anySuitTarget = null;
        Pile? emptyTarget = null;
        foreach (var tgt in vm.Tableaus)
        {
            if (tgt.Id == sourcePile.Id) continue;
            if (!vm.CanMoveSequence(cardsToMove, tgt)) continue;

            if (tgt.Cards.Count == 0)
            {
                emptyTarget ??= tgt;
            }
            else
            {
                if (sameSuitTarget == null && tgt.Cards.Last().Suit == cardsToMove[0].Suit)
                    sameSuitTarget = tgt;
                anySuitTarget ??= tgt;
            }
        }

        var chosen = sameSuitTarget ?? anySuitTarget ?? emptyTarget;
        return chosen != null && TryMoveCards(cardsToMove, sourcePile, chosen);
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
        TopLevel.GetTopLevel(this)?.AddHandler(InputElement.KeyDownEvent, OnKeyDown, RoutingStrategies.Tunnel);
    }

    private void SpiderView_Unloaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is SpiderViewModel vm)
            vm.PropertyChanged -= ViewModel_PropertyChanged;
        VictoryOverlay.PlayAgainRequested -= VictoryOverlay_PlayAgainRequested;
        WeakReferenceMessenger.Default.Unregister<FaceCardArtChangedMessage>(this);
        CardView.ClearPileViewCache(this);
        TopLevel.GetTopLevel(this)?.RemoveHandler(InputElement.KeyDownEvent, OnKeyDown);
    }

    // ── Keyboard cursor: per-game grid + hotkeys ────────────────────────────────────
    // Row 0: the stock, as a single reachable target (StockCursorPileView — a Pile-less
    // PileView that exists purely to give the shared cursor machinery a real target;
    // see its styles in SpiderView.axaml). Row 1: the 10 tableau columns. No Foundations
    // row — Spider auto-completes full runs to foundations itself, there's never a
    // manual move there (TryAutoMoveToFoundation always returns false, above).
    protected override List<List<PileView?>> BuildCursorGrid() => new()
    {
        new List<PileView?> { StockCursorPileView },
        new List<PileView?> { Tableau0, Tableau1, Tableau2, Tableau3, Tableau4, Tableau5, Tableau6, Tableau7, Tableau8, Tableau9 },
    };

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (DataContext is not SpiderViewModel vm) return;

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
                TryDealFromStock(vm); e.Handled = true; break;
            case Key.A:
                vm.Autocomplete(); e.Handled = true; break;
        }
    }

    // Shared by the keyboard D hotkey and the mouse stock-click path, so a deal blocked
    // by an empty tableau column gets the same visible warning on either input path
    // instead of a silent no-op (a player pressing D has no other way to know why
    // nothing happened). A deal blocked because the stock itself is empty needs no
    // banner — the stock's own empty-slot outline already makes that obvious.
    private void TryDealFromStock(SpiderViewModel vm)
    {
        if (vm.CanDealFromStock)
        {
            // Preserve wherever the cursor already is (D doesn't require it to be on
            // Stock) so the Tableaus/StockPiles notification this deal raises doesn't
            // wipe it — the mouse path already relinquished the cursor before calling
            // in here, so `pile` is null there and this is naturally a no-op for clicks.
            var pile = CursorPile;
            vm.DealFromStock();
            SoundService.PlayShuffle();
            if (pile != null) ArmCursorRestore(pile);
            return;
        }
        if (vm.StockPiles.Count > 0 && vm.Tableaus.Any(t => t.Cards.Count == 0))
            ShowDealBlockedWarning();
    }

    private DispatcherTimer? _dealBlockedDismissTimer;

    private void ShowDealBlockedWarning()
    {
        DealBlockedBanner.IsVisible = true;
        _dealBlockedDismissTimer = ArmOneShotTimer(_dealBlockedDismissTimer, TimeSpan.FromSeconds(3), () =>
        {
            _dealBlockedDismissTimer = null;
            DealBlockedBanner.IsVisible = false;
        });
    }

    private void DealBlockedDismiss_Click(object? sender, RoutedEventArgs e)
    {
        _dealBlockedDismissTimer?.Stop();
        _dealBlockedDismissTimer = null;
        DealBlockedBanner.IsVisible = false;
        e.Handled = true;
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
                // New game / restart — the pile contents underneath any cached cursor
                // position or pending selection are about to be entirely replaced.
                ClearCursorAndSelection();
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
                // Any move (or Undo) that touched a pile can shrink/replace it out from
                // under a cached cursor index, so the cursor always clears — but the
                // selection only clears if it's no longer actually there, so an
                // unrelated pile's own change doesn't silently cancel a pending
                // selection elsewhere on the board.
                ClearStaleCursorAndSelection();
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
                ClearStaleCursorAndSelection();
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
                ClearStaleCursorAndSelection();
                UpdateStockDisplay(vm);
            }
            else if (e.PropertyName == nameof(SpiderViewModel.HasNoMoves))
            {
                if (vm.HasNoMoves) NoMovesStatsLabel.Text = WinAnimationView.FormatStatsLine(vm.ScoreDisplay, vm.TimeDisplay);
                NoMovesBanner.IsVisible = vm.HasNoMoves;
            }
            else if (e.PropertyName == nameof(SpiderViewModel.IsAutocompletable) ||
                     e.PropertyName == nameof(SpiderViewModel.IsAutoplayRunning))
            {
                if (vm.IsAutoplayRunning) ClearCursorAndSelection();
                AutocompleteBanner.IsVisible = vm.IsAutocompletable && !vm.IsAutoplayRunning;
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

    protected override void ClearActiveHint()
    {
        if (DataContext is SpiderViewModel vm) vm.ClearHintCycle();
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
        RelinquishKeyboardCursor();
        TryDealFromStock(vm);
        e.Handled = true;
    }

    private bool _winTriggered;

    private List<Point> ComputeFoundationSpawnPoints()
    {
        var views = new[] { Foundation0, Foundation1, Foundation2, Foundation3, Foundation4, Foundation5, Foundation6, Foundation7 };
        var pts = new List<Point>(views.Length);
        foreach (var fv in views)
        {
            var topLeft = fv.TranslatePoint(new Point(0, 0), this) ?? default;
            pts.Add(new Point(topLeft.X + fv.Bounds.Width / 2.0, topLeft.Y));
        }
        return pts;
    }

    // The "You win" banner defaults to centering on VictoryOverlay's full bounds (which
    // span the whole window, for the bouncing-card cascade's room to fall) rather than
    // the board's actual content, on either axis — e.g. drifting off horizontal-center
    // under the zoom feature's LayoutTransformControl. Center on the real board's actual
    // midpoint, both axes, instead.
    private Point? ComputeBoardCenter() =>
        BoardGrid.TranslatePoint(new Point(BoardGrid.Bounds.Width / 2.0, BoardGrid.Bounds.Height / 2.0), VictoryOverlay);

    private void TriggerVictoryCascade()
    {
        if (_winTriggered) return;
        _winTriggered = true;
        VictoryOverlay.IsVisible = true;
        if (DataContext is SpiderViewModel vm)
        {
            Dispatcher.UIThread.Post(() => {
                VictoryOverlay.StartAnimation(vm.Foundations, ComputeFoundationSpawnPoints(), vm.ScoreDisplay, !vm.Options.IsNoStressMode ? vm.TimeDisplay : "", ComputeBoardCenter());
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
        if (DataContext is SpiderViewModel vm)
        {
            Dispatcher.UIThread.Post(() => {
                VictoryOverlay.StartAnimation(vm.Foundations, ComputeFoundationSpawnPoints(), vm.ScoreDisplay, !vm.Options.IsNoStressMode ? vm.TimeDisplay : "", ComputeBoardCenter());
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
            VictoryOverlay.StartAnimation(ComputeFoundationSpawnPoints(), ComputeBoardCenter());
        }, DispatcherPriority.Loaded);
        SoundService.PlaySolitaireWin();
    }

    public void DebugShowLossBanner()
    {
        if (DataContext is SpiderViewModel vm)
            NoMovesStatsLabel.Text = WinAnimationView.FormatStatsLine(vm.ScoreDisplay, vm.TimeDisplay);
        NoMovesBanner.IsVisible = true;
    }

    public void DebugShowAutocompleteBanner() => AutocompleteBanner.IsVisible = true;

    private void NoMovesNewGame_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not SpiderViewModel vm) return;
        NoMovesBanner.IsVisible = false;
        AutocompleteBanner.IsVisible = false;
        vm.InitializeGame();
        SoundService.PlayShuffle();
        e.Handled = true;
    }

    private void NoMovesRestart_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not SpiderViewModel vm) return;
        NoMovesBanner.IsVisible = false;
        AutocompleteBanner.IsVisible = false;
        vm.RestartGame();
        SoundService.PlayShuffle();
        e.Handled = true;
    }

    private void AutocompleteGame_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not SpiderViewModel vm) return;
        AutocompleteBanner.IsVisible = false;
        vm.Autocomplete();
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
            catch { BoardFeltGrid.Background = new SolidColorBrush(Avalonia.Media.Colors.Black); }
            return;
        }

        // Transparent, not an opaque repaint: the window background behind (MainWindow.ApplyFeltColor)
        // already carries this same felt color, and staying transparent here lets the single
        // app-wide vignette overlay (rendered behind the board content) show through in the gaps.
        BoardFeltGrid.Background = Brushes.Transparent;
    }
}
