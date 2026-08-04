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
    private HelpWindow? _helpWindow;

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
            ManualRules = vm.Options.ManualRules != null ? new HashSet<HoneycombRule>(vm.Options.ManualRules) : new HashSet<HoneycombRule>(),
            BannedRules = vm.Options.BannedRules != null ? new HashSet<string>(vm.Options.BannedRules) : new HashSet<string>()
        };
        
        SyncUI();
    }

    private void SyncUI()
    {
        _initializing = true;
        
        foreach (var item in HoneycombDifficultyCombo.Items.Cast<ComboBoxItem>())
        {
            if (item.Tag?.ToString() == _localOpts.Difficulty.ToString())
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
        HoneycombRule_SuddenDeath.IsChecked = _localOpts.ManualRules.Contains(HoneycombRule.SuddenDeath);

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
        Ban_SuddenDeath.IsChecked = _localOpts.BannedRules.Contains("SuddenDeath");

        CheckBanLimit();

        _initializing = false;
    }

    private void HoneycombDifficultyCombo_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (_initializing) return;
        if (HoneycombDifficultyCombo.SelectedItem is ComboBoxItem item && item.Tag != null
            && Enum.TryParse<HoneycombDifficulty>(item.Tag.ToString(), out var difficulty))
        {
            _localOpts.Difficulty = difficulty;
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
                    // Remove the exclusive partner (if any) BEFORE the cap check —
                    // selecting a rule whose partner is already selected is a net-zero
                    // swap, not an addition, so it must never be blocked just because
                    // the cap is full.
                    var updated = new HashSet<HoneycombRule>(_localOpts.ManualRules);
                    if (rule == HoneycombRule.Ascension) updated.Remove(HoneycombRule.Descension);
                    if (rule == HoneycombRule.Descension) updated.Remove(HoneycombRule.Ascension);
                    if (rule == HoneycombRule.Order) updated.Remove(HoneycombRule.Chaos);
                    if (rule == HoneycombRule.Chaos) updated.Remove(HoneycombRule.Order);
                    if (rule == HoneycombRule.AllOpen) updated.Remove(HoneycombRule.ThreeOpen);
                    if (rule == HoneycombRule.ThreeOpen) updated.Remove(HoneycombRule.AllOpen);
                    // Bomb Shelter's hidden card doesn't work when All Open/Three Open
                    // reveals every card anyway.
                    if (rule == HoneycombRule.AllOpen || rule == HoneycombRule.ThreeOpen) updated.Remove(HoneycombRule.BombShelter);
                    if (rule == HoneycombRule.BombShelter) { updated.Remove(HoneycombRule.AllOpen); updated.Remove(HoneycombRule.ThreeOpen); }

                    // Cap at 4 manual rules by blocking a 5th, rather than evicting the
                    // oldest — matches Mac's selectedRules picker (a Set has no reliable
                    // insertion order to evict by anyway).
                    if (updated.Count < 4)
                    {
                        updated.Add(rule);
                        _localOpts.ManualRules = updated;
                        _localOpts.ForceNormalRules = false;
                    }
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
        _vm.Options.ManualRules = new HashSet<HoneycombRule>(_localOpts.ManualRules);
        _vm.Options.BannedRules = new HashSet<string>(_localOpts.BannedRules);

        SettingsService.SaveHoneycombOptions(_vm.Options);
        _vm.NotifyOptionsChanged();

        OnCloseRequested?.Invoke(this, true);
    }

    public void Cancel_Click(object? sender, RoutedEventArgs e)
    {
        OnCloseRequested?.Invoke(this, false);
    }

    private void HoneycombHelp_Click(object? sender, RoutedEventArgs e)
    {
        if (_helpWindow != null) { _helpWindow.Activate(); _helpWindow.ScrollToHoneycomb(); return; }
        var owner = Avalonia.Controls.TopLevel.GetTopLevel(this) as Window;
        _helpWindow = new HelpWindow(startAtHoneycomb: true);
        _helpWindow.Closed += (_, _) => _helpWindow = null;
        if (owner != null) _helpWindow.Show(owner);
        else _helpWindow.Show();
    }
}
