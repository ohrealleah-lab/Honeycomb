import SwiftUI

// MARK: - Shared Help UI

private struct RuleSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HelpShell<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.largeTitle).bold()
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding([.top, .horizontal], 24)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content()
                }
                .padding(24)
            }
        }
        .frame(width: 520, height: 560)
    }
}

// MARK: - Klondike Guide

struct KlondikeHelpView: View {
    var body: some View {
        HelpShell(title: "Klondike Solitaire", subtitle: "Classic one- or three-card draw") {
            RuleSection(title: "Objective",
                        text: "Move all 52 cards to the four foundation piles, one per suit, built up from Ace to King.")

            RuleSection(title: "Layout",
                        text: "Seven tableau columns are dealt at the start: the first column has 1 card face-up, the second has 1 face-down and 1 face-up, and so on. The remaining cards form the stock pile in the upper left.")

            RuleSection(title: "Tableau Rules",
                        text: "Build tableau columns in descending rank and alternating color (red on black, black on red). Only Kings may be placed in an empty column. You may move a face-up card — or an entire face-up sequence — to another column.")

            RuleSection(title: "Foundation",
                        text: "Each foundation is built by suit from Ace (bottom) to King (top). Cards are moved there automatically when possible, or you can drag them manually.")

            RuleSection(title: "Stock & Waste",
                        text: "Click the stock to deal cards to the waste pile. In Draw 1 mode, one card is dealt at a time; in Draw 3 mode, three cards are dealt and only the top card of the waste is playable. When the stock is empty, click it to redeal from the waste (unlimited redeals in standard mode).")

            RuleSection(title: "Vegas Mode",
                        text: "In Vegas scoring, you start with a debt of −$52 (the cost of the deck). Each card moved to a foundation earns +$5. Redealing from the waste is not allowed — make your moves count!")

            RuleSection(title: "Keyboard Shortcuts",
                        text: "⌘N — New Game\n⌘R — Restart current deal\n⌘Z — Undo last move\n⌥⌘1 — Switch to Draw 1\n⌥⌘3 — Switch to Draw 3\n💡 Hint — press again to cycle through all available hints")
        }
    }
}

// MARK: - Beecell Guide

struct BeecellHelpView: View {
    var body: some View {
        HelpShell(title: "Freecell", subtitle: "FreeCell variant with a hive twist") {
            RuleSection(title: "Objective",
                        text: "Move all cards to the four foundation piles, built up by suit from Ace to King.")

            RuleSection(title: "Layout",
                        text: "All 52 cards are dealt face-up into eight tableau columns. Four free cells sit in the upper left, and four foundation piles sit in the upper right.")

            RuleSection(title: "Free Cells",
                        text: "A free cell can hold exactly one card at a time. Use free cells as temporary parking spots to maneuver cards around the tableau.")

            RuleSection(title: "Tableau Rules",
                        text: "Build tableau columns in descending rank and alternating color. You may move one card at a time to a free cell, a foundation, or a valid tableau position. The number of cards you can move as a group is limited by the number of empty free cells and empty columns available.")

            RuleSection(title: "Empty Columns",
                        text: "Any card or valid sequence may be placed in an empty column. Empty columns effectively act as extra free cells when calculating how many cards you can move at once.")

            RuleSection(title: "Strategy Tips",
                        text: "Nearly every deal of FreeCell is solvable — take your time and plan ahead. Avoid filling all free cells at once, as it severely limits your options. Try to expose Aces and low cards early.")

            RuleSection(title: "Keyboard Shortcuts",
                        text: "⌘N — New Game\n⌘R — Restart current deal\n⌘Z — Undo last move\n💡 Hint — press again to cycle through all available hints")
        }
    }
}

// MARK: - Spider Solibee Guide

