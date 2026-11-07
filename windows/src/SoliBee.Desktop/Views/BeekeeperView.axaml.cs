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
/// The Beekeeper screen: art frame, Catch Bee, Hive, Bear, Shop, Combs and the story log.
/// It only draws what <see cref="BeekeeperViewModel"/> says. Cards appear as the game
/// reveals them and then stay (sticky reveals), so the game starts nearly empty.
/// </summary>
public partial class BeekeeperView : UserControl
{
    private static readonly IBrush SoftCoral = new SolidColorBrush(Color.Parse("#FFA38F"));
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
        CatchButton.IsEnabled = true;
        ToolLineText.Text = BeekeeperText.ToolLine(vm.ToolLevel, vm.BeesPerCatch);

        // The Smoker
        SmokerCard.IsVisible = vm.HasSmoker;
        SmokerTitleText.Text = BeekeeperText.SmokerTitle;
        SmokerStatusText.Text = vm.IsCalm
            ? BeekeeperText.CalmNow(BeekeeperText.Clock(vm.CalmSecondsLeft), N(vm.Config.CalmHoneyMultiplier))
            : BeekeeperText.CalmMeter(vm.CalmMeter, vm.CalmMeterClicks);
        CalmBar.Value = vm.IsCalm
            ? (double)(vm.CalmSecondsLeft / vm.Config.CalmSeconds)
            : (double)vm.CalmMeter / Math.Max(1, vm.CalmMeterClicks);
        PuffButton.Content = BeekeeperText.Puff;
        PuffButton.IsEnabled = vm.CanPuff;

        // Hive
        HiveCard.IsVisible = vm.HoneyRevealed;
        HiveTitleText.Text = BeekeeperText.HiveTitle;
        HiveBeesLabel.Text = BeekeeperText.HiveBees;
        HiveBeesValue.Text = N(vm.Bees);
        HiveHoneyLabel.Text = BeekeeperText.HiveHoney;
        HiveHoneyValue.Text = N(vm.Honey) + " / " + N(vm.HoneyStorage);
        HiveWaxLabel.Text = BeekeeperText.HiveWax;
        HiveWaxValue.Text = N(vm.Wax);
        HiveWaxLabel.IsVisible = HiveWaxValue.IsVisible = vm.WaxRevealed;
        HiveBeebitsLabel.Text = BeekeeperText.HiveBeebits;
        HiveBeebitsValue.Text = N(vm.Beebits);
        HiveBeebitsLabel.IsVisible = HiveBeebitsValue.IsVisible = vm.BeebitsRevealed;
        HiveBeeswaxLabel.Text = BeekeeperText.HiveBeeswaxCandles;
        HiveBeeswaxValue.Text = N(vm.BeeswaxCandles);
        HiveBeeswaxLabel.IsVisible = HiveBeeswaxValue.IsVisible = vm.CandlesCrafted > 0;
        HiveRepellentLabel.Text = BeekeeperText.HiveRepellentCandles;
        HiveRepellentValue.Text = N(vm.RepellentCandles);
        HiveRepellentLabel.IsVisible = HiveRepellentValue.IsVisible = vm.RepellentUnlocked;
        HiveSageLabel.Text = BeekeeperText.HiveSage;
        HiveSageValue.Text = N(vm.Sage);
        HiveSageLabel.IsVisible = HiveSageValue.IsVisible = vm.SageRevealed;
        HoneyRateText.Text = BeekeeperText.HoneyPerSecond(N(vm.HoneyPerSecond, 2));
        HiveFullText.IsVisible = vm.StorageIsFull;
        HiveFullText.Text = BeekeeperText.CombsFull;
        WaxProgressPanel.IsVisible = vm.WaxRevealed;
        NextWaxText.Text = BeekeeperText.NextWax(N(vm.WaxProgress), N(vm.HoneyPerWax));
        WaxBar.Value = vm.HoneyPerWax > 0 ? (double)Math.Min(1m, vm.WaxProgress / vm.HoneyPerWax) : 0;

        // Bear
        BearCard.IsVisible = vm.BearRevealed;
        BearTitleText.Text = BeekeeperText.BearTitle;
        BearNameText.Text = BeekeeperText.BearLine(vm.BearName, vm.Trades);
        SellTenButton.Content = BeekeeperText.SellTen;
        SellAllButton.Content = BeekeeperText.SellAll;
        SellTenButton.IsEnabled = vm.SellTenCommand.CanExecute(null);
        SellAllButton.IsEnabled = vm.SellAllCommand.CanExecute(null);
        SellHintText.Text = BeekeeperText.SellTenHint;

        // Shop (also opens with The Workbench, so its upgrades are never out of sight)
        ShopCard.IsVisible = vm.ShopRevealed || vm.WorkbenchRevealed;
        ShopTitleText.Text = BeekeeperText.ShopTitle;
        if (ShopCard.IsVisible) UpdateShop(vm, lang);

        // Combs
        CombsCard.IsVisible = vm.CombsRevealed;
        CombsTitleText.Text = BeekeeperText.CombsBuilt(vm.Combs);
        CombsInfoText.Text = BeekeeperText.CombBlurb(N(vm.Config.StoragePerComb));
        BuildCombButton.Content = BeekeeperText.BuildComb(N(vm.CombCost));
        BuildCombButton.IsEnabled = vm.CanBuildComb;

