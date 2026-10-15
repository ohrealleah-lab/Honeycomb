using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text.Json;
using SoliBee.Core.Models;
using Xunit;

namespace SoliBee.Tests.Core;

// The Honeycomb card bank and saved decks: what a first launch gives the player, how saved
// files are read back (padded/trimmed to 5 slots, broken files), unlocking, favourites and
// Start Over. HoneycombProfileManager.Shared only loads once, so these tests build a fresh
// instance against files written into the sandboxed data folder.
public class HoneycombProfileStorageTests : DataSandbox
{
    private const string Unlocked = "honeycomb_unlocked_cards.json";
    private const string Decks = "honeycomb_saved_decks.json";
    private const string Favorites = "honeycomb_favorite_cards.json";

    private static HoneycombProfileManager Launch() =>
        (HoneycombProfileManager)Activator.CreateInstance(typeof(HoneycombProfileManager), nonPublic: true)!;

    private static void FirstLaunchState()
    {
        Delete(Unlocked); Delete(Decks); Delete(Favorites);
    }

    private static int Stars(int id) => HoneycombDatabase.Shared.Card(id)!.Stars;

    private static List<int> Saved(string file) => JsonSerializer.Deserialize<List<int>>(Read(file))!;

    // ---- First launch ----

    [Fact]
    public void FirstLaunch_UnlocksThreeOneStarAndTwoTwoStarCards()
    {
        FirstLaunchState();
        var m = Launch();

        Assert.Equal(5, m.UnlockedCardIds.Count);
        Assert.Equal(new[] { 1, 1, 1, 2, 2 }, m.UnlockedCardIds.Select(Stars).OrderBy(s => s));
    }

    [Fact]
    public void FirstLaunch_PutsTheStarterCardsInDeckOne_NamedDefault()
    {
        FirstLaunchState();
        var m = Launch();

        Assert.Equal("Default", m.SavedDecks[0].Name);
        Assert.Equal(m.UnlockedCardIds.OrderBy(i => i), m.SavedDecks[0].CardIds.OrderBy(i => i));
        Assert.Equal(5, m.SavedDecks[0].CardIds.Distinct().Count());
    }

    [Fact]
    public void FirstLaunch_LeavesTheOtherFourDecksEmpty()
    {
        FirstLaunchState();
        var m = Launch();

        Assert.Equal(5, m.SavedDecks.Count);
        for (int i = 1; i < 5; i++)
        {
            Assert.Equal($"Empty Slot {i + 1}", m.SavedDecks[i].Name);
            Assert.Empty(m.SavedDecks[i].CardIds);
        }
        Assert.Empty(m.FavoriteCardIds);
    }

    [Fact]
    public void FirstLaunch_SavesTheStarterCardsAndDeck_SoTheyAreTheSameNextTime()
    {
        FirstLaunchState();
        var first = Launch();

        var second = Launch();

        Assert.Equal(first.UnlockedCardIds.OrderBy(i => i), second.UnlockedCardIds.OrderBy(i => i));
        Assert.Equal("Default", second.SavedDecks[0].Name);
        Assert.Equal(first.SavedDecks[0].CardIds, second.SavedDecks[0].CardIds);
        Assert.Equal(5, second.SavedDecks.Count);
    }

    // ---- Reading saved files ----

    [Fact]
    public void SavedDecks_AreReadBack()
    {
        Write(Unlocked, "[1,2,3,4,5,6]");
        Write(Decks, JsonSerializer.Serialize(new List<HoneycombDeckState>
        {
            new() { Name = "Mine", CardIds = new() { 1, 2, 3, 4, 5 } },
            new() { Name = "Spare", CardIds = new() { 6 } },
            new() { Name = "C" }, new() { Name = "D" }, new() { Name = "E" },
        }));
        var m = Launch();

        Assert.Equal("Mine", m.SavedDecks[0].Name);
        Assert.Equal(new[] { 1, 2, 3, 4, 5 }, m.SavedDecks[0].CardIds);
        Assert.Equal("Spare", m.SavedDecks[1].Name);
        Assert.Equal(new[] { 6 }, m.SavedDecks[1].CardIds);
        Assert.Equal(new HashSet<int> { 1, 2, 3, 4, 5, 6 }, m.UnlockedCardIds);
    }

