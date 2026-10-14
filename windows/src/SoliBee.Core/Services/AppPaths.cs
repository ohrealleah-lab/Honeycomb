using System;
using System.IO;

namespace SoliBee.Core.Services;

// The one place that decides where the app keeps its data (%LocalAppData%\Honeycomb).
// Pure path math on purpose — it never creates the folder, because AppDataMigration
// only moves the legacy "SoliBee" folder when the new one doesn't exist yet, so
// anything that created it early would silently skip the migration. Every writer
// creates the folder itself (AtomicFile.WriteAllText does).
//
// The app ships through Velopack, not the Microsoft Store, so there is no packaged-app
// (Windows.Storage.ApplicationData) location to consider — this is the only location.
public static class AppPaths
{
    // HONEYCOMB_DATA_DIR, when set, replaces the folder wholesale. The test project sets it
    // to a temp folder before anything reads this, so tests can never touch real user data.
    public static string DataDirectory { get; } =
        Environment.GetEnvironmentVariable("HONEYCOMB_DATA_DIR") is { Length: > 0 } overridden
            ? overridden
            : Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                AppDataMigration.FolderName);
}
