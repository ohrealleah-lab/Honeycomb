using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using Xunit;

namespace SoliBee.Tests.Services;

// The small services that sit under the games: score text, the first-played date behind the
// one-year banner, the crash log, old-save migrations, face-card art slots and files, and the
// SoliBee → Honeycomb data-folder move. Everything writes to the throwaway data folder.
public class SmallServicesTests : DataSandbox
{
    // ---- Score text ----

    [Theory]
    [InlineData(0, false, "0")]
    [InlineData(1234, false, "1234")]
    [InlineData(-15, false, "-15")]
    [InlineData(0, true, "$0.00")]
    [InlineData(500, true, "$5.00")]
    [InlineData(-5200, true, "-$52.00")]
    [InlineData(-4700, true, "-$47.00")]
    [InlineData(12300, true, "$123.00")]
    public void ScoreFormatter_ShowsPlainNumbers_OrDollarsInVegas(int score, bool vegas, string expected) =>
        Assert.Equal(expected, ScoreFormatter.FormatScore(score, vegas));

    // ---- The first-played date (one-year banner) ----

    private static void WriteFirstPlayed(DateTime utc, bool shown) =>
        Write("first_played.json", $"{{\"FirstPlayedUtc\":\"{utc:O}\",\"HasShownOneYearBanner\":{(shown ? "true" : "false")}}}");

    [Fact]
    public void FirstPlayed_AnchorsNow_WhenThereIsNoFile_AndIsntAYearYet()
    {
        Delete("first_played.json");
        Assert.False(FirstPlayedTracker.ShouldShowOneYearBanner());
        Assert.True(File.Exists(Path.Combine(AppPaths.DataDirectory, "first_played.json")));
        Assert.False(FirstPlayedTracker.ShouldShowOneYearBanner());   // the anchor survives
    }

    [Fact]
    public void FirstPlayed_ShowsTheYearBannerOnce_AfterAYear()
    {
        WriteFirstPlayed(DateTime.UtcNow.AddDays(-400), shown: false);
        Assert.True(FirstPlayedTracker.ShouldShowOneYearBanner());
        Assert.False(FirstPlayedTracker.ShouldShowOneYearBanner());   // never again
        Assert.Contains("true", Read("first_played.json").ToLowerInvariant());
    }

    [Fact]
    public void FirstPlayed_NotYetAYear_ShowsNothing_AndAlreadyShownStaysShown()
    {
        WriteFirstPlayed(DateTime.UtcNow.AddDays(-300), shown: false);
        Assert.False(FirstPlayedTracker.ShouldShowOneYearBanner());
        WriteFirstPlayed(DateTime.UtcNow.AddDays(-900), shown: true);
        Assert.False(FirstPlayedTracker.ShouldShowOneYearBanner());
    }

    [Fact]
    public void FirstPlayed_DamagedFile_StartsAFreshAnchor()
    {
        Write("first_played.json", "not json");
        Assert.False(FirstPlayedTracker.ShouldShowOneYearBanner());
        Assert.False(FirstPlayedTracker.ShouldShowOneYearBanner());
    }

    // ---- The crash log ----

    [Fact]
    public void CrashLog_AppendsEntriesWithTheSourceAndTheError()
    {
        Delete("crash.log");
        CrashLogger.Log(new InvalidOperationException("first problem"), "TestSourceOne");
        CrashLogger.Log(null, "TestSourceTwo");
        var log = File.ReadAllText(Path.Combine(AppPaths.DataDirectory, "crash.log"));
        Assert.Contains("TestSourceOne", log);
        Assert.Contains("first problem", log);
        Assert.Contains("TestSourceTwo", log);
        Assert.True(log.IndexOf("TestSourceOne") < log.IndexOf("TestSourceTwo"));   // appended, not overwritten
    }

    // ---- Old stats files ----

    [Fact]
    public void LoadStats_DamagedOrMissing_GivesFreshStats()
    {
        Write("stats.json", "garbage");
        var s = StatsService.LoadStats();
        Assert.Equal(0, s.GamesPlayed);
        Delete("stats.json");
        Assert.Equal(0, StatsService.LoadStats().GamesWon);
    }

