using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using SoliBee.Desktop.Services;

namespace SoliBee.Desktop.Views;

public partial class BlackjackView : UserControl
{
    private AppLanguage _language = AppLanguage.English;

    private DispatcherTimer? _resultShowTimer;
    private DispatcherTimer? _bannerDelayTimer;
    private DispatcherTimer? _bannerFadeTimer;
    private DispatcherTimer? _bustFlashTimer;
    private DispatcherTimer? _cardsFadeTimer;
    private DispatcherTimer? _idleTimer;
    private DispatcherTimer? _idleFadeTimer;

    private BlackjackPhase _lastPhase         = BlackjackPhase.Betting;
    private bool           _resultSoundPlayed = false;
    private int            _prevBustCount     = 0;

    // True once the post-result card fade has completed and card-back placeholders
    // are showing in place of the (stale) finished hand, until the next Deal().
    private bool _cardsFadedOut = false;

    private static readonly Card _blankCard = new("__bj_blank__", CardSuit.Spades, 0, false);

    // Deal animation — track card IDs to detect newly-added cards each refresh
    private List<string>       _prevDealerIds  = new();
    private List<List<string>> _prevPlayerIds  = new();

    // Active chip button highlight tracking
    private static readonly SolidColorBrush _chipHighlight = new(Color.FromArgb(0x50, 0xFF, 0xFF, 0xFF));

    // Active split-hand border — cached rather than allocated per RebuildPlayerHands call
    private static readonly SolidColorBrush _activeSplitHandBorder = new(Color.FromRgb(0xFF, 0xCC, 0x00));

    public BlackjackView()
    {
        InitializeComponent();
        _language = SettingsService.LoadOptions().Language;
        ApplyLocalization();
        this.Loaded   += BlackjackView_Loaded;
        this.Unloaded += BlackjackView_Unloaded;
    }

    // Applies the current language to every static button/label in this view. Runs once at
    // construction and again whenever OptionsChangedMessage reports a language change (see
    // the registration in BlackjackView_Loaded), matching MainWindow's ApplyLocalization
    // pattern. Dynamic strings built elsewhere in this file (dealer/player count labels,
    // result headline/subline, win-streak text) also read Strings.Get(..., _language) at
    // the point they're built, so they pick up the current language too.
    private void ApplyLocalization()
    {
        ClearBetButton.Content   = Strings.Get(StringKey.BtnClearBetWin, _language);
        DealButton.Content       = Strings.Get(StringKey.BtnDealSpaceWin, _language);
        RebuyButton.Content      = Strings.Get(StringKey.BuyInButton, _language);

        // Chip buttons wrap a PokerChipFace (the vector-drawn chip visual, see
        // PokerChipFace.cs) as their Content, not a plain string — setting .Content
        // directly here like the buttons above would replace that control outright and
        // discard it before it ever renders, leaving just bare fallback text on the
        // felt. Update the existing instance's Label instead.
        if (Chip1Button.Content is PokerChipFace chip1)     chip1.Label     = Strings.Get(StringKey.Chip1, _language);
        if (Chip5Button.Content is PokerChipFace chip5)     chip5.Label     = Strings.Get(StringKey.Chip5, _language);
        if (Chip10Button.Content is PokerChipFace chip10)   chip10.Label    = Strings.Get(StringKey.Chip10, _language);
        if (Chip25Button.Content is PokerChipFace chip25)   chip25.Label    = Strings.Get(StringKey.Chip25, _language);
        if (DoubleBetButton.Content is PokerChipFace chip2x) chip2x.Label   = Strings.Get(StringKey.Chip2x, _language);

        HitButton.Content    = Strings.Get(StringKey.BtnHitWin, _language);
        StandButton.Content  = Strings.Get(StringKey.BtnStandWin, _language);
        DoubleButton.Content = Strings.Get(StringKey.BtnDoubleWin, _language);
        SplitButton.Content  = Strings.Get(StringKey.BtnSplitWin, _language);

        KeyHintLabel.Text = Strings.Get(StringKey.KeyHintRowWin, _language);

        VsDividerText.Text  = Strings.Get(StringKey.VsDivider, _language);
        IdlePromptText.Text = Strings.Get(StringKey.HitSpaceToDeal, _language);

        BidBar.ApplyLanguage(_language);
    }

