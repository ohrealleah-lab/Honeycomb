package com.leah.honeycomb.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.AppLanguage
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.leah.honeycomb.LocalAppContainer

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ThemesScreen(onBack: () -> Unit, onAbout: () -> Unit = {}) {
    val appContainer = LocalAppContainer.current
    val themeManager = appContainer.themeManager
    val themes by themeManager.themes.collectAsState()
    val activeThemeId by themeManager.activeThemeId.collectAsState()

    var showCreateDialog by remember { mutableStateOf(false) }

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
                    IconButton(onClick = { onAbout() }) {
                        Icon(Icons.Default.Info, contentDescription = "About")
                    }
                }
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { showCreateDialog = true }) {
                Icon(androidx.compose.material.icons.Icons.Default.Add, contentDescription = "Create Theme")
            }
        }
    ) { padding ->
        LazyVerticalGrid(
            columns = GridCells.Adaptive(100.dp),
            modifier = Modifier.padding(padding).padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(themes) { theme ->
                ThemeTile(
                    theme = theme,
                    isActive = theme.id == activeThemeId,
                    onSelect = { themeManager.setActiveTheme(theme.id) }
                )
            }
        }
        
        if (showCreateDialog) {
            CreateThemeDialog(onDismiss = { showCreateDialog = false })
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateThemeDialog(onDismiss: () -> Unit) {
    val appContainer = LocalAppContainer.current
    var name by remember { mutableStateOf("") }
    
    val customBackgrounds by appContainer.customBackgroundManager.backgrounds.collectAsState()
    val backgroundOptions = listOf("Green Felt", "Desert Felt") + customBackgrounds.map { it.name }
    var selectedBackground by remember { mutableStateOf(backgroundOptions.first()) }
    var bgDropdownExpanded by remember { mutableStateOf(false) }

    val customCardBacks by appContainer.customCardBackManager.cardBacks.collectAsState()
    val cardBackOptions = listOf("Solibee", "Pareidolic", "Pareidolic 2", "Vulpera", "Forest") + customCardBacks.map { it.name }
    var selectedCardBack by remember { mutableStateOf(cardBackOptions.first()) }
    var cbDropdownExpanded by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Create Theme") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Theme Name") },
                    modifier = Modifier.fillMaxWidth()
                )
                
                ExposedDropdownMenuBox(
                    expanded = bgDropdownExpanded,
                    onExpandedChange = { bgDropdownExpanded = !bgDropdownExpanded }
                ) {
                    OutlinedTextField(
                        value = selectedBackground,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Background") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = bgDropdownExpanded) },
                        modifier = Modifier.menuAnchor().fillMaxWidth()
                    )
                    ExposedDropdownMenu(
                        expanded = bgDropdownExpanded,
                        onDismissRequest = { bgDropdownExpanded = false }
                    ) {
                        backgroundOptions.forEach { option ->
                            DropdownMenuItem(
                                text = { Text(option) },
                                onClick = {
                                    selectedBackground = option
                                    bgDropdownExpanded = false
                                }
                            )
                        }
                    }
                }
                
                ExposedDropdownMenuBox(
                    expanded = cbDropdownExpanded,
                    onExpandedChange = { cbDropdownExpanded = !cbDropdownExpanded }
                ) {
                    OutlinedTextField(
                        value = selectedCardBack,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Card Back") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = cbDropdownExpanded) },
                        modifier = Modifier.menuAnchor().fillMaxWidth()
                    )
                    ExposedDropdownMenu(
                        expanded = cbDropdownExpanded,
                        onDismissRequest = { cbDropdownExpanded = false }
                    ) {
                        cardBackOptions.forEach { option ->
                            DropdownMenuItem(
                                text = { Text(option) },
                                onClick = {
                                    selectedCardBack = option
                                    cbDropdownExpanded = false
                                }
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val isCustomBg = selectedBackground !in listOf("Green Felt", "Desert Felt")
                    val feltColor = when (selectedBackground) {
                        "Green Felt" -> FeltColorType.FeltGreen
                        "Desert Felt" -> FeltColorType.Desert
                        else -> FeltColorType.FeltGreen
                    }
                    val customBgName = if (isCustomBg) selectedBackground else null
                    
                    appContainer.themeManager.addTheme(
                        SoliBeeTheme(
                            name = name.ifBlank { "My Theme" },
                            cardBackTheme = selectedCardBack,
                            feltColor = feltColor,
                            customBackgroundName = customBgName
                        )
                    )
                    onDismiss()
                }
            ) {
                Text("Create")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun ThemeTile(theme: SoliBeeTheme, isActive: Boolean, onSelect: () -> Unit) {
    // Implementing checkpoint 4.12-4.14: fixed size and explicit clickable hit region
    Box {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .width(100.dp)
                .clickable(onClick = onSelect)
        ) {
            Box(
                modifier = Modifier
                    .size(100.dp, 140.dp)
                    .background(if (isActive) Color.Yellow.copy(alpha = 0.3f) else Color.Transparent)
            ) {
                // Mini preview of the theme
                CompositionLocalProvider(LocalSoliBeeTheme provides theme) {
                    AppBackground(modifier = Modifier.fillMaxSize())
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text(theme.name, style = MaterialTheme.typography.bodySmall)
        }
    }
}