struct SpiderHelpView: View {
    var body: some View {
        HelpShell(title: "Spider Solitaire", subtitle: "Spider Solitaire with one, two, or four suits") {
            RuleSection(title: "Objective",
                        text: "Build eight complete in-suit sequences (Ace through King) within the tableau. Completed sequences are automatically removed to a foundation.")

            RuleSection(title: "Layout",
                        text: "104 cards (two standard decks) are dealt into ten tableau columns: the first four columns receive six cards each, the remaining six receive five cards each. Only the top card of each column is face-up at the start. Five additional rows of ten cards remain in the stock.")

            RuleSection(title: "Tableau Rules",
                        text: "Cards may be stacked in descending rank regardless of suit. However, you may only move a sequence as a group if all cards in that sequence share the same suit. Building in-suit sequences is therefore much more powerful than mixed-suit stacking.")

            RuleSection(title: "Suit Modes",
                        text: "• 1 Suit — all cards are Spades. Easiest.\n• 2 Suits — cards are Spades and Hearts. Medium difficulty.\n• 4 Suits — all four suits are used. Hardest.")

            RuleSection(title: "Dealing from Stock",
                        text: "When you are stuck, click the stock to deal one card face-up onto each of the ten tableau columns. You must have at least one card in every column before dealing from the stock. There are five deals available.")

            RuleSection(title: "Empty Columns",
                        text: "Any card or valid in-suit sequence may be placed in an empty column. Empty columns are extremely valuable — use them to juggle sequences.")

            RuleSection(title: "Keyboard Shortcuts",
                        text: "⌘N — New Game\n⌘R — Restart current deal\n⌘Z — Undo last move\n⌥⌘1 — 1-Suit mode\n⌥⌘2 — 2-Suit mode\n💡 Hint — press again to cycle through all available hints")
        }
    }
}

// MARK: - Video Poker Guide

struct VideoPokerHelpView: View {
    var body: some View {
        HelpShell(title: "Video Poker", subtitle: "Jacks or Better · Deuces Wild · Bonus Poker") {
            RuleSection(title: "Objective",
                        text: "Build the best five-card poker hand. If your hand matches an entry on the pay table, you win a multiple of your bet. Higher-ranking hands pay more.")

            RuleSection(title: "How to Play",
                        text: "1. Set your bet (1–5 coins) and press Deal.\n2. Five cards are dealt face-up. Click any cards you want to keep, or use 1–5 on the keyboard.\n3. Press Draw (or Space). Unselected cards are replaced with new ones from the deck.\n4. Your final hand is evaluated against the pay table and any winnings are added to your credits.")

            RuleSection(title: "Hand Rankings (low to high)",
                        text: "Jacks or Better — a pair of Jacks, Queens, Kings, or Aces\nTwo Pair\nThree of a Kind\nStraight — five consecutive ranks, any suit\nFlush — five cards of the same suit\nFull House — three of a kind plus a pair\nFour of a Kind\nStraight Flush — five consecutive cards in the same suit\nRoyal Flush — A K Q J 10 in the same suit (top payout)")

            RuleSection(title: "Betting & Credits",
                        text: "Choose 1 to 5 coins per hand. BET MAX locks in 5 coins and immediately deals. The Royal Flush jackpot is only awarded at the maximum 5-coin bet — always bet max when you can afford it.\n\nIf your credits drop below your current bet, a Rebuy button appears to top up.")

            RuleSection(title: "Jacks or Better",
                        text: "The standard 9/6 full-pay game. The lowest qualifying hand is a pair of Jacks or better. Payouts follow the classic schedule: Full House pays 9×, Flush pays 6×.")

            RuleSection(title: "Deuces Wild",
                        text: "All four 2s are wild and can substitute for any card. Because wilds make strong hands much easier to hit, the minimum qualifying hand is raised to Three of a Kind. Special hands include Four Deuces (four 2s) and Wild Royal Flush (a Royal using at least one deuce).")

            RuleSection(title: "Bonus Poker",
                        text: "Based on Jacks or Better with enhanced payouts for four-of-a-kind hands. Four Aces pays 80×, four 2s/3s/4s pay 40×, and other quads pay the standard 25×.")

            RuleSection(title: "Keyboard Shortcuts",
                        text: "Space — Deal / Draw\n1 2 3 4 5 — Toggle hold for cards 1–5\nH — Hold all cards\nC — Clear all holds\nM — Bet Max and deal")
        }
    }
}

