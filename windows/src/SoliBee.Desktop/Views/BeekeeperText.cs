using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

/// <summary>
/// Every word Beekeeper shows, in one place. The words live in the localization workbook
/// (Strings.Get); this class picks the right key and fills in the values, in the language
/// chosen in Options.
/// </summary>
internal static class BeekeeperText
{
    private static AppLanguage Lang => SettingsService.LoadOptions().Language;
    private static string T(StringKey key) => Strings.Get(key, Lang);

    // Fills each %@ in turn, left to right.
    private static string Fill(string template, params string[] values)
    {
        foreach (var v in values)
        {
            int i = template.IndexOf("%@", System.StringComparison.Ordinal);
            if (i < 0) break;
            template = template.Remove(i, 2).Insert(i, v);
        }
        return template;
    }

    // ---- labels
    public static string GameName => T(StringKey.GamemodeBeekeeperDisplay);
    public static string Catch => T(StringKey.BeekeeperCatchBee);
    public static string BeesLabel => T(StringKey.BeekeeperBeesLabel);
    public static string HoneyLabel => T(StringKey.BeekeeperHoneyLabel);
    public static string WaxLabel => T(StringKey.BeekeeperWaxLabel);
    public static string BeebitsLabel => T(StringKey.BeekeeperBeebitsLabel);
    public static string HiveTitle => T(StringKey.BeekeeperHiveTitle);
    public static string HiveBees => T(StringKey.BeekeeperHiveBees);
    public static string HiveHoney => T(StringKey.BeekeeperHiveHoney);
    public static string HiveWax => T(StringKey.BeekeeperHiveWax);
    public static string HiveCombs => T(StringKey.BeekeeperHiveCombs);
    public static string Comb => T(StringKey.BeekeeperComb);
    public static string Build => T(StringKey.BeekeeperBuild);
    public static string HiveBeebits => T(StringKey.BeekeeperHiveBeebits);
    public static string BearTitle => T(StringKey.BeekeeperBearTitle);
    public static string ShopTitle => T(StringKey.BeekeeperShopTitle);
    public static string LogTitle => T(StringKey.BeekeeperLogTitle);
    public static string SellTen => T(StringKey.BeekeeperSellTen);
    public static string SellAll => T(StringKey.BeekeeperSellAll);
    public static string Owned => T(StringKey.BeekeeperOwned);
    public static string StartOver => T(StringKey.BeekeeperStartOverTitle);
    public static string StartOverBody => T(StringKey.BeekeeperStartOverBody);

    public static string Sting => T(StringKey.BeekeeperStingPopup);
    public static string Bees(decimal n) =>
        n == 1m ? T(StringKey.BeekeeperPlusOneBee) : Fill(T(StringKey.BeekeeperPlusBeesFmt), NumberFormatter.Format(n, Lang));

    /// <summary>"Hive whistle · 400 bees": the tool in use and everything one click catches.</summary>
    public static string ToolLine(int level, decimal beesPerCatch) =>
        T(level switch
        {
            1 => StringKey.BeekeeperToolGloves,
            2 => StringKey.BeekeeperToolNet,
            3 => StringKey.BeekeeperToolVacuum,
            4 => StringKey.BeekeeperToolLure,
            5 => StringKey.BeekeeperToolCart,
            6 => StringKey.BeekeeperToolWhistle,
            _ => StringKey.BeekeeperToolBareHands,
        })
        + " · " + (beesPerCatch == 1m ? T(StringKey.BeekeeperOneBee)
                                      : Fill(T(StringKey.BeekeeperBeesFmt), NumberFormatter.Format(beesPerCatch, Lang)));

    public static string ToolName(string id) => id switch
    {
        "gloves" => T(StringKey.BeekeeperShopGloves),
        "net" => T(StringKey.BeekeeperShopNet),
        "vacuum" => T(StringKey.BeekeeperShopVacuum),
        "lure" => T(StringKey.BeekeeperShopLure),
        "cart" => T(StringKey.BeekeeperShopCart),
        "whistle" => T(StringKey.BeekeeperShopWhistle),
        _ => id,
    };

    public static string ToolBlurb(string id, int bees) => Fill(T(StringKey.BeekeeperBeesPerClickFmt), bees.ToString());

    public static string HoneyPerSecond(string n) => Fill(T(StringKey.BeekeeperHoneyPerSecFmt), n);
    public static string NextWax(string progress, string needed) => Fill(T(StringKey.BeekeeperNextWaxFmt), progress, needed);
    public static string CombsFull => T(StringKey.BeekeeperCombsFull);
    public static string BearLine(string name, long trades) =>
        trades == 0 ? name : Fill(T(StringKey.BeekeeperBearTradesFmt), name, NumberFormatter.Format(trades, Lang));
    public static string SellTenHint => T(StringKey.BeekeeperSellHint);
    public static string WaxCatcherName => T(StringKey.BeekeeperWaxCatcher);
    public static string WaxCatcherBlurb => T(StringKey.BeekeeperWaxCatcherBlurb);
    public static string CombBlurb(string storageAdded) => Fill(T(StringKey.BeekeeperCombBlurbFmt), storageAdded);

