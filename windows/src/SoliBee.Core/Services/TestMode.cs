namespace SoliBee.Core.Services;

// Set once, at startup, by the test assembly (see SoliBee.Tests' ModuleInitializer) —
// lets Core-level code skip real-time delays (e.g. the Ambiance/Idle nudge's 60s
// Task.Delay) that would otherwise sit as genuine background work for the whole test
// run's duration. Mirrors the Swift port's UISound.isHeadlessMode.
public static class TestMode
{
    public static bool IsHeadless { get; set; } = false;
}
