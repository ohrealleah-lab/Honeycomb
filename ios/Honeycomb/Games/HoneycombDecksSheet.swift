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

    // Mobile counterpart to mac's freeform stat search (type a value onto a mini card
    // graphic) — no room for that here, so four dropdowns instead. nil = "Any"/don't
    // filter that side; 1-9 direct, 10 = "A". Only ever read by statSearchedCardBank
    // below, which backs just the main Card Bank browse grid — Deck Builder's embedded
    // grid keeps using plain filteredCardBank, matching mac's separation.
    @State private var filterStatTop: Int? = nil
    @State private var filterStatRight: Int? = nil
    @State private var filterStatBottom: Int? = nil
    @State private var filterStatLeft: Int? = nil

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

    // Index order [Top, Right, Bottom, Left] matches HoneycombCardData.stats
    // (see HoneycombCardView's stats[0]/[1]/[2]/[3] usage) — same order mac's
    // statFilters uses, independent of whatever order the dropdowns are laid out in.
    private var statFilters: [Int?] {
        [filterStatTop, filterStatRight, filterStatBottom, filterStatLeft]
    }

    // AND across every filled-in side: a card survives only if each filled side is
    // within ±2 of its stat (exact or near). Exact-only matches (every filled side
    // dead-on) sort first; anything relying on the ±2 tolerance sorts after and is
    // reported in `near` so the grid can render it dimmed. Mirrors mac's
    // statSearchedCardBank exactly.
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
                Spacer()
                if !deck.name.isEmpty {
                    Button(isActive ? coordinator.L(.deckActiveBadge) : coordinator.L(.deckSetActive)) {
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

            statFilterRow
                .padding(.horizontal)

            ScrollView {
                let searched = statSearchedCardBank
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                    ForEach(searched.ids, id: \.self) { cardId in
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
                                    // Cards that only matched via the ±2 tolerance (not an
                                    // exact hit on every filled dropdown) render dimmed —
                                    // mirrors mac's freeform stat search.
                                    .opacity(searched.near.contains(cardId) ? 0.4 : 1.0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var statFilterRow: some View {
        HStack(spacing: 10) {
            statDropdown(coordinator.L(.statPositionTop), value: $filterStatTop)
            statDropdown(coordinator.L(.statPositionBottom), value: $filterStatBottom)
            statDropdown(coordinator.L(.statPositionLeft), value: $filterStatLeft)
            statDropdown(coordinator.L(.statPositionRight), value: $filterStatRight)
            Spacer()
        }
    }

    private func statDropdown(_ label: String, value: Binding<Int?>) -> some View {
        Menu {
            Button(coordinator.L(.statFilterAny)) { value.wrappedValue = nil }
            ForEach(1...10, id: \.self) { v in
                Button(statValueLabel(v)) { value.wrappedValue = v }
            }
        } label: {
            HStack(spacing: 4) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Text(value.wrappedValue.map(statValueLabel) ?? coordinator.L(.statFilterAny))
                    .font(.caption.bold())
                Image(systemName: "chevron.down").font(.system(size: 9))
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func statValueLabel(_ value: Int) -> String {
        value >= 10 ? "A" : "\(value)"
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
