package com.leah.honeycomb.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import com.leah.honeycomb.CardBackView
import com.leah.honeycomb.LocalAppContainer

// Single source of truth for the built-in felt names <-> FeltColorType mapping — was
// previously duplicated (and had drifted from CardView.kt's actual bundled card-back set).
val builtinFeltNames = listOf("Green Felt", "Crimson", "Royal Blue", "Charcoal", "Desert Felt")

fun feltColorForName(name: String): FeltColorType = when (name) {
    "Green Felt" -> FeltColorType.FeltGreen
    "Crimson" -> FeltColorType.Crimson
    "Royal Blue" -> FeltColorType.RoyalBlue
    "Charcoal" -> FeltColorType.Charcoal
    "Desert Felt" -> FeltColorType.Desert
    else -> FeltColorType.FeltGreen
}

// Every name CardView.kt's CardBackView actually knows how to render as a bundled asset —
// previously only a 4-name subset was offered here, silently hiding decks a saved theme
// (e.g. the default "Pareidolic 2" theme) could still be using.
val builtinCardBackNames = listOf(
    "Solibee", "Pareidolic", "Pareidolic 2", "Vulpera", "Forest",
    "Moogle", "Dingwall", "On The Water", "Red Sky", "Sunset"
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ThemesScreen(onBack: () -> Unit, onAbout: () -> Unit = {}) {
    val appContainer = LocalAppContainer.current
    val themeManager = appContainer.themeManager
    val themes by themeManager.themes.collectAsState()
    val activeThemeId by themeManager.activeThemeId.collectAsState()
    val showFeltVignette by themeManager.showFeltVignette.collectAsState()

    val customCardBacks by appContainer.customCardBackManager.cardBacks.collectAsState()
    val customBackgrounds by appContainer.customBackgroundManager.backgrounds.collectAsState()

    val scrollState = rememberScrollState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Themes") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = onAbout) {
                        Icon(Icons.Default.Info, contentDescription = "About")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // Saved Themes
            Text("Saved Themes", style = MaterialTheme.typography.titleMedium)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                items(themes) { theme ->
                    ThemePreviewItem(
                        theme = theme,
                        isActive = theme.id == activeThemeId,
                        onApply = { themeManager.setActiveTheme(theme.id) }
                    )
                }
            }

            // Card Back — built-ins keep their display name; custom imports are identified
            // by id and shown as an unlabeled thumbnail (no name to show).
            Text("Card Back", style = MaterialTheme.typography.titleMedium)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                items(builtinCardBackNames) { cbName ->
                    CardBackSelectorItem(
                        cardBackId = cbName,
                        label = cbName,
                        onClick = { themeManager.updateActiveThemeCardBack(cbName) }
                    )
                }
                items(customCardBacks, key = { it.id }) { custom ->
                    CardBackSelectorItem(
                        cardBackId = custom.id,
                        label = null,
                        onClick = { themeManager.updateActiveThemeCardBack(custom.id) }
                    )
                }
            }

            // Background — same built-in-vs-custom split as Card Back above.
            Text("Background", style = MaterialTheme.typography.titleMedium)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                items(builtinFeltNames) { bgName ->
                    BackgroundSelectorItem(
                        label = bgName,
                        feltColor = feltColorForName(bgName),
                        customBackgroundId = null,
                        onClick = { themeManager.updateActiveThemeBackground(feltColorForName(bgName), null) }
                    )
                }
                items(customBackgrounds, key = { it.id }) { custom ->
                    BackgroundSelectorItem(
                        label = null,
                        feltColor = FeltColorType.Custom,
                        customBackgroundId = custom.id,
                        onClick = { themeManager.updateActiveThemeBackground(FeltColorType.Custom, custom.id) }
                    )
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Show Vignette")
                Spacer(modifier = Modifier.width(8.dp))
                Switch(
                    checked = showFeltVignette,
                    onCheckedChange = { themeManager.setShowFeltVignette(it) }
                )
            }

            // Custom Card Color
            Text("Custom Card Color", style = MaterialTheme.typography.titleMedium)
            CustomCardColorSection(themeManager)
        }
    }
}

@Composable
fun ThemePreviewItem(theme: SoliBeeTheme, isActive: Boolean, onApply: () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(80.dp, 120.dp)
                .clip(RoundedCornerShape(8.dp))
        ) {
            CompositionLocalProvider(LocalSoliBeeTheme provides theme) {
                AppBackground(modifier = Modifier.fillMaxSize())
            }
            Box(
                modifier = Modifier
                    .requiredSize(114.dp, 160.dp)
                    .wrapContentSize(unbounded = true, align = Alignment.Center)
                    .graphicsLayer { scaleX = 0.5f; scaleY = 0.5f }
            ) {
                CardBackView(themeName = theme.cardBackTheme, isAnimated = false)
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        if (isActive) {
            Text("Active", color = MaterialTheme.colorScheme.primary)
        } else {
            Button(onClick = onApply) {
                Text("Apply")
            }
        }
    }
}