        // The Workbench
        WorkbenchCard.IsVisible = vm.WorkbenchRevealed;
        WorkbenchTitleText.Text = BeekeeperText.WorkbenchTitle;
        BeeswaxNameText.Text = BeekeeperText.BeeswaxCandle;
        BeeswaxInfoText.Text = BeekeeperText.Price(null, N(vm.Config.BeeswaxCandleWax), null) + " · " + BeekeeperText.BeeswaxBlurb;
        CraftBeeswaxButton.Content = BeekeeperText.Make;
        CraftBeeswaxButton.IsEnabled = vm.CanCraftBeeswax;
        RepellentRow.IsVisible = vm.RepellentUnlocked;
        RepellentNameText.Text = BeekeeperText.RepellentCandle;
        RepellentInfoText.Text = BeekeeperText.Price(null, N(vm.Config.RepellentCandleWax), N(vm.Config.RepellentCandleSage))
            + " · " + BeekeeperText.RepellentBlurb(BeekeeperText.Clock(vm.Engine.RepellentBurnSeconds));
        CraftRepellentButton.Content = BeekeeperText.Make;
        CraftRepellentButton.IsEnabled = vm.CanCraftRepellent;
        LightRepellentButton.Content = BeekeeperText.Light;
        LightRepellentButton.IsEnabled = vm.CanLightRepellent;

        // The Hippies
        HippiesCard.IsVisible = vm.HippiesRevealed;
        HippiesTitleText.Text = BeekeeperText.HippiesTitle;
        TradeTenButton.Content = BeekeeperText.TradeTen;
        TradeAllButton.Content = BeekeeperText.TradeAll;
        TradeTenButton.IsEnabled = TradeAllButton.IsEnabled = vm.CanTradeCandles;
        HippiesRateText.Text = BeekeeperText.HippiesRate;

        // Wasps
        bool burning = vm.RepellentSecondsLeft > 0m;
        WaspCard.IsVisible = vm.WaspApproaching || burning;
        WaspTitleText.Text = BeekeeperText.WaspsTitle;
        WaspHerePanel.IsVisible = vm.WaspApproaching;
        WaspHereText.Text = BeekeeperText.WaspHere;
        WaspTimeText.Text = BeekeeperText.TimeLeft(BeekeeperText.Clock(vm.WaspSecondsLeft));
        ThrowShoeButton.Content = BeekeeperText.ThrowShoe;
        ThrowShoeButton.IsEnabled = vm.CanThrowShoe;
        BribeButton.Content = BeekeeperText.Bribe(N(vm.BribeCost));
        BribeButton.IsEnabled = vm.CanBribe;
        WaspLightButton.Content = BeekeeperText.LightCandle;
        WaspLightButton.IsVisible = vm.RepellentUnlocked;
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

    private void UpdateShop(BeekeeperViewModel vm, AppLanguage lang)
    {
        string N(decimal v) => NumberFormatter.Format(v, lang);
        string? Part(decimal v) => v > 0m ? N(v) : null;
        var upgrades = vm.ShopUpgrades;
        string sig = $"{vm.ToolLevel}|{vm.HasWaxCatcher}|{lang}|{string.Join(",", upgrades.Select(u => u.Id))}";
        if (sig != _shopSignature)
        {
            _shopSignature = sig;
            _shopButtons.Clear();
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
                    BeekeeperText.ToolName(tool.Id), BeekeeperText.ToolBlurb(tool.Id, tool.BeesPerClick),
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
                    BeekeeperText.UpgradeName(id), BeekeeperText.UpgradeBlurb(id), false,
                    BeekeeperText.Price(Part(u.Beebits), Part(u.Wax), Part(u.Sage)), "upgrade:" + id, _ => vm.BuyUpgrade(id)));
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
            if (_shopButtons.TryGetValue("upgrade:" + u.Id, out var ub)) ub.IsEnabled = vm.CanBuyUpgrade(u.Id);
    }

    private Control MakeShopRow(string name, string blurb, bool owned, string price, string id, Action<object?> buy)
    {
        var row = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        var text = new StackPanel { Spacing = 2, VerticalAlignment = VerticalAlignment.Center };
        text.Children.Add(new TextBlock { Text = name, Classes = { "bk-body" }, FontWeight = FontWeight.SemiBold });
        text.Children.Add(new TextBlock { Text = blurb, Classes = { "bk-muted" } });
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
    private void SellTen_Click(object? sender, RoutedEventArgs e) => _vm?.SellTenCommand.Execute(null);
    private void SellAll_Click(object? sender, RoutedEventArgs e) => _vm?.SellAllCommand.Execute(null);
    private void BuildComb_Click(object? sender, RoutedEventArgs e) => _vm?.BuildCombCommand.Execute(null);
    private void CraftBeeswax_Click(object? sender, RoutedEventArgs e) => _vm?.CraftBeeswaxCommand.Execute(null);
    private void CraftRepellent_Click(object? sender, RoutedEventArgs e) => _vm?.CraftRepellentCommand.Execute(null);
    private void LightRepellent_Click(object? sender, RoutedEventArgs e) => _vm?.LightRepellentCommand.Execute(null);
    private void TradeTen_Click(object? sender, RoutedEventArgs e) => _vm?.TradeTenCandlesCommand.Execute(null);
    private void TradeAll_Click(object? sender, RoutedEventArgs e) => _vm?.TradeAllCandlesCommand.Execute(null);
    private void ThrowShoe_Click(object? sender, RoutedEventArgs e) => _vm?.ThrowShoeCommand.Execute(null);
    private void Bribe_Click(object? sender, RoutedEventArgs e) => _vm?.BribeCommand.Execute(null);
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
