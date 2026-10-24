import Foundation
import Observation

public struct SoliBeeTheme: Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var cardBackTheme: String
    public var feltColor: FeltColorTheme
    public var customFeltRed: Double
    public var customFeltGreen: Double
    public var customFeltBlue: Double
    public var faceArts: [CustomFaceArt]
    public var customCardColors: CustomCardColorGroup
    public var customBackgroundName: String?

    public init(
        id: UUID = UUID(),
        name: String,
        cardBackTheme: String,
        feltColor: FeltColorTheme,
        customFeltRed: Double,
        customFeltGreen: Double,
        customFeltBlue: Double,
        faceArts: [CustomFaceArt],
        customCardColors: CustomCardColorGroup = CustomCardColorGroup(),
        customBackgroundName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.cardBackTheme = cardBackTheme
        self.feltColor = feltColor
        self.customFeltRed = customFeltRed
        self.customFeltGreen = customFeltGreen
        self.customFeltBlue = customFeltBlue
        self.faceArts = faceArts
        self.customCardColors = customCardColors
        self.customBackgroundName = customBackgroundName
    }

    enum CodingKeys: String, CodingKey {
        case id, name, cardBackTheme, feltColor
        case customFeltRed, customFeltGreen, customFeltBlue, faceArts, customCardColors, customBackgroundName
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self,            forKey: .id)
        name           = try c.decode(String.self,          forKey: .name)
        cardBackTheme  = try c.decode(String.self,          forKey: .cardBackTheme)
        feltColor      = try c.decode(FeltColorTheme.self,  forKey: .feltColor)
        customFeltRed   = try c.decodeIfPresent(Double.self, forKey: .customFeltRed)   ?? 0
        customFeltGreen = try c.decodeIfPresent(Double.self, forKey: .customFeltGreen) ?? 0
        customFeltBlue  = try c.decodeIfPresent(Double.self, forKey: .customFeltBlue)  ?? 0
        faceArts       = try c.decodeIfPresent([CustomFaceArt].self, forKey: .faceArts) ?? []
        customCardColors = try c.decodeIfPresent(CustomCardColorGroup.self, forKey: .customCardColors) ?? CustomCardColorGroup()
        customBackgroundName = try c.decodeIfPresent(String.self, forKey: .customBackgroundName)
    }
}

@Observable
public final class ThemeManager {
    public static let shared = ThemeManager()

    public var themes: [SoliBeeTheme] = []

    // Tracks which saved theme (if any) is currently applied, so the UI can tell
    // whether the user has since drifted away from it via manual customization.
    // Cleared whenever a theme-relevant setting changes outside of applyTheme().
    public var activeThemeId: UUID? {
        didSet {
            if let activeThemeId {
                UserDefaults.standard.set(activeThemeId.uuidString, forKey: "solibee_active_theme_id")
            } else {
                UserDefaults.standard.removeObject(forKey: "solibee_active_theme_id")
            }
        }
    }

