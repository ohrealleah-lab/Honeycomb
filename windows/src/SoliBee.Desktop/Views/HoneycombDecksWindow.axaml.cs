using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Threading;
using SoliBee.Core.Models;
using SoliBee.Core.ViewModels;
using System.Linq;

namespace SoliBee.Desktop.Views;

public partial class HoneycombDecksWindow : Window
{
    private HoneycombDecksViewModel _vm;

    public HoneycombDecksWindow()
    {
        InitializeComponent();
        _vm = new HoneycombDecksViewModel();
        DataContext = _vm;

        _vm.PropertyChanged += (s, e) =>
        {
            if (e.PropertyName == nameof(_vm.CurrentStars))
                UpdateCapDisplay();
        };

        SortCombo.SelectionChanged += (s, e) => RenderBank();

        RenderBank();
        RenderDeck();
        UpdateCapDisplay();
    }

    private void UpdateCapDisplay()
    {
        Dispatcher.UIThread.Post(() =>
        {
            CapText.Text = $"{_vm.CurrentStars} / {_vm.MaxStarsCap} ★";
            CapText.Foreground = _vm.CurrentStars > _vm.MaxStarsCap ? Avalonia.Media.Brushes.Red : Avalonia.Media.Brushes.Gold;
            
            bool valid = _vm.CurrentDeck.Count == 5 && _vm.CurrentStars <= _vm.MaxStarsCap;
            SaveButton.IsEnabled = valid;
            
            if (_vm.CurrentDeck.Count < 5)
            {
                ErrorText.Text = $"Need {5 - _vm.CurrentDeck.Count} more cards.";
                ErrorText.IsVisible = true;
            }
            else if (_vm.CurrentStars > _vm.MaxStarsCap)
            {
                ErrorText.Text = "Star cap exceeded!";
                ErrorText.IsVisible = true;
            }
            else
            {
                ErrorText.IsVisible = false;
            }
        });
    }

    private void RenderBank()
    {
        BankPanel.Children.Clear();
        
        var items = _vm.CardBank.AsEnumerable();
        if (SortCombo.SelectedIndex == 1) items = items.OrderByDescending(c => c.Stars).ThenBy(c => c.Id);
        else if (SortCombo.SelectedIndex == 2) items = items.OrderBy(c => c.Suit).ThenBy(c => c.Id);
        else items = items.OrderBy(c => c.Id);

        foreach (var data in items)
        {
            var cardView = new HoneycombCardView();
            var card = new HoneycombCard(data, 1);
            _ = cardView.RenderCard(card);
            
            // Allow adding
            cardView.PointerPressed += (s, e) =>
            {
                if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
                {
                    if (_vm.AddToDeck(data))
                        RenderDeck();
                }
            };
            
            BankPanel.Children.Add(cardView);
        }
    }

    private void RenderDeck()
    {
        DeckPanel.Children.Clear();
        
        foreach (var data in _vm.CurrentDeck)
        {
            var cardView = new HoneycombCardView();
            var card = new HoneycombCard(data, 1);
            _ = cardView.RenderCard(card);
            
            cardView.PointerPressed += (s, e) =>
            {
                if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
                {
                    _vm.RemoveFromDeck(data);
                    RenderDeck();
                }
            };
            
            DeckPanel.Children.Add(cardView);
        }
    }

    private void Save_Click(object? sender, RoutedEventArgs e)
    {
        _vm.SaveDeck();
        Close();
    }
}
