import SwiftUI

public struct HoneycombDecksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator
    @Binding var activeDeckIndex: Int
    var viewModel: HoneycombViewModel

    @State private var profile = HoneycombProfileManager.shared
    @State private var editingDeckIndex: Int? = nil
    @State private var newDeckName: String = ""
    @State private var editingDeckCards: [Int] = []
    @State private var validationError: String? = nil
    @State private var showStartOverConfirmation = false

    // Card Bank filter — nil means "All".
    @State private var filterStar: Int? = nil
    @State private var filterSuit: String? = nil
    @State private var filterFavoritesOnly: Bool = false

    // Freeform stat search — one value per card position instead of separate side/
    // direction pickers; empty means "don't filter that side". Only ever read by
    // statSearchedCardBank below, which only backs the main browse grid — Deck
    // Builder's grid keeps using plain filteredCardBank so the two stay independent
    // filters, matching the Windows port (where they're separate views entirely).
    @State private var filterStatTop: String = ""
    @State private var filterStatLeft: String = ""
    @State private var filterStatRight: String = ""
    @State private var filterStatBottom: String = ""

    private var filteredCardBank: [Int] {
        let db = HoneycombDatabase.shared
        return Array(profile.unlockedCardIds).sorted().filter { id in
            guard let card = db.card(id: id) else { return false }
            if let star = filterStar, card.stars != star { return false }
            if let suit = filterSuit, card.suit != suit { return false }
            if filterFavoritesOnly && !profile.favoriteCardIds.contains(id) { return false }
            return true
        }
    }

    // "A"/"a" = 10 (matches HoneycombCardView's own statString), 1-9 parse directly;
    // anything else (a stray letter, "0", etc.) is treated the same as empty rather
    // than blocking the keystroke — no separate validation/rejection path needed.
    private func parseStatBox(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        if trimmed.uppercased() == "A" { return 10 }
        if let value = Int(trimmed), (1...9).contains(value) { return value }
        return nil
    }

    // Index order [Top, Right, Bottom, Left] matches HoneycombCardData.stats
    // (see HoneycombCardView's stats[0]/[1]/[2]/[3] usage).
    private var statFilters: [Int?] {
        [parseStatBox(filterStatTop), parseStatBox(filterStatRight),
         parseStatBox(filterStatBottom), parseStatBox(filterStatLeft)]
    }

    // AND across every filled-in side: a card survives only if each filled side is
    // within ±2 of its stat (exact or near). Exact-only matches (every filled side
    // dead-on) sort first; anything relying on the ±2 tolerance sorts after and is
    // reported in `near` so the grid can render it dimmed.
    private var statSearchedCardBank: (ids: [Int], near: Set<Int>) {
        let filters = statFilters
        guard filters.contains(where: { $0 != nil }) else { return (filteredCardBank, []) }

        let db = HoneycombDatabase.shared
        var exact: [Int] = []
        var near: [Int] = []
        for id in filteredCardBank {
            guard let card = db.card(id: id) else { continue }
            var isNear = false
            var matches = true
            for (i, target) in filters.enumerated() {
                guard let target else { continue }
                let diff = abs(card.stats[i] - target)
                if diff == 0 { continue }
                if diff <= 2 { isNear = true; continue }
                matches = false
                break
            }
            if !matches { continue }
            if isNear { near.append(id) } else { exact.append(id) }
        }
        return (exact + near, Set(near))
    }

    private func statSearchField(_ binding: Binding<String>) -> some View {
        TextField("", text: binding)
            .multilineTextAlignment(.center)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .frame(width: 28, height: 24)
            .background(Color(white: 0.95))
            .cornerRadius(4)
            .textFieldStyle(.plain)
            .onChange(of: binding.wrappedValue) { _, newValue in
                if newValue.count > 1 {
                    binding.wrappedValue = String(newValue.suffix(1))
                }
            }
    }

    private var statSearchWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Freeform search: type a value onto the card to filter the bank.")
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))

                Image(systemName: "suit.club.fill")
                    .font(.system(size: 34))
                    .foregroundColor(Color.gray.opacity(0.3))

                statSearchField($filterStatTop).position(x: 48, y: 20)
                statSearchField($filterStatLeft).position(x: 20, y: 64)
                statSearchField($filterStatRight).position(x: 76, y: 64)
                statSearchField($filterStatBottom).position(x: 48, y: 108)
            }
            .frame(width: 96, height: 128)
        }
    }

    // Favoriting only happens from the main browse grid (Deck Builder's grid already
    // uses a tap to add/remove the card from the deck being edited, so a second,
    // conflicting meaning for the same tap would be confusing there).
    private func toggleFavorite(cardId: Int) {
        profile.toggleFavorite(id: cardId)
    }

    private func performStartOver() {
        viewModel.startOver()
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
                    // Left: freeform stat search, then Saved Decks
                    VStack(alignment: .leading, spacing: 10) {
                        statSearchWidget

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

                        startOverPanel
                    }
                    .padding()
                    .frame(width: leftWidth, alignment: .top)

                    Divider()

                    // Right: Card Bank
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("CARD BANK (\(profile.unlockedCardIds.count) of \(HoneycombDatabase.shared.allCards.count))")
                                .font(.caption).bold()
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 4)

                        cardBankFilterBar

                        ScrollView {
                            let searched = statSearchedCardBank
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                                ForEach(searched.ids, id: \.self) { cardId in
                                    if let cardData = HoneycombDatabase.shared.card(id: cardId) {
                                        // A real Button (rather than a bare .onTapGesture) so AppKit's
                                        // own hit-testing resolves which card was clicked — inside a
                                        // LazyVGrid, a raw tap gesture could occasionally resolve
                                        // against a neighboring cell's recognizer instead of the one
                                        // actually under the cursor.
                                        Button {
                                            toggleFavorite(cardId: cardId)
                                        } label: {
                                            HoneycombCardView(card: HoneycombCard(data: cardData, owner: .player), size: CGSize(width: 90, height: 127), isFlipped: false, useOwnershipColoring: false)
                                                .overlay(alignment: .topTrailing) {
                                                    // Always rendered (opacity-toggled) rather than conditionally
                                                    // included/excluded — a Button label nested this deep inside a
                                                    // LazyVGrid can be slow to re-diff an if/else branch, which made
                                                    // un-favoriting look like it silently failed until the next
                                                    // full redraw even though the underlying state updated.
                                                    Image(systemName: "heart.fill")
                                                        .foregroundColor(.red)
                                                        .font(.system(size: 16))
                                                        .padding(6)
                                                        .shadow(color: .white, radius: 2)
                                                        .opacity(profile.favoriteCardIds.contains(cardId) ? 1 : 0)
                                                }
                                                // Freeform stat search: cards that only matched via the ±2
                                                // tolerance (not an exact hit on every filled-in side) render
                                                // dimmed, so exact matches stand out even though both are
                                                // already sorted exact-first.
                                                .opacity(searched.near.contains(cardId) ? 0.4 : 1.0)
                                        }
                                        .buttonStyle(.plain)
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
    }

    private var startOverPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Want a fresh start? Starting over clears your saved decks and card bank, then reseeds the game with a whole new set of cards.")
                .foregroundColor(.white)

            Button("Start Over") {
                showStartOverConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .foregroundColor(.black)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red)
        .cornerRadius(10)
        .alert("Start Over?", isPresented: $showStartOverConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Start Over", role: .destructive) { performStartOver() }
        } message: {
            Text("Starting over reseeds the game with an entirely new set of cards. All saved decks and card bank progress. This can't be undone.")
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
                Spacer()
                // Always shown (not just when inactive) — reads "Active" and disables
                // itself when this is the active deck, instead of disappearing, so the
                // active state is signaled in the same spot every deck's button sits
                // in. No separate "(Active)" label — the disabled button state plus
                // the row's felt-tinted background/border already say it.
                if !deck.name.isEmpty {
                    Button(activeDeckIndex == index ? "Active" : "Set Active") {
                        activeDeckIndex = index
                    }
                    .buttonStyle(.bordered)
                    .disabled(activeDeckIndex == index)
                }
                Button(deck.name.isEmpty ? "Create" : "Edit") {
                    editingDeckIndex = index
                    newDeckName = deck.name
                    editingDeckCards = deck.cardIds
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
        // Active deck gets the same felt-color background/border treatment as the
        // Deck Builder's "Your Deck" tray, instead of the same flat black tint every
        // deck (active or not) previously used — matches the Windows port.
        .background(activeDeckIndex == index ? coordinator.currentFeltColor.opacity(0.5) : Color.black.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(activeDeckIndex == index ? coordinator.currentFeltColor : .clear, lineWidth: 2)
        )
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

            Button {
                filterFavoritesOnly.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: filterFavoritesOnly ? "heart.fill" : "heart")
                        .foregroundColor(filterFavoritesOnly ? .red : .primary)
                    Text("Favorites").font(.caption).bold()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(filterFavoritesOnly ? Color.red.opacity(0.12) : Color.black.opacity(0.08))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            if filterStar != nil || filterSuit != nil || filterFavoritesOnly {
                Button("Clear") {
                    filterStar = nil
                    filterSuit = nil
                    filterFavoritesOnly = false
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
            // App-wide felt color (AppCoordinator.currentFeltColor already resolves
            // .custom vs the built-in theme presets) instead of a fixed blue tint, so
            // the tray reads as "your active area" against the felt rather than
            // blending into the rest of the sheet.
            .background(coordinator.currentFeltColor.opacity(0.5))
            .cornerRadius(12)

            // Card Bank for Selection — shares the same suit/star filter as the main view.
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Bank - Tap to Add").font(.headline)
                Text("Maximum one 5★ and one 4★ card per deck. Two 4★ cards can be used without a 5★.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                                    // Empty content when not in the deck renders no menu at all — no
                                    // right-click affordance on cards that aren't placed yet. Right-
                                    // click on macOS, long-press on iOS (same modifier, no #if os()
                                    // needed). No confirmation: re-adding the card is one tap away.
                                    .contextMenu {
                                        if editingDeckCards.contains(cardId) {
                                            Button("Remove from deck?") {
                                                editingDeckCards.removeAll { $0 == cardId }
                                                validateDeck()
                                            }
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
