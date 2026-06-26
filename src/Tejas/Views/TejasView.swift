import SwiftUI
import AppKit

public struct TejasView: View {
    var viewModel: TejasViewModel
    @State private var isShowingOptions = false
    @State private var isShowingStats = false
    @State private var raiseAmount: Int = 20
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator?

    public init(viewModel: TejasViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            viewModel.options.feltColor.primaryColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                toolbarView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                Divider().overlay(Color.white.opacity(0.2))

                ScrollView {
                    VStack(spacing: 16) {
                        // AI seats (top)
                        aiSeatsRow

                        // Community cards
                        communityCardsArea

                        // Pot + phase
                        potBanner

                        // Human hole cards
                        humanHoleCards

                        // Side pots (if any)
                        if !viewModel.state.sidePots.isEmpty {
                            sidePotDisplay
                        }

                        // Action panel
                        actionArea

                        // Hand over banner
                        if viewModel.state.currentPhase == .handOver {
                            handOverBanner
                        }

                        // Rebuy
                        if viewModel.sessionChips <= 0 {
                            rebuyBanner
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 820, minHeight: 640)
        .sheet(isPresented: $isShowingOptions) {
            TejasOptionsView(viewModel: viewModel, isShowingStats: $isShowingStats)
        }
        .sheet(isPresented: $isShowingStats) {
            TejasStatsView(viewModel: viewModel)
        }
        .onAppear {
            raiseAmount = viewModel.options.bigBlind
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: 16) {
            gameModeButtons
            Spacer()
            Text("Chips: \(viewModel.sessionChips)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.yellow)
            if viewModel.options.isTimed {
                Text(formatTime(viewModel.state.timerSeconds))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
            }
            if !viewModel.options.hideStatsButton {
                Button(action: { isShowingStats = true }) {
                    Text("Stats")
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            Button(action: { isShowingOptions = true }) {
                Text("Options")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .focusable(false)
        }
    }

    private var gameModeButtons: some View {
        Menu {
            Button(GameMode.klondike.rawValue) {
                if let coordinator = coordinator, coordinator.gameMode != .klondike {
                    coordinator.gameMode = .klondike
                    coordinator.startNewGame()
                }
            }
            Button(GameMode.beecell.rawValue) {
                if let coordinator = coordinator, coordinator.gameMode != .beecell {
                    coordinator.gameMode = .beecell
                    coordinator.startNewGame()
                }
            }
            Button(GameMode.spider.rawValue) {
                if let coordinator = coordinator, coordinator.gameMode != .spider {
                    coordinator.gameMode = .spider
                    coordinator.startNewGame()
                }
            }
            Divider()
            Button(GameMode.videoPoker.rawValue) {
                if let coordinator = coordinator, coordinator.gameMode != .videoPoker {
                    coordinator.gameMode = .videoPoker
                }
            }
        } label: {
            Text("Game Selection")
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.15))
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white, lineWidth: 1))
        .focusable(false)
    }

    // MARK: - AI Seats

    private var aiSeatsRow: some View {
        HStack(spacing: 12) {
            ForEach(viewModel.state.players.filter { $0.isAI }) { player in
                let idx = viewModel.state.players.firstIndex(where: { $0.id == player.id })
                TejasPlayerSeat(
                    player: player,
                    isActive: idx == viewModel.state.activePlayerIndex,
                    showCards: viewModel.state.currentPhase == .showdown || viewModel.state.currentPhase == .handOver
                )
            }
        }
    }

    // MARK: - Community Cards

    private var communityCardsArea: some View {
        VStack(spacing: 8) {
            Text("Community Cards")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { i in
                    if i < viewModel.state.communityCards.count {
                        CardView(card: viewModel.state.communityCards[i])
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            .frame(width: 77, height: 122)
                    }
                }
            }
        }
    }

    // MARK: - Pot Banner

    private var potBanner: some View {
        HStack(spacing: 20) {
            VStack(spacing: 2) {
                Text("Pot")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Text("\(viewModel.state.pot)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
            }

            Divider().frame(height: 30).overlay(Color.white.opacity(0.3))

            Text(phaseLabel)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }

    private var phaseLabel: String {
        switch viewModel.state.currentPhase {
        case .waiting:   return "Waiting..."
        case .preFlop:   return viewModel.options.noBetMode ? "Pre-Flop" : "Pre-Flop Betting"
        case .flop:      return "Flop"
        case .turn:      return "Turn"
        case .river:     return "River"
        case .showdown:  return "Showdown!"
        case .handOver:  return viewModel.state.lastWinnerName.map { "\($0) wins!" } ?? "Hand over"
        }
    }

    // MARK: - Human Hole Cards

    private var humanHoleCards: some View {
        VStack(spacing: 8) {
            if let human = viewModel.state.humanPlayer {
                Text("Your Hand")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))

                HStack(spacing: 16) {
                    ForEach(human.holeCards) { card in
                        CardView(card: card)
                    }
                }

                HStack(spacing: 8) {
                    Text(human.name)
                    Text("—")
                    Text("\(human.sessionChips) chips")
                    if human.isDealer { Text("(Dealer)").foregroundColor(.yellow) }
                    if human.isAllIn  { Text("ALL-IN").foregroundColor(.orange).fontWeight(.bold) }
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Side Pot Display

    private var sidePotDisplay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Side Pots:")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            ForEach(Array(viewModel.state.sidePots.enumerated()), id: \.offset) { idx, pot in
                Text("Side Pot \(idx + 1): \(pot.amount) (\(pot.eligiblePlayerIDs.count) eligible)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.25))
        .cornerRadius(6)
    }

    // MARK: - Action Area

    private var actionArea: some View {
        Group {
            switch viewModel.state.currentPhase {
            case .preFlop, .flop, .turn, .river:
                if viewModel.state.isHumanTurn {
                    bettingButtons
                } else {
                    Text("Waiting for AI...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            case .handOver:
                Button("Next Hand") {
                    viewModel.startNewHand()
                    raiseAmount = viewModel.options.bigBlind
                }
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.yellow)
                .cornerRadius(6)
                .buttonStyle(.plain)
            default:
                EmptyView()
            }
        }
    }

    private var bettingButtons: some View {
        VStack(spacing: 8) {
            if viewModel.options.noBetMode {
                // No-bet mode: check or fold only
                HStack(spacing: 12) {
                    tejasButton("Fold", color: .red.opacity(0.8)) {
                        viewModel.act(.fold)
                    }
                    tejasButton("Check", color: .blue.opacity(0.8)) {
                        viewModel.act(.check)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    tejasButton("Fold", color: .red.opacity(0.8)) {
                        viewModel.act(.fold)
                    }

                    let callAmt = viewModel.state.minimumBet - (viewModel.state.humanPlayer?.currentBet ?? 0)
                    if callAmt == 0 {
                        tejasButton("Check", color: .blue.opacity(0.8)) {
                            viewModel.act(.check)
                        }
                    } else {
                        tejasButton("Call \(callAmt)", color: .green.opacity(0.8)) {
                            viewModel.act(.call)
                        }
                    }

                    tejasButton("Raise \(raiseAmount)", color: .orange.opacity(0.8)) {
                        viewModel.act(.raise(raiseAmount))
                    }

                    let humanChips = viewModel.state.humanPlayer?.sessionChips ?? 0
                    if humanChips > 0 {
                        tejasButton("All-In", color: .purple.opacity(0.9)) {
                            viewModel.act(.raise(humanChips))
                        }
                    }
                }

                let minRaise = max(viewModel.state.lastRaiseAmount, viewModel.options.bigBlind)
                let humanChips = viewModel.state.humanPlayer?.sessionChips ?? minRaise
                Stepper("Raise: \(raiseAmount)", value: $raiseAmount, in: minRaise...max(minRaise, humanChips), step: viewModel.options.bigBlind)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
    }

    private func tejasButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(.system(.body, design: .monospaced))
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(6)
            .buttonStyle(.plain)
    }

    // MARK: - Hand Over Banner

    private var handOverBanner: some View {
        VStack(spacing: 6) {
            if let winner = viewModel.state.lastWinnerName {
                Text("\(winner) wins!")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)
            }
            if let handName = viewModel.state.lastWinningHand {
                Text(handName)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Rebuy

    private var rebuyBanner: some View {
        VStack(spacing: 8) {
            Text("Out of chips!")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.red)
            Button("Rebuy (+\(viewModel.options.startingChips) chips)") {
                viewModel.rebuy()
            }
            .font(.system(.body, design: .monospaced))
            .fontWeight(.bold)
            .foregroundColor(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.yellow)
            .cornerRadius(6)
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.black.opacity(0.4))
        .cornerRadius(10)
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// MARK: - Tejas Player Seat Sub-View

struct TejasPlayerSeat: View {
    let player: TejasPlayer
    let isActive: Bool
    let showCards: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Hole cards
            HStack(spacing: -12) {
                ForEach(0..<2, id: \.self) { i in
                    if i < player.holeCards.count {
                        let card = showCards
                            ? Card(id: player.holeCards[i].id, suit: player.holeCards[i].suit, rank: player.holeCards[i].rank, faceUp: true)
                            : Card(suit: .spades, rank: 1, faceUp: false)
                        CardView(card: card)
                            .scaleEffect(0.45)
                            .frame(width: 40, height: 60)
                    }
                }
            }
            .frame(height: 60)

            HStack(spacing: 4) {
                if player.isDealer {
                    Text("D")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(3)
                        .background(Color.yellow)
                        .clipShape(Circle())
                }
                Text(player.name)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(isActive ? .yellow : .white)
            }

            if player.isFolded {
                Text("Folded")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.red.opacity(0.8))
            } else if player.isAllIn {
                Text("ALL-IN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            } else {
                Text("\(player.sessionChips)¢")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            if player.currentBet > 0 {
                Text("Bet: \(player.currentBet)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.green.opacity(0.9))
            }
        }
        .padding(8)
        .background(isActive ? Color.yellow.opacity(0.15) : Color.black.opacity(0.2))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(isActive ? Color.yellow : Color.white.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Options View

struct TejasOptionsView: View {
    @Bindable var viewModel: TejasViewModel
    @Binding var isShowingStats: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var seatCount: Int
    @State private var startingChips: Int
    @State private var smallBlind: Int
    @State private var bigBlind: Int
    @State private var aiDifficulty: AIDifficulty
    @State private var noBetMode: Bool
    @State private var isTimed: Bool
    @State private var isSoundEnabled: Bool
    @State private var hideHintButton: Bool
    @State private var hideStatsButton: Bool
    @State private var isDarkMode: Bool
    @State private var feltColor: FeltColorTheme
    @State private var cardBackTheme: String
    @State private var customSelectedColor: Color

    let originalRed: Double
    let originalGreen: Double
    let originalBlue: Double

    init(viewModel: TejasViewModel, isShowingStats: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingStats = isShowingStats
        _seatCount     = State(initialValue: viewModel.options.seatCount)
        _startingChips = State(initialValue: viewModel.options.startingChips)
        _smallBlind    = State(initialValue: viewModel.options.smallBlind)
        _bigBlind      = State(initialValue: viewModel.options.bigBlind)
        _aiDifficulty  = State(initialValue: viewModel.options.aiDifficulty)
        _noBetMode     = State(initialValue: viewModel.options.noBetMode)
        _isTimed         = State(initialValue: viewModel.options.isTimed)
        _isSoundEnabled  = State(initialValue: viewModel.options.isSoundEnabled)
        _hideHintButton  = State(initialValue: viewModel.options.hideHintButton)
        _hideStatsButton = State(initialValue: viewModel.options.hideStatsButton)
        _isDarkMode      = State(initialValue: viewModel.options.isDarkMode)
        _feltColor       = State(initialValue: viewModel.options.feltColor)
        _cardBackTheme   = State(initialValue: viewModel.options.cardBackTheme)

        let r = UserDefaults.standard.double(forKey: "custom_felt_red")
        let g = UserDefaults.standard.double(forKey: "custom_felt_green")
        let b = UserDefaults.standard.double(forKey: "custom_felt_blue")
        self.originalRed = r; self.originalGreen = g; self.originalBlue = b
        let initialColor: Color = (r == 0 && g == 0 && b == 0)
            ? Color(red: 0.35, green: 0.15, blue: 0.45)
            : Color(red: r, green: g, blue: b)
        _customSelectedColor = State(initialValue: initialColor)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Tejas Hold'em Preferences")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .padding(.top, 12)

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {

                    // ── Poker-specific ──
                    Picker("Players:", selection: $seatCount) {
                        ForEach(2...6, id: \.self) { n in Text("\(n)").tag(n) }
                    }
                    .pickerStyle(.segmented)

                    Picker("AI Difficulty:", selection: $aiDifficulty) {
                        ForEach(AIDifficulty.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper("Starting Chips: \(startingChips)", value: $startingChips, in: 100...10000, step: 100)
                        .font(.system(.body, design: .monospaced))

                    Stepper("Small Blind: \(smallBlind)", value: $smallBlind, in: 5...1000, step: 5)
                        .font(.system(.body, design: .monospaced))

                    Stepper("Big Blind: \(bigBlind)", value: $bigBlind, in: 10...2000, step: 10)
                        .font(.system(.body, design: .monospaced))

                    Toggle("No Bet Mode", isOn: $noBetMode).font(.system(.body, design: .monospaced))

                    Divider()

                    // ── Shared toggles ──
                    Toggle("Timed Game", isOn: $isTimed).font(.system(.body, design: .monospaced))
                    Toggle("Sound Effects", isOn: $isSoundEnabled).font(.system(.body, design: .monospaced))
                    Toggle("Hide Hint button", isOn: $hideHintButton).font(.system(.body, design: .monospaced))
                    Toggle("Hide Stats button", isOn: $hideStatsButton).font(.system(.body, design: .monospaced))
                    Toggle("Dark Mode Cards", isOn: $isDarkMode).font(.system(.body, design: .monospaced))

                    Divider()

                    // ── Felt ──
                    Picker("Felt Color:", selection: $feltColor) {
                        Text("Felt Green").tag(FeltColorTheme.feltGreen)
                        Text("Crimson").tag(FeltColorTheme.crimson)
                        Text("Royal Blue").tag(FeltColorTheme.royalBlue)
                        Text("Charcoal").tag(FeltColorTheme.charcoal)
                        Text("Desert").tag(FeltColorTheme.desert)
                        Text("Custom").tag(FeltColorTheme.custom)
                    }
                    .font(.system(.body, design: .monospaced))

                    if feltColor == .custom {
                        ColorPicker("Custom Color:", selection: $customSelectedColor)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: customSelectedColor) { _, newColor in
                                let nsColor = NSColor(newColor)
                                if let rgb = nsColor.usingColorSpace(.deviceRGB) {
                                    UserDefaults.standard.set(Double(rgb.redComponent),   forKey: "custom_felt_red")
                                    UserDefaults.standard.set(Double(rgb.greenComponent), forKey: "custom_felt_green")
                                    UserDefaults.standard.set(Double(rgb.blueComponent),  forKey: "custom_felt_blue")
                                }
                            }
                    }

                    Divider()

                    CustomArtPanelView(cardBackTheme: $cardBackTheme, feltColor: $feltColor)
                }
                .padding(.horizontal, 24)
            }
            .frame(maxHeight: 680)

            Divider()

            HStack {
                Button("Cancel") {
                    UserDefaults.standard.set(originalRed,   forKey: "custom_felt_red")
                    UserDefaults.standard.set(originalGreen, forKey: "custom_felt_green")
                    UserDefaults.standard.set(originalBlue,  forKey: "custom_felt_blue")
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isShowingStats = true }
                }) {
                    Text("View Stats").foregroundColor(.blue).underline()
                }
                .buttonStyle(.plain)
                .font(.system(.body, design: .monospaced))

                Spacer()

                Button("OK") {
                    var o = viewModel.options
                    o.seatCount      = seatCount
                    o.startingChips  = startingChips
                    o.smallBlind     = smallBlind
                    o.bigBlind       = bigBlind
                    o.aiDifficulty   = aiDifficulty
                    o.noBetMode      = noBetMode
                    o.isTimed        = isTimed
                    o.isSoundEnabled = isSoundEnabled
                    o.hideHintButton = hideHintButton
                    o.hideStatsButton = hideStatsButton
                    o.isDarkMode     = isDarkMode
                    o.feltColor      = feltColor
                    o.cardBackTheme  = cardBackTheme
                    o.customFeltColorRevision += 1
                    viewModel.options = o
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 440)
    }
}

// MARK: - Stats View

struct TejasStatsView: View {
    var viewModel: TejasViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Tejas Hold'em Statistics")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .padding(.top, 16)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                statRow("Hands Played", "\(viewModel.statistics.handsPlayed)")
                statRow("Hands Won",    "\(viewModel.statistics.handsWon)")
                statRow("Win Rate",     String(format: "%.1f%%", viewModel.statistics.winRate * 100))
                statRow("Biggest Pot",  "\(viewModel.statistics.biggestPotWon)")
                statRow("Rebuys",       "\(viewModel.statistics.rebuyCount)")
            }
            .padding(.horizontal, 24)

            Divider()

            HStack {
                Button("Reset Stats") { viewModel.resetStatistics() }
                    .foregroundColor(.red)
                    .font(.system(.body, design: .monospaced))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .font(.system(.body, design: .monospaced))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 320)
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(.body, design: .monospaced))
            Spacer()
            Text(value).font(.system(.body, design: .monospaced)).fontWeight(.bold)
        }
    }
}
