using System;
using System.Reflection;
using System.Threading.Tasks;
using Velopack;
using Velopack.Sources;

namespace SoliBee.Core.Services;

public sealed record UpdateCheckOutcome(UpdateInfo? UpdateInfo, bool IsNewer);

// Manual-only: checks GitHub's latest release against the running app version. There is
// deliberately no automatic/background check and no auto-download/apply — this only ever
// runs when the player clicks "Check for Updates" in the About window, and the result is
// just a link to the release page for them to download and run the installer themselves.
public static class UpdateCheckService
{
    private const string RepoUrl = "https://github.com/ohrealleah-lab/Honeycomb";
    private static UpdateManager? _updateManager;

    public static string CurrentVersion =>
        Assembly.GetExecutingAssembly()
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
        ?? Assembly.GetExecutingAssembly().GetName().Version?.ToString()
        ?? "0.0.0.0";

    private static UpdateManager GetUpdateManager()
    {
        if (_updateManager == null)
        {
            _updateManager = new UpdateManager(new GithubSource(RepoUrl, null, false));
        }
        return _updateManager;
    }

    // Always live. Throws on failure so the caller (About window) can show an inline error state.
    public static async Task<UpdateCheckOutcome> CheckNowAsync()
    {
        try
        {
            var mgr = GetUpdateManager();
            var updateInfo = await mgr.CheckForUpdatesAsync();
            return new UpdateCheckOutcome(updateInfo, updateInfo != null);
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException("Unable to check for updates.", ex);
        }
    }

    public static async Task DownloadAndApplyUpdatesAsync(UpdateInfo updateInfo, Action<int> progress)
    {
        try
        {
            var mgr = GetUpdateManager();
            await mgr.DownloadUpdatesAsync(updateInfo, progress);
            mgr.ApplyUpdatesAndRestart(updateInfo);
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException("Unable to download or apply updates.", ex);
        }
    }
}
