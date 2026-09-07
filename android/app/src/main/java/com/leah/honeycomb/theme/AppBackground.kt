package com.leah.honeycomb.theme

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.foundation.Canvas
import androidx.compose.ui.graphics.Brush
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
fun AppBackground(modifier: Modifier = Modifier, intensity: Float = 0.45f) {
    val theme = LocalSoliBeeTheme.current
    val context = LocalContext.current
    val appContainer = LocalAppContainer.current

    val bgColor = when (theme.feltColor) {
        FeltColorType.FeltGreen -> Color(0.0f, 0.5f, 0.0f)
        FeltColorType.Crimson -> Color(0.55f, 0.05f, 0.15f)
        FeltColorType.RoyalBlue -> Color(0.1f, 0.2f, 0.5f)
        FeltColorType.Charcoal -> Color(0.18f, 0.18f, 0.18f)
        FeltColorType.Desert -> Color(0.76f, 0.59f, 0.48f)
        FeltColorType.Custom -> {
            if (theme.customFeltRed == 0.0 && theme.customFeltGreen == 0.0 && theme.customFeltBlue == 0.0) {
                Color(0.35f, 0.15f, 0.45f)
            } else {
                Color(
                    theme.customFeltRed.toFloat(),
                    theme.customFeltGreen.toFloat(),
                    theme.customFeltBlue.toFloat()
                )
            }
        }
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

    val showVignette by appContainer.themeManager.showFeltVignette.collectAsState()
    if (showVignette) {
        Canvas(modifier = modifier.fillMaxSize()) {
            val diagonal = kotlin.math.sqrt((size.width * size.width + size.height * size.height).toDouble()).toFloat()
            val maxRadius = (diagonal / 2f) * 1.05f
            val startStop = 0.35f / 1.05f
            
            drawRect(
                brush = Brush.radialGradient(
                    colorStops = arrayOf(
                        0.0f to Color.Transparent,
                        startStop to Color.Transparent,
                        1.0f to Color.Black.copy(alpha = intensity)
                    ),
                    center = center,
                    radius = maxRadius
                )
            )
        }
    }
}