    [Fact]
    public void FewerThanFiveSavedDecks_AreToppedUpWithEmptySlots()
    {
        Write(Unlocked, "[1,2,3,4,5]");
        Write(Decks, JsonSerializer.Serialize(new List<HoneycombDeckState>
        {
            new() { Name = "Only", CardIds = new() { 1, 2, 3, 4, 5 } },
            new() { Name = "Second" },
        }));
        var m = Launch();

        Assert.Equal(5, m.SavedDecks.Count);
        Assert.Equal("Only", m.SavedDecks[0].Name);
        Assert.Equal("Second", m.SavedDecks[1].Name);
        Assert.Equal("Empty Slot 3", m.SavedDecks[2].Name);
        Assert.Equal("Empty Slot 4", m.SavedDecks[3].Name);
        Assert.Equal("Empty Slot 5", m.SavedDecks[4].Name);
        Assert.Empty(m.SavedDecks[4].CardIds);
    }

    [Fact]
    public void MoreThanFiveSavedDecks_AreTrimmedToTheFirstFive()
    {
        Write(Unlocked, "[1,2,3,4,5]");
        Write(Decks, JsonSerializer.Serialize(Enumerable.Range(1, 8).Select(i => new HoneycombDeckState { Name = $"D{i}" }).ToList()));
        var m = Launch();

        Assert.Equal(new[] { "D1", "D2", "D3", "D4", "D5" }, m.SavedDecks.Select(d => d.Name));
    }

    [Fact]
    public void BrokenDecksFile_GivesFiveEmptySlots_WithoutCrashing()
    {
        Write(Unlocked, "[1,2,3,4,5]");
        Write(Decks, "this is not json");
        var m = Launch();

        Assert.Equal(5, m.SavedDecks.Count);
        Assert.All(m.SavedDecks, d => Assert.Empty(d.CardIds));
        Assert.Equal("Empty Slot 1", m.SavedDecks[0].Name);
    }

    [Fact]
    public void BrokenUnlockedFile_MeansNothingUnlocked_NotACrashOrANewStarterSet()
    {
        Write(Unlocked, "{{{");
        Write(Decks, "[]");
        var m = Launch();

        Assert.Empty(m.UnlockedCardIds);
        Assert.Equal(5, m.SavedDecks.Count);
    }

    [Fact]
    public void BrokenFavoritesFile_MeansNoFavourites()
    {
        Write(Unlocked, "[1,2,3,4,5]");
        Write(Decks, "[]");
        Write(Favorites, "oops");

        Assert.Empty(Launch().FavoriteCardIds);
    }

    // ---- Unlocking and favourites ----

    [Fact]
    public void UnlockCard_AddsItToTheBank_AndSurvivesARelaunch()
    {
        Write(Unlocked, "[1,2,3]");
        Write(Decks, "[]");
        var m = Launch();

        m.UnlockCard(40);
        m.UnlockCard(40);

        Assert.Equal(new HashSet<int> { 1, 2, 3, 40 }, m.UnlockedCardIds);
        Assert.Equal(new HashSet<int> { 1, 2, 3, 40 }, Launch().UnlockedCardIds);
        Assert.Equal(4, Saved(Unlocked).Count);
    }

    [Fact]
    public void Favourites_AreSavedAndComeBack()
    {
        Write(Unlocked, "[1,2,3,4,5]");
        Write(Decks, "[]");
        var m = Launch();

        m.FavoriteCardIds.Add(2);
        m.FavoriteCardIds.Add(4);
        m.SaveFavoriteCards();
        Assert.Equal(new HashSet<int> { 2, 4 }, Launch().FavoriteCardIds);

        m.FavoriteCardIds.Remove(2);
        m.SaveFavoriteCards();
        Assert.Equal(new HashSet<int> { 4 }, Launch().FavoriteCardIds);
    }

    [Fact]
    public void SaveSavedDecks_PersistsEditsToADeck()
    {
        FirstLaunchState();
        var m = Launch();

        m.SavedDecks[2].Name = "Fresh";
        m.SavedDecks[2].CardIds = new List<int> { 7, 8, 9, 10, 11 };
        m.SaveSavedDecks();

        var again = Launch();
        Assert.Equal("Fresh", again.SavedDecks[2].Name);
        Assert.Equal(new[] { 7, 8, 9, 10, 11 }, again.SavedDecks[2].CardIds);
        Assert.Equal("Default", again.SavedDecks[0].Name);
    }

    // ---- Start Over ----

    // Start Over reseeds the shared card database (a different set of cards), so put the
    // original cards back afterwards for the tests that run next.
    private static void WithDatabaseRestored(Action body)
    {
        var db = HoneycombDatabase.Shared;
        var cards = db.AllCards;
        var seed = db.CurrentSeed;
        try { body(); }
        finally
        {
            typeof(HoneycombDatabase).GetProperty(nameof(HoneycombDatabase.AllCards), BindingFlags.Public | BindingFlags.Instance)!.SetValue(db, cards);
            typeof(HoneycombDatabase).GetProperty(nameof(HoneycombDatabase.CurrentSeed), BindingFlags.Public | BindingFlags.Instance)!.SetValue(db, seed);
        }
    }

