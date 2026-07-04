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

    public abstract bool CanMoveCards(List<Card> cards, Pile targetPile);
    public abstract bool TryMoveCards(List<Card> cards, Pile sourcePile, Pile targetPile);
    public abstract bool TryAutoMoveToFoundation(Card card, Pile sourcePile);

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
}
