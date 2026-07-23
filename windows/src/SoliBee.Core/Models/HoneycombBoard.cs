using System;
using System.Collections.Generic;
using System.Linq;

namespace SoliBee.Core.Models;

public class HoneycombCell
{
    public HoneycombCard? Card { get; set; }
    public bool IsEmpty => Card == null;
}

public class HoneycombBoard
{
    public HoneycombCell[] Cells { get; } = new HoneycombCell[9];

    public int SessionSamePlusTriggers { get; set; }
    public int SessionFallenAceCaptures { get; set; }

    public bool LastSameTriggered { get; private set; }
    public bool LastPlusTriggered { get; private set; }
    public bool LastFallenAceTriggered { get; private set; }
    public int LastComboFlipCount { get; private set; }

    public List<string> AscensionDescensionSuits { get; set; } = new();

    public HoneycombBoard()
    {
        for (int i = 0; i < 9; i++) Cells[i] = new HoneycombCell();
    }

    public HoneycombBoard Clone()
    {
        var clone = new HoneycombBoard
        {
            SessionSamePlusTriggers = this.SessionSamePlusTriggers,
            SessionFallenAceCaptures = this.SessionFallenAceCaptures,
            LastSameTriggered = this.LastSameTriggered,
            LastPlusTriggered = this.LastPlusTriggered,
            LastFallenAceTriggered = this.LastFallenAceTriggered,
            LastComboFlipCount = this.LastComboFlipCount,
            AscensionDescensionSuits = new List<string>(this.AscensionDescensionSuits)
        };
        for (int i = 0; i < 9; i++)
        {
            if (!this.Cells[i].IsEmpty)
            {
                var c = this.Cells[i].Card!;
                clone.Cells[i].Card = new HoneycombCard(c.Data, c.Owner)
                {
                    Modifier = c.Modifier,
                    OriginalOwner = c.OriginalOwner
                };
            }
        }
        return clone;
    }

    public List<int> PlaceCard(HoneycombCard card, int index, HashSet<HoneycombRule> rules, bool skipCaptures = false)
    {
        if (index < 0 || index >= 9 || !Cells[index].IsEmpty)
            return new List<int>();

        Cells[index].Card = card;

        LastSameTriggered = false;
        LastPlusTriggered = false;
        LastFallenAceTriggered = false;
        LastComboFlipCount = 0;

        UpdateModifiers(rules);

        if (skipCaptures) return new List<int>();

        var flipped = ResolveCaptures(index, rules, isCombo: false);
        return flipped;
    }

    public List<int> RevealFaceDownCard(int index, HashSet<HoneycombRule> rules)
    {
        if (index < 0 || index >= 9 || Cells[index].IsEmpty || !Cells[index].Card!.IsFaceDown) return new List<int>();

        Cells[index].Card!.IsFaceDown = false;
        
        // Cannot trigger combos, so we remove Same, Plus, FallenAce temporarily for this capture
        var ruleClone = new HashSet<HoneycombRule>(rules);
        ruleClone.Remove(HoneycombRule.Same);
        ruleClone.Remove(HoneycombRule.Plus);
        ruleClone.Remove(HoneycombRule.FallenAce);

        LastSameTriggered = false;
        LastPlusTriggered = false;
        LastFallenAceTriggered = false;
        LastComboFlipCount = 0;

        return ResolveCaptures(index, ruleClone, isCombo: false);
    }

    private void UpdateModifiers(HashSet<HoneycombRule> rules)
    {
        bool ascension = rules.Contains(HoneycombRule.Ascension);
        bool descension = rules.Contains(HoneycombRule.Descension);

        if (!ascension && !descension)
        {
            foreach (var cell in Cells)
                if (!cell.IsEmpty)
                    cell.Card!.Modifier = 0;
            return;
        }

        var suitCounts = new Dictionary<string, int>();
        foreach (var suit in AscensionDescensionSuits)
            suitCounts[suit] = 0;

        foreach (var cell in Cells)
        {
            if (!cell.IsEmpty && AscensionDescensionSuits.Contains(cell.Card!.Data.Suit))
            {
                suitCounts[cell.Card.Data.Suit]++;
            }
        }

        foreach (var cell in Cells)
        {
            if (cell.IsEmpty) continue;

            if (AscensionDescensionSuits.Contains(cell.Card!.Data.Suit))
            {
                int count = suitCounts[cell.Card.Data.Suit];
                if (ascension)
                    cell.Card.Modifier = count;
                else if (descension)
                    cell.Card.Modifier = -count;
            }
            else
            {
                cell.Card.Modifier = 0;
            }
        }
    }

