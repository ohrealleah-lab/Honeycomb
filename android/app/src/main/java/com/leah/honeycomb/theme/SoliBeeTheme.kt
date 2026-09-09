package com.leah.honeycomb.theme

import androidx.compose.runtime.Immutable
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class CustomCardColorGroup(
    val isEnabled: Boolean = false,
    val bgRed: Double = 1.0,
    val bgGreen: Double = 1.0,
    val bgBlue: Double = 1.0,
    val bgAlpha: Double = 1.0,
    val outlineRed: Double = 0.0,
    val outlineGreen: Double = 0.0,
    val outlineBlue: Double = 0.0,
    val outlineAlpha: Double = 0.85,
    val blackSuitRed: Double = 0.0,
    val blackSuitGreen: Double = 0.0,
    val blackSuitBlue: Double = 0.0,
    val blackSuitAlpha: Double = 1.0,
    val redSuitRed: Double = 0.8,
    val redSuitGreen: Double = 0.1,
    val redSuitBlue: Double = 0.1,
    val redSuitAlpha: Double = 1.0,
    val shadowRed: Double = 0.0,
    val shadowGreen: Double = 0.0,
    val shadowBlue: Double = 0.0,
    val shadowAlpha: Double = 0.15
)

@Serializable
data class CustomFaceArt(
    val slot: String,
    val relativePath: String,
    val scale: Double = 1.0,
    val offsetXFraction: Double = 0.0,
    val offsetYFraction: Double = 0.0
)

@Serializable
enum class FeltColorType {
    FeltGreen, Crimson, RoyalBlue, Charcoal, Desert, Custom
}

@Immutable
@Serializable
data class SoliBeeTheme(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val cardBackTheme: String,
    val feltColor: FeltColorType,
    // null means "no custom color chosen yet" — distinct from a genuinely black (0,0,0)
    // custom color, which an all-zero-defaults sentinel couldn't represent.
    val customFeltRed: Double? = null,
    val customFeltGreen: Double? = null,
    val customFeltBlue: Double? = null,
    val faceArts: List<CustomFaceArt> = emptyList(),
    val customCardColors: CustomCardColorGroup = CustomCardColorGroup(),
    val customBackgroundName: String? = null
)
