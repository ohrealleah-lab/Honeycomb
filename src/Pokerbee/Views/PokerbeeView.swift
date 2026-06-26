import SwiftUI
import AppKit

public struct PokerbeeView: View {
    var viewModel: PokerbeeViewModel
    @State private var isShowingOptions = false
    @State private var isShowingStats = false
    @State private var raiseAmount: Int = 20
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator?

    public init(viewModel: PokerbeeViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            viewModel.options.feltColor.primaryColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top toolbar
                toolbarView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                Divider().overlay(Color.white.opacity(0.2))

                ScrollView {
                    VStack(spacing: 20) {
                        // AI opponents row
                        aiSeatsRow

                        // Pot + phase banner
                        potBanner

                        // Human hand
                        humanHandArea

                        // Action buttons (human turn) or status
                        actionArea

                        // Result banner (hand over)
                        if viewModel.state.currentPhase == .handOver {
                            handOverBanner
                        }

                        // Rebuy prompt
                        if viewModel.sessionChips <= 0 {
                            rebuyBanner
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 760, minHeight: 600)
        .sheet(isPresented: $isShowingOptions) {
            PokerbeeOptionsView(viewModel: viewModel, isShowingStats: $isShowingStats)
        }
        .sheet(isPresented: $isShowingStats) {
            PokerbeeStatsView(viewModel: viewModel)
        }
        .onAppear {
            raiseAmount = viewModel.options.ante * 2
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: 16) {
            // Game mode switcher
            gameModeButtons

            Spacer()

            // Session info
            Text("Chips: \(viewModel.sessionChips)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.yellow)

            if viewModel.options.isTimed {
                Text(formatTime(viewModel.state.timerSeconds))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
            }

            // Stats
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

            // Options
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

    // MARK: - AI Seats Row

    private var aiSeatsRow: some View {
        HStack(spacing: 16) {
            ForEach(viewModel.state.players.filter { $0.isAI }) { player in
                PokerSeatView(
                    player: player,
                    isActive: viewModel.state.activePlayerIndex == viewModel.state.players.firstIndex(where: { $0.id == player.id }),
                    showCards: viewModel.state.currentPhase == .showdown || viewModel.state.currentPhase == .handOver
                )
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Pot Banner

    private var potBanner: some View {
        VStack(spacing: 4) {
            Text("Pot: \(viewModel.state.pot)")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)

            Text(phaseLabel)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 24)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }

    private var phaseLabel: String {
        switch viewModel.state.currentPhase {
        case .waiting:          return "Waiting..."
        case .dealing:          return "Dealing..."
        case .preDrawBetting:   return "Pre-Draw Betting"
        case .drawing:          return "Draw Phase — select cards to discard"
        case .postDrawBetting:  return "Post-Draw Betting"
        case .showdown:         return "Showdown!"
        case .handOver:         return viewModel.state.lastWinnerName.map { "\($0) wins!" } ?? "Hand over"
        }
    }

    // MARK: - Human Hand Area

    private var humanHandArea: some View {
        VStack(spacing: 12) {
            if let human = viewModel.state.humanPlayer {
                Text("Your Hand")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))

                HStack(spacing: 12) {
                    ForEach(Array(human.hand.enumerated()), id: \.offset) { idx, card in
                        let isSelected = viewModel.state.selectedDiscardIndices.contains(idx)
                        CardView(card: card)
                            .offset(y: isSelected ? -12 : 0)
                            .animation(.easeInOut(duration: 0.15), value: isSelected)
                            .onTapGesture {
                                if viewModel.state.currentPhase == .drawing {
                                    toggleDiscard(index: idx)
                                }
                            }
                            .overlay(
                                isSelected ? RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.yellow, lineWidth: 2) : nil
                            )
                    }
                }

                Text("\(human.name) — \(human.sessionChips) chips")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private func toggleDiscard(index: Int) {
        if viewModel.state.selectedDiscardIndices.contains(index) {
            viewModel.state.selectedDiscardIndices.remove(index)
        } else {
            viewModel.state.selectedDiscardIndices.insert(index)
        }
    }

    // MARK: - Action Area

    private var actionArea: some View {
        VStack(spacing: 12) {
            switch viewModel.state.currentPhase {
            case .preDrawBetting, .postDrawBetting:
                if viewModel.state.isHumanTurn {
                    bettingButtons
                } else {
                    Text("Waiting for AI...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }

            case .drawing:
                VStack(spacing: 8) {
                    Text("Select cards to discard, then tap Draw.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))

                    Button("Draw (\(viewModel.state.selectedDiscardIndices.count) card\(viewModel.state.selectedDiscardIndices.count == 1 ? "" : "s"))") {
                        viewModel.submitDiscards(Array(viewModel.state.selectedDiscardIndices))
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

            case .handOver:
                Button("Next Hand") {
                    viewModel.startNewHand()
                    raiseAmount = viewModel.options.ante * 2
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
            HStack(spacing: 12) {
                pokerButton("Fold", color: .red.opacity(0.8)) {
                    viewModel.act(.fold)
                }

                let callAmt = viewModel.state.currentBetAmount - (viewModel.state.humanPlayer?.currentBet ?? 0)
                if callAmt == 0 {
                    pokerButton("Check", color: .blue.opacity(0.8)) {
                        viewModel.act(.check)
                    }
                } else {
                    pokerButton("Call \(callAmt)", color: .green.opacity(0.8)) {
                        viewModel.act(.call)
                    }
                }

                pokerButton("Raise \(raiseAmount)", color: .orange.opacity(0.8)) {
                    viewModel.act(.raise(raiseAmount))
                }
            }

            Stepper("Raise amount: \(raiseAmount)", value: $raiseAmount, in: viewModel.options.ante...viewModel.sessionChips, step: viewModel.options.ante)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    private func pokerButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(.system(.body, design: .monospaced))
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
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

    // MARK: - Rebuy Banner

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

// MARK: - Seat Sub-View

struct PokerSeatView: View {
    let player: PokerbeePlayer
    let isActive: Bool
    let showCards: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Cards (face-down placeholders or revealed)
            HStack(spacing: -20) {
                ForEach(0..<max(1, player.hand.count), id: \.self) { i in
                    if showCards && i < player.hand.count {
                        CardView(card: player.hand[i])
                            .scaleEffect(0.5)
                            .frame(width: 44, height: 66)
                    } else if i < player.hand.count {
                        CardView(card: Card(suit: .spades, rank: 1, faceUp: false))
                            .scaleEffect(0.5)
                            .frame(width: 44, height: 66)
                    }
                }
            }
            .frame(height: 66)

            Text(player.name)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(isActive == true ? .yellow : .white)

            if player.isFolded {
                Text("Folded")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.red.opacity(0.8))
            } else {
                Text("\(player.sessionChips)¢")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(8)
        .background(isActive == true ? Color.yellow.opacity(0.15) : Color.black.opacity(0.2))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive == true ? Color.yellow : Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Options View

struct PokerbeeOptionsView: View {
    @Bindable var viewModel: PokerbeeViewModel
    @Binding var isShowingStats: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var seatCount: Int
    @State private var startingChips: Int
    @State private var ante: Int
    @State private var aiDifficulty: AIDifficulty
    @State private var noBidMode: Bool
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

    init(viewModel: PokerbeeViewModel, isShowingStats: Binding<Bool>) {
        self.viewModel = viewModel
        self._isShowingStats = isShowingStats
        _seatCount     = State(initialValue: viewModel.options.seatCount)
        _startingChips = State(initialValue: viewModel.options.startingChips)
        _ante          = State(initialValue: viewModel.options.ante)
        _aiDifficulty  = State(initialValue: viewModel.options.aiDifficulty)
        _noBidMode     = State(initialValue: viewModel.options.noBidMode)
        _isTimed       = State(initialValue: viewModel.options.isTimed)
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
            Text("Pokerbee Preferences")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .padding(.top, 12)

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {

                    // ── Poker-specific section ──
                    Picker("Players:", selection: $seatCount) {
                        ForEach(2...6, id: \.self) { n in Text("\(n)").tag(n) }
                    }
                    .pickerStyle(.segmented)
                    .font(.system(.body, design: .monospaced))

                    Picker("AI Difficulty:", selection: $aiDifficulty) {
                        ForEach(AIDifficulty.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .font(.system(.body, design: .monospaced))

                    Stepper("Starting Chips: \(startingChips)", value: $startingChips, in: 100...10000, step: 100)
                        .font(.system(.body, design: .monospaced))

                    Stepper("Ante: \(ante)", value: $ante, in: 0...500, step: 5)
                        .font(.system(.body, design: .monospaced))

                    Toggle("No Bid Mode", isOn: $noBidMode)
                        .font(.system(.body, design: .monospaced))

                    Divider()

                    // ── Shared toggles ──
                    Toggle("Timed Game", isOn: $isTimed)
                        .font(.system(.body, design: .monospaced))
                    Toggle("Sound Effects", isOn: $isSoundEnabled)
                        .font(.system(.body, design: .monospaced))
                    Toggle("Hide Hint button", isOn: $hideHintButton)
                        .font(.system(.body, design: .monospaced))
                    Toggle("Hide Stats button", isOn: $hideStatsButton)
                        .font(.system(.body, design: .monospaced))
                    Toggle("Dark Mode Cards", isOn: $isDarkMode)
                        .font(.system(.body, design: .monospaced))

                    Divider()

                    // ── Felt color ──
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

                    // ── Custom card art ──
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
                    o.ante           = ante
                    o.aiDifficulty   = aiDifficulty
                    o.noBidMode      = noBidMode
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

struct PokerbeeStatsView: View {
    var viewModel: PokerbeeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Pokerbee Statistics")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .padding(.top, 16)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                statRow("Hands Played",   "\(viewModel.statistics.handsPlayed)")
                statRow("Hands Won",      "\(viewModel.statistics.handsWon)")
                statRow("Win Rate",       String(format: "%.1f%%", viewModel.statistics.winRate * 100))
                statRow("Biggest Pot",    "\(viewModel.statistics.biggestPotWon)")
                statRow("Rebuys",         "\(viewModel.statistics.rebuyCount)")
            }
            .padding(.horizontal, 24)

            Divider()

            HStack {
                Button("Reset Stats") {
                    viewModel.resetStatistics()
                }
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
            Text(label)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
        }
    }
}
