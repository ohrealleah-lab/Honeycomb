using System;
using Avalonia.Controls;
using Avalonia.Interactivity;

namespace SoliBee.Desktop.Views;

public partial class AutocompleteBanner : UserControl
{
    public event EventHandler? AutocompleteClicked;
    public event EventHandler? DismissClicked;

    public AutocompleteBanner()
    {
        InitializeComponent();
    }

    private void Autocomplete_Click(object? sender, RoutedEventArgs e) => AutocompleteClicked?.Invoke(this, EventArgs.Empty);
    private void Dismiss_Click(object? sender, RoutedEventArgs e) => DismissClicked?.Invoke(this, EventArgs.Empty);
}
