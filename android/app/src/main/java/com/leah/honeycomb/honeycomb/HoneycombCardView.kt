package com.leah.honeycomb.honeycomb

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.leah.honeycomb.CardBackView
import com.leah.honeycomb.rememberCardColors
import com.leah.honeycomb.CardDimensions
import com.leah.honeycomb.theme.LocalSoliBeeTheme
import kotlinx.coroutines.delay

@Composable
fun HoneycombCardView(
    card: HoneycombCard,
    modifier: Modifier = Modifier,
    isFlipped: Boolean = false,
    useOwnershipColoring: Boolean = true,
    stealHighlight: Boolean = false,
    highlightedStatIndices: Set<Int> = emptySet(),
    isCaptureAttacker: Boolean = false
) {
    val theme = LocalSoliBeeTheme.current

    var displayedOwner by remember { mutableStateOf(card.owner) }
    var displayedIsFaceDown by remember { mutableStateOf(card.isFaceDown) }
    var isPastFlipMidpoint by remember { mutableStateOf(false) }

    var flipTarget by remember { mutableFloatStateOf(0f) }
    val flipDegrees by animateFloatAsState(
        targetValue = flipTarget,
        animationSpec = tween(durationMillis = 400, easing = LinearOutSlowInEasing)
    )

    LaunchedEffect(card.owner) {
        if (displayedOwner != card.owner) {
            flipTarget += 180f
            delay(200)
            displayedOwner = card.owner
            isPastFlipMidpoint = !isPastFlipMidpoint
        }
    }

    LaunchedEffect(card.isFaceDown) {
        if (displayedIsFaceDown != card.isFaceDown) {
            flipTarget += 180f
            delay(200)
            displayedIsFaceDown = card.isFaceDown
            isPastFlipMidpoint = !isPastFlipMidpoint
        }
    }

    var ruleTriggerGeneration by remember { mutableIntStateOf(0) }
    LaunchedEffect(isCaptureAttacker) {
        if (isCaptureAttacker) {
            ruleTriggerGeneration++
        }
    }

    var ruleTriggerScale by remember { mutableFloatStateOf(1.0f) }
    LaunchedEffect(ruleTriggerGeneration) {
        if (ruleTriggerGeneration > 0) {
            ruleTriggerScale = 1.2f
            delay(1000)
            ruleTriggerScale = 1.0f
        }
    }

    val animatedRuleTriggerScale by animateFloatAsState(
        targetValue = ruleTriggerScale,
        animationSpec = tween(durationMillis = 200, easing = FastOutSlowInEasing)
    )

    var statPulseScale by remember { mutableFloatStateOf(1.0f) }
    var modifierGlowOpacity by remember { mutableFloatStateOf(0.0f) }
    // Hoisted to always-composed (rather than declared inside the badge's conditional
    // block below) so its internal Animatable persists across the badge appearing —
    // an animateFloatAsState created fresh at the moment a modifier badge first shows
    // up has no prior value to animate from and would snap straight to target instead
    // of animating in.
    val animatedModifierGlowOpacity by animateFloatAsState(
        targetValue = modifierGlowOpacity,
        animationSpec = tween(durationMillis = 300)
    )

    LaunchedEffect(card.modifier) {
        statPulseScale = 1.4f
        if (card.modifier != 0) {
            modifierGlowOpacity = 1.0f
        } else {
            modifierGlowOpacity = 0.0f
        }
        
        delay(150)
        statPulseScale = 1.0f
        
        if (card.modifier != 0) {
            delay(850)
            modifierGlowOpacity = 0.0f
        }
    }

    val animatedStatPulseScale by animateFloatAsState(
        targetValue = statPulseScale,
        animationSpec = tween(durationMillis = 150)
    )

    var pointHighlightPulseScale by remember { mutableFloatStateOf(1.0f) }
    LaunchedEffect(highlightedStatIndices) {
        if (highlightedStatIndices.isNotEmpty()) {
            pointHighlightPulseScale = 1.4f
            delay(150)
            pointHighlightPulseScale = 1.0f
        }
    }
    val animatedPointHighlightPulse by animateFloatAsState(
        targetValue = pointHighlightPulseScale,
        animationSpec = tween(durationMillis = 150)
    )

    val isRed = if (useOwnershipColoring) {
        displayedOwner == CardOwner.Opponent
    } else {
        card.data.suit == "H" || card.data.suit == "D"
    }

    val colors = rememberCardColors(theme, isRed)
    val currentColor = colors.suitColor
    val outlineColor = colors.outlineColor
    val cardBackgroundColor = colors.backgroundColor
    val shadowColor = colors.shadowColor

    BoxWithConstraints(
        modifier = modifier
            .graphicsLayer {
                scaleX = animatedRuleTriggerScale
                scaleY = animatedRuleTriggerScale
            }
    ) {
        val sizeWidth = maxWidth.value
        val numberFontSize = (sizeWidth * (24.0f / 128.0f)).sp
        val numberPadding = (sizeWidth * (13.0f / 128.0f)).dp
        val cornerRadius = 10.dp

        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    scaleX = if (isPastFlipMidpoint) -1f else 1f
                    rotationY = flipDegrees
                    cameraDistance = 12f * density
                }
                .shadow(1.5.dp, RoundedCornerShape(cornerRadius), ambientColor = shadowColor, spotColor = shadowColor)
                .clip(RoundedCornerShape(cornerRadius))
                .background(cardBackgroundColor)
                .border(
                    width = if (stealHighlight) 14.dp else 0.75.dp,
                    color = if (stealHighlight) Color.Yellow else outlineColor,
                    shape = RoundedCornerShape(cornerRadius)
                )
        ) {
            if (isFlipped || displayedIsFaceDown) {
                CardBackView(themeName = theme.cardBackTheme, isAnimated = false)
            } else {
                Text(
                    text = suitSymbol(card.data.suit),
                    color = currentColor,
                    fontSize = (sizeWidth * 0.5f).sp,
                    modifier = Modifier.align(Alignment.Center)
                )

                StarsView(
                    cardData = card.data,
                    sizeWidth = sizeWidth,
                    modifier = Modifier.align(Alignment.Center)
                )

                // Top (0)
                StatText(
                    stat = card.data.stats[0],
                    isHighlighted = highlightedStatIndices.contains(0),
                    animatedStatPulseScale = animatedStatPulseScale,
                    animatedPointHighlightPulse = animatedPointHighlightPulse,
                    currentColor = currentColor,
                    fontSize = numberFontSize,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(top = numberPadding)
                )

                // Right (1)
                StatText(
                    stat = card.data.stats[1],
                    isHighlighted = highlightedStatIndices.contains(1),
                    animatedStatPulseScale = animatedStatPulseScale,
                    animatedPointHighlightPulse = animatedPointHighlightPulse,
                    currentColor = currentColor,
                    fontSize = numberFontSize,
                    modifier = Modifier
                        .align(Alignment.CenterEnd)
                        .padding(end = numberPadding)
                )

                // Bottom (2)
                StatText(
                    stat = card.data.stats[2],
                    isHighlighted = highlightedStatIndices.contains(2),
                    animatedStatPulseScale = animatedStatPulseScale,
                    animatedPointHighlightPulse = animatedPointHighlightPulse,
                    currentColor = currentColor,
                    fontSize = numberFontSize,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = numberPadding)
                )

                // Left (3)
                StatText(
                    stat = card.data.stats[3],
                    isHighlighted = highlightedStatIndices.contains(3),
                    animatedStatPulseScale = animatedStatPulseScale,
                    animatedPointHighlightPulse = animatedPointHighlightPulse,
                    currentColor = currentColor,
                    fontSize = numberFontSize,
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .padding(start = numberPadding)
                )
            }
        }
        
        // Ascension/Descension badge
        if (!isFlipped && !displayedIsFaceDown && card.modifier != 0) {
            val modText = if (card.modifier > 0) "+${card.modifier}" else "${card.modifier}"
            val badgeFontSize = (sizeWidth * (24.0f / 128.0f)).sp

            Text(
                text = modText,
                color = currentColor,
                fontSize = badgeFontSize,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.Black,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = (maxHeight.value * (10.0f / 181.0f)).dp, end = (sizeWidth * (10.0f / 128.0f)).dp)
                    .shadow(
                        elevation = (sizeWidth * (3.0f / 128.0f)).dp,
                        spotColor = Color.White.copy(alpha = animatedModifierGlowOpacity)
                    )
                    .shadow(
                        elevation = (sizeWidth * (6.0f / 128.0f)).dp,
                        spotColor = currentColor.copy(alpha = 0.9f * animatedModifierGlowOpacity)
                    )
            )
        }
    }
}

