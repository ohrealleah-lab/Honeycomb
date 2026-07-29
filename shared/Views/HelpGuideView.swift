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

private struct ShortcutRow: View {
    let action: String
    let shortcut: String

    var body: some View {
        HStack(alignment: .top) {
            Text(action)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(shortcut)
                .font(.body)
                .foregroundStyle(.secondary)
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
        HelpShell(title: "Klondike Solitaire", subtitle: "Classic single-deck solitaire with Draw 1, Draw 3, and Vegas scoring options.") {
            RuleSection(title: "📌 Overview & Objective",
                        text: "Move all 52 cards to the four Foundation piles, organized by suit from Ace (lowest) to King (highest).")

            RuleSection(title: "🃏 Setup & Layout",
                        text: "• Tableau (7 Columns): Dealt from left to right with 1 to 7 cards respectively. Only the top card in each column is face-up.\n• Stock Pile (Top-Left): Contains the remaining 24 face-down cards.\n• Waste Pile (Next to Stock): Holds cards drawn from the stock.\n• Foundations (Top-Right): Four empty slots reserved for completing each suit.")

            RuleSection(title: "🎮 Rules & How to Play",
                        text: "• Tableau Building: Stack cards in descending rank with alternating colors (e.g., a red 6 on a black 7). You may move a single card or an entire face-up sequence to another column.\n• Empty Columns: Only a King (or a sequence starting with a King) may be placed in an empty tableau column.\n• Stock & Waste:\n  – Draw 1 Mode: Clicking the stock reveals 1 card to the waste.\n  – Draw 3 Mode: Reveals 3 cards; only the top card of the waste is playable. Once played, the next card in the 3-card batch becomes available.\n• Scoring Modes:\n  – Standard: Flip face-down card (+5 pts) · Waste to Tableau (+5 pts) · Waste/Tableau to Foundation (+10 pts) · Foundation back to Tableau (−15 pts).\n  – Vegas: Start with a debt of −$52. Earn +$5 for every card moved to a foundation. Draw 1 permits only 1 pass through the stock; Draw 3 allows 3 passes (2 redeals).")
            
            VStack(alignment: .leading, spacing: 6) {
                Text("⌨️ Controls & Shortcuts")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ShortcutRow(action: "Navigate Board Cursor", shortcut: "Arrow Keys")
                    ShortcutRow(action: "Select / Place Card", shortcut: "Space / Enter")
                    ShortcutRow(action: "Clear Selection", shortcut: "Escape")
                    ShortcutRow(action: "Draw Card(s)", shortcut: "D")
                    ShortcutRow(action: "Auto-Move to Foundation", shortcut: "F")
                    ShortcutRow(action: "Autocomplete Game", shortcut: "A")
                    ShortcutRow(action: "New Game / Restart Deal", shortcut: "⌘N / ⌘R")
                    ShortcutRow(action: "Undo Move", shortcut: "⌘Z")
                    ShortcutRow(action: "Toggle Draw 1 / Draw 3", shortcut: "⌥⌘1 / ⌥⌘3")
                    ShortcutRow(action: "Cycle Available Hints", shortcut: "Hint button")
                }
            }
            
            RuleSection(title: "💡 Strategy & Pro Tips",
                        text: "1. Prioritize Face-Down Cards: Always prioritize moves that reveal hidden cards in the longest tableau columns.\n2. Keep Columns Open: Don't clear a tableau column unless you already have a King ready to occupy it.\n3. Delay Foundation Moves: Avoid rushing cards into the foundation early if those cards might be needed to build lower sequences in the tableau.")
        }
    }
}

// MARK: - Beecell Guide

