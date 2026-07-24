import Foundation

// MARK: - UI Sound

/// Platform hook for actually producing audio. The shared `UISound` facade forwards to
/// whichever backend the app assigns at startup (NSSound on macOS, AVAudioPlayer on iOS).
/// Left nil in headless/test contexts, where no audio should play at all.
public protocol UISoundBackend {
    /// Play a bundled game-effect sound (e.g. "shuffle", "snap", "victory"), falling back
    /// to a platform system sound if the bundled file is missing.
    func playEffect(named name: String)
    /// Play a short UI feedback sound for button interactions.
    func playSystemSound(named name: String, volume: Float)
}

public enum UISound {
    public static var isEnabled: Bool = true
    public static var isHeadlessMode: Bool = false
    /// Assigned once at app startup by each platform's entry point.
    public static var backend: UISoundBackend?

    public static func click() {
        guard isEnabled, !isHeadlessMode else { return }
        backend?.playSystemSound(named: "Tink", volume: 1.0)
    }

    public static func tick() {
        guard isEnabled, !isHeadlessMode else { return }
        backend?.playSystemSound(named: "Pop", volume: 0.25)
    }

    // Shared game-effect player (shuffle/snap/victory/etc.) used by every game's ViewModel.
    // `respectHeadlessMode` defaults to false to preserve each game's pre-existing behavior —
    // only BlackjackViewModel checked isHeadlessMode before this was consolidated.
    public static func play(named name: String, enabled: Bool, respectHeadlessMode: Bool = false) {
        guard enabled, !(respectHeadlessMode && isHeadlessMode) else { return }
        backend?.playEffect(named: name)
    }
}
