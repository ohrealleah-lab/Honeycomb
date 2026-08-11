using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using Xunit;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;

namespace SoliBee.Tests.Core;

// Regression coverage that the ~50 gameplay conditions wired into HoneycombViewModel
// actually FIRE — mirrors mac's HoneycombBannerTriggerTests.swift. Drives
// HoneycombViewModel through its real public API and asserts the right banner shows
// up, either in MatchResultFlavorText (win/lose overlay flavor) or the mid-match
// banner queue (captured via the OnFlashBanner event — there's no public "peek the
// queue" property on this port, unlike Swift's flashRuleBanner).
//
// Not covered here (left to manual playtesting — see the test plan discussion): the
// two Nectar Exchange swap-outcome variants (which card gets swapped is random, not
// forceable through the public API) and the rules-banner 80/20 gate's actual hit rate
// (a statistical property, not a pass/fail condition).
public class HoneycombBannerTriggerTests
{
    private static HoneycombCard MkCard(int id, int owner, int[]? stats = null, int stars = 3, string suit = "S") =>
        new(new HoneycombCardData { Id = id, Name = $"C{id}", Stars = stars, Stats = stats ?? new[] { 5, 5, 5, 5 }, Suit = suit }, owner);

    // Unbeatable on every side — used for cards that must survive a neighboring
    // placement without getting captured back, so a forced board's owner counts stay
    // exactly as constructed.
    private static HoneycombCard MkFortressCard(int id, int owner) =>
        MkCard(id, owner, stats: new[] { 10, 10, 10, 10 });

    // Too weak to capture anything — used for the one card actually placed via the
    // public API in these tests, so it can't disturb a fortress board's owner counts.
    private static HoneycombCard MkWeakCard(int id, int owner) =>
        MkCard(id, owner, stats: new[] { 1, 1, 1, 1 });

