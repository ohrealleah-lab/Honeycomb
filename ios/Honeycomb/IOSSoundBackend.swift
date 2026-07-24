import Foundation
import AVFoundation

/// AVAudioPlayer-based implementation of the shared `UISoundBackend` protocol —
/// the iOS counterpart of the mac app's NSSound-based MacUISoundBackend.
final class IOSSoundBackend: UISoundBackend {
    // One player per effect name, kept alive so playback isn't cut off by dealloc.
    // Replaying an effect restarts its player from the top, matching NSSound behavior
    // closely enough for short one-shot effects.
    private var players: [String: AVAudioPlayer] = [:]

    init() {
        // .ambient: game audio mixes with (and never interrupts) the user's music,
        // and respects the silent switch — the right default for a card game.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }

    func playEffect(named name: String) {
        play(named: name, volume: 1.0)
    }

    func playSystemSound(named name: String, volume: Float) {
        // iOS has no named system sounds like macOS's "Tink"/"Pop". Map the two UI
        // feedback sounds onto the bundled snap effect at reduced volume.
        play(named: "snap", volume: volume * 0.25)
    }

    private func play(named name: String, volume: Float) {
        if let player = players[name] {
            player.volume = volume
            player.currentTime = 0
            player.play()
            return
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "aiff"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        players[name] = player
        player.volume = volume
        player.play()
    }
}