    [Fact]
    public void StartOver_RebuildsDeckOneWithTheSameStarMix_AndWipesEverythingElse() => WithDatabaseRestored(() =>
    {
        var db = HoneycombDatabase.Shared;
        int Pick(int stars, int skip) => db.AllCards.Where(c => c.Stars == stars).Skip(skip).First().Id;
        var old = new List<int> { Pick(5, 0), Pick(4, 0), Pick(3, 0), Pick(3, 1), Pick(2, 0) };

        Write(Unlocked, JsonSerializer.Serialize(old.Concat(new[] { Pick(1, 0), Pick(1, 1) })));
        Write(Decks, JsonSerializer.Serialize(new List<HoneycombDeckState>
        {
            new() { Name = "My Best", CardIds = old },
            new() { Name = "Second", CardIds = new() { Pick(1, 0), Pick(1, 1), Pick(1, 2), Pick(1, 3), Pick(1, 4) } },
            new() { Name = "C" }, new() { Name = "D" }, new() { Name = "E" },
        }));
        Write(Favorites, JsonSerializer.Serialize(new[] { old[0] }));
        var m = Launch();

        m.StartOver();

        Assert.Equal("Default", m.SavedDecks[0].Name);
        Assert.Equal(new[] { 5, 4, 3, 3, 2 }, m.SavedDecks[0].CardIds.Select(Stars).OrderByDescending(s => s));
        Assert.Equal(5, m.SavedDecks[0].CardIds.Distinct().Count());
        Assert.Equal(5, m.SavedDecks.Count);
        for (int i = 1; i < 5; i++)
        {
            Assert.Equal($"Empty Slot {i + 1}", m.SavedDecks[i].Name);
            Assert.Empty(m.SavedDecks[i].CardIds);
        }
        Assert.Equal(new HashSet<int>(m.SavedDecks[0].CardIds), m.UnlockedCardIds);
        Assert.Empty(m.FavoriteCardIds);

        // ...and it is all saved, so a relaunch sees the same thing.
        var again = Launch();
        Assert.Equal("Default", again.SavedDecks[0].Name);
        Assert.Equal(m.SavedDecks[0].CardIds, again.SavedDecks[0].CardIds);
        Assert.Equal(m.UnlockedCardIds, again.UnlockedCardIds);
        Assert.Empty(again.FavoriteCardIds);
    });

    [Fact]
    public void StartOver_OnANeverBuiltDeckOne_FallsBackToTheStarterMix() => WithDatabaseRestored(() =>
    {
        Write(Unlocked, "[1,2,3]");
        Write(Decks, "[]");
        var m = Launch();
        Assert.Empty(m.SavedDecks[0].CardIds);

        m.StartOver();

        Assert.Equal("Default", m.SavedDecks[0].Name);
        Assert.Equal(new[] { 1, 1, 1, 2, 2 }, m.SavedDecks[0].CardIds.Select(Stars).OrderBy(s => s));
        Assert.Equal(5, m.UnlockedCardIds.Count);
    });

    [Fact]
    public void StartOver_GivesTheCardDatabaseAFreshSeed() => WithDatabaseRestored(() =>
    {
        FirstLaunchState();
        var m = Launch();
        var seedBefore = HoneycombDatabase.Shared.CurrentSeed;

        m.StartOver();

        Assert.NotEqual(seedBefore, HoneycombDatabase.Shared.CurrentSeed);
        Assert.Equal(HoneycombDatabase.Shared.CurrentSeed.ToString(), Read("honeycomb_seed.json").Trim());
    });

    [Fact]
    public void ComputeStartOverDeck_NeverRepeatsACard()
    {
        var one = HoneycombDatabase.Shared.AllCards.First(c => c.Stars == 3).Id;
        var composition = Enumerable.Repeat(one, 5).ToList();

        for (int run = 0; run < 25; run++)
        {
            var ids = HoneycombProfileManager.ComputeStartOverDeck(composition);
            Assert.Equal(5, ids.Distinct().Count());
            Assert.All(ids, id => Assert.Equal(3, Stars(id)));
        }
    }

    [Fact]
    public void ComputeStartOverDeck_WithNoPreviousDeck_GivesTheStarterMix()
    {
        foreach (var previous in new List<int>?[] { null, new List<int>(), new List<int> { 1, 2 } })
        {
            var ids = HoneycombProfileManager.ComputeStartOverDeck(previous);
            Assert.Equal(new[] { 1, 1, 1, 2, 2 }, ids.Select(Stars).OrderBy(s => s));
        }
    }
}
