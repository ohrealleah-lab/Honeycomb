using System;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Services;

public static class SoundService
{
    public static void PlayShuffle() => PlaySound("shuffle.wav");
    public static void PlaySnap() => PlaySound("snap.wav");
    public static void PlayVictory() => PlaySound("victory.wav");

    private static void PlaySound(string filename)
    {
        var options = SettingsService.LoadOptions();
        if (!options.IsSoundEnabled) return;

#if WINDOWS
        try
        {
            var uri = new Uri($"ms-appx:///Assets/{filename}");
            var player = new Windows.Media.Playback.MediaPlayer();
            player.Source = Windows.Media.Core.MediaSource.CreateFromUri(uri);
            player.Play();
        }
        catch
        {
            // Ignore playback exceptions
        }
#else
        // Mock sound playback on non-Windows platforms
        Console.WriteLine($"[SoundService] Playing: {filename}");
#endif
    }
}
