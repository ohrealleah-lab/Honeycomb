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

            RuleSection(title: "No Stress Mode",
                        text: "Turns off the timer for a pressure-free game. This is a shared setting — enabling it here also enables it in Freecell, Spider, Video Poker, and Blackjack, where it also turns off timers and switches the casino games into free play (no bets, no credits, just the cards).")

            RuleSection(title: "Keyboard Shortcuts",
                        text: "Arrow Keys — Navigate board cursor\nSpace / Return — Select / Place cards\nEscape — Clear selection\nD — Draw card\nF — Auto-move to foundations\nA — Autocomplete\n⌘N — New Game\n⌘R — Restart current deal\n⌘Z — Undo last move\n⌥⌘1 — Switch to Draw 1\n⌥⌘3 — Switch to Draw 3\n💡 Hint — press again to cycle through all available hints")
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

            RuleSection(title: "No Stress Mode",
                        text: "Turns off the timer for a pressure-free game. This is a shared setting — enabling it here also enables it in Klondike, Spider, Video Poker, and Blackjack, where it also turns off timers and switches the casino games into free play (no bets, no credits, just the cards).")

            RuleSection(title: "Keyboard Shortcuts",
                        text: "Arrow Keys — Navigate board cursor\nSpace / Return — Select / Place cards\nEscape — Clear selection\nC — Auto-move to free cell\nF — Auto-move to foundations\nA — Autocomplete\n⌘N — New Game\n⌘R — Restart current deal\n⌘Z — Undo last move\n💡 Hint — press again to cycle through all available hints")
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

            RuleSection(title: "No Stress Mode",
                        text: "Turns off the timer for a pressure-free game. This is a shared setting — enabling it here also enables it in Klondike, Freecell, Video Poker, and Blackjack, where it also turns off timers and switches the casino games into free play (no bets, no credits, just the cards).")

            RuleSection(title: "Keyboard Shortcuts",
                        text: "Arrow Keys — Navigate board cursor\nSpace / Return — Select / Place cards\nEscape — Clear selection\nD — Deal from stock\nA — Autocomplete\n⌘N — New Game\n⌘R — Restart current deal\n⌘Z — Undo last move\n⌥⌘1 — 1-Suit mode\n⌥⌘2 — 2-Suit mode\n💡 Hint — press again to cycle through all available hints")
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

            RuleSection(title: "No Stress Mode",
                        text: "Switches into free play: no bets, no credits won or lost, just relaxed practice — winning hands and streaks still show. This is a shared setting — enabling it here also enables it in Blackjack, and turns off the timer in Klondike, Freecell, and Spider.")

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
                        text: "Win — pays 2× your bet (profit of 1×)\nBlackjack (Ace + 10-value card) — pays 3:1 (profit of 3×)\nPush (tie) — your bet is returned\nBust or Loss — bet is forfeited\n\nDealer must stand on 17 and hit on 16 or lower.")

            RuleSection(title: "Credits",
                        text: "You start each session with 100 credits. If your credits drop to zero, a Rebuy button adds another 100 credits to keep playing.")

            RuleSection(title: "No Stress Mode",
                        text: "Switches into free play: no bets, no credits won or lost, just relaxed practice — winning hands and streaks still show, and Double/Split always behave as if you have credits for them. This is a shared setting — enabling it here also enables it in Video Poker, and turns off the timer in Klondike, Freecell, and Spider.")

            RuleSection(title: "Keyboard Shortcuts",
                        text: "Space — Deal\nH — Hit\nS — Stand\nD — Double Down\nP — Split\nM — Bet Max and deal")
        }
    }
}

// MARK: - Honeycomb Guide

