using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.Json;

namespace SoliBee.Core.Models;

public class HoneycombDeckState
{
    public string Name { get; set; } = "Empty Slot";
    public List<int> CardIds { get; set; } = new List<int>();
}

public class HoneycombProfileManager
{
    public static HoneycombProfileManager Shared { get; } = new HoneycombProfileManager();

    public HashSet<int> UnlockedCardIds { get; private set; } = new HashSet<int>();
    public List<HoneycombDeckState> SavedDecks { get; private set; } = new List<HoneycombDeckState>();
    public HashSet<int> FavoriteCardIds { get; private set; } = new HashSet<int>();

    private string GetLocalFolderPath()
    {
        try
        {
            var appDataType = Type.GetType("Windows.Storage.ApplicationData, Windows, Version=255.255.255.255, Culture=neutral, PublicKeyToken=null, ContentType=WindowsRuntime");
            if (appDataType != null)
            {
                var currentProp = appDataType.GetProperty("Current", BindingFlags.Public | BindingFlags.Static);
                var currentInstance = currentProp?.GetValue(null);
                if (currentInstance != null)
                {
                    var localFolderProp = currentInstance.GetType().GetProperty("LocalFolder", BindingFlags.Public | BindingFlags.Instance);
                    var localFolderInstance = localFolderProp?.GetValue(currentInstance);
                    if (localFolderInstance != null)
                    {
                        var pathProp = localFolderInstance.GetType().GetProperty("Path", BindingFlags.Public | BindingFlags.Instance);
                        var path = pathProp?.GetValue(localFolderInstance) as string;
                        if (!string.IsNullOrEmpty(path))
                        {
                            return path;
                        }
                    }
                }
            }
        }
        catch { }

        var fallbackDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SoliBee");
        if (!Directory.Exists(fallbackDir))
        {
            Directory.CreateDirectory(fallbackDir);
        }
        return fallbackDir;
    }

    private string UnlockedCardsPath => Path.Combine(GetLocalFolderPath(), "honeycomb_unlocked_cards.json");
    private string SavedDecksPath => Path.Combine(GetLocalFolderPath(), "honeycomb_saved_decks.json");
    private string FavoriteCardsPath => Path.Combine(GetLocalFolderPath(), "honeycomb_favorite_cards.json");

    private HoneycombProfileManager()
    {
        Load();
    }

    private void Load()
    {
        bool isFirstRun = false;

        // Load UnlockedCards
        if (File.Exists(UnlockedCardsPath))
        {
            try
            {
                var json = File.ReadAllText(UnlockedCardsPath);
                var ids = JsonSerializer.Deserialize<List<int>>(json);
                if (ids != null) UnlockedCardIds = new HashSet<int>(ids);
            }
            catch { }
        }
        else
        {
            isFirstRun = true;
            // No unlocked-cards file yet -> starter unlock = 3 random 1* cards + 2 random 2* cards
            UnlockedCardIds = new HashSet<int>();
            var ones = HoneycombDatabase.Shared.RandomCards(1, 3);
            var twos = HoneycombDatabase.Shared.RandomCards(2, 2);
            foreach (var c in ones.Concat(twos)) UnlockedCardIds.Add(c.Id);
            SaveUnlockedCards();
        }

        // Load SavedDecks
        if (File.Exists(SavedDecksPath))
        {
            try
            {
                var json = File.ReadAllText(SavedDecksPath);
                var decks = JsonSerializer.Deserialize<List<HoneycombDeckState>>(json);
                if (decks != null) SavedDecks = decks;
            }
            catch { }
        }
        
        while (SavedDecks.Count < 5)
        {
            SavedDecks.Add(new HoneycombDeckState { Name = $"Empty Slot {SavedDecks.Count + 1}", CardIds = new List<int>() });
        }
        if (SavedDecks.Count > 5)
        {
            SavedDecks = SavedDecks.Take(5).ToList();
        }

        if (isFirstRun)
        {
            // if exactly 5 starter ids exist, slot 0 is named "Default" and populated with those 5 ids
            if (UnlockedCardIds.Count == 5)
            {
                SavedDecks[0].Name = "Default";
                SavedDecks[0].CardIds = UnlockedCardIds.ToList();
                SaveSavedDecks();
            }
        }

        // Load Favorites
        if (File.Exists(FavoriteCardsPath))
        {
            try
            {
                var json = File.ReadAllText(FavoriteCardsPath);
                var ids = JsonSerializer.Deserialize<List<int>>(json);
                if (ids != null) FavoriteCardIds = new HashSet<int>(ids);
            }
            catch { }
        }
    }

