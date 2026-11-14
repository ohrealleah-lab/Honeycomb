using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Linq;
using Avalonia;
using Avalonia.Input;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

/// <summary>
/// The Beekeeper screen: art frame, Catch Bee, Hive, Bear, Shop, The Workbench, Hippies, wasps and the story log.
/// It only draws what <see cref="BeekeeperViewModel"/> says. Cards appear as the game
/// reveals them and then stay (sticky reveals), so the game starts nearly empty.
/// </summary>
public partial class BeekeeperView : UserControl
{
    private static readonly IBrush SoftCoral = new SolidColorBrush(Color.Parse("#FFA38F"));
    /// <summary>The wall colour (stage 7.5): a price that needs more storage, not merely unaffordable.</summary>
    private static readonly IBrush WallBrush = SoftCoral;
    private static readonly IBrush WhiteBrush = Brushes.White;
    private static readonly IBrush AccentFallback = new SolidColorBrush(Color.Parse("#FFD300"));

    // Older story lines fade: newest first at full strength.
    private static readonly double[] LineOpacity = { 1.0, 0.8, 0.62, 0.46, 0.34, 0.26 };
    private const int MaxVisibleLines = 12;

    private BeekeeperViewModel? _vm;
    private AppLanguage _language = AppLanguage.English;

    private int _shownCatchSerial;
    private readonly DispatcherTimer _popupTimer = new() { Interval = TimeSpan.FromMilliseconds(16) };
    private readonly Stopwatch _popupClock = new();
    private bool _popupStung;
    private readonly DispatcherTimer _lockTimer = new();

    // Shop rows are built once per (tool level, catcher, revealed) so a button is never
    // replaced under the player's mouse while the hive ticks.
    private string _shopSignature = "";
    private readonly Dictionary<string, Button> _shopButtons = new();
    private string _logSignature = "";

    /// <summary>False: the Shop hides tools and the Wax-Catcher once bought, like upgrades.</summary>
    private const bool ShowBoughtItems = false;

    // Wasps only come while the player can see and use this screen (spec 010).
    private Window? _window;
    private bool _onScreen;