    // Fixed, hardcoded ids — these must NEVER be regenerated. defaultThemes is a `static
    // let` re-evaluated fresh on every process launch; without an explicit id here each
    // entry would get a new random UUID() every launch, silently orphaning any persisted
    // `activeThemeId` (or any other stored reference) that pointed at last launch's id.
    // load() matches these by name, so a player who already has a theme with one of
    // these names keeps their own copy; only names they don't have yet get added.
    private static let defaultThemes: [SoliBeeTheme] = [
        SoliBeeTheme(id: UUID(uuidString: "3B1E1B7A-3F0C-4B8D-9C1E-000000000001")!,
                     name: "Default", cardBackTheme: "Solibee", feltColor: .feltGreen,
                     customFeltRed: 0.0, customFeltGreen: 0.0, customFeltBlue: 0.0,
                     faceArts: [], customCardColors: presetCardColors(
                         bg: (1.0, 1.0, 1.0), blackSuit: (0.0667, 0.0667, 0.0667), redSuit: (0.7686, 0.1176, 0.1176),
                         hint: (1.0, 0.8431, 0.0), button: (1.0, 1.0, 1.0))),
        SoliBeeTheme(id: UUID(uuidString: "3B1E1B7A-3F0C-4B8D-9C1E-000000000006")!,
                     name: "Honey", cardBackTheme: "Solibee", feltColor: .custom,
                     customFeltRed: 0.2314, customFeltGreen: 0.1647, customFeltBlue: 0.0784,
                     faceArts: [], customCardColors: presetCardColors(
                         bg: (1.0, 0.9647, 0.8627), blackSuit: (0.0549, 0.0353, 0.0118), redSuit: (0.7529, 0.1882, 0.1098),
                         hint: (1.0, 0.8275, 0.0), button: (1.0, 0.8275, 0.0))),
        SoliBeeTheme(id: UUID(uuidString: "3B1E1B7A-3F0C-4B8D-9C1E-000000000007")!,
                     name: "Sunset", cardBackTheme: "Sunset", feltColor: .custom,
                     customFeltRed: 0.1176, customFeltGreen: 0.2275, customFeltBlue: 0.2824,
                     faceArts: [], customCardColors: presetCardColors(
                         bg: (0.9922, 0.9529, 0.8902), blackSuit: (0.0784, 0.0471, 0.0235), redSuit: (0.7412, 0.2392, 0.102),
                         hint: (1.0, 0.7098, 0.3412), button: (0.9922, 0.9529, 0.8902))),
        SoliBeeTheme(id: UUID(uuidString: "3B1E1B7A-3F0C-4B8D-9C1E-000000000008")!,
                     name: "Moogle", cardBackTheme: "Moogle", feltColor: .custom,
                     customFeltRed: 0.0784, customFeltGreen: 0.0784, customFeltBlue: 0.0784,
                     faceArts: [], customCardColors: presetCardColors(
                         bg: (1.0, 1.0, 1.0), blackSuit: (0.0, 0.0, 0.0), redSuit: (0.8157, 0.1255, 0.1804),
                         hint: (1.0, 0.898, 0.0), button: (1.0, 1.0, 1.0))),
        SoliBeeTheme(id: UUID(uuidString: "3B1E1B7A-3F0C-4B8D-9C1E-000000000002")!,
                     name: "Pareidolic 2", cardBackTheme: "Pareidolic 2", feltColor: .custom,
                     customFeltRed: 0.3608, customFeltGreen: 0.3451, customFeltBlue: 0.651,
                     faceArts: [], customCardColors: presetCardColors(
                         bg: (1.0, 1.0, 1.0), blackSuit: (0.0667, 0.0667, 0.0667), redSuit: (0.7686, 0.1176, 0.1176),
                         hint: (1.0, 0.8431, 0.0), button: (1.0, 1.0, 1.0))),
        SoliBeeTheme(id: UUID(uuidString: "3B1E1B7A-3F0C-4B8D-9C1E-000000000003")!,
                     name: "Desert", cardBackTheme: "Vulpera", feltColor: .desert,
                     customFeltRed: 0.0, customFeltGreen: 0.0, customFeltBlue: 0.0,
                     faceArts: [], customCardColors: presetCardColors(
                         bg: (1.0, 0.9804, 0.9529), blackSuit: (0.0667, 0.0667, 0.0667), redSuit: (0.7686, 0.1176, 0.1176),
                         hint: (1.0, 0.8431, 0.0), button: (1.0, 1.0, 1.0))),
        SoliBeeTheme(id: UUID(uuidString: "3B1E1B7A-3F0C-4B8D-9C1E-000000000004")!,
                     name: "Forest", cardBackTheme: "Forest", feltColor: .custom,
                     customFeltRed: 0.3686, customFeltGreen: 0.3294, customFeltBlue: 0.3137,
                     faceArts: [], customCardColors: presetCardColors(
                         bg: (0.902, 0.8118, 0.6745), blackSuit: (0.1333, 0.0353, 0.0392), redSuit: (0.6588, 0.0941, 0.102),
                         hint: (1.0, 0.8431, 0.0), button: (1.0, 1.0, 1.0))),
        SoliBeeTheme(id: UUID(uuidString: "3B1E1B7A-3F0C-4B8D-9C1E-000000000005")!,
                     name: "OceanSky", cardBackTheme: "Pareidolic", feltColor: .custom,
                     customFeltRed: 0.1412, customFeltGreen: 0.4706, customFeltBlue: 0.5608,
                     faceArts: [], customCardColors: presetCardColors(
                         bg: (0.949, 0.9961, 1.0), blackSuit: (0.0784, 0.1098, 0.1255), redSuit: (0.6902, 0.1882, 0.4314),
                         hint: (1.0, 0.8431, 0.0), button: (1.0, 1.0, 1.0))),
    ]

    // Built-in themes all turn custom card colors on with the standard outline and
    // shadow; only the card face, suit, hint glow and top-bar button colors differ.
    private static func presetCardColors(
        bg: (Double, Double, Double), blackSuit: (Double, Double, Double), redSuit: (Double, Double, Double),
        hint: (Double, Double, Double), button: (Double, Double, Double)
    ) -> CustomCardColorGroup {
        var group = CustomCardColorGroup()
        group.isEnabled = true
        (group.bgRed, group.bgGreen, group.bgBlue) = bg
        (group.blackSuitRed, group.blackSuitGreen, group.blackSuitBlue) = blackSuit
        (group.redSuitRed, group.redSuitGreen, group.redSuitBlue) = redSuit
        (group.hintHighlightRed, group.hintHighlightGreen, group.hintHighlightBlue) = hint
        (group.buttonRed, group.buttonGreen, group.buttonBlue) = button
        return group
    }

