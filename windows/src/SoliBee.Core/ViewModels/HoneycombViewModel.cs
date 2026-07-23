using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

public record HoneycombPendingSwap(int BoardIndex, int ReplaceHandIndex, string IncomingCardName, string OutgoingCardName);

public partial class HoneycombViewModel : ObservableObject
{
    [ObservableProperty] private HoneycombState _state = new();
    [ObservableProperty] private HoneycombOptions _options = new();
    [ObservableProperty] private HoneycombStats _stats = new();

    private static int s_consecutiveStarters = 0;
    private static int s_lastStarter = 0;

    private bool _isAnimating = false;
    private bool _isHeadless = false;

    private List<HoneycombCardData>? _sessionHandOverride = null;
    public bool HasUnsavedActiveDeck => _sessionHandOverride != null;
    
    [ObservableProperty] private HoneycombPendingSwap? _pendingSwap;
    [ObservableProperty] private string? _swapValidationError;

    public (int handIndex, int cellIndex)? ActiveHint { get; private set; }

    public bool IsPlaying => State.Phase == HoneycombPhase.Playing;
    public bool CanUndo => State.UndoStack.Count > 0 && IsPlaying && State.CurrentTurn == 1 && !_isAnimating;
    
    public event Action<string>? OnFlashBanner;

    public HoneycombViewModel(bool isHeadless = false)
    {
        _isHeadless = isHeadless;
        Options = SettingsService.LoadHoneycombOptions();
        Stats = LoadStats();
        
        WeakReferenceMessenger.Default.Register<OptionsChangedMessage>(this, (_, m) =>
        {
            var oldOpts = SettingsService.LoadOptions();
            Options = SettingsService.LoadHoneycombOptions();
            var newOpts = SettingsService.LoadOptions();
            if (oldOpts.HoneycombActiveDeckIndex != newOpts.HoneycombActiveDeckIndex || 
                oldOpts.IsNoStressMode != newOpts.IsNoStressMode)
            {
                _sessionHandOverride = null;
                OnPropertyChanged(nameof(HasUnsavedActiveDeck));
            }
            NotifyStateChanged();
        });
    }

    private List<HoneycombRule> DetermineActiveRules()
    {
        if (Options.ForceNormalRules) return new List<HoneycombRule>();

        if (Options.ManualRules != null && Options.ManualRules.Count > 0)
        {
            return Options.ManualRules.ToList();
        }

        var pool = Enum.GetValues<HoneycombRule>().ToList();
        
        // Remove banned rules from pool
        if (Options.BannedRules != null)
        {
            pool.RemoveAll(r => Options.BannedRules.Contains(r.ToString()));
        }
        
        
        if (Options.Difficulty == "Easy")
        {
            pool.Remove(HoneycombRule.Ascension);
            pool.Remove(HoneycombRule.Descension);
            pool.Remove(HoneycombRule.FallenAce);
        }

        // If Normal Mode is banned, force at least 1 rule
        int minRules = (Options.BannedRules != null && Options.BannedRules.Contains("Normal Mode")) ? 1 : 0;
        int maxRules = Math.Min(2, pool.Count);
        
        if (maxRules < minRules) return new List<HoneycombRule>();
        
        int count = Random.Shared.Next(minRules, maxRules + 1);
        if (count == 0) return new List<HoneycombRule>();

        var selected = new List<HoneycombRule>();
        for (int i = 0; i < count; i++)
        {
            if (pool.Count == 0) break;
            int idx = Random.Shared.Next(pool.Count);
            var r = pool[idx];
            selected.Add(r);
            pool.RemoveAt(idx);

            if (r == HoneycombRule.Ascension) pool.Remove(HoneycombRule.Descension);
            else if (r == HoneycombRule.Descension) pool.Remove(HoneycombRule.Ascension);
            else if (r == HoneycombRule.Order) pool.Remove(HoneycombRule.Chaos);
            else if (r == HoneycombRule.Chaos) pool.Remove(HoneycombRule.Order);
            else if (r == HoneycombRule.AllOpen) pool.Remove(HoneycombRule.ThreeOpen);
            else if (r == HoneycombRule.ThreeOpen) pool.Remove(HoneycombRule.AllOpen);
        }
        return selected;
    }

