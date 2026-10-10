using System;
using System.IO;
using System.Linq;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

// Stats files are shared between game screens; a save from a stale in-memory copy must
// never undo progress another screen recorded since. Each test puts the real files back.
public class SharedStatsFileTests : IDisposable
{
    private static readonly string[] Files =
    {
        StatsService.StatsFilePath,
        Path.Combine(AppPaths.DataDirectory, "honeycomb_stats.json"),
    };
    private readonly string?[] _saved = Files.Select(f => File.Exists(f) ? File.ReadAllText(f) : null).ToArray();

    public void Dispose()
    {
        for (int i = 0; i < Files.Length; i++)
        {
            if (_saved[i] != null) File.WriteAllText(Files[i], _saved[i]);
            else if (File.Exists(Files[i])) File.Delete(Files[i]);
        }
    }

    private static int SpiderGamesPlayed() =>
        StatsService.LoadStats().SpiderStatsBySuit.Values.Sum(m => m.GamesPlayed);

    // Klondike used to write its launch-time copy of stats.json on every deal, erasing
    // Spider/Freecell games played since launch.
    [Fact]
    public void Klondike_Deal_Keeps_Spider_Progress_Made_Since_Launch()
    {
        var klondike = new GameViewModel();
        var spider = new SpiderViewModel();
        spider.InitializeGame();
        int spiderPlayed = SpiderGamesPlayed();
        Assert.True(spiderPlayed > 0);

        klondike.InitializeGame();

        Assert.Equal(spiderPlayed, SpiderGamesPlayed());
    }

    // Start Over (Manage Decks) writes the count straight to the file; the running
    // Honeycomb game must pick it up so its next save doesn't put the old count back.
    [Fact]
    public void Honeycomb_Start_Over_Count_Survives_The_Games_Next_Save()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        int before = HoneycombViewModel.LoadStats().TimesStartedOver;

        HoneycombViewModel.RecordStartOver();

        Assert.Equal(before + 1, vm.Stats.TimesStartedOver);
    }
}
