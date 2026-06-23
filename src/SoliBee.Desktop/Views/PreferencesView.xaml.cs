#if WINDOWS
using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public partial class PreferencesView : UserControl
{
    private bool _initializing = true;

    public PreferencesView()
    {
        this.InitializeComponent();
        this.Loaded += PreferencesView_Loaded;
    }

    private void PreferencesView_Loaded(object sender, RoutedEventArgs e)
    {
        if (DataContext is GameOptions options)
        {
            // Select FeltColor in ComboBox
            foreach (ComboBoxItem item in FeltColorComboBox.Items)
            {
                if (item.Tag.ToString() == options.FeltColor.ToString())
                {
                    FeltColorComboBox.SelectedItem = item;
                    break;
                }
            }

            // Select CardBackTheme
            foreach (ComboBoxItem item in CardBackComboBox.Items)
            {
                if (item.Tag.ToString() == options.CardBackTheme)
                {
                    CardBackComboBox.SelectedItem = item;
                    break;
                }
            }

            TimedCheckBox.IsChecked = options.IsTimed;
            SoundCheckBox.IsChecked = options.IsSoundEnabled;
            VegasCheckBox.IsChecked = options.IsVegasScoring;
            DrawConstraintsCheckBox.IsChecked = options.IsDrawConstraintsEnabled;
        }
        _initializing = false;
    }

    private void FeltColorComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_initializing) return;

        if (DataContext is GameOptions options && FeltColorComboBox.SelectedItem is ComboBoxItem item)
        {
            if (Enum.TryParse<FeltColorTheme>(item.Tag.ToString(), out var feltTheme))
            {
                options.FeltColor = feltTheme;
                options.CustomFeltColorRevision++;
                NotifySettingsChanged(options);
            }
        }
    }

    private void CardBackComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_initializing) return;

        if (DataContext is GameOptions options && CardBackComboBox.SelectedItem is ComboBoxItem item)
        {
            options.CardBackTheme = item.Tag.ToString();
            NotifySettingsChanged(options);
        }
    }

    private void Option_Changed(object sender, RoutedEventArgs e)
    {
        if (_initializing) return;

        if (DataContext is GameOptions options)
        {
            options.IsTimed = TimedCheckBox.IsChecked ?? false;
            options.IsSoundEnabled = SoundCheckBox.IsChecked ?? false;
            options.IsVegasScoring = VegasCheckBox.IsChecked ?? false;
            options.IsDrawConstraintsEnabled = DrawConstraintsCheckBox.IsChecked ?? false;
            NotifySettingsChanged(options);
        }
    }

    private void NotifySettingsChanged(GameOptions options)
    {
        SettingsService.SaveOptions(options);
        WeakReferenceMessenger.Default.Send(new OptionsChangedMessage(options));
    }
}
#else
namespace SoliBee.Desktop.Views;

public class PreferencesView
{
    // Dummy class for non-Windows compilation
}
#endif
