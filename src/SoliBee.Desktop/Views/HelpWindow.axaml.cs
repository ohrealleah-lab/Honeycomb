using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Media;

namespace SoliBee.Desktop.Views;

public partial class HelpWindow : Window
{
    public HelpWindow() : this("Klondike") { }

    public HelpWindow(string gameMode)
    {
        InitializeComponent();
        Title = gameMode switch
        {
            "Klondike" => "Klondike Solitaire — Help",
            "Beecell"  => "Beecell — Help",
            "Spider"   => "Spider Solibee — Help",
            _          => "Help"
        };
        BuildContent(gameMode);
    }

    private void BuildContent(string mode)
    {
        switch (mode)
        {
            case "Klondike": BuildKlondikeContent(); break;
            case "Beecell":  BuildBeecellContent();  break;
            case "Spider":   BuildSpiderContent();   break;
        }
    }

    private void AddTitle(string text)
    {
        ContentPanel.Children.Add(new TextBlock
        {
            Text = text,
            FontSize = 20,
            FontWeight = FontWeight.Bold,
            Foreground = new SolidColorBrush(Colors.White),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 0, 0, 8)
        });
    }

    private void AddHeading(string text)
    {
        ContentPanel.Children.Add(new TextBlock
        {
            Text = text,
            FontSize = 13,
            FontWeight = FontWeight.Bold,
            Foreground = new SolidColorBrush(Color.Parse("#7EC8FF")),
            Margin = new Thickness(0, 12, 0, 2)
        });
    }

    private void AddBullet(string text)
    {
        ContentPanel.Children.Add(new TextBlock
        {
            Text = "• " + text,
            FontSize = 13,
            Foreground = new SolidColorBrush(Color.Parse("#D0D0D0")),
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(14, 0, 0, 0)
        });
    }

    private void Close_Click(object? sender, RoutedEventArgs e) => Close();

    private void BuildKlondikeContent()
    {
        AddTitle("Klondike Solitaire");

        AddHeading("Objective");
        AddBullet("Move all 52 cards to four foundation piles, built Ace through King by suit.");

        AddHeading("Layout");
        AddBullet("7 tableau columns — column 1 has 1 card face-up, column 7 has 6 face-down with 1 face-up on top.");
        AddBullet("The remaining 24 cards form the stock pile.");

        AddHeading("Tableau Rules");
        AddBullet("Stack in descending rank and alternating color (red on black, black on red).");
        AddBullet("Only a King (or a sequence starting with a King) can fill an empty column.");
        AddBullet("Face-up sequences can be moved together.");

        AddHeading("Foundations");
        AddBullet("Built by suit from Ace to King.");
        AddBullet("Cards auto-move to the foundation when it is safe to do so.");

        AddHeading("Stock & Waste");
        AddBullet("Click the stock to deal cards to the waste pile.");
        AddBullet("Draw 1: one card at a time. Draw 3: deals three, only the top card is playable.");
        AddBullet("When the stock runs out, click it to redeal from the waste (−25 pts in Vegas mode).");

        AddHeading("Vegas Scoring");
        AddBullet("+5 points for each card moved to a foundation.");
        AddBullet("−25 points each time the stock is redealt.");
        AddBullet("Goal: finish with a positive score.");

        AddHeading("Toolbar Actions");
        AddBullet("New Game — deal a fresh random hand");
        AddBullet("Restart — replay the exact same deal");
        AddBullet("Undo — take back the last move");
        AddBullet("Draw 1 / Draw 3 — switch deal mode in the game selector");
    }

    private void BuildBeecellContent()
    {
        AddTitle("Beecell");

        AddHeading("Objective");
        AddBullet("Move all cards to the four foundation piles, built Ace through King by suit.");

        AddHeading("Layout");
        AddBullet("All 52 cards are dealt face-up into 8 tableau columns.");
        AddBullet("4 free cells top-left — each holds one card as temporary parking.");
        AddBullet("4 foundations top-right — built Ace through King by suit.");

        AddHeading("Free Cells");
        AddBullet("Each free cell holds exactly one card at a time.");
        AddBullet("Use them to temporarily move cards out of the way.");

        AddHeading("Tableau Rules");
        AddBullet("Stack cards in descending rank and alternating color.");
        AddBullet("Number of cards moveable as a group = (empty free cells + 1) × 2^(empty columns).");
        AddBullet("Empty columns act like extra free cells and greatly increase how many cards can move at once.");

        AddHeading("Strategy");
        AddBullet("Nearly every deal is solvable — if stuck, undo and replan.");
        AddBullet("Avoid filling all free cells at once; you need breathing room to reorganize.");
        AddBullet("Expose Aces and Twos early to start building the foundations.");
        AddBullet("Creating empty columns is your most powerful resource — protect them.");

        AddHeading("Toolbar Actions");
        AddBullet("New Game — deal a fresh random hand");
        AddBullet("Restart — replay the exact same deal");
        AddBullet("Undo — take back the last move");
    }

    private void BuildSpiderContent()
    {
        AddTitle("Spider Solibee");

        AddHeading("Objective");
        AddBullet("Build 8 complete in-suit sequences from Ace to King. Completed sequences are automatically removed.");

        AddHeading("Layout");
        AddBullet("104 cards (2 decks) dealt into 10 tableau columns.");
        AddBullet("First 4 columns get 6 cards; last 6 columns get 5. Only the top card of each column is face-up.");
        AddBullet("5 stock rows of 10 cards are held in reserve.");

        AddHeading("Tableau Rules");
        AddBullet("Cards can be stacked in descending rank regardless of suit.");
        AddBullet("You can only move a group of cards together if all cards in the group share the same suit.");
        AddBullet("Mixed-suit stacks must be moved one card at a time.");

        AddHeading("Suit Modes");
        AddBullet("1 suit (easiest) — all cards are the same suit; sequences build freely.");
        AddBullet("2 suits (medium) — two suits in play; moderate planning required.");
        AddBullet("4 suits (hardest) — all four suits; sequences must be kept same-suit throughout.");

        AddHeading("Dealing from Stock");
        AddBullet("Click the stock button to deal one card face-up onto each of the 10 columns.");
        AddBullet("All 10 columns must be non-empty before you can deal.");
        AddBullet("5 deals are available — plan carefully before spending them.");

        AddHeading("Empty Columns");
        AddBullet("Any single card or valid in-suit sequence can be placed in an empty column.");
        AddBullet("Empty columns are extremely valuable for reorganizing large sequences.");

        AddHeading("Toolbar Actions");
        AddBullet("New Game — deal a fresh random hand");
        AddBullet("Restart — replay the exact same deal");
        AddBullet("Undo — take back the last move");
        AddBullet("Suit mode — change difficulty in the game selector");
    }
}
