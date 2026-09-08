package com.leah.honeycomb

sealed class AppRoute(val route: String) {
    object About : AppRoute("about")
    object Themes : AppRoute("themes")
    object CustomArtImport : AppRoute("custom_art_import")
    object SharedOptions : AppRoute("shared_options")

    sealed class Klondike(route: String) : AppRoute(route) {
        object Board : Klondike("klondike")
        object Options : Klondike("klondike_options")
        object Stats : Klondike("klondike_stats")
    }

    sealed class Spider(route: String) : AppRoute(route) {
        object Board : Spider("spider")
        object Options : Spider("spider_options")
        object Stats : Spider("spider_stats")
    }

    sealed class Beecell(route: String) : AppRoute(route) {
        object Board : Beecell("beecell")
        object Options : Beecell("beecell_options")
        object Stats : Beecell("beecell_stats")
    }

    sealed class Blackjack(route: String) : AppRoute(route) {
        object Board : Blackjack("blackjack")
        object Options : Blackjack("blackjack_options")
        object Stats : Blackjack("blackjack_stats")
    }

    sealed class VideoPoker(route: String) : AppRoute(route) {
        object Board : VideoPoker("videopoker")
        object Options : VideoPoker("videopoker_options")
        object Stats : VideoPoker("videopoker_stats")
    }

    sealed class Honeycomb(route: String) : AppRoute(route) {
        object Board : Honeycomb("honeycomb")
        object Options : Honeycomb("honeycomb_options")
        object Stats : Honeycomb("honeycomb_stats")
        object Decks : Honeycomb("honeycomb_decks")
        object Rules : Honeycomb("honeycomb_rules")
    }
}
