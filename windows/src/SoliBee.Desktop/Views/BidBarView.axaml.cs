using Avalonia.Controls;
using SoliBee.Core.Localization;

namespace SoliBee.Desktop.Views;

public partial class BidBarView : UserControl
{
    public BidBarView()
    {
        InitializeComponent();
    }

    public void ApplyLanguage(AppLanguage language)
    {
        CreditsCaption.Text = Strings.Get(StringKey.CreditsLabel, language);
        BetCaption.Text     = Strings.Get(StringKey.BetLabel, language);
        HandsCaption.Text   = Strings.Get(StringKey.HandsLabel, language);
    }

    public string CreditsText
    {
        get => CreditsLabel.Text ?? "";
        set => CreditsLabel.Text = value;
    }

    public string BetText
    {
        get => BetLabel.Text ?? "";
        set => BetLabel.Text = value;
    }

    public string HandsText
    {
        get => HandsLabel.Text ?? "";
        set => HandsLabel.Text = value;
    }
}