    public void StartNewMatch()
    {
        State.Phase = HoneycombPhase.Playing;
        State.UndoStack.Clear();
        State.ActiveRules = DetermineActiveRules();
        State.HasStolenThisMatch = false;
        State.CardsCapturedThisMatch = 0;
        State.IsSuddenDeath = false;
        
        State.Board = new HoneycombBoard();
        State.Board = new HoneycombBoard();

        if (State.ActiveRules.Contains(HoneycombRule.Ascension))
        {
            var suits = Enum.GetValues<CardSuit>().OrderBy(x => Random.Shared.Next()).Take(1).Select(s => s.ToString()).ToList();
            State.Board.AscensionDescensionSuits = suits;
        }
        else if (State.ActiveRules.Contains(HoneycombRule.Descension))
        {
            var suits = Enum.GetValues<CardSuit>().OrderBy(x => Random.Shared.Next()).Take(1).Select(s => s.ToString()).ToList();
            State.Board.AscensionDescensionSuits = suits;
        }

        var globalOpts = SettingsService.LoadOptions();
        List<int> playerIds;
        if (globalOpts.IsNoStressMode)
        {
            _sessionHandOverride = null;
            playerIds = new List<int>();
            playerIds.AddRange(HoneycombDatabase.Shared.RandomCards(5, 1).Select(c => c.Id));
            playerIds.AddRange(HoneycombDatabase.Shared.RandomCards(4, 1).Select(c => c.Id));
            playerIds.AddRange(HoneycombDatabase.Shared.RandomCards(3, 3).Select(c => c.Id));
        }
        else if (_sessionHandOverride != null && _sessionHandOverride.Count == 5)
        {
            playerIds = _sessionHandOverride.Select(c => c.Id).ToList();
        }
        else
        {
            int deckIdx = globalOpts.HoneycombActiveDeckIndex;
            var decks = HoneycombProfileManager.Shared.SavedDecks;
            if (deckIdx >= 0 && deckIdx < decks.Count && decks[deckIdx].CardIds.Count == 5)
                playerIds = decks[deckIdx].CardIds.ToList();
            else
                playerIds = HoneycombProfileManager.ComputeStartOverDeck(null);
        }
        State.PlayerHand = playerIds.Select(id => new HoneycombCard(HoneycombDatabase.Shared.Card(id)!, 1)).ToList();
        State.PlayerStartingDeck = State.PlayerHand.Select(c => c.Clone()).ToList();

        bool reverse = State.ActiveRules.Contains(HoneycombRule.Reverse);
        var comp = new List<(int stars, int count)>();
        if (!reverse)
        {
            if (Options.Difficulty == "Easy") { comp.Add((1, 4)); comp.Add((2, 1)); }
            else if (Options.Difficulty == "Medium") { comp.Add((2, 4)); comp.Add((3, 1)); }
            else if (Options.Difficulty == "Hard") { comp.Add((3, 3)); comp.Add((4, 1)); comp.Add((5, 1)); }
            else { comp.Add((3, 2)); comp.Add((4, 1)); comp.Add((5, 2)); }
        }
        else
        {
            if (Options.Difficulty == "Easy") { comp.Add((3, 3)); comp.Add((4, 1)); comp.Add((5, 1)); }
            else if (Options.Difficulty == "Medium") { comp.Add((2, 4)); comp.Add((3, 1)); }
            else if (Options.Difficulty == "Hard") { comp.Add((1, 2)); comp.Add((2, 3)); }
            else { comp.Add((1, 5)); }
        }

        State.OpponentHand = new List<HoneycombCard>();
        foreach (var (stars, count) in comp)
        {
            var cards = HoneycombDatabase.Shared.RulesAwareCards(stars, count, reverse);
            State.OpponentHand.AddRange(cards.Select(c => new HoneycombCard(c, -1)));
        }
        
        State.PlayerRevealedIds.Clear();
        State.OpponentRevealedIds.Clear();

        if (State.ActiveRules.Contains(HoneycombRule.AllOpen))
        {
            foreach (var c in State.PlayerHand) State.PlayerRevealedIds.Add(c.UniqueInstanceId);
            foreach (var c in State.OpponentHand) State.OpponentRevealedIds.Add(c.UniqueInstanceId);
        }
        else if (State.ActiveRules.Contains(HoneycombRule.ThreeOpen))
        {
            var pRand = State.PlayerHand.OrderBy(x => Random.Shared.Next()).Take(3).ToList();
            var oRand = State.OpponentHand.OrderBy(x => Random.Shared.Next()).Take(3).ToList();
            foreach (var c in pRand) State.PlayerRevealedIds.Add(c.UniqueInstanceId);
            foreach (var c in oRand) State.OpponentRevealedIds.Add(c.UniqueInstanceId);
        }
        
        if (State.ActiveRules.Contains(HoneycombRule.Swap))
        {
            int pIdx = Random.Shared.Next(State.PlayerHand.Count);
            int oIdx = Random.Shared.Next(State.OpponentHand.Count);
            
            var pCard = State.PlayerHand[pIdx];
            var oCard = State.OpponentHand[oIdx];
            
            pCard.Owner = -1;
            oCard.Owner = 1;
            
            State.PlayerHand[pIdx] = oCard;
            State.OpponentHand[oIdx] = pCard;
        }

        State.PlayerChaosIndex = null;
        State.OpponentChaosIndex = null;

        int starter = Random.Shared.Next(2) == 0 ? 1 : -1;
        if (s_consecutiveStarters >= 3)
        {
            starter = s_lastStarter == 1 ? -1 : 1;
        }
        
        if (starter == s_lastStarter) s_consecutiveStarters++;
        else
        {
            s_lastStarter = starter;
            s_consecutiveStarters = 1;
        }
        
        State.CurrentTurn = starter;
        
        var ruleNames = State.ActiveRules.Select(r => 
        {
            var name = System.Text.RegularExpressions.Regex.Replace(r.ToString(), "(\\B[A-Z])", " $1");
            if ((r == HoneycombRule.Ascension || r == HoneycombRule.Descension) && State.Board.AscensionDescensionSuits.Count > 0)
            {
                return $"{name} Suit: {string.Join(", ", State.Board.AscensionDescensionSuits)}";
            }
            return name;
        }).ToList();
        if (ruleNames.Count == 0) ruleNames.Add("Normal");
        
        string starterName = starter == 1 ? "Player" : "Opponent";
        OnFlashBanner?.Invoke($"First Move: {starterName}!\n" + string.Join(", ", ruleNames));
        
        StartTurn();
    }

