using System;
using System.Globalization;
using System.Text;
using SoliBee.Core.Localization;

namespace SoliBee.Core.Services;

/// <summary>
/// Short, language-aware text for big numbers (spec FR-011): 1.2K, 3.4M, 1.2B, 1T, then
/// scientific (1.23e15) for anything bigger. Always rounds DOWN, so a number never reads
/// higher than it is (999,999 is "999.9K", never "1000K"). English uses a dot as the
/// decimal mark and Spanish a comma; Spanish names 10^9 "mM" (mil millones) and 10^12 "B"
/// (billón) so the suffixes don't mean something different to a Spanish reader.
/// </summary>
public static class NumberFormatter
{
    private static readonly string[] EnglishSuffixes = { "", "K", "M", "B", "T" };
    private static readonly string[] SpanishSuffixes = { "", "K", "M", "mM", "B" };

    /// <param name="decimalsBelowThousand">How many decimals to show for values under 1,000
    /// (0 for counts like honey and bees, 2 for rates like honey per second). Trailing zeros are dropped.</param>
    public static string Format(decimal value, AppLanguage language, int decimalsBelowThousand = 0)
    {
        if (value < 0m) return "-" + Format(-value, language, decimalsBelowThousand);

        string text;
        if (value < 1000m)
        {
            text = FloorTo(value, decimalsBelowThousand).ToString(Pattern(decimalsBelowThousand), CultureInfo.InvariantCulture);
        }
        else if (value < 1_000_000_000_000_000m) // below 10^15
        {
            var suffixes = language == AppLanguage.Spanish ? SpanishSuffixes : EnglishSuffixes;
            int group = 1;
            decimal divisor = 1000m;
            while (group < suffixes.Length - 1 && value >= divisor * 1000m)
            {
                divisor *= 1000m;
                group++;
            }
            text = FloorTo(value / divisor, 1).ToString("0.#", CultureInfo.InvariantCulture) + suffixes[group];
        }
        else
        {
            text = Scientific(value);
        }

        return language == AppLanguage.Spanish ? text.Replace('.', ',') : text;
    }

    private static string Scientific(decimal value)
    {
        int exponent = 0;
        decimal scaled = value;
        while (scaled >= 10m)
        {
            scaled /= 10m;
            exponent++;
        }
        var sb = new StringBuilder();
        sb.Append(FloorTo(scaled, 2).ToString("0.##", CultureInfo.InvariantCulture));
        sb.Append('e').Append(exponent.ToString(CultureInfo.InvariantCulture));
        return sb.ToString();
    }

    private static decimal FloorTo(decimal value, int decimals)
    {
        if (decimals <= 0) return Math.Floor(value);
        decimal factor = 1m;
        for (int i = 0; i < decimals; i++) factor *= 10m;
        return Math.Floor(value * factor) / factor;
    }

    private static string Pattern(int decimals) => decimals <= 0 ? "0" : "0." + new string('#', decimals);
}