struct BeecellHelpView: View {
    var body: some View {
        HelpShell(title: "Freecell (Beecell)", subtitle: "The ultimate strategic solitaire game—99.9% of all deals are solvable.") {
            RuleSection(title: "📌 Overview & Objective",
                        text: "Move all 52 cards to the four Foundation piles, built up by suit from Ace to King.")

            RuleSection(title: "🃏 Setup & Layout",
                        text: "• Tableau (8 Columns): All 52 cards are dealt face-up at the start (4 columns of 7 cards, 4 columns of 6 cards).\n• Free Cells (Top-Left): Four temporary storage slots.\n• Foundations (Top-Right): Four suit build-up piles.")

            RuleSection(title: "🎮 Rules & How to Play",
                        text: "• Tableau Building: Stack cards in descending rank and alternating colors.\n• Free Cell Storage: Each free cell can hold exactly 1 card at a time.\n• Multi-Card Movement Capacity: You can move a face-up card sequence in a single action. The maximum number of cards you can move at once is calculated as: (Free Cells Available + 1) × 2^(Empty Tableau Columns).\n• Empty Columns: Any single card or valid sequence can be moved into an empty tableau column.")
            
            VStack(alignment: .leading, spacing: 6) {
                Text("⌨️ Controls & Shortcuts")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ShortcutRow(action: "Navigate / Select", shortcut: "Arrow Keys + Space / Enter")
                    ShortcutRow(action: "Auto-Park to Free Cell", shortcut: "C")
                    ShortcutRow(action: "Auto-Move to Foundation", shortcut: "F")
                    ShortcutRow(action: "Autocomplete Game", shortcut: "A")
                    ShortcutRow(action: "New Game / Restart Deal", shortcut: "⌘N / ⌘R")
                    ShortcutRow(action: "Undo Move", shortcut: "⌘Z")
                    ShortcutRow(action: "Hint", shortcut: "Hint button")
                }
            }

            RuleSection(title: "💡 Strategy & Pro Tips",
                        text: "1. Protect Your Free Cells: Treat free cells as temporary maneuvering space. Avoid filling all four free cells simultaneously, as it drastically reduces your sequence-moving capacity.\n2. Uncover Low Cards Early: Focus on freeing up Aces and 2s buried at the bottom of columns.\n3. Empty Columns are Gold: An empty column doubles your movement capacity and acts as an unrestricted free cell.")
        }
    }
}

// MARK: - Spider Solibee Guide

struct SpiderHelpView: View {
    var body: some View {
        HelpShell(title: "Spider Solitaire", subtitle: "A deep, two-deck game of sequence building across 1, 2, or 4 suits.") {
            RuleSection(title: "📌 Overview & Objective",
                        text: "Assemble eight complete same-suit sequences from King down to Ace within the tableau. Each completed 13-card sequence is automatically removed to the foundation.")

            RuleSection(title: "🃏 Setup & Layout",
                        text: "• Tableau (10 Columns): 54 cards dealt across 10 columns (first 4 get 6 cards; last 6 get 5 cards). Only the top card of each column is face-up.\n• Stock (Bottom/Top): 50 remaining cards arranged in 5 extra deals of 10 cards each.")

            RuleSection(title: "🎮 Rules & How to Play",
                        text: "• Difficulty Modes:\n  – 1-Suit (Easy): All 104 cards are Spades.\n  – 2-Suits (Medium): 52 Spades and 52 Hearts.\n  – 4-Suits (Hard): All four standard suits are used.\n• Tableau Building: Stack cards in descending rank regardless of suit (e.g., a 7 of Hearts can sit on an 8 of Spades). Crucial Exception: You may only move a multi-card sequence if all cards in that sequence share the same suit.\n• Stock Deals: Click the stock to deal 1 card onto every tableau column. Requirement: Every column must contain at least 1 card before you can deal from the stock.")

            VStack(alignment: .leading, spacing: 6) {
                Text("⌨️ Controls & Shortcuts")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ShortcutRow(action: "Deal 10 Cards from Stock", shortcut: "D")
                    ShortcutRow(action: "Select / Place Sequence", shortcut: "Space / Enter")
                    ShortcutRow(action: "1-Suit / 2-Suit Mode", shortcut: "⌥⌘1 / ⌥⌘2")
                    ShortcutRow(action: "Autocomplete", shortcut: "A")
                    ShortcutRow(action: "Undo Move", shortcut: "⌘Z")
                }
            }

            RuleSection(title: "💡 Strategy & Pro Tips",
                        text: "1. Same-Suit Over Mixed-Suit: Always prefer building same-suit runs. Mixed-suit stacks lock up your cards and cannot be moved together.\n2. Empty Columns First: Empty columns allow you to isolate mixed-suit stacks and re-organize them into clean same-suit runs.\n3. Delay Dealing: Exhaust every possible move on the board before clicking the stock.")
        }
    }
}