    // ---- stage 2: The Workbench, Hippies, wasps, upgrades
    public static string HiveBeeswaxCandles => T(StringKey.BeekeeperHiveBeeswaxCandles);
    public static string HiveRepellentCandles => T(StringKey.BeekeeperHiveRepellentCandles);
    public static string HiveSage => T(StringKey.BeekeeperHiveSage);

    public static string WorkbenchTitle => T(StringKey.BeekeeperWorkbenchTitle);
    public static string BeeswaxCandle => T(StringKey.BeekeeperBeeswaxCandle);
    public static string BeeswaxBlurb => T(StringKey.BeekeeperBeeswaxBlurb);
    public static string RepellentCandle => T(StringKey.BeekeeperRepellentCandle);
    public static string RepellentBlurb(string time) => Fill(T(StringKey.BeekeeperRepellentBlurbFmt), time);
    public static string Make => T(StringKey.BeekeeperMake);
    public static string Light => T(StringKey.BeekeeperLight);

    public static string HippiesTitle => T(StringKey.BeekeeperHippiesTitle);
    public static string HippiesRate => T(StringKey.BeekeeperHippiesRate);
    public static string TradeTen => T(StringKey.BeekeeperTradeTen);
    public static string TradeAll => T(StringKey.BeekeeperTradeAll);

    public static string WaspsTitle => T(StringKey.BeekeeperWaspsTitle);
    public static string WaspHere => T(StringKey.BeekeeperWaspHere);
    public static string TimeLeft(string time) => Fill(T(StringKey.BeekeeperTimeLeftFmt), time);
    public static string ThrowShoe => T(StringKey.BeekeeperThrowShoe);
    public static string Bribe(string honey) => Fill(T(StringKey.BeekeeperBribeFmt), honey);
    public static string LightCandle => T(StringKey.BeekeeperLightCandle);
    public static string CandleBurning(string time) => Fill(T(StringKey.BeekeeperCandleBurningFmt), time);

    /// <summary>A price that may mix resources: "300 beebits · 100 wax · 2 sage".</summary>
    public static string Price(string? beebits, string? wax, string? sage)
    {
        var parts = new System.Collections.Generic.List<string>();
        if (beebits != null) parts.Add(beebits + " " + BeebitsLabel.ToLowerInvariant());
        if (wax != null) parts.Add(Fill(T(StringKey.BeekeeperCostWaxFmt), wax));
        if (sage != null) parts.Add(Fill(T(StringKey.BeekeeperCostSageFmt), sage));
        return string.Join(" · ", parts);
    }

    /// <summary>Minutes and seconds, e.g. "0:42" or "14:30" (rounded up, so it never shows 0:00 early).</summary>
    public static string Clock(decimal seconds)
    {
        long s = (long)System.Math.Ceiling(System.Math.Max(0m, seconds));
        return $"{s / 60}:{s % 60:00}";
    }

    public static string UpgradeName(string id) => UpgradeNameIn(id, Lang);

    public static string SmokerTitle => T(StringKey.BeekeeperSmokerTitle);
    public static string CalmMeter(int clicks, int needed) => Fill(T(StringKey.BeekeeperCalmMeterFmt), clicks.ToString(), needed.ToString());
    public static string CalmNow(string time, string multiplier) => Fill(T(StringKey.BeekeeperCalmNowFmt), time, multiplier);
    public static string Puff => T(StringKey.BeekeeperPuff);

    public static string UpgradeBlurb(string id) => id switch
    {
        BeekeeperUpgrades.Practice => T(StringKey.BeekeeperUpgradePracticeBlurb),
        BeekeeperUpgrades.MorePractice => T(StringKey.BeekeeperUpgradeMorePracticeBlurb),
        BeekeeperUpgrades.Smoker => T(StringKey.BeekeeperUpgradeSmokerBlurb),
        BeekeeperUpgrades.BiggerCombs1 => T(StringKey.BeekeeperUpgradeBiggerCombs1Blurb),
        BeekeeperUpgrades.BiggerCombs2 => T(StringKey.BeekeeperUpgradeBiggerCombs2Blurb),
        BeekeeperUpgrades.BetterWaxCatcher => T(StringKey.BeekeeperUpgradeBetterWaxCatcherBlurb),
        BeekeeperUpgrades.StrongerCandles => T(StringKey.BeekeeperUpgradeStrongerCandlesBlurb),
        _ => "",
    };

    // ---- story log (saved as keys plus values, so old lines follow a language change)

