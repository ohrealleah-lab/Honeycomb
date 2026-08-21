import SwiftUI

// Shared label/value row used by every game's Statistics sheet (Klondike, Beecell,
// Spider, VideoPoker, Blackjack, Honeycomb). `valueBold` defaults to false to match
// Klondike/Beecell/Spider/Honeycomb's original plain-weight value text; VideoPoker and
// Blackjack pass true to preserve their bolded value column.
struct StatRowView: View {
    let label: String
    let value: String
    var valueBold: Bool = false
    // Opt-in style for the redesigned two-column stat grids (Klondike/Beecell/Spider) —
    // smaller muted-gray label, larger heavy-weight value — so the number reads as the
    // thing players actually care about. Defaults to false so Blackjack/VideoPoker/
    // Honeycomb's existing single-column panels render exactly as before.
    var emphasized: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(emphasized ? .system(size: 13) : .system(.body))
                .foregroundColor(emphasized ? .secondary : .primary)
            Spacer()
            if emphasized {
                Text(value)
                    .font(.system(size: 17, weight: .heavy))
            } else {
                Text(value)
                    .font(.system(.body))
                    .fontWeight(valueBold ? .bold : .regular)
            }
        }
    }
}
