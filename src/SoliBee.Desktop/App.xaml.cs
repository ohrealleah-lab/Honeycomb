#if WINDOWS
using Microsoft.UI.Xaml;

namespace SoliBee.Desktop;

public partial class App : Application
{
    private Window m_window;

    public App()
    {
        this.InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        m_window = new MainWindow();
        m_window.Activate();
    }
}
#else
namespace SoliBee.Desktop;

public class App
{
    // Dummy class for non-Windows compilation
}
#endif
