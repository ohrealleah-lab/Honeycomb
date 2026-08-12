using System;
using System.IO;

namespace SoliBee.Core.Services;

// No crash reporting existed anywhere in the app before this — an unhandled exception
// on the UI thread just took the whole process down with no trace left behind, so a
// crash during game-switching had no way to be diagnosed after the fact. This only logs;
// it doesn't (can't) stop the process from exiting once an exception is truly unhandled.
public static class CrashLogger
{
    private static readonly string LogPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        AppDataMigration.FolderName, "crash.log");

    public static void Install()
    {
        AppDomain.CurrentDomain.UnhandledException += (_, e) =>
            Log(e.ExceptionObject as Exception, "AppDomain.UnhandledException");

        System.Threading.Tasks.TaskScheduler.UnobservedTaskException += (_, e) =>
        {
            Log(e.Exception, "TaskScheduler.UnobservedTaskException");
            e.SetObserved();
        };
    }

    public static void Log(Exception? ex, string source)
    {
        try
        {
            var dir = Path.GetDirectoryName(LogPath);
            if (dir != null && !Directory.Exists(dir)) Directory.CreateDirectory(dir);
            File.AppendAllText(LogPath, $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {source}: {ex}\n\n");
        }
        catch
        {
            // Best-effort only — never let logging itself crash the app.
        }
    }
}
