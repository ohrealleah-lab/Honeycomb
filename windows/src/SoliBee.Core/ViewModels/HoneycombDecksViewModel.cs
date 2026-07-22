using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using System.Collections.ObjectModel;
using System.Linq;

namespace SoliBee.Core.ViewModels;

public partial class HoneycombDecksViewModel : ObservableObject
{
    private readonly HoneycombStats _stats;

    [ObservableProperty]
    private ObservableCollection<HoneycombCardData> _cardBank = new();

    [ObservableProperty]
    private ObservableCollection<HoneycombCardData> _currentDeck = new();

    [ObservableProperty]
    private int _maxStarsCap = 15; // Base cap

    public int CurrentStars => CurrentDeck.Sum(c => c.Stars);

    public HoneycombDecksViewModel()
    {
        _stats = HoneycombViewModel.LoadStats();
        _maxStarsCap = 15 + (_stats.MatchesWon / 5); // Example progression
        if (_maxStarsCap > 30) _maxStarsCap = 30; // Max cap

        LoadBank();
        LoadCurrentDeck();
    }

    private void LoadBank()
    {
        CardBank.Clear();
        foreach (var id in _stats.CollectedCardIds)
        {
            var data = HoneycombDatabase.Shared.Card(id);
            if (data != null) CardBank.Add(data);
        }
    }

    private void LoadCurrentDeck()
    {
        CurrentDeck.Clear();
        var opts = SettingsService.LoadOptions();
        foreach (var id in opts.PlayerDeckIds)
        {
            var data = HoneycombDatabase.Shared.Card(id);
            if (data != null) CurrentDeck.Add(data);
        }
    }

    public bool AddToDeck(HoneycombCardData card)
    {
        if (CurrentDeck.Count >= 5) return false;
        if (CurrentDeck.Any(c => c.Id == card.Id)) return false; // No duplicates
        
        if (CurrentStars + card.Stars > MaxStarsCap) return false;

        CurrentDeck.Add(card);
        OnPropertyChanged(nameof(CurrentStars));
        return true;
    }

    public void RemoveFromDeck(HoneycombCardData card)
    {
        CurrentDeck.Remove(card);
        OnPropertyChanged(nameof(CurrentStars));
    }

    public void SaveDeck()
    {
        if (CurrentDeck.Count != 5) return; // Must have exactly 5

        var opts = SettingsService.LoadOptions();
        opts.PlayerDeckIds = CurrentDeck.Select(c => c.Id).ToList();
        SettingsService.SaveOptions(opts);
    }
}
