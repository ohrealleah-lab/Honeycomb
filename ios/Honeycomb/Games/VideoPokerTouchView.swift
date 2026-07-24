import SwiftUI
import UIKit

/// Touch-first Video Poker for iPhone/iPad, driven by the shared VideoPokerViewModel.
/// Button-driven (no drags): tap cards to hold during the holding phase, Deal/Draw
/// button advances the phase machine, bet controls sit below. Triple Play rendering is
/// not built yet — the settings expose Single Play options only for now.
struct VideoPokerTouchView: View {
    @Bindable var viewModel: VideoPokerViewModel
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator

    @State private var isMenuOpen = false
    @State private var showingStats = false

    private let holdHaptic = UIImpactFeedbackGenerator(style: .light)
    private let dealHaptic = UIImpactFeedbackGenerator(style: .medium)

    private var canAffordBet: Bool {
        viewModel.isFreePlay || viewModel.state.sessionCredits >= viewModel.totalBet
    }

    var body: some View {
        GeometryReader { geo in
            let cardW = min((geo.size.width - 24 - 4 * 8) / 5, 110)

            ZStack {
                coordinator.currentFeltColor.ignoresSafeArea()

                VStack(spacing: 12) {
                    topBar
                        .padding(.horizontal, 12)
                        .frame(height: 44)

                    payTableView
                        .padding(.horizontal, 16)

                    Spacer(minLength: 4)

                    resultBanner

                    handRow(cardW: cardW)
                        .padding(.horizontal, 12)

                    Spacer(minLength: 4)

                    controls
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                SlideDownMenu(isOpen: $isMenuOpen, coordinator: coordinator) {
                    showingStats = true
                } gameSettings: {
                    VideoPokerSettingsSection(viewModel: viewModel,
                                              isMidHand: viewModel.state.phase == .holding)
                }
            }
        }
        .sheet(isPresented: $showingStats) { VideoPokerStatsSheet(viewModel: viewModel) }
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

            Text(viewModel.options.variant.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
    }

    // MARK: Pay table

    private var payTableView: some View {
        VStack(spacing: 2) {
            ForEach(Array(viewModel.payTable.enumerated()), id: \.offset) { _, entry in
                let isHit = viewModel.state.phase == .result
                    && viewModel.state.lastPayout > 0
                    && viewModel.state.lastHandName == entry.handName
                HStack {
                    Text(entry.handName)
                    Spacer()
                    Text("\(entry.payout(bet: max(1, viewModel.state.currentBet)))")
                        .monospacedDigit()
                }
                .font(.caption2.weight(isHit ? .black : .medium))
                .foregroundStyle(isHit ? .yellow : .white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 1)
                .background(isHit ? Color.black.opacity(0.4) : .clear)
            }
        }
        .padding(.vertical, 6)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Hand

    private func handRow(cardW: CGFloat) -> some View {
        HStack(spacing: 8) {
            if viewModel.state.hand.isEmpty {
                ForEach(0..<5, id: \.self) { _ in
                    HoneycombSimpleCardBack()
                        .frame(width: cardW, height: cardW * 181.0 / 128.0)
                }
            } else {
                ForEach(Array(viewModel.state.hand.enumerated()), id: \.element.id) { i, card in
                    VStack(spacing: 4) {
                        Text("HELD")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.yellow)
                            .opacity(viewModel.state.heldIndices.contains(i) ? 1 : 0)
                        TouchCardView(card: card, width: cardW)
                            .overlay(
                                RoundedRectangle(cornerRadius: cardW * 0.07)
                                    .stroke(Color.yellow,
                                            lineWidth: viewModel.state.heldIndices.contains(i) ? 3 : 0)
                            )
                            .onTapGesture {
                                guard viewModel.state.phase == .holding else { return }
                                viewModel.toggleHold(at: i)
                                holdHaptic.impactOccurred()
                            }
                    }
                }
            }
        }
    }

    private var resultBanner: some View {
        Group {
            if viewModel.state.phase == .result, !viewModel.state.lastHandName.isEmpty {
                Text(viewModel.state.lastPayout > 0
                     ? "\(viewModel.state.lastHandName)  +\(viewModel.state.lastPayout)"
                     : viewModel.state.lastHandName)
                    .font(.title3.weight(.black))
                    .foregroundStyle(viewModel.state.lastPayout > 0 ? .yellow : .white.opacity(0.8))
            } else if viewModel.state.phase == .holding {
                Text("Tap cards to hold, then Draw")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text(" ").font(.title3.weight(.black))
            }
        }
        .frame(height: 28)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 12) {
            if viewModel.state.phase != .holding {
                HStack(spacing: 0) {
                    Button {
                        viewModel.decreaseBet()
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    Text("BET \(viewModel.state.currentBet)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .frame(minWidth: 60)
                    Button {
                        viewModel.increaseBet()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                }
                .foregroundStyle(.white)
                .background(.black.opacity(0.35), in: Capsule())

                Button("Max") {
                    viewModel.maxBet()
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }

            Spacer()

            if !canAffordBet && viewModel.state.phase != .holding {
                Button {
                    viewModel.rebuy()
                } label: {
                    Label("Rebuy", systemImage: "arrow.clockwise.circle")
                        .font(.headline)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            } else {
                Button {
                    if viewModel.state.phase == .holding {
                        viewModel.draw()
                    } else {
                        viewModel.deal()
                    }
                    dealHaptic.impactOccurred()
                } label: {
                    Text(viewModel.state.phase == .holding ? "Draw" : "Deal")
                        .font(.headline)
                        .padding(.horizontal, 24)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.state.phase != .holding && !canAffordBet)
            }
        }
    }
}

// MARK: - Settings section shown inside the slide-down menu

struct VideoPokerSettingsSection: View {
    @Bindable var viewModel: VideoPokerViewModel
    let isMidHand: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VIDEO POKER")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Group {
                Picker("Variant", selection: $viewModel.options.variant) {
                    ForEach(VideoPokerVariant.allCases, id: \.self) { v in
                        Text(v.rawValue).tag(v)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Sound", isOn: $viewModel.options.isSoundEnabled)
                Toggle("No Stress Mode", isOn: $viewModel.options.noStressMode)
            }
            .disabled(isMidHand)
            .opacity(isMidHand ? 0.5 : 1)

            if isMidHand {
                Text("Settings unlock when the hand ends.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Stats sheet

struct VideoPokerStatsSheet: View {
    @Bindable var viewModel: VideoPokerViewModel
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
            .navigationTitle("Video Poker Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
