using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;

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
    public static string Catch => T(StringKey.BeekeeperCatchBee);
    public static string BeesLabel => T(StringKey.BeekeeperBeesLabel);
    public static string HoneyLabel => T(StringKey.BeekeeperHoneyLabel);
    public static string WaxLabel => T(StringKey.BeekeeperWaxLabel);
    public static string BeebitsLabel => T(StringKey.BeekeeperBeebitsLabel);
    public static string HiveTitle(bool wooden) =>
        T(wooden ? StringKey.BeekeeperHiveTitleWooden : StringKey.BeekeeperHiveTitleSkep);
    public static string Comb => T(StringKey.BeekeeperComb);
    public static string Build => T(StringKey.BeekeeperBuild);
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
    public static string WaxCatcherName => T(StringKey.BeekeeperWaxCatcher);
    public static string WaxCatcherBlurb => T(StringKey.BeekeeperWaxCatcherBlurb);
    /// <summary>What a comb gives (stage 7.5): "+0.2 honey a second, room for 300 honey and 2 wax".</summary>
    public static string CombBlurb(string honeyPerSecond, string honeyRoom, string waxRoom) =>
        Fill(T(StringKey.BeekeeperCombBlurbFmt), honeyPerSecond, honeyRoom, waxRoom);
    // Cut in stage 7.5 (spec 016): public static string CombBlurb(string storageAdded) => Fill(T(StringKey.BeekeeperCombBlurbFmt), storageAdded);

    // ---- stage 7.5: walls and capacity upgrades
    /// <summary>"Needs more wax storage (holds 32)": a price above the wax cap.</summary>
    public static string WaxWall(string holds) => Fill(T(StringKey.BeekeeperWallWaxFmt), holds);
    /// <summary>"Needs more honey storage (holds 200)": a price above the honey cap.</summary>
    public static string HoneyWall(string holds) => Fill(T(StringKey.BeekeeperWallHoneyFmt), holds);
    /// <summary>The hover on a button held back by a wall: the ways past it.</summary>
    public static string WaxWallTip => T(StringKey.BeekeeperWallWaxTip);
    public static string HoneyWallTip => T(StringKey.BeekeeperWallHoneyTip);
    public static string HoneySuper => T(StringKey.BeekeeperHoneySuper);
    public static string HoneySuperBlurb(string room, string owned) => Fill(T(StringKey.BeekeeperHoneySuperBlurbFmt), room, owned);
    public static string WaxTray => T(StringKey.BeekeeperWaxTray);
    public static string WaxTrayBlurb(string room, string owned) => Fill(T(StringKey.BeekeeperWaxTrayBlurbFmt), room, owned);
    public static string Add => T(StringKey.BeekeeperAdd);

    // ---- stage 2: The Workbench, Hippies, wasps, upgrades

    public static string WorkbenchTitle => T(StringKey.BeekeeperWorkbenchTitle);
    public static string BeeswaxCandle => T(StringKey.BeekeeperBeeswaxCandle);
    public static string BeeswaxBlurb => T(StringKey.BeekeeperBeeswaxBlurb);
    public static string RepellentCandle => T(StringKey.BeekeeperRepellentCandle);
    public static string RepellentBlurb(string time) => Fill(T(StringKey.BeekeeperRepellentBlurbFmt), time);
    public static string Make => T(StringKey.BeekeeperMake);
    public static string MakeTimes(int n) => Fill(T(StringKey.BeekeeperMakeTimesFmt), n.ToString());
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
            "wasps" => T(StringKey.BeekeeperWaspsName),
            _ => name ?? id,
        };
        return trades == 0 ? who : Fill(T(StringKey.BeekeeperBearTradesFmt), who, NumberFormatter.Format(trades, Lang));
    }

    /// <summary>What a buyer gives for what: "10 honey = 1 Beebit". <paramref name="give"/> is the
    /// offer's give amount (from the config).</summary>
    public static string TradeRate(string id, decimal give = 0m)
    {
        string g = NumberFormatter.Format(give, Lang);
        return id switch
        {
            "bear" => Fill(T(StringKey.BeekeeperSellHint), g),
            "hippies" => Fill(T(StringKey.BeekeeperHippiesRate), g),
            "wasps" => Fill(T(StringKey.BeekeeperWaspsRateFmt), g),
            _ => "",
        };
    }

    public static string TradeOne => T(StringKey.BeekeeperTradeOne);

    public static string WaspsTitle => T(StringKey.BeekeeperWaspsTitle);
    public static string WaspHere => T(StringKey.BeekeeperWaspHere);
    public static string TimeLeft(string time) => Fill(T(StringKey.BeekeeperTimeLeftFmt), time);
    public static string ThrowShoe => T(StringKey.BeekeeperThrowShoe);
    public static string Bribe(string honey) => Fill(T(StringKey.BeekeeperBribeFmt), honey);
    public static string LightCandle => T(StringKey.BeekeeperLightCandle);
    public static string CandleBurning(string time) => Fill(T(StringKey.BeekeeperCandleBurningFmt), time);

    /// <summary>A price that may mix resources: "300 beebits · 100 wax · 2 sage". Since stage 7.5 a
    /// price can include free bees, shown first ("20 bees · 10 wax").</summary>
    public static string Price(string? beebits, string? wax, string? sage,
                               string? pollen = null, string? honey = null, string? beeBread = null,
                               string? paper = null, string? propolis = null, string? bees = null)
    {
        var parts = new System.Collections.Generic.List<string>();
        if (bees != null) parts.Add(Fill(T(StringKey.BeekeeperCostBeesFmt), bees));
        if (beebits != null) parts.Add(beebits + " " + BeebitsLabel.ToLowerInvariant());
        if (wax != null) parts.Add(Fill(T(StringKey.BeekeeperCostWaxFmt), wax));
        if (sage != null) parts.Add(Fill(T(StringKey.BeekeeperCostSageFmt), sage));
        if (pollen != null) parts.Add(Fill(T(StringKey.BeekeeperCostPollenFmt), pollen));
        if (honey != null) parts.Add(Fill(T(StringKey.BeekeeperCostHoneyFmt), honey));
        if (beeBread != null) parts.Add(Fill(T(StringKey.BeekeeperCostBeeBreadFmt), beeBread));
        if (paper != null) parts.Add(Fill(T(StringKey.BeekeeperCostPaperFmt), paper));
        if (propolis != null) parts.Add(Fill(T(StringKey.BeekeeperCostPropolisFmt), propolis));
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

    /// <summary>A Shop upgrade's blurb. <paramref name="percent"/> is the figure it quotes (from the
    /// config, via the view model); upgrades whose blurb has no number ignore it.</summary>
    public static string UpgradeBlurb(string id, decimal? percent = null)
    {
        string P() => NumberFormatter.Format(percent ?? 0m, Lang);
        return id switch
        {
            BeekeeperUpgrades.Practice => Fill(T(StringKey.BeekeeperUpgradePracticeBlurb), P()),
            BeekeeperUpgrades.MorePractice => Fill(T(StringKey.BeekeeperUpgradeMorePracticeBlurb), P()),
            BeekeeperUpgrades.Smoker => T(StringKey.BeekeeperUpgradeSmokerBlurb),
            BeekeeperUpgrades.BiggerCombs1 => Fill(T(StringKey.BeekeeperUpgradeBiggerCombs1Blurb), P()),
            BeekeeperUpgrades.BiggerCombs2 => Fill(T(StringKey.BeekeeperUpgradeBiggerCombs2Blurb), P()),
            BeekeeperUpgrades.BetterWaxCatcher => Fill(T(StringKey.BeekeeperUpgradeBetterWaxCatcherBlurb), P()),
            BeekeeperUpgrades.StrongerCandles => Fill(T(StringKey.BeekeeperUpgradeStrongerCandlesBlurb), P()),
            BeekeeperUpgrades.Notebook => T(StringKey.BeekeeperUpgradeNotebookBlurb),
            BeekeeperUpgrades.ThirdBed => T(StringKey.BeekeeperUpgradeThirdBedBlurb),
            BeekeeperUpgrades.PropolisSeal => Fill(T(StringKey.BeekeeperUpgradePropolisSealBlurb), P()),
            _ => "",
        };
    }

    // ---- stage 4: the Garden, bees, bee bread, the wooden hive
    // Cut in stage 6 (spec 014): the forager and guard rows.
    // public static string HiveForagers => T(StringKey.BeekeeperHiveForagers);
    // public static string HiveGuards => T(StringKey.BeekeeperHiveGuards);
    public static string WoodenHiveName => T(StringKey.BeekeeperWoodenHiveName);
    public static string WoodenHiveBlurb(string percent) => Fill(T(StringKey.BeekeeperWoodenHiveBlurbFmt), percent);
    public static string Move => T(StringKey.BeekeeperMove);

    public static string GardenTitle => T(StringKey.BeekeeperGardenTitle);
    public static string GardenPlant => T(StringKey.BeekeeperGardenPlant);
    // Cut in stage 7 (spec 015): the growing seed was a surprise; beds now name what grows.
    // public static string GardenGrowing => T(StringKey.BeekeeperGardenGrowing);
    public static string GardenEmptyBed => T(StringKey.BeekeeperGardenEmptyBed);
    public static string BedGrowing(BeekeeperPlant p, decimal secondsLeft) =>
        Fill(T(StringKey.BeekeeperGardenBedGrowingFmt), PlantName(p.Id), Roughly(secondsLeft));
    /// <summary>"Willow seed": a seed in hand.</summary>
    public static string SeedLine(string plantId) => CapFirst(Fill(T(StringKey.BeekeeperGardenSeedFmt), SeedName(plantId, Lang)));
    /// <summary>The Plant button's hover: "Takes about 6 hours to grow."</summary>
    public static string TakesToGrow(decimal seconds) => Fill(T(StringKey.BeekeeperGardenTakesFmt), Roughly(seconds));

    private static string CapFirst(string s) => s.Length == 0 ? s : char.ToUpperInvariant(s[0]) + s.Substring(1);

    /// <summary>A rough time: whole minutes under an hour, whole hours above ("about 40 minutes").</summary>
    public static string Roughly(decimal seconds) => RoughlyIn(seconds, Lang);

    private static string RoughlyIn(decimal seconds, AppLanguage lang)
    {
        decimal minutes = System.Math.Ceiling(System.Math.Max(0m, seconds) / 60m);
        if (minutes < 60m)
        {
            if (minutes <= 1m) return Strings.Get(StringKey.BeekeeperDurationMinute, lang);
            return Fill(Strings.Get(StringKey.BeekeeperDurationMinutesFmt, lang), NumberFormatter.Format(minutes, lang));
        }
        decimal hours = System.Math.Max(1m, System.Math.Round(minutes / 60m));
        if (hours == 1m) return Strings.Get(StringKey.BeekeeperDurationHour, lang);
        return Fill(Strings.Get(StringKey.BeekeeperDurationHoursFmt, lang), NumberFormatter.Format(hours, lang));
    }

    // ---- stage 7: the poplar, propolis, the two candles, the Notebook
    public static string BeeBoostCandle => T(StringKey.BeekeeperBeeBoostCandle);
    public static string BeeBoostBlurb(string percent, string time) => Fill(T(StringKey.BeekeeperBeeBoostBlurbFmt), percent, time);
    public static string SagePropolisCandle => T(StringKey.BeekeeperSagePropolisCandle);
    public static string SagePropolisBlurb(string percent, string time) => Fill(T(StringKey.BeekeeperSagePropolisBlurbFmt), percent, time);
    public static string LightBeeBoost => T(StringKey.BeekeeperLightBeeBoost);
    public static string LightSagePropolis => T(StringKey.BeekeeperLightSagePropolis);
    public static string NotebookTitle => T(StringKey.BeekeeperNotebookTitle);

    public static string NotebookNote(string id) => id switch
    {
        BeekeeperNotes.Queen => T(StringKey.BeekeeperNoteQueen),
        BeekeeperSpecialties.Foraging => T(StringKey.BeekeeperNoteForaging),
        BeekeeperSpecialties.Guarding => T(StringKey.BeekeeperNoteGuarding),
        BeekeeperSpecialties.Nursing => T(StringKey.BeekeeperNoteNursing),
        BeekeeperSpecialties.Resin => T(StringKey.BeekeeperNoteResin),
        _ => "",
    };
    public static string BeeBread => T(StringKey.BeekeeperBeeBread);
    public static string BeeBreadBlurb => T(StringKey.BeekeeperBeeBreadBlurb);

    // ---- stage 5: the queen, the pantry, the trade agreement
    public static string QueenStatus(bool laying) =>
        T(laying ? StringKey.BeekeeperQueenLaying : StringKey.BeekeeperQueenResting);
    public static string BeesPerSecond(string n) => Fill(T(StringKey.BeekeeperBeesPerSecFmt), n);
    public static string BeeBreadPerSecond(string n) => Fill(T(StringKey.BeekeeperBeeBreadPerSecFmt), n);
    public static string AgreementLine => T(StringKey.BeekeeperAgreementLine);
    // Cut in stage 7.5 (spec 016): the agreement's rate hover (the bear no longer sells by himself).
    // public static string BeebitsPerSecond(string n) => Fill(T(StringKey.BeekeeperBeebitsPerSecFmt), n);

    /// <summary>"The pantry lasts about 8 hours." Minutes under an hour and a half, hours after.</summary>
    public static string PantryLasts(decimal seconds)
    {
        decimal minutes = System.Math.Ceiling(seconds / 60m);
        if (minutes <= 1m) return T(StringKey.BeekeeperPantryMinute);
        if (minutes < 90m)
            return Fill(T(StringKey.BeekeeperPantryMinutesFmt), NumberFormatter.Format(System.Math.Max(1m, minutes), Lang));
        return Fill(T(StringKey.BeekeeperPantryHoursFmt), NumberFormatter.Format(System.Math.Round(minutes / 60m), Lang));
    }

    // ---- stage 6: the Hive card in groups, specialties, the wasps' paper

    public static string HiveGroupTitle(string id) => id switch
    {
        BeekeeperHiveRows.GroupBees => T(StringKey.BeekeeperGroupBees),
        BeekeeperHiveRows.GroupHive => T(StringKey.BeekeeperGroupHive),
        BeekeeperHiveRows.GroupGarden => T(StringKey.BeekeeperGroupGarden),
        BeekeeperHiveRows.GroupCrafts => T(StringKey.BeekeeperGroupCrafts),
        BeekeeperHiveRows.GroupTradeGoods => T(StringKey.BeekeeperGroupTradeGoods),
        _ => id,
    };

    /// <summary>True for rows drawn as one full-width line (no label and value columns).</summary>
    public static bool IsHiveLine(string id) =>
        id is BeekeeperHiveRows.Foraging or BeekeeperHiveRows.Guarding or BeekeeperHiveRows.CombsFull
            or BeekeeperHiveRows.WaxFull or BeekeeperHiveRows.Nursing or BeekeeperHiveRows.Resin
            or BeekeeperHiveRows.BeeBoostBurning or BeekeeperHiveRows.SagePropolisBurning;

    /// <summary>A Hive row's label, or for a full-width row its whole line.</summary>
    public static string HiveRowLabel(BeekeeperHiveRow r)
    {
        string N(decimal v) => NumberFormatter.Format(v, Lang);
        return r.Id switch
        {
            BeekeeperHiveRows.Honeybees => T(StringKey.BeekeeperHiveBees),
            BeekeeperHiveRows.Queen => T(StringKey.BeekeeperHiveQueen),
            BeekeeperHiveRows.Foraging => Fill(T(StringKey.BeekeeperSpecialtyForagingFmt), N(r.Value)),
            BeekeeperHiveRows.Guarding => Fill(T(StringKey.BeekeeperSpecialtyGuardingFmt), N(r.Value)),
            BeekeeperHiveRows.Nursing => Fill(T(StringKey.BeekeeperSpecialtyNursingFmt), N(r.Value)),
            BeekeeperHiveRows.Resin => Fill(T(StringKey.BeekeeperSpecialtyResinFmt), N(r.Value)),
            BeekeeperHiveRows.Propolis => T(StringKey.BeekeeperHivePropolis),
            BeekeeperHiveRows.BeeBoostCandles => T(StringKey.BeekeeperHiveBeeBoostCandles),
            BeekeeperHiveRows.SagePropolisCandles => T(StringKey.BeekeeperHiveSagePropolisCandles),
            BeekeeperHiveRows.BeeBoostBurning => Fill(T(StringKey.BeekeeperBeeBoostBurningFmt), Roughly(r.Value)),
            BeekeeperHiveRows.SagePropolisBurning => Fill(T(StringKey.BeekeeperSagePropolisBurningFmt), Roughly(r.Value)),
            BeekeeperHiveRows.Honey => T(StringKey.BeekeeperHiveHoney),
            BeekeeperHiveRows.Wax => T(StringKey.BeekeeperHiveWax),
            BeekeeperHiveRows.Combs => T(StringKey.BeekeeperHiveCombs),
            BeekeeperHiveRows.CombsFull => T(StringKey.BeekeeperCombsFull),
            BeekeeperHiveRows.WaxFull => T(StringKey.BeekeeperWaxFull),
            BeekeeperHiveRows.Seeds => T(StringKey.BeekeeperHiveSeeds),
            BeekeeperHiveRows.Pollen => T(StringKey.BeekeeperHivePollen),
            BeekeeperHiveRows.BeeBread => T(StringKey.BeekeeperHiveBeeBread),
            BeekeeperHiveRows.BeeswaxCandles => T(StringKey.BeekeeperHiveBeeswaxCandles),
            BeekeeperHiveRows.RepellentCandles => T(StringKey.BeekeeperHiveRepellentCandles),
            BeekeeperHiveRows.Beebits => T(StringKey.BeekeeperHiveBeebits),
            BeekeeperHiveRows.Sage => T(StringKey.BeekeeperHiveSage),
            BeekeeperHiveRows.Paper => T(StringKey.BeekeeperHivePaper),
            _ => r.Id,
        };
    }

    /// <summary>A Hive row's value column ("45 / 200", "laying", "12").</summary>
    public static string HiveRowValue(BeekeeperHiveRow r)
    {
        string N(decimal v) => NumberFormatter.Format(v, Lang);
        return r.Id switch
        {
            BeekeeperHiveRows.Honey => N(r.Value) + " / " + N(r.Value2),
            BeekeeperHiveRows.Wax => N(r.Value) + " / " + N(r.Value2),   // stage 7.5: wax has a cap
            BeekeeperHiveRows.Queen => QueenStatus(r.Value > 0m),
            _ when IsHiveLine(r.Id) => "",
            _ => N(r.Value),
        };
    }

    /// <summary>The hover text for a row with a rate, or null for none.</summary>
    public static string? HiveRowTip(BeekeeperHiveRow r)
    {
        if (r.Rate is not { } rate) return null;
        string N(decimal v, int d) => NumberFormatter.Format(v, Lang, d);
        return r.Id switch
        {
            BeekeeperHiveRows.Honeybees => BeesPerSecond(N(rate, 2)),
            BeekeeperHiveRows.Honey => HoneyPerSecond(N(rate, 2)),
            BeekeeperHiveRows.Wax => WaxPerSecond(N(rate, 2)),
            BeekeeperHiveRows.Pollen => PollenPerSecond(N(rate, 2)),
            BeekeeperHiveRows.Propolis => Fill(T(StringKey.BeekeeperPropolisPerSecFmt), N(rate, 3)),
            BeekeeperHiveRows.BeeBread => BeeBreadPerSecond(N(rate, 4))
                                          + (r.Rate2 > 0m ? "\n" + PantryLasts(r.Rate2) : ""),
            _ => null,
        };
    }

    public static string PollenPerSecond(string n) => Fill(T(StringKey.BeekeeperPollenPerSecFmt), n);

    /// <summary>The Garden card's line for a sprouted plant: "Wildflowers: foraging".</summary>
    public static string PlantLine(BeekeeperPlant p) =>
        Fill(T(StringKey.BeekeeperPlantLineFmt), PlantName(p.Id), SpecialtyName(p.Specialty));

    public static string SpecialtyName(string id) => id switch
    {
        BeekeeperSpecialties.Foraging => T(StringKey.BeekeeperSpecialtyForaging),
        BeekeeperSpecialties.Guarding => T(StringKey.BeekeeperSpecialtyGuarding),
        BeekeeperSpecialties.Nursing => T(StringKey.BeekeeperSpecialtyNursing),
        BeekeeperSpecialties.Resin => T(StringKey.BeekeeperSpecialtyResin),
        _ => id,
    };

    public static string PlantName(string id) => id switch
    {
        BeekeeperPlants.Wildflowers => T(StringKey.BeekeeperPlantWildflowers),
        BeekeeperPlants.Bramble => T(StringKey.BeekeeperPlantBramble),
        BeekeeperPlants.Willow => T(StringKey.BeekeeperPlantWillow),
        BeekeeperPlants.Poplar => T(StringKey.BeekeeperPlantPoplar),
        BeekeeperPlants.Clover => T(StringKey.BeekeeperPlantClover),
        _ => id,
    };

    /// <summary>A plant as it is named before "seed": "wildflower", "willow" (lower case).</summary>
    private static string SeedName(string id, AppLanguage lang) => id switch
    {
        BeekeeperPlants.Wildflowers => Strings.Get(StringKey.BeekeeperSeedNameWildflowers, lang),
        BeekeeperPlants.Bramble => Strings.Get(StringKey.BeekeeperSeedNameBramble, lang),
        BeekeeperPlants.Willow => Strings.Get(StringKey.BeekeeperSeedNameWillow, lang),
        BeekeeperPlants.Poplar => Strings.Get(StringKey.BeekeeperSeedNamePoplar, lang),
        BeekeeperPlants.Clover => Strings.Get(StringKey.BeekeeperSeedNameClover, lang),
        _ => id,
    };

    public static string PlantBlurb(string id) => id switch
    {
        BeekeeperPlants.Wildflowers => T(StringKey.BeekeeperPlantWildflowersBlurb),
        BeekeeperPlants.Bramble => T(StringKey.BeekeeperPlantBrambleBlurb),
        BeekeeperPlants.Willow => T(StringKey.BeekeeperPlantWillowBlurb),
        BeekeeperPlants.Poplar => T(StringKey.BeekeeperPlantPoplarBlurb),
        BeekeeperPlants.Clover => T(StringKey.BeekeeperPlantCloverBlurb),
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
        BeekeeperUpgrades.Notebook => Strings.Get(StringKey.BeekeeperUpgradeNotebook, lang),
        BeekeeperUpgrades.ThirdBed => Strings.Get(StringKey.BeekeeperUpgradeThirdBed, lang),
        BeekeeperUpgrades.PropolisSeal => Strings.Get(StringKey.BeekeeperUpgradePropolisSeal, lang),
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
            // Lines saved before the amounts were kept (Value2 = 0) show the old short wording.
            BeekeeperEvents.Sale => e.Value2 <= 0m ? Fill(L(StringKey.BeekeeperLogSaleFmt), e.Text ?? "")
                : e.Value == 1m ? Fill(L(StringKey.BeekeeperLogTradeBearOneFmt), e.Text ?? "", N(e.Value2))
                : Fill(L(StringKey.BeekeeperLogTradeBearFmt), e.Text ?? "", N(e.Value2), N(e.Value)),
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
            BeekeeperEvents.CombBuilt => Fill(L(StringKey.BeekeeperLogCombBuiltFmt), N(e.Value)),   // stage 7.5: bees that moved in
            BeekeeperEvents.WelcomeBack => Fill(L(StringKey.BeekeeperLogWelcomeBackFmt), N(e.Value)),
            BeekeeperEvents.WelcomeBackNothing => L(StringKey.BeekeeperLogWelcomeBackNothing),
            BeekeeperEvents.WorkbenchOpened => L(StringKey.BeekeeperLogWorkbenchOpened),
            BeekeeperEvents.FirstBeeswaxCandle => L(StringKey.BeekeeperLogFirstBeeswaxCandle),
            BeekeeperEvents.HippiesArrive => L(StringKey.BeekeeperLogHippiesArrive),
            BeekeeperEvents.CandlesTraded => e.Value2 <= 0m
                ? Fill(L(StringKey.BeekeeperLogCandlesTradedFmt), N(e.Value))
                : Fill(L(StringKey.BeekeeperLogTradeHippiesFmt), N(e.Value2), N(e.Value)),
            BeekeeperEvents.RepellentUnlocked => L(StringKey.BeekeeperLogRepellentUnlocked),
            BeekeeperEvents.UpgradeBought => e.Text switch
            {
                BeekeeperUpgrades.Notebook => L(StringKey.BeekeeperLogNotebookBought),
                BeekeeperUpgrades.ThirdBed => L(StringKey.BeekeeperLogThirdBedBought),
                BeekeeperUpgrades.PropolisSeal => L(StringKey.BeekeeperLogPropolisSealBought),
                _ => Fill(L(StringKey.BeekeeperLogUpgradeBoughtFmt), UpgradeNameIn(e.Text ?? "", lang)),
            },
            BeekeeperEvents.WaspArrives => L(StringKey.BeekeeperLogWaspArrives),
            BeekeeperEvents.ShoeHit => L(StringKey.BeekeeperLogShoeHit),
            // Raids take only honey since stage 6 (spec 014). Lines saved before then keep their
            // old wording (bees flown off, or the guards keeping them safe), so the story stays true.
            BeekeeperEvents.ShoeMissRaid => e.Text == "guards"
                ? Fill(L(StringKey.BeekeeperLogShoeMissGuardsFmt), N(e.Value))
                : e.Value2 > 0m ? Fill(L(StringKey.BeekeeperLogShoeMissFmt), N(e.Value), N(e.Value2))
                : Fill(L(StringKey.BeekeeperLogShoeMissHoneyFmt), N(e.Value)),
            BeekeeperEvents.WaspRaid => e.Text == "guards"
                ? Fill(L(StringKey.BeekeeperLogWaspRaidGuardsFmt), N(e.Value))
                : e.Value2 > 0m ? Fill(L(StringKey.BeekeeperLogWaspRaidFmt), N(e.Value), N(e.Value2))
                : Fill(L(StringKey.BeekeeperLogWaspRaidHoneyFmt), N(e.Value)),
            BeekeeperEvents.Bribe => Fill(L(StringKey.BeekeeperLogBribeFmt), N(e.Value)),
            BeekeeperEvents.WaspLeft => L(StringKey.BeekeeperLogWaspLeft),
            BeekeeperEvents.CandleLit => L(StringKey.BeekeeperLogCandleLit),
            BeekeeperEvents.CandleOut => L(StringKey.BeekeeperLogCandleOut),
            BeekeeperEvents.SmokerPuffed => L(StringKey.BeekeeperLogSmokerPuffed),
            BeekeeperEvents.CalmEnded => L(StringKey.BeekeeperLogCalmEnded),
            // Lines saved before seeds had names (no plant in Text) keep the old wording.
            BeekeeperEvents.SeedGiven => string.IsNullOrEmpty(e.Text) ? L(StringKey.BeekeeperLogSeedGiven)
                : Fill(L(StringKey.BeekeeperLogSeedGivenFmt), SeedName(e.Text, lang)),
            BeekeeperEvents.WaspSeedGiven => Fill(L(StringKey.BeekeeperLogWaspSeedGivenFmt), SeedName(e.Text ?? "", lang)),
            BeekeeperEvents.SeedPlanted => string.IsNullOrEmpty(e.Text) ? L(StringKey.BeekeeperLogSeedPlanted)
                : Fill(L(StringKey.BeekeeperLogSeedPlantedFmt), SeedName(e.Text, lang)),
            BeekeeperEvents.SeedSprouted => L(StringKey.BeekeeperLogSeedSprouted),
            BeekeeperEvents.PlantRevealed => e.Text switch
            {
                BeekeeperPlants.Wildflowers => L(StringKey.BeekeeperLogPlantWildflowersForaging),
                BeekeeperPlants.Bramble => L(StringKey.BeekeeperLogPlantBrambleGuarding),
                BeekeeperPlants.Willow => L(StringKey.BeekeeperLogPlantWillowNursing),
                BeekeeperPlants.Poplar => L(StringKey.BeekeeperLogPlantPoplarResin),
                BeekeeperPlants.Clover => L(StringKey.BeekeeperLogPlantCloverForaging),
                // Cut in stage 6 (spec 014): the bees the plants attracted.
                // BeekeeperPlants.Wildflowers => L(StringKey.BeekeeperLogPlantWildflowers),
                // BeekeeperPlants.Bramble => L(StringKey.BeekeeperLogPlantBramble),
                _ => "",
            },
            BeekeeperEvents.FirstPollen => L(StringKey.BeekeeperLogFirstPollen),
            BeekeeperEvents.BeeBreadMade => L(StringKey.BeekeeperLogBeeBread),
            BeekeeperEvents.WoodenHive => L(StringKey.BeekeeperLogWoodenHive),
            BeekeeperEvents.QueenSettles => L(StringKey.BeekeeperLogQueenSettles),
            BeekeeperEvents.PantryEmpty => L(StringKey.BeekeeperLogPantryEmpty),
            BeekeeperEvents.QueenResumes => L(StringKey.BeekeeperLogQueenResumes),
            BeekeeperEvents.TradeAgreement => Fill(L(StringKey.BeekeeperLogTradeAgreementFmt), e.Text ?? ""),
            BeekeeperEvents.WelcomeBackQueen => e.Value == 1m ? L(StringKey.BeekeeperLogWelcomeBackQueenOne)
                : Fill(L(StringKey.BeekeeperLogWelcomeBackQueenFmt), N(e.Value)),
            // Cut in stage 7.5 (spec 016): the bear no longer sells honey while you are away.
            // BeekeeperEvents.WelcomeBackBear => e.Value == 1m ? Fill(L(StringKey.BeekeeperLogWelcomeBackBearOneFmt), e.Text ?? "")
            //     : Fill(L(StringKey.BeekeeperLogWelcomeBackBearFmt), e.Text ?? "", N(e.Value)),
            BeekeeperEvents.WelcomeBackPantry => L(StringKey.BeekeeperLogWelcomeBackPantry),
            BeekeeperEvents.OldCountsSettle => L(StringKey.BeekeeperLogOldCountsSettle),
            BeekeeperEvents.BribeHint => L(StringKey.BeekeeperLogBribeHint),
            BeekeeperEvents.Emissary => L(StringKey.BeekeeperLogEmissary),
            BeekeeperEvents.FirstPaper => L(StringKey.BeekeeperLogFirstPaper),
            BeekeeperEvents.FirstPropolis => L(StringKey.BeekeeperLogFirstPropolis),
            BeekeeperEvents.BeeBoostLit => L(StringKey.BeekeeperLogBeeBoostLit),
            BeekeeperEvents.BeeBoostOut => L(StringKey.BeekeeperLogBeeBoostOut),
            BeekeeperEvents.SagePropolisLit => L(StringKey.BeekeeperLogSagePropolisLit),
            BeekeeperEvents.SagePropolisOut => L(StringKey.BeekeeperLogSagePropolisOut),
            BeekeeperEvents.WelcomeBackSageOut => L(StringKey.BeekeeperLogWelcomeBackSageOut),
            BeekeeperEvents.WelcomeBackPropolis => Fill(L(StringKey.BeekeeperLogWelcomeBackPropolisFmt), N(e.Value)),
            BeekeeperEvents.WaspTrade => Fill(L(StringKey.BeekeeperLogTradeWaspsFmt), N(e.Value2), N(e.Value)),
            // Stage 7.5 (spec 016)
            BeekeeperEvents.WaxFull => L(StringKey.BeekeeperLogWaxFull),
            BeekeeperEvents.FirstWall => L(StringKey.BeekeeperLogFirstWall),
            BeekeeperEvents.HoneySuperBought => L(StringKey.BeekeeperLogHoneySuperBought),
            BeekeeperEvents.WaxTrayBought => L(StringKey.BeekeeperLogWaxTrayBought),
            BeekeeperEvents.Crafted => e.Text switch
            {
                "beeswax" => Fill(L(StringKey.BeekeeperLogCraftedBeeswaxFmt), N(e.Value)),
                "repellent" => Fill(L(StringKey.BeekeeperLogCraftedRepellentFmt), N(e.Value)),
                "bee_bread" => Fill(L(StringKey.BeekeeperLogCraftedBeeBreadFmt), N(e.Value)),
                "bee_boost" => Fill(L(StringKey.BeekeeperLogCraftedBeeBoostFmt), N(e.Value)),
                "sage_propolis" => Fill(L(StringKey.BeekeeperLogCraftedSagePropolisFmt), N(e.Value)),
                _ => "",
            },
            _ => "",
        };
    }
}
