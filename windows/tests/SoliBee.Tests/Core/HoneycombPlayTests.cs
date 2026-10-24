using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.Core;

// Honeycomb play on hand-built boards: Capped Brood's face-down countdown and the reveal,
// and the Hint button. (Mac: HoneycombBombShelterTests and the hint tests.)
public class HoneycombPlayTests : DataSandbox
{
    private static HoneycombViewModel NewVm()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        vm.Options = new HoneycombOptions { ForceNormalRules = true };
        vm.State.Phase = HoneycombPhase.Playing;
        vm.State.CurrentTurn = 1;
        vm.State.ActiveRules = new List<HoneycombRule>();
        vm.State.Board = new HoneycombBoard();
        vm.State.PlayerHand = new List<HoneycombCard>();
        vm.State.OpponentHand = new List<HoneycombCard>();
        return vm;
    }

    private static int _nextId = 70_000;

    private static HoneycombCard Mk(int owner, params int[] stats) =>
        new(new HoneycombCardData { Id = _nextId++, Name = "C" + _nextId, Stars = 3, Stats = stats, Suit = "S" }, owner);

    // ---- Capped Brood (Bomb Shelter) ----

    private static void Tick(HoneycombViewModel vm, int justPlaced, Action completion) =>
        Reflect.Call(vm, "AdvanceBombShelterTimers", justPlaced, completion);

    [Fact]
    public void ACappedBroodCard_CountsDownOncePerTurn_AndFlipsUpOnTheThird()
    {
        var vm = NewVm();
        vm.State.ActiveRules = new List<HoneycombRule> { HoneycombRule.BombShelter };
        var hidden = Mk(1, 5, 5, 5, 5);
        hidden.IsFaceDown = true;
        hidden.BombShelterTurnsRemaining = 3;
        vm.State.Board.Cells[0].Card = hidden;

        int completed = 0;
        Tick(vm, 8, () => completed++);
        Assert.Equal(2, vm.State.Board.Cells[0].Card!.BombShelterTurnsRemaining);
        Assert.True(vm.State.Board.Cells[0].Card!.IsFaceDown);
        Assert.Equal(1, completed);               // the turn carries on straight away when nothing is revealed

        Tick(vm, 8, () => completed++);
        Assert.Equal(1, vm.State.Board.Cells[0].Card!.BombShelterTurnsRemaining);
        Assert.True(vm.State.Board.Cells[0].Card!.IsFaceDown);

        Tick(vm, 8, () => completed++);           // third turn: it flips
        var revealed = vm.State.Board.Cells[0].Card!;
        Assert.False(revealed.IsFaceDown);
        Assert.Null(revealed.BombShelterTurnsRemaining);
        Assert.Equal(3, completed);               // and the turn still carries on once the reveal is done
    }

    [Fact]
    public void TheCardJustPlayed_DoesNotCountItsOwnTurn()
    {
        var vm = NewVm();
        var hidden = Mk(1, 5, 5, 5, 5);
        hidden.IsFaceDown = true;
        hidden.BombShelterTurnsRemaining = 3;
        vm.State.Board.Cells[4].Card = hidden;
        Tick(vm, 4, () => { });
        Assert.Equal(3, vm.State.Board.Cells[4].Card!.BombShelterTurnsRemaining);
    }

    [Fact]
    public void ARevealedCard_CapturesNeighboursItBeats()
    {
        var vm = NewVm();
        var hidden = Mk(1, 9, 9, 9, 9);
        hidden.IsFaceDown = true;
        hidden.BombShelterTurnsRemaining = 1;
        var victimRight = Mk(-1, 1, 1, 1, 1);
        var victimBelow = Mk(-1, 1, 1, 1, 1);
        vm.State.Board.Cells[0].Card = hidden;
        vm.State.Board.Cells[1].Card = victimRight;
        vm.State.Board.Cells[3].Card = victimBelow;

        Tick(vm, 8, () => { });

        Assert.Equal(1, vm.State.Board.Cells[1].Card!.Owner);
        Assert.Equal(1, vm.State.Board.Cells[3].Card!.Owner);
        Assert.Equal(-1, vm.State.Board.Cells[1].Card!.OriginalOwner);   // still the opponent's card to steal
    }

    [Fact]
    public void FaceUpCardsAndEmptyCells_AreIgnoredByTheCountdown()
    {
        var vm = NewVm();
        var faceUp = Mk(1, 5, 5, 5, 5);
        faceUp.BombShelterTurnsRemaining = 2;   // not face down, so never ticks
        vm.State.Board.Cells[2].Card = faceUp;
        int completed = 0;
        Tick(vm, 8, () => completed++);
        Assert.Equal(2, faceUp.BombShelterTurnsRemaining);
        Assert.Equal(1, completed);
    }

    [Fact]
    public void TwoCardsDueOnTheSameTurn_BothReveal()
    {
        var vm = NewVm();
        var a = Mk(1, 5, 5, 5, 5); a.IsFaceDown = true; a.BombShelterTurnsRemaining = 1;
        var b = Mk(-1, 5, 5, 5, 5); b.IsFaceDown = true; b.BombShelterTurnsRemaining = 1;
        vm.State.Board.Cells[0].Card = a;
        vm.State.Board.Cells[8].Card = b;
        int completed = 0;
        Tick(vm, 4, () => completed++);
        Assert.False(vm.State.Board.Cells[0].Card!.IsFaceDown);
        Assert.False(vm.State.Board.Cells[8].Card!.IsFaceDown);
        Assert.Equal(1, completed);   // one turn switch, not two
    }

    // ---- Hints ----

    private static (int handIndex, int cellIndex)? WaitForHint(HoneycombViewModel vm, int timeoutMs = 8000)
    {
        var deadline = DateTime.UtcNow.AddMilliseconds(timeoutMs);
        while (DateTime.UtcNow < deadline)
        {
            if (vm.ActiveHint != null) return vm.ActiveHint;
            Thread.Sleep(10);
        }
        return null;
    }

    private static void FillBoardExcept(HoneycombViewModel vm, int emptyCell)
    {
        for (int i = 0; i < 9; i++)
            if (i != emptyCell) vm.State.Board.Cells[i].Card = Mk(i % 2 == 0 ? 1 : -1, 5, 5, 5, 5);
    }

    [Fact]
    public void Hint_WithOneCardAndOneEmptyCell_PointsAtThatMove()
    {
        var vm = NewVm();
        FillBoardExcept(vm, 4);
        vm.State.PlayerHand = new List<HoneycombCard> { Mk(1, 6, 6, 6, 6) };
        vm.State.OpponentHand = new List<HoneycombCard>();
        vm.FindHint();
        var hint = WaitForHint(vm);
        Assert.NotNull(hint);
        Assert.Equal((0, 4), hint!.Value);
    }

    [Fact]
    public void Hint_PicksARealCardAndARealEmptyCell()
    {
        var vm = NewVm();
        vm.State.Board.Cells[0].Card = Mk(-1, 3, 3, 3, 3);
        vm.State.PlayerHand = new List<HoneycombCard> { Mk(1, 9, 1, 9, 1), Mk(1, 2, 2, 2, 2), Mk(1, 8, 8, 8, 8) };
        vm.State.OpponentHand = new List<HoneycombCard> { Mk(-1, 5, 5, 5, 5), Mk(-1, 4, 4, 4, 4) };
        vm.FindHint();
        var hint = WaitForHint(vm);
        Assert.NotNull(hint);
        Assert.InRange(hint!.Value.handIndex, 0, 2);
        Assert.True(vm.State.Board.Cells[hint.Value.cellIndex].IsEmpty);
    }

    [Fact]
    public void Hint_UnderOrder_AlwaysPointsAtTheFirstCard()
    {
        var vm = NewVm();
        vm.State.ActiveRules = new List<HoneycombRule> { HoneycombRule.Order };
        FillBoardExcept(vm, 7);
        vm.State.PlayerHand = new List<HoneycombCard> { Mk(1, 2, 2, 2, 2), Mk(1, 9, 9, 9, 9) };
        vm.FindHint();
        var hint = WaitForHint(vm);
        Assert.NotNull(hint);
        Assert.Equal(0, hint!.Value.handIndex);   // you must play the card in order
    }

    [Fact]
    public void Hint_IsNotGiven_OffYourTurn_OutsideAMatch_OrWithNoCards()
    {
        var vm = NewVm();
        vm.State.PlayerHand = new List<HoneycombCard> { Mk(1, 5, 5, 5, 5) };

        vm.State.CurrentTurn = -1;
        vm.FindHint();
        Thread.Sleep(200);
        Assert.Null(vm.ActiveHint);

        vm.State.CurrentTurn = 1;
        vm.State.Phase = HoneycombPhase.Result;
        vm.FindHint();
        Thread.Sleep(200);
        Assert.Null(vm.ActiveHint);

        vm.State.Phase = HoneycombPhase.Playing;
        vm.State.PlayerHand = new List<HoneycombCard>();
        vm.FindHint();
        Thread.Sleep(200);
        Assert.Null(vm.ActiveHint);
    }

    [Fact]
    public void AHint_IsClearedWhenANewMatchStarts()
    {
        var vm = NewVm();
        FillBoardExcept(vm, 4);
        vm.State.PlayerHand = new List<HoneycombCard> { Mk(1, 6, 6, 6, 6) };
        vm.FindHint();
        Assert.NotNull(WaitForHint(vm));
        vm.StartNewMatch();
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);
        Assert.Null(vm.ActiveHint);
    }
}
