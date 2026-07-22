using System;
using System.IO;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Services;

public static class SoundService
{
    public static void PlayShuffle() => PlaySound("shuffle.wav");
    public static void PlaySnap() => PlaySound("snap.wav");
    public static void PlayVictory() => PlaySound("victory.wav");

    // Played specifically on a solitaire win (Klondike/Freecell/Spider) — Blackjack's
    // own win sound still uses PlayVictory().
    public static void PlaySolitaireWin() => PlaySound("tada.wav");

    private static void PlaySound(string filename)
    {
        var options = SettingsService.LoadOptions();
        if (!options.IsSoundEnabled) return;

#if WINDOWS
        try
        {
            var path = Path.Combine(AppContext.BaseDirectory, "Assets", filename);
            if (File.Exists(path))
                NativeMethods.PlaySoundFile(path);
        }
        catch { }
#else
        Console.WriteLine($"[SoundService] Playing: {filename}");
#endif
    }

#if WINDOWS
    private static class NativeMethods
    {
        [System.Runtime.InteropServices.DllImport("winmm.dll", SetLastError = true,
            CharSet = System.Runtime.InteropServices.CharSet.Auto)]
        private static extern bool PlaySound(string pszSound, IntPtr hmod, uint fdwSound);

        private const uint SND_FILENAME  = 0x00020000;
        private const uint SND_ASYNC     = 0x00000001;
        private const uint SND_NODEFAULT = 0x00000002;

        public static void PlaySoundFile(string path) =>
            PlaySound(path, IntPtr.Zero, SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
    }
#endif
}
