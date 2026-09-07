package com.leah.honeycomb

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.leah.honeycomb.theme.LocalSoliBeeTheme
import java.io.File
import androidx.compose.ui.platform.LocalContext

object CardDimensions {
    val width = 114.dp
    val height = 160.dp
}


data class SuitPosition(val x: Int, val y: Int, val isUpsideDown: Boolean)

private val suitPositions = mapOf(
    2 to listOf(SuitPosition(0, -42, false), SuitPosition(0, 42, true)),
    3 to listOf(SuitPosition(0, -42, false), SuitPosition(0, 0, false), SuitPosition(0, 42, true)),
    4 to listOf(SuitPosition(-26, -42, false), SuitPosition(26, -42, false), SuitPosition(-26, 42, true), SuitPosition(26, 42, true)),
    5 to listOf(SuitPosition(-26, -42, false), SuitPosition(26, -42, false), SuitPosition(0, 0, false), SuitPosition(-26, 42, true), SuitPosition(26, 42, true)),
    6 to listOf(SuitPosition(-26, -42, false), SuitPosition(26, -42, false), SuitPosition(-26, 0, false), SuitPosition(26, 0, false), SuitPosition(-26, 42, true), SuitPosition(26, 42, true)),
    7 to listOf(SuitPosition(-26, -42, false), SuitPosition(26, -42, false), SuitPosition(-26, 0, false), SuitPosition(26, 0, false), SuitPosition(-26, 42, true), SuitPosition(26, 42, true), SuitPosition(0, -21, false)),
    8 to listOf(SuitPosition(-26, -42, false), SuitPosition(26, -42, false), SuitPosition(-26, 0, false), SuitPosition(26, 0, false), SuitPosition(-26, 42, true), SuitPosition(26, 42, true), SuitPosition(0, -21, false), SuitPosition(0, 21, true)),
    9 to listOf(SuitPosition(-26, -42, false), SuitPosition(26, -42, false), SuitPosition(-26, -14, false), SuitPosition(26, -14, false), SuitPosition(-26, 14, true), SuitPosition(26, 14, true), SuitPosition(-26, 42, true), SuitPosition(26, 42, true), SuitPosition(0, 0, false)),
    10 to listOf(SuitPosition(-26, -42, false), SuitPosition(26, -42, false), SuitPosition(-26, -14, false), SuitPosition(26, -14, false), SuitPosition(-26, 14, true), SuitPosition(26, 14, true), SuitPosition(-26, 42, true), SuitPosition(26, 42, true), SuitPosition(0, -27, false), SuitPosition(0, 27, true))
)

