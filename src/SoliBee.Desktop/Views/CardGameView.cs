using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Threading;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public abstract class CardGameView : UserControl
{
    public CardView? SelectedCardView { get; set; }
    public Pile? SelectedSourcePile { get; set; }

    // Shared by CardView/PileView's PointerPressed handlers to find the ancestor
    // CardGameView instance whose cursor/selection state they need to mutate — the
    // one tree-walk implementation both used to duplicate independently.
    public static CardGameView? FindAncestorGameView(Avalonia.StyledElement? start)
    {
        var parent = start;
        while (parent != null)
        {
            if (parent is CardGameView cgv) return cgv;
            parent = parent.Parent;
        }
        return null;
    }

    public abstract bool CanMoveCards(List<Card> cards, Pile targetPile);
    public abstract bool TryMoveCards(List<Card> cards, Pile sourcePile, Pile targetPile);
    public abstract bool TryAutoMoveToFoundation(Card card, Pile sourcePile);

    // Handles a double-click on a face-up card. Default behavior is "try to auto-move it
    // to a foundation" — the same action Klondike/FreeCell's F hotkey performs — since
    // for those two games double-click-to-foundation is exactly what a double-click means.
    // Spider overrides this instead of TryAutoMoveToFoundation (which it leaves returning
    // false, since Spider auto-completes whole runs itself and has no F hotkey), because
    // its double-click targets a tableau column, not a foundation.
    public virtual bool TryHandleDoubleClick(Card card, Pile sourcePile) => TryAutoMoveToFoundation(card, sourcePile);

    // Called when a hint's on-screen timer expires, so the queue is cleared and the
    // next Hint press starts fresh rather than cycling to a hint that's no longer shown.
    protected abstract void ClearActiveHint();

    private readonly List<CardView> _hintedCardViews = new();
    private readonly List<PileView> _hintedPileViews = new();
    private DispatcherTimer? _hintAutoDismissTimer;

    protected void ApplyHint(HintMove? hint, IEnumerable<PileView> allPiles)
    {
        _hintAutoDismissTimer?.Stop();
        _hintAutoDismissTimer = null;

        foreach (var cv in _hintedCardViews) cv.ClearHint();
        _hintedCardViews.Clear();
        foreach (var pv in _hintedPileViews) pv.ClearHint();
        _hintedPileViews.Clear();

        if (hint == null) return;

        if (hint.Card.Id == "no_move")
        {
            StartDismissTimer();
            return;
        }

        var piles = allPiles.ToList();

        if (!string.IsNullOrEmpty(hint.SourcePileId))
        {
            var sourcePv = piles.FirstOrDefault(p => p.Pile?.Id == hint.SourcePileId);
            if (sourcePv?.Pile != null)
            {
                if (sourcePv.Pile.Type == PileType.Tableau)
                    HighlightStackFrom(sourcePv, hint.Card);
                else if (sourcePv.Pile.Type == PileType.Waste)
                    HighlightTopCard(sourcePv);
                else
                    HighlightWholePile(sourcePv);
            }
        }

        if (!string.IsNullOrEmpty(hint.TargetPileId))
        {
            var targetPv = piles.FirstOrDefault(p => p.Pile?.Id == hint.TargetPileId);
            if (targetPv?.Pile != null)
            {
                if ((targetPv.Pile.Type == PileType.Tableau || targetPv.Pile.Type == PileType.Waste) && targetPv.Pile.Cards.Count > 0)
                    HighlightTopCard(targetPv);
                else
                    HighlightWholePile(targetPv);
            }
        }

        StartDismissTimer();
    }

    private void HighlightStackFrom(PileView pv, Card fromCard)
    {
        var canvas = pv.FindControl<Canvas>("CardsCanvas");
        if (canvas == null || pv.Pile == null) return;
        int idx = pv.Pile.Cards.IndexOf(fromCard);
        if (idx < 0) return;
        for (int i = idx; i < canvas.Children.Count; i++)
        {
            if (canvas.Children[i] is CardView cv)
            {
                cv.ShowHint();
                _hintedCardViews.Add(cv);
            }
        }
    }

    private void HighlightTopCard(PileView pv)
    {
        var canvas = pv.FindControl<Canvas>("CardsCanvas");
        if (canvas == null || canvas.Children.Count == 0) return;
        if (canvas.Children[^1] is CardView cv)
        {
            cv.ShowHint();
            _hintedCardViews.Add(cv);
        }
    }

    private void HighlightWholePile(PileView pv)
    {
        pv.ShowHint();
        _hintedPileViews.Add(pv);
    }

    private void StartDismissTimer()
    {
        _hintAutoDismissTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
        _hintAutoDismissTimer.Tick += (_, _) =>
        {
            _hintAutoDismissTimer?.Stop();
            _hintAutoDismissTimer = null;
            ClearActiveHint();
        };
        _hintAutoDismissTimer.Start();
    }

    // Shared one-shot timer helper: stops `previous` if still running, then creates,
    // starts, and returns a new timer whose Tick fires `onElapsed` exactly once (having
    // already stopped itself first). Callers still null out their own field inside
    // `onElapsed` if "not currently armed" needs to be externally observable.
    protected static DispatcherTimer ArmOneShotTimer(DispatcherTimer? previous, TimeSpan delay, Action onElapsed)
    {
        previous?.Stop();
        DispatcherTimer? timer = null;
        timer = new DispatcherTimer { Interval = delay };
        timer.Tick += (_, _) =>
        {
            timer!.Stop();
            onElapsed();
        };
        timer.Start();
        return timer;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Keyboard cursor + context-sensitive select/move — shared by Klondike, Freecell,
    // and Spider (one navigation model, not per-game special cases). Arrow keys move a
    // focus cursor around a per-game grid of piles (built fresh by BuildCursorGrid every
    // time the cursor re-activates, so it can never go stale across a deck-count change,
    // new deal, etc). Space/Return is context-sensitive: nothing selected -> select the
    // focused card (or the run starting at it); something selected and cursor now on a
    // different legal target -> complete the move; cursor back on the same pile that's
    // selected -> deselect. Selection state (SelectedCardView/SelectedSourcePile above)
    // is the SAME state the mouse click-to-select path uses — keyboard and mouse are two
    // input modes mutating one shared selection, never two competing copies of it.
    //
    // Reset discipline: ClearCursorAndSelection is called unconditionally (never a
    // partial reset, never a "is the cached index still valid" check) on every trigger
    // that can invalidate a cached pile position — new game, restart, undo, autocomplete
    // starting, and any real move completing (mouse or keyboard) — because all of those
    // already raise the same Stock/Waste/Foundations/Tableaus property-changed
    // notifications each view already listens to, that's the one place per view this
    // needs to be wired in. RelinquishKeyboardCursor (cursor only, selection untouched)
    // is called from every mouse entry point in CardView/PileView's PointerPressed, so
    // any direct mouse interaction drops the keyboard focus indicator immediately.

    // Index into CursorPile.Pile.Cards that's focused; only meaningful for Tableau/Waste
    // piles (a real card is highlighted there). -1 = "whole pile" cursor (Stock,
    // Foundation, FreeCell, or an empty Tableau/Waste with no card to focus).
    protected int CursorCardIndex { get; private set; } = -1;
    protected bool HasCursor => CursorPile != null;

    private List<List<PileView?>>? _cursorGrid;
    private int _cursorRow = -1;
    private int _cursorCol = -1;

    // Computed, not stored — CursorPile is always exactly _cursorGrid[_cursorRow][_cursorCol]
    // (or null when no cursor is active). Deriving it instead of tracking a sixth field in
    // parallel makes the "reset one piece of cursor state but not the other" bug class
    // (called out explicitly in the remarks above) structurally impossible: there's no
    // separate CursorPile field that a future write site could forget to null alongside
    // _cursorRow/_cursorCol.
    protected PileView? CursorPile =>
        _cursorGrid != null && _cursorRow >= 0 && _cursorRow < _cursorGrid.Count
            && _cursorCol >= 0 && _cursorCol < _cursorGrid[_cursorRow].Count
            ? _cursorGrid[_cursorRow][_cursorCol]
            : null;

    // Per-game: the focusable-pile grid, rows top-to-bottom, left-to-right within a row.
    // A null entry is a gap (e.g. Klondike's spacer slot between Waste and Foundations)
    // that Left/Right skip over.
    protected abstract List<List<PileView?>> BuildCursorGrid();

    private static int DefaultCardIndexFor(PileView pv)
    {
        var pile = pv.Pile;
        if (pile == null || pile.Cards.Count == 0) return -1;
        return pile.Type is PileType.Tableau or PileType.Waste ? pile.Cards.Count - 1 : -1;
    }

    // Waste's CardsCanvas only ever renders the currently-visible fan — the pile's real
    // top card plus, in Draw-3 mode, up to two older cards shown behind it purely for
    // visibility — not a 1:1 mirror of Pile.Cards like every other pile type's canvas.
    // modelIndex is a model index (Pile.Cards.Count - 1, from DefaultCardIndexFor, so it
    // lines up with what the F-hotkey handlers and ActivateCursor's move-range math
    // expect); this translates it down to the matching canvas slot. Without this, a
    // Waste with more history than its fan shows (Draw-3 mode has more than 3 total, or
    // any Draw-1 waste beyond the very first card) either looks up past the end of
    // Children (falling back to a whole-pile cursor) or grabs an older, buried card
    // instead of the real top one — letting a move accidentally sweep in the whole fan.
    // Pulled out into its own named helper (rather than left inline in GetCardViewAt)
    // so this pile-type special case can't be missed by a future reader, and so any
    // future pile type that also filters its canvas (e.g. a fanned Stock) has an
    // obvious place to add its own translation instead of another inline branch.
    private static int? WasteCanvasIndexFor(Pile wastePile, Canvas canvas, int modelIndex)
    {
        int canvasIndex = modelIndex - (wastePile.Cards.Count - canvas.Children.Count);
        return canvasIndex >= 0 && canvasIndex < canvas.Children.Count ? canvasIndex : null;
    }

    private static CardView? GetCardViewAt(PileView pv, int cardIndex)
    {
        var canvas = pv.FindControl<Canvas>("CardsCanvas");
        if (canvas == null || cardIndex < 0) return null;

        if (pv.Pile?.Type == PileType.Waste)
        {
            int? canvasIndex = WasteCanvasIndexFor(pv.Pile, canvas, cardIndex);
            return canvasIndex.HasValue ? canvas.Children[canvasIndex.Value] as CardView : null;
        }

        if (cardIndex >= canvas.Children.Count) return null;
        return canvas.Children[cardIndex] as CardView;
    }

    private void ShowCursorVisual()
    {
        if (CursorPile?.Pile == null) return;
        if (CursorCardIndex >= 0)
        {
            var cv = GetCardViewAt(CursorPile, CursorCardIndex);
            if (cv != null) { cv.ShowCursor(); return; }
        }
        CursorPile.ShowCursor();
    }

    private void ClearCursorVisual()
    {
        if (CursorPile?.Pile == null) return;
        if (CursorCardIndex >= 0)
            GetCardViewAt(CursorPile, CursorCardIndex)?.ClearCursor();
        CursorPile.ClearCursor();
    }

    private void SetCursor(int row, int col, int cardIndex)
    {
        ClearCursorVisual();
        _cursorRow = row;
        _cursorCol = col;
        CursorCardIndex = cardIndex;
        ShowCursorVisual();
    }

    private void EnsureCursorActive()
    {
        if (CursorPile != null) return;
        _cursorGrid = BuildCursorGrid();

        // A pending selection (most commonly a mouse click-to-select, which relinquishes
        // the keyboard cursor but deliberately leaves the selection itself alone) should
        // keep "the selector" on the selected card — resume the cursor there instead of
        // defaulting to the grid's first slot (e.g. Klondike's stock/deal pile), which
        // would otherwise make the cursor jump somewhere the player never asked for.
        if (SelectedSourcePile != null)
        {
            for (int r = 0; r < _cursorGrid.Count; r++)
            {
                for (int c = 0; c < _cursorGrid[r].Count; c++)
                {
                    var pv = _cursorGrid[r][c];
                    if (pv?.Pile != SelectedSourcePile) continue;
                    int idx = SelectedCardView?.Card != null ? pv.Pile!.Cards.IndexOf(SelectedCardView.Card) : -1;
                    SetCursor(r, c, idx >= 0 ? idx : DefaultCardIndexFor(pv));
                    return;
                }
            }
        }

        for (int r = 0; r < _cursorGrid.Count; r++)
        {
            for (int c = 0; c < _cursorGrid[r].Count; c++)
            {
                if (_cursorGrid[r][c] != null)
                {
                    SetCursor(r, c, DefaultCardIndexFor(_cursorGrid[r][c]!));
                    return;
                }
            }
        }
    }

    // Cursor only — leaves any pending selection alone, since mouse and keyboard
    // deliberately share selection state. Call from every mouse PointerPressed entry
    // point so any direct mouse interaction relinquishes keyboard focus immediately.
    // Public: CardView/PileView call this on a CardGameView instance they've walked up
    // to, not on themselves — a protected member isn't visible across that sibling call.
    public void RelinquishKeyboardCursor()
    {
        if (CursorPile == null) return;
        ClearCursorVisual();
        _cursorGrid = null;
        _cursorRow = -1;
        _cursorCol = -1;
        CursorCardIndex = -1;
    }

    // Set right before a keyboard-completed move (ActivateCursor's Space/Return success
    // path) so the Stock/Waste/Foundations/Tableaus notification that move triggers
    // re-engages the cursor on the pile the card just landed in, instead of the generic
    // "wipe it" behavior every other trigger on that same notification wants (mouse
    // moves already have a null CursorPile by this point; Undo/autocomplete genuinely
    // want a full wipe). Consumed (nulled) by the very next ClearCursorAndSelection call.
    private PileView? _pendingCursorRestoreTarget;

    // Only a keyboard-driven action sets this — call right before/after a keyboard
    // hotkey mutates a pile (ActivateCursor's Space/Return move, or a per-game D/F/C
    // hotkey), passing the pile the cursor should still be on afterward — usually
    // CursorPile itself, captured before the action so it survives whatever the action
    // does to the model. Protected so per-game OnKeyDown handlers (D/F/C) can use it too.
    protected void ArmCursorRestore(PileView targetPileView) => _pendingCursorRestoreTarget = targetPileView;

    // Cursor AND selection together, unconditionally — call on a trigger that replaces
    // or invalidates the whole board regardless of what the selection currently points
    // at: new game, restart, autocomplete starting. (Restart in particular re-deals the
    // *exact same* shuffle, so a selected card can end up back in the exact same pile —
    // re-validating instead of hard-clearing would wrongly leave that selection alive.)
    protected void ClearCursorAndSelection() => ClearCursorAndSelectionCore(revalidateSelection: false);

    // Cursor always clears (its cached position/index is tied to a specific pile's
    // current on-screen layout, which just changed) but the SELECTION only clears if
    // it's no longer actually present in its source pile — call from a generic
    // Stock/Waste/Foundations/Tableaus-changed notification, which fires for every
    // move (including ones in a completely different pile than the pending selection)
    // and previously wiped an untouched selection right along with the cursor.
    protected void ClearStaleCursorAndSelection() => ClearCursorAndSelectionCore(revalidateSelection: true);

    private void ClearCursorAndSelectionCore(bool revalidateSelection)
    {
        var restoreTarget = _pendingCursorRestoreTarget;
        _pendingCursorRestoreTarget = null;

        RelinquishKeyboardCursor();
        if (SelectedCardView != null)
        {
            bool stillValid = revalidateSelection
                && SelectedSourcePile != null && SelectedCardView.Card != null
                && SelectedSourcePile.Cards.Contains(SelectedCardView.Card);
            if (!stillValid)
            {
                SelectedCardView.ClearSelection();
                SelectedCardView = null;
                SelectedSourcePile = null;
            }
        }

        if (restoreTarget != null)
        {
            // A single move can raise more than one of these notifications (e.g.
            // MoveCard always touches both Foundations and Tableaus) and each view's
            // per-pile UpdateCardsLayout() calls that follow this one haven't run yet —
            // defer to the next dispatcher iteration so the target pile's CardsCanvas
            // already reflects the just-moved card by the time we look for it.
            Dispatcher.UIThread.Post(() => RestoreCursorTo(restoreTarget));
        }
    }

    private void RestoreCursorTo(PileView targetPileView)
    {
        _cursorGrid = BuildCursorGrid();
        for (int r = 0; r < _cursorGrid.Count; r++)
        {
            for (int c = 0; c < _cursorGrid[r].Count; c++)
            {
                if (_cursorGrid[r][c] == targetPileView)
                {
                    SetCursor(r, c, DefaultCardIndexFor(targetPileView));
                    return;
                }
            }
        }
    }

    private int FindNearestNonNullColumn(int row, int preferredCol)
    {
        var r = _cursorGrid![row];
        if (preferredCol < r.Count && r[preferredCol] != null) return preferredCol;
        for (int d = 1; d < r.Count; d++)
        {
            int left = preferredCol - d, right = preferredCol + d;
            if (left >= 0 && left < r.Count && r[left] != null) return left;
            if (right >= 0 && right < r.Count && r[right] != null) return right;
        }
        return -1;
    }

    // rowDelta/colDelta: exactly one should be non-zero, -1 (Up/Left) or +1 (Down/Right).
    protected void MoveCursor(int rowDelta, int colDelta)
    {
        // A fresh engagement (cursor was null — either the very first arrow press of the
        // session, or one relinquished by a mouse click that left a pending selection)
        // consumes this keypress purely to reveal the cursor where EnsureCursorActive
        // put it. Applying rowDelta/colDelta on top of that same press would silently
        // step the cursor one cell past wherever it just landed — e.g. a mouse-selected
        // card in the leftmost tableau column, followed by Up, would land the cursor on
        // Stock (row 0's own leftmost slot) instead of revealing it on the selected card.
        bool wasInactive = CursorPile == null;
        EnsureCursorActive();
        if (wasInactive) return;
        if (CursorPile == null || _cursorGrid == null) return;

        // Within a Tableau column, Up/Down walk the focused card through that column's
        // face-up run before switching rows — Up moves toward earlier (less-buried,
        // visually higher) cards, Down moves toward the most recently played (bottom of
        // the fan) card and stops there (no row below the tableau row in any of these
        // three layouts).
        if (rowDelta != 0 && CursorPile.Pile?.Type == PileType.Tableau && CursorCardIndex >= 0)
        {
            var cards = CursorPile.Pile.Cards;
            int firstFaceUp = cards.FindIndex(c => c.IsFaceUp);
            if (firstFaceUp >= 0)
            {
                if (rowDelta < 0 && CursorCardIndex > firstFaceUp) { SetCursor(_cursorRow, _cursorCol, CursorCardIndex - 1); return; }
                if (rowDelta > 0 && CursorCardIndex < cards.Count - 1) { SetCursor(_cursorRow, _cursorCol, CursorCardIndex + 1); return; }
                if (rowDelta > 0) return; // already at the bottom of the column
                // rowDelta < 0 and already at the topmost face-up card: fall through to
                // switch rows below.
            }
        }

        if (rowDelta != 0)
        {
            int newRow = _cursorRow + rowDelta;
            if (newRow < 0 || newRow >= _cursorGrid.Count) return; // clamp, no wrap
            int newCol = FindNearestNonNullColumn(newRow, _cursorCol);
            if (newCol < 0) return;
            SetCursor(newRow, newCol, DefaultCardIndexFor(_cursorGrid[newRow][newCol]!));
        }
        else
        {
            var row = _cursorGrid[_cursorRow];
            int newCol = _cursorCol + colDelta;
            while (newCol >= 0 && newCol < row.Count && row[newCol] == null) newCol += colDelta;
            if (newCol < 0 || newCol >= row.Count) return; // clamp, no wrap
            SetCursor(_cursorRow, newCol, DefaultCardIndexFor(row[newCol]!));
        }
    }

    // Hook for a pile that has no selectable card but still has a direct action when
    // Space/Return lands on it — Klondike/Spider's Stock draws/deals, same as a mouse
    // click on it (PileView_PointerPressed dispatches Stock clicks the same way,
    // regardless of any pending selection — mirrored here for the same reason). Default
    // no-ops; CardGameView subclasses with such a pile override it. Returns whether it
    // handled the activation.
    protected virtual bool TryActivateEmptyCursorPile(PileView pile) => false;

    // Space/Return: context-sensitive select, move, or deselect. Mirrors
    // CardView_PointerPressed's click-to-select/click-to-move logic exactly, just driven
    // by the cursor's current position instead of a physical click.
    protected void ActivateCursor()
    {
        EnsureCursorActive();
        if (CursorPile?.Pile == null) return;
        var targetPile = CursorPile.Pile;

        if (TryActivateEmptyCursorPile(CursorPile)) return;

        if (SelectedCardView == null)
        {
            if (CursorCardIndex < 0) return; // nothing here to pick up
            var cv = GetCardViewAt(CursorPile, CursorCardIndex);
            if (cv?.Card == null || !cv.Card.IsFaceUp) return;
            SelectedCardView = cv;
            SelectedSourcePile = targetPile;
            cv.Highlight();
            return;
        }

        var selectedCard = SelectedCardView.Card;
        var sourcePile = SelectedSourcePile;
        if (selectedCard == null || sourcePile == null)
        {
            SelectedCardView.ClearSelection();
            SelectedCardView = null;
            SelectedSourcePile = null;
            return;
        }

        if (targetPile == sourcePile)
        {
            SelectedCardView.ClearSelection();
            SelectedCardView = null;
            SelectedSourcePile = null;
            return;
        }

        int idx = sourcePile.Cards.IndexOf(selectedCard);
        var cardsToMove = idx < 0
            ? new List<Card> { selectedCard }
            : sourcePile.Cards.GetRange(idx, sourcePile.Cards.Count - idx);

        if (CanMoveCards(cardsToMove, targetPile))
        {
            // Capture before the move — a keyboard-completed move should leave the
            // cursor sitting on the pile the card just landed in (where it already was,
            // since that's how the move got triggered) so arrow keys can keep navigating
            // from there, instead of the Tableaus/Foundations notification this move
            // raises wiping the cursor back to the grid's default slot.
            var targetPileView = CursorPile;
            TryMoveCards(cardsToMove, sourcePile, targetPile);
            SelectedCardView.ClearSelection();
            SelectedCardView = null;
            SelectedSourcePile = null;
            ArmCursorRestore(targetPileView);
        }
        else if (CursorCardIndex >= 0)
        {
            // Illegal target, but a real face-up card sits at the cursor — reselect
            // there instead, matching CardView_PointerPressed's "click a different card"
            // behavior.
            var cv = GetCardViewAt(CursorPile, CursorCardIndex);
            if (cv?.Card != null && cv.Card.IsFaceUp)
            {
                SelectedCardView.ClearSelection();
                SelectedCardView = cv;
                SelectedSourcePile = targetPile;
                cv.Highlight();
            }
        }
        // Illegal target with no real card there (e.g. an empty pile that isn't a valid
        // drop target) — leave the current selection active so the player can try again.
    }
}
