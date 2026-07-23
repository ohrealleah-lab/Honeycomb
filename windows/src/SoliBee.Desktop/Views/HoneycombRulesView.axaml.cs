using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Threading;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public partial class HoneycombRulesView : UserControl
{
    private HoneycombViewModel? _vm;
    private HoneycombOptions _localOpts;
    private bool _initializing = true;

    public event EventHandler<bool>? OnCloseRequested;

    public HoneycombRulesView()
    {
        InitializeComponent();
        _localOpts = new HoneycombOptions(); // temp
    }

    public void Initialize(HoneycombViewModel vm)
    {
        _vm = vm;
        
        // Deep copy options so Cancel discards changes
        _localOpts = new HoneycombOptions
        {
            Difficulty = vm.Options.Difficulty,
            ForceNormalRules = vm.Options.ForceNormalRules,
            ManualRules = vm.Options.ManualRules?.ToList() ?? new List<HoneycombRule>(),
            BannedRules = vm.Options.BannedRules?.ToList() ?? new List<string>()
        };
        
        SyncUI();
    }

    private void SyncUI()
    {
        _initializing = true;
        
        foreach (var item in HoneycombDifficultyCombo.Items.Cast<ComboBoxItem>())
        {
            if (item.Tag?.ToString() == _localOpts.Difficulty)
            {
                HoneycombDifficultyCombo.SelectedItem = item;
                break;
            }
        }

        // Game Choice
        HoneycombRule_ForceNormal.IsChecked = _localOpts.ForceNormalRules;
        HoneycombRule_Ascension.IsChecked = _localOpts.ManualRules.Contains(HoneycombRule.Ascension);
        HoneycombRule_Descension.IsChecked = _localOpts.ManualRules.Contains(HoneycombRule.Descension);
        HoneycombRule_Same.IsChecked = _localOpts.ManualRules.Contains(HoneycombRule.Same);
        HoneycombRule_Plus.IsChecked = _localOpts.ManualRules.Contains(HoneycombRule.Plus);
        HoneycombRule_FallenAce.IsChecked = _localOpts.ManualRules.Contains(HoneycombRule.FallenAce);
        HoneycombRule_AllOpen.IsChecked = _localOpts.ManualRules.Contains(HoneycombRule.AllOpen);
        HoneycombRule_ThreeOpen.IsChecked = _localOpts.ManualRules.Contains(HoneycombRule.ThreeOpen);
        HoneycombRule_Swap.IsChecked = _localOpts.ManualRules.Contains(HoneycombRule.Swap);
        HoneycombRule_Order.IsChecked = _localOpts.ManualRules.Contains(HoneycombRule.Order);
        HoneycombRule_Chaos.IsChecked = _localOpts.ManualRules.Contains(HoneycombRule.Chaos);
        HoneycombRule_BombShelter.IsChecked = _localOpts.ManualRules.Contains(HoneycombRule.BombShelter);

        // Ban List
        Ban_NormalMode.IsChecked = _localOpts.BannedRules.Contains("Normal Mode");
        Ban_Ascension.IsChecked = _localOpts.BannedRules.Contains("Ascension");
        Ban_Descension.IsChecked = _localOpts.BannedRules.Contains("Descension");
        Ban_Same.IsChecked = _localOpts.BannedRules.Contains("Same");
        Ban_Plus.IsChecked = _localOpts.BannedRules.Contains("Plus");
        Ban_FallenAce.IsChecked = _localOpts.BannedRules.Contains("FallenAce");
        Ban_AllOpen.IsChecked = _localOpts.BannedRules.Contains("AllOpen");
        Ban_ThreeOpen.IsChecked = _localOpts.BannedRules.Contains("ThreeOpen");
        Ban_Swap.IsChecked = _localOpts.BannedRules.Contains("Swap");
        Ban_Order.IsChecked = _localOpts.BannedRules.Contains("Order");
        Ban_Chaos.IsChecked = _localOpts.BannedRules.Contains("Chaos");
        Ban_BombShelter.IsChecked = _localOpts.BannedRules.Contains("BombShelter");
        Ban_Reverse.IsChecked = _localOpts.BannedRules.Contains("Reverse");
        
        CheckBanLimit();

        _initializing = false;
    }

    private void HoneycombDifficultyCombo_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (_initializing) return;
        if (HoneycombDifficultyCombo.SelectedItem is ComboBoxItem item && item.Tag != null)
        {
            _localOpts.Difficulty = item.Tag.ToString()!;
        }
    }

    private void HoneycombRule_Changed(object? sender, RoutedEventArgs e)
    {
        if (_initializing) return;
        if (sender is CheckBox cb && cb.Tag is string tag)
        {
            if (tag == "ForceNormal")
            {
                _localOpts.ForceNormalRules = cb.IsChecked ?? false;
                if (_localOpts.ForceNormalRules)
                {
                    _localOpts.ManualRules.Clear();
                }
            }
            else if (Enum.TryParse<HoneycombRule>(tag, out var rule))
            {
                if (cb.IsChecked == true)
                {
                    if (!_localOpts.ManualRules.Contains(rule))
                    {
                        _localOpts.ManualRules.Add(rule);
                        
                        // Mutually exclusive pairs
                        if (rule == HoneycombRule.Ascension) _localOpts.ManualRules.Remove(HoneycombRule.Descension);
                        if (rule == HoneycombRule.Descension) _localOpts.ManualRules.Remove(HoneycombRule.Ascension);
                        if (rule == HoneycombRule.Order) _localOpts.ManualRules.Remove(HoneycombRule.Chaos);
                        if (rule == HoneycombRule.Chaos) _localOpts.ManualRules.Remove(HoneycombRule.Order);
                        if (rule == HoneycombRule.AllOpen) _localOpts.ManualRules.Remove(HoneycombRule.ThreeOpen);
                        if (rule == HoneycombRule.ThreeOpen) _localOpts.ManualRules.Remove(HoneycombRule.AllOpen);
                        
                        if (_localOpts.ManualRules.Count > 2)
                        {
                            _localOpts.ManualRules.RemoveAt(0);
                        }
                    }
                    _localOpts.ForceNormalRules = false;
                }
                else
                {
                    _localOpts.ManualRules.Remove(rule);
                }
            }
            SyncUI();
        }
    }

    private void BanRule_Changed(object? sender, RoutedEventArgs e)
    {
        if (_initializing) return;
        if (sender is CheckBox cb && cb.Tag is string ruleName)
        {
            bool isChecked = cb.IsChecked ?? false;
            
            if (isChecked)
            {
                if (_localOpts.BannedRules.Count >= 11) // Max 12 total, can't ban all 12
                {
                    // Revert UI immediately
                    _initializing = true;
                    cb.IsChecked = false;
                    _initializing = false;
                    
                    // Show warning
                    SillyBeeWarning.IsVisible = true;
                    // Auto-hide warning
                    DispatcherTimer.RunOnce(() => { SillyBeeWarning.IsVisible = false; }, TimeSpan.FromSeconds(3));
                    return;
                }
                
                if (!_localOpts.BannedRules.Contains(ruleName))
                    _localOpts.BannedRules.Add(ruleName);
            }
            else
            {
                _localOpts.BannedRules.Remove(ruleName);
            }
            
            CheckBanLimit();
        }
    }
    
    private void CheckBanLimit()
    {
        SillyBeeWarning.IsVisible = false;
    }

    private void OK_Click(object? sender, RoutedEventArgs e)
    {
        if (_vm == null) return;

        // Apply changes
        _vm.Options.Difficulty = _localOpts.Difficulty;
        _vm.Options.ForceNormalRules = _localOpts.ForceNormalRules;
        _vm.Options.ManualRules = _localOpts.ManualRules.ToList();
        _vm.Options.BannedRules = _localOpts.BannedRules.ToList();
        
        SettingsService.SaveHoneycombOptions(_vm.Options);
        
        OnCloseRequested?.Invoke(this, true);
    }

    public void Cancel_Click(object? sender, RoutedEventArgs e)
    {
        OnCloseRequested?.Invoke(this, false);
    }
}
