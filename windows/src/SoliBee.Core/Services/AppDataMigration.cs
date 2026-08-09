using System;
using System.IO;

namespace SoliBee.Core.Services;

// Central home for the app-data folder name. The product shipped as "SoliBee" before the
// Honeycomb rename, so every persistence path (settings, stats, decks, themes, custom art,
// last-mode) still pointed at %LocalAppData%\SoliBee\. EnsureMigrated() moves that folder to
// %LocalAppData%\Honeycomb\ once, on first launch after the rename, so existing users don't
// appear to lose their settings/stats/decks.
public static class AppDataMigration
{
    public const string FolderName = "Honeycomb";
    private const string LegacyFolderName = "SoliBee";

    public static void EnsureMigrated()
    {
        try
        {
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string legacyDir = Path.Combine(localAppData, LegacyFolderName);
            string newDir = Path.Combine(localAppData, FolderName);

            if (Directory.Exists(newDir) || !Directory.Exists(legacyDir)) return;

            try
            {
                Directory.Move(legacyDir, newDir);
            }
            catch
            {
                // Cross-volume or locked-file fallback — copy instead of move so a partial
                // failure still leaves the legacy data intact for next launch to retry.
                CopyDirectory(legacyDir, newDir);
            }
        }
        catch
        {
            // Never block app startup over migration — worst case, settings/stats reset.
        }
    }

    private static void CopyDirectory(string sourceDir, string destDir)
    {
        Directory.CreateDirectory(destDir);
        foreach (var file in Directory.GetFiles(sourceDir))
        {
            File.Copy(file, Path.Combine(destDir, Path.GetFileName(file)), overwrite: true);
        }
        foreach (var dir in Directory.GetDirectories(sourceDir))
        {
            CopyDirectory(dir, Path.Combine(destDir, Path.GetFileName(dir)));
        }
    }
}
