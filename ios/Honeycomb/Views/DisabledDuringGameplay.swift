import SwiftUI

// Shared "settings locked while a hand/game is in progress" treatment used by
// VideoPoker's and Blackjack's in-menu settings sections.
struct DisabledDuringGameplayModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .disabled(isActive)
            .opacity(isActive ? 0.5 : 1)
    }
}

extension View {
    func disabledDuringGameplay(_ isActive: Bool) -> some View {
        modifier(DisabledDuringGameplayModifier(isActive: isActive))
    }
}
