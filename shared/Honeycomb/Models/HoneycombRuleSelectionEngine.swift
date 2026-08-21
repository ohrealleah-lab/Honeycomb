import Foundation

// Shared Auto/Pick/Ban logic for the Rules screen's unified rule list, used by both
// mac's HoneycombRulesView and iOS's merged rules sheet so the selection/ban validation
// (max-4 cap, exclusive rule pairs, "can't ban everything" guard) lives in one place
// instead of being copy-pasted per platform.
public enum HoneycombRuleState {
    case auto
    case picked
    case banned
}

// "Normal Mode" isn't a HoneycombRule case — picking it means `forceNormalMode = true`
// (lock the match to zero rules) and banning it means `bannedRules.contains("Normal Mode")`
// (keep roulette from ever landing on a zero-rule match). Modeling it alongside the real
// rules here is what lets the unified list treat every row the same way.
public enum HoneycombRuleRowID: Hashable {
    case rule(HoneycombRule)
    case normalMode

    public static let banListOrder: [HoneycombRuleRowID] = [.normalMode] + HoneycombRule.allCases.map { .rule($0) }
    public static let pickableOrder: [HoneycombRuleRowID] = [.normalMode] + HoneycombRule.allCases.map { .rule($0) }

    public var isPickable: Bool { true }

    var banName: String {
        switch self {
        case .normalMode: return "Normal Mode"
        case .rule(let r): return r.rawValue
        }
    }
}

public enum HoneycombRuleSelection {
    public static func state(
        of id: HoneycombRuleRowID,
        selectedRules: Set<HoneycombRule>,
        forceNormalMode: Bool,
        bannedRules: Set<String>
    ) -> HoneycombRuleState {
        if bannedRules.contains(id.banName) { return .banned }
        switch id {
        case .normalMode: return forceNormalMode ? .picked : .auto
        case .rule(let r): return selectedRules.contains(r) ? .picked : .auto
        }
    }

    // Returns true if the ban was blocked by the "can't ban everything" guard (the
    // caller shows the silly-bee warning in that case); false otherwise.
    @discardableResult
    public static func setState(
        _ newState: HoneycombRuleState,
        for id: HoneycombRuleRowID,
        selectedRules: inout Set<HoneycombRule>,
        forceNormalMode: inout Bool,
        bannedRules: inout Set<String>
    ) -> Bool {
        switch newState {
        case .auto:
            bannedRules.remove(id.banName)
            if case .normalMode = id { forceNormalMode = false }
            if case .rule(let r) = id { selectedRules.remove(r) }
            return false

        case .picked:
            guard id.isPickable else { return false }
            bannedRules.remove(id.banName)
            switch id {
            case .normalMode:
                forceNormalMode = true
                selectedRules.removeAll()
            case .rule(let r):
                var updated = selectedRules
                // Remove the exclusive partner (if any) BEFORE the cap check — selecting
                // a rule whose partner is already selected is a net-zero swap, not an
                // addition, so it must never be blocked just because the cap is full.
                if r == .ascension { updated.remove(.descension) }
                if r == .descension { updated.remove(.ascension) }
                if r == .order { updated.remove(.chaos) }
                if r == .chaos { updated.remove(.order) }
                if r == .allOpen { updated.remove(.threeOpen) }
                if r == .threeOpen { updated.remove(.allOpen) }
                // Bomb Shelter's hidden card doesn't work when All Open/Three Open
                // reveals every card anyway.
                if r == .allOpen || r == .threeOpen { updated.remove(.bombShelter) }
                if r == .bombShelter { updated.remove(.allOpen); updated.remove(.threeOpen) }

                if updated.count < 4 {
                    updated.insert(r)
                    selectedRules = updated
                    forceNormalMode = false
                }
            }
            return false

        case .banned:
            // "Silly bee" guard: never allow banning the last remaining unbanned item.
            if bannedRules.count >= HoneycombRuleRowID.banListOrder.count - 1 && !bannedRules.contains(id.banName) {
                return true
            }
            if case .normalMode = id { forceNormalMode = false }
            if case .rule(let r) = id { selectedRules.remove(r) }
            bannedRules.insert(id.banName)
            return false
        }
    }
}
