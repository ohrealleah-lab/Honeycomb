using System;
using System.Collections.Generic;
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

    private CardView? _hintedCardView;
    private DispatcherTimer? _hintAutoDismissTimer;

    protected void ApplyHint(HintMove? hint, IEnumerable<PileView> allPiles)
    {
        _hintAutoDismissTimer?.Stop();
        _hintAutoDismissTimer = null;

        _hintedCardView?.ClearHint();
        _hintedCardView = null;
        if (hint == null || hint.Card.Id is "no_move" or "deal") return;

        foreach (var pv in allPiles)
        {
            if (pv.Pile?.Id != hint.SourcePileId) continue;
            var canvas = pv.FindControl<Avalonia.Controls.Canvas>("CardsCanvas");
            if (canvas == null) continue;
            foreach (var child in canvas.Children)
            {
                if (child is CardView cv && cv.Card == hint.Card)
                {
                    cv.ShowHint();
                    _hintedCardView = cv;

                    _hintAutoDismissTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(6) };
                    _hintAutoDismissTimer.Tick += (_, _) =>
                    {
                        _hintAutoDismissTimer?.Stop();
                        _hintAutoDismissTimer = null;
                        _hintedCardView?.ClearHint();
                        _hintedCardView = null;
                    };
                    _hintAutoDismissTimer.Start();
                    return;
                }
            }
        }
    }
}