@Composable
fun StatText(
    stat: Int,
    isHighlighted: Boolean,
    animatedStatPulseScale: Float,
    animatedPointHighlightPulse: Float,
    currentColor: Color,
    fontSize: androidx.compose.ui.unit.TextUnit,
    modifier: Modifier
) {
    val text = if (stat >= 10) "A" else stat.toString()
    val color = if (isHighlighted) Color.Yellow else currentColor
    val scale = if (isHighlighted) animatedStatPulseScale * animatedPointHighlightPulse else animatedStatPulseScale

    Text(
        text = text,
        color = color,
        fontSize = fontSize,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        modifier = modifier.graphicsLayer {
            scaleX = scale
            scaleY = scale
        }
    )
}

@Composable
fun StarsView(cardData: HoneycombCardData, sizeWidth: Float, modifier: Modifier = Modifier) {
    val count = cardData.stars
    val isHeartOrDiamond = cardData.suit == "H" || cardData.suit == "D"
    val starFontSize = (sizeWidth * 0.06f).sp

    @Composable
    fun StarText() {
        Text(
            text = "★",
            color = Color.White,
            fontSize = starFontSize,
            modifier = Modifier.shadow(1.dp, ambientColor = Color.Black.copy(alpha = 0.35f), spotColor = Color.Black.copy(alpha = 0.35f))
        )
    }

    Box(modifier = modifier) {
        when (count) {
            4 -> {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) { StarText(); StarText() }
                    Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) { StarText(); StarText() }
                }
            }
            5 -> {
                Column(verticalArrangement = Arrangement.spacedBy(1.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    if (isHeartOrDiamond) {
                        Row(horizontalArrangement = Arrangement.spacedBy(1.dp)) { StarText(); StarText(); StarText() }
                        Row(horizontalArrangement = Arrangement.spacedBy(1.dp)) { StarText(); StarText() }
                    } else {
                        Row(horizontalArrangement = Arrangement.spacedBy(1.dp)) { StarText(); StarText() }
                        Row(horizontalArrangement = Arrangement.spacedBy(1.dp)) { StarText(); StarText(); StarText() }
                    }
                }
            }
            else -> {
                Row(horizontalArrangement = Arrangement.spacedBy(1.dp)) {
                    for (i in 0 until count) {
                        StarText()
                    }
                }
            }
        }
    }
}

fun suitSymbol(suit: String): String = when (suit) {
    "S" -> "♠\uFE0E"
    "H" -> "♥\uFE0E"
    "D" -> "♦\uFE0E"
    "C" -> "♣\uFE0E"
    else -> "?"
}