    private void StartTurn()
    {
        if (!IsPlaying) return;

        ActiveHint = null;

        if (State.ActiveRules.Contains(HoneycombRule.Chaos))
        {
            if (State.CurrentTurn == 1)
                State.PlayerChaosIndex = State.PlayerHand.Count > 0 ? Random.Shared.Next(State.PlayerHand.Count) : null;
            else
                State.OpponentChaosIndex = State.OpponentHand.Count > 0 ? Random.Shared.Next(State.OpponentHand.Count) : null;
        }

        NotifyStateChanged();

        if (State.CurrentTurn == -1 && !_isAnimating)
        {
            RunAITurn();
        }
    }

    private async void RunAITurn()
    {
        _isAnimating = true;
        NotifyStateChanged();
        
        if (!_isHeadless) await Task.Delay(2500); // UI pace beat
        
        if (!IsPlaying || State.CurrentTurn != -1)
        {
            _isAnimating = false;
            NotifyStateChanged();
            return;
        }

        HoneycombDifficulty diff = Options.Difficulty switch {
            "Easy" => HoneycombDifficulty.Easy,
            "Medium" => HoneycombDifficulty.Medium,
            "Hard" => HoneycombDifficulty.Hard,
            "UltraHard" => HoneycombDifficulty.UltraHard,
            _ => HoneycombDifficulty.Medium
        };

        var knownOpponent = State.OpponentHand.Where(c => State.OpponentRevealedIds.Contains(c.UniqueInstanceId)).ToList();
        var move = HoneycombAI.FindMove(State.Board, State.OpponentHand, State.PlayerHand, State.PlayerHand.Count > State.PlayerRevealedIds.Count, new HashSet<HoneycombRule>(State.ActiveRules), diff, -1, 1, State.OpponentChaosIndex);
        if (move.HandIndex >= 0)
        {
            ExecutePlacement(move.HandIndex, move.CellIndex);
        }
        else
        {
            // Fallback if AI has no move
            _isAnimating = false;
            NotifyStateChanged();
        }
    }

