import SwiftUI
import UIKit

/// Touch-first Blackjack for iPhone/iPad, driven by the shared BlackjackViewModel.
/// Button-driven (no drags): dealer row on top (hole card face-down until dealer's
/// turn), player hand(s) below, action buttons (Hit/Stand/Double/Split) replace the
/// bet controls once a hand is in progress. Supports the split-hands display.
struct BlackjackTouchView: View {
    @Bindable var viewModel: BlackjackViewModel
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    @State private var isMenuOpen = false
    @State private var showingStats = false

    private let actionHaptic = UIImpactFeedbackGenerator(style: .medium)

    private var canAffordBet: Bool {
        viewModel.isFreePlay || viewModel.state.sessionCredits >= max(viewModel.state.currentBet, 1)
    }

    var body: some View {
        GeometryReader { geo in
            let cardW = min((geo.size.width - 32) / 6, 90)

            ZStack {
                coordinator.currentFeltColor.ignoresSafeArea()

                // ScrollView fallback rather than a computed shrink factor — a split
                // stacks a second hand below the first, and landscape's shorter height
                // can't always fit dealer + two hands + controls. Scrolling beats
                // clipping the action buttons off the bottom; portrait already fits
                // without scrolling in the common case.
                ScrollView {
                    VStack(spacing: 16) {
                        topBar
                            .padding(.horizontal, 12)
                            .frame(height: 44)

                        dealerArea(cardW: cardW)

                        resultBanner

                        Spacer(minLength: 4)

                        playerHandsArea(cardW: cardW)

                        Spacer(minLength: 4)

                        controls
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                    .frame(minHeight: geo.size.height)
                }

                SlideDownMenu(isOpen: $isMenuOpen, coordinator: coordinator) {
                    showingStats = true
                } gameSettings: {
                    BlackjackSettingsSection(viewModel: viewModel,
                                             canOpenOptions: viewModel.canOpenOptions)
                }
            }
        }
        .environment(\.activeCardBackTheme, coordinator.cardBackTheme)
        .sheet(isPresented: $showingStats) { BlackjackStatsSheet(viewModel: viewModel) }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                isMenuOpen = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Menu")

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "creditcard")
                Text(viewModel.isFreePlay ? "Free Play" : "\(viewModel.state.sessionCredits)")
            }
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(.yellow)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.35), in: Capsule())

            Spacer()

            Text("Blackjack")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: Dealer

    private func dealerArea(cardW: CGFloat) -> some View {
        VStack(spacing: 6) {
            Text(dealerLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 6) {
                if viewModel.state.dealerCards.isEmpty {
                    ForEach(0..<2, id: \.self) { _ in
                        HoneycombSimpleCardBack().frame(width: cardW, height: cardW * 181.0 / 128.0)
                    }
                } else {
                    ForEach(Array(viewModel.state.dealerCards.enumerated()), id: \.offset) { _, card in
                        TouchCardView(card: card, width: cardW)
                    }
                }
            }
        }
    }

    private var dealerLabel: String {
        guard !viewModel.state.dealerCards.isEmpty else { return "DEALER" }
        let value = viewModel.state.phase == .playing ? viewModel.state.dealerVisibleValue : viewModel.state.dealerValue
        return "DEALER  \(value)"
    }

    // MARK: Player hand(s)

    private func playerHandsArea(cardW: CGFloat) -> some View {
        VStack(spacing: 18) {
            ForEach(Array(viewModel.state.playerHands.enumerated()), id: \.offset) { i, hand in
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        if viewModel.state.playerHands.count > 1 {
                            Circle()
                                .fill(i == viewModel.state.activeHandIndex && viewModel.state.phase == .playing
                                      ? Color.yellow : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                        Text("\(handLabel(hand, index: i))  \(hand.value)\(hand.isBust ? " BUST" : "")")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(hand.isBust ? .red : .white)
                        if let result = hand.result {
                            Text(resultText(result))
                                .font(.caption.weight(.black))
                                .foregroundStyle(resultColor(result))
                        }
                    }
                    HStack(spacing: 6) {
                        ForEach(Array(hand.cards.enumerated()), id: \.offset) { _, card in
                            TouchCardView(card: card, width: cardW)
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    (i == viewModel.state.activeHandIndex && viewModel.state.phase == .playing && viewModel.state.playerHands.count > 1)
                        ? Color.black.opacity(0.25) : .clear,
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
        }
    }

    private func handLabel(_ hand: BlackjackHand, index: Int) -> String {
        viewModel.state.playerHands.count > 1 ? "HAND \(index + 1)" : "YOU"
    }

    private func resultText(_ result: BlackjackHandResult) -> String {
        switch result {
        case .win: return "WIN"
        case .loss: return "LOSS"
        case .push: return "PUSH"
        case .blackjack: return "BLACKJACK!"
        case .bust: return "BUST"
        }
    }

    private func resultColor(_ result: BlackjackHandResult) -> Color {
        switch result {
        case .win, .blackjack: return .yellow
        case .push: return .white
        case .loss, .bust: return .red.opacity(0.9)
        }
    }

    private var resultBanner: some View {
        Group {
            if viewModel.state.phase == .result, !viewModel.state.lastResultSummary.isEmpty {
                Text(viewModel.state.lastResultSummary)
                    .font(.title3.weight(.black))
                    .foregroundStyle(viewModel.state.lastNetResult > 0 ? .yellow : .white.opacity(0.85))
            } else {
                Text(" ").font(.title3.weight(.black))
            }
        }
        .frame(height: 28)
    }

    // MARK: Controls

    private var controls: some View {
        Group {
            switch viewModel.state.phase {
            case .betting:
                bettingControls
            case .playing:
                actionControls
            case .dealerTurn:
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
            case .result:
                if viewModel.canRebuy {
                    rebuyControl
                } else {
                    bettingControls
                }
            }
        }
    }

    private var bettingControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 0) {
                    Button {
                        viewModel.clearBet()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    Text("BET \(viewModel.state.currentBet)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .frame(minWidth: 60)
                    Button {
                        viewModel.doubleBet()
                    } label: {
                        Image(systemName: "multiply")
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                }
                .foregroundStyle(.white)
                .background(.black.opacity(0.35), in: Capsule())

                Spacer()

                ForEach([1, 5, 25], id: \.self) { chip in
                    Button {
                        viewModel.addToBet(chip)
                    } label: {
                        Text("+\(chip)")
                            .font(.caption.weight(.bold))
                            .frame(width: 42, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }

            Button {
                viewModel.deal()
                actionHaptic.impactOccurred()
            } label: {
                Text("Deal")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAffordBet || viewModel.state.currentBet == 0)
        }
    }

    private var actionControls: some View {
        HStack(spacing: 10) {
            actionButton("Hit", systemImage: "plus.circle") {
                viewModel.hit()
            }
            actionButton("Stand", systemImage: "hand.raised") {
                viewModel.stand()
            }
            if viewModel.canDouble {
                actionButton("Double", systemImage: "multiply.circle") {
                    viewModel.doubleDown()
                }
            }
            if viewModel.canSplit {
                actionButton("Split", systemImage: "arrow.triangle.branch") {
                    viewModel.split()
                }
            }
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            actionHaptic.impactOccurred()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
    }

    private var rebuyControl: some View {
        HStack {
            Spacer()
            Button {
                viewModel.rebuy()
            } label: {
                Label("Rebuy", systemImage: "arrow.clockwise.circle")
                    .font(.headline)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            Spacer()
        }
    }
}

// MARK: - Settings section shown inside the slide-down menu

struct BlackjackSettingsSection: View {
    @Bindable var viewModel: BlackjackViewModel
    let canOpenOptions: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BLACKJACK")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Group {
                Toggle("Sound", isOn: $viewModel.options.isSoundEnabled)
                Toggle("No Stress Mode", isOn: $viewModel.options.noStressMode)
            }
            .disabled(!canOpenOptions)
            .opacity(canOpenOptions ? 1 : 0.5)

            if !canOpenOptions {
                Text("Settings unlock between hands.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Stats sheet

struct BlackjackStatsSheet: View {
    @Bindable var viewModel: BlackjackViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                HStack {
                    Text("Hands Dealt")
                    Spacer()
                    Text("\(viewModel.state.handsDealt)").foregroundStyle(.secondary)
                }
                HStack {
                    Text("Session Credits")
                    Spacer()
                    Text("\(viewModel.state.sessionCredits)").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Blackjack Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
