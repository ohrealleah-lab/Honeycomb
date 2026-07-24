import Foundation

public struct KeyboardCursor: Equatable {
    public var pileId: String
    public var cardIndex: Int?

    public init(pileId: String, cardIndex: Int? = nil) {
        self.pileId = pileId
        self.cardIndex = cardIndex
    }
}
