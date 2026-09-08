package com.leah.honeycomb

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@Composable
fun GlobalOptionsSection(
    sharedOptions: SharedGameOptions,
    language: AppLanguage,
    showHideHintRow: Boolean = true
) {
    val isSoundEnabled by sharedOptions.isSoundEnabled.collectAsState()
    val honeyMode by sharedOptions.honeyMode.collectAsState()
    val hideHintButton by sharedOptions.hideHintButton.collectAsState()
    val noStressMode by sharedOptions.noStressMode.collectAsState()
    val manuallyDismissBanners by sharedOptions.manuallyDismissBanners.collectAsState()
    val hideBee by sharedOptions.hideBee.collectAsState()

    Column {
        SwitchOptionRow(
            label = Strings.get(StringKey.SoundEffects, language),
            checked = isSoundEnabled,
            onCheckedChange = { sharedOptions.setSoundEnabled(it) }
        )
        SwitchOptionRow(
            label = Strings.get(StringKey.HoneyMode, language),
            checked = honeyMode,
            onCheckedChange = { sharedOptions.setHoneyMode(it) }
        )
        if (showHideHintRow) {
            SwitchOptionRow(
                label = Strings.get(StringKey.HideHintButton, language),
                checked = hideHintButton,
                onCheckedChange = { sharedOptions.setHideHintButton(it) }
            )
        }
        SwitchOptionRow(
            label = Strings.get(StringKey.NoStressMode, language),
            checked = noStressMode,
            onCheckedChange = { sharedOptions.setNoStressMode(it) }
        )
        SwitchOptionRow(
            label = Strings.get(StringKey.ManuallyDismissBanners, language),
            checked = manuallyDismissBanners,
            onCheckedChange = { sharedOptions.setManuallyDismissBanners(it) }
        )
        SwitchOptionRow(
            label = Strings.get(StringKey.HideBee, language),
            checked = hideBee,
            onCheckedChange = { sharedOptions.setHideBee(it) }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OptionsFullScreenView(
    title: String,
    gameSectionTitle: String?,
    onDismiss: () -> Unit,
    onShowStats: (() -> Unit)? = null,
    helpText: String? = null,
    gameSettings: (@Composable () -> Unit)? = null
) {
    val appContainer = LocalAppContainer.current
    val sharedOptions = appContainer.sharedOptions
    val language by appContainer.language.collectAsState()
    var showHelp by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(title, fontWeight = FontWeight.Bold) },
                actions = {
                    TextButton(onClick = onDismiss) {
                        Text("Done", color = Color(0xFF007AFF), fontWeight = FontWeight.Bold)
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .padding(padding)
                .padding(horizontal = 16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            Spacer(modifier = Modifier.height(8.dp))
            
            // Language Section
            Column {
                Text(Strings.get(StringKey.Language, language), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(8.dp))
                SegmentedControl(
                    items = listOf(AppLanguage.English, AppLanguage.Spanish),
                    selectedItem = language,
                    onItemSelection = { appContainer.setLanguage(it) },
                    itemLabel = { if (it == AppLanguage.English) "English" else "Español" }
                )
            }

            // Game Settings
            if (gameSettings != null && gameSectionTitle != null) {
                Column {
                    Text(gameSectionTitle, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Spacer(modifier = Modifier.height(8.dp))
                    RoundedContainer {
                        gameSettings()
                    }
                }
            }

            // Global Options
            Column {
                Text(Strings.get(StringKey.GlobalSettingsHeader, language), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(8.dp))
                RoundedContainer {
                    GlobalOptionsSection(sharedOptions, language)
                }
            }

            // Navigation
            Column {
                RoundedContainer {
                    if (onShowStats != null) {
                        NavigationRow(Strings.get(StringKey.StatisticsNavRow, language), onClick = onShowStats)
                        if (helpText != null) {
                            HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                        }
                    }
                    if (helpText != null) {
                        NavigationRow(Strings.get(StringKey.HowToPlayNavRow, language), onClick = { showHelp = true })
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
        }
    }

    if (showHelp && helpText != null) {
        ModalBottomSheet(onDismissRequest = { showHelp = false }) {
            Column(modifier = Modifier.padding(16.dp).verticalScroll(rememberScrollState())) {
                Text(
                    text = Strings.get(StringKey.HelpRulesHowToPlayTitle, language),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 16.dp)
                )
                Text(text = helpText, style = MaterialTheme.typography.bodyLarge)
                Spacer(modifier = Modifier.height(48.dp))
            }
        }
    }
}

@Composable
fun RoundedContainer(content: @Composable () -> Unit) {
    Surface(
        color = Color.Black.copy(alpha = 0.05f),
        shape = RoundedCornerShape(10.dp)
    ) {
        Column(modifier = Modifier.padding(vertical = 8.dp)) {
            content()
        }
    }
}

@Composable
fun NavigationRow(title: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, style = MaterialTheme.typography.bodyLarge)
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = Color.Gray)
    }
}

@Composable
fun <T> SegmentedControl(
    items: List<T>,
    selectedItem: T,
    onItemSelection: (T) -> Unit,
    itemLabel: (T) -> String
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.Black.copy(alpha = 0.05f), RoundedCornerShape(percent = 50))
            .padding(4.dp)
    ) {
        items.forEach { item ->
            val isSelected = selectedItem == item
            val backgroundShape = RoundedCornerShape(percent = 50)
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(backgroundShape)
                    .background(if (isSelected) MaterialTheme.colorScheme.surface else Color.Transparent)
                    .clickable { onItemSelection(item) }
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = itemLabel(item),
                    color = if (isSelected) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                )
            }
        }
    }
}

@Composable
fun SwitchOptionRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = label, style = MaterialTheme.typography.bodyLarge)
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
fun IntStepperRow(
    label: String,
    value: Int,
    step: Int,
    range: IntRange,
    onValueChange: (Int) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = label, style = MaterialTheme.typography.bodyLarge)
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { onValueChange((value - step).coerceIn(range)) }, enabled = value > range.first) {
                Icon(Icons.Default.Remove, contentDescription = "Decrease")
            }
            Text(
                text = "$value",
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.widthIn(min = 56.dp),
                textAlign = TextAlign.Center
            )
            IconButton(onClick = { onValueChange((value + step).coerceIn(range)) }, enabled = value < range.last) {
                Icon(Icons.Default.Add, contentDescription = "Increase")
            }
        }
    }
}

@Composable
fun SharedOptionsScreen(onBack: () -> Unit) {
    val appContainer = LocalAppContainer.current
    val language by appContainer.language.collectAsState()

    OptionsFullScreenView(
        title = Strings.get(StringKey.Options, language),
        gameSectionTitle = null,
        onDismiss = onBack,
        gameSettings = null
    )
}
