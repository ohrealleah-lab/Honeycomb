package com.leah.honeycomb

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll

data class GameInfo(
    val route: String,
    val title: String,
    val description: String,
    val iconResId: Int? = null,
    val textIcon: String? = null
)

val gamesList = listOf(
    GameInfo(
        route = AppRoute.Klondike.Board.route,
        title = "Klondike Solibee",
        description = "Classic single-deck solitaire with Draw 1, Draw 3, and Vegas scoring options.",
        textIcon = "♠"
    ),
    GameInfo(
        route = AppRoute.Beecell.Board.route,
        title = "Beecell",
        description = "The ultimate strategic solitaire game—99.9% of all deals are solvable.",
        textIcon = "♥"
    ),
    GameInfo(
        route = AppRoute.Spider.Board.route,
        title = "Spider Solibee",
        description = "A deep, two-deck game of sequence building across 1, 2, or 4 suits.",
        textIcon = "♣"
    ),
    GameInfo(
        route = AppRoute.VideoPoker.Board.route,
        title = "Video Poker",
        description = "Classic casino poker with Jacks or Better, Deuces Wild, and Bonus Poker pay tables.",
        textIcon = "♦"
    ),
    GameInfo(
        route = AppRoute.Blackjack.Board.route,
        title = "Video Blackjack",
        description = "Beat the dealer by getting closer to 21 without going over.",
        textIcon = "21"
    ),
    GameInfo(
        route = AppRoute.Honeycomb.Board.route,
        title = "Honeycomb",
        description = "A tactical 3x3 grid card battle inspired by Triple Triad.",
        textIcon = "⬢"
    )
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GameSelectionSheet(
    currentRoute: String,
    onNavigate: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = Color.White,
        shape = RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp),
        dragHandle = { BottomSheetDefaults.DragHandle() }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp)
                .verticalScroll(rememberScrollState())
        ) {
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Game Selection",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.Black
                )
                Button(
                    onClick = onDismiss,
                    modifier = Modifier.align(Alignment.CenterEnd),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF007AFF)),
                    contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp)
                ) {
                    Text("Done", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.White)
                }
            }
            
            Spacer(modifier = Modifier.height(24.dp))
            Text(
                text = "Game",
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color.Black
            )
            Spacer(modifier = Modifier.height(16.dp))
            
            gamesList.forEach { game ->
                GameSelectionRow(
                    game = game,
                    isSelected = game.route == currentRoute,
                    onClick = {
                        if (game.route != currentRoute) {
                            onNavigate(game.route)
                        }
                        onDismiss()
                    }
                )
                Spacer(modifier = Modifier.height(12.dp))
            }
        }
    }
}

@Composable
fun GameSelectionRow(game: GameInfo, isSelected: Boolean, onClick: () -> Unit) {
    val bgColor = if (isSelected) Color(0xFFDCEFFF) else Color(0xFFF2F2F7)
    val contentColor = if (isSelected) Color(0xFF007AFF) else Color(0xFF8E8E93)
    val titleColor = Color.Black
    val descColor = Color(0xFF8E8E93)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bgColor)
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier.size(32.dp),
            contentAlignment = Alignment.Center
        ) {
            if (game.textIcon == "21") {
                Box(
                    modifier = Modifier
                        .size(24.dp)
                        .background(contentColor, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "21",
                        color = Color.White,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            } else {
                Text(
                    text = game.textIcon ?: "",
                    fontSize = 28.sp,
                    color = contentColor,
                    modifier = Modifier.offset(y = (-2).dp)
                )
            }
        }
        
        Spacer(modifier = Modifier.width(16.dp))
        
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = game.title,
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold,
                color = titleColor
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = game.description,
                fontSize = 14.sp,
                color = descColor,
                lineHeight = 18.sp
            )
        }
        
        if (isSelected) {
            Spacer(modifier = Modifier.width(16.dp))
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = "Selected",
                tint = Color(0xFF007AFF),
                modifier = Modifier.size(24.dp)
            )
        }
    }
}
