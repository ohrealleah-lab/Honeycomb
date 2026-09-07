package com.leah.honeycomb.theme

import androidx.compose.runtime.compositionLocalOf

val LocalSoliBeeTheme = compositionLocalOf<SoliBeeTheme> {
    ThemeManager.defaultThemes.first()
}
