using SoliBee.Core.Localization;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Core;

public class NumberFormatterTests
{
    [Theory]
    [InlineData("0", 0)]
    [InlineData("7", 7)]
    [InlineData("999", 999)]
    [InlineData("999", 999.99)]
    [InlineData("1K", 1000)]
    [InlineData("1.2K", 1234)]
    [InlineData("1.9K", 1999)]            // rounds down, never up
    [InlineData("12.3K", 12345)]
    [InlineData("999.9K", 999999)]        // never "1000K"
    [InlineData("1M", 1_000_000)]
    [InlineData("3.4M", 3_400_000)]
    [InlineData("1.2B", 1_200_000_000)]
    [InlineData("1T", 1_000_000_000_000)]
    [InlineData("999.9T", 999_999_999_999_999)]
    public void English_ShortensBigNumbers(string expected, double value)
        => Assert.Equal(expected, NumberFormatter.Format((decimal)value, AppLanguage.English));

    [Theory]
    [InlineData("1,2K", 1234)]
    [InlineData("3,4M", 3_400_000)]
    [InlineData("1,2mM", 1_200_000_000)]  // mil millones
    [InlineData("1B", 1_000_000_000_000)] // billón
    public void Spanish_UsesCommasAndItsOwnSuffixes(string expected, double value)
        => Assert.Equal(expected, NumberFormatter.Format((decimal)value, AppLanguage.Spanish));

    [Theory]
    [InlineData("1e15", 1e15)]
    [InlineData("1.23e15", 1.234e15)]
    [InlineData("9.99e20", 9.999e20)]
    public void Huge_GoesScientific(string expected, double value)
        => Assert.Equal(expected, NumberFormatter.Format((decimal)value, AppLanguage.English));

    [Fact]
    public void Spanish_ScientificUsesAComma()
        => Assert.Equal("1,23e15", NumberFormatter.Format(1.234e15m, AppLanguage.Spanish));

    [Fact]
    public void LargestDecimal_DoesNotCrash()
        => Assert.StartsWith("7.92e28", NumberFormatter.Format(decimal.MaxValue, AppLanguage.English));

    [Theory]
    [InlineData("0.12", 0.12)]
    [InlineData("2.5", 2.5)]
    [InlineData("2", 2)]
    [InlineData("0.99", 0.999)]           // rounds down
    public void Rates_ShowTwoDecimals_DroppingTrailingZeros(string expected, double value)
        => Assert.Equal(expected, NumberFormatter.Format((decimal)value, AppLanguage.English, decimalsBelowThousand: 2));

    [Fact]
    public void Rates_UseACommaInSpanish()
        => Assert.Equal("0,12", NumberFormatter.Format(0.12m, AppLanguage.Spanish, 2));

    [Fact]
    public void Negatives_KeepTheirSign()
        => Assert.Equal("-1.5K", NumberFormatter.Format(-1500m, AppLanguage.English));
}
