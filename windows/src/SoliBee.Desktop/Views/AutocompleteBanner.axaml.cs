using System;
using Avalonia.Controls;
using Avalonia.Interactivity;
using SoliBee.Core.Localization;

namespace SoliBee.Desktop.Views;

public partial class AutocompleteBanner : UserControl
{
    public event EventHandler? AutocompleteClicked;
    public event EventHandler? DismissClicked;

    public AutocompleteBanner()
    {
        InitializeComponent();
    }

    // isKlondike picks between the two body-text variants — Klondike's foundations are
    // literally called that, but Freecell/Spider's win condition reads more naturally as
    // "sorted into foundations" (Spider has no foundations at all until the final sort).
    public void ApplyLocalization(AppLanguage language, bool isKlondike)
    {
        TitleText.Text = Strings.Get(StringKey.VictoryGuaranteed, language);
        BodyText.Text = Strings.Get(isKlondike ? StringKey.AutocompleteBodyKlondike : StringKey.AutocompleteBodyOther, language);
        AutocompleteButton.Content = Strings.Get(StringKey.AutocompleteGame, language);
    }

    private void Autocomplete_Click(object? sender, RoutedEventArgs e) => AutocompleteClicked?.Invoke(this, EventArgs.Empty);
    private void Dismiss_Click(object? sender, RoutedEventArgs e) => DismissClicked?.Invoke(this, EventArgs.Empty);
}
