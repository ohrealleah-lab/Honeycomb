using System;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Threading.Tasks;
using SoliBee.Core.Models;

namespace SoliBee.Core.Services;

public sealed record UpdateCheckOutcome(string LatestVersion, string ReleaseUrl, bool IsNewer);

// Checks GitHub Releases for a newer Honeycomb build. Two entry points:
// CheckIfDueAsync (launch-time, respects the 30-day cadence and the disabled flag)
// and CheckNowAsync (the About window's manual "Check for Updates" button, which
// always hits the network live regardless of either). Both funnel through the
// same fetch/compare logic; only how the result is surfaced differs.
public static class UpdateCheckService
{
    private const string Repo = "ohrealleah-lab/Honeycomb";
    private const double CheckIntervalDays = 30;

    private static readonly HttpClient Http = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };

    static UpdateCheckService()
    {
        Http.DefaultRequestHeaders.UserAgent.ParseAdd("Honeycomb-App");
    }

    public static string CurrentVersion =>
        Assembly.GetExecutingAssembly()
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
        ?? Assembly.GetExecutingAssembly().GetName().Version?.ToString(3)
        ?? "0.0.0";

    // Automatic launch-time check: resets a stale "disabled" flag if a newer version
    // has since been installed, then — if not disabled and the 30-day cadence is due —
    // checks live. Returns null when no prompt is warranted (disabled, not due, no
    // newer version, or the check failed — offline handling is deliberately silent
    // here so a launch never surfaces a network error to the user).
    public static async Task<UpdateCheckOutcome?> CheckIfDueAsync()
    {
        var options = SettingsService.LoadOptions();
        ResetDisabledFlagIfNewerVersionInstalled(options);

        if (options.UpdateChecksDisabled) return null;

        if (options.LastUpdateCheckUtc is DateTime last &&
            (DateTime.UtcNow - last).TotalDays < CheckIntervalDays)
        {
            return null;
        }

        var outcome = await FetchLatestReleaseAsync();
        if (outcome == null) return null; // offline/failed — stay silent, retry next launch

        options.LastUpdateCheckUtc = DateTime.UtcNow;
        SettingsService.SaveOptions(options);

        return outcome.IsNewer ? outcome : null;
    }

    // Manual "Check for Updates" button: always live, ignores both the cadence and
    // the disabled flag since it's an explicit user action. Throws on failure so the
    // caller (About window) can show an inline error state.
    public static async Task<UpdateCheckOutcome> CheckNowAsync()
    {
        var outcome = await FetchLatestReleaseAsync()
            ?? throw new InvalidOperationException("Unable to reach GitHub to check for updates.");

        var options = SettingsService.LoadOptions();
        options.LastUpdateCheckUtc = DateTime.UtcNow;
        SettingsService.SaveOptions(options);

        return outcome;
    }

    // "Don't Ask Again" from either the automatic prompt or the About window.
    public static void DeclineUpdate()
    {
        var options = SettingsService.LoadOptions();
        options.UpdateChecksDisabled = true;
        options.UpdateChecksDisabledAtVersion = CurrentVersion;
        SettingsService.SaveOptions(options);
    }

    private static void ResetDisabledFlagIfNewerVersionInstalled(GameOptions options)
    {
        if (!options.UpdateChecksDisabled || options.UpdateChecksDisabledAtVersion == null) return;
        if (IsVersionNewer(CurrentVersion, options.UpdateChecksDisabledAtVersion))
        {
            options.UpdateChecksDisabled = false;
            options.UpdateChecksDisabledAtVersion = null;
            SettingsService.SaveOptions(options);
        }
    }

    private static async Task<UpdateCheckOutcome?> FetchLatestReleaseAsync()
    {
        try
        {
            var response = await Http.GetAsync($"https://api.github.com/repos/{Repo}/releases/latest");
            if (!response.IsSuccessStatusCode) return null;

            using var stream = await response.Content.ReadAsStreamAsync();
            using var doc = await JsonDocument.ParseAsync(stream);
            var root = doc.RootElement;
            if (!root.TryGetProperty("tag_name", out var tagProp) ||
                !root.TryGetProperty("html_url", out var urlProp))
            {
                return null;
            }

            var tagName = tagProp.GetString() ?? "";
            var releaseUrl = urlProp.GetString() ?? "";
            if (tagName.Length == 0 || releaseUrl.Length == 0) return null;

            return new UpdateCheckOutcome(tagName, releaseUrl, IsVersionNewer(tagName, CurrentVersion));
        }
        catch
        {
            return null;
        }
    }

    // Compares dot-separated numeric version strings component by component
    // (e.g. "0.9.10" > "0.9.6"), tolerant of a leading "v"/"V" and missing
    // trailing components (shorter strings are padded with 0s).
    internal static bool IsVersionNewer(string candidate, string baseline)
    {
        static int[] Components(string s)
        {
            s = s.TrimStart('v', 'V');
            var parts = s.Split('.');
            var result = new int[parts.Length];
            for (int i = 0; i < parts.Length; i++)
                result[i] = int.TryParse(parts[i], out var n) ? n : 0;
            return result;
        }

        var a = Components(candidate);
        var b = Components(baseline);
        int max = Math.Max(a.Length, b.Length);
        for (int i = 0; i < max; i++)
        {
            int av = i < a.Length ? a[i] : 0;
            int bv = i < b.Length ? b[i] : 0;
            if (av != bv) return av > bv;
        }
        return false;
    }
}
