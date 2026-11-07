using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

/// <summary>
/// Every word Beekeeper shows, in one place. English only for now; Phase 5 moves these into
/// the localization workbook (Strings.Get) without touching the screen code.
/// </summary>
internal static class BeekeeperText
{
    // ---- labels
    public const string Catch = "Catch Bee";
    public const string BeesLabel = "BEES";
    public const string HoneyLabel = "HONEY";
    public const string WaxLabel = "WAX";
    public const string BeebitsLabel = "BEEBITS";
    public const string HiveTitle = "THE HIVE";
    public const string BearTitle = "THE BEAR";
    public const string ShopTitle = "THE BEEKEEPER'S SHOP";
    public const string CombsTitle = "COMBS";
    public const string LogTitle = "THE GARDEN";
    public const string SellTen = "Sell 10";
    public const string SellAll = "Sell All";
    public const string Owned = "Owned";
    public const string StartOver = "Start over?";
    public const string StartOverBody = "Your hive and everything in it will be lost.";

    public static string Sting => "Ouch! A sting.";
    public static string Bees(int n) => n == 1 ? "+1 bee" : $"+{n} bees";

    public static string ToolLine(int level, int beesPerClick) =>
        (level switch { 1 => "Padded gloves", 2 => "Mesh net", 3 => "Bee-safe vacuum", _ => "Bare hands" })
        + " · " + (beesPerClick == 1 ? "1 bee" : beesPerClick + " bees");

    public static string ToolName(string id) => id switch
    {
        "gloves" => "Padded Gloves",
        "net" => "Mesh Net",
        "vacuum" => "Bee-Safe Vacuum",
        _ => id,
    };

    public static string ToolBlurb(string id, int bees) => bees + " bees per click";

    public static string HoneyPerSecond(string n) => n + " honey / sec";
    public static string NextWax(string progress, string needed) => $"Next wax: {progress}/{needed}";
    public static string CombsFull => "The combs are full";
    public static string BearLine(string name, long trades) => trades == 0 ? name : $"{name} · Trades: {trades}";
    public static string SellTenHint => "10 honey = 1 Beebit";
    public static string WaxCatcherName => "Wax-Catcher";
    public static string WaxCatcherBlurb => "Twice the wax";
    public static string CombsBuilt(int n) => n == 1 ? "COMBS · 1 built" : $"COMBS · {n} built";
    public static string BuildComb(string waxCost) => $"Build a comb · {waxCost} wax";
    public static string CombBlurb(string storageAdded) => $"+{storageAdded} honey storage";

    // ---- story log
    public static string LogLine(BeekeeperLogEntry e, AppLanguage lang)
    {
        string N(decimal v) => NumberFormatter.Format(v, lang);
        return e.Key switch
        {
            BeekeeperEvents.NewGame => "The garden hums. Your bees are frolicking.",
            BeekeeperEvents.FirstBee => "You cup a bee in your hands. It tickles.",
            BeekeeperEvents.Sting => "Ouch! A sting. No bee this time.",
            BeekeeperEvents.StorageFull => "The combs are full of honey.",
            BeekeeperEvents.BearArrives => $"A bear wanders over. He says his name is {e.Text}.",
            BeekeeperEvents.Sale => $"{e.Text} counts it out.",
            BeekeeperEvents.FirstWax => "Wax drops, pale as moonlight.",
            BeekeeperEvents.ShopOpened => "The Beekeeper's shop opens.",
            BeekeeperEvents.ToolBought => e.Text switch
            {
                "gloves" => "Padded gloves on. Much braver.",
                "net" => "A mesh net. Sweeping, not chasing.",
                "vacuum" => "The vacuum hums. The bees seem to like it.",
                _ => "A new tool.",
            },
            BeekeeperEvents.WaxCatcherBought => "The brass catcher gleams. Wax comes twice as fast.",
            BeekeeperEvents.CombsAvailable => "There is wax enough for a new comb.",
            BeekeeperEvents.CombBuilt => $"A new comb. Room for {N(e.Value)} more honey.",
            BeekeeperEvents.WelcomeBack => $"While you were away, the bees made {N(e.Value)} honey.",
            BeekeeperEvents.WelcomeBackNothing => "The bees are glad you're back.",
            _ => "",
        };
    }
}
