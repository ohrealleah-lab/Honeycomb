import Foundation

// SoliBeeTests/TestRunner.swift runs every suite sequentially in one process, and
// SharedGameOptions (shared/Models/SharedGameOptions.swift) persists all 5 of its
// fields to a shared UserDefaults domain and unconditionally mutates two
// process-wide global statics (UISound.isEnabled, BannerCatalog.honeyModeEnabled)
// on every construction and every change — even for a throwaway standalone instance
// a test builds via a ViewModel's default `sharedOptions:` init parameter. Wrap any
// test that mutates isSoundEnabled/noStressMode/honeyMode/manuallyDismissBanners/
// hideHintButton on such an instance in this helper so it can't leak into a later
// test in the same process.
func withRestoredSharedGameOptions(_ body: () -> Void) {
    let keys = [
        "global_sound_enabled", "global_no_stress_mode", "global_honey_mode",
        "global_manually_dismiss_banners", "global_hide_hint_button"
    ]
    let savedDefaults = keys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
    let savedSoundEnabled = UISound.isEnabled
    let savedHoneyModeEnabled = BannerCatalog.honeyModeEnabled
    defer {
        for (key, value) in savedDefaults {
            if let value { UserDefaults.standard.set(value, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        UISound.isEnabled = savedSoundEnabled
        BannerCatalog.honeyModeEnabled = savedHoneyModeEnabled
    }
    body()
}
