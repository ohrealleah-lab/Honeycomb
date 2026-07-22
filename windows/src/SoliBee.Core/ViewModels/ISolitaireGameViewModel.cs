using System.Collections.Generic;
using SoliBee.Core.Models;

namespace SoliBee.Core.ViewModels;

// Shared surface of GameViewModel/FreecellViewModel/SpiderViewModel used by
// SoliBee.Desktop's CardGameView to centralize victory-overlay and stuck/autocomplete
// banner logic that was previously duplicated identically per game (GameView.axaml.cs,
// FreecellView.axaml.cs, SpiderView.axaml.cs), differing only in which concrete
// view-model type DataContext happened to hold.
public interface ISolitaireGameViewModel
{
    List<Pile> Foundations { get; }
    string ScoreDisplay { get; }
    string TimeDisplay { get; }
    GameOptions Options { get; }
    void InitializeGame(bool countAsNewGame = true);
    void RestartGame();
    void Autocomplete();
}
