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

    private static readonly SolidColorBrush _brushPointHighlight = new(Color.Parse("#FFD600"));

    // Point Highlights: recolors the winning stat number(s) — 0=Top, 1=Right,
    // 2=Bottom, 3=Left — gold and briefly pulses their scale for a beat before a
    // capture visually flips, matching Mac's HoneycombCardView (the number itself
    // highlights, not a border/edge). Pass null/empty to clear. When not highlighted,
    // this deliberately leaves Foreground alone — UpdateVisuals already set the
    // correct owner color for this render pass, and always runs before this is called.
    public void SetStatHighlight(System.Collections.Generic.HashSet<int>? statIndices)
    {
        ApplyStatHighlight(TopStat, 0, statIndices);
        ApplyStatHighlight(RightStat, 1, statIndices);
        ApplyStatHighlight(BottomStat, 2, statIndices);
        ApplyStatHighlight(LeftStat, 3, statIndices);
    }

    private void ApplyStatHighlight(TextBlock statText, int index, System.Collections.Generic.HashSet<int>? statIndices)
    {
        if (statIndices?.Contains(index) != true) return;

        statText.Foreground = _brushPointHighlight;
        if (statText.RenderTransform is ScaleTransform scale) PulseScale(scale);
    }

    private async void PulseScale(ScaleTransform scale)
    {
        scale.ScaleX = 1.4;
        scale.ScaleY = 1.4;
        await Task.Delay(150);
        scale.ScaleX = 1.0;
        scale.ScaleY = 1.0;
    }

    private int _currentOwner = 0;

    public HoneycombCardView()
    {
        InitializeComponent();
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
            CardBackImage.Source = CardView.ResolveCardBackBitmap(null);
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

        // Always the card's *base* stat (Data.Stats), never card.Stat(i) — any active
        // Ascension/Descension modifier is shown separately via AscensionModifierText
        // below, not baked into these corner numbers (matches the Swift port's
        // HoneycombCardView, which reads card.data.stats[i] here for the same reason).
        TopStat.Text = FormatStat(card.Data.Stats[0]);
        RightStat.Text = FormatStat(card.Data.Stats[1]);
        BottomStat.Text = FormatStat(card.Data.Stats[2]);
        LeftStat.Text = FormatStat(card.Data.Stats[3]);

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
            AscensionModifierText.IsVisible = true;
            AscensionModifierText.Text = card.Modifier > 0 ? $"+{card.Modifier}" : card.Modifier.ToString();
            AscensionModifierText.Foreground = color;
        }
        else
        {
            AscensionModifierText.IsVisible = false;
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

    private async Task PlayOwnerChangeAnimation(HoneycombCard card, int stepDelayMs = 16)
    {
        var st = new Rotate3DTransform();
        FlipContainer.RenderTransform = st;

        // 1. Rotate to 90 degrees
        for (double a = 0; a <= 90; a += 15)
        {
            st.AngleY = a;
            await Task.Delay(stepDelayMs);
        }

        // 2. Midpoint: Update visuals
        UpdateVisuals(card);

        // 3. Rotate from 270 to 360 (completes the flip without mirroring the text)
        for (double a = 270; a <= 360; a += 15)
        {
            st.AngleY = a;
            await Task.Delay(stepDelayMs);
        }
        st.AngleY = 0;
    }

    // Nectar Exchange (Swap): plays the same flip used for board-capture owner
    // changes, but for a hand slot whose card *identity* just changed (a different
    // card traded in, not just a new owner for the same card) — RenderCard's
    // ownerChanged auto-detection doesn't fire for that case, so the ViewModel's
    // OnSwapLanded event calls this directly on the two affected hand slots. 50%
    // slower (24ms/step vs 16ms) than the capture-flip default, matching the mac
    // port's slowed Swap animation.
    public async Task PlaySwapFlipAnimation(HoneycombCard newCard)
    {
        _card = newCard;
        _currentOwner = newCard.Owner;
        await PlayOwnerChangeAnimation(newCard, stepDelayMs: 24);
    }

    private void Card_PointerPressed(object sender, PointerPressedEventArgs e)
    {
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        {
            OnCardClicked?.Invoke(this, (_handIndex, _cellIndex));
        }
    }
}
