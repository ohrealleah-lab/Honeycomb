import Foundation

// Coordinator-free lookup for use from ViewModels/Models, which don't hold an
// AppCoordinator reference (same reasoning as BannerCatalog.currentLanguage — see
// that file). Falls back to English on a missing key rather than crashing or
// showing a blank. `args` feeds interpolated strings via String(format:), e.g.
// L(.freecellStats, language: language, deckLabel) for "Freecell Statistics (%@)".
public func L(_ key: StringKey, language: AppLanguage, _ args: CVarArg...) -> String {
    let table = language == .spanish ? StringsSpanish.table : StringsEnglish.table
    let format = table[key] ?? StringsEnglish.table[key] ?? "?\(key.rawValue)?"
    return args.isEmpty ? format : String(format: format, arguments: args)
}

public extension AppCoordinator {
    // Falls back to English on a missing key, same as the free function above —
    // this is just the coordinator-bound convenience form for View code.
    func L(_ key: StringKey, _ args: CVarArg...) -> String {
        let table = language == .spanish ? StringsSpanish.table : StringsEnglish.table
        let format = table[key] ?? StringsEnglish.table[key] ?? "?\(key.rawValue)?"
        return args.isEmpty ? format : String(format: format, arguments: args)
    }
}
