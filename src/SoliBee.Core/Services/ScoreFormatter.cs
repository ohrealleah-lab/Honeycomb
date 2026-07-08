using System;

namespace SoliBee.Core.Services;

public static class ScoreFormatter
{
    // Vegas scoring stores score in cents (e.g. buy-ins/payouts are multiples of 100),
    // so this formats it as a dollar amount; standard scoring just shows the raw number.
    public static string FormatScore(int score, bool isVegasScoring)
    {
        if (!isVegasScoring) return score.ToString();

        int dollars = score / 100;
        int abs     = Math.Abs(dollars);
        return dollars < 0 ? $"-${abs}.00" : $"${abs}.00";
    }
}