    public void InitializeGame() => StartNewMatch();
    
    public void RestartGame() => StartNewMatch();

    public void Undo()
    {
        if (!CanUndo) return;
        var snap = State.UndoStack.Pop();
        
        State.Board = snap.Board;
        State.PlayerHand = snap.PlayerHand;
        State.OpponentHand = snap.OpponentHand;
        State.PlayerRevealedIds = snap.PlayerRevealedIds;
        State.OpponentRevealedIds = snap.OpponentRevealedIds;
        State.CurrentTurn = snap.CurrentTurn;
        State.CardsCapturedThisMatch = snap.CardsCapturedThisMatch;
        State.PlayerChaosIndex = snap.PlayerChaosIndex;
        State.OpponentChaosIndex = snap.OpponentChaosIndex;
        
        ActiveHint = null;
        NotifyStateChanged();
    }

    private void PushSnapshot()
    {
        var snap = new HoneycombSnapshot
        {
            Board = State.Board.Clone(),
            PlayerHand = State.PlayerHand.Select(c => c.Clone()).ToList(),
            OpponentHand = State.OpponentHand.Select(c => c.Clone()).ToList(),
            PlayerRevealedIds = new HashSet<Guid>(State.PlayerRevealedIds),
            OpponentRevealedIds = new HashSet<Guid>(State.OpponentRevealedIds),
            CurrentTurn = State.CurrentTurn,
            CardsCapturedThisMatch = State.CardsCapturedThisMatch,
            PlayerChaosIndex = State.PlayerChaosIndex,
            OpponentChaosIndex = State.OpponentChaosIndex
        };
        State.UndoStack.Push(snap);
    }

    public void PlayCard(int handIndex, int cellIndex)
    {
        if (!IsPlaying || State.CurrentTurn != 1 || _isAnimating) return;
        if (handIndex < 0 || handIndex >= State.PlayerHand.Count) return;
        
        if (State.ActiveRules.Contains(HoneycombRule.Order) && handIndex != 0) return;
        if (State.ActiveRules.Contains(HoneycombRule.Chaos) && State.PlayerChaosIndex.HasValue && handIndex != State.PlayerChaosIndex.Value) return;

        PushSnapshot();
        ExecutePlacement(handIndex, cellIndex);
    }

    private void ExecutePlacement(int handIndex, int cellIndex)
    {
        var hand = State.CurrentTurn == 1 ? State.PlayerHand : State.OpponentHand;
        var card = hand[handIndex];
        
        var boardCopy = State.Board.Clone();
        int preScore = State.CurrentTurn == 1 ? CountPlayerCards(boardCopy, hand) : CountOpponentCards(boardCopy, hand);
        int preCombo = boardCopy.SessionSamePlusTriggers;
        int preFA = boardCopy.SessionFallenAceCaptures;

        if (!State.Board.Cells[cellIndex].IsEmpty)
        {
            _isAnimating = false;
            NotifyStateChanged();
            return;
        }

        var flipped = State.Board.PlaceCard(card, cellIndex, new HashSet<HoneycombRule>(State.ActiveRules));
        hand.RemoveAt(handIndex);
        
        int postScore = State.CurrentTurn == 1 ? CountPlayerCards(State.Board, hand) : CountOpponentCards(State.Board, hand);
            // cards captured = net difference, but actually that counts cards we placed minus what we had before.
            // Better to compute captures explicitly or let Stats handle it.
            if (State.CurrentTurn == 1)
            {
                State.CardsCapturedThisMatch += Math.Max(0, postScore - preScore); // preScore already includes the card placed from hand
            }

        if (IsBoardFull())
        {
            SettleMatch();
        }
        else
        {
            State.CurrentTurn = State.CurrentTurn == 1 ? -1 : 1;
            _isAnimating = false;
            StartTurn();
        }
    }