    private List<int> ResolveCaptures(int index, HashSet<HoneycombRule> rules, bool isCombo)
    {
        var attacker = Cells[index].Card!;
        var flippedThisTurn = new List<int>();
        var comboQueue = new List<int>();
        var neighbors = GetNeighbors(index).Where(n => !Cells[n.Index].Card!.IsFaceDown).ToList();
        var samePlusFlipped = new HashSet<int>();

        if (!isCombo)
        {
            var sameMatches = new List<int>();
            var plusSums = new Dictionary<int, List<int>>();

            foreach (var n in neighbors)
            {
                var neighborCard = Cells[n.Index].Card!;
                int attackerStat = attacker.Stat(n.AttackerEdge);
                int neighborStat = neighborCard.Stat(n.NeighborEdge);

                if (attackerStat == neighborStat)
                {
                    sameMatches.Add(n.Index);
                }

                int sum = attackerStat + neighborStat;
                if (!plusSums.ContainsKey(sum)) plusSums[sum] = new List<int>();
                plusSums[sum].Add(n.Index);
            }

            var triggers = new HashSet<int>();

            if (rules.Contains(HoneycombRule.Same) && sameMatches.Count >= 2)
            {
                foreach (var idx in sameMatches) triggers.Add(idx);
            }

            if (rules.Contains(HoneycombRule.Plus))
            {
                foreach (var kvp in plusSums)
                {
                    if (kvp.Value.Count >= 2)
                    {
                        foreach (var idx in kvp.Value) triggers.Add(idx);
                    }
                }
            }

            bool samePlusActualFlip = false;
            foreach (var idx in triggers)
            {
                var targetCard = Cells[idx].Card!;
                if (targetCard.Owner != attacker.Owner)
                {
                    samePlusActualFlip = true;
                    if (rules.Contains(HoneycombRule.Same) && sameMatches.Contains(idx)) LastSameTriggered = true;
                    if (rules.Contains(HoneycombRule.Plus) && plusSums.Values.Any(list => list.Count >= 2 && list.Contains(idx))) LastPlusTriggered = true;
                    
                    targetCard.Owner = attacker.Owner;
                    flippedThisTurn.Add(idx);
                    comboQueue.Add(idx);
                }
                samePlusFlipped.Add(idx);
            }

            if (samePlusActualFlip)
            {
                SessionSamePlusTriggers++;
            }
        }

        foreach (var n in neighbors)
        {
            if (samePlusFlipped.Contains(n.Index)) continue;

            var targetCard = Cells[n.Index].Card!;
            if (targetCard.Owner == attacker.Owner) continue;

            int attackerStat = attacker.Stat(n.AttackerEdge);
            int targetStat = targetCard.Stat(n.NeighborEdge);
            int baseAttackerStat = attacker.Data.Stats[n.AttackerEdge];
            int baseTargetStat = targetCard.Data.Stats[n.NeighborEdge];

            if (CanCapture(attackerStat, targetStat, rules))
            {
                if (baseAttackerStat == 1 && baseTargetStat == 10)
                {
                    SessionFallenAceCaptures++;
                }

                if (rules.Contains(HoneycombRule.FallenAce))
                {
                    bool reverse = rules.Contains(HoneycombRule.Reverse);
                    if ((!reverse && attackerStat == 1 && targetStat == 10) ||
                        (reverse && attackerStat == 10 && targetStat == 1))
                    {
                        LastFallenAceTriggered = true;
                    }
                }

                targetCard.Owner = attacker.Owner;
                flippedThisTurn.Add(n.Index);
                if (isCombo)
                {
                    LastComboFlipCount++;
                    comboQueue.Add(n.Index);
                }
            }
        }

        foreach (var comboIndex in comboQueue)
        {
            flippedThisTurn.AddRange(ResolveCaptures(comboIndex, rules, isCombo: true));
        }

        return flippedThisTurn;
    }

    private bool CanCapture(int attackerStat, int targetStat, HashSet<HoneycombRule> rules)
    {
        bool reverse = rules.Contains(HoneycombRule.Reverse);
        bool fallenAce = rules.Contains(HoneycombRule.FallenAce);

        if (fallenAce)
        {
            if (!reverse)
            {
                if (attackerStat == 1 && targetStat == 10) return true;
                if (attackerStat == 10 && targetStat == 1) return false;
            }
            else
            {
                if (attackerStat == 10 && targetStat == 1) return true;
                if (attackerStat == 1 && targetStat == 10) return false;
            }
        }

        if (reverse) return attackerStat < targetStat;
        return attackerStat > targetStat;
    }

    private List<(int Index, int AttackerEdge, int NeighborEdge)> GetNeighbors(int idx)
    {
        var result = new List<(int, int, int)>();
        int row = idx / 3;
        int col = idx % 3;

        if (row > 0 && !Cells[idx - 3].IsEmpty) result.Add((idx - 3, 0, 2)); // Top
        if (col < 2 && !Cells[idx + 1].IsEmpty) result.Add((idx + 1, 1, 3)); // Right
        if (row < 2 && !Cells[idx + 3].IsEmpty) result.Add((idx + 3, 2, 0)); // Bottom
        if (col > 0 && !Cells[idx - 1].IsEmpty) result.Add((idx - 1, 3, 1)); // Left

        return result;
    }
}