struct HoneycombHelpView: View {
    var body: some View {
        HelpShell(title: "Honeycomb", subtitle: "Triple Triad-style card battle") {
            RuleSection(title: "Objective",
                        text: "Battle an AI opponent on a 3×3 grid. Place your 5 cards one at a time; when a placement's facing stat beats an adjacent enemy card's opposite facing stat, you capture it. Whoever controls more of the 9 cells once the board fills wins the match.")

            RuleSection(title: "How to Play",
                        text: "Drag a card from your hand onto any empty board cell, or tap a hand card to select it and then tap an empty cell. You and the dealer alternate turns until the board is full.")

            RuleSection(title: "Capturing & Combos",
                        text: "Each card shows 4 stats — Top, Right, Bottom, Left. Placing a card next to an enemy card compares your facing stat to their opposite facing stat; the higher value flips the loser to your side (10 is shown as \"A\"). A card captured this way can immediately capture its own neighbors in a chain reaction, called a Combo.")

            RuleSection(title: "Match Rules Overview",
                        text: "Up to 2 rules can be active per match, chosen in Options before you Start Match. Ascension and Descension can't both be picked (they're opposites), and neither can Order and Chaos. Leave rule selection empty (and Normal Mode off) and Roulette randomly rolls 0–2 rules for you every match instead — Roulette is also the only way Reverse can appear, since it's too easily exploited to pick on purpose.")

            RuleSection(title: "Ascension / Descension",
                        text: "At the start of the match, 2 of the 4 suits are randomly chosen to be affected. Under Ascension, every card of an affected suit gains +1 to all four of its stats for each card of that suit currently on the board — recalculated before every placement's captures resolve, so the bonus grows as more of that suit hits the table. Descension is the same idea in reverse: −1 per card of that suit on the board. A card of an unaffected suit plays completely normally.")

            RuleSection(title: "Same",
                        text: "If 2 or more of a placed card's touching neighbors have a facing stat exactly equal to the attacker's matching facing stat, every one of those matching neighbors is captured at once — not just the strongest one. Your own adjacent cards count toward the trigger too, not only the dealer's, so a placement boxed in by 2 of your own matching cards can still fire Same (this is intentional, not a bug).")

            RuleSection(title: "Plus",
                        text: "If 2 or more touching neighbor pairs each sum (attacker's facing stat + that neighbor's facing stat) to the same total as each other, every card in that matching group is captured — even if the shared sum isn't the attacker's own stat. Like Same, your own adjacent cards count toward the trigger.")

            RuleSection(title: "Fallen Ace",
                        text: "A card showing a 1 that attacks a card showing a 10 (\"A\") always captures it, overriding the normal higher-beats-lower comparison — a 1 is the one value that can topple an Ace. Under Reverse, this flips too: an attacking 10 always captures a defending 1.")

            RuleSection(title: "Reverse",
                        text: "Capture direction is fully inverted: the attacker wins when its facing stat is lower than the defender's, not higher. Reverse only ever appears via Roulette, never by manual selection — the AI's own deck (and, under Fallen Ace, its capture math) is specially adjusted per difficulty so a nominally \"Baby Bee\" opponent doesn't become trivial under the inversion.")

            RuleSection(title: "All Open / Three Open",
                        text: "All Open reveals the dealer's entire hand face-up for the whole match; Three Open reveals exactly 3 random cards from it, staying revealed by that specific card's identity as the hand shrinks. Either way the reveal is symmetric — the dealer's AI gets the same look at your hand it's giving you, so nobody's playing with hidden information the other side lacks.")

            RuleSection(title: "Swap",
                        text: "Before the first turn, one random card from your hand trades places with one random card from the dealer's hand. The swapped card plays for whoever now holds it, but for Card Bank unlock and post-win steal eligibility it still belongs to its original owner if you don't recapture it during the match.")

            RuleSection(title: "Order / Chaos",
                        text: "Order restricts your legal play each turn to strictly the next card in your original deck order — no choosing. Chaos instead re-rolls one random legal card the instant a side's turn begins, highlighted with a thick yellow border; you'll see the dealer's mandated card highlighted at least 2 seconds before its AI actually plays it.")

            RuleSection(title: "Bomb Shelter",
                        text: "The first card a player plays remains face down, unknown to the opponent. At the end of game, the face down cards get flipped. The starting player’s card gets exposed first. Cannot trigger combos.")

            RuleSection(title: "Sudden Death",
                        text: "A 5-5 tie sends the match into Sudden Death: the board clears and immediately replays with each side's exact end-of-round cards, alternating who starts, until someone wins outright.")

            RuleSection(title: "Difficulty",
                        text: "Baby Bee plays randomly. Honey Bee greedily maximizes its own captures each turn. Queen Bee and Killer Bee search several moves ahead using a full positional evaluation, with Killer Bee also fielding the strongest overall deck.")

            RuleSection(title: "Hint",
                        text: "On any difficulty below Killer Bee, the Hint button suggests the strongest card-and-cell placement — found with the same search Killer Bee's own AI uses — highlighting it for 2 seconds. It only ever considers dealer cards you've actually been shown, never one still hidden from you.")

            RuleSection(title: "Card Bank & Decks",
                        text: "Winning a card isn't automatic — after a win, you may drag one card the dealer played that round onto one of your 5 active deck slots, permanently unlocking it into your Card Bank. This steal is capped at one per match; Rematch (or start a new match) to steal again. Build named decks from Manage Decks, subject to rarity caps: at most one 5★ card, and at most one 4★ if a 5★ is already in the deck (otherwise up to two 4★).")

            RuleSection(title: "No Stress Mode",
                        text: "Deals a fixed, strong deck every match (one 5★, one 4★, three 3★) instead of your chosen active deck, and hides Steal Card — a relaxed way to play without managing a collection. This is a shared setting — enabling it here also enables it across the other games.")
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
                        text: "Tap \"Save as New Theme\" to snapshot the current card back, felt color, face art, and custom colors into a named theme. Apply any saved theme in one tap; delete it with the trash icon.")
        }
    }
}

// MARK: - Previews

#Preview("Klondike Help") { KlondikeHelpView() }
#Preview("Beecell Help") { BeecellHelpView() }
#Preview("Spider Help") { SpiderHelpView() }
#Preview("Video Poker Help") { VideoPokerHelpView() }
#Preview("Blackjack Help") { BlackjackHelpView() }
#Preview("Honeycomb Help") { HoneycombHelpView() }
#Preview("Themes Help") { ThemesHelpView() }