    // RunAITurn (the opponent's-move entry point) has no public equivalent on this
    // port — PlayCard is public, but there's no way to invoke the opponent's own turn
    // in isolation except through this same private method the AI itself calls.
    // Mirrors the reflection pattern BlackjackViewModelTests.cs already uses for the
    // same reason (invoking DealerPlay directly).
    private static void RunAiTurn(HoneycombViewModel vm)
    {
        var method = typeof(HoneycombViewModel).GetMethod("RunAITurn", BindingFlags.NonPublic | BindingFlags.Instance);
        method!.Invoke(vm, new object[] { true }); // skipPacingDelay: true
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);
    }

    // Captures every banner text shown while `action` runs, in order — subscribes to
    // OnFlashBanner (fired on enqueue-when-empty and on AdvanceBannerQueue revealing
    // the next one), then drains whatever's left in the queue afterward so a
    // multi-banner sequence is fully captured, not just its first entry.
    private static List<string> CaptureBanners(HoneycombViewModel vm, Action action)
    {
        var captured = new List<string>();
        void Handler(string text, bool isLongDuration) => captured.Add(text);
        vm.OnFlashBanner += Handler;
        action();
        for (int i = 0; i < 50; i++) vm.AdvanceBannerQueue();
        vm.OnFlashBanner -= Handler;
        return captured;
    }

    private static List<string> CatalogMessages(BannerId id) => BannerCatalog.Definition(id)?.Messages ?? new List<string>();

    // Catalog messages can carry "{Token}" placeholders (e.g. "{OpponentName}
    // prepares a final sting!") that get substituted before the text ever reaches the
    // banner queue/MatchResultFlavorText — matching post-substitution text against
    // the raw catalog string can't be a plain substring check. This instead checks
    // that every literal (non-token) chunk of the raw message shows up in the
    // haystack, which is robust to whatever the token got replaced with.
    private static IEnumerable<string> LiteralChunks(string raw) =>
        System.Text.RegularExpressions.Regex.Split(raw, @"\{[^}]+\}").Where(s => !string.IsNullOrEmpty(s));

    private static bool Matches(string haystack, string rawCatalogMessage)
    {
        var chunks = LiteralChunks(rawCatalogMessage).ToList();
        if (chunks.Count == 0) return !string.IsNullOrEmpty(haystack);
        return chunks.All(haystack.Contains);
    }

    private static bool QueueContainsMessage(List<string> queue, params BannerId[] ids)
    {
        var rawMessages = ids.SelectMany(CatalogMessages).ToList();
        return queue.Any(haystack => rawMessages.Any(raw => Matches(haystack, raw)));
    }

    private static bool FlavorContainsMessage(string? text, params BannerId[] ids)
    {
        if (text == null) return false;
        return QueueContainsMessage(new List<string> { text }, ids);
    }

    // MARK: - Win/Lose overlay flavor

    [Fact]
    public void FlawlessWin_FiresFlavorAndMilestone()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        vm.State.Phase = HoneycombPhase.Playing;
        vm.State.CurrentTurn = 1;
        vm.State.ActiveRules = new List<HoneycombRule>();
        vm.Stats.MatchesWon = 9; // this win should cross the 10-win milestone

        var board = new HoneycombBoard();
        for (int i = 0; i < 8; i++) board.Cells[i].Card = MkFortressCard(i, 1);
        vm.State.Board = board;
        vm.State.PlayerHand = new List<HoneycombCard> { MkWeakCard(100, 1) };
        vm.State.OpponentHand = new List<HoneycombCard>();

        var queued = CaptureBanners(vm, () => vm.PlayCard(0, 8));

        Assert.True(vm.State.PlayerScore > vm.State.OpponentScore);
        Assert.True(FlavorContainsMessage(vm.MatchResultFlavorText,
            BannerId.RuleSpecificPlayerWinsFlawlessOpponentScore0, BannerId.GameplayPlayerWinsByTheMaximumPossibleMargin));
        Assert.True(QueueContainsMessage(queued, BannerId.MilestonesPlayerReaches10TotalWins));
    }

    [Fact]
    public void FlawlessLoss_FiresFlavor()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        vm.State.Phase = HoneycombPhase.Playing;
        vm.State.CurrentTurn = -1;
        vm.State.ActiveRules = new List<HoneycombRule>();

        var board = new HoneycombBoard();
        for (int i = 0; i < 8; i++) board.Cells[i].Card = MkFortressCard(i, -1);
        vm.State.Board = board;
        vm.State.OpponentHand = new List<HoneycombCard> { MkWeakCard(200, -1) };
        vm.State.PlayerHand = new List<HoneycombCard>();

        CaptureBanners(vm, () => RunAiTurn(vm));

        Assert.True(vm.State.OpponentScore > vm.State.PlayerScore);
        Assert.True(FlavorContainsMessage(vm.MatchResultFlavorText, BannerId.RuleSpecificPlayerLosesFlawless0Captures));
    }

    [Fact]
    public void WinWith4RulesActive_FiresFlavor()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        vm.State.Phase = HoneycombPhase.Playing;
        vm.State.CurrentTurn = 1;
        // All four are legality/reveal-only rules — none change capture math, so the
        // forced fortress board's owner counts land exactly as constructed.
        vm.State.ActiveRules = new List<HoneycombRule> { HoneycombRule.AllOpen, HoneycombRule.ThreeOpen, HoneycombRule.Order, HoneycombRule.Chaos };

        var board = new HoneycombBoard();
        for (int i = 0; i < 5; i++) board.Cells[i].Card = MkFortressCard(i, 1);
        for (int i = 5; i < 8; i++) board.Cells[i].Card = MkFortressCard(i, -1);
        vm.State.Board = board;
        vm.State.PlayerHand = new List<HoneycombCard> { MkWeakCard(300, 1) };
        vm.State.OpponentHand = new List<HoneycombCard>();

        vm.PlayCard(0, 8);

        Assert.True(vm.State.PlayerScore > vm.State.OpponentScore);
        Assert.True(FlavorContainsMessage(vm.MatchResultFlavorText, BannerId.GameplayPlayerWinsAMatchWith4RulesActiveAtOnce));
    }

    // MARK: - Mid-match toasts

    [Fact]
    public void ThreeHintsUsed_FiresBanner()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        vm.State.Phase = HoneycombPhase.Playing;
        vm.State.CurrentTurn = 1;
        vm.State.ActiveRules = new List<HoneycombRule>();
        vm.State.Board = new HoneycombBoard();
        vm.State.PlayerHand = Enumerable.Range(1, 5).Select(i => MkCard(i, 1)).ToList();
        vm.State.OpponentHand = Enumerable.Range(11, 5).Select(i => MkCard(i, -1)).ToList();

        var beforeThird = CaptureBanners(vm, () =>
        {
            vm.FindHint();
            vm.FindHint();
        });
        Assert.Empty(beforeThird);

        var queued = CaptureBanners(vm, () => vm.FindHint());
        Assert.True(QueueContainsMessage(queued, BannerId.Gameplay3HintsUsedInOneMatch));
    }

    [Fact]
    public void UndoUsedAndRepeatMove_FireBanners()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        vm.State.Phase = HoneycombPhase.Playing;
        vm.State.CurrentTurn = 1;
        vm.State.ActiveRules = new List<HoneycombRule>();
        vm.State.Board = new HoneycombBoard();
        vm.State.PlayerHand = new List<HoneycombCard> { MkWeakCard(1, 1), MkWeakCard(2, 1) };
        vm.State.OpponentHand = new List<HoneycombCard> { MkWeakCard(11, -1), MkWeakCard(12, -1) };

        vm.PlayCard(0, 0); // this move's own capture banner (if any) doesn't matter here
        // PlayCard fires the opponent's reply via RunAITurn, which is genuinely async
        // (hops to a background thread) — CanUndo requires CurrentTurn back on the
        // player, so wait for that reply to actually land before checking it.
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);

        Assert.True(vm.CanUndo);
        var afterUndo = CaptureBanners(vm, () => vm.Undo());
        Assert.True(QueueContainsMessage(afterUndo, BannerId.GameplayUndoUsedImmediatelyAfterAPlacement));

        // Replaying the exact same card onto the exact same cell should fire the
        // repeat-move banner too.
        var afterRepeat = CaptureBanners(vm, () => vm.PlayCard(0, 0));
        Assert.True(QueueContainsMessage(afterRepeat, BannerId.GameplayPlayerUsesUndoThinksAboutItAndThenMakesTheExact));
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);

        // Negative case: undo again, then play a DIFFERENT cell — must NOT fire.
        Assert.True(vm.CanUndo);
        vm.Undo();
        var afterDifferentCell = CaptureBanners(vm, () => vm.PlayCard(0, 1));
        Assert.False(QueueContainsMessage(afterDifferentCell, BannerId.GameplayPlayerUsesUndoThinksAboutItAndThenMakesTheExact));
    }

    [Fact]
    public void BoardImbalance_FiresBanner()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        vm.State.Phase = HoneycombPhase.Playing;
        vm.State.CurrentTurn = 1;
        vm.State.ActiveRules = new List<HoneycombRule>();

        var board = new HoneycombBoard();
        board.Cells[0].Card = MkFortressCard(0, 1);
        for (int i = 1; i < 6; i++) board.Cells[i].Card = MkFortressCard(i, -1);
        // cells[6..8] stay empty — cell 6 becomes the player's 2nd card below; the
        // opponent needs a real (if harmless) card of their own here since PlayCard's
        // completion synchronously runs their reply turn in headless mode, and an
        // empty opponent hand crashes HoneycombAI.FindGreedyMove.
        vm.State.Board = board;
        vm.State.PlayerHand = new List<HoneycombCard> { MkWeakCard(400, 1) };
        vm.State.OpponentHand = new List<HoneycombCard> { MkWeakCard(401, -1) };

        // The imbalance banner only actually fires off the OPPONENT's placement (the
        // 2-vs-6 split doesn't exist yet right after the player's own move) — that
        // happens inside RunAITurn's background search, so the wait has to happen
        // INSIDE the CaptureBanners closure, while OnFlashBanner is still subscribed,
        // not after CaptureBanners has already drained the queue and returned.
        var queued = CaptureBanners(vm, () =>
        {
            vm.PlayCard(0, 6);
            HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);
        });

        int playerOwned = vm.State.Board.Cells.Count(c => c.Card?.Owner == 1);
        int opponentOwned = vm.State.Board.Cells.Count(c => c.Card?.Owner == -1);
        Assert.Equal(2, playerOwned);
        Assert.Equal(6, opponentOwned);
        Assert.True(QueueContainsMessage(queued, BannerId.GameplayPlayerHasOnly2CardsOnTheBoardVsOpponents6Few));
    }

    [Fact]
    public void OpponentAboutToPlaceLastCard_FiresWarning()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        vm.State.Phase = HoneycombPhase.Playing;
        vm.State.CurrentTurn = -1;
        vm.State.ActiveRules = new List<HoneycombRule>();

        var board = new HoneycombBoard();
        for (int i = 0; i < 3; i++) board.Cells[i].Card = MkFortressCard(i, 1);
        for (int i = 3; i < 8; i++) board.Cells[i].Card = MkFortressCard(i, -1);
        // 3 player-owned vs 5 opponent-owned, 1 empty. The "pre-move" score the trigger
        // checks against is board ownership PLUS whatever's still sitting in each hand
        // (an unplayed card still counts toward that side's eventual score) — the
        // opponent's one card about to be played counts on their side of that formula,
        // so the player needs a leftover (never-played) card of their own for the 3-5
        // board split to net out to exactly a 2-card opponent lead: (5+1) - (3+1) = 2.
        vm.State.Board = board;
        vm.State.OpponentHand = new List<HoneycombCard> { MkWeakCard(500, -1) };
        vm.State.PlayerHand = new List<HoneycombCard> { MkWeakCard(501, 1) };

        var queued = CaptureBanners(vm, () => RunAiTurn(vm));

        Assert.True(QueueContainsMessage(queued, BannerId.GameplayOpponentIsWinningByTwoCardsAndIsAboutToPlaceThe));
    }

    // MARK: - Streaks

    [Fact]
    public void SameDifficultyStreak_FiresOnFifthMatch()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        // Only rematches count toward this streak (confirmed by the banner content
        // owner: plain New Game starts at the same difficulty shouldn't trip it) —
        // one real StartNewMatch() to populate _rematchOpponentDeck, then 5
        // RematchGame() calls to reach the 5th consecutive same-difficulty match.
        vm.StartNewMatch();
        List<string> queued = new();
        for (int i = 0; i < 5; i++)
        {
            queued = CaptureBanners(vm, () => vm.RematchGame());
        }
        Assert.True(QueueContainsMessage(queued, BannerId.GameplayPlayerPlaysAgainstTheSameAiDifficulty5TimesInARow));
    }

    [Fact]
    public void SameDifficultyStreak_DoesNotFireOnPlainNewGameStarts()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        // Same default difficulty every time, but via StartNewMatch() (not
        // RematchGame()) — should never trip the streak, no matter how many times
        // it repeats.
        List<string> queued = new();
        for (int i = 0; i < 6; i++)
        {
            queued = CaptureBanners(vm, () => vm.StartNewMatch());
        }
        Assert.False(QueueContainsMessage(queued, BannerId.GameplayPlayerPlaysAgainstTheSameAiDifficulty5TimesInARow));
    }

    // Forces a win by directly overwriting board/hands to an 8-0 fortress split, then
    // playing the 9th card — same technique as FlawlessWin_FiresFlavorAndMilestone,
    // just repeated across a real RematchGame() chain so the "against the same
    // opponent" streak state (private to HoneycombViewModel) accumulates naturally
    // through the real API instead of being poked directly.
    private static void ForceWinViaFortressBoard(HoneycombViewModel vm)
    {
        vm.State.ActiveRules = new List<HoneycombRule>();
        vm.State.CurrentTurn = 1;
        vm.State.Phase = HoneycombPhase.Playing;
        var board = new HoneycombBoard();
        for (int i = 0; i < 8; i++) board.Cells[i].Card = MkFortressCard(i, 1);
        vm.State.Board = board;
        vm.State.PlayerHand = new List<HoneycombCard> { MkWeakCard(new Random().Next(10_000, 99_999), 1) };
        vm.State.OpponentHand = new List<HoneycombCard>();
        vm.PlayCard(0, 8);
    }

    private static void ForceLossViaFortressBoard(HoneycombViewModel vm)
    {
        vm.State.ActiveRules = new List<HoneycombRule>();
        vm.State.CurrentTurn = -1;
        vm.State.Phase = HoneycombPhase.Playing;
        var board = new HoneycombBoard();
        for (int i = 0; i < 8; i++) board.Cells[i].Card = MkFortressCard(i, -1);
        vm.State.Board = board;
        vm.State.OpponentHand = new List<HoneycombCard> { MkWeakCard(new Random().Next(10_000, 99_999), -1) };
        vm.State.PlayerHand = new List<HoneycombCard>();
        RunAiTurn(vm);
    }

    [Fact]
    public void RematchWinStreak_FiresOnThirdWin()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        // One real StartNewMatch() to populate _rematchOpponentDeck — everything else
        // about this match is immediately overwritten. StartNewMatch/RematchGame can
        // themselves kick off the AI's opening move (fire-and-forget, same RunAITurn
        // background search) if the opponent happens to be dealt the first turn —
        // wait for that to settle before the next Force*ViaFortressBoard call stomps
        // the board out from under it, or the stale move lands on the new state later.
        vm.StartNewMatch();
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);

        ForceWinViaFortressBoard(vm); // win #1
        vm.RematchGame();
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);

        ForceWinViaFortressBoard(vm); // win #2
        vm.RematchGame();
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);

        var queued = CaptureBanners(vm, () => ForceWinViaFortressBoard(vm)); // win #3 — should trip the streak
        Assert.True(QueueContainsMessage(queued, BannerId.Gameplay3RematchWinsInARowAgainstTheSameOpponent));
    }

    [Fact]
    public void RematchLossStreak_FiresOnThirdLoss()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        vm.StartNewMatch();
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);

        ForceLossViaFortressBoard(vm); // loss #1
        vm.RematchGame();
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);

        ForceLossViaFortressBoard(vm); // loss #2
        vm.RematchGame();
        HoneycombAsyncTestHelpers.WaitForAiTurnToSettle(vm);

        var queued = CaptureBanners(vm, () => ForceLossViaFortressBoard(vm)); // loss #3 — should trip the streak
        Assert.True(QueueContainsMessage(queued, BannerId.Gameplay3RematchLossesInARowAgainstTheSameOpponent));
    }

    // MARK: - Session-scoped (first launch / loading)

    [Fact]
    public void FirstLaunchMilestone_FiresOnFreshStart()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        // The constructor loads whatever this machine's real honeycomb_stats.json
        // says — reset to a clean slate so GamesPlayed == 0 regardless of real play
        // history, since that's the exact condition MilestonesFirstLaunchEver fires on.
        vm.Stats = new HoneycombStats();

        var queued = CaptureBanners(vm, () => vm.StartNewMatch());

        Assert.True(QueueContainsMessage(queued, BannerId.MilestonesFirstLaunchEver));
    }

    [Fact]
    public void LoadingBanner_FiresOnViewAppear()
    {
        var vm = new HoneycombViewModel(isHeadless: true);

        var queued = CaptureBanners(vm, () => vm.CheckLoadingBanner());

        // Whichever Loading banner today's actual date/time maps to, SOME loading
        // message should be present — this can't pin an exact id without mocking the
        // system clock, so it checks membership across every Loading-location entry.
        var loadingIds = Enum.GetValues<BannerId>().Where(id => id.ToString().StartsWith("Loading")).ToArray();
        Assert.True(QueueContainsMessage(queued, loadingIds));
    }

    [Fact]
    public void LoadingBanner_DoesNotFireTwiceInSameSession()
    {
        var vm = new HoneycombViewModel(isHeadless: true);
        CaptureBanners(vm, () => vm.CheckLoadingBanner());

        // Simulates switching back to this game later in the same session.
        var queued = CaptureBanners(vm, () => vm.CheckLoadingBanner());

        Assert.Empty(queued);
    }
}
