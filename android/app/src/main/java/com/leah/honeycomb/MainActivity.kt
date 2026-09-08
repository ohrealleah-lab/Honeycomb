package com.leah.honeycomb

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.*
import com.leah.honeycomb.klondike.KlondikeBoard
import com.leah.honeycomb.klondike.KlondikeOptionsSheet
import com.leah.honeycomb.klondike.KlondikeStatsScreen
import com.leah.honeycomb.spider.SpiderBoard
import com.leah.honeycomb.spider.SpiderOptionsScreen
import com.leah.honeycomb.spider.SpiderStatsScreen
import com.leah.honeycomb.beecell.BeecellBoard
import com.leah.honeycomb.beecell.BeecellOptionsScreen
import com.leah.honeycomb.beecell.BeecellStatsScreen
import com.leah.honeycomb.blackjack.BlackjackBoard
import com.leah.honeycomb.blackjack.BlackjackOptionsScreen
import com.leah.honeycomb.blackjack.BlackjackStatsScreen
import com.leah.honeycomb.honeycomb.HoneycombMatchUI
import com.leah.honeycomb.honeycomb.HoneycombStatsScreen
import com.leah.honeycomb.videopoker.VideoPokerBoard
import com.leah.honeycomb.videopoker.VideoPokerOptionsScreen
import com.leah.honeycomb.videopoker.VideoPokerStatsScreen

class MainActivity : ComponentActivity() {
    private lateinit var appContainer: AppContainer