    public void SaveUnlockedCards()
    {
        try
        {
            var json = JsonSerializer.Serialize(UnlockedCardIds.ToList(), new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(UnlockedCardsPath, json);
        }
        catch { }
    }

    public void UnlockCard(int cardId)
    {
        UnlockedCardIds.Add(cardId);
        SaveUnlockedCards();
    }

    public void SaveSavedDecks()
    {
        try
        {
            var json = JsonSerializer.Serialize(SavedDecks, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(SavedDecksPath, json);
        }
        catch { }
    }

    public void SaveFavoriteCards()
    {
        try
        {
            var json = JsonSerializer.Serialize(FavoriteCardIds.ToList(), new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(FavoriteCardsPath, json);
        }
        catch { }
    }

    public bool ValidateDeck(List<int> cardIds, string deckName, out string errorMessage)
    {
        if (cardIds.Count != 5)
        {
            errorMessage = "A deck must contain exactly 5 cards.";
            return false;
        }

        if (string.IsNullOrWhiteSpace(deckName))
        {
            errorMessage = "Deck name cannot be empty.";
            return false;
        }

        if (deckName.Length > 20)
        {
            errorMessage = "Deck name cannot exceed 20 characters.";
            return false;
        }

        int fiveStars = 0;
        int fourStars = 0;
        foreach (var id in cardIds)
        {
            var cardData = HoneycombDatabase.Shared.Card(id);
            if (cardData != null)
            {
                if (cardData.Stars == 5) fiveStars++;
                if (cardData.Stars == 4) fourStars++;
            }
        }

        if (fiveStars > 1)
        {
            errorMessage = "A deck can never contain more than one 5★ card.";
            return false;
        }
        else if (fiveStars == 1 && fourStars > 1)
        {
            errorMessage = "If you have a 5★ card, you can only have one 4★ card.";
            return false;
        }
        else if (fiveStars == 0 && fourStars > 2)
        {
            errorMessage = "A deck can never contain more than two 4★ cards.";
            return false;
        }

        errorMessage = string.Empty;
        return true;
    }

    public static List<int> ComputeStartOverDeck(List<int>? previousCardIds)
    {
        var newIds = new List<int>();

        if (previousCardIds != null && previousCardIds.Count == 5)
        {
            foreach (var id in previousCardIds)
            {
                var cardData = HoneycombDatabase.Shared.Card(id);
                int stars = cardData?.Stars ?? 1;
                newIds.Add(HoneycombDatabase.Shared.RandomCards(stars, 1).First().Id);
            }
        }
        else
        {
            var ones = HoneycombDatabase.Shared.RandomCards(1, 3);
            var twos = HoneycombDatabase.Shared.RandomCards(2, 2);
            newIds.AddRange(ones.Select(c => c.Id));
            newIds.AddRange(twos.Select(c => c.Id));
        }

        return newIds;
    }

    public void StartOver()
    {
        var prevIds = SavedDecks[0].CardIds;
        var newIds = ComputeStartOverDeck(prevIds);

        for (int i = 0; i < 5; i++)
        {
            SavedDecks[i].Name = $"Empty Slot {i + 1}";
            SavedDecks[i].CardIds.Clear();
        }

        SavedDecks[0].Name = "Default";
        SavedDecks[0].CardIds = newIds;
        
        UnlockedCardIds.Clear();
        foreach (var id in newIds) UnlockedCardIds.Add(id);
        
        FavoriteCardIds.Clear();

        HoneycombDatabase.Shared.Reseed();
        
        // Let ViewModel or caller reset options to 0
        
        SaveUnlockedCards();
        SaveSavedDecks();
        SaveFavoriteCards();
    }
}