@Composable
fun CardView(
    card: Card,
    modifier: Modifier = Modifier,
    isAnimated: Boolean = false,
    isFocused: Boolean = false,
    isSelected: Boolean = false,
    pointPopupText: String? = null
) {
    var flipTarget by remember { mutableFloatStateOf(if (card.faceUp) 0f else 180f) }
    val flipDegrees by animateFloatAsState(
        targetValue = flipTarget,
        animationSpec = tween(durationMillis = 400, easing = LinearOutSlowInEasing)
    )

    LaunchedEffect(card.faceUp) {
        flipTarget = if (card.faceUp) 0f else 180f
    }
    val isPastFlipMidpoint = flipDegrees > 90f
    val theme = LocalSoliBeeTheme.current
    
    val outlineColor = if (theme.customCardColors.isEnabled) 
        Color(theme.customCardColors.outlineRed.toFloat(), theme.customCardColors.outlineGreen.toFloat(), theme.customCardColors.outlineBlue.toFloat(), theme.customCardColors.outlineAlpha.toFloat())
    else Color.Black.copy(alpha = 0.85f)
    
    val cardBackgroundColor = if (theme.customCardColors.isEnabled)
        Color(theme.customCardColors.bgRed.toFloat(), theme.customCardColors.bgGreen.toFloat(), theme.customCardColors.bgBlue.toFloat(), theme.customCardColors.bgAlpha.toFloat())
    else Color.White
    
    val shadowColor = if (theme.customCardColors.isEnabled)
        Color(theme.customCardColors.shadowRed.toFloat(), theme.customCardColors.shadowGreen.toFloat(), theme.customCardColors.shadowBlue.toFloat(), theme.customCardColors.shadowAlpha.toFloat())
    else Color.Black.copy(alpha = 0.15f)
    
    val suitColor = if (theme.customCardColors.isEnabled) {
        if (card.isRed) Color(theme.customCardColors.redSuitRed.toFloat(), theme.customCardColors.redSuitGreen.toFloat(), theme.customCardColors.redSuitBlue.toFloat(), theme.customCardColors.redSuitAlpha.toFloat())
        else Color(theme.customCardColors.blackSuitRed.toFloat(), theme.customCardColors.blackSuitGreen.toFloat(), theme.customCardColors.blackSuitBlue.toFloat(), theme.customCardColors.blackSuitAlpha.toFloat())
    } else {
        if (card.isRed) Color(0.8f, 0.1f, 0.1f) else Color(0.1f, 0.1f, 0.1f)
    }
    
    val cornerRadius = 10.dp

    // The inner Box below deliberately lays itself out at a fixed CardDimensions size
    // (114x160dp) via requiredSize, then visually scales down to fit whatever size this
    // CardView was actually given (via the graphicsLayer scaleX/scaleY below). A
    // requiredSize child larger than its parent does NOT get placed at the parent's
    // TopStart origin by default despite BoxWithConstraints' own contentAlignment saying
    // so — Box centers an over-sized child regardless, so the visible (post-scale) card
    // was rendering centered on, and bleeding symmetrically outside, its actual slot
    // (e.g. a Klondike tableau card ~38x54dp) instead of filling it — explicit
    // Modifier.align(Alignment.TopStart) on the child itself is what actually forces the
    // TopStart placement scale is anchored from.
    BoxWithConstraints(modifier = modifier, contentAlignment = Alignment.TopStart) {
        val scale = maxWidth / CardDimensions.width

        Box(
            modifier = Modifier
                .wrapContentSize(align = Alignment.TopStart, unbounded = true)
                .size(CardDimensions.width, CardDimensions.height)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                    transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0f, 0f)
                    shadowElevation = 1.5.dp.toPx()
                    shape = RoundedCornerShape(cornerRadius)
                    clip = false
                    ambientShadowColor = shadowColor
                    spotShadowColor = shadowColor
                }
                .clip(RoundedCornerShape(cornerRadius))
                .background(cardBackgroundColor)
                .border(0.75.dp, outlineColor, RoundedCornerShape(cornerRadius))
        ) {
        if (card.faceUp) {
            CardFrontView(card = card, suitColor = suitColor)
        } else {
            CardBackView(theme.cardBackTheme, isAnimated = isAnimated)
        }
        
        if (pointPopupText != null) {
            Text(
                text = pointPopupText,
                color = suitColor,
                fontSize = 24.sp,
                fontWeight = FontWeight.Black,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 10.dp, end = 10.dp)
                    .shadow(3.dp, spotColor = Color.White)
                    .shadow(6.dp, spotColor = suitColor.copy(alpha = 0.9f))
            )
        }
    }
}
}