struct BlackjackHelpView: View {
    var body: some View {
        HelpShell(title: "Video Blackjack", subtitle: "Beat the Dealer to 21") {
            RuleSection(title: "Objective",
                        text: "Get a hand value closer to 21 than the dealer without going over. Card values: numbered cards are face value, face cards (J/Q/K) are worth 10, Aces are worth 11 or 1.")

            RuleSection(title: "How to Play",
                        text: "1. Set your bet (1–5 credits) and press Deal, or press BET MAX to bet 5 and deal immediately.\n2. You receive two cards face-up; the dealer gets one face-up and one face-down (the hole card).\n3. Choose Hit, Stand, Double Down, or Split.\n4. After you finish, the dealer reveals their hole card and draws until reaching 17 or higher.\n5. Your hand is compared to the dealer's and winnings are paid out.")

            RuleSection(title: "Actions",
                        text: "Hit — draw one more card\nStand — keep your current hand\nDouble Down — double your bet, draw exactly one card, then stand (available on your first two cards)\nSplit — if your first two cards have the same rank, split them into two separate hands each with its own bet")

            RuleSection(title: "Payouts",
                        text: "Win — pays 2× your bet (profit of 1×)\nBlackjack (Ace + 10-value card) — pays 3:2 (profit of 1.5×)\nPush (tie) — your bet is returned\nBust or Loss — bet is forfeited\n\nDealer must stand on 17 and hit on 16 or lower.")

            RuleSection(title: "Credits",
                        text: "You start each session with 100 credits. If your credits drop to zero, a Rebuy button adds another 100 credits to keep playing.")

            RuleSection(title: "Keyboard Shortcuts",
                        text: "Space — Deal\nH — Hit\nS — Stand\nD — Double Down\nP — Split\nM — Bet Max and deal")
        }
    }
}

struct ThemesHelpView: View {
    var body: some View {
        HelpShell(title: "Themes", subtitle: "Customize the look of every game") {
            RuleSection(title: "Opening Themes",
                        text: "In any game's Preferences, tap the Themes button to open the Themes panel. Changes preview live and apply when you close the panel.")

            RuleSection(title: "Felt Color",
                        text: "Choose from five preset felt colors — Felt Green, Crimson, Royal Blue, Charcoal, or Desert — or pick Custom to set any color you like with the color picker.")

            RuleSection(title: "Felt Vignette",
                        text: "Toggle the subtle dark vignette around the felt on or off. The setting is shared across all games.")

            RuleSection(title: "Card Backs",
                        text: "Choose a card back design from the deck selector, or upload a custom back (.jpg, .png, or .gif). GIF card backs animate on the stock pile. The selected back applies to all games.")

            RuleSection(title: "Face Card Art",
                        text: "Upload custom art for Jacks, Queens, Kings, and Aces (.jpg or .png). Drag an image onto a slot to replace that card face.")

            RuleSection(title: "Custom Card Colors",
                        text: "Override the suit, background, and outline colors on card faces independently from the felt theme.")

            RuleSection(title: "Saved Themes",
                        text: "Tap \"Save current as Theme…\" to snapshot the current card back, felt color, face art, and custom colors into a named theme. Apply any saved theme in one tap; delete it with the trash icon.")
        }
    }
}

// MARK: - Previews

#Preview("Klondike Help") { KlondikeHelpView() }
#Preview("Beecell Help") { BeecellHelpView() }
#Preview("Spider Help") { SpiderHelpView() }
#Preview("Video Poker Help") { VideoPokerHelpView() }
#Preview("Blackjack Help") { BlackjackHelpView() }
#Preview("Themes Help") { ThemesHelpView() }
