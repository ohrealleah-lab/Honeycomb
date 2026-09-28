using System;
using System.IO;

namespace SoliBee.Core.Services;

// Write-then-replace for every persisted file (stats, card bank, decks, seed, options,
// themes). A plain File.WriteAllText truncates the target first, so a crash, kill or
// power loss mid-write left a half-written file — which the loaders then failed to
// parse and silently replaced with defaults on the next save, wiping e.g. every game's
// stats (stats.json holds all of them) or the Honeycomb card collection. The temp name
// is per-call, so two overlapping saves can't collide. Same pattern SettingsService
// already used for settings.json.
public static class AtomicFile
{
    public static void WriteAllText(string path, string contents)
    {
        var directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
        var tempPath = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            File.WriteAllText(tempPath, contents);
            File.Move(tempPath, path, overwrite: true);
        }
        finally
        {
            if (File.Exists(tempPath)) File.Delete(tempPath);
        }
    }
}
