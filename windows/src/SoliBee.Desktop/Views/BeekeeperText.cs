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
    public static string HiveTitle(bool wooden) =>
        T(wooden ? StringKey.BeekeeperHiveTitleWooden : StringKey.BeekeeperHiveTitleSkep);
    public static string HiveBees => T(StringKey.BeekeeperHiveBees);
    public static string HiveHoney => T(StringKey.BeekeeperHiveHoney);
    public static string HiveWax => T(StringKey.BeekeeperHiveWax);
    public static string HiveCombs => T(StringKey.BeekeeperHiveCombs);
    public static string Comb => T(StringKey.BeekeeperComb);
    public static string Build => T(StringKey.BeekeeperBuild);
    public static string HiveBeebits => T(StringKey.BeekeeperHiveBeebits);
    public static string ShopTitle => T(StringKey.BeekeeperShopTitle);
    public static string LogTitle => T(StringKey.BeekeeperLogTitle);
    public static string Owned => T(StringKey.BeekeeperOwned);
    public static string StartOver => T(StringKey.BeekeeperStartOverTitle);
    public static string StartOverBody => T(StringKey.BeekeeperStartOverBody);

    public static string Sting => T(StringKey.BeekeeperStingPopup);
    public static string Bees(decimal n) =>
        n == 1m ? T(StringKey.BeekeeperPlusOneBee) : Fill(T(StringKey.BeekeeperPlusBeesFmt), NumberFormatter.Format(n, Lang));

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
    public static string WaxPerSecond(string n) => Fill(T(StringKey.BeekeeperWaxPerSecFmt), n);
    public static string CombsFull => T(StringKey.BeekeeperCombsFull);
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

    // ---- Trading: one shared card for every buyer (Leah)
    public static string TradingTitle => T(StringKey.BeekeeperTradingTitle);
    public static string TradeTen => T(StringKey.BeekeeperTradeTen);
    public static string TradeAll => T(StringKey.BeekeeperTradeAll);

    /// <summary>"Bruno · Trades: 3", "The Hippies · Trades: 1": who, and how often you've traded.</summary>
    public static string TraderLine(string id, string? name, long trades)
    {
        string who = id switch
        {
            "hippies" => T(StringKey.BeekeeperHippiesName),
            _ => name ?? id,
        };
        return trades == 0 ? who : Fill(T(StringKey.BeekeeperBearTradesFmt), who, NumberFormatter.Format(trades, Lang));
    }

    /// <summary>What a buyer gives for what: "10 honey = 1 Beebit".</summary>
    public static string TradeRate(string id) => id switch
    {
        "bear" => T(StringKey.BeekeeperSellHint),
        "hippies" => T(StringKey.BeekeeperHippiesRate),
        _ => "",
    };

    public static string WaspsTitle => T(StringKey.BeekeeperWaspsTitle);
    public static string WaspHere => T(StringKey.BeekeeperWaspHere);
    public static string TimeLeft(string time) => Fill(T(StringKey.BeekeeperTimeLeftFmt), time);
    public static string ThrowShoe => T(StringKey.BeekeeperThrowShoe);
    public static string Bribe(string honey) => Fill(T(StringKey.BeekeeperBribeFmt), honey);
    public static string LightCandle => T(StringKey.BeekeeperLightCandle);
    public static string CandleBurning(string time) => Fill(T(StringKey.BeekeeperCandleBurningFmt), time);

    /// <summary>A price that may mix resources: "300 beebits · 100 wax · 2 sage".</summary>
    public static string Price(string? beebits, string? wax, string? sage,
                               string? pollen = null, string? honey = null, string? beeBread = null)
    {
        var parts = new System.Collections.Generic.List<string>();
        if (beebits != null) parts.Add(beebits + " " + BeebitsLabel.ToLowerInvariant());
        if (wax != null) parts.Add(Fill(T(StringKey.BeekeeperCostWaxFmt), wax));
        if (sage != null) parts.Add(Fill(T(StringKey.BeekeeperCostSageFmt), sage));
        if (pollen != null) parts.Add(Fill(T(StringKey.BeekeeperCostPollenFmt), pollen));
        if (honey != null) parts.Add(Fill(T(StringKey.BeekeeperCostHoneyFmt), honey));
        if (beeBread != null) parts.Add(Fill(T(StringKey.BeekeeperCostBeeBreadFmt), beeBread));
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

    // ---- stage 4: the Garden, bees, bee bread, the wooden hive
    public static string HiveSeeds => T(StringKey.BeekeeperHiveSeeds);
    public static string HiveForagers => T(StringKey.BeekeeperHiveForagers);
    public static string HiveGuards => T(StringKey.BeekeeperHiveGuards);
    public static string HivePollen => T(StringKey.BeekeeperHivePollen);
    public static string HiveBeeBread => T(StringKey.BeekeeperHiveBeeBread);
    public static string WoodenHiveName => T(StringKey.BeekeeperWoodenHiveName);
    public static string WoodenHiveBlurb(string percent) => Fill(T(StringKey.BeekeeperWoodenHiveBlurbFmt), percent);
    public static string Move => T(StringKey.BeekeeperMove);

    public static string GardenTitle => T(StringKey.BeekeeperGardenTitle);
    public static string GardenPlant => T(StringKey.BeekeeperGardenPlant);
    public static string GardenGrowing => T(StringKey.BeekeeperGardenGrowing);
    public static string GardenEmpty => T(StringKey.BeekeeperGardenEmpty);
    public static string BeeBread => T(StringKey.BeekeeperBeeBread);
    public static string BeeBreadBlurb => T(StringKey.BeekeeperBeeBreadBlurb);

    public static string PlantName(string id) => id switch
    {
        BeekeeperPlants.Wildflowers => T(StringKey.BeekeeperPlantWildflowers),
        BeekeeperPlants.Bramble => T(StringKey.BeekeeperPlantBramble),
        _ => id,
    };

    public static string PlantBlurb(string id) => id switch
    {
        BeekeeperPlants.Wildflowers => T(StringKey.BeekeeperPlantWildflowersBlurb),
        BeekeeperPlants.Bramble => T(StringKey.BeekeeperPlantBrambleBlurb),
        _ => "",
    };

    public static string BeesTitle => T(StringKey.BeekeeperBeesTitle);

    public static string BeeName(string kind) => kind switch
    {
        BeekeeperBees.Honey => T(StringKey.BeekeeperBeeHoneyName),
        BeekeeperBees.Forager => T(StringKey.BeekeeperBeeForagerName),
        BeekeeperBees.Guard => T(StringKey.BeekeeperBeeGuardName),
        _ => kind,
    };

    public static string BeeBlurb(string kind) => kind switch
    {
        BeekeeperBees.Honey => T(StringKey.BeekeeperBeeHoneyBlurb),
        BeekeeperBees.Forager => T(StringKey.BeekeeperBeeForagerBlurb),
        BeekeeperBees.Guard => T(StringKey.BeekeeperBeeGuardBlurb),
        _ => "",
    };

    public static string BeeFact(string kind) => kind switch
    {
        BeekeeperBees.Honey => T(StringKey.BeekeeperBeeHoneyFact),
        BeekeeperBees.Forager => T(StringKey.BeekeeperBeeForagerFact),
        BeekeeperBees.Guard => T(StringKey.BeekeeperBeeGuardFact),
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
            BeekeeperEvents.ShoeMissRaid => e.Text == "guards"
                ? Fill(L(StringKey.BeekeeperLogShoeMissGuardsFmt), N(e.Value))
                : Fill(L(StringKey.BeekeeperLogShoeMissFmt), N(e.Value), N(e.Value2)),
            BeekeeperEvents.WaspRaid => e.Text == "guards"
                ? Fill(L(StringKey.BeekeeperLogWaspRaidGuardsFmt), N(e.Value))
                : Fill(L(StringKey.BeekeeperLogWaspRaidFmt), N(e.Value), N(e.Value2)),
            BeekeeperEvents.Bribe => Fill(L(StringKey.BeekeeperLogBribeFmt), N(e.Value)),
            BeekeeperEvents.WaspLeft => L(StringKey.BeekeeperLogWaspLeft),
            BeekeeperEvents.CandleLit => L(StringKey.BeekeeperLogCandleLit),
            BeekeeperEvents.CandleOut => L(StringKey.BeekeeperLogCandleOut),
            BeekeeperEvents.SmokerPuffed => L(StringKey.BeekeeperLogSmokerPuffed),
            BeekeeperEvents.CalmEnded => L(StringKey.BeekeeperLogCalmEnded),
            BeekeeperEvents.SeedGiven => L(StringKey.BeekeeperLogSeedGiven),
            BeekeeperEvents.SeedPlanted => L(StringKey.BeekeeperLogSeedPlanted),
            BeekeeperEvents.SeedSprouted => L(StringKey.BeekeeperLogSeedSprouted),
            BeekeeperEvents.PlantRevealed => e.Text switch
            {
                BeekeeperPlants.Wildflowers => L(StringKey.BeekeeperLogPlantWildflowers),
                BeekeeperPlants.Bramble => L(StringKey.BeekeeperLogPlantBramble),
                _ => "",
            },
            BeekeeperEvents.FirstPollen => L(StringKey.BeekeeperLogFirstPollen),
            BeekeeperEvents.BeeBreadMade => L(StringKey.BeekeeperLogBeeBread),
            BeekeeperEvents.WoodenHive => L(StringKey.BeekeeperLogWoodenHive),
            _ => "",
        };
    }
}
