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
    public static string Bees(int n) =>
        n == 1 ? T(StringKey.BeekeeperPlusOneBee) : Fill(T(StringKey.BeekeeperPlusBeesFmt), n.ToString());

    public static string ToolLine(int level, int beesPerClick) =>
        T(level switch
        {
            1 => StringKey.BeekeeperToolGloves,
            2 => StringKey.BeekeeperToolNet,
            3 => StringKey.BeekeeperToolVacuum,
            _ => StringKey.BeekeeperToolBareHands,
        })
        + " · " + (beesPerClick == 1 ? T(StringKey.BeekeeperOneBee) : Fill(T(StringKey.BeekeeperBeesFmt), beesPerClick.ToString()));

    public static string ToolName(string id) => id switch
    {
        "gloves" => T(StringKey.BeekeeperShopGloves),
        "net" => T(StringKey.BeekeeperShopNet),
        "vacuum" => T(StringKey.BeekeeperShopVacuum),
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
    public static string CombsBuilt(int n) =>
        n == 1 ? T(StringKey.BeekeeperCombsBuiltOne) : Fill(T(StringKey.BeekeeperCombsBuiltFmt), n.ToString());
    public static string BuildComb(string waxCost) => Fill(T(StringKey.BeekeeperBuildCombFmt), waxCost);
    public static string CombBlurb(string storageAdded) => Fill(T(StringKey.BeekeeperCombBlurbFmt), storageAdded);

    // ---- story log (saved as keys plus values, so old lines follow a language change)
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
                _ => StringKey.BeekeeperLogNewTool,
            }),
            BeekeeperEvents.WaxCatcherBought => L(StringKey.BeekeeperLogWaxCatcher),
            BeekeeperEvents.CombsAvailable => L(StringKey.BeekeeperLogCombsAvailable),
            BeekeeperEvents.CombBuilt => Fill(L(StringKey.BeekeeperLogCombBuiltFmt), N(e.Value)),
            BeekeeperEvents.WelcomeBack => Fill(L(StringKey.BeekeeperLogWelcomeBackFmt), N(e.Value)),
            BeekeeperEvents.WelcomeBackNothing => L(StringKey.BeekeeperLogWelcomeBackNothing),
            _ => "",
        };
    }
}
