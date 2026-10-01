using Avalonia;
using Avalonia.Controls;

namespace SoliBee.Desktop.Views;

// The main window's dialogs (Preferences, Stats, Manage Decks, the confirm prompt…) are
// overlays drawn over the live game, not separate windows, so the game views' window-wide
// key handlers keep receiving keystrokes while one is up — a Space meant for a Preferences
// checkbox would otherwise deal a Video Poker hand behind it. Every game's key handler
// asks this first and does nothing while a dialog is open (Mac's key monitors do the same).
internal static class DialogGuard
{
    public static bool IsDialogOpen(Visual view) =>
        TopLevel.GetTopLevel(view) is MainWindow window && window.IsDialogOpen;
}
