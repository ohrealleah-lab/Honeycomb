package com.leah.honeycomb.honeycomb

import kotlinx.serialization.Serializable

@Serializable
enum class HoneycombGameState {
    Setup,
    Playing,
    GameOver,
    SuddenDeath
}

@Serializable
enum class HoneycombMatchOutcome {
    None,
    Win,
    Loss,
    Draw,
    SuddenDeathPending
}
