import SwiftUI

// A brief, self-dismissing notice styled like the VideoPoker/Blackjack result banners
// (bold yellow headline over a dark rounded card) — for quick "nothing to do here" notices
// like "No hints available", as opposed to the multi-button Game Over/Win banners.
struct FlashBannerView: View {
    let message: String
    // Always clickable to dismiss when a dismiss handler is provided — not gated on the
    // "Manually Dismiss Banners" option's *current* value. It used to be gated on that,
    // but if the player turned the option off while a manually-shown banner (no
    // auto-dismiss timer was ever scheduled for it) was still on screen, the banner
    // became permanently stuck: not clickable anymore, and nothing left to time it out
    // either. Clicking to dismiss now always works regardless of the option, so a
    // banner can never end up in a state where nothing can close it.
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack {
            Spacer(minLength: 8)
            Text(message)
                .font(.system(size: 60, weight: .black))
                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.3)
                .shadow(radius: 3)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(Color.black.opacity(0.75))
                .cornerRadius(12)
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)
                .contentShape(Rectangle())
                .onTapGesture { onDismiss?() }
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(onDismiss != nil)
        .transition(.opacity)
    }
}