@Composable
fun CardFrontView(card: Card, suitColor: Color) {
    Box(modifier = Modifier.fillMaxSize()) {
        CardCenterSuitView(
            card = card,
            suitColor = suitColor,
            modifier = Modifier.align(Alignment.Center)
        )

        // Top Left Index
        Row(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(start = 8.dp, top = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(1.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(text = card.rankString, color = suitColor, fontSize = 17.sp, fontWeight = FontWeight.Bold)
            Text(text = card.suit.symbol, color = suitColor, fontSize = 14.sp)
        }

        // Bottom Right Index
        Row(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 8.dp, bottom = 8.dp)
                .graphicsLayer { rotationZ = 180f },
            horizontalArrangement = Arrangement.spacedBy(1.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(text = card.rankString, color = suitColor, fontSize = 17.sp, fontWeight = FontWeight.Bold)
            Text(text = card.suit.symbol, color = suitColor, fontSize = 14.sp)
        }
    }
}

@Composable
fun CardCenterSuitView(card: Card, suitColor: Color, modifier: Modifier = Modifier) {
    val theme = LocalSoliBeeTheme.current
    val context = LocalContext.current
    
    // Check if there is custom face art for this card slot
    val slotName = "${card.rankString}${card.suit.symbol}" // simplistic slot matching
    val customArt = theme.faceArts.find { it.slot == slotName || it.slot == card.rankString }
    
    if (customArt != null) {
        val file = File(File(context.filesDir, "FaceArt"), customArt.relativePath)
        if (file.exists()) {
            AsyncImage(
                model = file,
                contentDescription = null,
                modifier = modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        scaleX = customArt.scale.toFloat()
                        scaleY = customArt.scale.toFloat()
                        translationX = (customArt.offsetXFraction * CardDimensions.width.toPx()).toFloat()
                        translationY = (customArt.offsetYFraction * CardDimensions.height.toPx()).toFloat()
                    },
                contentScale = ContentScale.Fit
            )
            return
        }
    }

    // Default Face Rendering
    if (card.rank == 1) {
        Text(text = card.suit.symbol, color = suitColor, fontSize = 52.sp, modifier = modifier)
    } else if (card.isFaceCard) {
        // Draw the default face art image instead of just text
        val drawableId = when (card.rank) {
            11 -> if (card.isRed) R.drawable.face_red_j else R.drawable.face_j
            12 -> if (card.isRed) R.drawable.face_red_q else R.drawable.face_q
            13 -> if (card.isRed) R.drawable.face_red_k else R.drawable.face_k
            else -> 0
        }
        if (drawableId != 0) {
            Image(
                painter = painterResource(id = drawableId),
                contentDescription = null,
                modifier = modifier.fillMaxSize(0.55f),
                contentScale = ContentScale.Fit
            )
        } else {
            Text(text = card.rankString, color = suitColor, fontSize = 48.sp, modifier = modifier)
        }
    } else {
        Box(modifier = modifier.size(86.dp, 138.dp)) {
            val positions = suitPositions[card.rank] ?: emptyList()
            for (pos in positions) {
                Text(
                    text = card.suit.symbol,
                    color = suitColor,
                    fontSize = 20.sp, // Reduced to match iOS visual weight
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .offset(x = pos.x.dp, y = pos.y.dp)
                        .graphicsLayer { if (pos.isUpsideDown) rotationZ = 180f }
                )
            }
        }
    }
}

@Composable
fun CardBackView(themeName: String, isAnimated: Boolean) {
    val context = LocalContext.current
    val bundledId = when (themeName) {
        "Moogle" -> R.drawable.moogle
        "Dingwall" -> R.drawable.dingwall
        "Vulpera" -> R.drawable.priest
        "Forest" -> R.drawable.forest
        "On The Water" -> R.drawable.on_the_water
        "Pareidolic" -> R.drawable.pareidolic
        "Pareidolic 2" -> R.drawable.pareidolic_2
        "Red Sky" -> R.drawable.red_sky
        "Sunset" -> R.drawable.sunset
        "Solibee" -> R.drawable.solibee
        else -> 0
    }
    
    if (bundledId != 0) {
        Image(
            painter = painterResource(id = bundledId),
            contentDescription = null,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop
        )
    } else {
        // Assume it's a custom card back
        val appContainer = LocalAppContainer.current
        val customBacks = appContainer.customCardBackManager.cardBacks.value
        val customBg = customBacks.find { it.name == themeName }
        if (customBg != null) {
            val file = File(File(context.filesDir, "CardBacks"), customBg.relativePath)
            if (file.exists()) {
                AsyncImage(
                    model = file,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize()
                        .graphicsLayer {
                            scaleX = customBg.scale.toFloat()
                            scaleY = customBg.scale.toFloat()
                            translationX = (customBg.offsetXFraction * CardDimensions.width.toPx()).toFloat()
                            translationY = (customBg.offsetYFraction * CardDimensions.height.toPx()).toFloat()
                        },
                    contentScale = ContentScale.Crop
                )
            } else {
                // Fallback to blue box
                FallbackCardBack()
            }
        } else {
            FallbackCardBack()
        }
    }
}

@Composable
private fun FallbackCardBack() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0.1f, 0.3f, 0.6f).copy(alpha = 0.3f)),
        contentAlignment = Alignment.Center
    ) {
        Box(modifier = Modifier.background(Color.Blue, RoundedCornerShape(percent = 50)))
    }
}
