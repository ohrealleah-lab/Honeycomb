using System;
using System.Collections.Generic;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

public partial class SpiderViewModel : ObservableObject
{
    [ObservableProperty]
    private GameState _state = new();

    [ObservableProperty]
    private GameOptions _options;

    [ObservableProperty]
    private GameStatistics _stats;

    public List<Pile> StockPiles { get; } = new(); // For spider deals
    public List<Pile> Tableaus { get; } = new();

    public SpiderViewModel()
    {
        Options = SettingsService.LoadOptions();
        Stats = StatsService.LoadStats();

        // WeakReferenceMessenger registration for options synchronization
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            Options = m.Options;
            OnPropertyChanged(nameof(Options));
        });

        for (int i = 0; i < 10; i++)
        {
            Tableaus.Add(new Pile($"Tableau_{i}", PileType.Tableau));
        }

        InitializeGame();
    }

    public void InitializeGame()
    {
        StockPiles.Clear();
        foreach (var t in Tableaus) t.Cards.Clear();

        State = new GameState
        {
            Score = 500, // Spider starts at 500
            MovesCount = 0,
            TimerSeconds = 0,
            IsTimerActive = Options.IsTimed,
            HasWon = false
        };

        // Create standard Spider deck (usually 104 cards, 2 decks. We'll simplify to 104 cards of Spades for 1-suit, etc.)
        var deck = new List<Card>();
        // Using 1-suit (Spades) for simpler implementation
        for (int deckNum = 0; deckNum < 8; deckNum++) // 8 sets of Ace-King
        {
            for (int rank = 1; rank <= 13; rank++)
            {
                var rankStr = rank switch
                {
                    1 => "A",
                    11 => "J",
                    12 => "Q",
                    13 => "K",
                    _ => rank.ToString()
                };
                deck.Add(new Card($"spider_{deckNum}_{rankStr}", CardSuit.Spades, rank, false));
            }
        }

        // Shuffle deck
        var rng = new Random();
        deck = deck.OrderBy(c => rng.Next()).ToList();

        // Deal cards to tableaus: 4 columns of 6 cards, 6 columns of 5 cards
        for (int col = 0; col < 10; col++)
        {
            int cardsCount = col < 4 ? 6 : 5;
            for (int i = 0; i < cardsCount; i++)
            {
                var card = deck[0];
                deck.RemoveAt(0);

                if (i == cardsCount - 1)
                {
                    card = card with { IsFaceUp = true };
                }

                Tableaus[col].Cards.Add(card);
            }
        }

        // Put remaining cards in stock (5 deals of 10 cards)
        while (deck.Count > 0)
        {
            var stockPile = new Pile($"Stock_{StockPiles.Count}", PileType.Stock);
            for (int i = 0; i < 10 && deck.Count > 0; i++)
            {
                stockPile.Cards.Add(deck[0]);
                deck.RemoveAt(0);
            }
            StockPiles.Add(stockPile);
        }

        OnPropertyChanged(nameof(Tableaus));
        OnPropertyChanged(nameof(StockPiles));
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
