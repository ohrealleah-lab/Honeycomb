using Avalonia.Controls;

namespace SoliBee.Desktop.Views;

public partial class BidBarView : UserControl
{
    public BidBarView()
    {
        InitializeComponent();
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
