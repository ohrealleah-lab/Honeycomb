namespace SoliBee.Core.Localization;

// Persisted on GameOptions.Language — mirrors the Mac/iOS port's AppLanguage
// (shared/Localization/AppLanguage.swift).
public enum AppLanguage
{
    English,
    Spanish,
}

public static class AppLanguageExtensions
{
    // Deliberately not run through Strings.Get() — this is the label for the language
    // picker's own options, so each one always reads in its own language regardless
    // of which language is currently active (mirrors language_english/language_spanish
    // in the spreadsheet, kept Translate=FALSE for the same reason).
    public static string DisplayName(this AppLanguage language) => language switch
    {
        AppLanguage.Spanish => "Español",
        _ => "English",
    };
}
