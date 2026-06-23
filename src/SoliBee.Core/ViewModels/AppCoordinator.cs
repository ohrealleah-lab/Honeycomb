using CommunityToolkit.Mvvm.ComponentModel;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Core.ViewModels;

public partial class AppCoordinator : ObservableObject
{
    [ObservableProperty]
    private GameViewModel _gameViewModel;

    [ObservableProperty]
    private BeecellViewModel _beecellViewModel;

    [ObservableProperty]
    private SpiderViewModel _spiderViewModel;

    [ObservableProperty]
    private object _activeViewModel;

    public AppCoordinator()
    {
        GameViewModel = new GameViewModel();
        BeecellViewModel = new BeecellViewModel();
        SpiderViewModel = new SpiderViewModel();
        ActiveViewModel = GameViewModel;
    }

    public void SwitchToGame()
    {
        ActiveViewModel = GameViewModel;
    }

    public void SwitchToBeecell()
    {
        ActiveViewModel = BeecellViewModel;
    }

    public void SwitchToSpider()
    {
        ActiveViewModel = SpiderViewModel;
    }
}
