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
    public event Action<bool>? OnRuleAnimationScaleChanged;

    // Board and hand cards indicate ownership by recoloring the suit icon/stats
    // themselves (black = player, red = opponent), overriding the suit's natural
    // color. Only the deck manager/deck builder's Card Bank sets this false — it
    // always shows the player's own collection, where a card's natural suit color
    // (red for hearts/diamonds) is what's meaningful for visual contrast, not
    // ownership (which is constant there anyway). Mirrors the Swift port's
    // useOwnershipColoring (shared/Honeycomb/Views/HoneycombCardView.swift).
    public bool UseOwnershipColoring { get; set; } = true;

    public bool StealHighlight
    {
        get => StealHighlightBorder.IsVisible;
        set => StealHighlightBorder.IsVisible = value;
    }

    private static readonly SolidColorBrush _brushPointHighlight = new(Color.Parse("#FFD600"));

    // Steal-eligible / hierarchy-frenzy mandated / hint highlight border — .Color kept
    // in sync with CardView._hintHighlightColor by CardView.ApplyThemeColors.
    internal static readonly SolidColorBrush _brushStealHighlight = new(Color.Parse("#FFD700"));

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

    // Scale-up uses the CardRoot.RenderTransform's own XAML-declared Transitions
    // (CubicEaseOut, matching the doc). The hold-to-1.0 leg swaps in this EaseIn set
    // instead, per the doc's "ease back down with easeIn" — Avalonia's Transitions
    // apply the same easing regardless of which direction the value moves, so getting
    // a different curve for the return trip means swapping the Transitions collection
    // right before setting the value, not just relying on the one declared in XAML.
    private static readonly Transitions _scaleDownTransitions = new()
    {
        new DoubleTransition { Property = ScaleTransform.ScaleXProperty, Duration = TimeSpan.FromSeconds(0.2), Easing = new Avalonia.Animation.Easings.CubicEaseIn() },
        new DoubleTransition { Property = ScaleTransform.ScaleYProperty, Duration = TimeSpan.FromSeconds(0.2), Easing = new Avalonia.Animation.Easings.CubicEaseIn() },
    };
    private Transitions? _scaleUpTransitions;

    // Guards the delayed scale-down against a second trigger landing on the same card
    // before the first one's 1s hold elapses (e.g. a combo chain re-capturing this same
    // card as one of its own neighbors within a beat of its first capture) — without
    // this, the first trigger's stale Task.Delay would revert the scale (and fire
    // OnRuleAnimationScaleChanged false, dropping the zIndex) out from under the second
    // trigger's still-active pop. Mirrors the Swift port's ruleTriggerGeneration.
    private int _ruleAnimationGeneration = 0;

    private async void TriggerRuleScaleAnimation()
    {
        _ruleAnimationGeneration++;
        var generation = _ruleAnimationGeneration;
        OnRuleAnimationScaleChanged?.Invoke(true);
        if (CardRoot.RenderTransform is ScaleTransform scale)
        {
            _scaleUpTransitions ??= scale.Transitions;
            scale.Transitions = _scaleUpTransitions;
            scale.ScaleX = 1.2;
            scale.ScaleY = 1.2;
            await Task.Delay(1000);
            if (_ruleAnimationGeneration != generation) return;
            scale.Transitions = _scaleDownTransitions;
            scale.ScaleX = 1.0;
            scale.ScaleY = 1.0;
            await Task.Delay(200);
            if (_ruleAnimationGeneration != generation) return;
        }
        OnRuleAnimationScaleChanged?.Invoke(false);
    }

    private int _currentOwner = 0;
    // Tracks whether this slot is currently showing CardBack — separate from _card
    // being non-null, since a hand slot rendered faceDown still has _card set (the
    // face-down opponent card). Lets RenderCard tell a genuine reveal (was showing
    // the back, now showing the front — e.g. a Bomb Shelter card flipping face-up)
    // apart from an ordinary re-render.
    private bool _isShowingFaceDown = false;
    // Whether this slot was already flagged as a capture attacker as of the last
    // RenderCard call — compared against the freshly-passed isCaptureAttacker each
    // call so the pop fires exactly once per capture event (a false -> true edge),
    // not on every Refresh while HoneycombState.CaptureAttackerIds still contains this
    // card's id (it stays there ~100ms, long enough to span more than one Refresh).
    private bool _wasCaptureAttacker = false;

    public HoneycombCardView()
    {
        InitializeComponent();
        StealHighlightBorder.BorderBrush = _brushStealHighlight;
    }

    public async Task RenderCard(HoneycombCard? card, bool faceDown = false, int hIdx = -1, int cIdx = -1, bool isCaptureAttacker = false)
    {
        _handIndex = hIdx;
        _cellIndex = cIdx;

        if (card == null)
        {
            _card = null;
            _isShowingFaceDown = false;
            _wasCaptureAttacker = false;
            CardFace.IsVisible = false;
            CardBack.IsVisible = false;
            return;
        }

        if (faceDown)
        {
            _card = card;
            _isShowingFaceDown = true;
            CardFace.IsVisible = false;
            CardBack.IsVisible = true;
            CardBackImage.Source = CardView.ResolveCardBackBitmap(null);
            return;
        }

        bool ownerChanged = _card != null && _card.UniqueInstanceId == card.UniqueInstanceId && _currentOwner != 0 && _currentOwner != card.Owner;
        bool revealedFromFaceDown = _isShowingFaceDown;
        // Captures are a board-only mechanic (see HoneycombState.CaptureAttackerIds/
        // ViewModel.FlashCaptureAttackers) — the caller only ever passes
        // isCaptureAttacker: true for board slots, but gating here too is just
        // belt-and-suspenders clarity that this is a board-capture-only pop.
        bool isBoardSlot = cIdx >= 0;
        // Edge-triggered so a card that stays flagged across more than one Refresh
        // call (CaptureAttackerIds is cleared ~100ms later, not instantly) only pops
        // once, not once per Refresh.
        bool justBecameAttacker = isCaptureAttacker && !_wasCaptureAttacker;

        _card = card;
        _currentOwner = card.Owner;
        _isShowingFaceDown = false;
        _wasCaptureAttacker = isCaptureAttacker;

        // The pop is capture-only, and belongs to whichever card did the capturing —
        // the just-placed card's own direct capture, or a Bomb Shelter/Hive Swarm
        // reveal's own capture — not the cards it captured (ownerChanged, used below
        // only for the flip animation). Deliberately NOT wired to revealedFromFaceDown
        // on its own (a reveal that captures nothing shouldn't pop) or to a modifier
        // change (Pollination/Smoked Out recomputes every matching-suit card on every
        // placement, so it fired far too often and read as noise rather than a
        // capture-specific beat).
        if (isBoardSlot && justBecameAttacker)
        {
            TriggerRuleScaleAnimation();
        }

        if (revealedFromFaceDown)
        {
            await PlayRevealAnimation(card);
        }
        else if (ownerChanged)
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

        bool isHeartOrDiamond = card.Data.Suit == "H" || card.Data.Suit == "D";
        var color = UseOwnershipColoring
            ? (card.Owner == 1 ? CardView._brushTextBlackNormal : CardView._brushTextRed)
            : (isHeartOrDiamond ? CardView._brushTextRed : CardView._brushTextBlackNormal);

        StarsPanel.Children.Clear();
        int count = card.Data.Stars;

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

    // Total flip duration (both halves combined) — matches the Swift port's
    // HoneycombFlipTiming.duration (0.4s), used identically for capture/ownership
    // flips and the deal-flip reveal below. 14 steps total (7 per half, 15° each).
    private const double FlipTotalMs = 400.0;
    private static readonly TimeSpan FlipStepDelay = TimeSpan.FromMilliseconds(FlipTotalMs / 14.0);

    private async Task PlayOwnerChangeAnimation(HoneycombCard card)
    {
        var st = new Rotate3DTransform();
        FlipContainer.RenderTransform = st;

        // 1. Rotate to 90 degrees
        for (double a = 0; a <= 90; a += 15)
        {
            st.AngleY = a;
            await Task.Delay(FlipStepDelay);
        }

        // 2. Midpoint: Update visuals
        UpdateVisuals(card);

        // 3. Rotate from 270 to 360 (completes the flip without mirroring the text)
        for (double a = 270; a <= 360; a += 15)
        {
            st.AngleY = a;
            await Task.Delay(FlipStepDelay);
        }
        st.AngleY = 0;
    }

    // Bomb Shelter reveal (and any other face-down -> face-up transition): CardBack
    // and CardFace are separate siblings (not nested — CardBack is a plain direct
    // Image at the control's real card size, see the XAML comment above it), so
    // unlike PlayOwnerChangeAnimation's single FlipContainer transform, both need
    // their own Rotate3DTransform driven in lockstep for the flip to read as one
    // continuous card turning over rather than two independently-animated pieces.
    // Mirrors the Swift port's card.isFaceDown onChange flip
    // (shared/Honeycomb/Views/HoneycombCardView.swift).
    private async Task PlayRevealAnimation(HoneycombCard card)
    {
        var faceTransform = new Rotate3DTransform();
        var backTransform = new Rotate3DTransform();
        FlipContainer.RenderTransform = faceTransform;
        CardBack.RenderTransform = backTransform;

        // 1. Rotate to 90 degrees, CardBack still showing
        for (double a = 0; a <= 90; a += 15)
        {
            faceTransform.AngleY = a;
            backTransform.AngleY = a;
            await Task.Delay(FlipStepDelay);
        }

        // 2. Midpoint: swap from back to face (UpdateVisuals sets both IsVisible flags)
        UpdateVisuals(card);

        // 3. Rotate from 270 to 360 (completes the flip without mirroring the text)
        for (double a = 270; a <= 360; a += 15)
        {
            faceTransform.AngleY = a;
            backTransform.AngleY = a;
            await Task.Delay(FlipStepDelay);
        }
        faceTransform.AngleY = 0;
        backTransform.AngleY = 0;
    }

    private void Card_PointerPressed(object sender, PointerPressedEventArgs e)
    {
        if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        {
            OnCardClicked?.Invoke(this, (_handIndex, _cellIndex));
        }
    }
}
