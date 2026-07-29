import SwiftUI

// Shared label/value row used by every game's Statistics sheet (Klondike, Beecell,
// Spider, VideoPoker, Blackjack, Honeycomb). `valueBold` defaults to false to match
// Klondike/Beecell/Spider/Honeycomb's original plain-weight value text; VideoPoker and
// Blackjack pass true to preserve their bolded value column.
struct StatRowView: View {
    let label: String
    let value: String
    var valueBold: Bool = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).fontWeight(valueBold ? .bold : .regular)
        }
        .font(.system(.body))
    }
}
