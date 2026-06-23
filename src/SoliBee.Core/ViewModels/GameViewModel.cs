using System;
using System.Collections.Generic;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

public partial class GameViewModel : ObservableObject
{
    [ObservableProperty]
    private GameState _state = new();

    [ObservableProperty]
    private GameOptions _options;

    [ObservableProperty]
    private GameStatistics _stats;

    public Pile Stock { get; } = new("Stock", PileType.Stock);
    public Pile Waste { get; } = new("Waste", PileType.Waste);
    public List<Pile> Foundations { get; } = new();
    public List<Pile> Tableaus { get; } = new();

    private readonly Stack<GameStateSnapshot> _undoStack = new();

    public GameViewModel()
    {
        Options = SettingsService.LoadOptions();
        Stats = StatsService.LoadStats();

        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (r, m) =>
        {
            Options = m.Options;
            OnPropertyChanged(nameof(Options));
        });

        for (int i = 0; i < 4; i++)
        {
            Foundations.Add(new Pile($"Foundation_{i}", PileType.Foundation));
        }

        for (int i = 0; i < 7; i++)
        {
            Tableaus.Add(new Pile($"Tableau_{i}", PileType.Tableau));
        }

        InitializeGame();
    }

    public void InitializeGame()
    {
        // Clear everything
        Stock.Cards.Clear();
        Waste.Cards.Clear();
        foreach (var f in Foundations) f.Cards.Clear();
        foreach (var t in Tableaus) t.Cards.Clear();
        _undoStack.Clear();

        State = new GameState
        {
            Score = Options.IsVegasScoring ? -52 : 0,
            MovesCount = 0,
            TimerSeconds = 0,
            IsTimerActive = Options.IsTimed,
            HasWon = false,
            RecyclesCount = 0,
            Mode = Options.IsDrawConstraintsEnabled ? DrawMode.DrawThree : DrawMode.DrawOne
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
                deck.Add(new Card($"{suitName}_{rankStr}", suit, rank, false));
            }
        }

        // Shuffle deck
        var rng = new Random();
        deck = deck.OrderBy(c => rng.Next()).ToList();

        // Deal cards to tableau
        for (int i = 0; i < 7; i++)
        {
            for (int j = 0; j <= i; j++)
            {
                var card = deck[0];
                deck.RemoveAt(0);

                // Top card is face up
                if (j == i)
                {
                    card = card with { IsFaceUp = true };
                }

                Tableaus[i].Cards.Add(card);
            }
        }

        // Put remaining cards in stock
        foreach (var card in deck)
        {
            Stock.Cards.Add(card);
        }

        Stats.GamesPlayed++;
        StatsService.SaveStats(Stats);
        
        OnPropertyChanged(nameof(Stock));
        OnPropertyChanged(nameof(Waste));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
    }

    public void DrawCard()
    {
        SaveStateForUndo();

        if (Stock.Cards.Count == 0)
        {
            // Recycle waste back to stock
            if (Waste.Cards.Count == 0) return;

            // In Vegas scoring, recycle is restricted or costs points (standard Vegas allows limited recycles)
            State.RecyclesCount++;
            
            // Move waste cards to stock in reverse order, turn face down
            var wasteCards = Waste.Cards.ToList();
            wasteCards.Reverse();
            foreach (var card in wasteCards)
            {
                Stock.Cards.Add(card with { IsFaceUp = false });
            }
            Waste.Cards.Clear();
            State.MovesCount++;
            return;
        }

        int drawCount = State.Mode == DrawMode.DrawThree ? 3 : 1;
        int cardsToDraw = Math.Min(drawCount, Stock.Cards.Count);

        for (int i = 0; i < cardsToDraw; i++)
        {
            var card = Stock.Cards[^1];
            Stock.Cards.RemoveAt(Stock.Cards.Count - 1);
            Waste.Cards.Add(card with { IsFaceUp = true });
        }

        State.MovesCount++;
    }

    public bool CanMoveCard(Card card, Pile targetPile)
    {
        if (targetPile == null || card == null) return false;

        // Find the source pile
        var sourcePile = FindPileContaining(card);
        if (sourcePile == null) return false;

        // If card is not face up, it cannot be moved
        if (!card.IsFaceUp) return false;

        // Check rules based on target pile type
        if (targetPile.Type == PileType.Tableau)
        {
            // Only King can go to empty tableau
            if (targetPile.Cards.Count == 0)
            {
                // Must be a King (rank 13)
                // Note: if card is part of a fanned stack, we must move the whole stack.
                // The base card of the stack must be rank 13.
                return card.Rank == 13;
            }

            var targetTopCard = targetPile.Cards.Last();
            if (!targetTopCard.IsFaceUp) return false;

            // Target card must alternate color and be exactly 1 rank higher
            bool alternates = (IsRed(card.Suit) != IsRed(targetTopCard.Suit));
            bool sequential = (targetTopCard.Rank == card.Rank + 1);

            return alternates && sequential;
        }
        else if (targetPile.Type == PileType.Foundation)
        {
            // Foundation can only receive single cards, not stacks
            // Check if card is the top card of its pile
            if (sourcePile.Cards.Last() != card) return false;

            if (targetPile.Cards.Count == 0)
            {
                // Must be an Ace (rank 1)
                return card.Rank == 1;
            }

            var targetTopCard = targetPile.Cards.Last();
            
            // Must be same suit and exactly 1 rank higher
            bool sameSuit = (targetTopCard.Suit == card.Suit);
            bool sequential = (card.Rank == targetTopCard.Rank + 1);

            return sameSuit && sequential;
        }

        return false;
    }

    public void MoveCard(Card card, Pile targetPile)
    {
        if (!CanMoveCard(card, targetPile)) return;

        SaveStateForUndo();

        var sourcePile = FindPileContaining(card);
        int index = sourcePile.Cards.IndexOf(card);

        // Extract cards from the index to the end
        var cardsToMove = sourcePile.Cards.GetRange(index, sourcePile.Cards.Count - index);
        sourcePile.Cards.RemoveRange(index, sourcePile.Cards.Count - index);

        // Add to target pile
        foreach (var c in cardsToMove)
        {
            targetPile.Cards.Add(c);
        }

        // Auto flip the new top card of the source pile if it's a tableau
        if (sourcePile.Type == PileType.Tableau && sourcePile.Cards.Count > 0)
        {
            var topCard = sourcePile.Cards.Last();
            if (!topCard.IsFaceUp)
            {
                sourcePile.Cards[sourcePile.Cards.Count - 1] = topCard with { IsFaceUp = true };
            }
        }

        // Update score
        UpdateScoreForMove(sourcePile.Type, targetPile.Type);

        State.MovesCount++;
        CheckVictory();
    }

    private void UpdateScoreForMove(PileType source, PileType target)
    {
        if (Options.IsVegasScoring)
        {
            // Vegas scoring: +5 for each card moved to Foundation
            if (target == PileType.Foundation)
            {
                State.Score += 5;
            }
            // Moving off foundation costs $5
            else if (source == PileType.Foundation)
            {
                State.Score -= 5;
            }
        }
        else
        {
            // Standard Klondike scoring rules:
            // Waste to Tableau: 5 pts
            // Waste to Foundation: 10 pts
            // Tableau to Foundation: 10 pts
            // Turn over Tableau card: 5 pts
            // Foundation to Tableau: -15 pts
            if (source == PileType.Waste && target == PileType.Tableau) State.Score += 5;
            else if (source == PileType.Waste && target == PileType.Foundation) State.Score += 10;
            else if (source == PileType.Tableau && target == PileType.Foundation) State.Score += 10;
            else if (source == PileType.Foundation && target == PileType.Tableau) State.Score -= 15;
        }
    }

    public void SaveStateForUndo()
    {
        var snapshot = new GameStateSnapshot
        {
            Score = State.Score,
            MovesCount = State.MovesCount,
            TimerSeconds = State.TimerSeconds,
            RecyclesCount = State.RecyclesCount,
            HasWon = State.HasWon,
            PileCards = new List<List<Card>>()
        };

        // Snapshot all piles
        snapshot.PileCards.Add(Stock.Cards.ToList());
        snapshot.PileCards.Add(Waste.Cards.ToList());
        foreach (var f in Foundations) snapshot.PileCards.Add(f.Cards.ToList());
        foreach (var t in Tableaus) snapshot.PileCards.Add(t.Cards.ToList());

        _undoStack.Push(snapshot);
    }

    [RelayCommand]
    public void Undo()
    {
        if (_undoStack.Count == 0) return;

        var snapshot = _undoStack.Pop();
        State.Score = snapshot.Score;
        State.MovesCount = snapshot.MovesCount;
        State.TimerSeconds = snapshot.TimerSeconds;
        State.RecyclesCount = snapshot.RecyclesCount;
        State.HasWon = snapshot.HasWon;

        Stock.Cards.Clear();
        foreach (var c in snapshot.PileCards[0]) Stock.Cards.Add(c);

        Waste.Cards.Clear();
        foreach (var c in snapshot.PileCards[1]) Waste.Cards.Add(c);

        int index = 2;
        for (int i = 0; i < 4; i++)
        {
            Foundations[i].Cards.Clear();
            foreach (var c in snapshot.PileCards[index]) Foundations[i].Cards.Add(c);
            index++;
        }

        for (int i = 0; i < 7; i++)
        {
            Tableaus[i].Cards.Clear();
            foreach (var c in snapshot.PileCards[index]) Tableaus[i].Cards.Add(c);
            index++;
        }

        OnPropertyChanged(nameof(Stock));
        OnPropertyChanged(nameof(Waste));
        OnPropertyChanged(nameof(Foundations));
        OnPropertyChanged(nameof(Tableaus));
    }

    public bool IsAutocompletable()
    {
        if (Stock.Cards.Any() || Waste.Cards.Any()) return false;

        foreach (var t in Tableaus)
        {
            if (t.Cards.Any(c => !c.IsFaceUp)) return false;
        }

        return true;
    }

    [RelayCommand]
    public void Autocomplete()
    {
        if (!IsAutocompletable()) return;

        while (Foundations.Sum(f => f.Cards.Count) < 52)
        {
            bool movedAny = false;
            foreach (var t in Tableaus.Where(x => x.Cards.Count > 0))
            {
                var card = t.Cards.Last();
                foreach (var f in Foundations)
                {
                    if (CanMoveCard(card, f))
                    {
                        MoveCard(card, f);
                        movedAny = true;
                        break;
                    }
                }
                if (movedAny) break;
            }

            if (!movedAny)
            {
                // Prevent infinite loop if something goes wrong
                break;
            }
        }
    }

    public void CheckVictory()
    {
        // Win is when foundations contain all 52 cards
        if (Foundations.Sum(f => f.Cards.Count) == 52)
        {
            if (!State.HasWon)
            {
                State.HasWon = true;
                State.IsTimerActive = false;

                Stats.GamesWon++;
                Stats.CurrentStreak++;
                if (Stats.CurrentStreak > Stats.LongestStreak)
                {
                    Stats.LongestStreak = Stats.CurrentStreak;
                }

                if (Options.IsVegasScoring)
                {
                    if (State.Score > Stats.VegasHighScore)
                    {
                        Stats.VegasHighScore = State.Score;
                    }
                }
                else
                {
                    if (State.Score > Stats.StandardHighScore)
                    {
                        Stats.StandardHighScore = State.Score;
                    }
                }

                StatsService.SaveStats(Stats);
            }
        }
    }

    private Pile FindPileContaining(Card card)
    {
        if (Stock.Cards.Contains(card)) return Stock;
        if (Waste.Cards.Contains(card)) return Waste;
        
        var found = Foundations.FirstOrDefault(f => f.Cards.Contains(card));
        if (found != null) return found;

        return Tableaus.FirstOrDefault(t => t.Cards.Contains(card));
    }

    private static bool IsRed(CardSuit suit)
    {
        return suit == CardSuit.Hearts || suit == CardSuit.Diamonds;
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

public class GameStateSnapshot
{
    public int Score { get; set; }
    public int MovesCount { get; set; }
    public int TimerSeconds { get; set; }
    public int RecyclesCount { get; set; }
    public bool HasWon { get; set; }
    public List<List<Card>> PileCards { get; set; } = new();
}
