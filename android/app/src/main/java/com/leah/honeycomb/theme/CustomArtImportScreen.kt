package com.leah.honeycomb.theme

import com.leah.honeycomb.StringKey

import com.leah.honeycomb.tr

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.leah.honeycomb.LocalAppContainer
import kotlinx.coroutines.launch

// Face Card art import doesn't exist on Android — mobile screens are too small for it to
// be worth the space it takes in a card, unlike Mac's larger canvas. Only Background and
// Card Back remain, and neither takes a name anymore — custom art is identified purely by
// its generated id and picked by thumbnail, so there's no name to collide with a bundled
// asset's.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomArtImportScreen(onBack: () -> Unit) {
    val appContainer = LocalAppContainer.current
    val coroutineScope = rememberCoroutineScope()

    var selectedType by remember { mutableStateOf("Background") }
    var selectedUri by remember { mutableStateOf<Uri?>(null) }

    var showDropdown by remember { mutableStateOf(false) }
    val types = listOf("Background", "Card Back") // IDs; typeLabel() is what's shown
    val backgroundLabel = tr(StringKey.MenuSectionBackground)
    val cardBackLabel = tr(StringKey.MenuSectionCardBack)
    fun typeLabel(type: String) = if (type == "Card Back") cardBackLabel else backgroundLabel
    val selectFirstMessage = tr(StringKey.SelectImageFirstMessage)
    val importSuccessMessage = tr(StringKey.ImportSuccessfulMessage)
    val errorTitle = tr(StringKey.ErrorTitle)

    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        selectedUri = uri
    }

    var snackbarMessage by remember { mutableStateOf<String?>(null) }
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(snackbarMessage) {
        snackbarMessage?.let {
            snackbarHostState.showSnackbar(it)
            snackbarMessage = null
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(tr(StringKey.ImportCustomArtTitle)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = com.leah.honeycomb.tr(StringKey.Back))
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            ExposedDropdownMenuBox(
                expanded = showDropdown,
                onExpandedChange = { showDropdown = !showDropdown }
            ) {
                OutlinedTextField(
                    value = typeLabel(selectedType),
                    onValueChange = {},
                    readOnly = true,
                    label = { Text(tr(StringKey.ArtTypeLabel)) },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = showDropdown) },
                    modifier = Modifier.menuAnchor(MenuAnchorType.PrimaryNotEditable).fillMaxWidth()
                )
                ExposedDropdownMenu(
                    expanded = showDropdown,
                    onDismissRequest = { showDropdown = false }
                ) {
                    types.forEach { type ->
                        DropdownMenuItem(
                            text = { Text(typeLabel(type)) },
                            onClick = {
                                selectedType = type
                                showDropdown = false
                            }
                        )
                    }
                }
            }

            Button(
                onClick = { launcher.launch("image/*") },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(tr(if (selectedUri == null) StringKey.TouchChoosePhoto else StringKey.TouchChooseDifferentPhoto))
            }

            Spacer(modifier = Modifier.weight(1f))

            Button(
                onClick = {
                    val uri = selectedUri
                    if (uri == null) {
                        snackbarMessage = selectFirstMessage
                        return@Button
                    }

                    coroutineScope.launch {
                        val result = when (selectedType) {
                            "Background" -> appContainer.customBackgroundManager.addBackground(uri)
                            "Card Back" -> appContainer.customCardBackManager.addCardBack(uri)
                            else -> Result.failure(Exception("Unknown type"))
                        }

                        if (result.isSuccess) {
                            snackbarMessage = importSuccessMessage
                            selectedUri = null
                        } else {
                            snackbarMessage = "$errorTitle: ${result.exceptionOrNull()?.message}"
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = selectedUri != null
            ) {
                Text(tr(StringKey.Save))
            }
        }
    }
}
