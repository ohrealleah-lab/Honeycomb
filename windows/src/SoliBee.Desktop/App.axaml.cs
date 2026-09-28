using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using SoliBee.Desktop.Views;

namespace SoliBee.Desktop;

public partial class App : Application
{
    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);
    }

    public override void OnFrameworkInitializationCompleted()
    {
        // ClearType (subpixel) text on every window and popup as it attaches — Avalonia 12
        // only exposes TextOptions from code, so this can't live in App.axaml's styles.
        // Keeps text as crisp as it was on Avalonia 11.
        Avalonia.Controls.Control.LoadedEvent.AddClassHandler<Avalonia.Controls.TopLevel>((topLevel, _) =>
            Avalonia.Media.TextOptions.SetTextRenderingMode(topLevel, Avalonia.Media.TextRenderingMode.SubpixelAntialias));

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            desktop.MainWindow = new MainWindow();
        }

        base.OnFrameworkInitializationCompleted();
    }
}