    public BeekeeperView()
    {
        InitializeComponent();
        _popupTimer.Tick += PopupTick;
        _lockTimer.Tick += (_, _) => { _lockTimer.Stop(); Redraw(); };
        ApplyAccent();
        AddHandler(PointerPressedEvent, (_, _) => _vm?.NoteActivity(), RoutingStrategies.Tunnel, handledEventsToo: true);
        AddHandler(KeyDownEvent, (_, _) => _vm?.NoteActivity(), RoutingStrategies.Tunnel, handledEventsToo: true);
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            _language = m.Options.Language;
            ApplyAccent();
            _shopSignature = "";
            _logSignature = "";
            _plantsSignature = "";
            _seedsSignature = "";
            _notebookSignature = "";
            _hiveSignature = "";
            Redraw();
        });
        DataContextChanged += (_, _) => Attach(DataContext as BeekeeperViewModel);
        AttachedToVisualTree += (_, _) =>
        {
            _onScreen = true;
            HookWindow(TopLevel.GetTopLevel(this) as Window);
            Attach(DataContext as BeekeeperViewModel);
        };
        DetachedFromVisualTree += (_, _) =>
        {
            _onScreen = false;
            HookWindow(null);
            Attach(null);
        };
    }

    private void Attach(BeekeeperViewModel? vm)
    {
        if (ReferenceEquals(vm, _vm)) { if (vm != null) { UpdateWatched(); Redraw(); } return; }
        if (_vm != null)
        {
            _vm.PropertyChanged -= OnVmChanged;
            _vm.IsWatched = false;
        }
        _vm = vm;
        if (_vm != null)
        {
            _language = SettingsService.LoadOptions().Language;
            _shownCatchSerial = _vm.CatchSerial;      // don't replay an old popup when coming back
            _shopSignature = "";
            _logSignature = "";
            _vm.PropertyChanged += OnVmChanged;
            UpdateWatched();
            Redraw();
        }
    }

    private void HookWindow(Window? window)
    {
        if (ReferenceEquals(window, _window)) return;
        if (_window != null) _window.PropertyChanged -= OnWindowPropertyChanged;
        _window = window;
        if (_window != null) _window.PropertyChanged += OnWindowPropertyChanged;
    }

    private void OnWindowPropertyChanged(object? sender, AvaloniaPropertyChangedEventArgs e)
    {
        if (e.Property == Window.WindowStateProperty) UpdateWatched();
    }

    // On screen and the window not minimised.
    private void UpdateWatched()
    {
        if (_vm != null) _vm.IsWatched = _onScreen && _window?.WindowState != WindowState.Minimized;
    }

    private void OnVmChanged(object? sender, PropertyChangedEventArgs e) => Redraw();

    private void ApplyAccent()
    {
        var hex = SettingsService.LoadOptions().ThemeHintHighlight;
        CatchButton.Background = hex != null && Color.TryParse(hex, out var c) ? new SolidColorBrush(c) : AccentFallback;
    }

    // ------------------------------------------------------------------ drawing

    private void Redraw()
    {
        if (_vm == null) return;
        var vm = _vm;
        var lang = _language;
        string N(decimal v, int d = 0) => NumberFormatter.Format(v, lang, d);

        CatchButton.Content = BeekeeperText.Catch;
        // After a sting the button is red and disabled for a second; a one-shot timer brings it back.
        CatchButton.IsEnabled = !vm.IsStingLocked;
        if (vm.IsStingLocked)
        {
            _lockTimer.Stop();
            _lockTimer.Interval = vm.StingLockoutLeft + TimeSpan.FromMilliseconds(30);
            _lockTimer.Start();
        }

        // The Smoker
        // The Smoker: a button beside Catch Bee once bought; brighter while its boost is on.
        SmokerButton.IsVisible = vm.HasSmoker;
        SmokerButton.Opacity = vm.IsSmokerBoosted ? 1.0 : 0.75;
        ToolTip.SetTip(SmokerButton, BeekeeperText.UpgradeBlurb(BeekeeperUpgrades.Smoker, vm.SmokerBoostPercent));

        // Hive: the title, the groups of rows (built from the view model), the move-hive row.
        HiveCard.IsVisible = vm.HiveCardShown;   // stage 7.5: the drip's first wax can come before any bee
        HiveTitleText.Text = BeekeeperText.HiveTitle(vm.HasWoodenHive, vm.HasMeadow);
        UpdateHive(vm, lang);
        // Bee, 2026-11-12: the Pot honey button is gone; the Honey row's +1 / +10 / +100 links pot honey
        // (opened by the pot-honey story card). Likewise bee bread and beeswax candles left The Workbench.
        WoodenHiveRow.IsVisible = vm.WoodenHiveOffered;
        WoodenHiveNameText.Text = BeekeeperText.WoodenHiveName;
        WoodenHiveInfoText.Text = BeekeeperText.Price(null, N(vm.Config.WoodenHiveWax), null, beeBread: N(vm.Config.WoodenHiveBeeBread))
            + " · " + BeekeeperText.WoodenHiveBlurb(N(vm.WoodenHiveBonusPercent));
        MoveHiveButton.Content = BeekeeperText.Move;
        MoveHiveButton.IsEnabled = vm.CanMoveToWoodenHive;
        ShowWall(WoodenHiveWallText, MoveHiveButton, vm.WoodenHiveIsWall, N(vm.WaxStorage));
        // Stage 8: the meadow, offered once a wildflower and a clover grow; 50 of each buy it (counted, not spent).
        MeadowRow.IsVisible = vm.MeadowOffered;
        if (vm.MeadowOffered)
        {
            MeadowNameText.Text = BeekeeperText.MeadowName;
            MeadowNeedText.Text = BeekeeperText.MeadowNeed(N(vm.MeadowWildflowersHave), N(vm.MeadowWildflowersNeed),
                N(vm.MeadowCloverHave), N(vm.MeadowCloverNeed));
            MeadowInfoText.Text = BeekeeperText.MeadowBlurb(N(vm.MeadowHoneyPerSecond, 2), N(vm.MeadowHoneyRoom), N(vm.MeadowWaxRoom));
            BuyMeadowButton.Content = BeekeeperText.MeadowButton;
            BuyMeadowButton.IsEnabled = vm.CanBuyMeadow;
        }

        // Trading: one shared card, a row per buyer
        var offers = vm.TradeOffers;
        TradeCard.IsVisible = offers.Count > 0;
        TradeTitleText.Text = BeekeeperText.TradingTitle;
        UpdateTrades(offers, lang);
        if (_agreementText != null)
        {
            _agreementText.IsVisible = vm.HasTradeAgreement;
            // Cut in stage 7.5 (spec 016): the agreement's rate hover (no auto-sale any more).
            // SetRateTip(BeekeeperText.BeebitsPerSecond(N(vm.AgreementBeebitsPerSecond, 2)), _agreementText);
        }

        // Shop (also opens with The Workbench, so its upgrades are never out of sight)
        ShopCard.IsVisible = vm.ShopRevealed || vm.WorkbenchRevealed;
        ShopTitleText.Text = BeekeeperText.ShopTitle;
        if (ShopCard.IsVisible) UpdateShop(vm, lang);


        // Combs: how many is on the Hive card; building one is The Workbench's first row (Leah).

        // The Workbench: shows from the first 5 wax (combs); candles join at the 3rd comb (stage 7.5).
        WorkbenchCard.IsVisible = vm.CombRowShown;
        WorkbenchTitleText.Text = BeekeeperText.WorkbenchTitle;
        CombNameText.Text = BeekeeperText.Comb;
        // Stage 7.5 (spec 016): a comb costs bees and wax, and gives honey and room for both.
        // Bee, 2026-11-12: the cost on line 1, what you get on line 2 (the long line ran into the Build button).
        CombsInfoText.Text = BeekeeperText.Price(null, N(vm.CombCost), null, bees: N(vm.CombBeeCost))
            + "\n" + BeekeeperText.CombBlurb(N(vm.HoneyPerComb, 2), N(vm.StoragePerComb), N(vm.WaxStoragePerComb, 1));
        // Cut in stage 7.5: CombsInfoText.Text = BeekeeperText.Price(null, N(vm.CombCost), null) + " · " + BeekeeperText.CombBlurb(N(vm.StoragePerComb));
        BuildCombButton.Content = BeekeeperText.Build;
        BuildCombButton.IsEnabled = vm.CanBuildComb;
        ShowWall(CombWallText, BuildCombButton, vm.CombIsWall, N(vm.WaxStorage));

        // Capacity upgrades (stage 7.5): bought again and again, never walls. Stage 8 (spec 017): the
        // Honey Super costs wood and shows with the first wood; the Wax Tray stays on Beebits.
        // Cut in stage 8: HoneySuperRow.IsVisible = vm.CapacityUpgradesShown;
        // Cut in stage 8: HoneySuperInfoText.Text = BeekeeperText.Price(N(vm.HoneySuperCost), null, null) + ...
        HoneySuperRow.IsVisible = vm.HoneySuperShown;
        HoneySuperNameText.Text = BeekeeperText.HoneySuper;
        HoneySuperInfoText.Text = BeekeeperText.Price(null, null, null, wood: N(vm.HoneySuperCost))
            + "\n" + BeekeeperText.HoneySuperBlurb(N(vm.HoneySuperCapacity), N(vm.HoneySupers));
        BuyHoneySuperButton.Content = BeekeeperText.Add;
        BuyHoneySuperButton.IsEnabled = vm.CanBuyHoneySuper;
        WaxTrayRow.IsVisible = vm.CapacityUpgradesShown;
        WaxTrayNameText.Text = BeekeeperText.WaxTray;
        WaxTrayInfoText.Text = BeekeeperText.Price(N(vm.WaxTrayCost), null, null)
            + "\n" + BeekeeperText.WaxTrayBlurb(N(vm.WaxTrayCapacity, 1), N(vm.WaxTrays));
        BuyWaxTrayButton.Content = BeekeeperText.Add;
        BuyWaxTrayButton.IsEnabled = vm.CanBuyWaxTray;
        // Bee, 2026-11-12: bee bread moved to the Hive card (its row's craft links). Before: a workbench row with Make / x10 / x100.
        // Stage 8: candle prices follow the Dipping Rack, and with the Candle Molds a craft "makes 2".
        // Bee, 2026-11-12: "makes 2" is what you get, so it starts line 2.
        string makes = vm.CandlesPerCraft > 1 ? BeekeeperText.Makes(vm.CandlesPerCraft) + " · " : "";
        // Stage 10: the beeswax candle (wax only) is a craft link on the Beeswax candles Hive row now (Bee, 2026-11-12).
        // The herbal candle (was the sage repellent candle): opens with the first herbs (stage 10: from the bee hotel).
        RepellentRow.IsVisible = vm.RepellentShown;
        RepellentNameText.Text = BeekeeperText.RepellentCandle;
        RepellentInfoText.Text = BeekeeperText.Price(null, N(vm.HerbalCandleWaxNow), N(vm.Config.HerbalCandleHerbs))
            + "\n" + makes + BeekeeperText.RepellentBlurb(BeekeeperText.Roughly(vm.HerbalCandleBurnSeconds));
        // Cut in stage 8: BeekeeperText.Price(null, N(vm.Config.HerbalCandleWax), N(vm.Config.HerbalCandleHerbs))
        HerbBurningText.IsVisible = vm.HerbBuff is not null;
        if (vm.HerbBuff is { } buff)
            HerbBurningText.Text = BeekeeperText.HerbBurning(buff, BeekeeperText.Clock(vm.HerbSecondsLeft));
        // Stage 10: Good Deals says what it does now (only the bear's Beebits).
        ToolTip.SetTip(HerbBurningText, vm.HerbBuff == BeekeeperHerbs.Trades
            ? BeekeeperText.HerbTradesTip((vm.Config.HerbTradeMultiplier - 1m) * 100m) : null);
        CraftRepellentButton.Content = BeekeeperText.Make;
        CraftRepellentButton.IsEnabled = vm.CanCraftRepellent;
        // Stage 8: a candle's wax price above the cap is a wall too (it follows the Dipping Rack).
        ShowWallTip(CraftRepellentButton, vm.CandleIsWall(vm.HerbalCandleWaxNow));
        ShowWallTip(CraftBeeBoostButton, vm.CandleIsWall(vm.BeeBoostCandleWaxNow));
        ShowWallTip(CraftSagePropolisButton, vm.CandleIsWall(vm.SagePropolisCandleWaxNow));
        ShowBatch(Repellent10Button, 10, vm.CanCraftRepellentTimes(10));
        ShowBatch(Repellent100Button, 100, vm.CanCraftRepellentTimes(100));
        LightRepellentButton.Content = BeekeeperText.Light;
        LightRepellentButton.IsVisible = vm.RepellentCandles >= 1m || vm.HerbBuff is not null;
        LightRepellentButton.IsEnabled = vm.CanLightRepellent;

        // The propolis candles (stage 7): once the poplar has sprouted
        BeeBoostRow.IsVisible = vm.PropolisCandlesShown;
        BeeBoostNameText.Text = BeekeeperText.BeeBoostCandle;
        BeeBoostInfoText.Text = BeekeeperText.Price(null, N(vm.BeeBoostCandleWaxNow), null, propolis: N(vm.Config.BeeBoostCandlePropolis))
            + "\n" + makes + BeekeeperText.BeeBoostBlurb(N(vm.BeeBoostBonusPercent), BeekeeperText.Roughly(vm.Config.BeeBoostBurnSeconds));
        CraftBeeBoostButton.Content = BeekeeperText.Make;
        CraftBeeBoostButton.IsEnabled = vm.CanCraftBeeBoost;
        ShowBatch(BeeBoost10Button, 10, vm.CanCraftBeeBoostTimes(10));
        ShowBatch(BeeBoost100Button, 100, vm.CanCraftBeeBoostTimes(100));
        LightBeeBoostButton.Content = BeekeeperText.LightBeeBoost;
        LightBeeBoostButton.IsEnabled = vm.CanLightBeeBoost;
        SagePropolisRow.IsVisible = vm.PropolisCandlesShown;
        SagePropolisNameText.Text = BeekeeperText.SagePropolisCandle;
        SagePropolisInfoText.Text = BeekeeperText.Price(null, N(vm.SagePropolisCandleWaxNow), N(vm.Config.SagePropolisCandleHerbs),
                propolis: N(vm.Config.SagePropolisCandlePropolis))
            + "\n" + makes + BeekeeperText.SagePropolisBlurb(N(vm.SagePropolisBonusPercent), BeekeeperText.Roughly(vm.Config.SagePropolisBurnSeconds));
        CraftSagePropolisButton.Content = BeekeeperText.Make;
        CraftSagePropolisButton.IsEnabled = vm.CanCraftSagePropolis;
        ShowBatch(SagePropolis10Button, 10, vm.CanCraftSagePropolisTimes(10));
        ShowBatch(SagePropolis100Button, 100, vm.CanCraftSagePropolisTimes(100));
        LightSagePropolisButton.Content = BeekeeperText.LightSagePropolis;
        LightSagePropolisButton.IsEnabled = vm.CanLightSagePropolis;

        // The Notebook (stage 7): the Bees card, once bought
        NotebookCard.IsVisible = vm.HasNotebook;
        NotebookTitleText.Text = BeekeeperText.NotebookTitle;
        if (vm.HasNotebook) UpdateNotebook(vm, lang);

        // The Garden (stage 8): the seeds in hand by kind, the plants by kind with their counts
        GardenCard.IsVisible = vm.GardenRevealed || vm.BloomShown;   // stage 9: a debug start can come before the garden
        // Before stage 9: GardenCard.IsVisible = vm.GardenRevealed;
        GardenTitleText.Text = BeekeeperText.GardenTitle;
        // Stage 9: "In bloom: linden · 9 h left", refreshed every tick like the other timers.
        if (vm.Bloom is { } bloom)
        {
            BloomText.IsVisible = true;
            BloomText.Text = BeekeeperText.BloomLine(bloom);
            ToolTip.SetTip(BloomText, BeekeeperText.BloomTip(bloom));
        }
        else BloomText.IsVisible = false;
        // Cut in stage 8 (spec 017): UpdateBeds(vm);   // plants grow at once
        // Cut (Bee, 2026-11-11): the seed rows with their Plant buttons. A new kind is planted from the
        // story card ("Plant it?"), and seeds of a kind already growing plant themselves.
        // UpdateSeeds(vm, lang);
        SeedRows.IsVisible = false;
        UpdatePlants(vm, lang);

        // Wasps (never again once the emissary has come)
        bool burning = vm.RepellentSecondsLeft > 0m;
        WaspCard.IsVisible = !vm.EmissaryCome && (vm.WaspApproaching || burning);
        WaspTitleText.Text = BeekeeperText.WaspsTitle;
        WaspHerePanel.IsVisible = vm.WaspApproaching;
        WaspHereText.Text = BeekeeperText.WaspHere;
        WaspTimeText.Text = BeekeeperText.TimeLeft(BeekeeperText.Clock(vm.WaspSecondsLeft));
        ThrowShoeButton.Content = BeekeeperText.ThrowShoe;
        ThrowShoeButton.IsEnabled = vm.CanThrowShoe;
        BribeButton.Content = BeekeeperText.Bribe(N(vm.BribeCost));
        BribeButton.IsEnabled = vm.CanBribe;
        // First visit: Throw a shoe / Engage. Later visits: Throw a shoe / Bribe.
        EngageWaspButton.Content = BeekeeperText.Engage;
        EngageWaspButton.IsVisible = vm.WaspFirstVisit;
        EngageWaspButton.IsEnabled = vm.CanEngageWasp;
        BribeButton.IsVisible = !vm.WaspFirstVisit;
        UpdateVisitors(vm.RepsPresent, vm.BearName, lang);
        UpdateStory(vm, lang);
        ArtLayer.IsVisible = !StoryCard.IsVisible && !VisitorsCard.IsVisible;   // the bee art when there is no story
        // Cut: the wasp card's "Light a candle" button (sage candles are going away).
        // WaspLightButton.Content = BeekeeperText.LightCandle;
        // WaspLightButton.IsVisible = vm.RepellentShown;
        // WaspLightButton.IsEnabled = vm.CanLightRepellent;
        CandleBurningText.IsVisible = burning && !vm.WaspApproaching;
        CandleBurningText.Text = BeekeeperText.CandleBurning(BeekeeperText.Clock(vm.RepellentSecondsLeft));

        // Log (Bee, 2026-11-12: the HIVE LOG card waits for the first bee caught)
        LogCard.IsVisible = vm.LogCardShown;
        LogTitleText.Text = BeekeeperText.LogTitle;
        UpdateLog(vm, lang);

        // Catch popup (a new click since last time)
        if (vm.CatchSerial != _shownCatchSerial)
        {
            _shownCatchSerial = vm.CatchSerial;
            if (vm.LastCatch is { } c) StartPopup(c.Stung, c.BeesGained);
        }
    }

    /// <summary>A wall (stage 7.5, spec 016): the price is above the wax cap. The row says it needs more
    /// storage in the wall colour, and the (disabled) button's hover names the ways past. A price the
    /// player merely can't afford yet shows neither. The view model decides; this only draws.</summary>
    private static void ShowWall(TextBlock text, Button button, bool wall, string holds)
    {
        // Cut (may return, Bee 2026-11-10): the red "needs more wax storage" line. The disabled button's hover still explains.
        // text.IsVisible = wall;
        // text.Foreground = WallBrush;
        // text.Opacity = 1.0;
        // if (wall) text.Text = BeekeeperText.WaxWall(holds);
        text.IsVisible = false;
        ShowWallTip(button, wall);
    }

    /// <summary>A wall's hover on its (disabled) button: the ways past it.</summary>
    private static void ShowWallTip(Button button, bool wall)
    {
        ToolTip.SetShowOnDisabled(button, true);
        ToolTip.SetTip(button, wall ? BeekeeperText.WaxWallTip : null);
    }

    // Batch buttons (x10, x100) are hidden until the whole batch can be paid for.
    private static void ShowBatch(Button button, int count, bool affordable)
    {
        button.Content = BeekeeperText.MakeTimes(count);
        button.IsVisible = affordable;
    }

    private void Batch_Click(object? sender, RoutedEventArgs e)
    {
        if (_vm == null || sender is not Button { Tag: string tag }) return;
        var parts = tag.Split(':');
        int n = int.Parse(parts[1]);
        switch (parts[0])
        {
            case "Repellent": _vm.CraftRepellentTimes(n); break;
            case "BeeBoost": _vm.CraftBeeBoostTimes(n); break;
            case "SagePropolis": _vm.CraftSagePropolisTimes(n); break;
        }
    }

    private static void SetRateTip(string? text, params Control[] targets)
    {
        foreach (var t in targets) ToolTip.SetTip(t, text);
    }

    // The Hive card's groups are rebuilt only when a row appears or the language changes, so
    // a row is never swapped under the mouse (its hover text); values refresh every tick.
    private string _hiveSignature = "";
    private readonly Dictionary<string, (TextBlock Label, TextBlock? Value)> _hiveRows = new();

    private void UpdateHive(BeekeeperViewModel vm, AppLanguage lang)
    {
        var groups = vm.HiveGroups;
        // Lines that come and go on ticks (combs full, a candle burning) are always built and just
        // shown or hidden, so they never trigger a rebuild under the mouse.
        static bool Transient(string id) =>
            id is BeekeeperHiveRows.CombsFull or BeekeeperHiveRows.WaxFull
                or BeekeeperHiveRows.BeeBoostBurning or BeekeeperHiveRows.SagePropolisBurning;
        string sig = lang + "|" + vm.OpenCrafts + "|" + string.Join(";", groups.Select(g =>
            g.Id + ":" + string.Join(",", g.Rows.Where(r => r.Visible && !Transient(r.Id)).Select(r => r.Id))));
        if (sig != _hiveSignature)
        {
            _hiveSignature = sig;
            _hiveRows.Clear();
            _craftLinks.Clear();
            HiveGroups.Children.Clear();
            foreach (var g in groups)
            {
                if (!g.Rows.Any(r => r.Visible && !Transient(r.Id))) continue;
                var panel = new StackPanel { Spacing = 2 };
                panel.Children.Add(new TextBlock
                {
                    Text = BeekeeperText.HiveGroupTitle(g.Id),
                    Classes = { "bk-muted" },
                    FontWeight = FontWeight.SemiBold,
                    Margin = new Thickness(0, 0, 0, 2),
                });
                foreach (var r in g.Rows)
                {
                    if (!r.Visible && !Transient(r.Id)) continue;
                    if (BeekeeperText.IsHiveLine(r.Id))
                    {
                        // A whole-line row: a specialty, or the "combs are full" warning.
                        var line = new TextBlock { Classes = { "bk-body" } };
                        if (r.Id is BeekeeperHiveRows.CombsFull or BeekeeperHiveRows.WaxFull) line.Foreground = SoftCoral;
                        else line.Opacity = 0.9;
                        panel.Children.Add(line);
                        _hiveRows[r.Id] = (line, null);
                        continue;
                    }
                    // Bee, 2026-11-12: a row that makes something shows +1 / +10 / +100 links after its label,
                    // once its story card has opened them.
                    string? craft = BeekeeperViewModel.CraftOfRow(r.Id);
                    bool links = craft is not null && vm.CraftLinksOpen(craft);
                    var grid = new Grid { ColumnDefinitions = new ColumnDefinitions(links ? "Auto,Auto,*,Auto" : "*,Auto") };
                    var label = new TextBlock { Classes = { "bk-body" }, Opacity = 0.75 };
                    var value = new TextBlock { Classes = { "bk-body" }, FontWeight = FontWeight.SemiBold };
                    Grid.SetColumn(value, links ? 3 : 1);
                    grid.Children.Add(label);
                    if (links) { var linkPanel = BuildCraftLinks(craft!, r.Id); Grid.SetColumn(linkPanel, 1); grid.Children.Add(linkPanel); }
                    grid.Children.Add(value);
                    panel.Children.Add(grid);
                    _hiveRows[r.Id] = (label, value);
                }
                HiveGroups.Children.Add(panel);
            }
        }

        // Cheap per-tick part: words, numbers and hover rates.
        foreach (var g in groups)
            foreach (var r in g.Rows)
            {
                if (!_hiveRows.TryGetValue(r.Id, out var c)) continue;
                if (Transient(r.Id)) c.Label.IsVisible = r.Visible;
                if (!r.Visible) continue;
                c.Label.Text = BeekeeperText.HiveRowLabel(r);
                string? tip = BeekeeperText.HiveRowTip(r);
                if (c.Value is { } v)
                {
                    v.Text = BeekeeperText.HiveRowValue(r);
                    // The shared rule: a capped number (SecondsToFull is 0) is colored, in place of a warning line.
                    // (Not "= null": a local null brush draws no text at all; clearing the value restores the style's color.)
                    if (r.SecondsToFull is 0m) v.Foreground = SoftCoral; else v.ClearValue(TextBlock.ForegroundProperty);
                    SetRateTip(tip, c.Label, v);
                }
                else SetRateTip(tip, c.Label);
            }

        // The craft links: their sizes (+1, +10, then +100 or +1000), dimmed while a size can't be paid for, and
        // a hover with what that click costs (the recipe left The Workbench, so the price shows here).
        foreach (var (craft, links) in _craftLinks.Values)
        {
            int[] steps = { 1, vm.Config.CraftLinkMedium, vm.CraftBigStep(craft) };
            for (int i = 0; i < links.Length; i++)
            {
                bool can = vm.CanCraftTimes(craft, steps[i]);
                links[i].Text = BeekeeperText.CraftLink(steps[i]);
                links[i].Opacity = can ? 1.0 : 0.4;
                // Bee, 2026-11-14: +10 and +100 (or +1000) only show while the materials for that size exist;
                // +1 always shows (dimmed when it can't be paid for).
                links[i].IsVisible = i == 0 || can;
                ToolTip.SetTip(links[i], CraftLinkTip(vm, craft, steps[i], lang, can));
            }
        }
    }

    // The three craft links (+1, +10, +100/+1000) of each Hive row that has them, refreshed every tick.
    private readonly Dictionary<string, (string Craft, TextBlock[] Links)> _craftLinks = new();

    private StackPanel BuildCraftLinks(string craft, string rowId)
    {
        var panel = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10, Margin = new Thickness(10, 0, 0, 0) };
        var links = new TextBlock[3];
        for (int i = 0; i < links.Length; i++)
        {
            int slot = i;
            var link = new TextBlock
            {
                Classes = { "bk-body" }, Foreground = AccentFallback, TextDecorations = TextDecorations.Underline,
                Cursor = new Cursor(StandardCursorType.Hand), Background = Brushes.Transparent,
            };
            link.PointerPressed += (_, e) =>
            {
                if (_vm == null || !e.GetCurrentPoint(link).Properties.IsLeftButtonPressed) return;
                int n = slot == 0 ? 1 : slot == 1 ? _vm.Config.CraftLinkMedium : _vm.CraftBigStep(craft);
                if (_vm.CanCraftTimes(craft, n)) _vm.CraftTimes(craft, n);
            };
            links[i] = link;
            panel.Children.Add(link);
        }
        _craftLinks[rowId] = (craft, links);
        return panel;
    }

    /// <summary>What one click of a craft link costs (and, for candles, how many it makes).</summary>
    private static string CraftLinkTip(BeekeeperViewModel vm, string craft, int n, AppLanguage lang, bool can)
    {
        string N(decimal v) => NumberFormatter.Format(v, lang);
        switch (craft)
        {
            case BeekeeperStories.PotHoney:
                return BeekeeperText.Price(null, null, null, honey: N(vm.Config.PotHoneyHoney * n))
                    + " · " + N(vm.Config.PotHoneyJars * n) + " " + BeekeeperText.HiveRowLabel(new BeekeeperHiveRow(BeekeeperHiveRows.ClayJars, true)).ToLowerInvariant();
            case BeekeeperStories.Candle:
            {
                string tip = BeekeeperText.Price(null, N(vm.BeeswaxCandleWaxNow * n), null);
                if (vm.CandlesPerCraft > 1) tip += " · " + BeekeeperText.Makes(vm.CandlesPerCraft * n);
                if (!can && vm.CandleIsWall(vm.BeeswaxCandleWaxNow * n)) tip += "\n" + BeekeeperText.WaxWallTip;
                return tip;
            }
            default:   // bee bread
                return BeekeeperText.Price(null, null, null, pollen: N(vm.Config.BeeBreadPollen * n), honey: N(vm.Config.BeeBreadHoney * n));
        }
    }

    // Cut in stage 8 (spec 017, FR-815): plants grow at once, so there are no bed rows.
    // // The beds are plain text, so they are simply redrawn each tick (a row per bed, empty or growing).
    // private void UpdateBeds(BeekeeperViewModel vm)
    // {
    //     var growing = vm.GrowingBeds;
    //     int total = vm.BedRowCount;
    //     while (BedRows.Children.Count > total) BedRows.Children.RemoveAt(BedRows.Children.Count - 1);
    //     while (BedRows.Children.Count < total) BedRows.Children.Add(new TextBlock { Classes = { "bk-body" } });
    //     for (int i = 0; i < total; i++)
    //     {
    //         var line = (TextBlock)BedRows.Children[i];
    //         bool busy = i < growing.Count;
    //         line.Text = busy ? BeekeeperText.BedGrowing(growing[i].Plant, growing[i].SecondsLeft) : BeekeeperText.GardenEmptyBed;
    //         line.Opacity = busy ? 1.0 : 0.6;
    //     }
    // }

    // One row per kind of seed in hand, with the count and a Plant button that plants one (stage 8).
    // Rebuilt only when a kind comes or goes, so a button is never swapped under the mouse; the
    // counts and enabled states are refreshed every tick.
    private string _seedsSignature = "";
    private readonly Dictionary<string, (TextBlock Line, Button Plant)> _seedRows = new();

    private void UpdateSeeds(BeekeeperViewModel vm, AppLanguage lang)
    {
        var rows = vm.SeedRows;
        string sig = lang + "|" + string.Join(",", rows.Select(r => r.Plant.Id));
        if (sig != _seedsSignature)
        {
            _seedsSignature = sig;
            _seedRows.Clear();
            SeedRows.Children.Clear();
            foreach (var r in rows)
            {
                var id = r.Plant.Id;
                var row = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
                var line = new TextBlock
                {
                    Classes = { "bk-body" }, FontWeight = FontWeight.SemiBold, VerticalAlignment = VerticalAlignment.Center,
                };
                row.Children.Add(line);
                var button = new Button
                {
                    Classes = { "bk-button" }, MinWidth = 90, Content = BeekeeperText.GardenPlant,
                    HorizontalContentAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center,
                };
                // Cut in stage 8 (spec 017): the hover said how long the plant takes to grow.
                // ToolTip.SetTip(button, BeekeeperText.TakesToGrow(plant.GrowSeconds));
                button.Click += (_, _) => _vm?.PlantSeedCommand.Execute(id);
                Grid.SetColumn(button, 1);
                row.Children.Add(button);
                SeedRows.Children.Add(row);
                _seedRows[id] = (line, button);
            }
        }
        foreach (var r in rows)
        {
            if (!_seedRows.TryGetValue(r.Plant.Id, out var c)) continue;
            c.Line.Text = BeekeeperText.SeedsLine(r.Plant.Id, r.Count);
            c.Plant.IsEnabled = vm.CanPlantSeedOf(r.Plant.Id);
        }
    }

    // The Notebook (stage 8: two tabs). The notes and the bees are plain text, rebuilt only when
    // something is added; a fact is picked at random each time the Bees tab opens.
    private string _notebookSignature = "";
    private string _beesSignature = "";
    private bool _beesTab;
    private readonly Dictionary<string, string> _beeFacts = new();

    private void UpdateNotebook(BeekeeperViewModel vm, AppLanguage lang)
    {
        NotesTabButton.Content = BeekeeperText.TabNotes;
        BeesTabButton.Content = BeekeeperText.TabBees;
        NotesTabButton.Opacity = _beesTab ? 0.6 : 1.0;
        BeesTabButton.Opacity = _beesTab ? 1.0 : 0.6;
        NotebookRows.IsVisible = !_beesTab;
        BeesRows.IsVisible = _beesTab;
        if (_beesTab) { UpdateBees(vm, lang); return; }

        var notes = vm.NotebookNotes;
        string sig = lang + "|" + string.Join(",", notes);
        if (sig == _notebookSignature) return;
        _notebookSignature = sig;
        NotebookRows.Children.Clear();
        foreach (var id in notes)
            NotebookRows.Children.Add(new TextBlock { Text = BeekeeperText.NotebookNote(id), Classes = { "bk-body" }, Opacity = 0.9 });
    }

    private void UpdateBees(BeekeeperViewModel vm, AppLanguage lang)
    {
        var bees = vm.BeesMet;
        string sig = lang + "|" + string.Join(",", bees);
        if (sig == _beesSignature) return;
        _beesSignature = sig;
        BeesRows.Children.Clear();
        foreach (var id in bees)
        {
            if (!_beeFacts.ContainsKey(id))
            {
                var facts = BeekeeperText.BeeFacts(id);
                _beeFacts[id] = facts.Count == 0 ? "" : facts[Random.Shared.Next(facts.Count)];
            }
            var row = new StackPanel { Spacing = 2 };
            row.Children.Add(new TextBlock { Text = BeekeeperText.BeeTitle(id), Classes = { "bk-body" }, FontWeight = FontWeight.SemiBold });
            row.Children.Add(new TextBlock { Text = BeekeeperText.BeeDoes(id), Classes = { "bk-body" }, Opacity = 0.9, TextWrapping = TextWrapping.Wrap });
            row.Children.Add(new TextBlock { Text = _beeFacts[id], Classes = { "bk-muted" }, TextWrapping = TextWrapping.Wrap });
            BeesRows.Children.Add(row);
        }
    }

    private void NotesTab_Click(object? sender, RoutedEventArgs e)
    {
        _beesTab = false;
        if (_vm != null) UpdateNotebook(_vm, SettingsService.LoadOptions().Language);
    }

    private void BeesTab_Click(object? sender, RoutedEventArgs e)
    {
        // Each time the tab opens, every bee picks a fresh fact from its list.
        _beesTab = true;
        _beeFacts.Clear();
        _beesSignature = "";
        if (_vm != null) UpdateNotebook(_vm, SettingsService.LoadOptions().Language);
    }

    // One row per kind of plant growing, with how many, its specialty and (stage 8) the bonus the
    // plants after the first add. Rebuilt only when a kind comes; the counts refresh every tick.
    private string _plantsSignature = "";
    private readonly Dictionary<string, (TextBlock Count, TextBlock Bonus)> _plantRows = new();

    private void UpdatePlants(BeekeeperViewModel vm, AppLanguage lang)
    {
        var rows = vm.PlantRows;
        string sig = lang + "|" + string.Join(",", rows.Select(r => r.Plant.Id));
        if (sig != _plantsSignature)
        {
            _plantsSignature = sig;
            _plantRows.Clear();
            PlantRows.Children.Clear();
            foreach (var r in rows)
            {
                var p = r.Plant;
                var row = new StackPanel { Spacing = 2 };
                var head = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
                head.Children.Add(new TextBlock { Text = BeekeeperText.PlantLine(p), Classes = { "bk-body" }, FontWeight = FontWeight.SemiBold });
                var count = new TextBlock { Classes = { "bk-body" }, FontWeight = FontWeight.SemiBold };
                Grid.SetColumn(count, 1);
                head.Children.Add(count);
                row.Children.Add(head);
                row.Children.Add(new TextBlock { Text = BeekeeperText.PlantBlurb(p.Id), Classes = { "bk-muted" }, TextWrapping = TextWrapping.Wrap });
                var bonus = new TextBlock { Classes = { "bk-muted" }, TextWrapping = TextWrapping.Wrap };
                row.Children.Add(bonus);
                PlantRows.Children.Add(row);
                _plantRows[p.Id] = (count, bonus);
            }
        }
        foreach (var r in rows)
        {
            if (!_plantRows.TryGetValue(r.Plant.Id, out var c)) continue;
            c.Count.Text = NumberFormatter.Format(r.Count, lang);
            c.Bonus.IsVisible = r.Plant.BonusPerExtra > 0m;
            c.Bonus.Text = BeekeeperText.PlantBonusLine(r.Plant, vm.PlantBonusPercent(r.Plant));
        }
        // Cut in stage 8 (spec 017): one line per sprouted plant, one plant of each kind.
        // foreach (var p in vm.SproutedPlants) { PlantLine(p); PlantBlurb(p.Id); }
    }

    private void UpdateShop(BeekeeperViewModel vm, AppLanguage lang)
    {
        string N(decimal v) => NumberFormatter.Format(v, lang);
        string? Part(decimal v) => v > 0m ? N(v) : null;
        var upgrades = vm.ShopUpgrades;
        string sig = $"{vm.ToolLevel}|{vm.BeesPerClick}|{vm.HasWaxCatcher}|{vm.WaxCatcherRoom}|{lang}|{string.Join(",", upgrades.Select(u => u.Id))}";
        if (sig != _shopSignature)
        {
            _shopSignature = sig;
            _shopButtons.Clear();
            _shopWalls.Clear();
            ShopRows.Children.Clear();

            // Bought things are hidden (Leah, 2026-11-07): only the next tool is listed. A
            // "show bought things" option may come later; it would just flip ShowBoughtItems.
            // Bee, 2026-11-11: no catching tools without the gloves, and the gloves (tool 0) are found
            // in a story card, never listed here.
            for (int i = 0; i < vm.Config.Tools.Count; i++)
            {
                if (vm.ToolLevel < 1) break;
                if (i == 0) continue;
                var tool = vm.Config.Tools[i];
                bool owned = vm.ToolLevel > i;
                bool isNext = vm.ToolLevel == i;
                if (!isNext && !(owned && ShowBoughtItems)) continue;
                ShopRows.Children.Add(MakeShopRow(
                    BeekeeperText.ToolName(tool.Id), BeekeeperText.ToolBlurb(tool.Id, vm.BeesPerClickWith(tool)),
                    owned, BeekeeperText.Price(N(tool.Cost), null, null), tool.Id, vm.BuyNextToolCommand.Execute));
            }
            if (!vm.HasWaxCatcher || ShowBoughtItems)
                ShopRows.Children.Add(MakeShopRow(
                    BeekeeperText.WaxCatcherName, BeekeeperText.WaxCatcherBlurb(N(vm.WaxCatcherRoom)),
                    vm.HasWaxCatcher, BeekeeperText.Price(N(vm.Config.WaxCatcherCost), null, null), "catcher", vm.BuyWaxCatcherCommand.Execute));

            // Upgrades: only unlocked, not-yet-bought ones are listed (bought ones leave the Shop).
            foreach (var u in upgrades)
            {
                string id = u.Id;
                // Stage 8: wood joins the price; the Bee Hotel's blurb says how often a gift comes.
                string blurb = id == BeekeeperUpgrades.BeeHotel
                    ? BeekeeperText.HotelBlurb(vm.Config.HotelGiftSeconds)
                    : BeekeeperText.UpgradeBlurb(id, vm.UpgradeBonusPercent(id));
                ShopRows.Children.Add(MakeShopRow(
                    BeekeeperText.UpgradeName(id), blurb, false,
                    BeekeeperText.Price(Part(u.Beebits), Part(u.Wax), Part(u.Herbs), paper: Part(u.Paper), propolis: Part(u.Propolis),
                        bees: Part(u.Bees), wood: Part(u.Wood)),
                    "upgrade:" + id, _ => vm.BuyUpgrade(id), withWall: true));
            }
        }

        // Cheap per-tick part: only the buttons' enabled state.
        for (int i = 0; i < vm.Config.Tools.Count; i++)
        {
            var id = vm.Config.Tools[i].Id;
            if (_shopButtons.TryGetValue(id, out var b)) b.IsEnabled = vm.ToolLevel == i && vm.CanBuyNextTool;
        }
        if (_shopButtons.TryGetValue("catcher", out var cb)) cb.IsEnabled = vm.CanBuyWaxCatcher;
        foreach (var u in upgrades)
        {
            if (!_shopButtons.TryGetValue("upgrade:" + u.Id, out var ub)) continue;
            ub.IsEnabled = vm.CanBuyUpgrade(u.Id);
            // Stage 7.5: a wax price above the cap reads as needing more storage, and goes away by itself.
            if (_shopWalls.TryGetValue("upgrade:" + u.Id, out var wall))
                ShowWall(wall, ub, vm.UpgradeIsWall(u.Id), N(vm.WaxStorage));
        }
    }

    // Trade rows are rebuilt only when a buyer arrives or the language changes, so a button is
    // never swapped under the mouse; names and enabled states are refreshed every tick.
    private string _tradeSignature = "";
    private readonly Dictionary<string, (TextBlock Name, Button One, Button? All, Button? Ten, Button? Hundred)> _tradeRows = new();
    private readonly Dictionary<string, TextBlock> _tradeRates = new();
    private TextBlock? _agreementText;
    // Stage 10: the bear's potted-honey buttons and rate line (once the first potted honey is made).
    private (Button One, Button All, TextBlock Rate)? _pottedRow;

    private void UpdateTrades(IReadOnlyList<BeekeeperTradeOffer> offers, AppLanguage lang)
    {
        // Stage 10: the bear's potted-honey buttons arrive with the first potted honey, so they are part of the signature.
        string sig = lang + "|" + string.Join(",", offers.Select(o => o.Id + (o.PottedShown ? "+potted" : "")));
        if (sig != _tradeSignature)
        {
            _tradeSignature = sig;
            _tradeRows.Clear();
            _tradeRates.Clear();
            _agreementText = null;
            _pottedRow = null;
            TradeRows.Children.Clear();
            foreach (var offer in offers)
            {
                var o = offer;   // the row's buttons call the offer of the moment, looked up by id
                BeekeeperTradeOffer? Now() => _vm?.TradeOffers.FirstOrDefault(x => x.Id == o.Id);
                var name = new TextBlock { FontFamily = new FontFamily("Georgia"), FontSize = 20, Foreground = WhiteBrush };
                var buttons = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
                Button one;
                Button? all = null, ten = null, hundred = null;
                if (o.TradeTimes != null)
                {
                    // One trade, plus x10 and x100 shown only when the whole batch is affordable
                    // (the wasps' paper, spec 014).
                    one = new Button { Classes = { "bk-button" }, Content = BeekeeperText.TradeOne };
                    ten = new Button { Classes = { "bk-button" }, Content = BeekeeperText.MakeTimes(10), IsVisible = false };
                    hundred = new Button { Classes = { "bk-button" }, Content = BeekeeperText.MakeTimes(100), IsVisible = false };
                    one.Click += (_, _) => Now()?.TradeOne();
                    ten.Click += (_, _) => Now()?.TradeTimes?.Invoke(10);
                    hundred.Click += (_, _) => Now()?.TradeTimes?.Invoke(100);
                    buttons.Children.Add(one);
                    buttons.Children.Add(ten);
                    buttons.Children.Add(hundred);
                }
                else
                {
                    one = new Button { Classes = { "bk-button" }, Content = BeekeeperText.TradeTen };
                    all = new Button { Classes = { "bk-button" }, Content = BeekeeperText.TradeAll };
                    one.Click += (_, _) => Now()?.TradeOne();
                    all.Click += (_, _) => Now()?.TradeAll();
                    buttons.Children.Add(one);
                    buttons.Children.Add(all);
                }

                var row = new StackPanel { Spacing = 6 };
                row.Children.Add(name);
                row.Children.Add(buttons);
                var rate = new TextBlock { Text = BeekeeperText.TradeRate(o.Id, o.GiveAmount, o.GetAmount), Classes = { "bk-muted" } };
                row.Children.Add(rate);
                _tradeRates[o.Id] = rate;
                if (o.Id == "bear")
                {
                    // The bear's trade agreement (25 trades): shown once offered.
                    _agreementText = new TextBlock { Text = BeekeeperText.AgreementLine, Classes = { "bk-muted" }, IsVisible = false };
                    row.Children.Add(_agreementText);
                    if (o.PottedShown)
                    {
                        // Stage 10: potted honey sells only to the bear, one or all (each click is one trade).
                        var potted = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Margin = new Thickness(0, 4, 0, 0) };
                        var sellOne = new Button { Classes = { "bk-button" }, Content = BeekeeperText.SellPotted };
                        var sellAll = new Button { Classes = { "bk-button" }, Content = BeekeeperText.SellAllPotted };
                        sellOne.Click += (_, _) => Now()?.SellPotted?.Invoke();
                        sellAll.Click += (_, _) => Now()?.SellAllPotted?.Invoke();
                        potted.Children.Add(sellOne);
                        potted.Children.Add(sellAll);
                        row.Children.Add(potted);
                        var pottedRate = new TextBlock { Text = BeekeeperText.PottedRate(o.PottedGet), Classes = { "bk-muted" } };
                        row.Children.Add(pottedRate);
                        _pottedRow = (sellOne, sellAll, pottedRate);
                    }
                }
                TradeRows.Children.Add(row);
                _tradeRows[o.Id] = (name, one, all, ten, hundred);
            }
        }

        foreach (var o in offers)
        {
            if (!_tradeRows.TryGetValue(o.Id, out var r)) continue;
            r.Name.Text = BeekeeperText.TraderLine(o.Id, o.Name, o.Trades);
            r.One.IsEnabled = o.CanTrade;
            // Stage 7.5: the bear's bundle changes with the trade agreement (10, then 8), so the rate
            // line and the "Trade 10" button are rewritten every tick rather than only on a rebuild.
            if (_tradeRates.TryGetValue(o.Id, out var rateText)) rateText.Text = BeekeeperText.TradeRate(o.Id, o.GiveAmount, o.GetAmount);
            // Every buyer's button is one trade, so "Trade 1" (Bee, 2026-11-11: the bear's read "Trade 10",
            // the honey in his bundle, which looked like ten trades).
            // Before: if (o.TradeTimes == null) r.One.Content = BeekeeperText.TradeBundle(o.Id == "bear" ? o.GiveAmount : 1m);
            if (o.TradeTimes == null) r.One.Content = BeekeeperText.TradeBundle(1m);
            // Stage 10: the Hippies' button says the trade: "Trade 3 candles for a clay jar".
            if (o.Id == "hippies") r.One.Content = BeekeeperText.TradeJar(o.GiveAmount);
            if (o.Id == "bear" && _pottedRow is { } p)
            {
                p.One.IsEnabled = o.CanSellPotted;
                p.All.IsEnabled = o.CanSellPotted;
                p.Rate.Text = BeekeeperText.PottedRate(o.PottedGet);   // follows the Trades herb
            }
            if (r.All != null) r.All.IsEnabled = o.CanTrade;
            if (r.Ten != null) r.Ten.IsVisible = o.CanTradeTimes?.Invoke(10) == true;
            if (r.Hundred != null) r.Hundred.IsVisible = o.CanTradeTimes?.Invoke(100) == true;
        }
    }

    // The wall line under each Shop upgrade (stage 7.5), by the same id as its button.
    private readonly Dictionary<string, TextBlock> _shopWalls = new();

    private Control MakeShopRow(string name, string blurb, bool owned, string price, string id, Action<object?> buy,
                                bool withWall = false)
    {
        var row = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        var text = new StackPanel { Spacing = 2, VerticalAlignment = VerticalAlignment.Center };
        text.Children.Add(new TextBlock { Text = name, Classes = { "bk-body" }, FontWeight = FontWeight.SemiBold });
        text.Children.Add(new TextBlock { Text = blurb, Classes = { "bk-muted" } });
        if (withWall)
        {
            var wall = new TextBlock { Classes = { "bk-muted" }, IsVisible = false };
            text.Children.Add(wall);
            _shopWalls[id] = wall;
        }
        row.Children.Add(text);

        var button = new Button
        {
            Classes = { "bk-button" },
            MinWidth = 110,
            HorizontalContentAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Content = owned ? "✓ " + BeekeeperText.Owned : price,
            IsEnabled = false,
        };
        if (!owned)
        {
            button.Click += (_, _) => buy(null);
            _shopButtons[id] = button;
        }
        Grid.SetColumn(button, 1);
        row.Children.Add(button);
        return row;
    }

    private void UpdateLog(BeekeeperViewModel vm, AppLanguage lang)
    {
        var log = vm.Log;
        int shown = Math.Min(log.Count, MaxVisibleLines);

        // Redraw only when a visible line changed. Comparing every shown line (not just the
        // count and the newest) matters once the log is full at 50: then a new line identical
        // to the newest one (Sell 10 twice) leaves the count and the newest line unchanged.
        var sigBuilder = new System.Text.StringBuilder(lang.ToString());
        for (int i = 0; i < shown; i++)
            sigBuilder.Append('|').Append(log[i].Key).Append(':').Append(log[i].Value).Append(':').Append(log[i].Text);
        string sig = sigBuilder.ToString();
        if (sig == _logSignature) return;
        _logSignature = sig;

        LogLines.Children.Clear();
        // Cut (Bee, 2026-11-12): the pinned "those gloves fit well" line; it is a story card now.
        for (int i = 0; i < shown; i++)
        {
            string line = BeekeeperText.LogLine(log[i], lang);
            if (line.Length == 0) continue;
            LogLines.Children.Add(new TextBlock
            {
                Text = line,
                FontFamily = new FontFamily("Georgia"),
                FontSize = 14,
                Foreground = WhiteBrush,
                TextWrapping = TextWrapping.Wrap,
                Opacity = LineOpacity[Math.Min(i, LineOpacity.Length - 1)],
            });
        }
    }

    // ------------------------------------------------------------------ clicks

    private void Catch_Click(object? sender, RoutedEventArgs e) => _vm?.CatchCommand.Execute(null);
    private void BuildComb_Click(object? sender, RoutedEventArgs e) => _vm?.BuildCombCommand.Execute(null);
    private void BuyHoneySuper_Click(object? sender, RoutedEventArgs e) => _vm?.BuyHoneySuperCommand.Execute(null);
    private void BuyWaxTray_Click(object? sender, RoutedEventArgs e) => _vm?.BuyWaxTrayCommand.Execute(null);
    private void CraftRepellent_Click(object? sender, RoutedEventArgs e) => _vm?.CraftRepellentCommand.Execute(null);
    private void LightRepellent_Click(object? sender, RoutedEventArgs e) => _vm?.LightRepellentCommand.Execute(null);
    private void ThrowShoe_Click(object? sender, RoutedEventArgs e) => _vm?.ThrowShoeCommand.Execute(null);
    private void EngageWasp_Click(object? sender, RoutedEventArgs e) => _vm?.EngageWaspCommand.Execute(null);

    // Reps at the door: rebuilt only when who is here (or the language) changes.
    private string _visitorSignature = "";

    private void UpdateVisitors(IReadOnlyList<string> present, string bearName, AppLanguage lang)
    {
        VisitorsCard.IsVisible = present.Count > 0;
        VisitorsTitleText.Text = BeekeeperText.VisitorsTitle;
        string sig = lang + "|" + bearName + "|" + string.Join(",", present);
        if (sig == _visitorSignature) return;
        _visitorSignature = sig;
        VisitorRows.Children.Clear();
        foreach (var id in present)
        {
            var rep = id;
            var row = new StackPanel { Spacing = 6 };
            row.Children.Add(new TextBlock { Text = BeekeeperText.RepHere(rep, bearName), Classes = { "bk-body" }, FontWeight = FontWeight.SemiBold });
            var shoe = new Button { Classes = { "bk-button" }, Content = BeekeeperText.ThrowShoe,
                HorizontalAlignment = HorizontalAlignment.Stretch, HorizontalContentAlignment = HorizontalAlignment.Center };
            var engage = new Button { Classes = { "bk-button" }, Content = BeekeeperText.Engage,
                HorizontalAlignment = HorizontalAlignment.Stretch, HorizontalContentAlignment = HorizontalAlignment.Center };
            shoe.Click += (_, _) => _vm?.ThrowShoeAtRep(rep);
            engage.Click += (_, _) => _vm?.EngageRep(rep);
            row.Children.Add(shoe);
            row.Children.Add(engage);
            VisitorRows.Children.Add(row);
        }
    }

    // Story card: one moment at a time, rebuilt only when the story or the language changes.
    // A new moment is one more case here (plus its id, due rule and answers in the engine).
    private string _storySignature = "";

    private void UpdateStory(BeekeeperViewModel vm, AppLanguage lang)
    {
        string? id = vm.StoryHere;
        StoryCard.IsVisible = id is not null;
        string sig = lang + "|" + id + "|" + (id == BeekeeperStories.Seed ? vm.StorySeed : null);   // a new seed redraws the card
        if (sig == _storySignature) return;
        _storySignature = sig;
        StoryButtons.Children.Clear();
        if (id is null) return;

        Button MakeButton(string text, Action onClick)
        {
            var b = new Button { Classes = { "bk-button" }, Content = text,
                HorizontalAlignment = HorizontalAlignment.Stretch, HorizontalContentAlignment = HorizontalAlignment.Center };
            b.Click += (_, _) => onClick();
            return b;
        }

        switch (id)
        {
            case BeekeeperStories.Opening:   // stage 10: the grandmother's farmhouse
                StoryText.Text = BeekeeperText.StoryOpening;
                // Bee, 2026-11-12: no button; the card leaves after the first few clicks.
                // StoryButtons.Children.Add(MakeButton(BeekeeperText.StoryLookAround, () => _vm?.BeginFromStory()));
                break;
            case BeekeeperStories.Ouch:
                StoryText.Text = BeekeeperText.StoryOuch;
                // No button: the card goes by itself.
                break;
            case BeekeeperStories.Gloves:
                StoryText.Text = BeekeeperText.StoryGloves;
                StoryButtons.Children.Add(MakeButton(BeekeeperText.StoryYes, () => _vm?.PutOnGloves()));
                StoryButtons.Children.Add(MakeButton(BeekeeperText.StoryNo, () => _vm?.LeaveGloves()));
                break;
            // Bee, 2026-11-12: three cards with no button; they go by themselves.
            case BeekeeperStories.GlovesFit:   // after 6 bees caught while it shows
                StoryText.Text = BeekeeperText.StoryGlovesFit;
                break;
            case BeekeeperStories.BearShoe:   // the first shoe at a bear, fades after a few seconds
                StoryText.Text = BeekeeperText.StoryBearShoe;
                break;
            case BeekeeperStories.HippiesGone:   // the Hippies' 5th shoe, fades after a few seconds
                StoryText.Text = BeekeeperText.StoryHippiesGone;
                break;
            case BeekeeperStories.Smoker:
                StoryText.Text = BeekeeperText.StorySmoker;
                StoryButtons.Children.Add(MakeButton(BeekeeperText.StoryRepair, () => _vm?.RepairSmoker()));
                break;
            // Bee, 2026-11-12: the crafts that left The Workbench; each button makes the first one and opens the row's links.
            case BeekeeperStories.PotHoney:
                StoryText.Text = BeekeeperText.StoryPotHoney;
                StoryButtons.Children.Add(MakeButton(BeekeeperText.StoryPotHoneyButton, () => _vm?.CraftFromStory()));
                break;
            case BeekeeperStories.Candle:
                StoryText.Text = BeekeeperText.StoryCandle;
                StoryButtons.Children.Add(MakeButton(BeekeeperText.StoryCandleButton, () => _vm?.CraftFromStory()));
                break;
            case BeekeeperStories.BeeBread:
                StoryText.Text = BeekeeperText.StoryBeeBread;
                StoryButtons.Children.Add(MakeButton(BeekeeperText.StoryBeeBreadButton, () => _vm?.CraftFromStory()));
                break;
            case BeekeeperStories.Seed:   // Bee, 2026-11-11: a seed of a kind never planted
                StoryText.Text = BeekeeperText.StorySeed(vm.StorySeed ?? "");
                StoryButtons.Children.Add(MakeButton(BeekeeperText.GardenPlant, () => _vm?.PlantFromStory()));
                break;
        }
    }

    private void Bribe_Click(object? sender, RoutedEventArgs e) => _vm?.BribeCommand.Execute(null);
    private void CraftBeeBoost_Click(object? sender, RoutedEventArgs e) => _vm?.CraftBeeBoostCommand.Execute(null);
    private void LightBeeBoost_Click(object? sender, RoutedEventArgs e) => _vm?.LightBeeBoostCommand.Execute(null);
    private void CraftSagePropolis_Click(object? sender, RoutedEventArgs e) => _vm?.CraftSagePropolisCommand.Execute(null);
    private void LightSagePropolis_Click(object? sender, RoutedEventArgs e) => _vm?.LightSagePropolisCommand.Execute(null);
    private void MoveHive_Click(object? sender, RoutedEventArgs e) => _vm?.MoveToWoodenHiveCommand.Execute(null);
    private void BuyMeadow_Click(object? sender, RoutedEventArgs e) => _vm?.BuyMeadowCommand.Execute(null);
    private void Smoker_Click(object? sender, RoutedEventArgs e) => _vm?.UseSmokerCommand.Execute(null);

    // ------------------------------------------------------------------ catch popup

    // A short rise-and-fade above the button: white "+2 bees", or a coral sting that also
    // jolts the button ±3px sideways (UI_SPEC §3).
    private void StartPopup(bool stung, decimal bees)
    {
        _popupStung = stung;
        CatchPopup.Text = stung ? BeekeeperText.Sting : BeekeeperText.Bees(bees);
        CatchPopup.Foreground = stung ? SoftCoral : WhiteBrush;
        _popupClock.Restart();
        _popupTimer.Start();
        PopupTick(null, EventArgs.Empty);
    }

    private void PopupTick(object? sender, EventArgs e)
    {
        const double popupMs = 800, nudgeMs = 240;
        double t = _popupClock.Elapsed.TotalMilliseconds;

        double p = Math.Min(1, t / popupMs);
        CatchPopup.Opacity = 1 - p * p;
        ((TranslateTransform)CatchPopup.RenderTransform!).Y = -8 - 36 * p;

        double nudge = 0;
        if (_popupStung && t < nudgeMs)
            nudge = Math.Sin(t / nudgeMs * Math.PI * 4) * 3 * (1 - t / nudgeMs);
        ((TranslateTransform)CatchButton.RenderTransform!).X = nudge;

        if (t >= popupMs)
        {
            _popupTimer.Stop();
            CatchPopup.Opacity = 0;
            ((TranslateTransform)CatchButton.RenderTransform!).X = 0;
        }
    }
}
