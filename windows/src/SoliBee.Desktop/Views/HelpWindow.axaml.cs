using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia.Controls;
using Avalonia.Interactivity;
using SoliBee.Core.Localization;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

public partial class HelpWindow : Window
{
    public IEnumerable<string> DynamicRules { get; }

    public HelpWindow(bool startAtHoneycomb = false)
    {
        InitializeComponent();

        var language = SettingsService.LoadOptions().Language;
        var rules = Enum.GetValues<SoliBee.Core.Models.HoneycombRule>();
        DynamicRules = rules.Select(r =>
            $"• {HoneycombRuleLocalization.LocalizedRuleName(r, language)}: {HoneycombRuleLocalization.LocalizedRuleExplanation(r, null, language)}");
        DataContext = this;

        ApplyLocalization(language);

        if (startAtHoneycomb)
        {
            Opened += (_, _) => ScrollToHoneycomb();
        }
    }

    // Mirrors the Mac port's HelpGuideView.swift content 1:1 (same source strings),
    // just laid out as one scrollable window instead of 7 separate ones. Shortcut key
    // combos (Ctrl+N, Alt+1, etc.) are Windows-specific and stay untranslated — only
    // the action description on the left of each "• Action: Shortcut" line is
    // localized. A few single-letter shortcuts (Escape, D, F, A, H, M, S, P) have no
    // translation and stay English, same as the Mac port's equivalent gaps.
    private void ApplyLocalization(AppLanguage language)
    {
        string T(StringKey key) => Strings.Get(key, language);
        string Row(StringKey actionKey, string shortcut) => $"• {T(actionKey)}: {shortcut}";

        HelpGuideTitleText.Text = T(StringKey.HelpGuideWindowTitle);
        ContentsHeaderText.Text = T(StringKey.HelpGuideContentsHeader);

        IdxKlondike.Content = T(StringKey.HelpKlondikeTitle);
        IdxFreecell.Content = T(StringKey.HelpBeecellTitle);
        IdxSpider.Content = T(StringKey.HelpSpiderTitle);
        IdxVP.Content = T(StringKey.HelpVideopokerTitle);
        IdxBJ.Content = T(StringKey.HelpBlackjackTitle);
        IdxHoneycomb.Content = T(StringKey.AppName);
        IdxThemes.Content = T(StringKey.HelpThemesSettingsIndexLabel);

        KlondikeHeaderText.Text = T(StringKey.HelpKlondikeTitle).ToUpperInvariant();
        FreecellHeaderText.Text = T(StringKey.HelpBeecellTitle).ToUpperInvariant();
        SpiderHeaderText.Text = T(StringKey.HelpSpiderTitle).ToUpperInvariant();
        VideoPokerHeaderText.Text = T(StringKey.HelpVideopokerTitle).ToUpperInvariant();
        BlackjackHeaderText.Text = T(StringKey.HelpBlackjackTitle).ToUpperInvariant();
        HoneycombHeaderText.Text = T(StringKey.AppName).ToUpperInvariant();
        ThemesHeaderText.Text = T(StringKey.HelpThemesSettingsIndexLabel).ToUpperInvariant();

        // ── Klondike ──────────────────────────────────────────────────────
        KlondikeOverviewHeading.Text = T(StringKey.HelpOverviewObjectiveTitle);
        KlondikeOverviewBody.Text = T(StringKey.HelpKlondikeObjective);
        KlondikeSetupHeading.Text = T(StringKey.HelpSetupLayoutTitle);
        KlondikeSetupBody.Text = T(StringKey.HelpKlondikeLayout);
        KlondikeRulesHeading.Text = T(StringKey.HelpRulesHowToPlayTitle);
        KlondikeRulesBody.Text = T(StringKey.HelpKlondikeRules);
        KlondikeShortcutsHeading.Text = T(StringKey.HelpControlsShortcutsTitle);
        KlondikeShortcutsBody.Text = string.Join("\n",
            Row(StringKey.HelpShortcutNavigateBoardCursor, "Arrow Keys"),
            Row(StringKey.HelpShortcutSelectPlaceCard, "Space / Enter"),
            Row(StringKey.HelpShortcutClearSelection, "Escape"),
            Row(StringKey.HelpShortcutDrawCards, "D"),
            Row(StringKey.HelpShortcutAutoMoveFoundation, "F"),
            Row(StringKey.AutocompleteGame, "A"),
            Row(StringKey.HelpShortcutNewGameRestartDeal, "Ctrl+N / Ctrl+R"),
            Row(StringKey.HelpShortcutUndoMove, "Ctrl+Z"),
            Row(StringKey.HelpShortcutToggleDraw, "Alt+1 / Alt+3"),
            Row(StringKey.HelpShortcutCycleHints, T(StringKey.HelpShortcutHintButton)));
        KlondikeStrategyHeading.Text = T(StringKey.HelpStrategyProTipsTitle);
        KlondikeStrategyBody.Text = T(StringKey.HelpKlondikeStrategy);
        KlondikeNoStressHeading.Text = T(StringKey.HelpNoStressModeTitle);
        KlondikeNoStressBody.Text = T(StringKey.HelpKlondikeNoStress);

        // ── Freecell (Beecell) ───────────────────────────────────────────
        FreecellOverviewHeading.Text = T(StringKey.HelpOverviewObjectiveTitle);
        FreecellOverviewBody.Text = T(StringKey.HelpBeecellObjective);
        FreecellSetupHeading.Text = T(StringKey.HelpSetupLayoutTitle);
        FreecellSetupBody.Text = T(StringKey.HelpBeecellLayout);
        FreecellRulesHeading.Text = T(StringKey.HelpRulesHowToPlayTitle);
        FreecellRulesBody.Text = T(StringKey.HelpBeecellRules);
        FreecellShortcutsHeading.Text = T(StringKey.HelpControlsShortcutsTitle);
        FreecellShortcutsBody.Text = string.Join("\n",
            Row(StringKey.HelpShortcutNavigateSelect, "Arrow Keys + Space / Enter"),
            Row(StringKey.HelpShortcutAutoParkFreeCell, "C"),
            Row(StringKey.HelpShortcutAutoMoveFoundation, "F"),
            Row(StringKey.AutocompleteGame, "A"),
            Row(StringKey.HelpShortcutNewGameRestartDeal, "Ctrl+N / Ctrl+R"),
            Row(StringKey.HelpShortcutUndoMove, "Ctrl+Z"),
            Row(StringKey.Hint, T(StringKey.HelpShortcutHintButton)));
        FreecellStrategyHeading.Text = T(StringKey.HelpStrategyProTipsTitle);
        FreecellStrategyBody.Text = T(StringKey.HelpBeecellStrategy);
        FreecellNoStressHeading.Text = T(StringKey.HelpNoStressModeTitle);
        FreecellNoStressBody.Text = T(StringKey.HelpKlondikeNoStress);

        // ── Spider ────────────────────────────────────────────────────────
        SpiderOverviewHeading.Text = T(StringKey.HelpOverviewObjectiveTitle);
        SpiderOverviewBody.Text = T(StringKey.HelpSpiderObjective);
        SpiderSetupHeading.Text = T(StringKey.HelpSetupLayoutTitle);
        SpiderSetupBody.Text = T(StringKey.HelpSpiderLayout);
        SpiderRulesHeading.Text = T(StringKey.HelpRulesHowToPlayTitle);
        SpiderRulesBody.Text = T(StringKey.HelpSpiderRules);
        SpiderShortcutsHeading.Text = T(StringKey.HelpControlsShortcutsTitle);
        SpiderShortcutsBody.Text = string.Join("\n",
            Row(StringKey.HelpShortcutDeal10Cards, "D"),
            Row(StringKey.HelpShortcutSelectPlaceSequence, "Space / Enter"),
            Row(StringKey.HelpShortcut1suit2suitMode, "Alt+1 / Alt+2"),
            Row(StringKey.HelpShortcutAutocomplete, "A"),
            Row(StringKey.HelpShortcutUndoMove, "Ctrl+Z"));
        SpiderStrategyHeading.Text = T(StringKey.HelpStrategyProTipsTitle);
        SpiderStrategyBody.Text = T(StringKey.HelpSpiderStrategy);
        SpiderNoStressHeading.Text = T(StringKey.HelpNoStressModeTitle);
        SpiderNoStressBody.Text = T(StringKey.HelpKlondikeNoStress);

        // ── Video Poker ───────────────────────────────────────────────────
        VideoPokerOverviewHeading.Text = T(StringKey.HelpOverviewObjectiveTitle);
        VideoPokerOverviewBody.Text = T(StringKey.HelpVideopokerObjective);
        VideoPokerHowToPlayHeading.Text = T(StringKey.HelpHowToPlayVariantsTitle);
        VideoPokerHowToPlayBody.Text = T(StringKey.HelpVideopokerHowToPlay);
        VideoPokerShortcutsHeading.Text = T(StringKey.HelpControlsShortcutsTitle);
        VideoPokerShortcutsBody.Text = string.Join("\n",
            Row(StringKey.HelpShortcutDealDraw, "Space / Enter"),
            Row(StringKey.HelpShortcutHoldCard12345, "1, 2, 3, 4, 5"),
            Row(StringKey.HelpShortcutHoldAllCards, "H"),
            Row(StringKey.HelpShortcutClearAllHolds, "C / Q"),
            Row(StringKey.HelpShortcutBetMaxDeal, "M"));
        VideoPokerStrategyHeading.Text = T(StringKey.HelpStrategyProTipsTitle);
        VideoPokerStrategyBody.Text = T(StringKey.HelpVideopokerStrategy);
        VideoPokerNoStressHeading.Text = T(StringKey.HelpNoStressModeTitle);
        VideoPokerNoStressBody.Text = T(StringKey.HelpVideopokerNoStress);

        // ── Video Blackjack ──────────────────────────────────────────────
        BlackjackOverviewHeading.Text = T(StringKey.HelpOverviewObjectiveTitle);
        BlackjackOverviewBody.Text = T(StringKey.HelpBlackjackObjective);
        BlackjackRulesHeading.Text = T(StringKey.HelpRulesOptionsTitle);
        BlackjackRulesBody.Text = T(StringKey.HelpBlackjackRules);
        BlackjackShortcutsHeading.Text = T(StringKey.HelpControlsShortcutsTitle);
        BlackjackShortcutsBody.Text = string.Join("\n",
            Row(StringKey.HelpShortcutDealBuyIn, "Space / Enter"),
            Row(StringKey.HelpShortcutHit, "H"),
            Row(StringKey.HelpShortcutStand, "S"),
            Row(StringKey.HelpShortcutDoubleDown, "D"),
            Row(StringKey.HelpShortcutSplitPairs, "P"),
            Row(StringKey.HelpShortcutBetMaxDeal, "M"));
        BlackjackStrategyHeading.Text = T(StringKey.HelpStrategyProTipsTitle);
        BlackjackStrategyBody.Text = T(StringKey.HelpBlackjackStrategy);
        BlackjackNoStressHeading.Text = T(StringKey.HelpNoStressModeTitle);
        BlackjackNoStressBody.Text = T(StringKey.HelpBlackjackNoStress);

        // ── Honeycomb ────────────────────────────────────────────────────
        HoneycombOverviewHeading.Text = T(StringKey.HelpOverviewObjectiveTitle);
        HoneycombOverviewBody.Text = T(StringKey.HelpHoneycombObjective);
        HoneycombMechanicsHeading.Text = T(StringKey.HelpCoreGameplayMechanicsTitle);
        HoneycombMechanicsBody.Text = T(StringKey.HelpHoneycombMechanics);
        HoneycombMatchModifiersHeading.Text = T(StringKey.HelpMatchModifiersTitle);
        // Body is the DynamicRules-bound ItemsControl (already language-aware — see
        // the constructor above), not a static TextBlock.
        HoneycombCardBankHeading.Text = T(StringKey.HelpCardBankStealingTitle);
        HoneycombCardBankBody.Text = T(StringKey.HelpHoneycombCardBank);
        HoneycombShortcutsHeading.Text = T(StringKey.HelpControlsShortcutsTitle);
        HoneycombShortcutsBody.Text = Row(StringKey.HelpShortcutSelectPlaceCard, T(StringKey.HelpShortcutClickDragTap)) + "\n" +
            Row(StringKey.HelpShortcutShowBestAiMove, T(StringKey.HelpShortcutHintButton));
        HoneycombNoStressHeading.Text = T(StringKey.HelpNoStressModeTitle);
        HoneycombNoStressBody.Text = T(StringKey.HelpHoneycombNoStress);

        // ── Themes ───────────────────────────────────────────────────────
        ThemesCustomizationHeading.Text = T(StringKey.HelpThemesCustomizationTitle);
        ThemesCustomizationBody.Text = T(StringKey.HelpCustomizationThemes);
        ThemesOptionsHeading.Text = T(StringKey.HelpOptionsTitle);
        ThemesOptionsBody.Text = T(StringKey.HelpCustomizationOptions);
    }

    public void ScrollToHoneycomb() => HoneycombAnchor.BringIntoView();

    private void GoTo_Klondike(object? sender, RoutedEventArgs e) =>
        KlondikeAnchor.BringIntoView();

    private void GoTo_Freecell(object? sender, RoutedEventArgs e) =>
        FreecellAnchor.BringIntoView();

    private void GoTo_Spider(object? sender, RoutedEventArgs e) =>
        SpiderAnchor.BringIntoView();

    private void GoTo_VideoPoker(object? sender, RoutedEventArgs e) =>
        VideoPokerAnchor.BringIntoView();

    private void GoTo_Blackjack(object? sender, RoutedEventArgs e) =>
        BlackjackAnchor.BringIntoView();

    private void GoTo_Honeycomb(object? sender, RoutedEventArgs e) =>
        HoneycombAnchor.BringIntoView();


    private void GoTo_Themes(object? sender, RoutedEventArgs e) =>
        ThemesAnchor.BringIntoView();

    private void Close_Click(object? sender, RoutedEventArgs e) => Close();
}
