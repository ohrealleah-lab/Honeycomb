using System;
using Avalonia;
using Velopack;

namespace SoliBee.Desktop;

class Program
{
    // Initialization code. Don't use any Avalonia, third-party APIs or any
    // SynchronizationContext-reliant code before AppMain is called: things aren't initialized
    // yet and stuff might break.
    [STAThread]
    public static void Main(string[] args)
    {
        // Must run before anything else in Main (including Avalonia startup) — this is how
        // Velopack intercepts its own first-run/install/update/uninstall hook invocations.
        // A no-op on every normal launch.
        VelopackApp.Build().Run();

        BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
    }

    // Avalonia configuration, any platform-specific initialization code go here.
    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont();
}
