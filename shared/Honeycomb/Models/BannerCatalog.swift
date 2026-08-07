import Foundation

// Runtime companion to the generated BannerID enum (BannerID.swift) — loads
// HoneycombBannerCatalog.json (also generated, from the same spreadsheet run)
// and decides what text should actually show when a given banner fires.
//
// This only knows about *content*: which messages exist for an id, and
// whether/how the 20% gate + fallback applies. It has no opinion on *when*
// a trigger's condition becomes true (that's each call site's own gameplay
// logic) or on achievement/milestone "fire exactly once" guards (the exact
// crossing condition differs per milestone — total wins vs. first launch —
// so that's the caller's responsibility too, not something this can know).

public struct BannerDefinition: Codable {
    public let id: String
    public let category: String
    public let trigger: String
    public let type: String       // "ambiance" | "repeatableFlavor" | "achievement"
    public let location: String   // "toast" | "loading" | "winBanner" | "loseBanner" | "rulesBanner"
    public let gated: Bool
    public let gateChance: Double?
    public let fallback: String?
    public let messages: [String]
}

// What `BannerCatalog.fire(_:)` decided should actually show.
public enum BannerFireResult {
    // A message from the catalog's own pool for this id.
    case message(String)
    // The gate roll failed — this is the fallback text instead (an existing
    // production banner's own text, e.g. "Fallen Ace!", or the sentinel
    // BannerCatalog.ruleNameSentinel for rulesBanner entries, which the
    // caller resolves to the actual active rule's own display name).
    case fallback(String)
    // The id has no catalog entry, or its entry has no eligible content
    // (shouldn't happen for a valid, non-empty catalog) — nothing to show.
    case none
}

public final class BannerCatalog {
    public static let shared = BannerCatalog()

    // Sentinel a `fallback` string can equal for `rulesBanner`-location
    // entries — there's no single literal fallback text for those (it
    // depends on which rule is active), so the catalog can't bake it in;
    // the caller substitutes the rule's own existing display name instead.
    public static let ruleNameSentinel = "$RULE_NAME"

    private let entries: [BannerID: BannerDefinition]

    private init() {
        entries = Self.load()
    }

    private static func load() -> [BannerID: BannerDefinition] {
        guard let url = Bundle.main.url(forResource: "HoneycombBannerCatalog", withExtension: "json") else {
            assertionFailure("HoneycombBannerCatalog.json missing from the app bundle — check Package.swift's exclude list and the Makefile's resource cp step (mac), or Xcode's resource membership (iOS).")
            return [:]
        }
        guard let data = try? Data(contentsOf: url) else {
            assertionFailure("HoneycombBannerCatalog.json found but unreadable at \(url)")
            return [:]
        }
        struct Document: Codable { let banners: [BannerDefinition] }
        guard let doc = try? JSONDecoder().decode(Document.self, from: data) else {
            assertionFailure("HoneycombBannerCatalog.json failed to decode — did the schema change without updating BannerDefinition?")
            return [:]
        }
        var result: [BannerID: BannerDefinition] = [:]
        for entry in doc.banners {
            guard let id = BannerID(rawValue: entry.id) else {
                assertionFailure("HoneycombBannerCatalog.json has id \"\(entry.id)\" with no matching BannerID case — regenerate via tools/generate_banner_catalog.py.")
                continue
            }
            result[id] = entry
        }
        return result
    }

    public func definition(for id: BannerID) -> BannerDefinition? {
        entries[id]
    }

    // Decides what should show for `id` firing right now. `tokens` fills in
    // any `{PlaceholderName}` markers in the chosen text (e.g.
    // ["OpponentName": "Baby Bee"], ["ComboCount": "4"]).
    public func fire(_ id: BannerID, tokens: [String: String] = [:]) -> BannerFireResult {
        guard let def = entries[id] else { return .none }

        if def.gated, let chance = def.gateChance, Double.random(in: 0..<1) >= chance {
            guard let fallback = def.fallback else { return .none }
            return .fallback(Self.substitute(fallback, tokens: tokens))
        }
        guard let message = def.messages.randomElement() else { return .none }
        return .message(Self.substitute(message, tokens: tokens))
    }

