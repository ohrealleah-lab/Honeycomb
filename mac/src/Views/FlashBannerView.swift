import SwiftUI

// A brief, self-dismissing notice styled like the VideoPoker/Blackjack result banners
// (bold yellow headline over a dark rounded card) — for quick "nothing to do here" notices
// like "No hints available", as opposed to the multi-button Game Over/Win banners.
struct FlashBannerView: View {
    let message: String
    // "Manually Dismiss Banners" option: when set, the banner accepts a tap (instead of
    // passing clicks through to the board) and calls onDismiss instead of relying on the
    // caller's auto-dismiss timer, which is skipped entirely while this is true.
    var manualDismiss: Bool = false
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
                .onTapGesture { if manualDismiss { onDismiss?() } }
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(manualDismiss)
        .transition(.opacity)
    }
}
