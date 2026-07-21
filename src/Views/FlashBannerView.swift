import SwiftUI

// A brief, self-dismissing notice styled like the VideoPoker/Blackjack result banners
// (bold yellow headline over a dark rounded card) — for quick "nothing to do here" notices
// like "No hints available", as opposed to the multi-button Game Over/Win banners.
struct FlashBannerView: View {
    let message: String

    var body: some View {
        VStack {
            Spacer(minLength: 8)
            Text(message)
                .font(.system(size: 28, weight: .black))
                .foregroundColor(.yellow)
                .shadow(radius: 3)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(Color.black.opacity(0.75))
                .cornerRadius(12)
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5), radius: 16)
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}
