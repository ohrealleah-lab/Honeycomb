#if WINDOWS
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public partial class MainWindow : Window
{
    private AppCoordinator _coordinator;

    public MainWindow()
    {
        this.InitializeComponent();
        _coordinator = new AppCoordinator();
        this.MainContent.Content = new GameView { DataContext = _coordinator.GameViewModel };
    }

    private void NewGame_Click(object sender, RoutedEventArgs e)
    {
        _coordinator.GameViewModel.InitializeGame();
    }

    private void Undo_Click(object sender, RoutedEventArgs e)
    {
        _coordinator.GameViewModel.UndoCommand.Execute(null);
    }

    private void Autocomplete_Click(object sender, RoutedEventArgs e)
    {
        _coordinator.GameViewModel.AutocompleteCommand.Execute(null);
    }

    private async void Preferences_Click(object sender, RoutedEventArgs e)
    {
        var preferencesView = new PreferencesView();
        preferencesView.DataContext = _coordinator.GameViewModel.Options;

        var dialog = new ContentDialog
        {
            Title = "Preferences",
            Content = preferencesView,
            CloseButtonText = "OK",
            XamlRoot = this.Content.XamlRoot
        };
        await dialog.ShowAsync();
    }
}
#else
namespace SoliBee.Desktop.Views;

public class MainWindow
{
    // Dummy class for non-Windows compilation
}
#endif
