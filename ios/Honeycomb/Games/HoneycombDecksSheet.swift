import SwiftUI

/// Touch port of the mac app's "Manage Decks" window (HoneycombDecksView): browse the
/// unlocked card bank, favorite cards, and build/edit the 5 saved decks. Mac splits
/// Saved Decks and Card Bank into a permanent side-by-side layout (needs 900pt+ width);
/// on iPhone that doesn't fit, so this uses a segmented tab instead. Entirely backed by
/// HoneycombProfileManager/HoneycombDatabase (already shared, no NSImage dependency),
/// so this is pure UI — no new storage layer needed.
struct HoneycombDecksSheet: View {
    @Bindable var viewModel: HoneycombViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppCoordinator.self) private var coordinator

    @State private var profile = HoneycombProfileManager.shared
    @State private var tab: Tab = .decks
    @State private var editingDeckIndex: Int? = nil
    @State private var showStartOverConfirmation = false

    @State private var filterStar: Int? = nil
    @State private var filterSuit: String? = nil
    @State private var filterFavoritesOnly = false

    enum Tab: String, CaseIterable {
        case decks = "Saved Decks"
        case bank = "Card Bank"
    }

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text(tabLabel($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(12)

                switch tab {
                case .decks: savedDecksTab
                case .bank: cardBankTab
                }
            }
            .navigationTitle(coordinator.L(.manageDecks))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(coordinator.L(.done)) { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { editingDeckIndex.map { DeckEditWrapper(index: $0) } },
                set: { editingDeckIndex = $0?.index }
            )) { wrapper in
                DeckBuilderSheet(
                    index: wrapper.index,
                    initialName: profile.savedDecks[wrapper.index].name,
                    initialCardIds: profile.savedDecks[wrapper.index].cardIds,
                    filteredCardBank: filteredCardBank,
                    filterStar: $filterStar,
                    filterSuit: $filterSuit,
                    filterFavoritesOnly: $filterFavoritesOnly,
                    onSave: { name, cardIds in
                        profile.saveDeck(index: wrapper.index, name: name, cardIds: cardIds)
                        editingDeckIndex = nil
                    },
                    onCancel: { editingDeckIndex = nil }
                )
            }
        }
    }

    private func tabLabel(_ tab: Tab) -> String {
        switch tab {
        case .decks: return coordinator.L(.tabSavedDecks)
        case .bank: return coordinator.L(.tabCardBank)
        }
    }

    // MARK: Saved Decks tab

    private var savedDecksTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<profile.savedDecks.count, id: \.self) { index in
                    savedDeckRow(index: index)
                }
                startOverPanel
            }
            .padding()
        }
    }

    private func savedDeckRow(index: Int) -> some View {
        let deck = profile.savedDecks[index]
        let isActive = viewModel.options.activeDeckIndex == index
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                if deck.name.isEmpty {
                    Text(coordinator.L(.emptySlotFmt, index + 1)).foregroundStyle(.secondary)
                } else {
                    Text(deck.name).bold()
                }
                if isActive {
                    Text(coordinator.L(.deckActiveBadge)).font(.caption.bold()).foregroundStyle(.green)
                }
                Spacer()
                if !deck.name.isEmpty {
                    Button(coordinator.L(.deckSetActive)) {
                        viewModel.options.activeDeckIndex = index
                    }
                    .buttonStyle(.bordered)
                    .disabled(isActive)
                }
                Button(deck.name.isEmpty ? coordinator.L(.deckCreate) : coordinator.L(.edit)) {
                    editingDeckIndex = index
                }
                .buttonStyle(.bordered)
            }
            // Doubled from 44x62 — on a phone screen these were too small to read the
            // rank/suit at a glance, especially for the active deck a player checks most.
            HStack(spacing: 8) {
                ForEach(deck.cardIds, id: \.self) { cardId in
                    if let cardData = HoneycombDatabase.shared.card(id: cardId) {
                        HoneycombCardView(card: HoneycombCard(data: cardData, owner: .player),
                                          size: CGSize(width: 88, height: 124), isFlipped: false,
                                          useOwnershipColoring: false)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }

    private var startOverPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(coordinator.L(.startOverBody))
                .font(.footnote)
                .foregroundStyle(.white)
            Button(coordinator.L(.startOver), role: .destructive) {
                showStartOverConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .foregroundStyle(.black)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
        .alert(coordinator.L(.startOverTitle), isPresented: $showStartOverConfirmation) {
            Button(coordinator.L(.cancel), role: .cancel) {}
            Button(coordinator.L(.startOver), role: .destructive) { viewModel.startOver() }
        } message: {
            Text(coordinator.L(.startOverAlertBody))
        }
    }

    // MARK: Card Bank tab

    private var cardBankTab: some View {
        VStack(spacing: 8) {
            HStack {
                Text(coordinator.L(.cardBankCountFmt, profile.unlockedCardIds.count, HoneycombDatabase.shared.allCards.count))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            CardBankFilterBar(filterStar: $filterStar, filterSuit: $filterSuit, filterFavoritesOnly: $filterFavoritesOnly)
                .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                    ForEach(filteredCardBank, id: \.self) { cardId in
                        if let cardData = HoneycombDatabase.shared.card(id: cardId) {
                            Button {
                                profile.toggleFavorite(id: cardId)
                            } label: {
                                HoneycombCardView(card: HoneycombCard(data: cardData, owner: .player),
                                                  size: CGSize(width: 90, height: 127), isFlipped: false,
                                                  useOwnershipColoring: false)
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: "heart.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 16))
                                            .padding(6)
                                            .shadow(color: .white, radius: 2)
                                            .opacity(profile.favoriteCardIds.contains(cardId) ? 1 : 0)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
        }
    }

    struct DeckEditWrapper: Identifiable {
        let index: Int
        var id: Int { index }
    }
}

// MARK: - Filter bar (shared by the card bank tab and the deck builder)

private struct CardBankFilterBar: View {
    @Binding var filterStar: Int?
    @Binding var filterSuit: String?
    @Binding var filterFavoritesOnly: Bool
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                Button(coordinator.L(.allStarsFilter)) { filterStar = nil }
                ForEach(1...5, id: \.self) { star in
                    Button(coordinator.L(.starCountFmt, star)) { filterStar = star }
                }
            } label: {
                chip(filterStar.map { coordinator.L(.starCountFmt, $0) } ?? coordinator.L(.allStarsFilter))
            }

            Menu {
                Button(coordinator.L(.allSuitsFilter)) { filterSuit = nil }
                Button(coordinator.L(.suitSpades)) { filterSuit = "S" }
                Button(coordinator.L(.suitHearts)) { filterSuit = "H" }
                Button(coordinator.L(.suitDiamonds)) { filterSuit = "D" }
                Button(coordinator.L(.suitClubs)) { filterSuit = "C" }
            } label: {
                chip(suitLabel(filterSuit))
            }

            Button {
                filterFavoritesOnly.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: filterFavoritesOnly ? "heart.fill" : "heart")
                        .foregroundStyle(filterFavoritesOnly ? .red : .primary)
                    Text(coordinator.L(.favoritesFilter)).font(.caption.bold())
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(filterFavoritesOnly ? Color.red.opacity(0.15) : Color.black.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            if filterStar != nil || filterSuit != nil || filterFavoritesOnly {
                Button(coordinator.L(.clearFilters)) {
                    filterStar = nil
                    filterSuit = nil
                    filterFavoritesOnly = false
                }
                .font(.caption)
            }

            Spacer()
        }
    }

    private func chip(_ label: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption.bold())
            Image(systemName: "chevron.down").font(.system(size: 9))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func suitLabel(_ suit: String?) -> String {
        switch suit {
        case "S": return coordinator.L(.suitSpades)
        case "H": return coordinator.L(.suitHearts)
        case "D": return coordinator.L(.suitDiamonds)
        case "C": return coordinator.L(.suitClubs)
        default: return coordinator.L(.allSuitsFilter)
        }
    }
}

// MARK: - Deck builder

private struct DeckBuilderSheet: View {
    let index: Int
    let initialName: String
    let initialCardIds: [Int]
    let filteredCardBank: [Int]
    @Binding var filterStar: Int?
    @Binding var filterSuit: String?
    @Binding var filterFavoritesOnly: Bool
    let onSave: (String, [Int]) -> Void
    let onCancel: () -> Void
    @Environment(AppCoordinator.self) private var coordinator

    @State private var name: String = ""
    @State private var cardIds: [Int] = []
    @State private var validationError: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TextField(coordinator.L(.deckNamePlaceholderIos), text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: name) { validate() }

                    // A blank name is the #1 reason Save silently stays disabled — the
                    // rarity/length checks below don't cover it, so call it out on its
                    // own rather than leaving the player to guess why Save won't light up.
                    if name.isEmpty {
                        Text(coordinator.L(.enterDeckNameHint)).font(.footnote).foregroundStyle(.orange)
                    } else if let error = validationError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }

                    VStack(spacing: 8) {
                        Text(coordinator.L(.yourDeckCountFmt, cardIds.count))
                            .font(.headline)
                        HStack(spacing: 6) {
                            ForEach(0..<5, id: \.self) { i in
                                if i < cardIds.count {
                                    let cardId = cardIds[i]
                                    if let cardData = HoneycombDatabase.shared.card(id: cardId) {
                                        HoneycombCardView(card: HoneycombCard(data: cardData, owner: .player),
                                                          size: CGSize(width: 64, height: 90), isFlipped: false,
                                                          useOwnershipColoring: false)
                                            .onTapGesture {
                                                cardIds.remove(at: i)
                                                validate()
                                            }
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 64, height: 90)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(coordinator.L(.cardBankTapToAdd)).font(.headline)
                        Text(coordinator.L(.deckRulesHint))
                            .font(.caption).foregroundStyle(.secondary)
                        CardBankFilterBar(filterStar: $filterStar, filterSuit: $filterSuit, filterFavoritesOnly: $filterFavoritesOnly)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 10)], spacing: 10) {
                            ForEach(filteredCardBank, id: \.self) { cardId in
                                if let cardData = HoneycombDatabase.shared.card(id: cardId) {
                                    HoneycombCardView(card: HoneycombCard(data: cardData, owner: .player),
                                                      size: CGSize(width: 80, height: 113), isFlipped: false,
                                                      useOwnershipColoring: false)
                                        .opacity(cardIds.contains(cardId) ? 0.3 : 1.0)
                                        .onTapGesture {
                                            if !cardIds.contains(cardId) && cardIds.count < 5 {
                                                cardIds.append(cardId)
                                                validate()
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(coordinator.L(.deckBuilderTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(coordinator.L(.cancel), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(coordinator.L(.save)) { onSave(name, cardIds) }
                        .disabled(validationError != nil || cardIds.count != 5 || name.isEmpty || name.count > 20)
                }
            }
        }
        .onAppear {
            // A brand-new deck (empty slot) starts with no name — default it to
            // something already valid so Save doesn't require typing just to unlock,
            // mirroring "Empty Slot N" from the Saved Decks list.
            name = initialName.isEmpty ? coordinator.L(.deckSlotDefaultNameFmt, index + 1) : initialName
            cardIds = initialCardIds
            validate()
        }
    }

    private func validate() {
        let db = HoneycombDatabase.shared
        var fiveStars = 0
        var fourStars = 0
        for id in cardIds {
            if let card = db.card(id: id) {
                if card.stars == 5 { fiveStars += 1 }
                if card.stars == 4 { fourStars += 1 }
            }
        }
        if fiveStars > 1 {
            validationError = coordinator.L(.errTooMany5star)
        } else if fiveStars == 1 && fourStars > 1 {
            validationError = coordinator.L(.err5star4starCombo)
        } else if fiveStars == 0 && fourStars > 2 {
            validationError = coordinator.L(.errTooMany4star)
        } else if name.count > 20 {
            validationError = coordinator.L(.errNameTooLong)
        } else {
            validationError = nil
        }
    }
}