    [Fact]
    public void FreecellVegasStats_AreFoldedIntoTheStandardBucket()
    {
        var stats = new GameStatistics();
        stats.FreecellStatsByMode["vegas_1deck"] = new ModeStats
        {
            GamesPlayed = 4, GamesWon = 2, LongestStreak = 5, HighScore = 900, TotalWinSeconds = 300, ShortestWinSeconds = 60,
        };
        stats.FreecellStatsByMode["standard_1deck"] = new ModeStats
        {
            GamesPlayed = 10, GamesWon = 6, LongestStreak = 3, HighScore = 1200, TotalWinSeconds = 700, ShortestWinSeconds = 90,
        };
        stats.FreecellStatsByMode["vegas_2deck"] = new ModeStats { GamesPlayed = 1, GamesWon = 1, ShortestWinSeconds = 200 };

        StatsService.MigrateFreecellVegasStats(stats);

        Assert.DoesNotContain("vegas_1deck", stats.FreecellStatsByMode.Keys);
        Assert.DoesNotContain("vegas_2deck", stats.FreecellStatsByMode.Keys);
        var one = stats.FreecellStatsByMode["standard_1deck"];
        Assert.Equal(14, one.GamesPlayed);
        Assert.Equal(8, one.GamesWon);
        Assert.Equal(5, one.LongestStreak);                // the better of the two
        Assert.Equal(1200, one.HighScore);                 // the better of the two
        Assert.Equal(1000, one.TotalWinSeconds);
        Assert.Equal(60, one.ShortestWinSeconds);          // the faster of the two
        var two = stats.FreecellStatsByMode["standard_2deck"];   // created when there was none
        Assert.Equal(1, two.GamesWon);
        Assert.Equal(200, two.ShortestWinSeconds);
    }

    [Fact]
    public void FreecellVegasStats_MigrationIsHarmlessWhenThereIsNothingToMigrate()
    {
        var stats = new GameStatistics();
        stats.FreecellStatsByMode["standard_1deck"] = new ModeStats { GamesWon = 3 };
        StatsService.MigrateFreecellVegasStats(stats);
        Assert.Equal(3, stats.FreecellStatsByMode["standard_1deck"].GamesWon);
        Assert.Single(stats.FreecellStatsByMode);
    }

    [Fact]
    public void TimedGamesWon_IsSeededFromGamesWon_ForOldSaves_AndOnlyOnce()
    {
        var s = new GameStatistics { GamesWon = 4, TotalWinSeconds = 400, TimedGamesWon = 0 };
        s.SpiderStatsBySuit["standard_1suit"] = new ModeStats { GamesWon = 2, TotalWinSeconds = 100 };
        StatsService.MigrateTimedGamesWon(s);
        Assert.Equal(4, s.TimedGamesWon);
        Assert.Equal(2, s.SpiderStatsBySuit["standard_1suit"].TimedGamesWon);
        s.GamesWon = 9;
        StatsService.MigrateTimedGamesWon(s);
        Assert.Equal(4, s.TimedGamesWon);   // already seeded
    }

    [Fact]
    public void KlondikeSaves_NeverOverwriteFreecellOrSpiderProgress()
    {
        Delete("stats.json");
        var klondike = StatsService.LoadStats();            // a launch-time copy…
        var other = StatsService.LoadStats();               // …while Freecell and Spider keep playing
        other.FreecellStatsByMode["standard_1deck"] = new ModeStats { GamesWon = 7 };
        other.SpiderStatsBySuit["standard_2suit"] = new ModeStats { GamesWon = 3 };
        StatsService.SaveStats(other);

        klondike.GamesWon = 5;
        StatsService.SaveKlondikeStats(klondike);

        var saved = StatsService.LoadStats();
        Assert.Equal(5, saved.GamesWon);
        Assert.Equal(7, saved.FreecellStatsByMode["standard_1deck"].GamesWon);
        Assert.Equal(3, saved.SpiderStatsBySuit["standard_2suit"].GamesWon);
        Assert.Equal(7, klondike.FreecellStatsByMode["standard_1deck"].GamesWon);   // the caller's copy catches up too
    }

