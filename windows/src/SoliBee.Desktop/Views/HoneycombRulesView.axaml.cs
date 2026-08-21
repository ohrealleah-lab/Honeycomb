using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Media;
using Avalonia.Threading;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public partial class HoneycombRulesView : UserControl
{
    // Static brush pool (never allocate a SolidColorBrush per-row-per-refresh) — same
    // convention as CardView.axaml.cs's _brush* fields.
    private static readonly IBrush BrushAccent = new SolidColorBrush(Color.Parse("#007AFF"));
    private static readonly IBrush BrushBan = new SolidColorBrush(Color.Parse("#E53935"));
    private static readonly IBrush BrushWhite = Brushes.White;
    private static readonly IBrush BrushNeutralText = new SolidColorBrush(Color.Parse("#1A1A1A"));
    private static readonly IBrush BrushMutedText = new SolidColorBrush(Color.Parse("#8A8A8A"));
    private static readonly IBrush BrushTransparent = Brushes.Transparent;

    private HoneycombViewModel? _vm;
    private HoneycombOptions _localOpts;
    private HelpWindow? _helpWindow;
    private AppLanguage _language = AppLanguage.English;

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

        _language = SettingsService.LoadOptions().Language;
        ApplyLocalization();
        SyncUI();
    }

    private void ApplyLocalization()
    {
        OpponentLabel.Text = Strings.Get(StringKey.OpponentLabelColon, _language);
        BabyBeeItem.Content = Strings.Get(StringKey.StatBabyBee, _language);
        HoneyBeeItem.Content = Strings.Get(StringKey.StatHoneyBee, _language);
        QueenBeeItem.Content = Strings.Get(StringKey.StatQueenBee, _language);
        KillerBeeItem.Content = Strings.Get(StringKey.StatKillerBee, _language);
        HoneycombHelpButton.Content = Strings.Get(StringKey.HelpHoneycomb, _language);

        RulesTitleText.Text = Strings.Get(StringKey.RulesColumnTitle, _language);
        MatchRulesHintText.Text = Strings.Get(StringKey.MatchRulesHintWin, _language);

        SillyBeeWarning.Text = Strings.Get(StringKey.SillyBeeWarning, _language);
        CancelButton.Content = Strings.Get(StringKey.Cancel, _language);
        OkButton.Content = Strings.Get(StringKey.Ok, _language);
    }

    // One row per rule-or-Normal-Mode, mirroring shared/Honeycomb/Models/
    // HoneycombRuleSelectionEngine.swift's HoneycombRuleRowID on the Swift side
    // (Windows has no shared-Swift access, so the same Auto/Pick/Ban semantics —
    // max-4 cap, exclusive pairs, "can't ban everything" guard, Inversion/Reverse
    // staying ban-only — are mirrored here in C#).
    private sealed class RuleRowVM
    {
        public string Id = "";
        public string Title = "";
        public string Description = "";
        public bool IsPickable = true;
        public double PlayOpacity => IsPickable ? 1.0 : 0.0;
        public IBrush TitleColor = BrushNeutralText;
        public string AutoLabel = "";
        public string PickLabel = "";
        public string BanLabel = "";
        public IBrush AutoBg = BrushTransparent;
        public IBrush AutoFg = BrushMutedText;
        public IBrush PickBg = BrushTransparent;
        public IBrush PickFg = BrushMutedText;
        public IBrush BanBg = BrushTransparent;
        public IBrush BanFg = BrushMutedText;
    }

    // Every ban-list-eligible rule, "Normal Mode" first — matches the ban-set cap
    // ("can't ban all 14") used below.
    private static readonly HoneycombRule[] AllRules =
    {
        HoneycombRule.Ascension, HoneycombRule.Descension, HoneycombRule.Same, HoneycombRule.Plus,
        HoneycombRule.FallenAce, HoneycombRule.AllOpen, HoneycombRule.ThreeOpen, HoneycombRule.Swap,
        HoneycombRule.Order, HoneycombRule.Chaos, HoneycombRule.BombShelter, HoneycombRule.Reverse,
        HoneycombRule.SuddenDeath,
    };
    private const string NormalModeId = "Normal Mode";
    private const int TotalBanItems = 14; // Normal Mode + 13 HoneycombRule cases

    private void SyncUI()
    {
        foreach (var item in HoneycombDifficultyCombo.Items.Cast<ComboBoxItem>())
        {
            if (item.Tag?.ToString() == _localOpts.Difficulty.ToString())
            {
                HoneycombDifficultyCombo.SelectedItem = item;
                break;
            }
        }

        var autoLabel = Strings.Get(StringKey.RuleStateAuto, _language);
        var pickLabel = Strings.Get(StringKey.RuleStatePick, _language);
        var banLabel = Strings.Get(StringKey.RuleStateBan, _language);

        var rows = new List<RuleRowVM>
        {
            BuildRow(NormalModeId, Strings.Get(StringKey.ToggleNormalModeMac, _language),
                Strings.Get(StringKey.NormalModeBanListTooltip, _language), isPickable: true,
                isPicked: _localOpts.ForceNormalRules, isBanned: _localOpts.BannedRules.Contains(NormalModeId),
                autoLabel, pickLabel, banLabel)
        };
        foreach (var rule in AllRules)
        {
            rows.Add(BuildRow(rule.ToString(), HoneycombRuleLocalization.LocalizedRuleName(rule, _language),
                HoneycombRuleLocalization.LocalizedRuleExplanation(rule, null, _language),
                isPickable: rule != HoneycombRule.Reverse,
                isPicked: _localOpts.ManualRules.Contains(rule), isBanned: _localOpts.BannedRules.Contains(rule.ToString()),
                autoLabel, pickLabel, banLabel));
        }

        RuleRowsList.ItemsSource = rows;
        RulesSelectedCountText.Text = Strings.Get(StringKey.RulesSelectedCountFmt, _language).Replace("%d", _localOpts.ManualRules.Count.ToString());
        SillyBeeWarning.IsVisible = false;
    }

    private static RuleRowVM BuildRow(string id, string title, string description, bool isPickable,
        bool isPicked, bool isBanned, string autoLabel, string pickLabel, string banLabel)
    {
        var isAuto = !isPicked && !isBanned;
        return new RuleRowVM
        {
            Id = id,
            Title = title,
            Description = description,
            IsPickable = isPickable,
            TitleColor = isBanned ? BrushMutedText : BrushNeutralText,
            AutoLabel = autoLabel,
            PickLabel = pickLabel,
            BanLabel = banLabel,
            AutoBg = isAuto ? BrushWhite : BrushTransparent,
            AutoFg = isAuto ? BrushNeutralText : BrushMutedText,
            PickBg = isPicked ? BrushAccent : BrushTransparent,
            PickFg = isPicked ? BrushWhite : BrushMutedText,
            BanBg = isBanned ? BrushBan : BrushTransparent,
            BanFg = isBanned ? BrushWhite : BrushMutedText,
        };
    }

    private void HoneycombDifficultyCombo_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (HoneycombDifficultyCombo.SelectedItem is ComboBoxItem item && item.Tag != null
            && Enum.TryParse<HoneycombDifficulty>(item.Tag.ToString(), out var difficulty))
        {
            _localOpts.Difficulty = difficulty;
        }
    }

    private void AutoButton_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is not Button { Tag: string id }) return;
        _localOpts.BannedRules.Remove(id);
        if (id == NormalModeId) { _localOpts.ForceNormalRules = false; }
        else if (Enum.TryParse<HoneycombRule>(id, out var rule)) { _localOpts.ManualRules.Remove(rule); }
        SyncUI();
    }

    private void PickButton_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is not Button { Tag: string id }) return;
        _localOpts.BannedRules.Remove(id);

        if (id == NormalModeId)
        {
            _localOpts.ForceNormalRules = true;
            _localOpts.ManualRules.Clear();
        }
        else if (Enum.TryParse<HoneycombRule>(id, out var rule) && rule != HoneycombRule.Reverse)
        {
            // Remove the exclusive partner (if any) BEFORE the cap check — selecting a
            // rule whose partner is already selected is a net-zero swap, not an
            // addition, so it must never be blocked just because the cap is full.
            var updated = new HashSet<HoneycombRule>(_localOpts.ManualRules);
            if (rule == HoneycombRule.Ascension) updated.Remove(HoneycombRule.Descension);
            if (rule == HoneycombRule.Descension) updated.Remove(HoneycombRule.Ascension);
            if (rule == HoneycombRule.Order) updated.Remove(HoneycombRule.Chaos);
            if (rule == HoneycombRule.Chaos) updated.Remove(HoneycombRule.Order);
            if (rule == HoneycombRule.AllOpen) updated.Remove(HoneycombRule.ThreeOpen);
            if (rule == HoneycombRule.ThreeOpen) updated.Remove(HoneycombRule.AllOpen);
            // Bomb Shelter's hidden card doesn't work when All Open/Three Open reveals
            // every card anyway.
            if (rule == HoneycombRule.AllOpen || rule == HoneycombRule.ThreeOpen) updated.Remove(HoneycombRule.BombShelter);
            if (rule == HoneycombRule.BombShelter) { updated.Remove(HoneycombRule.AllOpen); updated.Remove(HoneycombRule.ThreeOpen); }

            if (updated.Count < 4)
            {
                updated.Add(rule);
                _localOpts.ManualRules = updated;
                _localOpts.ForceNormalRules = false;
            }
        }
        SyncUI();
    }

    private void BanButton_Click(object? sender, RoutedEventArgs e)
    {
        if (sender is not Button { Tag: string id }) return;

        // "Silly bee" guard — never allow banning the last remaining unbanned item.
        if (_localOpts.BannedRules.Count >= TotalBanItems - 1 && !_localOpts.BannedRules.Contains(id))
        {
            SillyBeeWarning.IsVisible = true;
            DispatcherTimer.RunOnce(() => { SillyBeeWarning.IsVisible = false; }, TimeSpan.FromSeconds(3));
            return;
        }

        if (id == NormalModeId) { _localOpts.ForceNormalRules = false; }
        else if (Enum.TryParse<HoneycombRule>(id, out var rule)) { _localOpts.ManualRules.Remove(rule); }
        _localOpts.BannedRules.Add(id);
        SyncUI();
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
