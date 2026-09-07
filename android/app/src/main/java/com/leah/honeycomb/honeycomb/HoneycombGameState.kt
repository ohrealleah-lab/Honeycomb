package com.leah.honeycomb.honeycomb

enum class HoneycombGameState {
    Setup,
    Playing,
    GameOver,
    SuddenDeath
}

enum class HoneycombMatchOutcome {
    None,
    Win,
    Loss,
    Draw,
    SuddenDeathPending
}
