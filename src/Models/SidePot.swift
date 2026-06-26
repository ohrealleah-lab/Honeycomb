import Foundation

public struct SidePot {
    public var amount: Int
    public var eligiblePlayerIDs: Set<UUID>

    public init(amount: Int, eligiblePlayerIDs: Set<UUID>) {
        self.amount = amount
        self.eligiblePlayerIDs = eligiblePlayerIDs
    }
}
