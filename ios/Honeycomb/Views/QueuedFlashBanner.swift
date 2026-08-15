import SwiftUI

// Displays the shared BannerCatalog flavor-text queue (milestones, idle nudges, "no
// hints available", etc.) that every game's ViewModel already populates via
// flashBanner/flashBannerTrigger + advanceBannerQueue() — mirrors mac's
// flashQueuedBanner/dismissQueuedBanner pattern (mac/src/Views/GameView.swift and
// identical siblings in BeecellView/SpiderView/VideoPokerView/BlackjackView) so this
// content isn't silently generated and dropped on iOS the way it was before this
// modifier existed. Honeycomb has its own equivalent wiring already (its rule/no-hints
// banners use a different trigger name) — this is for the other five games.
private struct QueuedFlashBannerModifier: ViewModifier {
    let trigger: Int
    let latestMessage: String?
    let manuallyDismissBanners: Bool
    let onAdvanceQueue: () -> Void

    @State private var isShowing = false
    @State private var text = ""
    @State private var dismissTask: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .overlay {
                if isShowing {
                    FlashBannerView(message: text, onDismiss: manuallyDismissBanners ? dismiss : nil)
                        .zIndex(100)
                }
            }
            .onChange(of: trigger) { _, _ in
                guard let message = latestMessage else { return }
                flash(message)
            }
    }

    private func flash(_ message: String) {
        dismissTask?.cancel()
        text = message
        withAnimation(.easeIn(duration: 0.15)) { isShowing = true }
        // Manually Dismiss Banners: the game is "paused" on this banner — no timer, it
        // stays up until the player taps it (FlashBannerView's own tap-to-dismiss).
        guard !manuallyDismissBanners else {
            dismissTask = nil
            return
        }
        let task = DispatchWorkItem { dismiss() }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
    }

    private func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(.easeOut(duration: 0.3)) { isShowing = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onAdvanceQueue()
        }
    }
}

extension View {
    func queuedFlashBanner(
        trigger: Int,
        latestMessage: String?,
        manuallyDismissBanners: Bool,
        onAdvanceQueue: @escaping () -> Void
    ) -> some View {
        modifier(QueuedFlashBannerModifier(
            trigger: trigger,
            latestMessage: latestMessage,
            manuallyDismissBanners: manuallyDismissBanners,
            onAdvanceQueue: onAdvanceQueue
        ))
    }
}
