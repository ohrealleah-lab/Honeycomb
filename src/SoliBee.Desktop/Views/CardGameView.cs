using System.Collections.Generic;
using Avalonia.Controls;
using SoliBee.Core.Models;

namespace SoliBee.Desktop.Views;

public abstract class CardGameView : UserControl
{
    public CardView? SelectedCardView { get; set; }
    public Pile? SelectedSourcePile { get; set; }

    public abstract bool CanMoveCards(List<Card> cards, Pile targetPile);
    public abstract bool TryMoveCards(List<Card> cards, Pile sourcePile, Pile targetPile);
    public abstract bool TryAutoMoveToFoundation(Card card, Pile sourcePile);
}
