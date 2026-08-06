// GENERATED FILE — do not hand-edit.
// Regenerate via `python3 tools/generate_banner_catalog.py` from
// Honeycomb_Fun_Messages.xlsx. See that script for the id/gating rules.

using System.Collections.Generic;

namespace SoliBee.Core.Models;

// Stable identifier for every banner/toast catalog entry (Windows). Mirrors
// the Swift port's BannerID (shared/Honeycomb/Models/BannerID.swift) —
// same catalog, same ids, generated from the same spreadsheet in one pass.
public enum BannerId
{
    RuleSpecificNectarExchangeSwapsAwayThePlayers5StarCard,
    RuleSpecificNectarExchangeTradesThePlayersWorstCardForThe,
    RuleSpecificRouletteRollsZeroExtraRules,
    LoadingGameLoadsOnMay20thWorldBeeDay,
    LoadingGameLoadsOnNewYearsDayJan1,
    LoadingGameLoadsOnHalloweenOct31,
    LoadingGameLoadsOnValentinesDayFeb14,
    LoadingFirstLaunchAfterPlayingForOneYear,
    LoadingPlayingOnAprilFoolsDayApr1,
    LoadingMatchStartsBetween1200AmAnd400AmLocalTime,
    LoadingMatchStartsBetween500AmAnd800AmLocalTime,
    LoadingMatchStartsBetween900PmAndMidnightLocalTime,
    LoadingMatchStartsWithinAMinuteOfLocalNoon,
    LoadingOnGameLoad,
    IdleActionNoActionTakenForOneMinute,
    Gameplay3HintsUsedInOneMatch,
    GameplayUndoUsedImmediatelyAfterAPlacement,
    GameplayPlayerWinsAMatchWith4RulesActiveAtOnce,
    GameplayOpponentIsWinningByTwoCardsAndIsAboutToPlaceThe,
    GameplayPlayerFlips3CardsInASingleTurn,
    GameplayOpponentFlips3OfThePlayersCardsInASingleTurnNotA,
    GameplayComboX4OrHigher,
    GameplayPlayerHasOnly2CardsOnTheBoardVsOpponents6Few,
    GameplayAPlacedCardCapturesOnAll4SidesAtOnce,
    Gameplay3RematchWinsInARowAgainstTheSameOpponent,
    Gameplay3RematchLossesInARowAgainstTheSameOpponent,
    GameplayA1StarCardCaptures3CardsInOneMove,
    GameplayA1StarCardCapturesA5StarCardRarityMismatch,
    GameplayPlayerUsesUndoThinksAboutItAndThenMakesTheExact,
    GameplayPlayerPlaysAgainstTheSameAiDifficulty5TimesInARow,
    GameplayPlayerWinsByTheMaximumPossibleMargin,
    MilestonesFirstLaunchEver,
    MilestonesPlayerReaches10TotalWins,
    MilestonesPlayerReaches100TotalWins,
    MilestonesPlayerReaches1000TotalWins,
    RuleSpecificFallenAceTriggersA1CapturesA10,
    RuleSpecificPollinationPushesACardsModifierTo3OrHigher,
    RuleSpecificSmokedOutDropsACardsEffectiveStatTo1,
    RuleSpecificAPlayerTriggersAPlusComboTheMathMatchesPerfectly,
    RuleSpecificPlayerWinsFlawlessOpponentScore0,
    RuleSpecificPlayerLosesFlawless0Captures,
    RuleSpecificRouletteRollsPollination,
    RuleSpecificRouletteRollsSmokedOut,
    RuleSpecificRouletteRollsMathBee,
    RuleSpecificRouletteRollsInversion,
    RuleSpecificRouletteRollsClearSkies,
    RuleSpecificRouletteRollsScoutingParty,
    RuleSpecificRouletteRollsFrenzy,
    RuleSpecificRouletteRollsSymmetry,
    RuleSpecificRouletteRollsNectarExchange,
    RuleSpecificRouletteRollsHierarchy,
}

