package com.leah.honeycomb.theme

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import coil.compose.AsyncImage
import com.leah.honeycomb.LocalAppContainer
import java.io.File

@Composable
fun AppBackground(modifier: Modifier = Modifier) {
    val theme = LocalSoliBeeTheme.current
    val context = LocalContext.current
    val appContainer = LocalAppContainer.current

    val bgColor = when (theme.feltColor) {
        FeltColorType.FeltGreen -> Color(0xFF1E5631)
        FeltColorType.Desert -> Color(0xFFD4B886)
        FeltColorType.Custom -> Color(
            theme.customFeltRed.toFloat(),
            theme.customFeltGreen.toFloat(),
            theme.customFeltBlue.toFloat()
        )
    }

    Box(modifier = modifier.fillMaxSize().background(bgColor)) {
        val customBgName = theme.customBackgroundName
        if (customBgName != null) {
            val backgrounds = appContainer.customBackgroundManager.backgrounds.value
            val bg = backgrounds.find { it.name == customBgName }
            if (bg != null) {
                val file = File(File(context.filesDir, "Backgrounds"), bg.relativePath)
                if (file.exists()) {
                    AsyncImage(
                        model = file,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize().graphicsLayer {
                            scaleX = bg.scale.toFloat()
                            scaleY = bg.scale.toFloat()
                            translationX = bg.offsetX.toFloat()
                            translationY = bg.offsetY.toFloat()
                        },
                        contentScale = ContentScale.Crop
                    )
                }
            }
        }
    }
}
