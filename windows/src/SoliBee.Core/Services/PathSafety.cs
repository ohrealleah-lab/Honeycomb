using System.IO;

namespace SoliBee.Core.Services;

// Custom card-back/face-art filenames are stored in JSON config files
// (settings.json, FaceCardArt/config.json, themes.json) and later combined into
// filesystem paths for loading and deletion. The app's own upload flow always
// generates safe GUID-based filenames, but if one of those config files were ever
// tampered with, an unvalidated value (an absolute path, or one containing "..")
// could let a load/delete operation escape the app's own data directory. Call
// IsSafeFileName before combining any such value into a path.
public static class PathSafety
{
    public static bool IsSafeFileName(string? name)
    {
        if (string.IsNullOrEmpty(name)) return false;
        if (Path.IsPathRooted(name)) return false;
        if (name.Contains("..")) return false;
        if (name.IndexOfAny(new[] { '/', '\\' }) >= 0) return false;
        return true;
    }
}