    // The log is drawn in the language it is asked for, which can differ from Options for a moment.
    private static string UpgradeNameIn(string id, AppLanguage lang) => id switch
    {
        BeekeeperUpgrades.BiggerCombs1 => Strings.Get(StringKey.BeekeeperUpgradeBiggerCombs1, lang),
        BeekeeperUpgrades.BiggerCombs2 => Strings.Get(StringKey.BeekeeperUpgradeBiggerCombs2, lang),
        BeekeeperUpgrades.BetterWaxCatcher => Strings.Get(StringKey.BeekeeperUpgradeBetterWaxCatcher, lang),
        BeekeeperUpgrades.StrongerCandles => Strings.Get(StringKey.BeekeeperUpgradeStrongerCandles, lang),
        BeekeeperUpgrades.Practice => Strings.Get(StringKey.BeekeeperUpgradePractice, lang),
        BeekeeperUpgrades.MorePractice => Strings.Get(StringKey.BeekeeperUpgradeMorePractice, lang),
        BeekeeperUpgrades.Smoker => Strings.Get(StringKey.BeekeeperUpgradeSmoker, lang),
        _ => id,
    };

    public static string LogLine(BeekeeperLogEntry e, AppLanguage lang)
    {
        string L(StringKey key) => Strings.Get(key, lang);
        string N(decimal v) => NumberFormatter.Format(v, lang);
        return e.Key switch
        {
            BeekeeperEvents.NewGame => L(StringKey.BeekeeperLogNewGame),
            BeekeeperEvents.FirstBee => L(StringKey.BeekeeperLogFirstBee),
            BeekeeperEvents.Sting => L(StringKey.BeekeeperLogSting),
            BeekeeperEvents.StorageFull => L(StringKey.BeekeeperLogStorageFull),
            BeekeeperEvents.BearArrives => Fill(L(StringKey.BeekeeperLogBearArrivesFmt), e.Text ?? ""),
            BeekeeperEvents.Sale => Fill(L(StringKey.BeekeeperLogSaleFmt), e.Text ?? ""),
            BeekeeperEvents.FirstWax => L(StringKey.BeekeeperLogFirstWax),
            BeekeeperEvents.ShopOpened => L(StringKey.BeekeeperLogShopOpened),
            BeekeeperEvents.ToolBought => L(e.Text switch
            {
                "gloves" => StringKey.BeekeeperLogGloves,
                "net" => StringKey.BeekeeperLogNet,
                "vacuum" => StringKey.BeekeeperLogVacuum,
                "lure" => StringKey.BeekeeperLogLure,
                "cart" => StringKey.BeekeeperLogCart,
                "whistle" => StringKey.BeekeeperLogWhistle,
                _ => StringKey.BeekeeperLogNewTool,
            }),
            BeekeeperEvents.WaxCatcherBought => L(StringKey.BeekeeperLogWaxCatcher),
            BeekeeperEvents.CombsAvailable => L(StringKey.BeekeeperLogCombsAvailable),
            BeekeeperEvents.CombBuilt => Fill(L(StringKey.BeekeeperLogCombBuiltFmt), N(e.Value)),
            BeekeeperEvents.WelcomeBack => Fill(L(StringKey.BeekeeperLogWelcomeBackFmt), N(e.Value)),
            BeekeeperEvents.WelcomeBackNothing => L(StringKey.BeekeeperLogWelcomeBackNothing),
            BeekeeperEvents.WorkbenchOpened => L(StringKey.BeekeeperLogWorkbenchOpened),
            BeekeeperEvents.FirstBeeswaxCandle => L(StringKey.BeekeeperLogFirstBeeswaxCandle),
            BeekeeperEvents.HippiesArrive => L(StringKey.BeekeeperLogHippiesArrive),
            BeekeeperEvents.CandlesTraded => Fill(L(StringKey.BeekeeperLogCandlesTradedFmt), N(e.Value)),
            BeekeeperEvents.RepellentUnlocked => L(StringKey.BeekeeperLogRepellentUnlocked),
            BeekeeperEvents.UpgradeBought => Fill(L(StringKey.BeekeeperLogUpgradeBoughtFmt), UpgradeNameIn(e.Text ?? "", lang)),
            BeekeeperEvents.WaspArrives => L(StringKey.BeekeeperLogWaspArrives),
            BeekeeperEvents.ShoeHit => L(StringKey.BeekeeperLogShoeHit),
            BeekeeperEvents.ShoeMissRaid => Fill(L(StringKey.BeekeeperLogShoeMissFmt), N(e.Value), N(e.Value2)),
            BeekeeperEvents.WaspRaid => Fill(L(StringKey.BeekeeperLogWaspRaidFmt), N(e.Value), N(e.Value2)),
            BeekeeperEvents.Bribe => Fill(L(StringKey.BeekeeperLogBribeFmt), N(e.Value)),
            BeekeeperEvents.WaspLeft => L(StringKey.BeekeeperLogWaspLeft),
            BeekeeperEvents.CandleLit => L(StringKey.BeekeeperLogCandleLit),
            BeekeeperEvents.CandleOut => L(StringKey.BeekeeperLogCandleOut),
            BeekeeperEvents.SmokerPuffed => L(StringKey.BeekeeperLogSmokerPuffed),
            BeekeeperEvents.CalmEnded => L(StringKey.BeekeeperLogCalmEnded),
            _ => "",
        };
    }
}
