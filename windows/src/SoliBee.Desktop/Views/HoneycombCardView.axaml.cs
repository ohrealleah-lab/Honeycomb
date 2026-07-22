using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;
using Avalonia.Animation;
using SoliBee.Core.Models;
using System;
using System.Threading.Tasks;

namespace SoliBee.Desktop.Views;

public partial class HoneycombCardView : UserControl
{
    private HoneycombCard? _card;
    private int _handIndex = -1;
    private int _cellIndex = -1;
    public event EventHandler<(int handIndex, int cellIndex)>? OnCardClicked;

    private int _currentOwner = 0;

    public HoneycombCardView()
    {
        InitializeComponent();
    }

    public async Task RenderCard(HoneycombCard? card, bool faceDown = false, int hIdx = -1, int cIdx = -1)
    {
        _handIndex = hIdx;
        _cellIndex = cIdx;

        if (card == null || faceDown)
        {
            _card = null;
            CardFace.IsVisible = false;
            CardBack.IsVisible = true;
            return;
        }

        bool ownerChanged = _card != null && _card.UniqueInstanceId == card.UniqueInstanceId && _currentOwner != 0 && _currentOwner != card.Owner;
        
        _card = card;
        _currentOwner = card.Owner;

        if (ownerChanged)
        {
            await PlayOwnerChangeAnimation(card);
        }
        else
        {
            UpdateVisuals(card);
        }
    }

    private void UpdateVisuals(HoneycombCard card)
    {
        CardFace.IsVisible = true;
        CardBack.IsVisible = false;

        string FormatStat(int val) => val == 10 ? "A" : val.ToString();

        TopStat.Text = FormatStat(card.Stat(0));
        RightStat.Text = FormatStat(card.Stat(1));
        BottomStat.Text = FormatStat(card.Stat(2));
        LeftStat.Text = FormatStat(card.Stat(3));

        SuitText.Text = GetSuitGlyph(card.Data.Suit);
        StarsText.Text = new string('★', card.Data.Stars) + new string('☆', 5 - card.Data.Stars);

        var color = card.Owner == 1 ? Brushes.Black : Brushes.Red;
        TopStat.Foreground = color;
        RightStat.Foreground = color;
        BottomStat.Foreground = color;
        LeftStat.Foreground = color;
        SuitText.Foreground = color;
        StarsText.Foreground = color;

        if (card.Modifier != 0)
        {
            ModifierBadge.IsVisible = true;
            ModifierText.Text = card.Modifier > 0 ? $"+{card.Modifier}" : card.Modifier.ToString();
            ModifierBadge.Background = card.Modifier > 0 ? Brushes.Green : Brushes.DarkRed;
        }
        else
        {
            ModifierBadge.IsVisible = false;
        }
    }

    private string GetSuitGlyph(string suit)
    {
        return suit switch
        {
            "Spades" => "♠",
            "Hearts" => "♥",
            "Diamonds" => "♦",
            "Clubs" => "♣",
            _ => "?"
        };
    }

    private async Task PlayOwnerChangeAnimation(HoneycombCard card)
    {
        // Pseudo flip using scaleX
        var st = new ScaleTransform(1, 1);
        FlipContainer.RenderTransform = st;
        
        // 1. Scale down to 0
        for (double s = 1.0; s >= 0; s -= 0.15)
        {
            st.ScaleX = s;
            await Task.Delay(16);
        }
        
        // 2. Midpoint: Update visuals
        UpdateVisuals(card);
        
        // 3. Scale back to 1
        for (double s = 0; s <= 1.0; s += 0.15)
        {
            st.ScaleX = s;
            await Task.Delay(16);
        }
        st.ScaleX = 1;
    }

    private void Card_PointerPressed(object sender, PointerPressedEventArgs e)
    {
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        {
            OnCardClicked?.Invoke(this, (_handIndex, _cellIndex));
        }
    }
}