    // ---- Face-card art slots ----

    [Fact]
    public void EverySlot_HasARank_ASuit_AColour_AndAName()
    {
        foreach (var slot in Enum.GetValues<FaceCardSlot>())
        {
            Assert.Contains(slot.GetRank(), new[] { 1, 11, 12, 13 });
            Assert.Contains(slot.GetRankLabel(), new[] { "A", "J", "Q", "K" });
            Assert.Contains(slot.GetSuitSymbol(), new[] { "♠", "♥", "♦", "♣" });
            Assert.False(string.IsNullOrWhiteSpace(slot.GetDisplayName()));
            Assert.Equal(slot.GetSuitSymbol() is "♥" or "♦", slot.GetIsRed());
        }
        Assert.Equal(16, Enum.GetValues<FaceCardSlot>().Length);
        Assert.Equal(16, Enum.GetValues<FaceCardSlot>().Select(s => s.GetDisplayName()).Distinct().Count());
    }

    [Fact]
    public void SlotFor_FindsTheSlotOfEveryAceAndFaceCard_AndNothingElse()
    {
        foreach (var slot in Enum.GetValues<FaceCardSlot>())
        {
            var suit = slot.GetSuitSymbol() switch { "♠" => CardSuit.Spades, "♥" => CardSuit.Hearts, "♦" => CardSuit.Diamonds, _ => CardSuit.Clubs };
            Assert.Equal(slot, FaceCardSlotExtensions.SlotFor(slot.GetRank(), suit));
        }
        Assert.Null(FaceCardSlotExtensions.SlotFor(7, CardSuit.Hearts));
        Assert.Null(FaceCardSlotExtensions.SlotFor(10, CardSuit.Spades));
    }

    // ---- Face-card art files ----

    private static CustomFaceArt Art(FaceCardSlot slot, string file) =>
        new() { Slot = slot, RelativePath = file, Scale = 1.5, OffsetX = 3, OffsetY = -4 };

    [Fact]
    public void FaceArt_AddUpdateRemove_AndTheFilesGoWithIt()
    {
        FaceCardArtService.ReplaceAll(Array.Empty<CustomFaceArt>());
        var dir = FaceCardArtService.ArtDirectory;
        File.WriteAllBytes(Path.Combine(dir, "king.png"), new byte[] { 1, 2, 3 });
        var king = Art(FaceCardSlot.BlackKing, "king.png");

        FaceCardArtService.Add(king);
        Assert.True(FaceCardArtService.GetArt(FaceCardSlot.BlackKing)!.IsEnabled);
        Assert.Equal(1.5, FaceCardArtService.GetArt(FaceCardSlot.BlackKing)!.Scale);
        Assert.Null(FaceCardArtService.GetArt(FaceCardSlot.RedKing));
        Assert.Equal(Path.Combine(dir, "king.png"), FaceCardArtService.GetFullPath(king));

        // Adding to a slot that already has art replaces it.
        FaceCardArtService.Add(Art(FaceCardSlot.BlackKing, "king2.png"));
        Assert.Single(FaceCardArtService.GetAllArts());
        Assert.Equal("king2.png", FaceCardArtService.GetArt(FaceCardSlot.BlackKing)!.RelativePath);

        // Update by id edits in place; an unknown id is added (replacing that slot's art).
        var edited = FaceCardArtService.GetArt(FaceCardSlot.BlackKing)!;
        edited.Scale = 2.5;
        FaceCardArtService.Update(edited);
        Assert.Equal(2.5, FaceCardArtService.GetArt(FaceCardSlot.BlackKing)!.Scale);
        FaceCardArtService.Update(Art(FaceCardSlot.RedQueen, "q.png"));
        Assert.Equal(2, FaceCardArtService.GetAllArts().Count);

        // Removing deletes the art's file too.
        File.WriteAllBytes(Path.Combine(dir, "q.png"), new byte[] { 9 });
        FaceCardArtService.Remove(FaceCardSlot.RedQueen);
        Assert.Null(FaceCardArtService.GetArt(FaceCardSlot.RedQueen));
        Assert.False(File.Exists(Path.Combine(dir, "q.png")));
        FaceCardArtService.Remove(FaceCardSlot.ClubsAce);   // removing nothing is fine
        Assert.Single(FaceCardArtService.GetAllArts());
    }