    private static func substitute(_ text: String, tokens: [String: String]) -> String {
        guard !tokens.isEmpty else { return text }
        var result = text
        for (key, value) in tokens {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }

    // Whether ANY game's loading banner has fired yet this app session — not
    // per-game (each ViewModel has its own one-shot flag for that); this one is
    // shared across every game so we can tell "app launch" (the very first
    // loading banner shown this session, whichever game happens to load first)
    // from a later game switch.
    private static var hasFiredAnyLoadingBannerThisSession = false

    // Decides which "loading" banner (checked once per game, per app session — each
    // ViewModel guards this with its own one-shot flag) fits right now. Time-of-day
    // windows and the one-year-anniversary check only apply at app launch — they're
    // tied to "the moment you opened the app," not to switching games afterward — so
    // on any later game switch this falls straight to holiday > generic. Shared across
    // every game (not Honeycomb-specific) since "is it Halloween" and "has this install
    // been played for a year" don't depend on which game asked.
    public static func loadingBannerID() -> BannerID {
        let isAppLaunch = !hasFiredAnyLoadingBannerThisSession
        hasFiredAnyLoadingBannerThisSession = true

        if isAppLaunch, shouldShowOneYearAnniversaryBanner() { return .loadingFirstLaunchAfterPlayingForOneYear }

        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)
        if month == 5, day == 20 { return .loadingGameLoadsOnMay20thWorldBeeDay }
        if month == 1, day == 1 { return .loadingGameLoadsOnNewYearsDayJan1 }
        if month == 10, day == 31 { return .loadingGameLoadsOnHalloweenOct31 }
        if month == 2, day == 14 { return .loadingGameLoadsOnValentinesDayFeb14 }
        if month == 4, day == 1 { return .loadingPlayingOnAprilFoolsDayApr1 }

        if isAppLaunch {
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            let minutesFromMidnight = hour * 60 + minute
            if abs(minutesFromMidnight - 720) <= 1 { return .loadingMatchStartsWithinAMinuteOfLocalNoon }
            if hour < 4 { return .loadingMatchStartsBetween1200AmAnd400AmLocalTime }
            if hour >= 5 && hour < 8 { return .loadingMatchStartsBetween500AmAnd800AmLocalTime }
            if hour >= 8 && hour < 12 { return .loadingMatchStartsBetween800AmAnd1200PmLocalTime }
            if hour >= 12 && hour < 14 { return .loadingMatchStartsBetween1200PmAnd200PmLocalTime }
            if hour >= 14 && hour < 17 { return .loadingMatchStartsBetween200PmAnd500PmLocalTime }
            if hour >= 17 && hour < 21 { return .loadingMatchStartsBetween500PmAnd900PmLocalTime }
            if hour >= 21 { return .loadingMatchStartsBetween900PmAndMidnightLocalTime }
        }
        return .loadingOnGameLoad
    }

    // One shared anchor for the whole app (not per-game) — "a year since you started
    // playing" should have one answer regardless of which game happens to load first
    // on any given day, so this deliberately isn't scoped to Honeycomb's own stats.
    private static let firstPlayedDateKey = "HoneycombFirstPlayedDate"
    private static let hasShownOneYearBannerKey = "HoneycombHasShownOneYearBanner"

    private static func shouldShowOneYearAnniversaryBanner() -> Bool {
        let now = Date()
        // Anchors this install date the first time it's ever read — a stats reset
        // deliberately does NOT touch this, since "a year since you started playing"
        // isn't something resetting one game's win count should undo. Reading it here
        // (before the check below) means the very first call always has zero elapsed
        // time, so it can never spuriously fire that day.
        if UserDefaults.standard.object(forKey: firstPlayedDateKey) == nil {
            UserDefaults.standard.set(now, forKey: firstPlayedDateKey)
        }
        guard !UserDefaults.standard.bool(forKey: hasShownOneYearBannerKey),
              let firstPlayed = UserDefaults.standard.object(forKey: firstPlayedDateKey) as? Date,
              now.timeIntervalSince(firstPlayed) >= 365 * 24 * 60 * 60 else {
            return false
        }
        UserDefaults.standard.set(true, forKey: hasShownOneYearBannerKey)
        return true
    }
}
