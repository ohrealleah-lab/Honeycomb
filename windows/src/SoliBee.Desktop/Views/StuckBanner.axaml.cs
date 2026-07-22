using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;

namespace SoliBee.Desktop.Views;

public partial class StuckBanner : UserControl
{
    public static readonly StyledProperty<object?> ExtraContentProperty =
        AvaloniaProperty.Register<StuckBanner, object?>(nameof(ExtraContent));

    // Klondike-only Vegas-mode "Final bankroll" line — Freecell/Spider leave this unset,
    // matching their banner's original appearance exactly (they never had this line).
    public object? ExtraContent
    {
        get => GetValue(ExtraContentProperty);
        set => SetValue(ExtraContentProperty, value);
    }

    public string StatsText
    {
        get => NoMovesStatsLabel.Text ?? "";
        set => NoMovesStatsLabel.Text = value;
    }

    public event EventHandler? NewGameClicked;
    public event EventHandler? RestartClicked;
    public event EventHandler? DismissClicked;

    public StuckBanner()
    {
        InitializeComponent();
    }

    private void NewGame_Click(object? sender, RoutedEventArgs e) => NewGameClicked?.Invoke(this, EventArgs.Empty);
    private void Restart_Click(object? sender, RoutedEventArgs e) => RestartClicked?.Invoke(this, EventArgs.Empty);
    private void Dismiss_Click(object? sender, RoutedEventArgs e) => DismissClicked?.Invoke(this, EventArgs.Empty);
}
