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
                    
                    LaunchedEffect(Unit) {
                        if (appContainer.initialGameMode != "home") {
                            navController.navigate(appContainer.initialGameMode)
                        }
                    }
                    
                    DisposableEffect(navController) {
                        val listener = androidx.navigation.NavController.OnDestinationChangedListener { _, destination, _ ->
                            val route = destination.route
                            if (route in listOf("klondike", "spider", "beecell", "blackjack", "videopoker", "honeycomb")) {
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
                        val intensity = if (currentRoute.startsWith("blackjack") || currentRoute.startsWith("videopoker")) 0.6f else 0.45f
                        com.leah.honeycomb.theme.AppBackground(intensity = intensity)
                        
                        NavHost(navController = navController, startDestination = "home", modifier = androidx.compose.ui.Modifier.fillMaxSize()) {
                        composable("home") {
                            Column(
                                modifier = Modifier.fillMaxSize(),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Center
                            ) {
                                Text("Honeycomb Casino", style = MaterialTheme.typography.headlineLarge)
                                Spacer(modifier = Modifier.height(32.dp))
                                Button(onClick = { navController.navigate("klondike") }) { Text("Play Klondike") }
                                Spacer(modifier = Modifier.height(16.dp))
                                Button(onClick = { navController.navigate("spider") }) { Text("Play Spider") }
                                Spacer(modifier = Modifier.height(16.dp))
                                Button(onClick = { navController.navigate("beecell") }) { Text("Play Beecell") }
                                Spacer(modifier = Modifier.height(16.dp))
                                Button(onClick = { navController.navigate("blackjack") }) { Text("Play Blackjack") }
                                Spacer(modifier = Modifier.height(16.dp))
                                Button(onClick = { navController.navigate("videopoker") }) { Text("Play Video Poker") }
                                Spacer(modifier = Modifier.height(16.dp))
                                Button(onClick = { navController.navigate("honeycomb") }) { Text("Play Honeycomb") }
                                Spacer(modifier = Modifier.height(32.dp))
                                Button(onClick = { navController.navigate("themes") }) { Text("Themes") }
                                Spacer(modifier = Modifier.height(16.dp))
                                Button(onClick = { navController.navigate("custom_art_import") }) { Text("Import Custom Art") }
                                Spacer(modifier = Modifier.height(16.dp))
                                Button(onClick = { navController.navigate("shared_options") }) { Text("Shared Options") }
                            }
                        }
                        composable("about") {
                            com.leah.honeycomb.theme.AboutScreen(onBack = { navController.popBackStack() })
                        }
                        composable("themes") {
                            com.leah.honeycomb.theme.ThemesScreen(onBack = { navController.popBackStack() }, onAbout = { navController.navigate("about") })
                        }
                        composable("custom_art_import") {
                            com.leah.honeycomb.theme.CustomArtImportScreen(onBack = { navController.popBackStack() })
                        }
                        composable("shared_options") {
                            com.leah.honeycomb.SharedOptionsScreen(onBack = { navController.popBackStack() })
                        }
                        composable("klondike") {
                            KlondikeBoard(
                                viewModel = appContainer.klondikeViewModel,
                                onOptionsTap = { navController.navigate("klondike_options") },
                                onMenuTap = { showGameSelection = true },
                                onThemesTap = { navController.navigate("themes") }
                            )
                        }
                        composable("klondike_options") {
                            KlondikeOptionsSheet(
                                viewModel = appContainer.klondikeViewModel,
                                onDismiss = { navController.popBackStack() },
                                onShowStats = { navController.navigate("klondike_stats") }
                            )
                        }
                        composable("klondike_stats") {
                            KlondikeStatsScreen(
                                viewModel = appContainer.klondikeViewModel,
                                onDismiss = { navController.popBackStack() }
                            )
                        }
                        composable("spider") {
                            SpiderBoard(
                                viewModel = appContainer.spiderViewModel,
                                onMenuTap = { showGameSelection = true },
                                onOptions = { navController.navigate("spider_options") },
                                onThemes = { navController.navigate("themes") }
                            )
                        }
                        composable("spider_options") {
                            SpiderOptionsScreen(
                                viewModel = appContainer.spiderViewModel,
                                onBack = { navController.popBackStack() },
                                onOpenThemes = { navController.navigate("themes") },
                                onOpenSharedOptions = { navController.navigate("shared_options") },
                                onShowStats = { navController.navigate("spider_stats") }
                            )
                        }
                        composable("spider_stats") {
                            SpiderStatsScreen(
                                viewModel = appContainer.spiderViewModel,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable("beecell") {
                            BeecellBoard(
                                viewModel = appContainer.beecellViewModel,
                                onMenuTap = { showGameSelection = true },
                                onOptions = { navController.navigate("beecell_options") },
                                onThemes = { navController.navigate("themes") }
                            )
                        }
                        composable("beecell_options") {
                            BeecellOptionsScreen(
                                viewModel = appContainer.beecellViewModel,
                                onBack = { navController.popBackStack() },
                                onOpenThemes = { navController.navigate("themes") },
                                onOpenSharedOptions = { navController.navigate("shared_options") },
                                onShowStats = { navController.navigate("beecell_stats") }
                            )
                        }
                        composable("beecell_stats") {
                            BeecellStatsScreen(
                                viewModel = appContainer.beecellViewModel,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable("blackjack") {
                            BlackjackBoard(
                                viewModel = appContainer.blackjackViewModel,
                                onMenuTap = { showGameSelection = true },
                                onOptions = { navController.navigate("blackjack_options") },
                                onThemes = { navController.navigate("themes") }
                            )
                        }
                        composable("blackjack_options") {
                            BlackjackOptionsScreen(
                                viewModel = appContainer.blackjackViewModel,
                                onBack = { navController.popBackStack() },
                                onOpenThemes = { navController.navigate("themes") },
                                onOpenSharedOptions = { navController.navigate("shared_options") },
                                onShowStats = { navController.navigate("blackjack_stats") }
                            )
                        }
                        composable("blackjack_stats") {
                            BlackjackStatsScreen(
                                viewModel = appContainer.blackjackViewModel,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable("videopoker") {
                            VideoPokerBoard(
                                viewModel = appContainer.videoPokerViewModel,
                                onMenuTap = { showGameSelection = true },
                                onOptions = { navController.navigate("videopoker_options") },
                                onThemes = { navController.navigate("themes") }
                            )
                        }
                        composable("videopoker_options") {
                            VideoPokerOptionsScreen(
                                viewModel = appContainer.videoPokerViewModel,
                                onBack = { navController.popBackStack() },
                                onOpenThemes = { navController.navigate("themes") },
                                onOpenSharedOptions = { navController.navigate("shared_options") },
                                onShowStats = { navController.navigate("videopoker_stats") }
                            )
                        }
                        composable("videopoker_stats") {
                            VideoPokerStatsScreen(
                                viewModel = appContainer.videoPokerViewModel,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        
                        composable("honeycomb") {
                            HoneycombMatchUI(
                                viewModel = appContainer.honeycombViewModel,
                                onMenuTap = { showGameSelection = true },
                                onOptionsTap = { navController.navigate("honeycomb_options") },
                                onThemesTap = { navController.navigate("themes") },
                                onManageDecksTap = { navController.navigate("honeycomb_decks") },
                                onRulesTap = { navController.navigate("honeycomb_rules") }
                            )
                        }
                        composable("honeycomb_options") {
                            com.leah.honeycomb.honeycomb.HoneycombOptionsScreen(
                                viewModel = appContainer.honeycombViewModel,
                                onBack = { navController.popBackStack() },
                                onOpenThemes = { navController.navigate("themes") },
                                onOpenSharedOptions = { navController.navigate("shared_options") },
                                onShowStats = { navController.navigate("honeycomb_stats") }
                            )
                        }
                        composable("honeycomb_stats") {
                            HoneycombStatsScreen(
                                viewModel = appContainer.honeycombViewModel,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable("honeycomb_decks") {
                            com.leah.honeycomb.honeycomb.HoneycombDecksScreen(
                                viewModel = appContainer.honeycombViewModel,
                                profileManager = appContainer.honeycombProfileManager,
                                database = appContainer.honeycombDatabase,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable("honeycomb_rules") {
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
                                    popUpTo("home")
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
