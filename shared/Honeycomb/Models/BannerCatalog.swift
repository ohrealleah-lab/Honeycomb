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

    // Mirrors AppCoordinator's honeyMode — a static flag rather than a parameter
    // threaded through every one of fire()'s ~40 call sites, since ViewModels don't
    // hold an AppCoordinator reference. AppCoordinator pushes into this on init and on
    // every change; nothing else should ever set it.
    public static var honeyModeEnabled: Bool = true

    // Decides what should show for `id` firing right now. `tokens` fills in
    // any `{PlaceholderName}` markers in the chosen text (e.g.
    // ["OpponentName": "Baby Bee"], ["ComboCount": "4"]).
    //
    // With Honey Mode off, every non-Achievement banner is either forced to its plain
    // fallback (gated entries — e.g. Combo x4+ always reads "HIVE MIND x4!" instead of
    // occasionally rolling flavor) or suppressed entirely (ungated entries — Loading,
    // Idle/Ambiance, and most Gameplay/Rule-Specific toasts have no plain-text
    // equivalent to fall back to). Every fire() call site already discards a
    // .fallback's own text in favor of its own existingDefaultText (see
    // bannerCatalogText below), so returning .fallback("") here is safe — the actual
    // string is never read.
    public func fire(_ id: BannerID, tokens: [String: String] = [:]) -> BannerFireResult {
        guard let def = entries[id] else { return .none }

        if !Self.honeyModeEnabled && def.type != "achievement" {
            return def.gated ? .fallback("") : .none
        }

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

    // Lunisolar/lunar holidays (Holi, Rosh Hashanah, Diwali, Eid al-Fitr, Hanukkah)
    // don't fall on a fixed Gregorian date, so — unlike the month/day checks above —
    // they need a real per-year lookup. No formula shortcut exists for these, so this
    // is a flat 20-year table (2025-2045) keyed "YYYY-M-D", one entry per year per
    // holiday — each holiday is a multi-day observance in real life, but only its
    // first day is listed here, since that's the one day the banner should show.
    private static let floatingHolidayDates: [String: BannerID] = {
        var dates: [String: BannerID] = [:]
        let holi = ["2025-3-14", "2026-3-3", "2027-3-22", "2028-3-11", "2029-3-29",
                     "2030-3-19", "2031-3-8", "2032-3-25", "2033-3-15", "2034-3-4",
                     "2035-3-22", "2036-3-12", "2037-3-1", "2038-3-19", "2039-3-8",
                     "2040-3-26", "2041-3-15", "2042-3-5", "2043-3-23", "2044-3-12",
                     "2045-3-1"]
        let roshHashanah = ["2025-9-23", "2026-9-12", "2027-10-2", "2028-9-21", "2029-9-10",
                             "2030-9-28", "2031-9-18", "2032-9-6", "2033-9-24", "2034-9-14",
                             "2035-10-4", "2036-9-22", "2037-9-10", "2038-9-30", "2039-9-19",
                             "2040-9-8", "2041-9-26", "2042-9-15", "2043-10-5", "2044-9-22",
                             "2045-9-12"]
        let diwali = ["2025-10-20", "2026-11-8", "2027-10-29", "2028-10-17", "2029-11-5",
                       "2030-10-26", "2031-11-14", "2032-11-2", "2033-10-22", "2034-11-10",
                       "2035-10-30", "2036-10-19", "2037-11-7", "2038-10-28", "2039-11-15",
                       "2040-11-4", "2041-10-24", "2042-11-12", "2043-10-31", "2044-10-20",
                       "2045-11-9"]
        let eidAlFitr = ["2025-3-30", "2026-3-19", "2027-3-9", "2028-2-26", "2029-2-14",
                          "2030-2-3", "2031-1-24", "2032-1-13", "2033-1-2", "2033-12-22",
                          "2034-12-11", "2035-11-30", "2036-11-18", "2037-11-8", "2038-10-29",
                          "2039-10-18", "2040-10-6", "2041-9-26", "2042-9-15", "2043-9-4",
                          "2044-8-24", "2045-8-13"]
        let hanukkah = ["2025-12-15", "2026-12-5", "2027-12-25", "2028-12-13", "2029-12-2",
                         "2030-12-21", "2031-12-10", "2032-11-28", "2033-12-17", "2034-12-7",
                         "2035-12-26", "2036-12-14", "2037-12-3", "2038-12-22", "2039-12-12",
                         "2040-11-30", "2041-12-18", "2042-12-8", "2043-12-27", "2044-12-15",
                         "2045-12-4"]
        for d in holi { dates[d] = .loadingGameLoadsOnHoli }
        for d in roshHashanah { dates[d] = .loadingGameLoadsOnRoshHashanah }
        for d in diwali { dates[d] = .loadingGameLoadsOnDiwali }
        for d in eidAlFitr { dates[d] = .loadingGameLoadsOnEidAlFitr }
        for d in hanukkah { dates[d] = .loadingGameLoadsOnHanukkah }
        return dates
    }()

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
        lastLoadingBannerWasAppLaunch = isAppLaunch

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
        if month == 4, day == 22 { return .loadingGameLoadsOnEarthDayApr22 }
        if month == 8, day == 15 { return .loadingGameLoadsOnNationalHoneyDayAug15 }
        if month == 3, day == 14 { return .loadingGameLoadsOnPiDayMar14 }
        if month == 12, day == 31 { return .loadingGameLoadsOnNewYearsEveDec31 }
        if month == 12, day == 25 { return .loadingGameLoadsOnChristmasDec25 }
        let year = calendar.component(.year, from: now)
        if let floatingID = floatingHolidayDates["\(year)-\(month)-\(day)"] { return floatingID }

        if isAppLaunch {
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            let minutesFromMidnight = hour * 60 + minute
            if abs(minutesFromMidnight - 720) <= 1 { return .loadingMatchStartsWithinAMinuteOfLocalNoon }
            if hour < 5 { return .loadingMatchStartsBetween1200AmAnd500AmLocalTime }
            if hour >= 5 && hour < 8 { return .loadingMatchStartsBetween500AmAnd800AmLocalTime }
            if hour >= 8 && hour < 12 { return .loadingMatchStartsBetween800AmAnd1200PmLocalTime }
            if hour >= 12 && hour < 14 { return .loadingMatchStartsBetween1200PmAnd200PmLocalTime }
            if hour >= 14 && hour < 17 { return .loadingMatchStartsBetween200PmAnd500PmLocalTime }
            if hour >= 17 && hour < 21 { return .loadingMatchStartsBetween500PmAnd900PmLocalTime }
            if hour >= 21 { return .loadingMatchStartsBetween900PmAndMidnightLocalTime }
        }
        return .loadingOnGameLoad
    }

    // Set by loadingBannerID() right before its caller enqueues the resulting banner —
    // every Loading-category catalog entry is ungated (always .message, never .none), so
    // a loadingBannerID() call is always immediately followed by that banner actually
    // being flashed. The very first loading banner of an app session gets a longer 3s
    // display (vs. the usual 2s) so there's actually time to read it — a match for
    // Windows, whose Avalonia UI has a startup cost native AppKit doesn't, though the
    // Mac side keeps the same duration for consistency between platforms rather than
    // because it strictly needs the extra time itself. Consumed (reset to false) by the
    // read itself so it can only ever apply to the one flash it was set for, not some
    // later unrelated banner.
    private static var lastLoadingBannerWasAppLaunch = false

    public static func consumeAppLaunchLoadingFlag() -> Bool {
        let wasAppLaunch = lastLoadingBannerWasAppLaunch
        lastLoadingBannerWasAppLaunch = false
        return wasAppLaunch
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
