package com.leah.honeycomb.theme

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class CustomCardColorGroup(
    var isEnabled: Boolean = false,
    var bgRed: Double = 1.0,
    var bgGreen: Double = 1.0,
    var bgBlue: Double = 1.0,
    var bgAlpha: Double = 1.0,
    var outlineRed: Double = 0.0,
    var outlineGreen: Double = 0.0,
    var outlineBlue: Double = 0.0,
    var outlineAlpha: Double = 0.85,
    var blackSuitRed: Double = 0.0,
    var blackSuitGreen: Double = 0.0,
    var blackSuitBlue: Double = 0.0,
    var blackSuitAlpha: Double = 1.0,
    var redSuitRed: Double = 0.8,
    var redSuitGreen: Double = 0.1,
    var redSuitBlue: Double = 0.1,
    var redSuitAlpha: Double = 1.0,
    var shadowRed: Double = 0.0,
    var shadowGreen: Double = 0.0,
    var shadowBlue: Double = 0.0,
    var shadowAlpha: Double = 0.15
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

@Serializable
data class SoliBeeTheme(
    val id: String = UUID.randomUUID().toString(),
    var name: String,
    var cardBackTheme: String,
    var feltColor: FeltColorType,
    // null means "no custom color chosen yet" — distinct from a genuinely black (0,0,0)
    // custom color, which an all-zero-defaults sentinel couldn't represent.
    var customFeltRed: Double? = null,
    var customFeltGreen: Double? = null,
    var customFeltBlue: Double? = null,
    var faceArts: MutableList<CustomFaceArt> = mutableListOf(),
    var customCardColors: CustomCardColorGroup = CustomCardColorGroup(),
    var customBackgroundName: String? = null
)
