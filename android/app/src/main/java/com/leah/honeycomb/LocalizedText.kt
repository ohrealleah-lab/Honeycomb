package com.leah.honeycomb

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue

// Composable shorthand for the current-language string — for screens that don't
// already thread a `language` value through, so UI text never has to be hard-coded
// in English. Recomposes when the app language changes.
@Composable
fun tr(key: StringKey): String {
    val language by LocalAppContainer.current.language.collectAsState()
    return Strings.get(key, language)
}

@Composable
fun trf(key: StringKey, vararg args: Any): String {
    val language by LocalAppContainer.current.language.collectAsState()
    return Strings.format(key, language, *args)
}