    [Fact]
    public void FaceArt_IsSavedToDisk_AndEmptiesWithReplaceAll()
    {
        FaceCardArtService.ReplaceAll(new[] { Art(FaceCardSlot.ClubsJack, "j.png"), Art(FaceCardSlot.DiamondsAce, "a.gif") });
        var config = File.ReadAllText(Path.Combine(FaceCardArtService.ArtDirectory, "config.json"));
        Assert.Contains("j.png", config);
        Assert.Contains("a.gif", config);
        Assert.True(FaceCardArtService.IsGif(FaceCardArtService.GetArt(FaceCardSlot.DiamondsAce)!));
        Assert.False(FaceCardArtService.IsGif(FaceCardArtService.GetArt(FaceCardSlot.ClubsJack)!));
        FaceCardArtService.ReplaceAll(Array.Empty<CustomFaceArt>());
        Assert.Empty(FaceCardArtService.GetAllArts());
    }

    [Theory]
    [InlineData("../outside.png")]
    [InlineData("sub/dir.png")]
    [InlineData("C:\\windows\\x.png")]
    [InlineData("/etc/passwd")]
    [InlineData("")]
    public void FaceArt_UnsafePaths_NeverResolveOutsideTheArtFolder(string path)
    {
        var art = Art(FaceCardSlot.BlackAce, path);
        var full = FaceCardArtService.GetFullPath(art);
        Assert.StartsWith(FaceCardArtService.ArtDirectory, full);
        Assert.False(File.Exists(full));
    }

    [Fact]
    public void FaceArt_RemovingAnUnsafePath_DeletesNothingOutsideTheFolder()
    {
        var outside = Path.Combine(AppPaths.DataDirectory, "precious.txt");
        Directory.CreateDirectory(AppPaths.DataDirectory);
        File.WriteAllText(outside, "keep me");
        FaceCardArtService.ReplaceAll(new[] { Art(FaceCardSlot.BlackAce, "../precious.txt") });
        FaceCardArtService.Remove(FaceCardSlot.BlackAce);
        Assert.True(File.Exists(outside));
        File.Delete(outside);
    }

    // ---- Blackjack hand values ----

    private static BlackjackHand Hand(params (int rank, bool up)[] cards) => new()
    {
        Cards = cards.Select(c => new Card($"c{Guid.NewGuid():N}", CardSuit.Spades, c.rank, c.up)).ToList()
    };

    [Fact]
    public void VisibleValue_CountsOnlyFaceUpCards_AndAcesSoftenWhenNeeded()
    {
        var hidden = Hand((1, true), (13, false));
        Assert.Equal((11, true), hidden.ComputeVisibleValue());       // the hole card isn't counted
        Assert.Equal((21, true), hidden.ComputeValue());              // but the full hand is a blackjack

        var twoAces = Hand((1, true), (1, true), (9, true));
        Assert.Equal((21, true), twoAces.ComputeVisibleValue());      // 11 + 1 + 9
        var bustSoftened = Hand((1, true), (9, true), (5, true));
        Assert.Equal((15, false), bustSoftened.ComputeVisibleValue()); // the ace drops to 1
        Assert.Equal((10, false), Hand((13, true)).ComputeVisibleValue());
    }

    [Fact]
    public void HandStatus_BustBlackjackAndComplete()
    {
        Assert.True(Hand((10, true), (9, true), (5, true)).IsBust);
        Assert.False(Hand((10, true), (9, true)).IsBust);
        Assert.True(Hand((1, true), (13, true)).IsBlackjack);
        var split21 = Hand((1, true), (13, true));
        split21.FromSplit = true;
        Assert.False(split21.IsBlackjack);                             // 21 after a split isn't a natural
        Assert.True(split21.IsComplete);                               // but it is complete
        Assert.False(Hand((5, true), (6, true)).IsComplete);
        var stood = Hand((5, true), (6, true)); stood.IsStood = true;
        Assert.True(stood.IsComplete);
        var doubled = Hand((5, true), (6, true)); doubled.IsDoubled = true;
        Assert.True(doubled.IsComplete);
    }

