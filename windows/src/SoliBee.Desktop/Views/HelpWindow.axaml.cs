using Avalonia.Controls;
using Avalonia.Interactivity;

namespace SoliBee.Desktop.Views;

public partial class HelpWindow : Window
{
    public HelpWindow()
    {
        InitializeComponent();
    }

    private void GoTo_Klondike(object? sender, RoutedEventArgs e) =>
        KlondikeAnchor.BringIntoView();

    private void GoTo_Freecell(object? sender, RoutedEventArgs e) =>
        FreecellAnchor.BringIntoView();

    private void GoTo_Spider(object? sender, RoutedEventArgs e) =>
        SpiderAnchor.BringIntoView();

    private void GoTo_VideoPoker(object? sender, RoutedEventArgs e) =>
        VideoPokerAnchor.BringIntoView();

    private void GoTo_Blackjack(object? sender, RoutedEventArgs e) =>
        BlackjackAnchor.BringIntoView();

    private void GoTo_Honeycomb(object? sender, RoutedEventArgs e) =>
        HoneycombAnchor.BringIntoView();

    private void GoTo_NoStress(object? sender, RoutedEventArgs e) =>
        NoStressAnchor.BringIntoView();

    private void GoTo_Themes(object? sender, RoutedEventArgs e) =>
        ThemesAnchor.BringIntoView();

    private void Close_Click(object? sender, RoutedEventArgs e) => Close();
}