    override fun onCreate(savedInstanceState: Bundle?) {
        if (!::appContainer.isInitialized) {
            appContainer = AppContainer(applicationContext)
        }
        super.onCreate(savedInstanceState)
        

        setContent {
            val themes by appContainer.themeManager.themes.collectAsState()
            val activeThemeId by appContainer.themeManager.activeThemeId.collectAsState()
            val activeTheme = themes.find { it.id == activeThemeId } ?: com.leah.honeycomb.theme.ThemeManager.defaultThemes.first()

            MaterialTheme {
                CompositionLocalProvider(
                    LocalAppContainer provides appContainer,
                    com.leah.honeycomb.theme.LocalSoliBeeTheme provides activeTheme
                ) {
                    val navController = rememberNavController()
                    var showGameSelection by remember { mutableStateOf(false) }
                    var currentRoute by remember { mutableStateOf(appContainer.initialGameMode) }
                    

                    
                    DisposableEffect(navController) {
                        val listener = androidx.navigation.NavController.OnDestinationChangedListener { _, destination, _ ->
                            val route = destination.route
                            if (route in gamesList.map { it.route }) {
                                appContainer.setLastGameMode(route!!)
                                currentRoute = route
                            }
                        }
                        navController.addOnDestinationChangedListener(listener)
                        onDispose {
                            navController.removeOnDestinationChangedListener(listener)
                        }
                    }
                    
                    androidx.compose.foundation.layout.Box(modifier = androidx.compose.ui.Modifier.fillMaxSize()) {
                        val intensity = if (currentRoute.startsWith(AppRoute.Blackjack.Board.route) || currentRoute.startsWith(AppRoute.VideoPoker.Board.route)) 0.6f else 0.45f
                        com.leah.honeycomb.theme.AppBackground(intensity = intensity)
                        
                        NavHost(navController = navController, startDestination = appContainer.initialGameMode.takeIf { it != "home" } ?: AppRoute.Klondike.Board.route, modifier = androidx.compose.ui.Modifier.fillMaxSize()) {

                        composable(AppRoute.About.route) {
                            com.leah.honeycomb.theme.AboutScreen(onBack = { navController.popBackStack() })
                        }
                        composable(AppRoute.Themes.route) {
                            com.leah.honeycomb.theme.ThemesScreen(onBack = { navController.popBackStack() }, onAbout = { navController.navigate(AppRoute.About.route) }, onImportArt = { navController.navigate(AppRoute.CustomArtImport.route) })
                        }
                        composable(AppRoute.CustomArtImport.route) {
                            com.leah.honeycomb.theme.CustomArtImportScreen(onBack = { navController.popBackStack() })
                        }
                        composable(AppRoute.SharedOptions.route) {
                            com.leah.honeycomb.SharedOptionsScreen(onBack = { navController.popBackStack() })
                        }
                        composable(AppRoute.Klondike.Board.route) {
                            KlondikeBoard(
                                viewModel = appContainer.klondikeViewModel,
                                onOptionsTap = { navController.navigate(AppRoute.Klondike.Options.route) },
                                onMenuTap = { showGameSelection = true },
                                onThemesTap = { navController.navigate(AppRoute.Themes.route) }
                            )
                        }
                        composable(AppRoute.Klondike.Options.route) {
                            KlondikeOptionsSheet(
                                viewModel = appContainer.klondikeViewModel,
                                onDismiss = { navController.popBackStack() },
                                onShowStats = { navController.navigate(AppRoute.Klondike.Stats.route) }
                            )
                        }
                        composable(AppRoute.Klondike.Stats.route) {
                            KlondikeStatsScreen(
                                viewModel = appContainer.klondikeViewModel,
                                onDismiss = { navController.popBackStack() }
                            )
                        }
                        composable(AppRoute.Spider.Board.route) {
                            SpiderBoard(
                                viewModel = appContainer.spiderViewModel,
                                onMenuTap = { showGameSelection = true },
                                onOptions = { navController.navigate(AppRoute.Spider.Options.route) },
                                onThemes = { navController.navigate(AppRoute.Themes.route) }
                            )
                        }
                        composable(AppRoute.Spider.Options.route) {
                            SpiderOptionsScreen(
                                viewModel = appContainer.spiderViewModel,
                                onBack = { navController.popBackStack() },
                                onOpenThemes = { navController.navigate(AppRoute.Themes.route) },
                                onOpenSharedOptions = { navController.navigate(AppRoute.SharedOptions.route) },
                                onShowStats = { navController.navigate(AppRoute.Spider.Stats.route) }
                            )
                        }
                        composable(AppRoute.Spider.Stats.route) {
                            SpiderStatsScreen(
                                viewModel = appContainer.spiderViewModel,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable(AppRoute.Beecell.Board.route) {
                            BeecellBoard(
                                viewModel = appContainer.beecellViewModel,
                                onMenuTap = { showGameSelection = true },
                                onOptions = { navController.navigate(AppRoute.Beecell.Options.route) },
                                onThemes = { navController.navigate(AppRoute.Themes.route) }
                            )
                        }
                        composable(AppRoute.Beecell.Options.route) {
                            BeecellOptionsScreen(
                                viewModel = appContainer.beecellViewModel,
                                onBack = { navController.popBackStack() },
                                onOpenThemes = { navController.navigate(AppRoute.Themes.route) },
                                onOpenSharedOptions = { navController.navigate(AppRoute.SharedOptions.route) },
                                onShowStats = { navController.navigate(AppRoute.Beecell.Stats.route) }
                            )
                        }
                        composable(AppRoute.Beecell.Stats.route) {
                            BeecellStatsScreen(
                                viewModel = appContainer.beecellViewModel,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable(AppRoute.Blackjack.Board.route) {
                            BlackjackBoard(
                                viewModel = appContainer.blackjackViewModel,
                                onMenuTap = { showGameSelection = true },
                                onOptions = { navController.navigate(AppRoute.Blackjack.Options.route) },
                                onThemes = { navController.navigate(AppRoute.Themes.route) }
                            )
                        }
                        composable(AppRoute.Blackjack.Options.route) {
                            BlackjackOptionsScreen(
                                viewModel = appContainer.blackjackViewModel,
                                onBack = { navController.popBackStack() },
                                onOpenThemes = { navController.navigate(AppRoute.Themes.route) },
                                onOpenSharedOptions = { navController.navigate(AppRoute.SharedOptions.route) },
                                onShowStats = { navController.navigate(AppRoute.Blackjack.Stats.route) }
                            )
                        }
                        composable(AppRoute.Blackjack.Stats.route) {
                            BlackjackStatsScreen(
                                viewModel = appContainer.blackjackViewModel,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable(AppRoute.VideoPoker.Board.route) {
                            VideoPokerBoard(
                                viewModel = appContainer.videoPokerViewModel,
                                onMenuTap = { showGameSelection = true },
                                onOptions = { navController.navigate(AppRoute.VideoPoker.Options.route) },
                                onThemes = { navController.navigate(AppRoute.Themes.route) }
                            )
                        }
                        composable(AppRoute.VideoPoker.Options.route) {
                            VideoPokerOptionsScreen(
                                viewModel = appContainer.videoPokerViewModel,
                                onBack = { navController.popBackStack() },
                                onOpenThemes = { navController.navigate(AppRoute.Themes.route) },
                                onOpenSharedOptions = { navController.navigate(AppRoute.SharedOptions.route) },
                                onShowStats = { navController.navigate(AppRoute.VideoPoker.Stats.route) }
                            )
                        }
                        composable(AppRoute.VideoPoker.Stats.route) {
                            VideoPokerStatsScreen(
                                viewModel = appContainer.videoPokerViewModel,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        
                        composable(AppRoute.Honeycomb.Board.route) {
                            HoneycombMatchUI(
                                viewModel = appContainer.honeycombViewModel,
                                onMenuTap = { showGameSelection = true },
                                onOptionsTap = { navController.navigate(AppRoute.Honeycomb.Options.route) },
                                onThemesTap = { navController.navigate(AppRoute.Themes.route) },
                                onManageDecksTap = { navController.navigate(AppRoute.Honeycomb.Decks.route) },
                                onRulesTap = { navController.navigate(AppRoute.Honeycomb.Rules.route) }
                            )
                        }
                        composable(AppRoute.Honeycomb.Options.route) {
                            com.leah.honeycomb.honeycomb.HoneycombOptionsScreen(
                                viewModel = appContainer.honeycombViewModel,
                                onBack = { navController.popBackStack() },
                                onOpenThemes = { navController.navigate(AppRoute.Themes.route) },
                                onOpenSharedOptions = { navController.navigate(AppRoute.SharedOptions.route) },
                                onShowStats = { navController.navigate(AppRoute.Honeycomb.Stats.route) }
                            )
                        }
                        composable(AppRoute.Honeycomb.Stats.route) {
                            HoneycombStatsScreen(
                                viewModel = appContainer.honeycombViewModel,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable(AppRoute.Honeycomb.Decks.route) {
                            com.leah.honeycomb.honeycomb.HoneycombDecksScreen(
                                viewModel = appContainer.honeycombViewModel,
                                profileManager = appContainer.honeycombProfileManager,
                                database = appContainer.honeycombDatabase,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable(AppRoute.Honeycomb.Rules.route) {
                            com.leah.honeycomb.honeycomb.HoneycombRulesScreen(
                                viewModel = appContainer.honeycombViewModel,
                                onBack = { navController.popBackStack() }
                            )
                        }
                    }
                    
                    if (showGameSelection) {
                        GameSelectionSheet(
                            currentRoute = currentRoute,
                            onNavigate = { route ->
                                navController.navigate(route) {
                                    popUpTo(0) { inclusive = true }
                                    launchSingleTop = true
                                }
                            },
                            onDismiss = { showGameSelection = false }
                        )
                    }
                    } // close Box
                }
            }
        }
    }
}