    // Names (lowercased) of built-in themes the user has explicitly deleted — checked
    // in load() so a deleted default doesn't silently reappear on next launch.
    private var deletedDefaultThemes: [String] {
        get { UserDefaults.standard.stringArray(forKey: "solibee_deleted_default_themes") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "solibee_deleted_default_themes") }
    }

    private init() {
        load()
        if let idString = UserDefaults.standard.string(forKey: "solibee_active_theme_id") {
            activeThemeId = UUID(uuidString: idString)
        }
    }

    private func load() {
        let deletedDefaults = Set(deletedDefaultThemes)
        guard let data = UserDefaults.standard.data(forKey: "solibee_themes"),
              var decoded = try? JSONDecoder().decode([SoliBeeTheme].self, from: data)
        else {
            themes = Self.defaultThemes.filter { !deletedDefaults.contains($0.name.lowercased()) }
            return
        }
        for defaultTheme in Self.defaultThemes {
            guard !deletedDefaults.contains(defaultTheme.name.lowercased()) else { continue }
            if !decoded.contains(where: { $0.name.lowercased() == defaultTheme.name.lowercased() }) {
                decoded.append(defaultTheme)
            }
        }
        themes = decoded
        save()
    }

    public func save() {
        if let data = try? JSONEncoder().encode(themes) {
            UserDefaults.standard.set(data, forKey: "solibee_themes")
        }
    }

    public func addTheme(_ theme: SoliBeeTheme) {
        themes.append(theme)
        save()
    }

    /// Overwrites an existing theme's saved values in place (same id and name,
    /// everything else replaced), for the "Update" action on an already-saved theme.
    public func updateTheme(_ theme: SoliBeeTheme) {
        guard let idx = themes.firstIndex(where: { $0.id == theme.id }) else { return }
        themes[idx] = theme
        save()
    }

    public func deleteTheme(id: UUID) {
        guard let theme = themes.first(where: { $0.id == id }) else { return }
        themes.removeAll { $0.id == id }
        let lowercasedName = theme.name.lowercased()
        if Self.defaultThemes.contains(where: { $0.name.lowercased() == lowercasedName }) {
            var deleted = deletedDefaultThemes
            if !deleted.contains(lowercasedName) {
                deleted.append(lowercasedName)
                deletedDefaultThemes = deleted
            }
        }
        if activeThemeId == id { activeThemeId = nil }
        save()
    }

    /// Returns true if `name` is already used (case-insensitive).
    public func nameExists(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return themes.contains { $0.name.lowercased() == trimmed }
    }

    /// Overwrites an existing theme's name (case-insensitive collision check against
    /// every *other* theme, so renaming a theme to its own current name is a no-op).
    public func renameTheme(id: UUID, newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = themes.firstIndex(where: { $0.id == id }) else { return false }
        let collides = themes.contains {
            $0.id != id && $0.name.lowercased() == trimmed.lowercased()
        }
        guard !collides else { return false }
        themes[idx].name = trimmed
        save()
        return true
    }

    // MARK: - Orphan-reference cleanup on asset delete
    //
    // Deleting a custom background/card back/face art image used to be blocked
    // outright when a saved theme referenced it (a "this image is used by theme X"
    // alert). That made deletion a two-step chore — find and edit the theme first.
    // Instead, deletion always succeeds immediately and every saved theme referencing
    // the deleted asset (not just the currently active one) is patched back to its
    // default in place, same as the live/current selection already falls back to felt.

    /// Clears `customBackgroundName` on every saved theme referencing it (falls back
    /// to felt color when that theme is next applied).
    public func clearBackgroundReferences(named name: String) {
        var changed = false
        for i in themes.indices where themes[i].customBackgroundName == name {
            themes[i].customBackgroundName = nil
            changed = true
        }
        if changed { save() }
    }

    /// Clears `cardBackTheme` on every saved theme referencing it, resetting to
    /// `fallback` (the default bundled card back).
    public func clearCardBackReferences(named name: String, fallback: String) {
        var changed = false
        for i in themes.indices where themes[i].cardBackTheme == name {
            themes[i].cardBackTheme = fallback
            changed = true
        }
        if changed { save() }
    }

    /// Removes the matching entry from `faceArts` on every saved theme referencing it.
    public func clearFaceArtReferences(relativePath: String) {
        var changed = false
        for i in themes.indices {
            let before = themes[i].faceArts.count
            themes[i].faceArts.removeAll { $0.relativePath == relativePath }
            if themes[i].faceArts.count != before { changed = true }
        }
        if changed { save() }
    }
}
