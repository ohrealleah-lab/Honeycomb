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
    // Forces a re-render once CustomBackgroundManager finishes async-sampling a
    // wallpaper's dominant color (see coordinator.currentAccentTint), same pattern
    // BackgroundLayerView already uses for its own async image load. Merely changing
    // this @State is enough to make SwiftUI re-evaluate body — not .id()-ing the view,
    // which would also reset in-progress state like the deck-name TextField/filters.
    @State private var accentColorTrigger: UUID = UUID()

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
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .frame(width: 18, height: 18)
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
            Text(coordinator.L(.statSearchHint))
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
            .frame(maxWidth: .infinity, alignment: .center)
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
                    Text(coordinator.L(.sheetTitleMac))
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    Button(coordinator.L(.done)) { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()

                Divider()

                HStack(spacing: 0) {
                    // Left: freeform stat search, then Saved Decks
                    VStack(alignment: .leading, spacing: 10) {
                        statSearchWidget

                        Text(coordinator.L(.savedDecksHeader))
                            .font(.caption).bold()
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)

                        // startOverPanel now scrolls along with the deck list instead of
                        // sitting pinned below it — pinned, it ate into the ScrollView's
                        // own height and cut off the last deck row before you could even
                        // scroll to it.
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(0..<profile.savedDecks.count, id: \.self) { index in
                                    savedDeckRow(index: index)
                                }

                                startOverPanel
                            }
                            // Transparent gaps between rows don't hit-test by default on
                            // macOS — without this, scrolling with the pointer over one of
                            // those gaps (rather than directly on a row) silently did
                            // nothing instead of scrolling the list.
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .padding()
                    .frame(width: leftWidth, alignment: .top)

                    Divider()

                    // Right: Card Bank
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(coordinator.L(.cardBankCountFmt, profile.unlockedCardIds.count, HoneycombDatabase.shared.allCards.count))
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
                            // Transparent gaps between cards don't hit-test by default on
                            // macOS — without this, scrolling with the pointer over a gap
                            // (rather than directly on a card) silently did nothing instead
                            // of scrolling the grid.
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .background {
                        // Matches the Stats/Rules/Options watermark treatment — fixed max
                        // size, and attached to this whole column (not inside the ScrollView
                        // above) so it stays put behind the title/filter bar/card grid
                        // instead of scrolling away with the cards.
                        if let image = NSImage(named: "Solibee") {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 550, maxHeight: 550)
                                .opacity(0.15)
                        }
                    }
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CustomBackgroundLoaded"))) { _ in
            accentColorTrigger = UUID()
        }
    }

    private var startOverPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(coordinator.L(.startOverBody))
                .foregroundColor(.white)

            Button(coordinator.L(.startOver)) {
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
        .alert(coordinator.L(.startOverTitle), isPresented: $showStartOverConfirmation) {
            Button(coordinator.L(.cancel), role: .cancel) {}
            Button(coordinator.L(.startOver), role: .destructive) { performStartOver() }
        } message: {
            Text(coordinator.L(.startOverAlertBody))
        }
    }

    private func savedDeckRow(index: Int) -> some View {
        let deck = profile.savedDecks[index]
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                if deck.name.isEmpty {
                    Text(coordinator.L(.emptySlotFmt, index + 1)).foregroundColor(.secondary)
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
                    Button(activeDeckIndex == index ? coordinator.L(.deckActiveBadge) : coordinator.L(.deckSetActive)) {
                        activeDeckIndex = index
                    }
                    .buttonStyle(.bordered)
                    .disabled(activeDeckIndex == index)
                }
                Button(deck.name.isEmpty ? coordinator.L(.deckCreate) : coordinator.L(.edit)) {
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
        // Active deck gets the same accent background/border treatment as the Deck
        // Builder's "Your Deck" tray, instead of the same flat black tint every deck
        // (active or not) previously used — matches the Windows port. currentAccentTint
        // (not currentFeltColor) so an active wallpaper theme's sampled dominant color
        // shows here too, not just a felt color that may be unrelated to what's active.
        .background(activeDeckIndex == index ? coordinator.currentAccentTint.opacity(0.5) : Color.black.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(activeDeckIndex == index ? coordinator.currentAccentTint : .clear, lineWidth: 2)
        )
    }

    private var cardBankFilterBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button(coordinator.L(.allStarsFilter)) { filterStar = nil }
                ForEach(1...5, id: \.self) { star in
                    Button(coordinator.L(.starCountFmt, star)) { filterStar = star }
                }
            } label: {
                filterChip(label: filterStar.map { coordinator.L(.starCountFmt, $0) } ?? coordinator.L(.allStarsFilter))
            }

            Menu {
                Button(coordinator.L(.allSuitsFilter)) { filterSuit = nil }
                Button(coordinator.L(.suitSpades)) { filterSuit = "S" }
                Button(coordinator.L(.suitHearts)) { filterSuit = "H" }
                Button(coordinator.L(.suitDiamonds)) { filterSuit = "D" }
                Button(coordinator.L(.suitClubs)) { filterSuit = "C" }
            } label: {
                filterChip(label: filterSuit.map { suitLabel($0) } ?? coordinator.L(.allSuitsFilter))
            }

            Button {
                filterFavoritesOnly.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: filterFavoritesOnly ? "heart.fill" : "heart")
                        .foregroundColor(filterFavoritesOnly ? .red : .primary)
                    Text(coordinator.L(.favoritesFilter)).font(.caption).bold()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(filterFavoritesOnly ? Color.red.opacity(0.12) : Color.black.opacity(0.08))
                .cornerRadius(8)
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
        case "S": return coordinator.L(.suitSpades)
        case "H": return coordinator.L(.suitHearts)
        case "D": return coordinator.L(.suitDiamonds)
        case "C": return coordinator.L(.suitClubs)
        default: return suit
        }
    }

    @ViewBuilder
    private func deckBuilder(wrapper: DeckEditWrapper) -> some View {
        VStack(spacing: 20) {
            Text(coordinator.L(.deckBuilderTitle)).font(.largeTitle).bold()

            TextField(coordinator.L(.deckNamePlaceholder), text: $newDeckName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)

            if let error = validationError {
                Text(error).foregroundColor(.red).font(.subheadline)
            }

            // Current Deck
            VStack {
                Text(coordinator.L(.yourDeckCountFmt, editingDeckCards.count)).font(.headline)
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
            // App-wide accent tint (AppCoordinator.currentAccentTint — felt color, or a
            // wallpaper theme's sampled dominant color when one's active) instead of a
            // fixed blue tint, so the tray reads as "your active area" against whatever
            // the active theme actually looks like, rather than blending into the sheet.
            .background(coordinator.currentAccentTint.opacity(0.5))
            .cornerRadius(12)

            // Card Bank for Selection — shares the same suit/star filter as the main view.
            VStack(alignment: .leading, spacing: 8) {
                Text(coordinator.L(.cardBankTapToAdd)).font(.headline)
                Text(coordinator.L(.deckRulesHint))
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
                                            Button(coordinator.L(.contextRemoveFromDeck)) {
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
                Button(coordinator.L(.cancel)) { editingDeckIndex = nil }
                Button(coordinator.L(.btnSaveDeck)) {
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
            validationError = coordinator.L(.errTooMany5star)
        } else if fiveStars == 1 && fourStars > 1 {
            validationError = coordinator.L(.err5star4starCombo)
        } else if fiveStars == 0 && fourStars > 2 {
            validationError = coordinator.L(.errTooMany4star)
        } else if newDeckName.count > 20 {
            validationError = coordinator.L(.errNameTooLong)
        } else {
            validationError = nil
        }
    }

    struct DeckEditWrapper: Identifiable {
        let index: Int
        var id: Int { index }
    }
}
