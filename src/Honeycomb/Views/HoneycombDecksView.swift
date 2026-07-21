import SwiftUI

public struct HoneycombDecksView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var activeDeckIndex: Int

    @State private var profile = HoneycombProfileManager.shared
    @State private var editingDeckIndex: Int? = nil
    @State private var newDeckName: String = ""
    @State private var editingDeckCards: [Int] = []
    @State private var validationError: String? = nil
    @State private var isNameLocked: Bool = false

    // Card Bank filter — nil means "All".
    @State private var filterStar: Int? = nil
    @State private var filterSuit: String? = nil

    private var filteredCardBank: [Int] {
        let db = HoneycombDatabase.shared
        return Array(profile.unlockedCardIds).sorted().filter { id in
            guard let card = db.card(id: id) else { return false }
            if let star = filterStar, card.stars != star { return false }
            if let suit = filterSuit, card.suit != suit { return false }
            return true
        }
    }

    public var body: some View {
        GeometryReader { geo in
            let leftWidth = max(300, geo.size.width * 0.32)

            VStack(spacing: 0) {
                HStack {
                    Text("Saved Decks & Card Bank")
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()

                Divider()

                HStack(spacing: 0) {
                    // Left: Saved Decks
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SAVED DECKS")
                            .font(.caption).bold()
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)

                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(0..<profile.savedDecks.count, id: \.self) { index in
                                    savedDeckRow(index: index)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(width: leftWidth, alignment: .top)

                    Divider()

                    // Right: Card Bank
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("CARD BANK")
                                .font(.caption).bold()
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(filteredCardBank.count)/\(profile.unlockedCardIds.count) shown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 4)

                        cardBankFilterBar

                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                                ForEach(filteredCardBank, id: \.self) { cardId in
                                    if let cardData = HoneycombDatabase.shared.card(id: cardId) {
                                        HoneycombCardView(card: HoneycombCard(data: cardData, owner: .player), size: CGSize(width: 90, height: 127), isFlipped: false, useOwnershipColoring: false)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
        .frame(minWidth: 900, idealWidth: 1100, minHeight: 650, idealHeight: 750)
        .sheet(item: Binding(
            get: { editingDeckIndex.map { DeckEditWrapper(index: $0) } },
            set: { editingDeckIndex = $0?.index }
        )) { wrapper in
            deckBuilder(wrapper: wrapper)
        }
        .onAppear {
            profile = HoneycombProfileManager.shared
        }
    }

    private func savedDeckRow(index: Int) -> some View {
        let deck = profile.savedDecks[index]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                if deck.name.isEmpty {
                    Text("Empty Slot \(index + 1)").foregroundColor(.secondary)
                } else {
                    Text(deck.name).bold()
                }
                if activeDeckIndex == index {
                    Text("(Active)").foregroundColor(.green).font(.caption).bold()
                }
                Spacer()
                if activeDeckIndex != index && !deck.name.isEmpty {
                    Button("Set Active") {
                        activeDeckIndex = index
                    }
                    .buttonStyle(.bordered)
                }
                Button(deck.name.isEmpty ? "Create" : "Edit") {
                    editingDeckIndex = index
                    newDeckName = deck.name
                    editingDeckCards = deck.cardIds
                    isNameLocked = !deck.name.isEmpty
                    validateDeck()
                }
            }

            HStack {
                ForEach(deck.cardIds, id: \.self) { cardId in
                    if let cardData = HoneycombDatabase.shared.card(id: cardId) {
                        HoneycombCardView(card: HoneycombCard(data: cardData, owner: .player), size: CGSize(width: 40, height: 57), isFlipped: false, useOwnershipColoring: false)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(8)
    }

    private var cardBankFilterBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button("All Stars") { filterStar = nil }
                ForEach(1...5, id: \.self) { star in
                    Button("\(star)★") { filterStar = star }
                }
            } label: {
                filterChip(label: filterStar.map { "\($0)★" } ?? "All Stars")
            }

            Menu {
                Button("All Suits") { filterSuit = nil }
                Button("♠ Spades") { filterSuit = "S" }
                Button("♥ Hearts") { filterSuit = "H" }
                Button("♦ Diamonds") { filterSuit = "D" }
                Button("♣ Clubs") { filterSuit = "C" }
            } label: {
                filterChip(label: filterSuit.map { suitLabel($0) } ?? "All Suits")
            }

            if filterStar != nil || filterSuit != nil {
                Button("Clear") {
                    filterStar = nil
                    filterSuit = nil
                }
                .font(.caption)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func filterChip(label: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption).bold()
            Image(systemName: "chevron.down").font(.system(size: 9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.08))
        .cornerRadius(8)
    }

    private func suitLabel(_ suit: String) -> String {
        switch suit {
        case "S": return "♠ Spades"
        case "H": return "♥ Hearts"
        case "D": return "♦ Diamonds"
        case "C": return "♣ Clubs"
        default: return suit
        }
    }

    @ViewBuilder
    private func deckBuilder(wrapper: DeckEditWrapper) -> some View {
        VStack(spacing: 20) {
            Text("Deck Builder").font(.largeTitle).bold()

            TextField("Deck Name (Max 20 chars)", text: $newDeckName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
                .disabled(isNameLocked)
            if isNameLocked {
                Text("Deck name is locked once saved.").foregroundColor(.secondary).font(.caption)
            }

            if let error = validationError {
                Text(error).foregroundColor(.red).font(.subheadline)
            }

            // Current Deck
            VStack {
                Text("Your Deck (\(editingDeckCards.count)/5) - Tap to Remove").font(.headline)
                HStack {
                    ForEach(0..<5) { i in
                        if i < editingDeckCards.count {
                            let cardId = editingDeckCards[i]
                            if let cardData = HoneycombDatabase.shared.card(id: cardId) {
                                HoneycombCardView(card: HoneycombCard(data: cardData, owner: .player), size: CGSize(width: 80, height: 113), isFlipped: false, useOwnershipColoring: false)
                                    .onTapGesture {
                                        editingDeckCards.remove(at: i)
                                        validateDeck()
                                    }
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 113)
                        }
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)

            // Card Bank for Selection — shares the same suit/star filter as the main view.
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Bank - Tap to Add").font(.headline)
                cardBankFilterBar
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                        ForEach(filteredCardBank, id: \.self) { cardId in
                            if let cardData = HoneycombDatabase.shared.card(id: cardId) {
                                HoneycombCardView(card: HoneycombCard(data: cardData, owner: .player), size: CGSize(width: 80, height: 113), isFlipped: false, useOwnershipColoring: false)
                                    .opacity(editingDeckCards.contains(cardId) ? 0.3 : 1.0)
                                    .onTapGesture {
                                        if !editingDeckCards.contains(cardId) && editingDeckCards.count < 5 {
                                            editingDeckCards.append(cardId)
                                            validateDeck()
                                        }
                                    }
                            }
                        }
                    }
                    .padding()
                }
            }

            HStack(spacing: 40) {
                Button("Cancel") { editingDeckIndex = nil }
                Button("Save Deck") {
                    if validationError == nil && editingDeckCards.count == 5 && !newDeckName.isEmpty {
                        profile.saveDeck(index: wrapper.index, name: newDeckName, cardIds: editingDeckCards)
                        editingDeckIndex = nil
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(validationError != nil || editingDeckCards.count != 5 || newDeckName.isEmpty || newDeckName.count > 20)
            }
        }
        .padding()
        .frame(minWidth: 700, minHeight: 700)
    }

    private func validateDeck() {
        let db = HoneycombDatabase.shared
        var fiveStars = 0
        var fourStars = 0

        for id in editingDeckCards {
            if let card = db.card(id: id) {
                if card.stars == 5 { fiveStars += 1 }
                if card.stars == 4 { fourStars += 1 }
            }
        }

        if fiveStars > 1 {
            validationError = "A deck can never contain more than one 5★ card."
        } else if fiveStars == 1 && fourStars > 1 {
            validationError = "If you have a 5★ card, you can only have one 4★ card."
        } else if fiveStars == 0 && fourStars > 2 {
            validationError = "A deck can never contain more than two 4★ cards."
        } else if newDeckName.count > 20 {
            validationError = "Deck name cannot exceed 20 characters."
        } else {
            validationError = nil
        }
    }

    struct DeckEditWrapper: Identifiable {
        let index: Int
        var id: Int { index }
    }
}