@Composable
fun CardBackSelectorItem(cardBackId: String, label: String?, onClick: () -> Unit) {
    Column(
        modifier = Modifier.clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .requiredSize(114.dp, 160.dp)
                .wrapContentSize(unbounded = true, align = Alignment.Center)
                .graphicsLayer { scaleX = 0.6f; scaleY = 0.6f }
        ) {
            CardBackView(themeName = cardBackId, isAnimated = false)
        }
        if (label != null) {
            Text(label, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
fun BackgroundSelectorItem(label: String?, feltColor: FeltColorType, customBackgroundId: String?, onClick: () -> Unit) {
    val dummyTheme = SoliBeeTheme(
        name = "Dummy",
        cardBackTheme = "Solibee",
        feltColor = feltColor,
        customBackgroundName = customBackgroundId
    )
    Column(
        modifier = Modifier.clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(60.dp, 60.dp)
                .clip(RoundedCornerShape(8.dp))
        ) {
            CompositionLocalProvider(LocalSoliBeeTheme provides dummyTheme) {
                AppBackground(modifier = Modifier.fillMaxSize())
            }
        }
        if (label != null) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(label, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CustomCardColorSection(themeManager: ThemeManager) {
    val activeThemeId by themeManager.activeThemeId.collectAsState()
    val themes by themeManager.themes.collectAsState()
    val activeTheme = themes.find { it.id == activeThemeId }
    val colors = activeTheme?.customCardColors ?: CustomCardColorGroup()

    var colorToEdit by remember { mutableStateOf<String?>(null) }
    var currentRed by remember { mutableStateOf(0.0) }
    var currentGreen by remember { mutableStateOf(0.0) }
    var currentBlue by remember { mutableStateOf(0.0) }
    var currentAlpha by remember { mutableStateOf(1.0) }

    val openDialog = { name: String, r: Double, g: Double, b: Double, a: Double ->
        colorToEdit = name
        currentRed = r
        currentGreen = g
        currentBlue = b
        currentAlpha = a
    }

    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("Enable Custom Colors")
        Spacer(modifier = Modifier.width(8.dp))
        Switch(
            checked = colors.isEnabled,
            onCheckedChange = { themeManager.updateActiveThemeCustomColors(colors.copy(isEnabled = it)) }
        )
    }

    if (colors.isEnabled) {
        FlowRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            ColorSwatch("Background", colors.bgRed, colors.bgGreen, colors.bgBlue, colors.bgAlpha) {
                openDialog("Background", colors.bgRed, colors.bgGreen, colors.bgBlue, colors.bgAlpha)
            }
            ColorSwatch("Outline", colors.outlineRed, colors.outlineGreen, colors.outlineBlue, colors.outlineAlpha) {
                openDialog("Outline", colors.outlineRed, colors.outlineGreen, colors.outlineBlue, colors.outlineAlpha)
            }
            ColorSwatch("Black Suit", colors.blackSuitRed, colors.blackSuitGreen, colors.blackSuitBlue, colors.blackSuitAlpha) {
                openDialog("Black Suit", colors.blackSuitRed, colors.blackSuitGreen, colors.blackSuitBlue, colors.blackSuitAlpha)
            }
            ColorSwatch("Red Suit", colors.redSuitRed, colors.redSuitGreen, colors.redSuitBlue, colors.redSuitAlpha) {
                openDialog("Red Suit", colors.redSuitRed, colors.redSuitGreen, colors.redSuitBlue, colors.redSuitAlpha)
            }
            ColorSwatch("Shadow", colors.shadowRed, colors.shadowGreen, colors.shadowBlue, colors.shadowAlpha) {
                openDialog("Shadow", colors.shadowRed, colors.shadowGreen, colors.shadowBlue, colors.shadowAlpha)
            }
        }
    }

    if (colorToEdit != null) {
        AlertDialog(
            onDismissRequest = { colorToEdit = null },
            title = { Text("Edit $colorToEdit") },
            text = {
                Column {
                    Text("Red")
                    Slider(value = currentRed.toFloat(), onValueChange = { currentRed = it.toDouble() })
                    Text("Green")
                    Slider(value = currentGreen.toFloat(), onValueChange = { currentGreen = it.toDouble() })
                    Text("Blue")
                    Slider(value = currentBlue.toFloat(), onValueChange = { currentBlue = it.toDouble() })
                    Text("Alpha")
                    Slider(value = currentAlpha.toFloat(), onValueChange = { currentAlpha = it.toDouble() })
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        val newColors = colors.copy()
                        when (colorToEdit) {
                            "Background" -> { newColors.bgRed = currentRed; newColors.bgGreen = currentGreen; newColors.bgBlue = currentBlue; newColors.bgAlpha = currentAlpha }
                            "Outline" -> { newColors.outlineRed = currentRed; newColors.outlineGreen = currentGreen; newColors.outlineBlue = currentBlue; newColors.outlineAlpha = currentAlpha }
                            "Black Suit" -> { newColors.blackSuitRed = currentRed; newColors.blackSuitGreen = currentGreen; newColors.blackSuitBlue = currentBlue; newColors.blackSuitAlpha = currentAlpha }
                            "Red Suit" -> { newColors.redSuitRed = currentRed; newColors.redSuitGreen = currentGreen; newColors.redSuitBlue = currentBlue; newColors.redSuitAlpha = currentAlpha }
                            "Shadow" -> { newColors.shadowRed = currentRed; newColors.shadowGreen = currentGreen; newColors.shadowBlue = currentBlue; newColors.shadowAlpha = currentAlpha }
                        }
                        themeManager.updateActiveThemeCustomColors(newColors)
                        colorToEdit = null
                    }
                ) { Text("Save") }
            },
            dismissButton = {
                TextButton(onClick = { colorToEdit = null }) { Text("Cancel") }
            }
        )
    }
}

@Composable
fun ColorSwatch(name: String, r: Double, g: Double, b: Double, a: Double, onClick: () -> Unit) {
    Column(
        modifier = Modifier.clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(Color(r.toFloat(), g.toFloat(), b.toFloat(), a.toFloat()))
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(name, style = MaterialTheme.typography.bodySmall)
    }
}
