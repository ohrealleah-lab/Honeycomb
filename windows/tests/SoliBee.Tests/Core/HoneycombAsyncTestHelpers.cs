using System;
using System.Reflection;
using System.Threading;
using SoliBee.Core.ViewModels;

namespace SoliBee.Tests.Core;

// RunAITurn (the opponent's move) is genuinely async — it hops to a background
// thread via `await Task.Run(() => HoneycombAI.FindMove(...))` before actually
// placing the AI's card and resolving captures/SettleMatch. Both invoking it
// directly via reflection (it's `async void`, so Invoke returns at the first
// await, not when the method is actually done) and triggering it indirectly
// through PlayCard's opponent auto-reply race whatever assertions immediately
// follow. There's no public awaitable or "settled" event to hook, so this polls
// the private _isAnimating flag (the same one CanUndo/input-gating already read
// internally) until it drops back to false — meaning the AI's move, and anything
// it triggers (SettleMatch, a Sudden Death continuation, undo-stack updates),
// has actually finished.
internal static class HoneycombAsyncTestHelpers
{
    private static readonly FieldInfo IsAnimatingField =
        typeof(HoneycombViewModel).GetField("_isAnimating", BindingFlags.NonPublic | BindingFlags.Instance)!;

    public static void WaitForAiTurnToSettle(HoneycombViewModel vm, int timeoutMs = 5000)
    {
        var deadline = DateTime.UtcNow.AddMilliseconds(timeoutMs);
        while (DateTime.UtcNow < deadline)
        {
            if (IsAnimatingField.GetValue(vm) is bool animating && !animating) return;
            Thread.Sleep(5);
        }
        throw new TimeoutException("HoneycombViewModel's AI turn didn't settle (_isAnimating stayed true) within the timeout — RunAITurn's background search may be stuck.");
    }
}
