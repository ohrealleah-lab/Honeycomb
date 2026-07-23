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

    public bool StealHighlight
    {
        get => StealHighlightBorder.IsVisible;
        set => StealHighlightBorder.IsVisible = value;
    }

    private int _currentOwner = 0;

    public HoneycombCardView()
    {
        InitializeComponent();
        BackCardView.Card = new SoliBee.Core.Models.Card("dummy", SoliBee.Core.Models.CardSuit.Spades, 1, false);
        BackCardView.DisableBorderAndShadowsForStretch();
    }

    public async Task RenderCard(HoneycombCard? card, bool faceDown = false, int hIdx = -1, int cIdx = -1)
    {
        _handIndex = hIdx;
        _cellIndex = cIdx;

        if (card == null)
        {
            _card = null;
            CardFace.IsVisible = false;
            CardBack.IsVisible = false;
            return;
        }

        if (faceDown)
        {
            _card = card;
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

        CardFace.Background = CardView._brushFaceBackNormal;
        CardFace.BorderBrush = CardView._brushFaceBorderNormal;

        string FormatStat(int val) => val == 10 ? "A" : val.ToString();

        TopStat.Text = FormatStat(card.Stat(0));
        RightStat.Text = FormatStat(card.Stat(1));
        BottomStat.Text = FormatStat(card.Stat(2));
        LeftStat.Text = FormatStat(card.Stat(3));

        string suitChar = GetSuitGlyph(card.Data.Suit);

        var color = card.Owner == 1 ? CardView._brushTextBlackNormal : CardView._brushTextRed;
        
        StarsPanel.Children.Clear();
        int count = card.Data.Stars;
        bool isHeartOrDiamond = card.Data.Suit == "H" || card.Data.Suit == "D";

        StackPanel CreateRow(int numStars)
        {
            var row = new StackPanel { 
                Orientation = Avalonia.Layout.Orientation.Horizontal, 
                Spacing = 2,
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center 
            };
            for (int i = 0; i < numStars; i++)
            {
                row.Children.Add(new Avalonia.Controls.Shapes.Path
                {
                    Data = Avalonia.Media.Geometry.Parse("M 6,0 L 7.8,4.5 L 12,4.8 L 8.7,7.6 L 9.8,12 L 6,9.5 L 2.2,12 L 3.3,7.6 L 0,4.8 L 4.2,4.5 Z"),
                    Fill = Brushes.White,
                    Stretch = Avalonia.Media.Stretch.Uniform,
                    Width = 12,
                    Height = 12
                });
            }
            return row;
        }

        switch (count)
        {
            case 4:
                StarsPanel.Children.Add(CreateRow(2));
                StarsPanel.Children.Add(CreateRow(2));
                break;
            case 5:
                if (isHeartOrDiamond)
                {
                    StarsPanel.Children.Add(CreateRow(3));
                    StarsPanel.Children.Add(CreateRow(2));
                }
                else
                {
                    StarsPanel.Children.Add(CreateRow(2));
                    StarsPanel.Children.Add(CreateRow(3));
                }
                break;
            default:
                if (count > 0)
                {
                    StarsPanel.Children.Add(CreateRow(count));
                }
                break;
        }

        TopStat.Foreground = color;
        RightStat.Foreground = color;
        BottomStat.Foreground = color;
        LeftStat.Foreground = color;
        SuitImage.Source = CardView.GetOrCreateAceBitmap(suitChar, color);

        if (card.Modifier != 0)
        {
            ModifierBadge.IsVisible = true;
            ModifierText.Text = card.Modifier > 0 ? $"+{card.Modifier}" : card.Modifier.ToString();
            ModifierBadge.Background = card.Modifier > 0 ? Brushes.Green : Brushes.DarkRed;
            ModifierBadge.BoxShadow = card.Modifier > 0 ? Avalonia.Media.BoxShadows.Parse("0 0 10 2 Green") : Avalonia.Media.BoxShadows.Parse("0 0 10 2 DarkRed");
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
            "Spades" or "S" => "♠",
            "Hearts" or "H" => "♥",
            "Diamonds" or "D" => "♦",
            "Clubs" or "C" => "♣",
            _ => "?"
        };
    }

    private async Task PlayOwnerChangeAnimation(HoneycombCard card)
    {
        var st = new Rotate3DTransform();
        FlipContainer.RenderTransform = st;
        
        // 1. Rotate to 90 degrees
        for (double a = 0; a <= 90; a += 15)
        {
            st.AngleY = a;
            await Task.Delay(16);
        }
        
        // 2. Midpoint: Update visuals
        UpdateVisuals(card);
        
        // 3. Rotate from 270 to 360 (completes the flip without mirroring the text)
        for (double a = 270; a <= 360; a += 15)
        {
            st.AngleY = a;
            await Task.Delay(16);
        }
        st.AngleY = 0;
    }

    private void Card_PointerPressed(object sender, PointerPressedEventArgs e)
    {
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        {
            OnCardClicked?.Invoke(this, (_handIndex, _cellIndex));
        }
    }
}