    private void BlackjackView_Loaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;
        vm.PropertyChanged += Vm_PropertyChanged;
        vm.OnFlashBanner += Vm_OnFlashBanner;
        MilestoneToast.OnDismissed += MilestoneToast_OnDismissed;
        TopLevel.GetTopLevel(this)?.AddHandler(InputElement.KeyDownEvent, OnKeyDown, RoutingStrategies.Tunnel);
        WeakReferenceMessenger.Default.Register<FaceCardArtChangedMessage>(this, (r, m) =>
            Dispatcher.UIThread.InvokeAsync(() => { if (DataContext is BlackjackViewModel bvm) Refresh(bvm); }));
        // Keep this view's static text in sync with a language change made while it's open
        // (e.g. Preferences opened over the running game) — mirrors MainWindow's own
        // OptionsChangedMessage -> ApplyLocalization hookup.
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            if (m.Options.Language != _language)
            {
                _language = m.Options.Language;
                ApplyLocalization();
                Refresh(vm);
            }
        });
        vm.CheckLoadingBanner();
        Refresh(vm);

        // Unlike VideoPoker's card slots (fixed, always-present elements in the AXAML),
        // the dealer/player cards here are added to DealerCardsPanel/PlayerHandsContainer
        // programmatically inside Refresh — the very first time that happens is right here,
        // after this view already had at least one measure/arrange pass with those
        // StackPanels empty. BoardFeltGrid's dealer/VS/player/button rows are all
        // Height="Auto", so if that stale empty-content measurement isn't invalidated,
        // the button row renders at the height it would occupy with no dealer/player
        // cards at all — overlapping the (still-visible, since ClipToBounds="False")
        // card placeholders instead of sitting below them. Forcing one synchronous
        // layout pass here, now that the cards actually exist, avoids that first-frame
        // glitch; a real Deal() naturally triggers enough of its own layout work
        // (slide-in animations etc.) that it isn't affected.
        BoardFeltGrid.UpdateLayout();
    }

    private void Vm_OnFlashBanner(string message)
    {
        // Avalonia's startup cost (unlike Mac's native AppKit path) eats into the very
        // first loading banner's visible time before the window is even on screen — give
        // just that one banner extra time to actually be read.
        var duration = BannerCatalog.ConsumeAppLaunchLoadingFlag() ? TimeSpan.FromSeconds(3) : TimeSpan.FromSeconds(2);
        var manualDismiss = SettingsService.LoadOptions().ManuallyDismissBanners;
        Dispatcher.UIThread.Post(() =>
        {
            MilestoneToast.Flash(message, duration, manualDismiss);
            BannerTapCatcher.IsHitTestVisible = true;
        });
    }

    // Board-wide tap-catcher: while a manually-dismissed toast is up, the game is
    // "paused" — any board click (not just the toast itself) dismisses it instead of
    // being forwarded to the card underneath.
    private void BannerTapCatcher_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (MilestoneToast.IsVisible) MilestoneToast.Dismiss();
    }

    private void MilestoneToast_OnDismissed()
    {
        BannerTapCatcher.IsHitTestVisible = false;
        (DataContext as BlackjackViewModel)?.AdvanceBannerQueue();
    }

    private void BlackjackView_Unloaded(object? sender, RoutedEventArgs e)
    {
        if (DataContext is BlackjackViewModel vm)
        {
            vm.PropertyChanged -= Vm_PropertyChanged;
            vm.OnFlashBanner -= Vm_OnFlashBanner;
        }
        MilestoneToast.OnDismissed -= MilestoneToast_OnDismissed;
        TopLevel.GetTopLevel(this)?.RemoveHandler(InputElement.KeyDownEvent, OnKeyDown);
        WeakReferenceMessenger.Default.Unregister<FaceCardArtChangedMessage>(this);
        WeakReferenceMessenger.Default.Unregister<OptionsChangedMessage>(this);
        StopTimers();
    }

    private void Vm_PropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        Dispatcher.UIThread.Post(() =>
        {
            if (DataContext is BlackjackViewModel vm) Refresh(vm);
        });
    }

    // ── Full refresh ─────────────────────────────────────────────────────────

    private void Refresh(BlackjackViewModel vm)
    {
        BidBar.CreditsText = vm.CreditDisplay;
        BidBar.BetText     = vm.BetDisplay;
        BidBar.HandsText   = vm.HandsDisplay;

        // Phase-transition sounds
        PlayTransitionSounds(vm);

        // Leaving Result (e.g. the next Deal() started a new hand) — stop showing
        // the post-fade card-back placeholders and resume normal card rendering.
        if (vm.State.Phase != BlackjackPhase.Result) _cardsFadedOut = false;

        // The banner/fade sequence already fully played for this result in a previous
        // View instance (e.g. the player switched to another game and back — the View
        // is recreated on every game switch, so this instance's own _cardsFadedOut
        // starts false with no memory of it). Jump straight to the settled card-back
        // state instead of replaying the whole hand + banner from scratch.
        if (vm.State.Phase == BlackjackPhase.Result && vm.State.ResultBannerShown)
            _cardsFadedOut = true;

        RebuildDealerCards(vm);
        RebuildPlayerHands(vm);
        UpdateButtons(vm);
        UpdateResult(vm);
        ApplyFeltColor(vm);
        ResetIdleTimer(vm);

        _lastPhase = vm.State.Phase;
    }

    private void PlayTransitionSounds(BlackjackViewModel vm)
    {
        var phase = vm.State.Phase;

        // Hole card flips when dealer starts playing
        if (_lastPhase == BlackjackPhase.Playing && phase == BlackjackPhase.DealerTurn)
            SoundService.PlaySnap();

        // Win/loss sound fires once on result
        if (phase == BlackjackPhase.Result && !_resultSoundPlayed)
        {
            _resultSoundPlayed = true;
            bool anyWin = vm.State.PlayerHands.Any(h =>
                h.Result is BlackjackHandResult.Won or BlackjackHandResult.Blackjack);
            if (anyWin) SoundService.PlayVictory();
        }

        if (phase == BlackjackPhase.Playing)
            _resultSoundPlayed = false;
    }

    // ── Deal animation helper ─────────────────────────────────────────────────

    private static void ScheduleCardSlideIn(CardView cv, double fromX, double fromY, int durationMs, int delayMs)
    {
        cv.Opacity = 0;
        if (delayMs == 0) { cv.BeginSlideIn(fromX, fromY, durationMs, fadeIn: true); return; }
        var t = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(delayMs) };
        t.Tick += (_, _) => { t.Stop(); cv.BeginSlideIn(fromX, fromY, durationMs, fadeIn: true); };
        t.Start();
    }

    // ── Dealer cards ──────────────────────────────────────────────────────────

    private const double CardBaseWidth   = 190;
    private const double LightOverlap    = -(CardBaseWidth * 0.30);
    private const double TightOverlap    = -(CardBaseWidth * 0.55);
    private const double TightestOverlap = -(CardBaseWidth * 0.75);

    private static Viewbox MakeCardVisual(CardView cv, int index)
    {
        var vb = new Viewbox { Stretch = Stretch.Uniform, Width = CardBaseWidth, Height = 268.375, Child = cv };
        if (index > 0) vb.Margin = new Avalonia.Thickness(LightOverlap, 0, 0, 0);
        return vb;
    }

    private bool ShowingBlankCards(BlackjackViewModel vm) =>
        vm.State.Phase == BlackjackPhase.Betting ||
        (_cardsFadedOut && vm.State.Phase == BlackjackPhase.Result);

    private void RebuildDealerCards(BlackjackViewModel vm)
    {
        DealerCardsPanel.Children.Clear();

        if (ShowingBlankCards(vm))
        {
            DealerCountLabel.Text = Strings.Get(StringKey.DealerLabel, _language);
            for (int i = 0; i < 2; i++)
                DealerCardsPanel.Children.Add(MakeCardVisual(new CardView { Card = _blankCard, IsHitTestVisible = false }, i));
            _prevDealerIds = new();
            return;
        }

        var cards   = vm.State.DealerHand.Cards;
        var newIds  = cards.Select(c => c.Id).ToList();
        int stagger = 0;

        // Only the face-up cards count toward the displayed total — the hole card
        // stays hidden from this count until it's flipped during the dealer's turn.
        var (visibleValue, _) = vm.State.DealerHand.ComputeVisibleValue();
        DealerCountLabel.Text = $"{Strings.Get(StringKey.DealerLabel, _language)}  {visibleValue}";

        double dealerOverlap = cards.Count >= 6 ? TightOverlap : LightOverlap;

        for (int i = 0; i < cards.Count; i++)
        {
            var cv = new CardView { Card = cards[i], IsHitTestVisible = false };
            var vb = new Viewbox { Stretch = Stretch.Uniform, Width = CardBaseWidth, Height = 268.375, Child = cv };
            if (i > 0) vb.Margin = new Avalonia.Thickness(dealerOverlap, 0, 0, 0);
            DealerCardsPanel.Children.Add(vb);

            bool isNew = i >= _prevDealerIds.Count || _prevDealerIds[i] != newIds[i];
            if (isNew) ScheduleCardSlideIn(cv, 0, -42, 185, stagger++ * 110);
        }

        _prevDealerIds = newIds;
    }

    // ── Player hands ──────────────────────────────────────────────────────────

    private void RebuildPlayerHands(BlackjackViewModel vm)
    {
        PlayerHandsContainer.Children.Clear();

        if (ShowingBlankCards(vm))
        {
            PlayerCountLabel.Text = Strings.Get(StringKey.PlayerLabel, _language);
            var cardRow = new StackPanel { Orientation = Orientation.Horizontal };
            for (int i = 0; i < 2; i++)
                cardRow.Children.Add(MakeCardVisual(new CardView { Card = _blankCard, IsHitTestVisible = false }, i));
            PlayerHandsContainer.Children.Add(cardRow);
            _prevPlayerIds = new();
            _prevBustCount = 0;
            return;
        }

        string playerLabel = Strings.Get(StringKey.PlayerLabel, _language);
        PlayerCountLabel.Text = vm.State.PlayerHands.Count > 1
            ? $"{playerLabel}  {string.Join(" / ", vm.State.PlayerHands.Select(h => h.ComputeValue().Value))}"
            : $"{playerLabel}  {vm.State.PlayerHands[0].ComputeValue().Value}";

        // Grow tracking list as needed
        while (_prevPlayerIds.Count < vm.State.PlayerHands.Count)
            _prevPlayerIds.Add(new List<string>());

        int bustCount = 0;
        Border? newBustBorder = null;

        for (int hi = 0; hi < vm.State.PlayerHands.Count; hi++)
        {
            var hand    = vm.State.PlayerHands[hi];
            bool active = vm.State.Phase == BlackjackPhase.Playing && hi == vm.State.ActiveHandIndex;

            var (val, _) = hand.ComputeValue();
            bool bust = val > 21;
            if (bust) bustCount++;

            var prevIds = hi < _prevPlayerIds.Count ? _prevPlayerIds[hi] : new List<string>();
            var newIds  = hand.Cards.Select(c => c.Id).ToList();
            int stagger = 0;

            // Cards row
            double overlap = vm.State.IsSplit
                ? (hand.Cards.Count >= 4 ? TightestOverlap : TightOverlap)
                : (hand.Cards.Count >= 6 ? TightOverlap : LightOverlap);

            var cardRow = new StackPanel { Orientation = Orientation.Horizontal };
            for (int ci = 0; ci < hand.Cards.Count; ci++)
            {
                var cv = new CardView { Card = hand.Cards[ci], IsHitTestVisible = false };
                var vb = new Viewbox { Stretch = Stretch.Uniform, Width = CardBaseWidth, Height = 268.375, Child = cv };
                if (ci > 0) vb.Margin = new Avalonia.Thickness(overlap, 0, 0, 0);
                cardRow.Children.Add(vb);

                bool isNew = ci >= prevIds.Count || prevIds[ci] != newIds[ci];
                if (isNew) ScheduleCardSlideIn(cv, 0, 42, 185, stagger++ * 110);
            }

            if (hi < _prevPlayerIds.Count) _prevPlayerIds[hi] = newIds;
            else _prevPlayerIds.Add(newIds);

            var inner = new StackPanel { Spacing = 5 };
            inner.Children.Add(cardRow);

            bool showActiveBorder = active && vm.State.IsSplit;
            var container = new Border
            {
                Child           = inner,
                Padding         = new Avalonia.Thickness(6, 4),
                CornerRadius    = new Avalonia.CornerRadius(6),
                BorderThickness = new Avalonia.Thickness(showActiveBorder ? 3 : 0),
                BorderBrush     = showActiveBorder ? _activeSplitHandBorder : null,
                Background      = null,
            };

            // Track the bust border for the flash animation
            if (bust) newBustBorder = container;

            // Outer column — includes "YOUR TURN" indicator for split.
            // Always reserve the label's slot (even when blank) so both split hands'
            // card rows stay vertically aligned instead of the active hand's cards
            // shifting down by the label's height.
            var outer = new StackPanel { Spacing = 3, HorizontalAlignment = HorizontalAlignment.Center };
            if (vm.State.IsSplit)
            {
                outer.Children.Add(new TextBlock
                {
                    Text                = active ? "▶  YOUR TURN" : " ",
                    FontSize            = 10,
                    FontWeight          = FontWeight.Bold,
                    Foreground          = new SolidColorBrush(Color.FromArgb(0xCC, 0xFF, 0xFF, 0x44)),
                    HorizontalAlignment = HorizontalAlignment.Center,
                    FontFamily          = new FontFamily("Segoe UI"),
                    LetterSpacing       = 1,
                });
            }
            outer.Children.Add(container);
            PlayerHandsContainer.Children.Add(outer);
        }

        // Trigger bust flash if a new bust just appeared
        if (bustCount > _prevBustCount && newBustBorder != null && vm.State.Phase == BlackjackPhase.Playing)
            AnimateBustFlash(newBustBorder);

        _prevBustCount = bustCount;
    }

    // ── Bust flash ────────────────────────────────────────────────────────────

    private void AnimateBustFlash(Border target)
    {
        _bustFlashTimer?.Stop();
        int ticks = 0;
        var bustRed = new SolidColorBrush(Color.FromArgb(0x60, 0xFF, 0x00, 0x00));
        var clear   = new SolidColorBrush(Color.FromArgb(0x00, 0x00, 0x00, 0x00));
        _bustFlashTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(110) };
        _bustFlashTimer.Tick += (_, _) =>
        {
            ticks++;
            target.Background = ticks % 2 == 1 ? bustRed : clear;
            if (ticks >= 6)
            {
                _bustFlashTimer!.Stop();
                _bustFlashTimer = null;
                target.Background = clear;
            }
        };
        _bustFlashTimer.Start();
        SoundService.PlaySnap();
    }

    // ── Buttons ───────────────────────────────────────────────────────────────

    private void UpdateButtons(BlackjackViewModel vm)
    {
        bool playing  = vm.State.Phase == BlackjackPhase.Playing;
        bool canDeal  = vm.CanDeal;
        bool freePlay = vm.Options.IsNoStressMode;

        ActionButtonRow.IsVisible = playing;
        HitButton.IsVisible    = playing;
        StandButton.IsVisible  = playing;
        DoubleButton.IsVisible = playing && vm.CanDouble;
        SplitButton.IsVisible  = playing && vm.CanSplit;
        BetButtonRow.IsVisible = vm.CanChangeBet;
        // No Stress Mode's free play has no bet to place, so the credits/bet readout
        // and every betting control disappear — only Deal (to start the next hand)
        // and the in-hand action buttons above remain.
        BidBar.IsVisible        = !freePlay;
        ChipButtonRow.IsVisible = !freePlay;
        ClearBetButton.IsVisible = !freePlay;
        // CanRebuy now triggers as an early low-credits warning (<=10), not "can't afford
        // to deal" — Deal stays visible/usable alongside Buy In as long as the phase
        // allows it, rather than being replaced by it.
        DealButton.IsVisible   = vm.CanDeal;
        RebuyButton.IsVisible  = vm.CanRebuy;
        RebuyDivider.IsVisible = vm.CanRebuy;

        if (playing)
        {
            HitButton.IsEnabled    = vm.CanHit;
            StandButton.IsEnabled  = vm.CanStand;
            DoubleButton.IsEnabled = vm.CanDouble;
            SplitButton.IsEnabled  = vm.CanSplit;
        }

    }

    // ── Result overlay ────────────────────────────────────────────────────────

    private static string FormatHandTotal(BlackjackHand hand)
    {
        var (value, _) = hand.ComputeValue();
        return hand.IsBust ? $"{value} (Bust)" : value.ToString();
    }

    private void UpdateResult(BlackjackViewModel vm)
    {
        if (vm.State.Phase != BlackjackPhase.Result)
        {
            if (_lastPhase == BlackjackPhase.Result) HideBanner();
            return;
        }

        // Already fully played out (see Refresh) — don't replay the reveal/banner.
        if (vm.State.ResultBannerShown) return;

        // Don't restart the banner if we're already showing it for this result
        if (_lastPhase == BlackjackPhase.Result) return;

        int net = vm.State.LastNetResult;
        bool anyBJ   = vm.State.PlayerHands.Any(h => h.Result == BlackjackHandResult.Blackjack);
        bool anyWin  = vm.State.PlayerHands.Any(h => h.Result is BlackjackHandResult.Won or BlackjackHandResult.Blackjack);
        bool allPush = vm.State.PlayerHands.All(h => h.Result == BlackjackHandResult.Push);

        // No Stress Mode's free play doesn't track credits at all — the streak and
        // winning-hand values (shown via headline/streak/hand totals below) still
        // display normally, just without a credit amount attached.
        bool freePlay = vm.Options.IsNoStressMode;
        string netStr = freePlay ? ""
            : net > 0 ? Strings.Get(StringKey.ResultSubNetPositiveFmt, _language).Replace("%d", net.ToString())
            : net < 0 ? Strings.Get(StringKey.ResultSubNetNegativeFmt, _language).Replace("%d", net.ToString())
            : Strings.Get(StringKey.ResultSubEven, _language);

        ResultDealerTotal.Text = Strings.Get(StringKey.ResultDealerValueFmt, _language)
            .Replace("%d", FormatHandTotal(vm.State.DealerHand));
        string playerValueFmt = Strings.Get(StringKey.ResultPlayerValueFmt, _language);
        ResultPlayerTotal.Text = vm.State.PlayerHands.Count > 1
            ? playerValueFmt.Replace("%d", string.Join(" / ", vm.State.PlayerHands.Select(FormatHandTotal)))
            : playerValueFmt.Replace("%d", FormatHandTotal(vm.State.PlayerHands[0]));

        string headline, subline, background;
        bool win;
        int streak;
        bool isNotTodayPartner = false;

        if (anyBJ)
        {
            headline   = Strings.Get(StringKey.ResultHeadlineBlackjack, _language);
            subline    = netStr;
            background = "#80000000";
            win        = true;
            streak     = vm.ConsecutiveWins;
        }
        else if (anyWin)
        {
            headline   = Strings.Get(StringKey.YouWin, _language);
            subline    = netStr;
            background = "#80000000";
            win        = true;
            streak     = vm.ConsecutiveWins;
        }
        else if (allPush)
        {
            headline   = Strings.Get(StringKey.ResultHeadlinePush, _language);
            subline    = freePlay ? "" : Strings.Get(StringKey.ResultSubPush, _language);
            background = "#80000000";
            win        = false;
            streak     = 0;
        }
        else
        {
            bool anyBust = vm.State.PlayerHands.Any(h => h.IsBust);
            isNotTodayPartner = !anyBust;
            headline   = anyBust ? Strings.Get(StringKey.ResultHeadlineBust, _language) : Strings.Get(StringKey.NotTodayPartner, _language);
            subline    = netStr;
            background = "#80000000";
            win        = false;
            streak     = 0;
        }

        // Every outcome (including a natural Blackjack) waits the same 1.5s after the
        // result is known before the banner appears, so the player always gets a beat
        // to see the final hand before it's covered.
        _resultShowTimer?.Stop();
        _resultShowTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(1500) };
        _resultShowTimer.Tick += (_, _) =>
        {
            _resultShowTimer!.Stop();
            _resultShowTimer = null;
            ResultHeadline.Text = headline;
            ResultSubline.Text  = subline;
            ResultOverlay.Background = new SolidColorBrush(Color.Parse(background));
            ResultOverlay.BoxShadow  = BoxShadows.Parse(BannerStyles.GoldGlowBoxShadow);
            ResultOverlay.MaxWidth   = isNotTodayPartner ? 460 : 320;
            ShowBanner(win, streak);
        };
        _resultShowTimer.Start();
    }

    // Dev-only banner preview, wired to the toolbar's local-only "Banners" dropdown
    // (the dropdown itself is only made visible in DEBUG builds — see MainWindow).
    public void DebugShowResultBanner(bool win)
    {
        _resultShowTimer?.Stop();
        _resultShowTimer = null;
        ResultDealerTotal.Text    = "Dealer: 20";
        ResultPlayerTotal.Text    = "Player: 21";
        ResultHeadline.Text       = win ? "You win!" : "Not today, partner!";
        ResultSubline.Text        = win ? "+50 credits" : "-50 credits";
        ResultOverlay.Background  = new SolidColorBrush(Color.Parse("#80000000"));
        ResultOverlay.BoxShadow   = BoxShadows.Parse(BannerStyles.GoldGlowBoxShadow);
        ResultOverlay.MaxWidth    = win ? 320 : 460;
        ShowBanner(win, streak: 0);
    }

    // Dev-only banner-catalog preview — wired to the toolbar's local-only "Banners"
    // dropdown's "Banner Catalog" section (see MainWindow.DebugBannerCategory_Click).
    public void DebugFlashToast(string message) => MilestoneToast.Flash(message, TimeSpan.FromSeconds(2));

    private void BannerDismiss_Click(object? sender, RoutedEventArgs e)
    {
        HideBanner();
    }

    private void ShowBanner(bool win, int streak)
    {
        if (streak >= 2)
        {
            ResultStreak.Text      = streak >= 5 ? Strings.Get(StringKey.StreakText5plusFmt, _language).Replace("%d", streak.ToString())
                                   : streak >= 3 ? Strings.Get(StringKey.StreakText3to4Fmt, _language).Replace("%d", streak.ToString())
                                   :               Strings.Get(StringKey.StreakText2Fmt, _language).Replace("%d", streak.ToString());
            ResultStreak.IsVisible = true;
        }
        else
        {
            ResultStreak.IsVisible = false;
        }

        ResultOverlay.Opacity   = 1.0;
        ResultOverlay.IsVisible = true;
        ResultOverlayScrim.IsVisible = true;
        if (TopLevel.GetTopLevel(this) is MainWindow mw) mw.SizeElementToGameArea(ResultOverlayScrim);
        WeakReferenceMessenger.Default.Send(new BoardScrimRequestMessage(this, true));

        if (win)
            WinParticleSystem.Burst(ParticleCanvas);

        _bannerDelayTimer?.Stop();
        _bannerDelayTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(5000) };
        _bannerDelayTimer.Tick += (_, _) =>
        {
            _bannerDelayTimer!.Stop();
            _bannerDelayTimer = null;
            FadeBanner();
        };
        _bannerDelayTimer.Start();
    }

    private void FadeBanner()
    {
        _bannerFadeTimer?.Stop();
        double opacity = 1.0;
        _bannerFadeTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _bannerFadeTimer.Tick += (_, _) =>
        {
            opacity -= 0.04;
            if (opacity <= 0)
            {
                _bannerFadeTimer!.Stop();
                _bannerFadeTimer = null;
                ResultOverlay.IsVisible = false;
                ResultOverlayScrim.IsVisible = false;
                ResultOverlay.Opacity   = 1.0;
                WeakReferenceMessenger.Default.Send(new BoardScrimRequestMessage(this, false));
                // Checked here, not synchronously when the round resolves — this is the
                // moment the win/lose result banner has actually finished fading out, so
                // the toast reads as following it (and landing alongside the Rebuy button)
                // instead of stacking on top of it.
                if (DataContext is BlackjackViewModel vm) vm.CheckOutOfCredits();
                StartCardsFade();
                return;
            }
            ResultOverlay.Opacity = opacity;
        };
        _bannerFadeTimer.Start();
    }

    // ── Post-result card fade ────────────────────────────────────────────────

    private void StartCardsFade()
    {
        _cardsFadeTimer?.Stop();
        double opacity = 1.0;
        _cardsFadeTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _cardsFadeTimer.Tick += (_, _) =>
        {
            opacity -= 0.025; // ~640 ms total
            if (opacity <= 0)
            {
                _cardsFadeTimer!.Stop();
                _cardsFadeTimer = null;
                DealerCardsPanel.Opacity      = 1.0;
                PlayerHandsContainer.Opacity  = 1.0;
                _cardsFadedOut = true;
                if (DataContext is BlackjackViewModel vm)
                {
                    // Mark this result as fully presented on the ViewModel (not just this
                    // View instance) so switching games and back doesn't replay the banner.
                    vm.State.ResultBannerShown = true;
                    RebuildDealerCards(vm);
                    RebuildPlayerHands(vm);
                }
                return;
            }
            DealerCardsPanel.Opacity     = opacity;
            PlayerHandsContainer.Opacity = opacity;
        };
        _cardsFadeTimer.Start();
    }

    private void StopCardsFade()
    {
        _cardsFadeTimer?.Stop();
        _cardsFadeTimer = null;
        DealerCardsPanel.Opacity     = 1.0;
        PlayerHandsContainer.Opacity = 1.0;
    }

    private void HideBanner()
    {
        _resultShowTimer?.Stop();  _resultShowTimer  = null;
        _bannerDelayTimer?.Stop(); _bannerDelayTimer = null;
        _bannerFadeTimer?.Stop();  _bannerFadeTimer  = null;
        ResultOverlay.IsVisible = false;
        ResultOverlayScrim.IsVisible = false;
        ResultOverlay.Opacity   = 1.0;
        WeakReferenceMessenger.Default.Send(new BoardScrimRequestMessage(this, false));
        StopCardsFade();
    }

    private void StopTimers()
    {
        _resultShowTimer?.Stop();  _resultShowTimer  = null;
        _bannerDelayTimer?.Stop(); _bannerDelayTimer = null;
        _bannerFadeTimer?.Stop();  _bannerFadeTimer  = null;
        _bustFlashTimer?.Stop();   _bustFlashTimer   = null;
        _cardsFadeTimer?.Stop();   _cardsFadeTimer   = null;
        _idleTimer?.Stop();        _idleTimer        = null;
        _idleFadeTimer?.Stop();    _idleFadeTimer    = null;
    }

    // ── Idle nudge ────────────────────────────────────────────────────────────

    private void ResetIdleTimer(BlackjackViewModel vm)
    {
        // Idle "Hit Space to Deal" nudge banner disabled — never scheduled.
        _idleTimer?.Stop();
        _idleTimer = null;
        if (IdlePrompt.Opacity > 0) FadeOutIdlePrompt();
    }

    private void FadeInIdlePrompt()
    {
        _idleFadeTimer?.Stop();
        double opacity = IdlePrompt.Opacity;
        _idleFadeTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _idleFadeTimer.Tick += (_, _) =>
        {
            opacity = Math.Min(1.0, opacity + 16.0 / 600.0);
            IdlePrompt.Opacity = opacity;
            if (opacity >= 1.0) { _idleFadeTimer!.Stop(); _idleFadeTimer = null; }
        };
        _idleFadeTimer.Start();
    }

    private void FadeOutIdlePrompt()
    {
        _idleFadeTimer?.Stop();
        double opacity = IdlePrompt.Opacity;
        if (opacity <= 0) return;
        double speed = opacity / (300.0 / 16.0);
        _idleFadeTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(16) };
        _idleFadeTimer.Tick += (_, _) =>
        {
            opacity = Math.Max(0, opacity - speed);
            IdlePrompt.Opacity = opacity;
            if (opacity <= 0) { _idleFadeTimer!.Stop(); _idleFadeTimer = null; IdlePrompt.Opacity = 0; }
        };
        _idleFadeTimer.Start();
    }

    // ── Felt color ────────────────────────────────────────────────────────────

    private void ApplyFeltColor(BlackjackViewModel vm)
    {
        // BoardFeltGrid no longer paints its own background — it lets the shared
        // window-level felt color + vignette (see MainWindow.ApplyFeltColor) show
        // through underneath, so the same continuous gradient spans the title bar and
        // the board with no seam. BidBar keeps its own darker panel for text contrast.
        string hex = vm.Options.FeltColor switch
        {
            "Crimson"   => "#8C0C26",
            "RoyalBlue" => "#1A3380",
            "Charcoal"  => "#2E2E2E",
            "Desert"    => "#C2967A",
            "Custom"    => vm.Options.CustomFeltColorHex,
            _           => "#008000",
        };
    }

    // ── Keyboard ──────────────────────────────────────────────────────────────

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;

        // Don't steal letter/symbol keystrokes while the user is typing in a TextBox
        // (e.g. the Save Theme name field). Tunnel handlers fire before the focused
        // control, so without this guard 'H'/'S'/etc. trigger game actions mid-typing.
        if (TopLevel.GetTopLevel(this)?.FocusManager?.GetFocusedElement() is TextBox) return;

        switch (e.Key)
        {
            case Key.Space: case Key.Enter:
                if (vm.CanDeal) { DoDeal(vm); }
                e.Handled = true; break;
            case Key.H:
                if (vm.CanHit) { vm.Hit(); SoundService.PlaySnap(); }
                e.Handled = true; break;
            case Key.S:
                if (vm.CanStand) { vm.Stand(); }
                e.Handled = true; break;
            case Key.D:
                if (vm.CanDouble) { vm.DoubleDown(); SoundService.PlaySnap(); }
                e.Handled = true; break;
            case Key.P:
                if (vm.CanSplit) { vm.Split(); SoundService.PlaySnap(); }
                e.Handled = true; break;
        }
    }

    // ── Event handlers ────────────────────────────────────────────────────────

    private void DoDeal(BlackjackViewModel vm)
    {
        HideBanner();
        _cardsFadedOut = false;
        _lastPhase = BlackjackPhase.Betting;
        vm.Deal();
        SoundService.PlayShuffle();
    }

    private void Deal_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;
        DoDeal(vm);
    }

    // Clicking the card backs deals a hand at the current bet, same as pressing
    // Deal/Space — mirrors the same click-to-deal behavior already wired up for
    // Video Poker's card slots. Matches whatever makes the Deal button itself
    // visible/clickable (Betting, Result/"Deal Again", etc.), not just the initial
    // Betting phase — otherwise clicking cards to start the next hand after a
    // finished hand wouldn't work.
    private void CardBack_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm || !vm.CanDeal) return;

        // CanDeal goes true the instant a hand settles (Phase -> Result), well before
        // the win/loss banner has actually revealed to the player (it waits ~1.5s,
        // then stays up until it fades or is dismissed). Without this guard, a stray
        // click anywhere on the card table during that window deals a "ghost" hand
        // underneath the still-pending reveal — and since Deal() can itself settle
        // instantly (e.g. another natural blackjack), the table can cycle through
        // several unintended hands before the player ever sees the first result.
        // The visible "Buy In Again" button and clicking the banner itself are still
        // immediate on purpose — this only blocks the invisible whole-table hitbox.
        if (vm.State.Phase == BlackjackPhase.Result && (_resultShowTimer != null || ResultOverlay.IsVisible))
            return;

        DoDeal(vm);
        e.Handled = true;
    }

    private void Hit_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm || !vm.CanHit) return;
        vm.Hit();
        SoundService.PlaySnap();
    }

    private void Stand_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm || !vm.CanStand) return;
        vm.Stand();
    }

    private void Double_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm || !vm.CanDouble) return;
        vm.DoubleDown();
        SoundService.PlaySnap();
    }

    private void Split_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm || !vm.CanSplit) return;
        vm.Split();
        SoundService.PlaySnap();
    }

    private void Rebuy_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;
        HideBanner();
        vm.Rebuy();
        SoundService.PlaySnap();
    }

    private void Chip_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;
        if (sender is not Button { Tag: string tag } || !int.TryParse(tag, out int amount)) return;
        vm.AddToBet(amount);
    }

    private void DoubleBet_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;
        vm.DoubleBet();
    }

    private void ClearBet_Click(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;
        vm.ClearBet();
    }

    private void ResultOverlay_PointerPressed(object? sender, PointerPressedEventArgs e)
    {
        if (DataContext is not BlackjackViewModel vm) return;
        if (vm.CanDeal) { DoDeal(vm); }
        e.Handled = true;
    }
}
