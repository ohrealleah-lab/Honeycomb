using System.Linq;
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
    // Stage 8 (spec 017): after the meadow, "A HIVE IN THE MEADOW".
    public static string HiveTitle(bool wooden, bool meadow = false) =>
        T(meadow ? StringKey.BeekeeperHiveTitleMeadow : wooden ? StringKey.BeekeeperHiveTitleWooden : StringKey.BeekeeperHiveTitleSkep);
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
        // Bee, 2026-11-11: the gloves are found in a story card, no longer shown in the Shop.
        // "gloves" => T(StringKey.BeekeeperShopGloves),
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
    public static string RepellentCandle => T(StringKey.BeekeeperRepellentCandle);
    public static string RepellentBlurb(string time) => Fill(T(StringKey.BeekeeperRepellentBlurbFmt), time);
    public static string Make => T(StringKey.BeekeeperMake);
    public static string MakeTimes(int n) => Fill(T(StringKey.BeekeeperMakeTimesFmt), n.ToString());
    public static string Light => T(StringKey.BeekeeperLight);

    // ---- Trading: one shared card for every buyer (Leah)
    public static string TradingTitle => T(StringKey.BeekeeperTradingTitle);
    public static string TradeTen => T(StringKey.BeekeeperTradeTen);
    public static string TradeAll => T(StringKey.BeekeeperTradeAll);
    /// <summary>The bear's one-bundle button with the bundle of the moment ("Trade 10", then "Trade 8"
    /// under the agreement). Reuses the "Trade 10" words, whose number is the bundle, so no new key.</summary>
    public static string TradeBundle(decimal honey) =>
        TradeTen.Replace("10", NumberFormatter.Format(honey, Lang));

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

    /// <summary>What a buyer gives for what: "10 honey = 5 Beebits". <paramref name="give"/> and
    /// <paramref name="get"/> are the offer's amounts (from the config).</summary>
    public static string TradeRate(string id, decimal give = 0m, decimal get = 0m)
    {
        string g = NumberFormatter.Format(give, Lang);
        return id switch
        {
            "bear" => get == 1m ? Fill(T(StringKey.BeekeeperSellHintOneFmt), g)   // "10 honey = 1 Beebit"
                : Fill(T(StringKey.BeekeeperSellHint), g, NumberFormatter.Format(get, Lang)),   // "10 honey = 5 Beebits"
            // Stage 10: "3 beeswax candles = 1 clay jar" (was "1 herbal candle = N Beebits").
            "hippies" => Fill(T(StringKey.BeekeeperHippiesRate), g),
            "wasps" => Fill(T(StringKey.BeekeeperWaspsRateFmt), g),
            _ => "",
        };
    }

    public static string TradeOne => T(StringKey.BeekeeperTradeOne);

    // ---- stage 10 (spec 019): potted honey, clay jars, the beeswax candle, the opening card
    public static string PotHoney => T(StringKey.BeekeeperPotHoney);
    /// <summary>"10 honey + 1 clay jar → 1 potted honey. The Bear pays more for it."</summary>
    public static string PotHoneyTip(string honey) => Fill(T(StringKey.BeekeeperPotHoneyTipFmt), honey);
    public static string SellPotted => T(StringKey.BeekeeperSellPotted);
    public static string SellAllPotted => T(StringKey.BeekeeperSellAllPotted);
    /// <summary>"1 potted honey = 15 Beebits".</summary>
    public static string PottedRate(decimal beebits) => Fill(T(StringKey.BeekeeperPottedRateFmt), NumberFormatter.Format(beebits, Lang));
    /// <summary>The Hippies' one-trade button: "Trade 3 candles for a clay jar".</summary>
    public static string TradeJar(decimal candles) => Fill(T(StringKey.BeekeeperTradeJarFmt), NumberFormatter.Format(candles, Lang));
    public static string BeeswaxCandle => T(StringKey.BeekeeperBeeswaxCandle);
    public static string BeeswaxBlurb => T(StringKey.BeekeeperBeeswaxBlurb);
    public static string StoryOpening => T(StringKey.BeekeeperStoryOpening);
    // Craft links and their story cards (Bee, 2026-11-12)
    public static string StoryPotHoney => T(StringKey.BeekeeperStoryPotHoney);
    public static string StoryPotHoneyButton => T(StringKey.BeekeeperStoryPotHoneyButton);
    public static string StoryCandle => T(StringKey.BeekeeperStoryCandle);
    public static string StoryCandleButton => T(StringKey.BeekeeperStoryCandleButton);
    public static string StoryBeeBread => T(StringKey.BeekeeperStoryBeeBread);
    public static string StoryBeeBreadButton => T(StringKey.BeekeeperStoryBeeBreadButton);
    /// <summary>A craft link's text: "+1", "+10", "+100".</summary>
    public static string CraftLink(int n) => Fill(T(StringKey.BeekeeperCraftLinkFmt), n.ToString());
    public static string PinnedGloves => T(StringKey.BeekeeperPinnedGloves);
    public static string StoryLookAround => T(StringKey.BeekeeperStoryLookAround);
    /// <summary>The hover on a burning Good Deals candle: "+50% Beebits from the Bear."</summary>
    public static string HerbTradesTip(decimal percent) => Fill(T(StringKey.BeekeeperHerbTradesTipFmt), NumberFormatter.Format(percent, Lang));

    public static string WaspsTitle => T(StringKey.BeekeeperWaspsTitle);
    public static string WaspHere => T(StringKey.BeekeeperWaspHere);
    public static string TimeLeft(string time) => Fill(T(StringKey.BeekeeperTimeLeftFmt), time);
    public static string ThrowShoe => T(StringKey.BeekeeperThrowShoe);
    // Story cards
    public static string StoryOuch => T(StringKey.BeekeeperStoryOuch);
    public static string StoryGloves => T(StringKey.BeekeeperStoryGloves);
    public static string StorySmoker => T(StringKey.BeekeeperStorySmoker);
    /// <summary>"A wildflower seed! Plant it in the garden?" (Bee, 2026-11-11).</summary>
    public static string StorySeed(string plantId) => Fill(T(StringKey.BeekeeperStorySeedFmt), SeedName(plantId, Lang));
    public static string StoryYes => T(StringKey.Yes);
    public static string StoryNo => T(StringKey.BeekeeperStoryNo);
    public static string StoryRepair => T(StringKey.BeekeeperStoryRepair);
    public static string Bribe(string honey) => Fill(T(StringKey.BeekeeperBribeFmt), honey);
    public static string Engage => T(StringKey.BeekeeperEngage);
    public static string VisitorsTitle => T(StringKey.BeekeeperVisitorsTitle);
    public static string RepNoun(string? id) => T(id == "bear" ? StringKey.BeekeeperRepBear : StringKey.BeekeeperRepHippies);
    public static string RepHere(string id) => Fill(T(StringKey.BeekeeperLogRepArrivesFmt), RepNoun(id));
    public static string LightCandle => T(StringKey.BeekeeperLightCandle);
    public static string CandleBurning(string time) => Fill(T(StringKey.BeekeeperCandleBurningFmt), time);

    /// <summary>A price that may mix resources: "300 beebits · 100 wax · 2 sage". Since stage 7.5 a
    /// price can include free bees, shown first ("20 bees · 10 wax").</summary>
    public static string Price(string? beebits, string? wax, string? herbs,
                               string? pollen = null, string? honey = null, string? beeBread = null,
                               string? paper = null, string? propolis = null, string? bees = null, string? wood = null)
    {
        var parts = new System.Collections.Generic.List<string>();
        if (bees != null) parts.Add(Fill(T(StringKey.BeekeeperCostBeesFmt), bees));
        if (beebits != null) parts.Add(beebits + " " + BeebitsLabel.ToLowerInvariant());
        if (wax != null) parts.Add(Fill(T(StringKey.BeekeeperCostWaxFmt), wax));
        if (herbs != null) parts.Add(herbs == "1" ? T(StringKey.BeekeeperCostHerbOne) : Fill(T(StringKey.BeekeeperCostSageFmt), herbs));
        if (pollen != null) parts.Add(Fill(T(StringKey.BeekeeperCostPollenFmt), pollen));
        if (honey != null) parts.Add(Fill(T(StringKey.BeekeeperCostHoneyFmt), honey));
        if (beeBread != null) parts.Add(Fill(T(StringKey.BeekeeperCostBeeBreadFmt), beeBread));
        if (paper != null) parts.Add(Fill(T(StringKey.BeekeeperCostPaperFmt), paper));
        if (propolis != null) parts.Add(Fill(T(StringKey.BeekeeperCostPropolisFmt), propolis));
        if (wood != null) parts.Add(Fill(T(StringKey.BeekeeperCostWoodFmt), wood));   // stage 8
        return string.Join(" · ", parts);
    }

    /// <summary>Minutes and seconds, e.g. "0:42" or "14:30" (rounded up, so it never shows 0:00 early).</summary>
    public static string Clock(decimal seconds)
    {
        long s = (long)System.Math.Ceiling(System.Math.Max(0m, seconds));
        return $"{s / 60}:{s % 60:00}";
    }

    public static string UpgradeName(string id) => UpgradeNameIn(id, Lang);

    /// <summary>A Shop upgrade's blurb. <paramref name="percent"/> is the figure it quotes (from the
    /// config, via the view model); upgrades whose blurb has no number ignore it.</summary>
    public static string UpgradeBlurb(string id, decimal? percent = null)
    {
        string P() => NumberFormatter.Format(percent ?? 0m, Lang);
        return id switch
        {
            BeekeeperUpgrades.Practice => Fill(T(StringKey.BeekeeperUpgradePracticeBlurb), P()),
            BeekeeperUpgrades.MorePractice => Fill(T(StringKey.BeekeeperUpgradeMorePracticeBlurb), P()),
            BeekeeperUpgrades.Smoker => Fill(T(StringKey.BeekeeperUpgradeSmokerBlurb), P()),
            BeekeeperUpgrades.BiggerCombs1 => Fill(T(StringKey.BeekeeperUpgradeBiggerCombs1Blurb), P()),
            BeekeeperUpgrades.BiggerCombs2 => Fill(T(StringKey.BeekeeperUpgradeBiggerCombs2Blurb), P()),
            BeekeeperUpgrades.BetterWaxCatcher => Fill(T(StringKey.BeekeeperUpgradeBetterWaxCatcherBlurb), P()),
            BeekeeperUpgrades.StrongerCandles => Fill(T(StringKey.BeekeeperUpgradeStrongerCandlesBlurb), P()),
            BeekeeperUpgrades.Notebook => T(StringKey.BeekeeperUpgradeNotebookBlurb),
            BeekeeperUpgrades.ThirdBed => T(StringKey.BeekeeperUpgradeThirdBedBlurb),
            BeekeeperUpgrades.PropolisSeal => Fill(T(StringKey.BeekeeperUpgradePropolisSealBlurb), P()),
            // Stage 8 (spec 017): the percent is how much less wax; the molds' number is candles a craft.
            BeekeeperUpgrades.WoodenFrames => Fill(T(StringKey.BeekeeperUpgradeWoodenFramesBlurb), P()),
            BeekeeperUpgrades.CandleMolds => Fill(T(StringKey.BeekeeperUpgradeCandleMoldsBlurb), P()),
            BeekeeperUpgrades.DippingRack => Fill(T(StringKey.BeekeeperUpgradeDippingRackBlurb), P()),
            _ => "",
        };
    }

    /// <summary>The Bee Hotel's blurb (stage 8): "Rare bees move in, and one brings back a gift every 30 min".</summary>
    public static string HotelBlurb(decimal giftSeconds) =>
        Fill(T(StringKey.BeekeeperUpgradeBeeHotelBlurb), ShortTime(giftSeconds));

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
    /// <summary>"Wildflower seeds ×12": seeds of one kind in hand (stage 8).</summary>
    public static string SeedsLine(string plantId, int count) =>
        CapFirst(Fill(T(StringKey.BeekeeperGardenSeedsFmt), SeedName(plantId, Lang), NumberFormatter.Format(count, Lang)));

    /// <summary>"Each one after the first: +1% honey (now +22%)" (stage 8).</summary>
    public static string PlantBonusLine(BeekeeperPlant p, decimal nowPercent) =>
        Fill(T(StringKey.BeekeeperPlantBonusFmt), NumberFormatter.Format(p.BonusPerExtra * 100m, Lang, 2),
            BonusTargetName(p.BonusTarget), NumberFormatter.Format(nowPercent, Lang, 2));

    public static string BonusTargetName(string target) => target switch
    {
        BeekeeperBonusTargets.Honey => T(StringKey.BeekeeperBonusHoney),
        BeekeeperBonusTargets.Wax => T(StringKey.BeekeeperBonusWax),
        BeekeeperBonusTargets.Wood => T(StringKey.BeekeeperBonusWood),
        BeekeeperBonusTargets.Propolis => T(StringKey.BeekeeperBonusPropolis),
        _ => target,
    };

    // ---- stage 8: candles per craft, the meadow, the Notebook's tabs, the bees
    /// <summary>"makes 2", after a candle's price once the Candle Molds are owned.</summary>
    public static string Makes(int n) => Fill(T(StringKey.BeekeeperMakesFmt), n.ToString());
    public static string MeadowName => T(StringKey.BeekeeperMeadowName);
    public static string MeadowButton => T(StringKey.BeekeeperMeadowButton);
    public static string MeadowNeed(string wildHave, string wildNeed, string cloverHave, string cloverNeed) =>
        Fill(T(StringKey.BeekeeperMeadowNeedFmt), wildHave, wildNeed, cloverHave, cloverNeed);
    public static string MeadowBlurb(string honeyPerSecond, string honeyRoom, string waxRoom) =>
        Fill(T(StringKey.BeekeeperMeadowBlurbFmt), honeyPerSecond, honeyRoom, waxRoom);
    public static string TabNotes => T(StringKey.BeekeeperTabNotes);
    public static string TabBees => T(StringKey.BeekeeperTabBees);

    /// <summary>A bee's name in a sentence, lower case ("mason bee"); the Bees tab capitalizes it.</summary>
    private static string BeeNameIn(string id, AppLanguage lang) => Strings.Get(id switch
    {
        BeekeeperBees.Honey => StringKey.BeekeeperBeeNameHoneybees,
        BeekeeperBees.Queen => StringKey.BeekeeperBeeNameQueen,
        BeekeeperBees.Carpenter => StringKey.BeekeeperBeeNameCarpenter,
        BeekeeperBees.Mason => StringKey.BeekeeperBeeNameMason,
        BeekeeperBees.Leafcutter => StringKey.BeekeeperBeeNameLeafcutter,
        _ => StringKey.BeekeeperBeeNameWoolCarder,
    }, lang);

    public static string BeeTitle(string id) => CapFirst(BeeNameIn(id, Lang));

    public static string BeeDoes(string id) => T(id switch
    {
        BeekeeperBees.Honey => StringKey.BeekeeperBeeDoesHoneybees,
        BeekeeperBees.Queen => StringKey.BeekeeperBeeDoesQueen,
        BeekeeperBees.Carpenter => StringKey.BeekeeperBeeDoesCarpenter,
        BeekeeperBees.Mason => StringKey.BeekeeperBeeDoesMason,
        BeekeeperBees.Leafcutter => StringKey.BeekeeperBeeDoesLeafcutter,
        _ => StringKey.BeekeeperBeeDoesWoolCarder,
    });

    /// <summary>Every fact a bee has (one each for now; Bee adds more later as new keys here).
    /// The Bees tab picks one at random each time it opens.</summary>
    public static System.Collections.Generic.IReadOnlyList<string> BeeFacts(string id) => (id switch
    {
        BeekeeperBees.Honey => new[] { StringKey.BeekeeperBeeFactHoneybees1 },
        BeekeeperBees.Queen => new[] { StringKey.BeekeeperBeeFactQueen1 },
        BeekeeperBees.Carpenter => new[] { StringKey.BeekeeperBeeFactCarpenter1 },
        BeekeeperBees.Mason => new[] { StringKey.BeekeeperBeeFactMason1 },
        BeekeeperBees.Leafcutter => new[] { StringKey.BeekeeperBeeFactLeafcutter1 },
        _ => new[] { StringKey.BeekeeperBeeFactWoolCarder1 },
    }).Select(T).ToList();

    /// <summary>A hotel gift in words: "a clover seed", "2 herbs", "5 propolis".</summary>
    private static string GiftIn(string? text, decimal amount, AppLanguage lang)
    {
        var g = BeekeeperEngine.ParseGiftText(text);
        string N(decimal v) => NumberFormatter.Format(v, lang);
        return g.Gift switch
        {
            BeekeeperGifts.Seed => amount == 1m && g.Plant is { } p
                ? Fill(Strings.Get(StringKey.BeekeeperGiftSeedOneFmt, lang), SeedName(p, lang))
                : Fill(Strings.Get(StringKey.BeekeeperGiftSeedsFmt, lang), N(amount)),
            BeekeeperGifts.Herbs => amount == 1m ? Strings.Get(StringKey.BeekeeperGiftHerbOne, lang)
                : Fill(Strings.Get(StringKey.BeekeeperGiftHerbsFmt, lang), N(amount)),
            _ => Fill(Strings.Get(StringKey.BeekeeperGiftPropolisFmt, lang), N(amount)),
        };
    }

    /// <summary>The welcome-back gifts: "3 seeds, 4 herbs and 10 propolis" (only the kinds that came).</summary>
    private static string GiftsIn(decimal seeds, decimal herbs, decimal propolis, AppLanguage lang)
    {
        string N(decimal v) => NumberFormatter.Format(v, lang);
        var parts = new System.Collections.Generic.List<string>();
        if (seeds > 0m) parts.Add(seeds == 1m ? Strings.Get(StringKey.BeekeeperGiftSeedOne, lang) : Fill(Strings.Get(StringKey.BeekeeperGiftSeedsFmt, lang), N(seeds)));
        if (herbs > 0m) parts.Add(herbs == 1m ? Strings.Get(StringKey.BeekeeperGiftHerbOne, lang) : Fill(Strings.Get(StringKey.BeekeeperGiftHerbsFmt, lang), N(herbs)));
        if (propolis > 0m) parts.Add(Fill(Strings.Get(StringKey.BeekeeperGiftPropolisFmt, lang), N(propolis)));
        if (parts.Count <= 1) return string.Concat(parts);
        return string.Join(", ", parts.Take(parts.Count - 1)) + Strings.Get(StringKey.BeekeeperListAnd, lang) + parts[^1];
    }

    /// <summary>"Willow seed": a seed in hand.</summary>
    public static string SeedLine(string plantId) => CapFirst(Fill(T(StringKey.BeekeeperGardenSeedFmt), SeedName(plantId, Lang)));
    // Cut in stage 8 (spec 017): plants grow at once.
    // /// <summary>The Plant button's hover: "Takes about 6 hours to grow."</summary>
    // public static string TakesToGrow(decimal seconds) => Fill(T(StringKey.BeekeeperGardenTakesFmt), Roughly(seconds));

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

    // ---- herbal candles (lit for one buff)
    // Cut (Bee, 2026-11-11): the Shop's Bee Herbs row.
    // public static string BeeHerbs => T(StringKey.BeekeeperBeeHerbs);
    // public static string BeeHerbsBlurb(string owned, string time) => Fill(T(StringKey.BeekeeperBeeHerbsBlurbFmt), owned, time);
    // public static string LightBeeHerb => T(StringKey.BeekeeperLightBeeHerb);
    public static string HerbBurning(string buff, string time) => Fill(T(StringKey.BeekeeperHerbBurningFmt), HerbName(buff), time);
    public static string HerbName(string buff) => buff switch
    {
        BeekeeperHerbs.BusyBees => T(StringKey.BeekeeperHerbBusyBees),
        BeekeeperHerbs.Wax => T(StringKey.BeekeeperHerbWax),
        BeekeeperHerbs.Trades => T(StringKey.BeekeeperHerbTrades),
        BeekeeperHerbs.Wanderers => T(StringKey.BeekeeperHerbWanderers),
        BeekeeperHerbs.LingeringSmoke => T(StringKey.BeekeeperHerbLingeringSmoke),
        BeekeeperHerbs.QuickFingers => T(StringKey.BeekeeperHerbQuickFingers),
        _ => buff,
    };

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
            BeekeeperHiveRows.RepellentCandles => T(StringKey.BeekeeperHiveRepellentCandles),
            BeekeeperHiveRows.Beebits => T(StringKey.BeekeeperHiveBeebits),
            BeekeeperHiveRows.Herbs => T(StringKey.BeekeeperHiveSage),   // "Herbs" (key kept from sage)
            BeekeeperHiveRows.Paper => T(StringKey.BeekeeperHivePaper),
            BeekeeperHiveRows.Wood => T(StringKey.BeekeeperHiveWood),   // stage 8
            // Stage 10
            BeekeeperHiveRows.ClayJars => T(StringKey.BeekeeperHiveClayJars),
            BeekeeperHiveRows.PottedHoney => T(StringKey.BeekeeperHivePottedHoney),
            BeekeeperHiveRows.BeeswaxCandles => T(StringKey.BeekeeperHiveBeeswaxCandles),
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

    /// <summary>One line per boost that is on ("+100% from the Smoker"), each starting a new line.</summary>
    private static string BoostLines(System.Collections.Generic.IReadOnlyList<BeekeeperBoost>? boosts)
    {
        if (boosts is null || boosts.Count == 0) return "";
        var sb = new System.Text.StringBuilder();
        foreach (var b in boosts)
        {
            string pct = NumberFormatter.Format(b.Percent, Lang, 2);
            sb.Append('\n').Append(b.Id switch
            {
                "smoker" => Fill(T(StringKey.BeekeeperBoostSmokerFmt), pct),
                "free_bees" => Fill(T(StringKey.BeekeeperHoneyFreeBeeBonusFmt), pct),
                "wax_catcher" => Fill(T(StringKey.BeekeeperBoostWaxCatcherFmt), pct),
                "wooden_hive" => Fill(T(StringKey.BeekeeperBoostWoodenHiveFmt), pct),
                "guarding" => Fill(T(StringKey.BeekeeperBoostGuardingFmt), pct),
                "nursing" => Fill(T(StringKey.BeekeeperBoostNursingFmt), pct),
                "bee_boost" => Fill(T(StringKey.BeekeeperBoostBeeBoostFmt), pct),
                "sage_propolis" => Fill(T(StringKey.BeekeeperBoostHerbPropolisFmt), pct),
                // Stage 8: "Wildflowers ×49: +49%"
                BeekeeperBeeTab.PlantBoost => Fill(T(StringKey.BeekeeperBoostPlantFmt), PlantName(b.Plant ?? ""),
                    NumberFormatter.Format(b.Count, Lang), pct),
                // Stage 9: "Linden in bloom: guarding ×2", "Winter: ×0.75"
                "bloom" => Fill(T(StringKey.BeekeeperBoostBloomFmt), CapFirst(BloomName(b.Plant ?? "")),
                    SpecialtyName(b.Specialty ?? ""), NumberFormatter.Format(b.Count, Lang, 2)),
                "winter" => Fill(T(StringKey.BeekeeperBoostWinterFmt), NumberFormatter.Format(b.Count, Lang, 2)),
                _ => Fill(T(StringKey.BeekeeperBoostHerbFmt), pct, HerbName(b.Id)),
            });
        }
        return sb.ToString();
    }

    /// <summary>One line per source ("+0.025 / sec from 250 free bees"), each starting a new line.</summary>
    private static string SourceLines(System.Collections.Generic.IReadOnlyList<BeekeeperSource>? sources)
    {
        if (sources is null || sources.Count == 0) return "";
        var sb = new System.Text.StringBuilder();
        foreach (var s in sources)
        {
            string rate = NumberFormatter.Format(s.PerSecond, Lang, 4);
            string count = NumberFormatter.Format(s.Count, Lang);
            sb.Append('\n').Append(s.Id switch
            {
                "wax_drip" => Fill(T(StringKey.BeekeeperSourceOnItsOwnFmt), rate),
                "free_bees" => s.Count == 1m ? Fill(T(StringKey.BeekeeperSourceFreeBeeOneFmt), rate)
                    : Fill(T(StringKey.BeekeeperSourceFreeBeesFmt), rate, count),
                "combs" => s.Count == 1m ? Fill(T(StringKey.BeekeeperSourceCombOneFmt), rate)
                    : Fill(T(StringKey.BeekeeperSourceCombsFmt), rate, count),
                "queen" => Fill(T(StringKey.BeekeeperSourceQueenFmt), rate),
                "foraging" => Fill(T(StringKey.BeekeeperSourceForagingFmt), rate),
                "resin" => Fill(T(StringKey.BeekeeperSourceResinFmt), rate),
                "carpenter_bee" => Fill(T(StringKey.BeekeeperSourceCarpenterBeeFmt), rate),   // stage 8
                "meadow" => Fill(T(StringKey.BeekeeperSourceMeadowFmt), rate),
                _ => Fill(T(StringKey.BeekeeperSourceHerbFmt), rate, HerbName(s.Id)),
            });
        }
        return sb.ToString();
    }

    /// <summary>What the free bees give right now (wax, honey), each on its own line; empty if nothing is active.</summary>
    private static string GivesLines(BeekeeperHiveRow r)
    {
        if (r.Gives is null || r.Gives.Count == 0) return "";
        var sb = new System.Text.StringBuilder("\n").Append(T(StringKey.BeekeeperFreeBeesGiveHeader));
        foreach (var g in r.Gives)
            sb.Append('\n').Append(g.Id == "wax"
                ? Fill(T(StringKey.BeekeeperFreeBeesGiveWaxFmt), NumberFormatter.Format(g.PerSecond, Lang, 4))
                : Fill(T(StringKey.BeekeeperFreeBeesGiveHoneyFmt), NumberFormatter.Format(g.PerSecond, Lang, 2)));
        return sb.ToString();
    }

    /// <summary>Everything that feeds a growing stat: its sources, then its boosts.</summary>
    private static string Parts(BeekeeperHiveRow r) => SourceLines(r.Sources) + BoostLines(r.Boosts);

    /// <summary>The hover text for a row with a rate, or null for none.</summary>
    public static string? HiveRowTip(BeekeeperHiveRow r)
    {
        // Stage 10 (spec 019, FR-1015): rows whose hover is words, not a rate.
        switch (r.Id)
        {
            case BeekeeperHiveRows.Beebits: return BeebitsTip(r);
            case BeekeeperHiveRows.ClayJars:
                return Fill(T(StringKey.BeekeeperClayJarsTipFmt), NumberFormatter.Format(r.Rate2, Lang), NumberFormatter.Format(r.Value2, Lang));
            case BeekeeperHiveRows.Herbs: return T(StringKey.BeekeeperHerbsTip);
            case BeekeeperHiveRows.Honeybees when r.Rate is null:   // no queen yet: the hover still says what the bees give
                return GivesLines(r).TrimStart('\n') is { Length: > 0 } g ? g : null;
        }
        if (r.Rate is not { } rate) return null;
        string N(decimal v, int d) => NumberFormatter.Format(v, Lang, d);
        string? tip = r.Id switch
        {
            // Every stat that grows on its own lists all that feeds it (Bee, 2026-11-11). The free
            // bees' honey bonus is now one of the honey boosts (it was read from Rate2 here).
            BeekeeperHiveRows.Honeybees => BeesPerSecond(N(rate, 2)) + Parts(r) + GivesLines(r),
            BeekeeperHiveRows.Honey => HoneyPerSecond(N(rate, 2)) + Parts(r),
            BeekeeperHiveRows.Wax => WaxPerSecond(N(rate, 2)) + Parts(r),
            BeekeeperHiveRows.Pollen => PollenPerSecond(N(rate, 2)) + Parts(r),
            BeekeeperHiveRows.Propolis => Fill(T(StringKey.BeekeeperPropolisPerSecFmt), N(rate, 3)) + Parts(r),
            BeekeeperHiveRows.Wood => Fill(T(StringKey.BeekeeperWoodPerSecFmt), N(rate, 3)) + Parts(r),   // stage 8
            BeekeeperHiveRows.BeeBread => BeeBreadPerSecond(N(rate, 4))
                                          + (r.Rate2 > 0m ? "\n" + PantryLasts(r.Rate2) : ""),
            _ => null,
        };
        // The shared rule: any capped row (SecondsToFull set) also says how long until it is full.
        if (tip is not null && r.SecondsToFull is { } toFull) tip += "\n" + TimeToFull(toFull);
        return tip;
    }

    /// <summary>The Beebits hover (stage 10): only the bear pays them; a line for plain honey (or the
    /// agreement's rate), one for potted honey once it has been made, then the Trades herb if it burns.</summary>
    private static string BeebitsTip(BeekeeperHiveRow r)
    {
        string N(decimal v) => NumberFormatter.Format(v, Lang);
        var sb = new System.Text.StringBuilder(T(StringKey.BeekeeperBeebitsTip));
        foreach (var s in r.Sources ?? System.Array.Empty<BeekeeperSource>())
        {
            string? line = s.Id switch
            {
                "plain_honey" => Fill(T(StringKey.BeekeeperBeebitsSourcePlainFmt), N(s.Count), N(s.PerSecond)),
                "plain_honey_agreement" => Fill(T(StringKey.BeekeeperBeebitsSourceAgreementFmt), N(s.Count), N(s.PerSecond)),
                "potted_honey" => Fill(T(StringKey.BeekeeperBeebitsSourcePottedFmt), N(s.PerSecond)),
                _ => null,
            };
            if (line is not null) sb.Append('\n').Append(line);
        }
        return sb + BoostLines(r.Boosts);
    }

    /// <summary>"Full" at the cap, else "Full in 3 h 20 min".</summary>
    public static string TimeToFull(decimal seconds) =>
        seconds <= 0m ? T(StringKey.BeekeeperTimeToFullFull) : Fill(T(StringKey.BeekeeperTimeToFullFmt), ShortTime(seconds));

    /// <summary>A short readable time, rounded up so it never says 0: "45 sec", "12 min", "3 h 20 min", "2 d 5 h".</summary>
    public static string ShortTime(decimal seconds)
    {
        string N(decimal v) => NumberFormatter.Format(v, Lang);
        decimal s = System.Math.Ceiling(System.Math.Max(1m, seconds));
        if (s < 60m) return Fill(T(StringKey.BeekeeperTimeSecFmt), N(s));
        decimal minutes = System.Math.Ceiling(s / 60m);
        if (minutes < 60m) return Fill(T(StringKey.BeekeeperTimeMinFmt), N(minutes));
        decimal hours = System.Math.Floor(minutes / 60m), restMin = minutes - hours * 60m;
        if (hours < 24m)
            return restMin == 0m ? Fill(T(StringKey.BeekeeperTimeHourFmt), N(hours))
                                 : Fill(T(StringKey.BeekeeperTimeHourMinFmt), N(hours), N(restMin));
        decimal days = System.Math.Floor(hours / 24m), restHours = hours - days * 24m;
        return restHours == 0m ? Fill(T(StringKey.BeekeeperTimeDayFmt), N(days))
                               : Fill(T(StringKey.BeekeeperTimeDayHourFmt), N(days), N(restHours));
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

    // ---- stage 9: the bloom calendar

    /// <summary>A bloom's name, lower case: "linden", "winter".</summary>
    public static string BloomName(string id) => BloomNameIn(id, Lang);

    private static string BloomNameIn(string id, AppLanguage lang) => id switch
    {
        BeekeeperBlooms.Crocus => Strings.Get(StringKey.BeekeeperBloomCrocus, lang),
        BeekeeperBlooms.Clover => Strings.Get(StringKey.BeekeeperBloomClover, lang),
        BeekeeperBlooms.Linden => Strings.Get(StringKey.BeekeeperBloomLinden, lang),
        BeekeeperBlooms.Goldenrod => Strings.Get(StringKey.BeekeeperBloomGoldenrod, lang),
        BeekeeperBlooms.Winter => Strings.Get(StringKey.BeekeeperBloomWinter, lang),
        _ => id,
    };

    /// <summary>A bloom with its article, for the welcome-back list: "the linden", "winter".</summary>
    private static string TheBloomIn(string id, AppLanguage lang) => id switch
    {
        BeekeeperBlooms.Crocus => Strings.Get(StringKey.BeekeeperBloomTheCrocus, lang),
        BeekeeperBlooms.Clover => Strings.Get(StringKey.BeekeeperBloomTheClover, lang),
        BeekeeperBlooms.Linden => Strings.Get(StringKey.BeekeeperBloomTheLinden, lang),
        BeekeeperBlooms.Goldenrod => Strings.Get(StringKey.BeekeeperBloomTheGoldenrod, lang),
        BeekeeperBlooms.Winter => Strings.Get(StringKey.BeekeeperBloomTheWinter, lang),
        _ => id,
    };

    /// <summary>Time left on the bloom line: whole hours rounded up, minutes under an hour ("9 h", "40 min").</summary>
    public static string BloomTimeLeft(decimal seconds)
    {
        string N(decimal v) => NumberFormatter.Format(v, Lang);
        decimal minutes = System.Math.Ceiling(System.Math.Max(1m, seconds) / 60m);
        if (minutes < 60m) return Fill(T(StringKey.BeekeeperTimeMinFmt), N(minutes));
        return Fill(T(StringKey.BeekeeperTimeHourFmt), N(System.Math.Ceiling(seconds / 3600m)));
    }

    /// <summary>The Garden card's line: "In bloom: linden · 9 h left", or "Winter · 5 h left".</summary>
    public static string BloomLine(BeekeeperBloomView b) =>
        b.Bloom == BeekeeperBlooms.Winter
            ? Fill(T(StringKey.BeekeeperBloomWinterLineFmt), BloomTimeLeft(b.SecondsLeft))
            : Fill(T(StringKey.BeekeeperBloomLineFmt), BloomName(b.Bloom), BloomTimeLeft(b.SecondsLeft));

    /// <summary>The bloom line's hover: what it favours (and whether the hive has it), then what blooms next.</summary>
    public static string BloomTip(BeekeeperBloomView b)
    {
        string N(decimal v) => NumberFormatter.Format(v, Lang);
        string first = (b.Bloom, b.HasFavoured) switch
        {
            (BeekeeperBlooms.Crocus, true) => T(StringKey.BeekeeperBloomTipCrocus),
            (BeekeeperBlooms.Crocus, false) => T(StringKey.BeekeeperBloomTipCrocusNone),
            (BeekeeperBlooms.Clover, true) => T(StringKey.BeekeeperBloomTipClover),
            (BeekeeperBlooms.Clover, false) => T(StringKey.BeekeeperBloomTipCloverNone),
            (BeekeeperBlooms.Linden, true) => Fill(T(StringKey.BeekeeperBloomTipLindenFmt), N(b.GuardingPercent)),
            (BeekeeperBlooms.Linden, false) => T(StringKey.BeekeeperBloomTipLindenNone),
            (BeekeeperBlooms.Goldenrod, true) => T(StringKey.BeekeeperBloomTipGoldenrod),
            (BeekeeperBlooms.Goldenrod, false) => T(StringKey.BeekeeperBloomTipGoldenrodNone),
            (BeekeeperBlooms.Winter, _) => Fill(T(StringKey.BeekeeperBloomTipWinterFmt), N(b.WinterPercent)),
            _ => "",
        };
        return first + "\n" + Fill(T(StringKey.BeekeeperBloomTipNextFmt), BloomName(b.Next));
    }

    /// <summary>The welcome-back line for the blooms that came out while away (Text = ids in order,
    /// joined by '|'; the last is out now).</summary>
    private static string WelcomeBackBloomsIn(string? text, AppLanguage lang)
    {
        var ids = (text ?? "").Split('|', System.StringSplitOptions.RemoveEmptyEntries);
        if (ids.Length == 0) return "";
        string now = ids[^1];
        if (ids.Length == 1)
            return now == BeekeeperBlooms.Winter
                ? Strings.Get(StringKey.BeekeeperLogWelcomeBackWinterOne, lang)
                : Fill(Strings.Get(StringKey.BeekeeperLogWelcomeBackBloomOneFmt, lang), TheBloomIn(now, lang));
        var passed = ids.Take(ids.Length - 1).ToList();
        var names = passed.Select(id => TheBloomIn(id, lang)).ToList();
        string list = names.Count == 1 ? names[0]
            : string.Join(", ", names.Take(names.Count - 1)) + Strings.Get(StringKey.BeekeeperListAnd, lang) + names[^1];
        if (now == BeekeeperBlooms.Winter)
            return Fill(Strings.Get(StringKey.BeekeeperLogWelcomeBackBloomsWinterFmt, lang), list);
        // "the goldenrod and winter bloomed" reads wrong, so a winter in the list "came and went".
        var key = passed.Contains(BeekeeperBlooms.Winter)
            ? StringKey.BeekeeperLogWelcomeBackSeasonsFmt : StringKey.BeekeeperLogWelcomeBackBloomsFmt;
        return Fill(Strings.Get(key, lang), list, TheBloomIn(now, lang));
    }

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
        // Stage 8 (spec 017)
        BeekeeperUpgrades.WoodenFrames => Strings.Get(StringKey.BeekeeperUpgradeWoodenFrames, lang),
        BeekeeperUpgrades.CandleMolds => Strings.Get(StringKey.BeekeeperUpgradeCandleMolds, lang),
        BeekeeperUpgrades.DippingRack => Strings.Get(StringKey.BeekeeperUpgradeDippingRack, lang),
        BeekeeperUpgrades.BeeHotel => Strings.Get(StringKey.BeekeeperUpgradeBeeHotel, lang),
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
            // Stage 10: Value = Beebits got, Value2 = honey given ("Bruno pays 5 Beebits for 10 honey.").
            BeekeeperEvents.Sale => e.Value2 <= 0m ? Fill(L(StringKey.BeekeeperLogSaleFmt), e.Text ?? "")
                : e.Value == 1m ? Fill(L(StringKey.BeekeeperLogTradeBearOneFmt), e.Text ?? "", N(e.Value2))
                : Fill(L(StringKey.BeekeeperLogTradeBearFmt), e.Text ?? "", N(e.Value), N(e.Value2)),
            // Before stage 10 (herbs): Fill(L(StringKey.BeekeeperLogTradeBearFmt), e.Text ?? "", N(e.Value2), N(e.Value)),
            BeekeeperEvents.PottedSale => Fill(L(StringKey.BeekeeperLogPottedSaleFmt), e.Text ?? "", N(e.Value), N(e.Value2)),
            BeekeeperEvents.HoneyPotted => L(StringKey.BeekeeperLogHoneyPotted),
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
            BeekeeperEvents.HippiesArrive => L(StringKey.BeekeeperLogHippiesArrive),
            // Stage 10: Value = clay jars got, Value2 = beeswax candles given.
            BeekeeperEvents.CandlesTraded => e.Value2 <= 0m
                ? Fill(L(StringKey.BeekeeperLogCandlesTradedFmt), N(e.Value))
                : e.Value == 1m ? Fill(L(StringKey.BeekeeperLogTradeHippiesOneFmt), N(e.Value2))   // "1 clay jar for 3 candles"
                : Fill(L(StringKey.BeekeeperLogTradeHippiesFmt), N(e.Value), N(e.Value2)),
            BeekeeperEvents.BeeswaxCrafted => Fill(L(StringKey.BeekeeperLogCraftedBeeswaxFmt), N(e.Value)),
            BeekeeperEvents.RepellentUnlocked => L(StringKey.BeekeeperLogRepellentUnlocked),
            BeekeeperEvents.UpgradeBought => e.Text switch
            {
                BeekeeperUpgrades.Notebook => L(StringKey.BeekeeperLogNotebookBought),
                BeekeeperUpgrades.ThirdBed => L(StringKey.BeekeeperLogThirdBedBought),
                BeekeeperUpgrades.PropolisSeal => L(StringKey.BeekeeperLogPropolisSealBought),
                BeekeeperUpgrades.WoodenFrames => L(StringKey.BeekeeperLogWoodenFramesBought),
                BeekeeperUpgrades.CandleMolds => L(StringKey.BeekeeperLogCandleMoldsBought),
                BeekeeperUpgrades.DippingRack => L(StringKey.BeekeeperLogDippingRackBought),
                BeekeeperUpgrades.BeeHotel => L(StringKey.BeekeeperLogBeeHotelBought),
                _ => Fill(L(StringKey.BeekeeperLogUpgradeBoughtFmt), UpgradeNameIn(e.Text ?? "", lang)),
            },
            BeekeeperEvents.WaspArrives => L(StringKey.BeekeeperLogWaspArrives),
            BeekeeperEvents.RepArrives => Fill(L(StringKey.BeekeeperLogRepArrivesFmt), Strings.Get(e.Text == "bear" ? StringKey.BeekeeperRepBear : StringKey.BeekeeperRepHippies, lang)),
            BeekeeperEvents.RepEngaged => Fill(L(StringKey.BeekeeperLogRepEngagedFmt), Strings.Get(e.Text == "bear" ? StringKey.BeekeeperRepBear : StringKey.BeekeeperRepHippies, lang)),
            BeekeeperEvents.RepLeft => Fill(L(StringKey.BeekeeperLogRepLeftFmt), Strings.Get(e.Text == "bear" ? StringKey.BeekeeperRepBear : StringKey.BeekeeperRepHippies, lang)),
            BeekeeperEvents.WaspEngaged => L(StringKey.BeekeeperLogWaspEngaged),
            BeekeeperEvents.GlovesOn => L(StringKey.BeekeeperLogGloves),
            BeekeeperEvents.GlovesGone => L(StringKey.BeekeeperLogGlovesGone),
            BeekeeperEvents.SmokerRepaired => L(StringKey.BeekeeperLogSmokerRepaired),
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
            // Bee Herbs: one line for the buff the herb rolled; Value is the number it quotes.
            BeekeeperEvents.HerbLit => e.Text switch
            {
                BeekeeperHerbs.BusyBees => Fill(L(StringKey.BeekeeperLogHerbBusyBeesFmt), N(e.Value)),
                BeekeeperHerbs.Wax => Fill(L(StringKey.BeekeeperLogHerbWaxFmt), N(e.Value)),
                BeekeeperHerbs.Trades => Fill(L(StringKey.BeekeeperLogHerbTradesFmt), N(e.Value)),
                BeekeeperHerbs.Wanderers => L(StringKey.BeekeeperLogHerbWanderers),
                BeekeeperHerbs.LingeringSmoke => Fill(L(StringKey.BeekeeperLogHerbLingeringSmokeFmt), N(e.Value)),
                BeekeeperHerbs.QuickFingers => Fill(L(StringKey.BeekeeperLogHerbQuickFingersFmt), N(e.Value), N(e.Value2)),
                BeekeeperHerbs.Dud => L(StringKey.BeekeeperLogHerbDud),
                _ => "",
            },
            BeekeeperEvents.HerbOut => L(StringKey.BeekeeperLogHerbOut),
            // Stage 8 (spec 017)
            BeekeeperEvents.SeedsGivenBatch => Fill(L(StringKey.BeekeeperLogSeedsGivenBatchFmt), N(e.Value)),
            BeekeeperEvents.SeedJoinsRoll => Fill(L(StringKey.BeekeeperLogSeedJoinsRollFmt), SeedName(e.Text ?? "", lang)),
            BeekeeperEvents.CarpenterBee => L(StringKey.BeekeeperLogCarpenterBee),
            BeekeeperEvents.MeadowBought => L(StringKey.BeekeeperLogMeadow),
            BeekeeperEvents.RareBeeArrives => Fill(L(StringKey.BeekeeperLogRareBeeArrivesFmt),
                BeeNameIn(BeekeeperEngine.ParseGiftText(e.Text).Bee, lang), GiftIn(e.Text, e.Value, lang)),
            BeekeeperEvents.HotelGift => Fill(L(StringKey.BeekeeperLogHotelGiftFmt),
                BeeNameIn(BeekeeperEngine.ParseGiftText(e.Text).Bee, lang), GiftIn(e.Text, e.Value, lang)),
            BeekeeperEvents.WelcomeBackWood => Fill(L(StringKey.BeekeeperLogWelcomeBackWoodFmt), N(e.Value)),
            // Value = seeds, Value2 = herbs, Text = propolis (an invariant number).
            BeekeeperEvents.WelcomeBackHotel => Fill(L(StringKey.BeekeeperLogWelcomeBackHotelFmt), GiftsIn(e.Value, e.Value2,
                decimal.TryParse(e.Text, System.Globalization.NumberStyles.Number, System.Globalization.CultureInfo.InvariantCulture, out var pr) ? pr : 0m, lang)),
            // Stage 9 (spec 018)
            BeekeeperEvents.CalendarStarted => L(StringKey.BeekeeperLogCalendarStarted),
            BeekeeperEvents.BloomChanged => e.Text switch
            {
                BeekeeperBlooms.Crocus => L(StringKey.BeekeeperLogBloomCrocus),
                BeekeeperBlooms.Clover => L(StringKey.BeekeeperLogBloomClover),
                BeekeeperBlooms.Linden => L(StringKey.BeekeeperLogBloomLinden),
                BeekeeperBlooms.Goldenrod => L(StringKey.BeekeeperLogBloomGoldenrod),
                BeekeeperBlooms.Winter => L(StringKey.BeekeeperLogBloomWinter),
                _ => "",
            },
            BeekeeperEvents.WelcomeBackBlooms => WelcomeBackBloomsIn(e.Text, lang),
            BeekeeperEvents.Crafted => e.Text switch
            {
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
