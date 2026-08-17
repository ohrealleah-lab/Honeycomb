// GENERATED FILE — do not hand-edit.
// Regenerate via `python3 tools/generate_localization.py` from
// Honeycomb_Localization.xlsx.

// Stable identifier for every localizable string (mac + iOS). Mirrors the
// Windows port's StringKey (windows/src/SoliBee.Core/Localization/StringKey.cs)
// — same keys, generated from the same spreadsheet in one pass.
public enum StringKey: String, CaseIterable {
    /// File menu / toolbar button
    case newGame = "new_game"
    /// File menu / toolbar button
    case restart = "restart"
    /// File menu / toolbar button
    case undo = "undo"
    /// Button, reused across every dialog/sheet
    case cancel = "cancel"
    /// Button, reused across every dialog/sheet
    case ok = "ok"
    /// Button, reused across every dialog/sheet
    case done = "done"
    /// Toolbar button label
    case hint = "hint"
    /// Toolbar button label
    case options = "options"
    /// Options sheet title (default)
    case preferences = "preferences"
    /// Options sheet button
    case viewStats = "view_stats"
    /// Options sheet section header
    case visualThemes = "visual_themes"
    /// Options sheet section subtitle
    case visualThemesSubtitle = "visual_themes_subtitle"
    /// New Language row label, top of Options
    case language = "language"
    /// Language picker option (kept in Latin script for both languages)
    case languageEnglish = "language_english"
    /// Language picker option (kept in Spanish for both languages)
    case languageSpanish = "language_spanish"
    /// Alert title
    case resetStatisticsTitle = "reset_statistics_title"
    /// Alert body
    case resetStatisticsBody = "reset_statistics_body"
    /// Alert button
    case reset = "reset"
    /// Status bar label
    case scoreLabel = "score_label"
    /// Status bar label
    case movesLabel = "moves_label"
    /// Status bar label
    case timeLabel = "time_label"
    /// Save button, reused across many dialogs/editors (Mac Themes/Backgrounds/CardArt editors, iOS import sheets, Windows theme dialogs)
    case save = "save"
    /// Delete button, reused across many alerts/dialogs
    case delete = "delete"
    /// Remove button, reused across many dialogs (iOS FaceCardArt, background/card-back removal)
    case remove = "remove"
    /// Add… menu item / button, reused (Mac background picker, Windows theme editor)
    case add = "add"
    /// Short 'Add' button (iOS import sheets, Windows deck rows)
    case addShort = "add_short"
    /// Edit button, reused (iOS deck rows, Mac deck rows)
    case edit = "edit"
    /// Back-navigation button, reused (Mac Themes header, Windows preferences back button)
    case back = "back"
    /// Close button, reused across stats screens on Mac and Windows
    case close = "close"
    /// Generic alert title for file-import errors, reused across Mac editors
    case errorTitle = "error_title"
    /// Confirmation dialog button (Windows discard-changes dialog)
    case yes = "yes"
    /// Sound toggle label, reused across every game's Options on Mac/iOS/Windows
    case soundEffects = "sound_effects"
    /// Short 'Sound' toggle label (iOS settings sections)
    case soundShort = "sound_short"
    /// Toggle label, reused across every game's Options on Mac/iOS/Windows
    case noStressMode = "no_stress_mode"
    /// Toggle label, reused across every game's Options on Mac/iOS/Windows
    case honeyMode = "honey_mode"
    /// Toggle label, reused across games (capitalization varies slightly at call sites — treat as one string)
    case hideHintButton = "hide_hint_button"
    /// Toggle label, reused across every game's Options on Mac/iOS/Windows
    case manuallyDismissBanners = "manually_dismiss_banners"
    /// Toggle label (Windows short form; Mac/iOS use 'Vegas Scoring Mode' — separate key)
    case vegasScoring = "vegas_scoring"
    /// Toggle label, longer form used on Mac/iOS Klondike Options
    case vegasScoringMode = "vegas_scoring_mode"
    /// Toggle label (Windows Preferences; Mac's menu-bar equivalent is 'stay_on_top')
    case alwaysOnTop = "always_on_top"
    /// Timer toggle label, reused across iOS Klondike/Spider/Beecell settings
    case timed = "timed"
    /// Toggle label, Video Poker/Blackjack Options (Mac/iOS/Windows)
    case hideBetBoard = "hide_bet_board"
    /// Stepper label, %d = credit amount — reused in Blackjack/Video Poker Options
    case startingCreditsFmt = "starting_credits_fmt"
    /// Uppercase hand-area label, reused across Blackjack/Honeycomb on all 3 platforms
    case dealerLabel = "dealer_label"
    /// Uppercase hand-area label, reused across Blackjack/Honeycomb on all 3 platforms
    case playerLabel = "player_label"
    /// 'VS' divider label between dealer/player, Blackjack
    case vsDivider = "vs_divider"
    /// Win overlay headline — 'You Win!' is the majority spelling across iOS/Windows; Mac's Klondike/Beecell/Blackjack use lowercase 'You win!' (same meaning, minor copy inconsistency worth a follow-up copy pass, not blocking translation)
    case youWin = "you_win"
    /// Stuck-game overlay heading, reused across Mac/iOS games
    case gameOver = "game_over"
    /// Stuck-game overlay body, reused across Mac/iOS games
    case noMovesRemaining = "no_moves_remaining"
    /// Button, reused across Mac/iOS stuck-game overlays and confirm dialogs
    case restartGame = "restart_game"
    /// Autocomplete-available overlay headline, reused across Mac Klondike/Beecell/Spider
    case victoryGuaranteed = "victory_guaranteed"
    /// Button, reused across Mac Klondike/Beecell/Spider
    case autocompleteGame = "autocomplete_game"
    /// Win-overlay tappable label, reused across Mac Klondike/Beecell
    case playAgain = "play_again"
    /// Flash banner text, reused verbatim across Mac/iOS Klondike/Beecell/Spider/Honeycomb
    case noHintsAvailable = "no_hints_available"
    /// confirmationDialog title, reused across Mac Klondike/Beecell
    case newGameConfirmTitle = "new_game_confirm_title"
    /// Win-overlay score fragment, %@ = score string — reused across Mac/iOS Klondike/Beecell/Spider
    case scoreFmt = "score_fmt"
    /// Win-overlay bankroll fragment (Vegas mode), %@ = bankroll string — reused across Mac/iOS Klondike
    case bankrollFmt = "bankroll_fmt"
    /// Stat row label, reused across Mac/iOS/Windows stats screens (colon-suffixed variant used on Mac 'Games Played:')
    case gamesPlayed = "games_played"
    /// Stat row label, reused across Mac/iOS/Windows stats screens (colon-suffixed variant used on Mac 'Games Won:')
    case gamesWon = "games_won"
    /// Stat row label, reused across Mac/iOS stats screens (colon-suffixed variant used on Mac 'High Score:')
    case highScore = "high_score"
    /// Stat row label, Mac 'Win Percentage:'
    case winPercentage = "win_percentage"
    /// Stat row label, reused across Mac/iOS stats screens
    case currentStreak = "current_streak"
    /// Stat row label, reused across Mac/iOS stats screens
    case longestStreak = "longest_streak"
    /// Stat row label, Mac Klondike/Beecell 'Avg Winning Time:'
    case avgWinningTime = "avg_winning_time"
    /// Stat row label, reused across Mac/iOS stats screens
    case fastestWin = "fastest_win"
    /// Button, reused across every stats screen on Mac/Windows
    case resetStats = "reset_stats"
    /// Alert body, generic (non-game-specific) wording — distinct from the seeded 'reset_statistics_body' which says 'for the current game'
    case resetStatisticsBodyGeneric = "reset_statistics_body_generic"
    /// Stat row label, reused Blackjack/Video Poker
    case handsPlayed = "hands_played"
    /// Stat row label, reused Blackjack/Video Poker
    case handsWon = "hands_won"
    /// Stat row label, reused Blackjack/Video Poker/Honeycomb
    case winRate = "win_rate"
    /// Stat row label, reused Blackjack/Video Poker
    case totalWagered = "total_wagered"
    /// Stat row label, reused Blackjack/Video Poker
    case totalPaid = "total_paid"
    /// Stat row label, reused Blackjack/Video Poker
    case biggestPay = "biggest_pay"
    /// Stat row label (Return To Player %), reused Blackjack/Video Poker
    case rtpStat = "rtp_stat"
    /// Stat row label, reused Blackjack/Video Poker
    case rebuysStat = "rebuys_stat"
    /// Stat row label, Video Poker
    case royalFlushes = "royal_flushes"
    /// Interpolated deck-mode label used inside Freecell/Beecell stats title format
    case deckCount1 = "deck_count_1"
    /// Interpolated deck-mode label used inside Freecell/Beecell stats title format
    case deckCount2 = "deck_count_2"
    /// Interpolated suit-count label used inside Spider stats title format
    case suitCount1 = "suit_count_1"
    /// Interpolated suit-count label used inside Spider stats title format
    case suitCount2 = "suit_count_2"
    /// Interpolated suit-count label used inside Spider stats title format
    case suitCount4 = "suit_count_4"
    /// Button/sheet title, reused Mac/Windows Honeycomb
    case manageDecks = "manage_decks"
    /// Button, reused across Mac/iOS/Windows Honeycomb
    case rematch = "rematch"
    /// Button, Honeycomb
    case newMatch = "new_match"
    /// Loss overlay headline, reused verbatim across Mac Blackjack/Video Poker and Windows Video Poker/Honeycomb
    case notTodayPartner = "not_today_partner"
    /// Post-game overlay confirmation after a steal, reused Mac/iOS Honeycomb
    case cardAddedToBank = "card_added_to_bank"
    /// Post-game overlay note, reused Mac/iOS Honeycomb
    case cardBankFullLine1 = "card_bank_full_line1"
    /// Post-game overlay flavor line, reused Mac/iOS Honeycomb
    case cardBankFullLine2 = "card_bank_full_line2"
    /// Post-game overlay note, %@/{0} = opponent name — reused Mac/iOS/Windows Honeycomb
    case obtainedAllCardsFmt = "obtained_all_cards_fmt"
    /// Post-game overlay note, reused Mac/iOS Honeycomb
    case rematchToTakeAnother = "rematch_to_take_another"
    /// Post-game overlay flavor line, reused Mac/iOS/Windows Honeycomb
    case stealProtectionLine = "steal_protection_line"
    /// Post-game action button, reused Mac/Windows Honeycomb
    case stealCard = "steal_card"
    /// Steal-confirmation alert/panel title, reused Mac/iOS/Windows Honeycomb
    case confirmStealTitle = "confirm_steal_title"
    /// Steal-mode instruction banner, reused Mac/iOS/Windows Honeycomb (line break preserved)
    case stealInstruction = "steal_instruction"
    /// Ban-list guard warning, reused Mac/iOS Honeycomb
    case sillyBeeWarning = "silly_bee_warning"
    /// Destructive button, reused Mac/iOS Honeycomb deck manager
    case startOver = "start_over"
    /// Alert title, reused Mac/iOS Honeycomb deck manager
    case startOverTitle = "start_over_title"
    /// Start-over panel explainer text, reused Mac/iOS Honeycomb deck manager
    case startOverBody = "start_over_body"
    /// Start-over confirmation alert body, reused Mac/iOS Honeycomb deck manager
    case startOverAlertBody = "start_over_alert_body"
    /// Saved-deck row placeholder, %d = slot number — reused Mac/iOS Honeycomb
    case emptySlotFmt = "empty_slot_fmt"
    /// Badge/button on the currently-active saved deck, reused Mac/iOS Honeycomb
    case deckActiveBadge = "deck_active_badge"
    /// Button, reused Mac/iOS Honeycomb
    case deckSetActive = "deck_set_active"
    /// Button, reused Mac/iOS Honeycomb
    case deckCreate = "deck_create"
    /// Filter menu item/chip, reused Mac/iOS Honeycomb deck manager
    case allStarsFilter = "all_stars_filter"
    /// Filter menu item, %d = star rating — reused Mac/iOS Honeycomb deck manager
    case starCountFmt = "star_count_fmt"
    /// Filter menu item/chip, reused Mac/iOS Honeycomb deck manager
    case allSuitsFilter = "all_suits_filter"
    /// Filter/label item, reused Mac/iOS Honeycomb deck manager
    case suitSpades = "suit_spades"
    /// Filter/label item, reused Mac/iOS Honeycomb deck manager
    case suitHearts = "suit_hearts"
    /// Filter/label item, reused Mac/iOS Honeycomb deck manager
    case suitDiamonds = "suit_diamonds"
    /// Filter/label item, reused Mac/iOS Honeycomb deck manager
    case suitClubs = "suit_clubs"
    /// Filter toggle chip label, reused Mac/iOS Honeycomb deck manager
    case favoritesFilter = "favorites_filter"
    /// Clear-filters button, reused Mac/iOS Honeycomb deck manager
    case clearFilters = "clear_filters"
    /// Sheet/nav title, reused Mac/iOS Honeycomb deck manager
    case deckBuilderTitle = "deck_builder_title"
    /// Helper text, reused Mac/iOS Honeycomb deck manager
    case deckRulesHint = "deck_rules_hint"
    /// Deck validation error, reused Mac/iOS Honeycomb deck manager
    case errTooMany5star = "err_too_many_5star"
    /// Deck validation error, reused Mac/iOS Honeycomb deck manager
    case err5star4starCombo = "err_5star_4star_combo"
    /// Deck validation error, reused Mac/iOS Honeycomb deck manager
    case errTooMany4star = "err_too_many_4star"
    /// Deck validation error, reused Mac/iOS Honeycomb deck manager
    case errNameTooLong = "err_name_too_long"
    /// Section header, %d of %d = unlocked/total — reused Mac/iOS Honeycomb deck manager
    case cardBankCountFmt = "card_bank_count_fmt"
    /// Section header, %d = card count out of 5 — reused Mac/iOS Honeycomb deck manager (Mac uses '-' iOS uses '—', treated as one string)
    case yourDeckCountFmt = "your_deck_count_fmt"
    /// Section header, reused Mac/iOS Honeycomb deck manager
    case cardBankTapToAdd = "card_bank_tap_to_add"
    /// Action button, reused Blackjack/Video Poker (Mac/iOS/Windows)
    case dealButton = "deal_button"
    /// Action button, reused Blackjack/Video Poker (Mac/iOS/Windows 'Buy In')
    case rebuyButton = "rebuy_button"
    /// Action button, Windows Blackjack/Video Poker (equivalent to Mac/iOS 'Rebuy')
    case buyInButton = "buy_in_button"
    /// Idle-state nudge text, reused Windows Blackjack/Video Poker
    case hitSpaceToDeal = "hit_space_to_deal"
    /// Action button, reused Video Poker (Mac/iOS/Windows)
    case holdAll = "hold_all"
    /// Action button, reused Video Poker (Mac/iOS/Windows)
    case betMax = "bet_max"
    /// Score badge, %d = player score — Honeycomb touch view
    case scoreYouFmt = "score_you_fmt"
    /// Score badge, %d = dealer score — Honeycomb touch view
    case scoreDealerFmt = "score_dealer_fmt"
    /// Window nav title, SoliBeeApp.swift
    case appNavigationTitle = "app_navigation_title"
    /// File menu item
    case resetDefaultCardBacks = "reset_default_card_backs"
    /// View menu toggle
    case stayOnTop = "stay_on_top"
    /// Window title / Help menu item
    case helpKlondike = "help_klondike"
    /// Window title / Help menu item
    case helpFreecell = "help_freecell"
    /// Window title / Help menu item
    case helpSpider = "help_spider"
    /// Window title / Help menu item
    case helpVideopoker = "help_videopoker"
    /// Window title / Help menu item
    case helpBlackjack = "help_blackjack"
    /// Window title / Help menu item
    case helpHoneycomb = "help_honeycomb"
    /// Window title / Help menu item
    case helpThemes = "help_themes"
    /// Window title / App menu item / Windows Preferences button
    case aboutHoneycomb = "about_honeycomb"
    /// App name — proper noun, kept as-is in both languages
    case appName = "app_name"
    /// Kerned label under app name
    case cardSuiteLabel = "card_suite_label"
    /// %@ = app version string
    case versionFmt = "version_fmt"
    /// Copyright text
    case copyrightNotice = "copyright_notice"
    /// Personal dedication text
    case dedication = "dedication"
    /// Button
    case checkForUpdates = "check_for_updates"
    /// Status text
    case checkingForUpdates = "checking_for_updates"
    /// Status text
    case upToDate = "up_to_date"
    /// Button
    case checkAgain = "check_again"
    /// Error message
    case updateCheckFailed = "update_check_failed"
    /// Button
    case tryAgain = "try_again"
    /// %@ = version number
    case newerVersionAvailableFmt = "newer_version_available_fmt"
    /// Button
    case viewRelease = "view_release"
    /// Status bar label
    case statusBankroll = "status_bankroll"
    /// Overlay text on stock pile (line break preserved)
    case stockExhausted = "stock_exhausted"
    /// Stuck-game overlay, %@ = bankroll string
    case finalBankrollFmt = "final_bankroll_fmt"
    /// Autocomplete overlay body, Klondike wording
    case autocompleteBodyKlondike = "autocomplete_body_klondike"
    /// Autocomplete overlay body, Beecell/Spider wording (differs slightly from Klondike's — flagged for a copy-consistency pass, not a translation blocker)
    case autocompleteBodyOther = "autocomplete_body_other"
    /// HotkeyLegendView text
    case hotkeyLegendKlondike = "hotkey_legend_klondike"
    /// HotkeyLegendView text, Beecell
    case hotkeyLegendBeecell = "hotkey_legend_beecell"
    /// HotkeyLegendView text, Spider
    case hotkeyLegendSpider = "hotkey_legend_spider"
    /// HotkeyLegendView text, Blackjack
    case hotkeyLegendBlackjack = "hotkey_legend_blackjack"
    /// HotkeyLegendView text, Video Poker
    case hotkeyLegendVideopoker = "hotkey_legend_videopoker"
    /// confirmationDialog title, Klondike
    case restartConfirmTitle = "restart_confirm_title"
    /// confirmationDialog title, Blackjack/Video Poker (shorter wording than the common 'new_game_confirm_title')
    case newGameConfirmTitleShort = "new_game_confirm_title_short"
    /// Win overlay, generic — first %@ already contains 'Score: X' or 'Bankroll: X', second %@ = formatted time
    case winSummaryWithTimeFmt = "win_summary_with_time_fmt"
    /// Picker label
    case drawModeLabel = "draw_mode_label"
    /// Picker option
    case drawOne = "draw_one"
    /// Picker option
    case drawThree = "draw_three"
    /// Sub-screen header when Face Cards panel open
    case faceCardsTitle = "face_cards_title"
    /// Sub-screen header when Card Colors panel open
    case cardColorsTitle = "card_colors_title"
    /// Panel header fallback
    case themesPanelTitle = "themes_panel_title"
    /// Bold heading above face card art grid
    case addCustomCardArtHeading = "add_custom_card_art_heading"
    /// Suffix text next to heading
    case jpgPngAcceptedSuffix = "jpg_png_accepted_suffix"
    /// Tooltip on hero backdrop preview
    case doubleClickAdjustBackgroundTooltip = "double_click_adjust_background_tooltip"
    /// Tooltip on hero card preview
    case clickAdjustCardBackTooltip = "click_adjust_card_back_tooltip"
    /// Label next to felt ColorPicker
    case customFeltColorLabel = "custom_felt_color_label"
    /// Nav row title
    case customizeFaceCardsTitle = "customize_face_cards_title"
    /// Nav row subtitle
    case customizeFaceCardsSubtitle = "customize_face_cards_subtitle"
    /// Nav row title
    case customCardColorsTitle = "custom_card_colors_title"
    /// Nav row subtitle, Mac wording
    case customCardColorsSubtitleMac = "custom_card_colors_subtitle_mac"
    /// Nav row subtitle, Windows wording (differs slightly from Mac — 'text' vs 'suit text')
    case customCardColorsSubtitleWin = "custom_card_colors_subtitle_win"
    /// Note above the 3-card mock preview
    case livePreviewNotice = "live_preview_notice"
    /// Label next to Background picker (Mac); Windows uses plain 'Background' as a section header — merged into one key
    case backgroundLabel = "background_label"
    /// Felt preset picker option
    case feltGreen = "felt_green"
    /// Felt preset picker option
    case feltCrimson = "felt_crimson"
    /// Felt preset picker option
    case feltRoyalBlue = "felt_royal_blue"
    /// Felt preset picker option
    case feltCharcoal = "felt_charcoal"
    /// Felt preset picker option
    case feltDesert = "felt_desert"
    /// Felt preset picker option
    case feltCustomColor = "felt_custom_color"
    /// Picker menu item that opens file picker
    case addCustomBackgroundOption = "add_custom_background_option"
    /// Toggle label, reused Mac/iOS/Windows
    case feltVignetteToggle = "felt_vignette_toggle"
    /// Button to delete active custom background
    case deleteCurrentWallpaper = "delete_current_wallpaper"
    /// Inline error text under editor sheet
    case couldNotSaveBackgroundError = "could_not_save_background_error"
    /// Confirmation alert title, reused Mac/Windows
    case deleteBackgroundTitle = "delete_background_title"
    /// Alert body, reused Mac/Windows
    case deleteBackgroundBody = "delete_background_body"
    /// Alert title, reused Mac/Windows
    case backgroundInUseTitle = "background_in_use_title"
    /// NSAlert message, reused twice on Mac
    case couldNotLoadSelectedImageFileError = "could_not_load_selected_image_file_error"
    /// NSAlert message for bad file type on background import
    case fileMustBeJpgPngError = "file_must_be_jpg_png_error"
    /// NSAlert title
    case imageTooLargeTitle = "image_too_large_title"
    /// NSAlert message
    case imageTooLargeMessage = "image_too_large_message"
    /// Windows-specific file validation message
    case backgroundInvalidFormatWin = "background_invalid_format_win"
    /// Alert body, %@/{0} = theme name referencing this background, reused Mac/Windows
    case backgroundInUseFmt = "background_in_use_fmt"
    /// Editor sheet header
    case editCustomBackgroundTitle = "edit_custom_background_title"
    /// Text field label
    case backgroundNameLabel = "background_name_label"
    /// Text field placeholder
    case backgroundNamePlaceholder = "background_name_placeholder"
    /// Slider label, reused across editors
    case horizontalPositionLabel = "horizontal_position_label"
    /// Slider value display, %.0f = pixel offset, reused across editors
    case pxOffsetFmt = "px_offset_fmt"
    /// Slider label, reused across editors
    case verticalPositionLabel = "vertical_position_label"
    /// Slider label, reused across editors
    case scaleFactorLabel = "scale_factor_label"
    /// Slider value display, %.2f = scale multiplier, reused across editors
    case scaleFmt = "scale_fmt"
    /// Validation error, reused across editors
    case nameEmptyOrExistsError = "name_empty_or_exists_error"
    /// Editor sheet header when re-editing existing deck
    case editCardBackTitle = "edit_card_back_title"
    /// Editor sheet header when adding new deck
    case editCustomCardArtTitle = "edit_custom_card_art_title"
    /// Text field label
    case cardBackNameLabel = "card_back_name_label"
    /// Text field placeholder
    case cardBackNamePlaceholder = "card_back_name_placeholder"
    /// Validation error
    case addNameToSaveError = "add_name_to_save_error"
    /// Tooltip on per-deck delete button
    case deleteDeckTooltip = "delete_deck_tooltip"
    /// Alert title, reused Mac/Windows
    case deleteCardBackTitle = "delete_card_back_title"
    /// Alert body, %@ = deck name
    case deleteNamedCardBackConfirmFmt = "delete_named_card_back_confirm_fmt"
    /// Alert body, generic (non-named) variant, reused Mac/Windows
    case deleteCardBackBody = "delete_card_back_body"
    /// Bold heading above deck carousel
    case cardDeckHeading = "card_deck_heading"
    /// Suffix next to Card Deck heading
    case jpgPngGifAcceptedSuffix = "jpg_png_gif_accepted_suffix"
    /// Button that opens file picker for new deck
    case addCustomDeck = "add_custom_deck"
    /// Alert title, reused Mac/Windows
    case cardBackInUseTitle = "card_back_in_use_title"
    /// Alert body, %@/{0} = theme name referencing this card back
    case cardBackInUseFmt = "card_back_in_use_fmt"
    /// Windows variant, {0} = comma-joined theme names, {1} = 's' or '' for plural
    case cardBackInUseMultiThemeFmt = "card_back_in_use_multi_theme_fmt"
    /// Windows fallback message
    case cardBackLastRemaining = "card_back_last_remaining"
    /// Section heading
    case customCardColorHeading = "custom_card_color_heading"
    /// Windows panel section title (plural form)
    case customCardColorsPanelTitle = "custom_card_colors_panel_title"
    /// Button + confirmation dialog title, reused Mac/Windows
    case resetCardColors = "reset_card_colors"
    /// Confirmation dialog body, reused Mac/Windows
    case resetCardColorsConfirmBody = "reset_card_colors_confirm_body"
    /// Color row label
    case cardBackgroundLabel = "card_background_label"
    /// Color row label
    case cardOutlineLabel = "card_outline_label"
    /// Color row label
    case blackSuitTextLabel = "black_suit_text_label"
    /// Color row label
    case redSuitTextLabel = "red_suit_text_label"
    /// Color row label
    case hintHighlightLabel = "hint_highlight_label"
    /// Editor sheet header, %@%@ = rank label + suit symbol concatenated with no separator (e.g. 'K♠')
    case editFaceCardArtTitleFmt = "edit_face_card_art_title_fmt"
    /// Short slider label
    case scaleShortLabel = "scale_short_label"
    /// Short slider label
    case horizontalShortLabel = "horizontal_short_label"
    /// Short slider label
    case verticalShortLabel = "vertical_short_label"
    /// Tooltip on per-slot delete button
    case removeArtTooltip = "remove_art_tooltip"
    /// Alert title
    case removeArtTitle = "remove_art_title"
    /// Alert body
    case removeArtConfirmBody = "remove_art_confirm_body"
    /// NSAlert message, bad file type on card-back/face-art import — shared by CustomCardArtSectionView.swift and FaceCardArtSectionView.swift
    case fileMustBeJpgPngGifError = "file_must_be_jpg_png_gif_error"
    /// NSAlert message (shorter than Backgrounds/CardBacks variant)
    case couldNotLoadSelectedImageError = "could_not_load_selected_image_error"
    /// NSAlert message
    case couldNotReadImageDataError = "could_not_read_image_data_error"
    /// Options Picker label
    case toggleGameModeLabel = "toggle_game_mode_label"
    /// Picker option
    case option1deck = "option_1deck"
    /// Picker option
    case option2deck = "option_2deck"
    /// Stats sheet title, %@/{0} = deck mode label — reused Mac/Windows
    case freecellStatisticsFmt = "freecell_statistics_fmt"
    /// StatRowView label, Beecell/Spider (colon variant of the common 'games_played')
    case gamesPlayedColon = "games_played_colon"
    /// StatRowView label, Beecell/Spider
    case gamesWonColon = "games_won_colon"
    /// StatRowView label, Beecell/Spider
    case highScoreColon = "high_score_colon"
    /// StatRowView label, Beecell/Spider
    case winPercentageColon = "win_percentage_colon"
    /// StatRowView label, Beecell/Spider
    case currentStreakColon = "current_streak_colon"
    /// StatRowView label, Beecell/Spider
    case longestStreakColon = "longest_streak_colon"
    /// StatRowView label, Beecell/Spider
    case avgWinningTimeColon = "avg_winning_time_colon"
    /// StatRowView label, Beecell/Spider
    case fastestWinColon = "fastest_win_colon"
    /// Stats screen button, Klondike
    case resetBankrollButton = "reset_bankroll_button"
    /// Credit display label, reused Mac/iOS/Windows Blackjack/Video Poker
    case creditsLabel = "credits_label"
    /// Credit display label, Blackjack only
    case betLabel = "bet_label"
    /// Credit display label, reused Blackjack/Video Poker
    case handsLabel = "hands_label"
    /// Result banner headline
    case resultHeadlineBlackjack = "result_headline_blackjack"
    /// Result banner headline
    case resultHeadlinePush = "result_headline_push"
    /// Result banner subline
    case resultSubPush = "result_sub_push"
    /// Result banner headline
    case resultHeadlineBust = "result_headline_bust"
    /// Result subline, %d = net credits won
    case resultSubNetPositiveFmt = "result_sub_net_positive_fmt"
    /// Result subline, %d = net credits lost
    case resultSubNetNegativeFmt = "result_sub_net_negative_fmt"
    /// Result subline literal
    case resultSubEven = "result_sub_even"
    /// Result banner line, %d/{0} = dealer hand value — reused Mac/Windows
    case resultDealerValueFmt = "result_dealer_value_fmt"
    /// Result banner line, %d = player hand value
    case resultPlayerValueFmt = "result_player_value_fmt"
    /// Win-streak text, %d = streak count — reused Blackjack/Video Poker
    case streakText5plusFmt = "streak_text_5plus_fmt"
    /// Win-streak text, %d = streak count — reused Blackjack/Video Poker
    case streakText3to4Fmt = "streak_text_3to4_fmt"
    /// Win-streak text, %d = streak count — reused Blackjack/Video Poker
    case streakText2Fmt = "streak_text_2_fmt"
    /// Betting action button, Mac wording
    case btnClearBet = "btn_clear_bet"
    /// Betting action button, Windows wording (Title Case vs Mac's uppercase)
    case btnClearBetWin = "btn_clear_bet_win"
    /// Action button, Mac wording — reused Blackjack/Video Poker
    case btnDealSpace = "btn_deal_space"
    /// Action button, Windows wording
    case btnDealSpaceWin = "btn_deal_space_win"
    /// Action button, Mac uppercase wording — reused Blackjack/Video Poker
    case btnRebuyMac = "btn_rebuy_mac"
    /// Playing-phase action button, Mac wording
    case btnHit = "btn_hit"
    /// Playing-phase action button, Windows wording
    case btnHitWin = "btn_hit_win"
    /// Playing-phase action button, Mac wording
    case btnStand = "btn_stand"
    /// Playing-phase action button, Windows wording
    case btnStandWin = "btn_stand_win"
    /// Playing-phase action button, Mac wording
    case btnDouble = "btn_double"
    /// Playing-phase action button, Windows wording
    case btnDoubleWin = "btn_double_win"
    /// Playing-phase action button, Mac wording
    case btnSplit = "btn_split"
    /// Playing-phase action button, Windows wording
    case btnSplitWin = "btn_split_win"
    /// Windows key-hint label (Mac's equivalent is hotkey_legend_blackjack)
    case keyHintRowWin = "key_hint_row_win"
    /// Chip add button, %d = amount
    case chipAmountFmt = "chip_amount_fmt"
    /// Chip value button (Windows)
    case chip1 = "chip_1"
    /// Chip value button (Windows)
    case chip5 = "chip_5"
    /// Chip value button (Windows)
    case chip10 = "chip_10"
    /// Chip value button (Windows)
    case chip25 = "chip_25"
    /// Double-bet chip button (Windows)
    case chip2x = "chip_2x"
    /// Stats sheet title, reused Mac/Windows
    case blackjackStatistics = "blackjack_statistics"
    /// StatRowView label, Blackjack only
    case statHandsLost = "stat_hands_lost"
    /// StatRowView label, Blackjack only
    case statPushes = "stat_pushes"
    /// StatRowView label, Blackjack only
    case statBlackjacks = "stat_blackjacks"
    /// StatRowView label, Mac abbreviated wording
    case statCurStreakShort = "stat_cur_streak_short"
    /// StatRowView label, reused Blackjack/Video Poker
    case statBestStreak = "stat_best_streak"
    /// Alert message, Blackjack-specific wording
    case msgResetStatsBlackjack = "msg_reset_stats_blackjack"
    /// Warning headline, reused Mac/Windows
    case emptyColumnWarningTitle = "empty_column_warning_title"
    /// Warning body, reused Mac/Windows
    case emptyColumnWarningBody = "empty_column_warning_body"
    /// Options Picker label
    case pickerSuitsLabel = "picker_suits_label"
    /// Picker option
    case optionSuits1 = "option_suits_1"
    /// Picker option
    case optionSuits2 = "option_suits_2"
    /// Picker option
    case optionSuits4 = "option_suits_4"
    /// Stats sheet title, %d %@/{0} = suit count + noun — reused Mac/Windows
    case spiderStatisticsFmt = "spider_statistics_fmt"
    /// Interpolated suit-count noun
    case labelSuitSingular = "label_suit_singular"
    /// Interpolated suit-count noun
    case labelSuitPlural = "label_suit_plural"
    /// Stat row label, Spider
    case statAverageWinTime = "stat_average_win_time"
    /// Time formatter fallback for 0 seconds
    case noTimePlaceholder = "no_time_placeholder"
    /// Credit label, Triple Play mode
    case betHandLabel = "bet_hand_label"
    /// Credit display label, Triple Play
    case totalBetLabel = "total_bet_label"
    /// Pay-table max-coin column header
    case payTableMaxCol = "pay_table_max_col"
    /// Win result headline, %@/{0} = hand name (e.g. 'Flush')
    case resultHandNameFmt = "result_hand_name_fmt"
    /// Win result subline, %d = payout amount
    case resultCreditsWonFmt = "result_credits_won_fmt"
    /// Loss result subline, %d = bet amount
    case resultCreditsLostFmt = "result_credits_lost_fmt"
    /// Loss row suffix text (Windows)
    case minusCreditsSuffix = "minus_credits_suffix"
    /// Bet stepper button
    case btnBetMinus = "btn_bet_minus"
    /// Action button, Mac wording
    case btnBetMaxMac = "btn_bet_max_mac"
    /// Bet stepper button
    case btnBetPlus = "btn_bet_plus"
    /// Holding-phase action button, Mac wording
    case btnHoldAllMac = "btn_hold_all_mac"
    /// Holding-phase action button, Windows wording
    case btnHoldAllWin = "btn_hold_all_win"
    /// Holding-phase action button, Mac wording
    case btnClearHoldsMac = "btn_clear_holds_mac"
    /// Holding-phase action button, Windows wording (uses Q shortcut)
    case btnClearHoldsWin = "btn_clear_holds_win"
    /// Deal button when holding
    case btnDraw = "btn_draw"
    /// Windows decrease-bet button
    case btnDrawWinMinus = "btn_draw_win_minus"
    /// Windows increase-bet button
    case btnDrawWinPlus = "btn_draw_win_plus"
    /// Result banner text during holding phase, iOS
    case tapHoldDrawHint = "tap_hold_draw_hint"
    /// 'HELD' chip over held cards, iOS
    case heldLabel = "held_label"
    /// Result banner text with payout, iOS, %@ = hand name, %d = payout
    case payoutResultFmt = "payout_result_fmt"
    /// Options Picker label
    case pickerVariantLabel = "picker_variant_label"
    /// Options Picker label
    case pickerPlaymodeLabel = "picker_playmode_label"
    /// Options Picker label
    case pickerDefaultBetLabel = "picker_default_bet_label"
    /// Picker option, %d = coin count, %@ pluralizes 'coin'/'coins'
    case optionCoinCountFmt = "option_coin_count_fmt"
    /// ComboBox item, Windows
    case variantJacksOrBetter = "variant_jacks_or_better"
    /// ComboBox item, Windows
    case variantDeucesWild = "variant_deuces_wild"
    /// ComboBox item, Windows
    case variantBonusPoker = "variant_bonus_poker"
    /// Stats sheet title, reused Mac/Windows
    case videoPokerStatistics = "video_poker_statistics"
    /// Toolbar button, reused Mac/Windows
    case toolbarStartMatch = "toolbar_start_match"
    /// Toolbar button, reused Mac/Windows
    case toolbarQuitMatch = "toolbar_quit_match"
    /// Toolbar button (Mac short form; Windows also has full 'Honeycomb Rules' title — separate row)
    case toolbarRules = "toolbar_rules"
    /// Overlay title, Windows
    case honeycombRulesTitle = "honeycomb_rules_title"
    /// StatusItemView label, reused Mac/Windows
    case statusYouLabel = "status_you_label"
    /// Rules banner heading
    case rulesBannerTitle = "rules_banner_title"
    /// Active-rules banner line when no rules active, reused Mac/iOS
    case ruleLineNormal = "rule_line_normal"
    /// Pre-game rules banner line, reused Mac/iOS
    case ruleLineRoulette = "rule_line_roulette"
    /// Rules banner line for Ascension/Descension, %@/{0} = rule name, %@/{1} = comma-joined suit names — reused Mac/iOS
    case ruleLineSuitFmt = "rule_line_suit_fmt"
    /// Hand label above player hand, iOS touch view
    case handLabelYou = "hand_label_you"
    /// Top bar button mid-match, iOS
    case quitButton = "quit_button"
    /// Top bar button pre-match, iOS
    case startButton = "start_button"
    /// Flash banner text, iOS (distinct wording from the common 'no_hints_available')
    case noHintsBanner = "no_hints_banner"
    /// Post-game action button, iOS
    case takeACardButton = "take_a_card_button"
    /// Accessibility label on overlay dismiss button, iOS
    case dismissA11y = "dismiss_a11y"
    /// Settings section header (uppercase), reused across iOS games
    case settingsHeader = "settings_header"
    /// Picker label, reused Mac/iOS
    case opponentPickerLabel = "opponent_picker_label"
    /// Settings toggle, iOS
    case forceNormalRulesToggle = "force_normal_rules_toggle"
    /// Force-normal-mode toggle, Mac (fuller wording than iOS)
    case toggleNormalModeMac = "toggle_normal_mode_mac"
    /// DisclosureGroup title, reused Mac/iOS
    case matchRulesDisclosure = "match_rules_disclosure"
    /// Rules sheet column heading, Mac
    case rulesColumnTitle = "rules_column_title"
    /// Helper text, reused Mac/iOS
    case matchRulesHint = "match_rules_hint"
    /// DisclosureGroup title, reused Mac/iOS
    case banListDisclosure = "ban_list_disclosure"
    /// Helper text, Mac
    case banListHintMac = "ban_list_hint_mac"
    /// Ban-list item label, reused Mac/iOS
    case normalModeBanItem = "normal_mode_ban_item"
    /// Disabled-settings hint, iOS
    case settingsUnlockNote = "settings_unlock_note"
    /// Navigation/sheet title, reused Mac/iOS
    case statsSheetTitle = "stats_sheet_title"
    /// Stats sheet title, Mac full wording (distinct from iOS's shorter 'Honeycomb Stats')
    case honeycombStatistics = "honeycomb_statistics"
    /// Stat row label, iOS
    case statMatchesPlayed = "stat_matches_played"
    /// Stat row label, reused Mac/iOS
    case statMatchesWon = "stat_matches_won"
    /// Stat row label, reused Mac/iOS
    case statMatchesLost = "stat_matches_lost"
    /// Stat row label, reused Mac/iOS
    case statMatchesDrawn = "stat_matches_drawn"
    /// Stat row label, iOS
    case statCardsCaptured = "stat_cards_captured"
    /// Stat row label, reused Mac/iOS
    case statCardsStolen = "stat_cards_stolen"
    /// Stat row label, reused Mac/iOS
    case statCurrentWinStreak = "stat_current_win_streak"
    /// Stat row label, reused Mac/iOS
    case statLongestWinStreak = "stat_longest_win_streak"
    /// Stat row label, iOS (shorter than Mac's fuller wording)
    case statFlawlessVictoriesIos = "stat_flawless_victories_ios"
    /// Stat row label, Mac full wording
    case statFlawlessVictoriesMac = "stat_flawless_victories_mac"
    /// Stat row label, iOS
    case statSamePlusTriggers = "stat_same_plus_triggers"
    /// Section header, iOS
    case statWinsByDifficultySection = "stat_wins_by_difficulty_section"
    /// Stat row label, iOS (Mac has 'Baby Bee Wins' — separate key)
    case statBabyBee = "stat_baby_bee"
    /// Stat row label, iOS
    case statHoneyBee = "stat_honey_bee"
    /// Stat row label, iOS
    case statQueenBee = "stat_queen_bee"
    /// Stat row label, iOS
    case statKillerBee = "stat_killer_bee"
    /// Stat row label, Mac full wording
    case statBabyBeeWins = "stat_baby_bee_wins"
    /// Stat row label, Mac full wording
    case statHoneyBeeWins = "stat_honey_bee_wins"
    /// Stat row label, Mac full wording
    case statQueenBeeWins = "stat_queen_bee_wins"
    /// Stat row label, Mac full wording
    case statKillerBeeWins = "stat_killer_bee_wins"
    /// Stat row label, Mac
    case statSwarmsToDeath = "stat_swarms_to_death"
    /// Stat row label, Mac
    case statTotalCardsFlipped = "stat_total_cards_flipped"
    /// Stat row label, Mac
    case statQueensFalls = "stat_queens_falls"
    /// Stat row label, Mac
    case statHiveMindsTriggered = "stat_hive_minds_triggered"
    /// Stat row label, Mac
    case statTimesStartedOver = "stat_times_started_over"
    /// Stat row label, Mac
    case statCardsUnlockedLabel = "stat_cards_unlocked_label"
    /// Stat row value, %d/%d (%@) — unlocked, total, percent string
    case statCardsUnlockedValueFmt = "stat_cards_unlocked_value_fmt"
    /// Per-suit progress row, %@/{0} = suit name
    case statSuitUnlockedFmt = "stat_suit_unlocked_fmt"
    /// Per-star progress row, %d/{0} = star rating
    case statStarUnlockedFmt = "stat_star_unlocked_fmt"
    /// Overlay title on a tie, Windows
    case tieResult = "tie_result"
    /// Overlay subtitle, {0}/{1} = player/opponent score
    case finalScoreFmt = "final_score_fmt"
    /// Sheet title, Mac full wording
    case sheetTitleMac = "sheet_title_mac"
    /// Segmented tab, iOS
    case tabSavedDecks = "tab_saved_decks"
    /// Segmented tab, iOS
    case tabCardBank = "tab_card_bank"
    /// Freeform search helper text, Mac
    case statSearchHint = "stat_search_hint"
    /// Section header, Mac (uppercase)
    case savedDecksHeader = "saved_decks_header"
    /// TextField placeholder, Mac wording
    case deckNamePlaceholder = "deck_name_placeholder"
    /// TextField placeholder, iOS wording (lowercase 'max')
    case deckNamePlaceholderIos = "deck_name_placeholder_ios"
    /// Validation helper text, iOS
    case enterDeckNameHint = "enter_deck_name_hint"
    /// Right-click menu item, Mac
    case contextRemoveFromDeck = "context_remove_from_deck"
    /// Button, Mac
    case btnSaveDeck = "btn_save_deck"
    /// Default deck name, %d = slot number, iOS
    case deckSlotDefaultNameFmt = "deck_slot_default_name_fmt"
    /// Stats sheet title, Klondike
    case klondikeStatisticsTitle = "klondike_statistics_title"
    /// Text label, Klondike stats (Vegas mode)
    case vegasBankrollLabel = "vegas_bankroll_label"
    /// Pay table row / result banner, VideoPokerViewModel.swift handName (display-only, stored value stays English)
    case handHighCard = "hand_high_card"
    /// Pay table row / result banner
    case handOnePair = "hand_one_pair"
    /// Pay table row / result banner
    case handTwoPair = "hand_two_pair"
    /// Pay table row / result banner
    case handThreeOfAKind = "hand_three_of_a_kind"
    /// Pay table row / result banner
    case handStraightFlush = "hand_straight_flush"
    /// Pay table row / result banner
    case handFlush = "hand_flush"
    /// Pay table row / result banner
    case handStraight = "hand_straight"
    /// Pay table row / result banner
    case handFourOfAKind = "hand_four_of_a_kind"
    /// Pay table row / result banner
    case handFullHouse = "hand_full_house"
    /// Pay table row / result banner (Deuces Wild)
    case handFiveOfAKind = "hand_five_of_a_kind"
    /// Pay table row (Bonus Poker)
    case handFourAces = "hand_four_aces"
    /// Pay table row (Bonus Poker)
    case handFour2s4s = "hand_four_2s_4s"
    /// Pay table row (Deuces Wild)
    case handFourDeuces = "hand_four_deuces"
    /// Pay table row (Deuces Wild)
    case handNaturalRoyalFlush = "hand_natural_royal_flush"
    /// Pay table row (Deuces Wild)
    case handWildRoyalFlush = "hand_wild_royal_flush"
    /// Result banner when hand doesn't qualify, VideoPokerViewModel.swift evaluateHand()/lastHandName (display-only)
    case handNoWin = "hand_no_win"
    /// HoneycombDifficulty.rawValue (persisted identifier) — NOT currently rendered anywhere as raw text (only .displayName "Killer Bee" is shown); kept for reference/future use, no wiring needed today
    case difficultyUltraHardRawvalue = "difficulty_ultra_hard_rawvalue"
    /// HoneycombRule.bombShelter.rawValue — display-only translation, rawValue itself stays English
    case ruleNameCappedBrood = "rule_name_capped_brood"
    /// HoneycombRule.swap.rawValue — display-only translation, rawValue itself stays English
    case ruleNameNectarExchange = "rule_name_nectar_exchange"
    /// HoneycombRule.threeOpen.rawValue — display-only translation, rawValue itself stays English
    case ruleNameScoutingParty = "rule_name_scouting_party"
    /// HoneycombRule.suddenDeath.rawValue — display-only translation, rawValue itself stays English
    case ruleNameSwarmToTheDeath = "rule_name_swarm_to_the_death"
    /// HoneycombRule.chaos.explanation(), HoneycombBoard.swift — display-only translation, explanation() source stays English
    case ruleExplanationChaos = "rule_explanation_chaos"
    /// HoneycombRule.reverse.explanation(), HoneycombBoard.swift — display-only translation, explanation() source stays English
    case ruleExplanationReverse = "rule_explanation_reverse"
    /// Ban-list Normal Mode row tooltip fallback, HoneycombView.swift:1416
    case normalModeBanListTooltip = "normal_mode_ban_list_tooltip"
    /// GameMode.klondike.displayName — rawValue "Klondike Solitaire" stays untouched (persisted)
    case gamemodeKlondikeDisplay = "gamemode_klondike_display"
    /// GameMode.spider.displayName — rawValue "Spider Solitaire" stays untouched (persisted)
    case gamemodeSpiderDisplay = "gamemode_spider_display"
    /// VideoPokerPlayMode.single.rawValue (Options picker) — display-only translation
    case playmodeSingle = "playmode_single"
    /// VideoPokerPlayMode.triple.rawValue (Options picker, currently hidden/tripleEnabled=false) — display-only translation
    case playmodeTriple = "playmode_triple"
    /// Section label, GameUIStyles.swift:263
    case gameSelectionLabel = "game_selection_label"
    /// Hint-move description, GameViewModel.swift:1057
    case hintRecycleWasteToStock = "hint_recycle_waste_to_stock"
    /// TextField placeholder, ThemesSectionView.swift (new + rename)
    case themeNameFieldPlaceholder = "theme_name_field_placeholder"
    /// Validation error, ThemesSectionView.swift
    case themeNameEmptyError = "theme_name_empty_error"
    /// Validation error, ThemesSectionView.swift, %@ = theme name
    case themeNameExistsErrorFmt = "theme_name_exists_error_fmt"
    /// Alert title, ThemesSectionView.swift
    case renameThemeTitle = "rename_theme_title"
    /// Button, ThemesSectionView.swift
    case saveAsNewTheme = "save_as_new_theme"
    /// Empty-state text, ThemesSectionView.swift
    case noSavedThemesYet = "no_saved_themes_yet"
    /// Alert title, ThemesSectionView.swift
    case deleteThemeTitle = "delete_theme_title"
    /// Button, ThemesSectionView.swift
    case applyThemeButton = "apply_theme_button"
    /// Alert body, ThemesSectionView.swift, %@ = theme name
    case deleteThemeConfirmFmt = "delete_theme_confirm_fmt"
    /// HoneycombHelpView subtitle, HelpGuideView.swift
    case helpHoneycombSubtitle = "help_honeycomb_subtitle"
    /// RuleSection title, Honeycomb only
    case helpCoreGameplayMechanicsTitle = "help_core_gameplay_mechanics_title"
    /// RuleSection title, Video Poker only
    case helpHowToPlayVariantsTitle = "help_how_to_play_variants_title"
    /// RuleSection title, shared across Klondike/Beecell/Spider/VideoPoker/Blackjack
    case helpStrategyProTipsTitle = "help_strategy_pro_tips_title"
    /// RuleSection title, shared across all 7 Help views
    case helpOverviewObjectiveTitle = "help_overview_objective_title"
    /// Section header, shared across all 7 Help views
    case helpControlsShortcutsTitle = "help_controls_shortcuts_title"
    /// ShortcutRow action, Honeycomb only
    case helpShortcutClickDragTap = "help_shortcut_click_drag_tap"
    /// ShortcutRow action, Beecell only
    case helpShortcutNavigateSelect = "help_shortcut_navigate_select"
    /// ShortcutRow action, shared Klondike + Honeycomb
    case helpShortcutSelectPlaceCard = "help_shortcut_select_place_card"
    /// ShortcutRow action, Spider only
    case helpShortcutSelectPlaceSequence = "help_shortcut_select_place_sequence"
    /// ShortcutRow action, Honeycomb only
    case helpShortcutShowBestAiMove = "help_shortcut_show_best_ai_move"
    /// ShortcutRow action, Blackjack only
    case helpShortcutSplitPairs = "help_shortcut_split_pairs"
    /// ShortcutRow shortcut value, Klondike only (standalone; Beecell/Spider use a compound form not covered by this pass)
    case helpShortcutArrowKeys = "help_shortcut_arrow_keys"
    /// ShortcutRow shortcut value, Video Poker only
    case helpShortcutCQ = "help_shortcut_c_q"
    /// ShortcutRow shortcut value, reused Klondike/Spider/VideoPoker
    case helpShortcutSpaceEnter = "help_shortcut_space_enter"
    /// ShortcutRow shortcut value, reused Klondike/Beecell
    case helpShortcutCmdNR = "help_shortcut_cmd_n_r"
    /// ShortcutRow shortcut value, reused Klondike/Beecell/Spider
    case helpShortcutCmdZ = "help_shortcut_cmd_z"
    /// HelpShell title for BeecellHelpView — proper noun, kept as-is
    case helpBeecellTitle = "help_beecell_title"
    /// Overview RuleSection body
    case helpKlondikeObjective = "help_klondike_objective"
    /// Setup & Layout RuleSection body
    case helpKlondikeLayout = "help_klondike_layout"
    /// Rules & How to Play RuleSection body
    case helpKlondikeRules = "help_klondike_rules"
    /// Strategy & Pro Tips RuleSection body
    case helpKlondikeStrategy = "help_klondike_strategy"
    /// No Stress Mode RuleSection body (identical text also used by Beecell/Spider — separate row per file grouping, exact duplicate)
    case helpKlondikeNoStress = "help_klondike_no_stress"
    /// Overview RuleSection body
    case helpBeecellObjective = "help_beecell_objective"
    /// Setup & Layout RuleSection body
    case helpBeecellLayout = "help_beecell_layout"
    /// Rules & How to Play RuleSection body
    case helpBeecellRules = "help_beecell_rules"
    /// Strategy & Pro Tips RuleSection body
    case helpBeecellStrategy = "help_beecell_strategy"
    /// Overview RuleSection body
    case helpSpiderObjective = "help_spider_objective"
    /// Setup & Layout RuleSection body
    case helpSpiderLayout = "help_spider_layout"
    /// Rules & How to Play RuleSection body
    case helpSpiderRules = "help_spider_rules"
    /// Strategy & Pro Tips RuleSection body
    case helpSpiderStrategy = "help_spider_strategy"
    /// Overview RuleSection body
    case helpVideopokerObjective = "help_videopoker_objective"
    /// How to Play & Variants RuleSection body
    case helpVideopokerHowToPlay = "help_videopoker_how_to_play"
    /// Strategy & Pro Tips RuleSection body
    case helpVideopokerStrategy = "help_videopoker_strategy"
    /// No Stress Mode RuleSection body
    case helpVideopokerNoStress = "help_videopoker_no_stress"
    /// Overview RuleSection body
    case helpBlackjackObjective = "help_blackjack_objective"
    /// Rules & Options RuleSection body
    case helpBlackjackRules = "help_blackjack_rules"
    /// Strategy & Pro Tips RuleSection body
    case helpBlackjackStrategy = "help_blackjack_strategy"
    /// No Stress Mode RuleSection body
    case helpBlackjackNoStress = "help_blackjack_no_stress"
    /// Overview RuleSection body
    case helpHoneycombObjective = "help_honeycomb_objective"
    /// Core Gameplay & Mechanics RuleSection body
    case helpHoneycombMechanics = "help_honeycomb_mechanics"
    /// Card Bank & Stealing RuleSection body
    case helpHoneycombCardBank = "help_honeycomb_card_bank"
    /// No Stress Mode RuleSection body
    case helpHoneycombNoStress = "help_honeycomb_no_stress"
    /// Themes & Customization RuleSection body, ThemesHelpView
    case helpCustomizationThemes = "help_customization_themes"
    /// Options RuleSection body, ThemesHelpView
    case helpCustomizationOptions = "help_customization_options"
    /// HelpShell title, KlondikeHelpView
    case helpKlondikeTitle = "help_klondike_title"
    /// HelpShell subtitle, KlondikeHelpView
    case helpKlondikeSubtitle = "help_klondike_subtitle"
    /// HelpShell subtitle, BeecellHelpView
    case helpBeecellSubtitle = "help_beecell_subtitle"
    /// HelpShell title, SpiderHelpView
    case helpSpiderTitle = "help_spider_title"
    /// HelpShell subtitle, SpiderHelpView
    case helpSpiderSubtitle = "help_spider_subtitle"
    /// HelpShell title, VideoPokerHelpView (identical text to gamemode_videopoker_display — kept as separate key since one is Help chrome, one is a game-mode label)
    case helpVideopokerTitle = "help_videopoker_title"
    /// HelpShell subtitle, VideoPokerHelpView
    case helpVideopokerSubtitle = "help_videopoker_subtitle"
    /// HelpShell title, BlackjackHelpView
    case helpBlackjackTitle = "help_blackjack_title"
    /// HelpShell subtitle, BlackjackHelpView
    case helpBlackjackSubtitle = "help_blackjack_subtitle"
    /// HelpShell title, ThemesHelpView
    case helpThemesTitle = "help_themes_title"
    /// HelpShell subtitle, ThemesHelpView
    case helpThemesSubtitle = "help_themes_subtitle"
    /// RuleSection title, shared Klondike/Beecell/Spider
    case helpSetupLayoutTitle = "help_setup_layout_title"
    /// RuleSection title, shared Klondike/Beecell/Spider
    case helpRulesHowToPlayTitle = "help_rules_how_to_play_title"
    /// RuleSection title, Blackjack
    case helpRulesOptionsTitle = "help_rules_options_title"
    /// RuleSection title, Honeycomb
    case helpMatchModifiersTitle = "help_match_modifiers_title"
    /// RuleSection title, Honeycomb
    case helpCardBankStealingTitle = "help_card_bank_stealing_title"
    /// RuleSection title, ThemesHelpView
    case helpThemesCustomizationTitle = "help_themes_customization_title"
    /// RuleSection title, ThemesHelpView
    case helpOptionsTitle = "help_options_title"
    /// ShortcutRow action, Klondike
    case helpShortcutNavigateBoardCursor = "help_shortcut_navigate_board_cursor"
    /// ShortcutRow action, Klondike
    case helpShortcutClearSelection = "help_shortcut_clear_selection"
    /// ShortcutRow action, Klondike
    case helpShortcutDrawCards = "help_shortcut_draw_cards"
    /// ShortcutRow action, shared Klondike/Beecell
    case helpShortcutAutoMoveFoundation = "help_shortcut_auto_move_foundation"
    /// ShortcutRow action, shared Klondike/Beecell
    case helpShortcutNewGameRestartDeal = "help_shortcut_new_game_restart_deal"
    /// ShortcutRow action, shared Klondike/Beecell/Spider
    case helpShortcutUndoMove = "help_shortcut_undo_move"
    /// ShortcutRow shortcut label — actually this row's English is the ACTION text, not the ⌥⌘ shortcut value; Klondike only
    case helpShortcutToggleDraw = "help_shortcut_toggle_draw"
    /// ShortcutRow action, Klondike
    case helpShortcutCycleHints = "help_shortcut_cycle_hints"
    /// ShortcutRow shortcut value, shared Klondike/Beecell/Honeycomb
    case helpShortcutHintButton = "help_shortcut_hint_button"
    /// ShortcutRow action, Beecell
    case helpShortcutAutoParkFreeCell = "help_shortcut_auto_park_free_cell"
    /// ShortcutRow shortcut value, Beecell (compound form)
    case helpShortcutArrowSpaceEnter = "help_shortcut_arrow_space_enter"
    /// ShortcutRow action, Spider
    case helpShortcutDeal10Cards = "help_shortcut_deal_10_cards"
    /// ShortcutRow action, Spider
    case helpShortcut1suit2suitMode = "help_shortcut_1suit_2suit_mode"
    /// ShortcutRow action, shared Spider/(short form)
    case helpShortcutAutocomplete = "help_shortcut_autocomplete"
    /// ShortcutRow action, Video Poker
    case helpShortcutDealDraw = "help_shortcut_deal_draw"
    /// ShortcutRow action, Video Poker
    case helpShortcutHoldCard12345 = "help_shortcut_hold_card_12345"
    /// ShortcutRow shortcut value, Video Poker
    case helpShortcut12345 = "help_shortcut_12345"
    /// ShortcutRow action, Video Poker
    case helpShortcutHoldAllCards = "help_shortcut_hold_all_cards"
    /// ShortcutRow action, shared VideoPoker/Blackjack
    case helpShortcutBetMaxDeal = "help_shortcut_bet_max_deal"
    /// ShortcutRow action, Blackjack
    case helpShortcutDealBuyIn = "help_shortcut_deal_buy_in"
    /// ShortcutRow action, Blackjack
    case helpShortcutHit = "help_shortcut_hit"
    /// ShortcutRow action, Blackjack
    case helpShortcutStand = "help_shortcut_stand"
    /// ShortcutRow action, Blackjack
    case helpShortcutDoubleDown = "help_shortcut_double_down"
    /// HoneycombRule.ascension.rawValue — display-only translation, rawValue itself stays English
    case ruleNamePollination = "rule_name_pollination"
    /// HoneycombRule.descension.rawValue — display-only translation, rawValue itself stays English
    case ruleNameSmokedOut = "rule_name_smoked_out"
    /// HoneycombRule.same.rawValue — display-only translation, rawValue itself stays English
    case ruleNameSymmetry = "rule_name_symmetry"
    /// HoneycombRule.plus.rawValue — display-only translation, rawValue itself stays English
    case ruleNameMathBee = "rule_name_math_bee"
    /// HoneycombRule.fallenAce.rawValue — display-only translation, rawValue itself stays English
    case ruleNameQueensFall = "rule_name_queens_fall"
    /// HoneycombRule.reverse.rawValue — display-only translation, rawValue itself stays English
    case ruleNameInversion = "rule_name_inversion"
    /// HoneycombRule.allOpen.rawValue — display-only translation, rawValue itself stays English
    case ruleNameClearSkies = "rule_name_clear_skies"
    /// HoneycombRule.order.rawValue — display-only translation, rawValue itself stays English
    case ruleNameHierarchy = "rule_name_hierarchy"
    /// HoneycombRule.chaos.rawValue — display-only translation, rawValue itself stays English
    case ruleNameFrenzy = "rule_name_frenzy"
    /// HoneycombRule.same.explanation() — display-only translation, explanation() source stays English
    case ruleExplanationSame = "rule_explanation_same"
    /// HoneycombRule.plus.explanation() — display-only translation, explanation() source stays English
    case ruleExplanationPlus = "rule_explanation_plus"
    /// HoneycombRule.fallenAce.explanation() — display-only translation, explanation() source stays English
    case ruleExplanationFallenAce = "rule_explanation_fallen_ace"
    /// HoneycombRule.ascension.explanation() generic (no suits yet selected) variant — display-only translation, explanation() source stays English
    case ruleExplanationAscensionGeneric = "rule_explanation_ascension_generic"
    /// HoneycombRule.descension.explanation() generic (no suits yet selected) variant — display-only translation, explanation() source stays English
    case ruleExplanationDescensionGeneric = "rule_explanation_descension_generic"
    /// HoneycombRule.order.explanation() — display-only translation, explanation() source stays English
    case ruleExplanationOrder = "rule_explanation_order"
    /// HoneycombRule.allOpen.explanation() — display-only translation, explanation() source stays English
    case ruleExplanationAllOpen = "rule_explanation_all_open"
    /// HoneycombRule.threeOpen.explanation() — display-only translation, explanation() source stays English
    case ruleExplanationThreeOpen = "rule_explanation_three_open"
    /// HoneycombRule.bombShelter.explanation() — display-only translation, explanation() source stays English
    case ruleExplanationBombShelter = "rule_explanation_bomb_shelter"
    /// HoneycombRule.suddenDeath.explanation() — display-only translation, explanation() source stays English
    case ruleExplanationSuddenDeath = "rule_explanation_sudden_death"
    /// HoneycombRule.swap.explanation() — display-only translation, explanation() source stays English
    case ruleExplanationSwap = "rule_explanation_swap"
    /// HoneycombDifficulty.easy.rawValue (persisted identifier) — NOT currently rendered anywhere as raw text (only .displayName "Baby Bee" is shown); kept for reference/future use, no wiring needed today
    case difficultyEasyRawvalue = "difficulty_easy_rawvalue"
    /// HoneycombDifficulty.medium.rawValue (persisted identifier) — NOT currently rendered anywhere as raw text (only .displayName "Honey Bee" is shown); kept for reference/future use, no wiring needed today
    case difficultyMediumRawvalue = "difficulty_medium_rawvalue"
    /// HoneycombDifficulty.hard.rawValue (persisted identifier) — NOT currently rendered anywhere as raw text (only .displayName "Queen Bee" is shown); kept for reference/future use, no wiring needed today
    case difficultyHardRawvalue = "difficulty_hard_rawvalue"
    /// GameMode.beecell.displayName — rawValue "Freecell" stays untouched (persisted); translator kept proper noun as-is
    case gamemodeBeecellDisplay = "gamemode_beecell_display"
    /// RuleExplanationPopover.swift label prefix, %@ = Roulette translation not needed, plain concat
    case rouletteColonPrefix = "roulette_colon_prefix"
    /// RuleExplanationPopover.swift roulette body text
    case rulesRandomizedAtStart = "rules_randomized_at_start"
    /// RuleExplanationPopover.swift rule-name label, %@ = translated rule name
    case ruleNameColonFmt = "rule_name_colon_fmt"
    /// Column header, HoneycombRulesView.axaml (Windows)
    case banColumnHeader = "ban_column_header"
    /// Column header, HoneycombRulesView.axaml (Windows)
    case playColumnHeader = "play_column_header"
    /// Helper text, HoneycombRulesView.axaml (Windows) — near-identical to matchRulesHint, kept separate since wording differs (match's vs match)
    case matchRulesHintWin = "match_rules_hint_win"
    /// Helper text, HoneycombRulesView.axaml (Windows)
    case banRemovesRuleHint = "ban_removes_rule_hint"
    /// Label, HoneycombRulesView.axaml (Windows) — colon variant of opponentPickerLabel
    case opponentLabelColon = "opponent_label_colon"
    /// Button, PreferencesView.axaml (Windows) — different wording from Mac's "Save as New Theme"
    case saveNewThemeEllipsisWin = "save_new_theme_ellipsis_win"
    /// Match-intro banner first line, HoneycombViewModel.swift/.cs
    case firstMovePlayer = "first_move_player"
    /// Match-intro banner first line, %@/{0} = opponent difficulty display name
    case firstMoveOpponentFmt = "first_move_opponent_fmt"
    /// RuleSection title, shared across all 7 Help views
    case helpNoStressModeTitle = "help_no_stress_mode_title"
    /// Index header, HelpWindow.axaml (Windows)
    case helpGuideContentsHeader = "help_guide_contents_header"
    /// Title bar text, HelpWindow.axaml (Windows) — distinct from per-game Help titles
    case helpGuideWindowTitle = "help_guide_window_title"
    /// Index button label, HelpWindow.axaml (Windows) — shorter than helpThemesTitle
    case helpThemesSettingsIndexLabel = "help_themes_settings_index_label"
    /// ShortcutRow action, Video Poker (Windows uses this phrasing; Mac shortens to Clear/C-Q)
    case helpShortcutClearAllHolds = "help_shortcut_clear_all_holds"
    /// Settings section header (uppercase), VideoPokerTouchView.swift
    case settingsHeaderVideopoker = "settings_header_videopoker"
    /// Pay table row / result banner, standard (non-Deuces-Wild) tables — VideoPokerViewModel.swift/.cs handName (display-only, stored value stays English)
    case handRoyalFlush = "hand_royal_flush"
    /// Pay table row / result banner, standard (non-Deuces-Wild, non-Bonus) tables base qualifying win — VideoPokerViewModel.swift/.cs handName
    case handJacksOrBetter = "hand_jacks_or_better"
    /// Random banner phrase when the player triggers a Hive Swarm reveal
    case swarmRevealPlayerHiveSwarm = "swarm_reveal_player_hive_swarm"
    /// Random banner phrase when the player triggers a Hive Swarm reveal
    case swarmRevealPlayerUnleashed = "swarm_reveal_player_unleashed"
    /// Random banner phrase when the player triggers a Hive Swarm reveal
    case swarmRevealPlayerAwakens = "swarm_reveal_player_awakens"
    /// Random banner phrase when the player triggers a Hive Swarm reveal
    case swarmRevealPlayerBuzzing = "swarm_reveal_player_buzzing"
    /// Random banner phrase when the opponent triggers a Hive Swarm reveal; %@ is the opponent/difficulty name
    case swarmRevealOpponentHiveSwarmFmt = "swarm_reveal_opponent_hive_swarm_fmt"
    /// Random banner phrase when the opponent triggers a Hive Swarm reveal; %@ is the opponent/difficulty name
    case swarmRevealOpponentUnleashedFmt = "swarm_reveal_opponent_unleashed_fmt"
    /// Random banner phrase when the opponent triggers a Hive Swarm reveal; %@ is the opponent/difficulty name
    case swarmRevealOpponentAwakensFmt = "swarm_reveal_opponent_awakens_fmt"
    /// Random banner phrase when the opponent triggers a Hive Swarm reveal; %@ is the opponent/difficulty name
    case swarmRevealOpponentBuzzingFmt = "swarm_reveal_opponent_buzzing_fmt"
    /// Chain-reaction capture combo banner; %d is the flip count (2+)
    case bannerHiveMindFmt = "banner_hive_mind_fmt"
    /// Windows Options page: Game Mode section header above the draw-mode/suit-count/deck-count picker
    case gameModeSectionHeader = "game_mode_section_header"
    /// Windows Options page: Themes sub-panel sidebar header
    case savedThemesHeader = "saved_themes_header"
    /// Windows Options page: hero preview tooltip (combined card+background, unlike Mac which has separate tooltips)
    case doubleClickCardOrBackgroundTooltip = "double_click_card_or_background_tooltip"
    /// Windows Options page: Delete Background confirmation dialog body
    case deleteBackgroundConfirmBody = "delete_background_confirm_body"
    /// Windows Options page: Save New Theme dialog title (distinct from the button which has an ellipsis)
    case saveNewThemeTitle = "save_new_theme_title"
    /// Windows Options page: Save New Theme dialog prompt text
    case enterThemeNamePrompt = "enter_theme_name_prompt"
    /// Windows Options page: Face Cards sub-panel instructional hint
    case tapTileUploadArtHint = "tap_tile_upload_art_hint"
    /// Plain suit name (no symbol prefix) — Ascension/Descension rule-bar suit list, e.g. "Ascension: Spades, Hearts"
    case suitNameSpadesPlain = "suit_name_spades_plain"
    /// Plain suit name (no symbol prefix) — Ascension/Descension rule-bar suit list
    case suitNameHeartsPlain = "suit_name_hearts_plain"
    /// Plain suit name (no symbol prefix) — Ascension/Descension rule-bar suit list
    case suitNameDiamondsPlain = "suit_name_diamonds_plain"
    /// Plain suit name (no symbol prefix) — Ascension/Descension rule-bar suit list
    case suitNameClubsPlain = "suit_name_clubs_plain"
    /// Windows About window: update download in progress
    case aboutDownloadingUpdate = "about_downloading_update"
    /// Windows About window: update download progress with percentage
    case aboutDownloadingUpdatePctFmt = "about_downloading_update_pct_fmt"
    /// Windows About window: update download failure message
    case aboutUpdateDownloadFailed = "about_update_download_failed"
    /// Windows About window: button to install a downloaded update and restart
    case installAndRestart = "install_and_restart"
    /// Windows Background editor window title when adding a new background
    case addBackgroundTitle = "add_background_title"
    /// Windows Background editor window title when editing an existing background
    case editBackgroundTitle = "edit_background_title"
    /// Windows Card Back editor: note shown instead of position sliders for fill-type card backs
    case cardBackFillNote = "card_back_fill_note"
    /// Windows Video Poker Deal/Draw toggle button, Deal state (D hotkey)
    case btnDealDHotkey = "btn_deal_d_hotkey"
    /// Windows Video Poker Deal/Draw toggle button, Draw state (D hotkey)
    case btnDrawDHotkey = "btn_draw_d_hotkey"
    /// Windows Deck Builder: right-click context menu item on a deck card
    case removeFromDeckContextMenu = "remove_from_deck_context_menu"
    /// Windows Manage Decks: star-count filter dropdown item, e.g. "1 Star"/"3 Stars"
    case starCountFilterFmt = "star_count_filter_fmt"
    /// Windows Manage Decks: empty state when the current filter selection matches no cards
    case noCardsMatchFilter = "no_cards_match_filter"
    /// Match-result overlay title on a loss (Honeycomb)
    case youLose = "you_lose"
    /// Match-result overlay title when a tied match enters Sudden Death; %@ is the localized Sudden Death rule name
    case drawSuddenDeathFmt = "draw_sudden_death_fmt"
    /// Result summary label, single-hand loss (iOS visible text)
    case resultDealerWins = "result_dealer_wins"
    /// Result summary label, multi-hand (split) win — %d is the hand number
    case resultHandWinFmt = "result_hand_win_fmt"
    /// Result summary label, multi-hand (split) loss — %d is the hand number
    case resultHandLossFmt = "result_hand_loss_fmt"
    /// Result summary label, multi-hand (split) push — %d is the hand number
    case resultHandPushFmt = "result_hand_push_fmt"
    /// Result summary label, multi-hand (split) bust — %d is the hand number
    case resultHandBustFmt = "result_hand_bust_fmt"
    /// Confirmation dialog when starting a new match mid-match
    case newMatchConfirmTitle = "new_match_confirm_title"
    /// Confirmation dialog when requesting a rematch mid-match
    case rematchConfirmTitle = "rematch_confirm_title"
    /// iOS slide-down menu segmented tab
    case menuTabGameSelection = "menu_tab_game_selection"
    /// iOS slide-down menu header title
    case menuHeaderTitle = "menu_header_title"
    /// iOS slide-down menu close-button accessibility label
    case closeMenuA11y = "close_menu_a11y"
    /// iOS slide-down menu Game Selection tab section header
    case menuSectionGame = "menu_section_game"
    /// iOS slide-down menu Themes tab felt-color section header
    case menuSectionTheme = "menu_section_theme"
    /// iOS slide-down menu Themes tab card-back section header
    case menuSectionCardBack = "menu_section_card_back"
    /// iOS slide-down menu Themes tab background section header
    case menuSectionBackground = "menu_section_background"
    /// iOS slide-down menu: clears the custom background back to felt color
    case backgroundNoneOption = "background_none_option"
    /// iOS slide-down menu: confirm removing a custom card back
    case removeCardBackAlertTitle = "remove_card_back_alert_title"
    /// iOS slide-down menu: confirm removing a custom background
    case removeBackgroundAlertTitle = "remove_background_alert_title"
    /// iOS slide-down menu: alert body, reused for both card-back and background removal
    case removeImportedImageBody = "remove_imported_image_body"
    /// iOS slide-down menu: Statistics destination row
    case statisticsNavRow = "statistics_nav_row"
    /// iOS slide-down menu: Help destination row
    case howToPlayNavRow = "how_to_play_nav_row"
    /// iOS slide-down menu: Face Card Art destination row
    case faceCardArtNavRow = "face_card_art_nav_row"
    /// iOS touch game views: New (deal) toolbar Label, Klondike/Spider/Beecell
    case touchNewDealLabel = "touch_new_deal_label"
    /// iOS touch game views: Undo Last Move toolbar Label, Klondike/Spider/Beecell
    case touchUndoLastMoveLabel = "touch_undo_last_move_label"
    /// iOS Spider touch view: stock pile accessibility label
    case touchDealA11y = "touch_deal_a11y"
    /// iOS Spider touch view: completed-runs tray accessibility label
    case touchCompletedRunsA11y = "touch_completed_runs_a11y"
    /// iOS Beecell touch view: deck-count Picker label
    case touchDecksPickerLabel = "touch_decks_picker_label"
    /// iOS Beecell touch view: deck-count Picker option
    case touchSingleDeckOption = "touch_single_deck_option"
    /// iOS Beecell touch view: deck-count Picker option
    case touchDoubleDeckOption = "touch_double_deck_option"
    /// iOS Spider touch view: suit-count Picker label (mislabeled "Difficulty" in source, corrected to match Mac's "Suits:")
    case touchSuitsPickerLabel = "touch_suits_picker_label"
    /// iOS Video Poker touch view: Max bet button
    case touchBetMaxButton = "touch_bet_max_button"
    /// iOS Blackjack touch view: settings-locked notice during a round
    case touchSettingsUnlockBetweenHands = "touch_settings_unlock_between_hands"
    /// iOS Video Poker touch view: settings-locked notice during a hand
    case touchSettingsUnlockHandEnds = "touch_settings_unlock_hand_ends"
    /// iOS Blackjack/Video Poker touch stats: hands-dealt row label
    case touchHandsDealtStat = "touch_hands_dealt_stat"
    /// iOS Blackjack/Video Poker touch stats: session-credits row label
    case touchSessionCreditsStat = "touch_session_credits_stat"
    /// iOS Blackjack touch view: per-hand label when split (multiple hands), %d is the hand number
    case touchHandLabelFmt = "touch_hand_label_fmt"
    /// iOS Blackjack touch view: player hand label when not split (single hand)
    case touchYouLabel = "touch_you_label"
    /// iOS Blackjack touch view: appended to a hand value when busted (leading space intentional)
    case touchBustSuffix = "touch_bust_suffix"
    /// iOS Blackjack touch view: per-hand result badge
    case touchResultWin = "touch_result_win"
    /// iOS Blackjack touch view: per-hand result badge
    case touchResultLoss = "touch_result_loss"
    /// iOS Blackjack touch view: per-hand result badge
    case touchResultPush = "touch_result_push"
    /// iOS Blackjack touch view: per-hand result badge
    case touchResultBlackjack = "touch_result_blackjack"
    /// iOS Blackjack touch view: per-hand result badge
    case touchResultBust = "touch_result_bust"
    /// iOS Blackjack touch view: action button
    case touchActionHit = "touch_action_hit"
    /// iOS Blackjack touch view: action button
    case touchActionStand = "touch_action_stand"
    /// iOS Blackjack touch view: action button
    case touchActionDouble = "touch_action_double"
    /// iOS Blackjack touch view: action button
    case touchActionSplit = "touch_action_split"
    /// iOS custom-art import sheets: Reset Position button
    case touchResetPositionButton = "touch_reset_position_button"
    /// iOS custom card-back import sheet nav title
    case touchAddCardBackTitle = "touch_add_card_back_title"
    /// Steal-mode instructional hint, iOS (touch wording — Mac/Windows use the click-based steal_instruction key)
    case stealInstructionTap = "steal_instruction_tap"
    /// Placeholder/fallback text
    case touchLayoutComingSoon = "touch_layout_coming_soon"
    /// Title-case game label
    case touchBlackjackTitle = "touch_blackjack_title"
    /// All-caps banner/header label
    case touchBlackjackBanner = "touch_blackjack_banner"
    /// All-caps banner/header label
    case touchSpiderBanner = "touch_spider_banner"
    /// All-caps banner/header label
    case touchKlondikeBanner = "touch_klondike_banner"
    /// All-caps banner/header label
    case touchBeecellBanner = "touch_beecell_banner"
    /// Mac-only dev menu title
    case debugBannersMenu = "debug_banners_menu"
    /// Windows Manage Decks: display name for the slot-0 (default) deck
    case deckDefaultName = "deck_default_name"
    /// iOS Blackjack/Video Poker touch view: credits capsule label in free-play mode
    case freePlayLabel = "free_play_label"
    /// iOS custom-art import sheets: photo picker button, no image chosen yet
    case touchChoosePhoto = "touch_choose_photo"
    /// iOS custom-art import sheets: photo picker button, image already chosen
    case touchChooseDifferentPhoto = "touch_choose_different_photo"
    /// iOS custom-art import sheets: crop editor section header
    case touchPinchZoomReposition = "touch_pinch_zoom_reposition"
    /// iOS custom-art import sheets: name TextField placeholder
    case touchNameFieldPlaceholder = "touch_name_field_placeholder"
    /// iOS custom-art import sheets: duplicate-name validation error
    case touchNameAlreadyTakenError = "touch_name_already_taken_error"
    /// iOS custom face-card-art import sheet: Enabled toggle label
    case touchEnabledToggle = "touch_enabled_toggle"
    /// Auto-filled base name for a new custom card back before the user renames it (appended with ' N' for the 2nd, 3rd, ... duplicate)
    case cardBackDefaultName = "card_back_default_name"
    /// Caption on the iOS Themes sheet Background grid's Add tile (imports a photo, unlike Card Back/Face Art's plain "Add")
    case addPhotoShort = "add_photo_short"
    /// Caption on the iOS Themes sheet Background grid's Custom Felt tile — shorter than feltCustomColor ("Custom Felt Color") so it fits the narrow tile without truncating
    case feltCustomShort = "felt_custom_short"
}
