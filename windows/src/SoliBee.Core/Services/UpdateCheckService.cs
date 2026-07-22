using System;
using System.Reflection;
using System.Threading.Tasks;
using SoliBee.Core.Models;
using Velopack;
using Velopack.Sources;

namespace SoliBee.Core.Services;

// ReleaseUrl still points at the GitHub release page (for a player who wants to read the
// changelog before updating) even though the actual update no longer needs a browser at
// all — InstallUpdateAsync downloads and applies it directly via Velopack.
public sealed record UpdateCheckOutcome(string LatestVersion, string ReleaseUrl, bool IsNewer);

// Checks Velopack's GitHub-hosted release feed for a newer Honeycomb build, and can
// download + apply it directly (no browser hand-off). Two check entry points:
// CheckIfDueAsync (launch-time, respects the 30-day cadence and the disabled flag) and
// CheckNowAsync (the About window's manual "Check for Updates" button, which always hits
// the network live regardless of either). Both funnel through the same fetch/compare
// logic; only how the result is surfaced differs.
public static class UpdateCheckService
{
    private const string Repo = "ohrealleah-lab/Honeycomb";
    private const double CheckIntervalDays = 30;

    private static readonly UpdateManager Manager =
        new(new GithubSource($"https://github.com/{Repo}", null, false));

    // Stashed from the most recent successful check so InstallUpdateAsync doesn't need to
    // re-fetch — Velopack's actual download/apply calls need the full UpdateInfo object,
    // not just the version string UpdateCheckOutcome exposes to callers.
    private static UpdateInfo? _pendingUpdate;

    public static string CurrentVersion =>
        Assembly.GetExecutingAssembly()
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
        ?? Assembly.GetExecutingAssembly().GetName().Version?.ToString(3)
        ?? "0.0.0";

    // Automatic launch-time check: resets a stale "disabled" flag if a newer version
    // has since been installed, then — if not disabled and the 30-day cadence is due —
    // checks live. Returns null when no prompt is warranted (disabled, not due, no
    // newer version, not a real Velopack install, or the check failed — offline handling
    // is deliberately silent here so a launch never surfaces a network error to the user).
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
        if (outcome == null) return null; // offline/failed/not installed — stay silent, retry next launch

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
            ?? throw new InvalidOperationException("Unable to check for updates.");

        var options = SettingsService.LoadOptions();
        options.LastUpdateCheckUtc = DateTime.UtcNow;
        SettingsService.SaveOptions(options);

        return outcome;
    }

    // Downloads and applies the update found by the most recent CheckIfDueAsync/CheckNowAsync
    // call, then restarts the app into the new version. Throws if there's no pending update
    // to install (i.e. called without a preceding successful newer-version check).
    public static async Task InstallUpdateAsync()
    {
        var info = _pendingUpdate
            ?? throw new InvalidOperationException("No update is pending — check for updates first.");
        await Manager.DownloadUpdatesAsync(info);
        Manager.ApplyUpdatesAndRestart(info);
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
        // Not a real Velopack install (e.g. a local dev/debug run) — there's nothing to
        // update in place, so don't even attempt the network call.
        if (!Manager.IsInstalled) return null;

        try
        {
            var info = await Manager.CheckForUpdatesAsync();
            _pendingUpdate = info;
            if (info == null) return null;

            var latestVersion = info.TargetFullRelease.Version.ToString();
            var releaseUrl = $"https://github.com/{Repo}/releases/tag/{latestVersion}";
            return new UpdateCheckOutcome(latestVersion, releaseUrl, IsVersionNewer(latestVersion, CurrentVersion));
        }
        catch
        {
            _pendingUpdate = null;
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
