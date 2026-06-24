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
                        text: "In Vegas scoring, each card moved to a foundation scores +5 points. A redeal of the stock costs −25 points. Try to finish with a positive score!")

            RuleSection(title: "Keyboard Shortcuts",
                        text: "⌘N — New Game\n⌘R — Restart current deal\n⌘Z — Undo last move\n⌥⌘1 — Switch to Draw 1\n⌥⌘3 — Switch to Draw 3")
        }
    }
}

// MARK: - Beecell Guide

struct BeecellHelpView: View {
    var body: some View {
        HelpShell(title: "Beecell", subtitle: "FreeCell variant with a hive twist") {
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
                        text: "⌘N — New Game\n⌘R — Restart current deal\n⌘Z — Undo last move")
        }
    }
}

// MARK: - Spider Solibee Guide

struct SpiderHelpView: View {
    var body: some View {
        HelpShell(title: "Spider Solibee", subtitle: "Spider Solitaire with one, two, or four suits") {
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
                        text: "⌘N — New Game\n⌘R — Restart current deal\n⌘Z — Undo last move\n⌥⌘1 — 1-Suit mode\n⌥⌘2 — 2-Suit mode")
        }
    }
}

// MARK: - Previews

#Preview("Klondike Help") { KlondikeHelpView() }
#Preview("Beecell Help") { BeecellHelpView() }
#Preview("Spider Help") { SpiderHelpView() }
