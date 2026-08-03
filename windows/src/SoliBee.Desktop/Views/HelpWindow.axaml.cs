using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Interactivity;
using SoliBee.Core.Models;

namespace SoliBee.Desktop.Views;

public partial class HelpWindow : Window
{
    public IEnumerable<string> DynamicRules { get; }

    public HelpWindow(bool startAtHoneycomb = false)
    {
        InitializeComponent();
        
        var rules = Enum.GetValues<SoliBee.Core.Models.HoneycombRule>();
        DynamicRules = rules.Select(r => $"• {r.DisplayName()}: {r.GetExplanation()}");
        DataContext = this;

        if (startAtHoneycomb)
        {
            Opened += (_, _) => ScrollToHoneycomb();
        }
    }

    public void ScrollToHoneycomb() => HoneycombAnchor.BringIntoView();

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


    private void GoTo_Themes(object? sender, RoutedEventArgs e) =>
        ThemesAnchor.BringIntoView();

    private void Close_Click(object? sender, RoutedEventArgs e) => Close();
}
