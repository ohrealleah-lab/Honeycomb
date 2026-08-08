using System.Runtime.CompilerServices;
using SoliBee.Core.Services;

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