    private bool IsBoardFull()
    {
        for (int i=0; i<9; i++) if (State.Board.Cells[i].IsEmpty) return false;
        return true;
    }

    private int CountPlayerCards(HoneycombBoard board, List<HoneycombCard> hand)
    {
        int total = hand.Count;
        for (int i=0; i<9; i++)
            if (!board.Cells[i].IsEmpty && board.Cells[i].Card!.Owner == 1) total++;
        return total;
    }
    private int CountOpponentCards(HoneycombBoard board, List<HoneycombCard> hand)
    {
        int total = hand.Count;
        for (int i=0; i<9; i++)
            if (!board.Cells[i].IsEmpty && board.Cells[i].Card!.Owner == -1) total++;
        return total;
    }

    private void SettleMatch()
    {
        State.PlayerScore = CountPlayerCards(State.Board, State.PlayerHand);
        State.OpponentScore = CountOpponentCards(State.Board, State.OpponentHand);

        if (State.PlayerScore == State.OpponentScore)
        {
            TriggerSuddenDeath();
            return;
        }

        bool won = State.PlayerScore > State.OpponentScore;
        bool drawn = false;
        bool flawless = State.OpponentScore == 0;
        
        Stats.RecordGame(won, drawn, State.CardsCapturedThisMatch, State.Board.SessionSamePlusTriggers, flawless, Options.Difficulty, State.Board.SessionFallenAceCaptures);
        SaveStats();

        State.Phase = HoneycombPhase.Result;
        _isAnimating = false;
        NotifyStateChanged();
    }

    private void TriggerSuddenDeath()
    {
        State.IsSuddenDeath = true;
        Stats.SuddenDeathCount++;
        SaveStats();

        var pHand = new List<HoneycombCard>(State.PlayerHand);
        var oHand = new List<HoneycombCard>(State.OpponentHand);
        for (int i=0; i<9; i++)
        {
            var c = State.Board.Cells[i].Card;
            if (c != null)
            {
                c.Modifier = 0;
                if (c.Owner == 1) pHand.Add(c);
                else oHand.Add(c);
            }
        }

        State.PlayerHand = pHand;
        State.OpponentHand = oHand;

        var suits = State.Board.AscensionDescensionSuits;
        State.Board = new HoneycombBoard();
        State.Board.AscensionDescensionSuits = suits;
        
        State.UndoStack.Clear();
        State.CurrentTurn = State.CurrentTurn == 1 ? -1 : 1; // flip who starts
        
        StartTurn();
    }

    public void FindHint()
    {
        if (!IsPlaying || State.CurrentTurn != 1 || _isAnimating) return;
        
        var knownOpponent = State.OpponentHand.Where(c => State.OpponentRevealedIds.Contains(c.UniqueInstanceId)).ToList();
        
        var move = HoneycombAI.FindMove(State.Board, State.PlayerHand, knownOpponent, false, new HashSet<HoneycombRule>(State.ActiveRules), HoneycombDifficulty.UltraHard, 1, -1, null);
        if (move.HandIndex >= 0)
        {
            ActiveHint = move;
            NotifyStateChanged();
        }
    }

    private static string GetLocalFolderPath()
    {
        try
        {
            var appDataType = Type.GetType("Windows.Storage.ApplicationData, Windows, Version=255.255.255.255, Culture=neutral, PublicKeyToken=null, ContentType=WindowsRuntime");
            if (appDataType != null)
            {
                var currentProp = appDataType.GetProperty("Current", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static);
                var currentInstance = currentProp?.GetValue(null);
                if (currentInstance != null)
                {
                    var localFolderProp = currentInstance.GetType().GetProperty("LocalFolder", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance);
                    var localFolderInstance = localFolderProp?.GetValue(currentInstance);
                    if (localFolderInstance != null)
                    {
                        var pathProp = localFolderInstance.GetType().GetProperty("Path", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance);
                        var path = pathProp?.GetValue(localFolderInstance) as string;
                        if (!string.IsNullOrEmpty(path)) return path;
                    }
                }
            }
        }
        catch { }
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SoliBee");
    }