// MARK: - Video Poker Guide

struct VideoPokerHelpView: View {
    var body: some View {
        HelpShell(title: "Video Poker", subtitle: "Classic casino poker with Jacks or Better, Deuces Wild, and Bonus Poker pay tables.") {
            RuleSection(title: "📌 Overview & Objective",
                        text: "Draw a 5-card hand that matches a qualifying entry on the pay table to earn credit multipliers.")

            RuleSection(title: "🎮 How to Play & Variants",
                        text: "1. Betting: Select 1 to 5 coins. Press Bet Max (M) to bet 5 coins and immediately deal. (Note: The 800× Royal Flush jackpot is only awarded on a 5-coin bet).\n2. Deal & Hold: Press Deal (Space). Click cards or press 1–5 to toggle HOLD on cards you wish to keep.\n3. Draw: Press Draw (Space). Unheld cards are replaced. Winnings are paid according to the pay table.\n\nGame Variants:\n• Jacks or Better: Standard pay table. Minimum qualifying hand is a pair of Jacks, Queens, Kings, or Aces (1×).\n• Deuces Wild: All four 2s are wild cards. Minimum winning hand is Three of a Kind. Special payouts for Four Deuces (200×) and Wild Royal Flush (25×).\n• Bonus Poker: Enhanced payouts for Four of a Kind (Four Aces pays 80×; Four 2s/3s/4s pays 40×).")
            
            VStack(alignment: .leading, spacing: 6) {
                Text("⌨️ Controls & Shortcuts")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ShortcutRow(action: "Deal / Draw", shortcut: "Space / Enter")
                    ShortcutRow(action: "Hold Card 1, 2, 3, 4, 5", shortcut: "1, 2, 3, 4, 5")
                    ShortcutRow(action: "Hold All Cards", shortcut: "H")
                    ShortcutRow(action: "Clear All Holds", shortcut: "C / Q")
                    ShortcutRow(action: "Bet Max & Deal", shortcut: "M")
                }
            }

            RuleSection(title: "💡 Strategy & Pro Tips",
                        text: "1. Always Bet Max (5 Coins): The Royal Flush payout jumps from 250× to 800× only at 5 coins.\n2. Never Break a Made Hand (Except for 4-to-a-Royal): Only break a Straight or Flush if you are 1 card away from a Royal Flush.\n3. In Deuces Wild, Never Discard a 2: Deuces are wild—always hold every 2 dealt to you!")
        }
    }
}

// MARK: - Video Blackjack Guide

struct BlackjackHelpView: View {
    var body: some View {
        HelpShell(title: "Video Blackjack", subtitle: "Beat the dealer by getting closer to 21 without going over.") {
            RuleSection(title: "📌 Overview & Objective",
                        text: "Outscore the dealer's hand total without exceeding 21. Face cards = 10, Aces = 1 or 11, Number cards = face value.")

            RuleSection(title: "🎮 Rules & Options",
                        text: "1. Place Bet & Deal: Select your chip wager (1, 5, 10, 25) or press Bet Max (M), then press Deal (Space).\n2. Your Turn:\n  – Hit (H): Take another card.\n  – Stand (S): Keep your current hand.\n  – Double Down (D): Double your wager, receive exactly 1 card, and automatically stand. (Available on initial 2 cards with totals of 9, 10, or 11).\n  – Split (P): If dealt two matching ranks, split them into two separate hands (requires an equal second wager).\n3. Dealer's Turn: Dealer reveals their hidden card and must hit until reaching 17 or higher (stands on all 17s).\n\nPayout Schedule:\n• Standard Win: 1:1 payout.\n• Natural Blackjack (Ace + 10-value card): 3:1 payout.\n• Push (Tie): Bet is returned.")
            
            VStack(alignment: .leading, spacing: 6) {
                Text("⌨️ Controls & Shortcuts")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ShortcutRow(action: "Deal / Buy In", shortcut: "Space / Enter")
                    ShortcutRow(action: "Hit", shortcut: "H")
                    ShortcutRow(action: "Stand", shortcut: "S")
                    ShortcutRow(action: "Double Down", shortcut: "D")
                    ShortcutRow(action: "Split Pairs", shortcut: "P")
                    ShortcutRow(action: "Bet Max & Deal", shortcut: "M")
                }
            }

            RuleSection(title: "💡 Strategy & Pro Tips",
                        text: "1. Always Split Aces and 8s: Never split 10s or 5s.\n2. Double Down on 11: Always Double Down when your starting hand totals 11 against a dealer 2 through 10.\n3. Watch the Dealer's Upcard: If the dealer shows a 2 through 6, they have a high chance of busting—stand on hard 12 or higher and let the dealer draw.")
        }
    }
}

