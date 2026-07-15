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

    private static let defaultThemes: [SoliBeeTheme] = [
        SoliBeeTheme(name: "Default",      cardBackTheme: "Moogle",       feltColor: .feltGreen,
                     customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0,
                     faceArts: [], customCardColors: CustomCardColorGroup()),
        SoliBeeTheme(name: "Pareidolic 2", cardBackTheme: "Pareidolic 2", feltColor: .custom,
                     customFeltRed: 0.5925555229187012, customFeltGreen: 0.5882400274276733, customFeltBlue: 0.8116011023521423,
                     faceArts: [], customCardColors: CustomCardColorGroup()),
        SoliBeeTheme(name: "Desert",       cardBackTheme: "Vulpera",      feltColor: .desert,
                     customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0,
                     faceArts: [], customCardColors: CustomCardColorGroup()),
        SoliBeeTheme(name: "Forest",       cardBackTheme: "Forest",       feltColor: .custom,
                     customFeltRed: 0.5211737751960754, customFeltGreen: 0.4769634008407593, customFeltBlue: 0.4559733271598816,
                     faceArts: [], customCardColors: {
                         var group = CustomCardColorGroup()
                         group.isEnabled = true
                         group.bgRed = 0.9010706543922424
                         group.bgGreen = 0.812778890132904
                         group.bgBlue = 0.6745686531066895
                         group.bgAlpha = 1
                         group.outlineRed = 0
                         group.outlineGreen = 0
                         group.outlineBlue = 0
                         group.outlineAlpha = 0.85
                         group.blackSuitRed = 0.7106840014457703
                         group.blackSuitGreen = 0.1873437464237213
                         group.blackSuitBlue = 0.14731520414352417
                         group.blackSuitAlpha = 1
                         group.redSuitRed = 0.7748149037361145
                         group.redSuitGreen = 0.11090389639139175
                         group.redSuitBlue = 0.10087030380964279
                         group.redSuitAlpha = 1
                         group.shadowRed = 0
                         group.shadowGreen = 0
                         group.shadowBlue = 0
                         group.shadowAlpha = 0.15
                         return group
                     }()),
        SoliBeeTheme(name: "OceanSky",     cardBackTheme: "Pareidolic",   feltColor: .custom,
                     customFeltRed: 0.5867433547973633, customFeltGreen: 0.9626139998435974, customFeltBlue: 0.9703466296195984,
                     faceArts: [], customCardColors: {
                         var group = CustomCardColorGroup()
                         group.isEnabled = true
                         group.bgRed = 0.8808431029319763
                         group.bgGreen = 0.9917027354240417
                         group.bgBlue = 0.9941582083702087
                         group.bgAlpha = 1
                         group.outlineRed = 0
                         group.outlineGreen = 0
                         group.outlineBlue = 0
                         group.outlineAlpha = 0.85
                         group.blackSuitRed = 0.2587890625
                         group.blackSuitGreen = 0.2587890625
                         group.blackSuitBlue = 0.2587890625
                         group.blackSuitAlpha = 1
                         group.redSuitRed = 0.7544758915901184
                         group.redSuitGreen = 0.3275292217731476
                         group.redSuitBlue = 0.5698546767234802
                         group.redSuitAlpha = 1
                         group.shadowRed = 0
                         group.shadowGreen = 0
                         group.shadowBlue = 0
                         group.shadowAlpha = 0.15
                         return group
                     }()),
    ]

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

    /// Call whenever a theme-relevant setting (felt color, card back, custom card
    /// colors, custom face art) changes outside of `applyTheme()`, so the UI can
    /// tell the user has drifted away from whatever theme was last applied.
    public func invalidateActiveTheme() {
        activeThemeId = nil
    }

    // MARK: - Asset reference lookups
    //
    // Shared by the custom card back / face art / background managers' delete
    // safeguards (and their selector views' pre-delete "in use" alerts) so "is this
    // asset referenced by a saved Theme" is defined once instead of as a near-identical
    // inline closure at each call site.

    public func themeReferencingCardBack(named name: String) -> SoliBeeTheme? {
        themes.first { $0.cardBackTheme == name }
    }

    public func themeReferencingBackground(named name: String) -> SoliBeeTheme? {
        themes.first { $0.customBackgroundName == name }
    }

    public func themeReferencingFaceArt(relativePath: String) -> SoliBeeTheme? {
        themes.first { $0.faceArts.contains { $0.relativePath == relativePath } }
    }
}
