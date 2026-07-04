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

    public init(
        id: UUID = UUID(),
        name: String,
        cardBackTheme: String,
        feltColor: FeltColorTheme,
        customFeltRed: Double,
        customFeltGreen: Double,
        customFeltBlue: Double,
        faceArts: [CustomFaceArt],
        customCardColors: CustomCardColorGroup = CustomCardColorGroup()
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
    }

    enum CodingKeys: String, CodingKey {
        case id, name, cardBackTheme, feltColor
        case customFeltRed, customFeltGreen, customFeltBlue, faceArts, customCardColors
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
    }
}

@Observable
public final class ThemeManager {
    public static let shared = ThemeManager()

    public var themes: [SoliBeeTheme] = []

    private static let defaultThemes: [SoliBeeTheme] = [
        SoliBeeTheme(name: "Pareidolic 2", cardBackTheme: "Pareidolic 2", feltColor: .custom,
                     customFeltRed: 0.5925555229187012, customFeltGreen: 0.5882400274276733, customFeltBlue: 0.8116011023521423,
                     faceArts: [], customCardColors: CustomCardColorGroup()),
        SoliBeeTheme(name: "Dingwall",     cardBackTheme: "Dingwall",     feltColor: .charcoal,
                     customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0,
                     faceArts: [], customCardColors: CustomCardColorGroup()),
        SoliBeeTheme(name: "Desert",       cardBackTheme: "Vulpera",      feltColor: .desert,
                     customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0,
                     faceArts: [], customCardColors: CustomCardColorGroup()),
    ]

    private init() { load() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "solibee_themes"),
              let decoded = try? JSONDecoder().decode([SoliBeeTheme].self, from: data)
        else {
            themes = Self.defaultThemes
            return
        }
        themes = decoded
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
        themes.removeAll { $0.id == id }
        save()
    }

    /// Returns true if `name` is already used (case-insensitive).
    public func nameExists(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return themes.contains { $0.name.lowercased() == trimmed }
    }
}
