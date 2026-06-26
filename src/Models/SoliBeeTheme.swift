import Foundation
import Observation

public struct SoliBeeTheme: Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var cardBackTheme: String
    public var isDarkMode: Bool
    public var feltColor: FeltColorTheme
    public var customFeltRed: Double
    public var customFeltGreen: Double
    public var customFeltBlue: Double
    public var faceArts: [CustomFaceArt]

    public init(
        id: UUID = UUID(),
        name: String,
        cardBackTheme: String,
        isDarkMode: Bool,
        feltColor: FeltColorTheme,
        customFeltRed: Double,
        customFeltGreen: Double,
        customFeltBlue: Double,
        faceArts: [CustomFaceArt]
    ) {
        self.id = id
        self.name = name
        self.cardBackTheme = cardBackTheme
        self.isDarkMode = isDarkMode
        self.feltColor = feltColor
        self.customFeltRed = customFeltRed
        self.customFeltGreen = customFeltGreen
        self.customFeltBlue = customFeltBlue
        self.faceArts = faceArts
    }

    enum CodingKeys: String, CodingKey {
        case id, name, cardBackTheme, isDarkMode, feltColor
        case customFeltRed, customFeltGreen, customFeltBlue, faceArts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self,            forKey: .id)
        name           = try c.decode(String.self,          forKey: .name)
        cardBackTheme  = try c.decode(String.self,          forKey: .cardBackTheme)
        isDarkMode     = try c.decode(Bool.self,            forKey: .isDarkMode)
        feltColor      = try c.decode(FeltColorTheme.self,  forKey: .feltColor)
        customFeltRed   = try c.decodeIfPresent(Double.self, forKey: .customFeltRed)   ?? 0
        customFeltGreen = try c.decodeIfPresent(Double.self, forKey: .customFeltGreen) ?? 0
        customFeltBlue  = try c.decodeIfPresent(Double.self, forKey: .customFeltBlue)  ?? 0
        faceArts       = try c.decodeIfPresent([CustomFaceArt].self, forKey: .faceArts) ?? []
    }
}

@Observable
public final class ThemeManager {
    public static let shared = ThemeManager()

    public var themes: [SoliBeeTheme] = []

    private static let defaultThemes: [SoliBeeTheme] = [
        SoliBeeTheme(name: "Pareidolic 2", cardBackTheme: "Pareidolic 2", isDarkMode: false,
                     feltColor: .custom,
                     customFeltRed: 0.5925555229187012, customFeltGreen: 0.5882400274276733, customFeltBlue: 0.8116011023521423,
                     faceArts: []),
        SoliBeeTheme(name: "Dingwall",     cardBackTheme: "Dingwall",     isDarkMode: false,
                     feltColor: .charcoal,
                     customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0,
                     faceArts: []),
        SoliBeeTheme(name: "Desert",       cardBackTheme: "Vulpera",      isDarkMode: false,
                     feltColor: .desert,
                     customFeltRed: 0, customFeltGreen: 0, customFeltBlue: 0,
                     faceArts: []),
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
