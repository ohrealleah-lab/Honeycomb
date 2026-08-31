import Foundation
import Observation

// True single source of truth for the settings that apply identically across every
// game: Sound, No Stress Mode, Honey Mode, Manually Dismiss Banners, Hide Hint
// Button. AppCoordinator and all 6 game ViewModels are handed this exact same
// instance at construction, so there's no per-game copy to keep in sync — reading
// or writing coordinator.isSoundEnabled and viewModel.sharedOptions.isSoundEnabled
// touch the identical stored property. Replaces the old scheme where each game's own
// Options struct carried a redundant duplicate field, kept in sync only because
// AppCoordinator pushed into it on every change (see git history:
// applySharedCommonOptionsToAllGames) — that push could in principle be skipped or
// raced, which was the whole reason for this migration.
@Observable
public final class SharedGameOptions {
    public var isSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "global_sound_enabled")
            UISound.isEnabled = isSoundEnabled
        }
    }
    public var noStressMode: Bool {
        didSet {
            UserDefaults.standard.set(noStressMode, forKey: "global_no_stress_mode")
            if oldValue != noStressMode {
                for observer in noStressModeObservers { observer() }
            }
        }
    }
    // Klondike/Beecell/Spider register here (see onNoStressModeChange) to
    // start/stop their timer immediately when No Stress Mode toggles mid-game —
    // Video Poker/Blackjack/Honeycomb have no timer and just read the value fresh
    // wherever they need it, no reaction required.
    private var noStressModeObservers: [() -> Void] = []
    public func onNoStressModeChange(_ observer: @escaping () -> Void) {
        noStressModeObservers.append(observer)
    }
    // "Honey Mode (Flavor)" — controls both the "+N"/"-N" score popups (each game's
    // own honeyMode guard) and, via BannerCatalog.honeyModeEnabled, whether
    // Repeatable Flavor/Ambiance banners fire at all. Achievement/Milestone banners
    // are never affected.
    public var honeyMode: Bool {
        didSet {
            UserDefaults.standard.set(honeyMode, forKey: "global_honey_mode")
            BannerCatalog.honeyModeEnabled = honeyMode
        }
    }
    // When on, banners/toasts stay up (no auto-dismiss timer) and the game is
    // effectively paused until the player clicks the banner or a card, at which point
    // it dismisses and the banner queue resumes. Default off — preserves the
    // pre-existing auto-dismiss behavior unless the player opts in.
    public var manuallyDismissBanners: Bool {
        didSet { UserDefaults.standard.set(manuallyDismissBanners, forKey: "global_manually_dismiss_banners") }
    }
    // Video Poker and Blackjack have no hint feature, so they just never read this.
    public var hideHintButton: Bool {
        didSet { UserDefaults.standard.set(hideHintButton, forKey: "global_hide_hint_button") }
    }

    public init() {
        self.isSoundEnabled = UserDefaults.standard.object(forKey: "global_sound_enabled") != nil
            ? UserDefaults.standard.bool(forKey: "global_sound_enabled") : true
        self.noStressMode = UserDefaults.standard.object(forKey: "global_no_stress_mode") != nil
            ? UserDefaults.standard.bool(forKey: "global_no_stress_mode") : false
        self.honeyMode = UserDefaults.standard.object(forKey: "global_honey_mode") != nil
            ? UserDefaults.standard.bool(forKey: "global_honey_mode") : true
        self.manuallyDismissBanners = UserDefaults.standard.object(forKey: "global_manually_dismiss_banners") != nil
            ? UserDefaults.standard.bool(forKey: "global_manually_dismiss_banners") : false
        self.hideHintButton = UserDefaults.standard.object(forKey: "global_hide_hint_button") != nil
            ? UserDefaults.standard.bool(forKey: "global_hide_hint_button") : false
        UISound.isEnabled = self.isSoundEnabled
        BannerCatalog.honeyModeEnabled = self.honeyMode
    }
}
