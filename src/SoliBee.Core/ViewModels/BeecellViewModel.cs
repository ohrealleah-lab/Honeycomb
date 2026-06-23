using System;
using System.Collections.Generic;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

public record OptionsChangedMessage(GameOptions Options);

public partial class BeecellViewModel : ObservableObject
{
    [ObservableProperty]
    private GameState _state = new();

    [ObservableProperty]
    private GameOptions _options;

    [ObservableProperty]
    private GameStatistics _stats;

    public List<Pile> FreeCells { get; } = new();
    public List<Pile> Foundations { get; } = new();
    public List<Pile> Tableaus { get; } = new();

    public BeecellViewModel()
    {
        Options = SettingsService.LoadOptions();
        Stats = StatsService.LoadStats();

        // WeakReferenceMessenger registration for options synchronization
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            Options = m.Options;
            OnPropertyChanged(nameof(Options));
        });

        for (int i = 0; i < 4; i++)
        {
            FreeCells.Add(new Pile($"FreeCell_{i}", PileType.Stock)); // Representing temporary cells
            Foundations.Add(new Pile($"Foundation_{i}", PileType.Foundation));
        }

        for (int i = 0; i < 8; i++)
        {
            Tableaus.Add(new Pile($"Tableau_{i}", PileType.Tableau));
        }

        InitializeGame();
    }

    public void InitializeGame()
    {
        foreach (var c in FreeCells) c.Cards.Clear();
        foreach (var f in Foundations) f.Cards.Clear();
        foreach (var t in Tableaus) t.Cards.Clear();

        State = new GameState
        {
            Score = 0,
            MovesCount = 0,
            TimerSeconds = 0,
            IsTimerActive = Options.IsTimed,
            HasWon = false
        };

        // Create standard 52 card deck
        var deck = new List<Card>();
        var suits = new[] { CardSuit.Spades, CardSuit.Hearts, CardSuit.Diamonds, CardSuit.Clubs };
        foreach (var suit in suits)
        {
            for (int rank = 1; rank <= 13; rank++)
            {
                var suitName = suit.ToString().ToLower();
                var rankStr = rank switch
                {
                    1 => "A",
                    11 => "J",
                    12 => "Q",
                    13 => "K",
                    _ => rank.ToString()
                };
                deck.Add(new Card($"beecell_{suitName}_{rankStr}", suit, rank, true)); // Freecell cards are always face up
            }
        }

        // Shuffle deck
        var rng = new Random();
        deck = deck.OrderBy(c => rng.Next()).ToList();

        // Distribute all 52 cards to 8 tableaus
        int tableauIndex = 0;
        while (deck.Count > 0)
        {
            var card = deck[0];
            deck.RemoveAt(0);
            Tableaus[tableauIndex].Cards.Add(card);
            tableauIndex = (tableauIndex + 1) % 8;
        }

        OnPropertyChanged(nameof(FreeCells));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
    }

    [RelayCommand]
    public void UpdateFeltColor(FeltColorTheme theme)
    {
        Options.FeltColor = theme;
        Options.CustomFeltColorRevision++;
        SettingsService.SaveOptions(Options);
        WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(Options));
    }
}