public static class BannerIdExtensions
{
    // Maps the JSON catalog's snake_case `id` string to its BannerId —
    // needed because System.Text.Json won't auto-match snake_case ids to
    // PascalCase enum members.
    private static readonly Dictionary<string, BannerId> ById = new()
    {
        ["rule_specific_nectar_exchange_swaps_away_the_players_5_star_card"] = BannerId.RuleSpecificNectarExchangeSwapsAwayThePlayers5StarCard,
        ["rule_specific_nectar_exchange_trades_the_players_worst_card_for_the"] = BannerId.RuleSpecificNectarExchangeTradesThePlayersWorstCardForThe,
        ["rule_specific_roulette_rolls_zero_extra_rules"] = BannerId.RuleSpecificRouletteRollsZeroExtraRules,
        ["loading_game_loads_on_may_20th_world_bee_day"] = BannerId.LoadingGameLoadsOnMay20thWorldBeeDay,
        ["loading_game_loads_on_new_years_day_jan_1"] = BannerId.LoadingGameLoadsOnNewYearsDayJan1,
        ["loading_game_loads_on_halloween_oct_31"] = BannerId.LoadingGameLoadsOnHalloweenOct31,
        ["loading_game_loads_on_valentines_day_feb_14"] = BannerId.LoadingGameLoadsOnValentinesDayFeb14,
        ["loading_first_launch_after_playing_for_one_year"] = BannerId.LoadingFirstLaunchAfterPlayingForOneYear,
        ["loading_playing_on_april_fools_day_apr_1"] = BannerId.LoadingPlayingOnAprilFoolsDayApr1,
        ["loading_match_starts_between_12_00_am_and_4_00_am_local_time"] = BannerId.LoadingMatchStartsBetween1200AmAnd400AmLocalTime,
        ["loading_match_starts_between_5_00_am_and_8_00_am_local_time"] = BannerId.LoadingMatchStartsBetween500AmAnd800AmLocalTime,
        ["loading_match_starts_between_9_00_pm_and_midnight_local_time"] = BannerId.LoadingMatchStartsBetween900PmAndMidnightLocalTime,
        ["loading_match_starts_within_a_minute_of_local_noon"] = BannerId.LoadingMatchStartsWithinAMinuteOfLocalNoon,
        ["loading_on_game_load"] = BannerId.LoadingOnGameLoad,
        ["idle_action_no_action_taken_for_one_minute"] = BannerId.IdleActionNoActionTakenForOneMinute,
        ["gameplay_3_hints_used_in_one_match"] = BannerId.Gameplay3HintsUsedInOneMatch,
        ["gameplay_undo_used_immediately_after_a_placement"] = BannerId.GameplayUndoUsedImmediatelyAfterAPlacement,
        ["gameplay_player_wins_a_match_with_4_rules_active_at_once"] = BannerId.GameplayPlayerWinsAMatchWith4RulesActiveAtOnce,
        ["gameplay_opponent_is_winning_by_two_cards_and_is_about_to_place_the"] = BannerId.GameplayOpponentIsWinningByTwoCardsAndIsAboutToPlaceThe,
        ["gameplay_player_flips_3_cards_in_a_single_turn"] = BannerId.GameplayPlayerFlips3CardsInASingleTurn,
        ["gameplay_opponent_flips_3_of_the_players_cards_in_a_single_turn_not_a"] = BannerId.GameplayOpponentFlips3OfThePlayersCardsInASingleTurnNotA,
        ["gameplay_combo_x4_or_higher"] = BannerId.GameplayComboX4OrHigher,
        ["gameplay_player_has_only_2_cards_on_the_board_vs_opponents_6_few"] = BannerId.GameplayPlayerHasOnly2CardsOnTheBoardVsOpponents6Few,
        ["gameplay_a_placed_card_captures_on_all_4_sides_at_once"] = BannerId.GameplayAPlacedCardCapturesOnAll4SidesAtOnce,
        ["gameplay_3_rematch_wins_in_a_row_against_the_same_opponent"] = BannerId.Gameplay3RematchWinsInARowAgainstTheSameOpponent,
        ["gameplay_3_rematch_losses_in_a_row_against_the_same_opponent"] = BannerId.Gameplay3RematchLossesInARowAgainstTheSameOpponent,
        ["gameplay_a_1_star_card_captures_3_cards_in_one_move"] = BannerId.GameplayA1StarCardCaptures3CardsInOneMove,
        ["gameplay_a_1_star_card_captures_a_5_star_card_rarity_mismatch"] = BannerId.GameplayA1StarCardCapturesA5StarCardRarityMismatch,
        ["gameplay_player_uses_undo_thinks_about_it_and_then_makes_the_exact"] = BannerId.GameplayPlayerUsesUndoThinksAboutItAndThenMakesTheExact,
        ["gameplay_player_plays_against_the_same_ai_difficulty_5_times_in_a_row"] = BannerId.GameplayPlayerPlaysAgainstTheSameAiDifficulty5TimesInARow,
        ["gameplay_player_wins_by_the_maximum_possible_margin"] = BannerId.GameplayPlayerWinsByTheMaximumPossibleMargin,
        ["milestones_first_launch_ever"] = BannerId.MilestonesFirstLaunchEver,
        ["milestones_player_reaches_10_total_wins"] = BannerId.MilestonesPlayerReaches10TotalWins,
        ["milestones_player_reaches_100_total_wins"] = BannerId.MilestonesPlayerReaches100TotalWins,
        ["milestones_player_reaches_1000_total_wins"] = BannerId.MilestonesPlayerReaches1000TotalWins,
        ["rule_specific_fallen_ace_triggers_a_1_captures_a_10"] = BannerId.RuleSpecificFallenAceTriggersA1CapturesA10,
        ["rule_specific_pollination_pushes_a_cards_modifier_to_3_or_higher"] = BannerId.RuleSpecificPollinationPushesACardsModifierTo3OrHigher,
        ["rule_specific_smoked_out_drops_a_cards_effective_stat_to_1"] = BannerId.RuleSpecificSmokedOutDropsACardsEffectiveStatTo1,
        ["rule_specific_a_player_triggers_a_plus_combo_the_math_matches_perfectly"] = BannerId.RuleSpecificAPlayerTriggersAPlusComboTheMathMatchesPerfectly,
        ["rule_specific_player_wins_flawless_opponent_score_0"] = BannerId.RuleSpecificPlayerWinsFlawlessOpponentScore0,
        ["rule_specific_player_loses_flawless_0_captures"] = BannerId.RuleSpecificPlayerLosesFlawless0Captures,
        ["rule_specific_roulette_rolls_pollination"] = BannerId.RuleSpecificRouletteRollsPollination,
        ["rule_specific_roulette_rolls_smoked_out"] = BannerId.RuleSpecificRouletteRollsSmokedOut,
        ["rule_specific_roulette_rolls_math_bee"] = BannerId.RuleSpecificRouletteRollsMathBee,
        ["rule_specific_roulette_rolls_inversion"] = BannerId.RuleSpecificRouletteRollsInversion,
        ["rule_specific_roulette_rolls_clear_skies"] = BannerId.RuleSpecificRouletteRollsClearSkies,
        ["rule_specific_roulette_rolls_scouting_party"] = BannerId.RuleSpecificRouletteRollsScoutingParty,
        ["rule_specific_roulette_rolls_frenzy"] = BannerId.RuleSpecificRouletteRollsFrenzy,
        ["rule_specific_roulette_rolls_symmetry"] = BannerId.RuleSpecificRouletteRollsSymmetry,
        ["rule_specific_roulette_rolls_nectar_exchange"] = BannerId.RuleSpecificRouletteRollsNectarExchange,
        ["rule_specific_roulette_rolls_hierarchy"] = BannerId.RuleSpecificRouletteRollsHierarchy,
    };

    public static BannerId Parse(string id) => ById[id];
}