// MARK: - Honeycomb Guide

struct HoneycombHelpView: View {
    var body: some View {
        HelpShell(title: "Honeycomb", subtitle: "A tactical 3×3 grid card battle inspired by Triple Triad.") {
            RuleSection(title: "📌 Overview & Objective",
                        text: "Battle an AI opponent on a 3×3 grid using a 5-card deck. Each card features 4 directional stats (Top, Right, Bottom, Left). Place cards strategically to flip enemy cards to your color. Whoever controls the majority of the 9 grid cells at the end wins!")

            RuleSection(title: "🎮 Core Gameplay & Mechanics",
                        text: "• Capturing: When you place a card adjacent to an opponent's card, your facing stat is compared against their opposite facing stat. If your stat is higher, the enemy card is captured (flipped to your color). Stat 10 is rendered as \"A\".\n• Combos: A card captured during a turn immediately checks its own adjacent neighbors, triggering a chain-reaction capture sequence!")

            RuleSection(title: "🎲 Match Modifiers & Special Rules",
                        text: "• Same: If 2+ touching neighbor stats match your card's facing stats, all matching neighbors are captured simultaneously.\n• Plus: If the sum of (your stat + neighbor's stat) equals the same total across 2+ neighbors, all involved cards are captured.\n• Fallen Ace: A card with a stat of 1 attacking a 10 (\"A\") always captures it!\n• Reverse: Inverts all comparisons—lower stats beat higher stats. (Reverse appears via Roulette only).\n• Ascension / Descension: Grants +1 (or −1) to stats for all cards matching randomly selected suits as more of that suit enter the board.\n• Order / Chaos: Order forces you to play cards in exact deck sequence. Chaos randomly mandates which card must be played each turn.\n• Bomb Shelter: First card played remains face-down for 3 turns before flipping automatically.")
            
            RuleSection(title: "🏆 Card Bank & Stealing",
                        text: "• Steal Mechanics: After winning a match, double-click an eligible dealer card to permanently steal it into your Card Bank!\n• Deck Rarity Caps: Custom decks are limited to: at most one 5★ card, and at most one 4★ card if a 5★ is present (or up to two 4★ cards without a 5★).\n• Smart Opponent Decks: The AI automatically selects decks containing cards you don't yet own to maximize steal rewards.")

            VStack(alignment: .leading, spacing: 6) {
                Text("⌨️ Controls & Shortcuts")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ShortcutRow(action: "Select / Place Card", shortcut: "Click & Drag or Tap Card → Tap Cell")
                    ShortcutRow(action: "Show Best AI Move", shortcut: "Hint button")
                }
            }
        }
    }
}

// MARK: - Themes Help Guide

struct ThemesHelpView: View {
    var body: some View {
        HelpShell(title: "Themes & Global Settings", subtitle: "Customize the look of every game and adjust global modes.") {
            RuleSection(title: "🧘 No Stress Mode",
                        text: "• Universal Toggle: Enabling No Stress Mode in Options turns off all pressure across every game.\n• Solitaire Games: Disables timers completely.\n• Video Poker & Blackjack: Switches into Free Play—hides bets, credits, and pay tables so you can play risk-free without wagers.\n• Honeycomb: Supplies a fixed strong deck every match and hides Card Steal.")

            RuleSection(title: "🎨 Themes & Customization",
                        text: "• Felt Table: Choose from 5 preset felt colors (Green, Crimson, Royal Blue, Charcoal, Desert) or set a Custom Color via picker. Toggle edge vignette on/off.\n• Card Backs: Select built-in designs or upload custom .jpg/.png/.gif files.\n• Face Card Art: Upload custom image/GIF artwork individually for Aces, Jacks, Queens, and Kings.\n• Saved Themes: Snapshot your custom felt, card backs, and face art into named custom themes to apply anytime in one click!")
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
