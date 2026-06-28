import Foundation

@Observable
class DebugSettings {
    static let shared = DebugSettings()
    var faceCardFontSize: Double = 90
}
