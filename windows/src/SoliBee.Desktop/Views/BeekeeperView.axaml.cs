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

        // The Smoker
        SmokerCard.IsVisible = vm.HasSmoker;
        SmokerTitleText.Text = BeekeeperText.SmokerTitle;
        SmokerStatusText.Text = vm.IsCalm
            ? BeekeeperText.CalmNow(BeekeeperText.Clock(vm.CalmSecondsLeft), N(vm.Config.CalmHoneyMultiplier))
            : BeekeeperText.CalmMeter(vm.CalmMeter, vm.CalmMeterClicks);
        CalmBar.Value = (double)vm.CalmBarFraction;
        PuffButton.Content = BeekeeperText.Puff;
        PuffButton.IsEnabled = vm.CanPuff;

        // Hive: the title, the groups of rows (built from the view model), the move-hive row.
        HiveCard.IsVisible = vm.HiveCardShown;   // stage 7.5: the drip's first wax can come before any bee
        HiveTitleText.Text = BeekeeperText.HiveTitle(vm.HasWoodenHive);
        UpdateHive(vm, lang);
        WoodenHiveRow.IsVisible = vm.WoodenHiveOffered;
        WoodenHiveNameText.Text = BeekeeperText.WoodenHiveName;
        WoodenHiveInfoText.Text = BeekeeperText.Price(null, N(vm.Config.WoodenHiveWax), null, beeBread: N(vm.Config.WoodenHiveBeeBread))
            + " · " + BeekeeperText.WoodenHiveBlurb(N(vm.WoodenHiveBonusPercent));
        MoveHiveButton.Content = BeekeeperText.Move;
        MoveHiveButton.IsEnabled = vm.CanMoveToWoodenHive;
        ShowWall(WoodenHiveWallText, MoveHiveButton, vm.WoodenHiveIsWall, N(vm.WaxStorage));

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
        CombsInfoText.Text = BeekeeperText.Price(null, N(vm.CombCost), null, bees: N(vm.CombBeeCost))
            + " · " + BeekeeperText.CombBlurb(N(vm.HoneyPerComb, 2), N(vm.StoragePerComb), N(vm.WaxStoragePerComb, 1));
        // Cut in stage 7.5: CombsInfoText.Text = BeekeeperText.Price(null, N(vm.CombCost), null) + " · " + BeekeeperText.CombBlurb(N(vm.StoragePerComb));
        BuildCombButton.Content = BeekeeperText.Build;
        BuildCombButton.IsEnabled = vm.CanBuildComb;
        ShowWall(CombWallText, BuildCombButton, vm.CombIsWall, N(vm.WaxStorage));

        // Capacity upgrades (stage 7.5): Beebits only, bought again and again, so never walls.
        HoneySuperRow.IsVisible = vm.CapacityUpgradesShown;
        HoneySuperNameText.Text = BeekeeperText.HoneySuper;
        HoneySuperInfoText.Text = BeekeeperText.Price(N(vm.HoneySuperCost), null, null)
            + " · " + BeekeeperText.HoneySuperBlurb(N(vm.HoneySuperCapacity), N(vm.HoneySupers));
        BuyHoneySuperButton.Content = BeekeeperText.Add;
        BuyHoneySuperButton.IsEnabled = vm.CanBuyHoneySuper;
        WaxTrayRow.IsVisible = vm.CapacityUpgradesShown;
        WaxTrayNameText.Text = BeekeeperText.WaxTray;
        WaxTrayInfoText.Text = BeekeeperText.Price(N(vm.WaxTrayCost), null, null)
            + " · " + BeekeeperText.WaxTrayBlurb(N(vm.WaxTrayCapacity, 1), N(vm.WaxTrays));
        BuyWaxTrayButton.Content = BeekeeperText.Add;
        BuyWaxTrayButton.IsEnabled = vm.CanBuyWaxTray;
        BeeswaxRow.IsVisible = vm.WorkbenchRevealed;
        BeeswaxNameText.Text = BeekeeperText.BeeswaxCandle;
        BeeswaxInfoText.Text = BeekeeperText.Price(null, N(vm.Config.BeeswaxCandleWax), null) + " · " + BeekeeperText.BeeswaxBlurb;
        CraftBeeswaxButton.Content = BeekeeperText.Make;
        CraftBeeswaxButton.IsEnabled = vm.CanCraftBeeswax;
        ShowBatch(Beeswax10Button, 10, vm.CanCraftBeeswaxTimes(10));
        ShowBatch(Beeswax100Button, 100, vm.CanCraftBeeswaxTimes(100));
        BeeBreadRow.IsVisible = vm.PollenRevealed;
        BeeBreadNameText.Text = BeekeeperText.BeeBread;
        BeeBreadInfoText.Text = BeekeeperText.Price(null, null, null, pollen: N(vm.Config.BeeBreadPollen), honey: N(vm.Config.BeeBreadHoney))
            + " · " + BeekeeperText.BeeBreadBlurb;
        MakeBeeBreadButton.Content = BeekeeperText.Make;
        MakeBeeBreadButton.IsEnabled = vm.CanMakeBeeBread;
        ShowBatch(BeeBread10Button, 10, vm.CanMakeBeeBreadTimes(10));
        ShowBatch(BeeBread100Button, 100, vm.CanMakeBeeBreadTimes(100));
        // Repellent candles retire once the wasps' emissary has come (spec 014).
        RepellentRow.IsVisible = vm.RepellentShown;
        RepellentNameText.Text = BeekeeperText.RepellentCandle;
        RepellentInfoText.Text = BeekeeperText.Price(null, N(vm.Config.RepellentCandleWax), N(vm.Config.RepellentCandleSage))
            + " · " + BeekeeperText.RepellentBlurb(BeekeeperText.Clock(vm.RepellentBurnSeconds));
        CraftRepellentButton.Content = BeekeeperText.Make;
        CraftRepellentButton.IsEnabled = vm.CanCraftRepellent;
        ShowBatch(Repellent10Button, 10, vm.CanCraftRepellentTimes(10));
        ShowBatch(Repellent100Button, 100, vm.CanCraftRepellentTimes(100));
        LightRepellentButton.Content = BeekeeperText.Light;
        LightRepellentButton.IsEnabled = vm.CanLightRepellent;

        // The propolis candles (stage 7): once the poplar has sprouted
        BeeBoostRow.IsVisible = vm.PropolisCandlesShown;
        BeeBoostNameText.Text = BeekeeperText.BeeBoostCandle;
        BeeBoostInfoText.Text = BeekeeperText.Price(null, N(vm.Config.BeeBoostCandleWax), null, propolis: N(vm.Config.BeeBoostCandlePropolis))
            + " · " + BeekeeperText.BeeBoostBlurb(N(vm.BeeBoostBonusPercent), BeekeeperText.Roughly(vm.Config.BeeBoostBurnSeconds));
        CraftBeeBoostButton.Content = BeekeeperText.Make;
        CraftBeeBoostButton.IsEnabled = vm.CanCraftBeeBoost;
        ShowBatch(BeeBoost10Button, 10, vm.CanCraftBeeBoostTimes(10));
        ShowBatch(BeeBoost100Button, 100, vm.CanCraftBeeBoostTimes(100));
        LightBeeBoostButton.Content = BeekeeperText.LightBeeBoost;
        LightBeeBoostButton.IsEnabled = vm.CanLightBeeBoost;
        SagePropolisRow.IsVisible = vm.PropolisCandlesShown;
        SagePropolisNameText.Text = BeekeeperText.SagePropolisCandle;
        SagePropolisInfoText.Text = BeekeeperText.Price(null, N(vm.Config.SagePropolisCandleWax), N(vm.Config.SagePropolisCandleSage),
                propolis: N(vm.Config.SagePropolisCandlePropolis))
            + " · " + BeekeeperText.SagePropolisBlurb(N(vm.SagePropolisBonusPercent), BeekeeperText.Roughly(vm.Config.SagePropolisBurnSeconds));
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

        // The Garden (stage 7): the beds, the seeds in hand, the plants once sprouted
        GardenCard.IsVisible = vm.GardenRevealed;
        GardenTitleText.Text = BeekeeperText.GardenTitle;
        UpdateBeds(vm);
        UpdateSeeds(vm, lang);
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
        WaspLightButton.Content = BeekeeperText.LightCandle;
        WaspLightButton.IsVisible = vm.RepellentShown;
        WaspLightButton.IsEnabled = vm.CanLightRepellent;
        CandleBurningText.IsVisible = burning && !vm.WaspApproaching;
        CandleBurningText.Text = BeekeeperText.CandleBurning(BeekeeperText.Clock(vm.RepellentSecondsLeft));

        // Log
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
        text.IsVisible = wall;
        text.Foreground = WallBrush;
        text.Opacity = 1.0;
        if (wall) text.Text = BeekeeperText.WaxWall(holds);
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
            case "Beeswax": _vm.CraftBeeswaxTimes(n); break;
            case "BeeBread": _vm.MakeBeeBreadTimes(n); break;
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
        string sig = lang + "|" + string.Join(";", groups.Select(g =>
            g.Id + ":" + string.Join(",", g.Rows.Where(r => r.Visible && !Transient(r.Id)).Select(r => r.Id))));
        if (sig != _hiveSignature)
        {
            _hiveSignature = sig;
            _hiveRows.Clear();
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
                    var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
                    var label = new TextBlock { Classes = { "bk-body" }, Opacity = 0.75 };
                    var value = new TextBlock { Classes = { "bk-body" }, FontWeight = FontWeight.SemiBold };
                    Grid.SetColumn(value, 1);
                    grid.Children.Add(label);
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
                    SetRateTip(tip, c.Label, v);
                }
                else SetRateTip(tip, c.Label);
            }
    }

    // The beds are plain text, so they are simply redrawn each tick (a row per bed, empty or growing).
    private void UpdateBeds(BeekeeperViewModel vm)
    {
        var growing = vm.GrowingBeds;
        int total = vm.BedRowCount;
        while (BedRows.Children.Count > total) BedRows.Children.RemoveAt(BedRows.Children.Count - 1);
        while (BedRows.Children.Count < total) BedRows.Children.Add(new TextBlock { Classes = { "bk-body" } });
        for (int i = 0; i < total; i++)
        {
            var line = (TextBlock)BedRows.Children[i];
            bool busy = i < growing.Count;
            line.Text = busy ? BeekeeperText.BedGrowing(growing[i].Plant, growing[i].SecondsLeft) : BeekeeperText.GardenEmptyBed;
            line.Opacity = busy ? 1.0 : 0.6;
        }
    }

    // Each seed in hand has its own Plant button. Rebuilt only when the seeds change, so a button is
    // never swapped under the mouse; whether it is enabled (a free bed) is refreshed every tick.
    private string _seedsSignature = "";
    private readonly Dictionary<string, Button> _seedButtons = new();

    private void UpdateSeeds(BeekeeperViewModel vm, AppLanguage lang)
    {
        var seeds = vm.SeedsInHand;
        string sig = lang + "|" + string.Join(",", seeds.Select(p => p.Id));
        if (sig != _seedsSignature)
        {
            _seedsSignature = sig;
            _seedButtons.Clear();
            SeedRows.Children.Clear();
            foreach (var plant in seeds)
            {
                var id = plant.Id;
                var row = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
                row.Children.Add(new TextBlock
                {
                    Text = BeekeeperText.SeedLine(id), Classes = { "bk-body" },
                    FontWeight = FontWeight.SemiBold, VerticalAlignment = VerticalAlignment.Center,
                });
                var button = new Button
                {
                    Classes = { "bk-button" }, MinWidth = 90, Content = BeekeeperText.GardenPlant,
                    HorizontalContentAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center,
                };
                ToolTip.SetTip(button, BeekeeperText.TakesToGrow(plant.GrowSeconds));
                ToolTip.SetShowOnDisabled(button, true);   // beds full: the button is off but still says how long it takes
                button.Click += (_, _) => _vm?.PlantSeedCommand.Execute(id);
                Grid.SetColumn(button, 1);
                row.Children.Add(button);
                SeedRows.Children.Add(row);
                _seedButtons[id] = button;
            }
        }
        foreach (var (id, button) in _seedButtons) button.IsEnabled = vm.CanPlantSeedOf(id);
    }

    // The Notebook's notes: plain text, rebuilt only when a note is added.
    private string _notebookSignature = "";

    private void UpdateNotebook(BeekeeperViewModel vm, AppLanguage lang)
    {
        var notes = vm.NotebookNotes;
        string sig = lang + "|" + string.Join(",", notes);
        if (sig == _notebookSignature) return;
        _notebookSignature = sig;
        NotebookRows.Children.Clear();
        foreach (var id in notes)
            NotebookRows.Children.Add(new TextBlock { Text = BeekeeperText.NotebookNote(id), Classes = { "bk-body" }, Opacity = 0.9 });
    }

    private string _plantsSignature = "";

    // Plain text rows, rebuilt only when what they show changes.
    private void UpdatePlants(BeekeeperViewModel vm, AppLanguage lang)
    {
        var plants = vm.SproutedPlants;
        string sig = lang + "|" + string.Join(",", plants.Select(p => p.Id));
        if (sig == _plantsSignature) return;
        _plantsSignature = sig;
        PlantRows.Children.Clear();
        foreach (var p in plants)
        {
            var row = new StackPanel { Spacing = 2 };
            row.Children.Add(new TextBlock { Text = BeekeeperText.PlantLine(p), Classes = { "bk-body" }, FontWeight = FontWeight.SemiBold });
            row.Children.Add(new TextBlock { Text = BeekeeperText.PlantBlurb(p.Id), Classes = { "bk-muted" } });
            PlantRows.Children.Add(row);
        }
    }

    private void UpdateShop(BeekeeperViewModel vm, AppLanguage lang)
    {
        string N(decimal v) => NumberFormatter.Format(v, lang);
        string? Part(decimal v) => v > 0m ? N(v) : null;
        var upgrades = vm.ShopUpgrades;
        string sig = $"{vm.ToolLevel}|{vm.BeesPerClick}|{vm.HasWaxCatcher}|{lang}|{string.Join(",", upgrades.Select(u => u.Id))}";
        if (sig != _shopSignature)
        {
            _shopSignature = sig;
            _shopButtons.Clear();
            _shopWalls.Clear();
            ShopRows.Children.Clear();

            // Bought things are hidden (Leah, 2026-11-07): only the next tool is listed. A
            // "show bought things" option may come later; it would just flip ShowBoughtItems.
            for (int i = 0; i < vm.Config.Tools.Count; i++)
            {
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
                    BeekeeperText.WaxCatcherName, BeekeeperText.WaxCatcherBlurb,
                    vm.HasWaxCatcher, BeekeeperText.Price(N(vm.Config.WaxCatcherCost), null, null), "catcher", vm.BuyWaxCatcherCommand.Execute));

            // Upgrades: only unlocked, not-yet-bought ones are listed (bought ones leave the Shop).
            foreach (var u in upgrades)
            {
                string id = u.Id;
                ShopRows.Children.Add(MakeShopRow(
                    BeekeeperText.UpgradeName(id), BeekeeperText.UpgradeBlurb(id, vm.UpgradeBonusPercent(id)), false,
                    BeekeeperText.Price(Part(u.Beebits), Part(u.Wax), Part(u.Sage), paper: Part(u.Paper), propolis: Part(u.Propolis)),
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

    private void UpdateTrades(IReadOnlyList<BeekeeperTradeOffer> offers, AppLanguage lang)
    {
        string sig = lang + "|" + string.Join(",", offers.Select(o => o.Id));
        if (sig != _tradeSignature)
        {
            _tradeSignature = sig;
            _tradeRows.Clear();
            _tradeRates.Clear();
            _agreementText = null;
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
                var rate = new TextBlock { Text = BeekeeperText.TradeRate(o.Id, o.GiveAmount), Classes = { "bk-muted" } };
                row.Children.Add(rate);
                _tradeRates[o.Id] = rate;
                if (o.Id == "bear")
                {
                    // The bear's trade agreement (25 trades): shown once offered.
                    _agreementText = new TextBlock { Text = BeekeeperText.AgreementLine, Classes = { "bk-muted" }, IsVisible = false };
                    row.Children.Add(_agreementText);
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
            if (_tradeRates.TryGetValue(o.Id, out var rateText)) rateText.Text = BeekeeperText.TradeRate(o.Id, o.GiveAmount);
            if (o.Id == "bear" && o.TradeTimes == null) r.One.Content = BeekeeperText.TradeBundle(o.GiveAmount);
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
    private void CraftBeeswax_Click(object? sender, RoutedEventArgs e) => _vm?.CraftBeeswaxCommand.Execute(null);
    private void CraftRepellent_Click(object? sender, RoutedEventArgs e) => _vm?.CraftRepellentCommand.Execute(null);
    private void LightRepellent_Click(object? sender, RoutedEventArgs e) => _vm?.LightRepellentCommand.Execute(null);
    private void ThrowShoe_Click(object? sender, RoutedEventArgs e) => _vm?.ThrowShoeCommand.Execute(null);
    private void Bribe_Click(object? sender, RoutedEventArgs e) => _vm?.BribeCommand.Execute(null);
    private void CraftBeeBoost_Click(object? sender, RoutedEventArgs e) => _vm?.CraftBeeBoostCommand.Execute(null);
    private void LightBeeBoost_Click(object? sender, RoutedEventArgs e) => _vm?.LightBeeBoostCommand.Execute(null);
    private void CraftSagePropolis_Click(object? sender, RoutedEventArgs e) => _vm?.CraftSagePropolisCommand.Execute(null);
    private void LightSagePropolis_Click(object? sender, RoutedEventArgs e) => _vm?.LightSagePropolisCommand.Execute(null);
    private void MakeBeeBread_Click(object? sender, RoutedEventArgs e) => _vm?.MakeBeeBreadCommand.Execute(null);
    private void MoveHive_Click(object? sender, RoutedEventArgs e) => _vm?.MoveToWoodenHiveCommand.Execute(null);
    private void Puff_Click(object? sender, RoutedEventArgs e) => _vm?.PuffSmokerCommand.Execute(null);

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
