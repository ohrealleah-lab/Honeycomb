package com.leah.honeycomb.theme

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.leah.honeycomb.LocalAppContainer
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomArtImportScreen(onBack: () -> Unit) {
    val appContainer = LocalAppContainer.current
    val coroutineScope = rememberCoroutineScope()
    
    var selectedType by remember { mutableStateOf("Background") }
    var name by remember { mutableStateOf("") }
    var selectedUri by remember { mutableStateOf<Uri?>(null) }
    
    var showDropdown by remember { mutableStateOf(false) }
    val types = listOf("Background", "Card Back", "Face Card")
    
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
                title = { Text("Import Custom Art") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
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
                    value = selectedType,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Art Type") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = showDropdown) },
                    modifier = Modifier.menuAnchor().fillMaxWidth()
                )
                ExposedDropdownMenu(
                    expanded = showDropdown,
                    onDismissRequest = { showDropdown = false }
                ) {
                    types.forEach { type ->
                        DropdownMenuItem(
                            text = { Text(type) },
                            onClick = {
                                selectedType = type
                                showDropdown = false
                            }
                        )
                    }
                }
            }

            if (selectedType != "Face Card") {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Name") },
                    modifier = Modifier.fillMaxWidth()
                )
            }

            Button(
                onClick = { launcher.launch("image/*") },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(if (selectedUri == null) "Select Image" else "Image Selected")
            }

            Spacer(modifier = Modifier.weight(1f))

            Button(
                onClick = {
                    val uri = selectedUri
                    if (uri == null) {
                        snackbarMessage = "Please select an image first."
                        return@Button
                    }
                    if (selectedType != "Face Card" && name.isBlank()) {
                        snackbarMessage = "Please enter a name."
                        return@Button
                    }

                    coroutineScope.launch {
                        val result = when (selectedType) {
                            "Background" -> appContainer.customBackgroundManager.addBackground(uri, name)
                            "Card Back" -> appContainer.customCardBackManager.addCardBack(uri, name)
                            "Face Card" -> appContainer.customFaceCardArtManager.addFaceArt(uri).map { }
                            else -> Result.failure(Exception("Unknown type"))
                        }

                        if (result.isSuccess) {
                            snackbarMessage = "Import successful!"
                            name = ""
                            selectedUri = null
                        } else {
                            snackbarMessage = "Error: ${result.exceptionOrNull()?.message}"
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = selectedUri != null && (selectedType == "Face Card" || name.isNotBlank())
            ) {
                Text("Save")
            }
        }
    }
}
