namespace SoliBee.Desktop.Views;

// Single source of truth for the gold glow shared by every overlay banner
// (win/stuck/autocomplete banners, and Blackjack/Video Poker's win-loss banners).
// Referenced from App.axaml's Border.banner-glow style via {x:Static} and from
// BlackjackView.axaml.cs directly, since that view sets BoxShadow at runtime.
public static class BannerStyles
{
    public const string GoldGlowBoxShadow = "0 0 16 0 #80FFD600";
}