    private static string DataDir => GetLocalFolderPath();
    private static string OptionsPath => Path.Combine(DataDir, "honeycomb_options.json");
    private static string StatisticsPath => Path.Combine(DataDir, "honeycomb_stats.json");

    public void SaveOptions()
    {
        SettingsService.SaveHoneycombOptions(Options);
    }

    private void SaveStats()
    {
        try { Directory.CreateDirectory(DataDir); File.WriteAllText(StatisticsPath, JsonSerializer.Serialize(Stats, new JsonSerializerOptions { WriteIndented = true })); }
        catch { }
    }

    public static HoneycombStats LoadStats()
    {
        try { if (File.Exists(StatisticsPath)) { var s = JsonSerializer.Deserialize<HoneycombStats>(File.ReadAllText(StatisticsPath)); if (s != null) return s; } }
        catch { }
        return new HoneycombStats();
    }

    private void NotifyStateChanged()
    {
        if (State != null)
        {
            State.PlayerScore = CountPlayerCards(State.Board, State.PlayerHand);
            State.OpponentScore = CountOpponentCards(State.Board, State.OpponentHand);
        }
        OnPropertyChanged(nameof(State));
        OnPropertyChanged(nameof(IsPlaying));
        OnPropertyChanged(nameof(CanUndo));
        OnPropertyChanged(nameof(ActiveHint));
    }

    public void ResetStats()
    {
        Stats = new HoneycombStats();
        SaveStats();
    }

    public void RequestSwap(int boardIndex, int replaceHandIndex)
    {
        if (State.HasStolenThisMatch) return;
        if (State.PlayerScore <= State.OpponentScore) return; // Must win to steal
        var incoming = State.Board.Cells[boardIndex].Card;
        if (incoming == null || incoming.OriginalOwner != -1 || incoming.Owner != 1) return;
        if (HoneycombProfileManager.Shared.UnlockedCardIds.Contains(incoming.Data.Id)) return;
        
        var playerStartingDeck = _sessionHandOverride != null ? _sessionHandOverride : State.PlayerStartingDeck.Select(c => c.Data).ToList();
        if (replaceHandIndex < 0 || replaceHandIndex >= playerStartingDeck.Count) return;

        var hypotheticalDeck = new List<HoneycombCardData>(playerStartingDeck);
        hypotheticalDeck[replaceHandIndex] = incoming.Data;

        int fiveStars = hypotheticalDeck.Count(c => c.Stars == 5);
        int fourStars = hypotheticalDeck.Count(c => c.Stars == 4);
        
        if (fiveStars > 1) { SwapValidationError = "Max 1 card of 5★ allowed."; return; }
        if (fiveStars == 1 && fourStars > 1) { SwapValidationError = "Max 1 card of 4★ when a 5★ is present."; return; }
        if (fiveStars == 0 && fourStars > 2) { SwapValidationError = "Max 2 cards of 4★ allowed."; return; }

        var outgoing = playerStartingDeck[replaceHandIndex];
        SwapValidationError = null;
        PendingSwap = new HoneycombPendingSwap(boardIndex, replaceHandIndex, incoming.Data.Name, outgoing.Name);
    }

    public void CancelPendingSwap()
    {
        PendingSwap = null;
        SwapValidationError = null;
    }

    public void ConfirmPendingSwap()
    {
        if (PendingSwap == null) return;
        var swap = PendingSwap;
        PendingSwap = null;
        
        var incoming = State.Board.Cells[swap.BoardIndex].Card;
        if (incoming == null || incoming.OriginalOwner != -1) return;

        HoneycombProfileManager.Shared.UnlockCard(incoming.Data.Id);
        Stats.CardsStolen++;
        SaveStats();
        State.HasStolenThisMatch = true;

        var playerStartingDeck = _sessionHandOverride != null ? new List<HoneycombCardData>(_sessionHandOverride) : State.PlayerStartingDeck.Select(c => c.Data).ToList();
        playerStartingDeck[swap.ReplaceHandIndex] = incoming.Data;
        _sessionHandOverride = playerStartingDeck;
        OnPropertyChanged(nameof(HasUnsavedActiveDeck));
    }
}