    // ---- Names ----

    [Fact]
    public void SuitAndDifficultyNames()
    {
        Assert.Equal("Spades", HoneycombCardData.SuitDisplayName("S"));
        Assert.Equal("Hearts", HoneycombCardData.SuitDisplayName("H"));
        Assert.Equal("Diamonds", HoneycombCardData.SuitDisplayName("D"));
        Assert.Equal("Clubs", HoneycombCardData.SuitDisplayName("C"));
        Assert.Equal("X", HoneycombCardData.SuitDisplayName("X"));
        foreach (var code in new[] { "S", "H", "D", "C" })
        {
            Assert.False(string.IsNullOrWhiteSpace(HoneycombCardData.LocalizedSuitName(code, AppLanguage.English)));
            Assert.NotEqual(HoneycombCardData.LocalizedSuitName(code, AppLanguage.English), HoneycombCardData.LocalizedSuitName(code, AppLanguage.Spanish));
        }
        Assert.Equal("X", HoneycombCardData.LocalizedSuitName("X", AppLanguage.English));
        Assert.Equal(new[] { "Baby Bee", "Honey Bee", "Queen Bee", "Killer Bee" },
            Enum.GetValues<HoneycombDifficulty>().Select(d => d.DisplayName()));
    }

    // ---- The SoliBee → Honeycomb folder move ----

    private static string Temp() => Path.Combine(Path.GetTempPath(), "HoneycombMigration_" + Guid.NewGuid().ToString("N"));

    [Fact]
    public void Migration_MovesTheOldFolderAcross_WithEverythingInIt()
    {
        var root = Temp();
        var legacy = Path.Combine(root, "SoliBee");
        Directory.CreateDirectory(Path.Combine(legacy, "FaceCardArt"));
        File.WriteAllText(Path.Combine(legacy, "settings.json"), "{\"a\":1}");
        File.WriteAllText(Path.Combine(legacy, "FaceCardArt", "config.json"), "[]");
        try
        {
            AppDataMigration.EnsureMigrated(root);
            var moved = Path.Combine(root, "Honeycomb");
            Assert.Equal("{\"a\":1}", File.ReadAllText(Path.Combine(moved, "settings.json")));
            Assert.True(File.Exists(Path.Combine(moved, "FaceCardArt", "config.json")));
            Assert.False(Directory.Exists(legacy));
        }
        finally { Directory.Delete(root, true); }
    }

    [Fact]
    public void Migration_NeverOverwritesAnExistingHoneycombFolder()
    {
        var root = Temp();
        Directory.CreateDirectory(Path.Combine(root, "SoliBee"));
        File.WriteAllText(Path.Combine(root, "SoliBee", "settings.json"), "old");
        Directory.CreateDirectory(Path.Combine(root, "Honeycomb"));
        File.WriteAllText(Path.Combine(root, "Honeycomb", "settings.json"), "current");
        try
        {
            AppDataMigration.EnsureMigrated(root);
            Assert.Equal("current", File.ReadAllText(Path.Combine(root, "Honeycomb", "settings.json")));
            Assert.True(Directory.Exists(Path.Combine(root, "SoliBee")));   // left alone
        }
        finally { Directory.Delete(root, true); }
    }

    [Fact]
    public void Migration_DoesNothing_WhenThereIsNoOldFolder()
    {
        var root = Temp();
        Directory.CreateDirectory(root);
        try
        {
            AppDataMigration.EnsureMigrated(root);
            Assert.False(Directory.Exists(Path.Combine(root, "Honeycomb")));   // and it doesn't create one
        }
        finally { Directory.Delete(root, true); }
    }

    [Fact]
    public void Migration_NeverThrows_EvenOnABadPath()
    {
        AppDataMigration.EnsureMigrated("\0not-a-path");
    }

    // ---- Version ----

    [Fact]
    public void TheRunningVersion_IsNeverBlank() =>
        Assert.False(string.IsNullOrWhiteSpace(UpdateCheckService.CurrentVersion));
}
