using System.Runtime.CompilerServices;
using SoliBee.Core.Services;
using Xunit;

// xUnit runs separate test classes in parallel by default. Several Honeycomb tests
// (HoneycombViewModelTests, HoneycombBannerTriggerTests) each spin up a real
// Task.Run(() => HoneycombAI.FindMove(...)) background search and then poll for it
// to finish within a 5s deadline (see HoneycombAsyncTestHelpers.WaitForAiTurnToSettle).
// Run individually, each search settles in well under a second; run concurrently
// across classes, the ThreadPool's throttled thread-injection rate under sudden
// simultaneous CPU-bound load pushes some of those searches past the deadline,
// failing with a timeout that has nothing to do with the code under test. Disabling
// collection parallelization serializes all tests in this assembly, matching how
// fast any individual one actually runs.
[assembly: CollectionBehavior(DisableTestParallelization = true)]

namespace SoliBee.Tests;

// Runs once, before any test in this assembly, so every ViewModel's
// ScheduleIdleActionCheck() skips its 60s Task.Delay instead of leaving it as real
// background work for the whole test run's duration.
internal static class TestModeInit
{
    [ModuleInitializer]
    internal static void Init()
    {
        TestMode.IsHeadless = true;
    }
}
