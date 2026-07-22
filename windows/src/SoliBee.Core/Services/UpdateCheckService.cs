using System;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Threading.Tasks;

namespace SoliBee.Core.Services;

public sealed record UpdateCheckOutcome(string LatestVersion, string ReleaseUrl, bool IsNewer);

// Manual-only: checks GitHub's latest release against the running app version. There is
// deliberately no automatic/background check and no auto-download/apply — this only ever
// runs when the player clicks "Check for Updates" in the About window, and the result is
// just a link to the release page for them to download and run the installer themselves.
public static class UpdateCheckService
{
    private const string Repo = "ohrealleah-lab/Honeycomb";

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

    // Always live. Throws on failure so the caller (About window) can show an inline error state.
    public static async Task<UpdateCheckOutcome> CheckNowAsync()
    {
        try
        {
            var response = await Http.GetAsync($"https://api.github.com/repos/{Repo}/releases/latest");
            if (!response.IsSuccessStatusCode)
                throw new InvalidOperationException("Unable to check for updates.");

            using var stream = await response.Content.ReadAsStreamAsync();
            using var doc = await JsonDocument.ParseAsync(stream);
            var root = doc.RootElement;
            if (!root.TryGetProperty("tag_name", out var tagProp) ||
                !root.TryGetProperty("html_url", out var urlProp))
            {
                throw new InvalidOperationException("Unable to check for updates.");
            }

            var tagName = tagProp.GetString() ?? "";
            var releaseUrl = urlProp.GetString() ?? "";
            if (tagName.Length == 0 || releaseUrl.Length == 0)
                throw new InvalidOperationException("Unable to check for updates.");

            return new UpdateCheckOutcome(tagName, releaseUrl, IsVersionNewer(tagName, CurrentVersion));
        }
        catch (InvalidOperationException)
        {
            throw;
        }
        catch
        {
            throw new InvalidOperationException("Unable to check for updates.");
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
