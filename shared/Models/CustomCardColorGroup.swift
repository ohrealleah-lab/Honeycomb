import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// Decomposes a SwiftUI Color into device-RGB components via the native color type of
// whichever platform this compiles on. Returns nil for colors with no RGB representation.
private func rgbaComponents(of color: Color) -> (red: Double, green: Double, blue: Double, alpha: Double)? {
    #if canImport(AppKit)
    guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return nil }
    return (Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent), Double(rgb.alphaComponent))
    #else
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
    return (Double(r), Double(g), Double(b), Double(a))
    #endif
}

public struct CustomCardColorGroup: Codable, Equatable {
    public var isEnabled: Bool = false
    
    // Background color components (Default: White)
    public var bgRed: Double = 1.0
    public var bgGreen: Double = 1.0
    public var bgBlue: Double = 1.0
    public var bgAlpha: Double = 1.0
    
    // Outline color components (Default: Black/Gray)
    public var outlineRed: Double = 0.0
    public var outlineGreen: Double = 0.0
    public var outlineBlue: Double = 0.0
    public var outlineAlpha: Double = 0.85
    
    // Black suit text color components (Default: Dark Gray/Black)
    public var blackSuitRed: Double = 0.1
    public var blackSuitGreen: Double = 0.1
    public var blackSuitBlue: Double = 0.1
    public var blackSuitAlpha: Double = 1.0
    
    // Red suit text color components (Default: Red)
    public var redSuitRed: Double = 0.8
    public var redSuitGreen: Double = 0.1
    public var redSuitBlue: Double = 0.1
    public var redSuitAlpha: Double = 1.0
    
    // Shadow color components (Default: Translucent Black)
    public var shadowRed: Double = 0.0
    public var shadowGreen: Double = 0.0
    public var shadowBlue: Double = 0.0
    public var shadowAlpha: Double = 0.15

    // Hint/hierarchy/frenzy highlight color components (Default: Gold, matches prior
    // hardcoded Color.yellow). Independent of isEnabled — this highlight always renders
    // with whatever color is set here, regardless of whether the rest of the custom
    // card color scheme is toggled on, since it's a distinct feature from card recoloring.
    public var hintHighlightRed: Double = 1.0
    public var hintHighlightGreen: Double = 0.843
    public var hintHighlightBlue: Double = 0.0
    public var hintHighlightAlpha: Double = 1.0

    public init() {}

    // Custom Decodable so a JSON blob saved before hintHighlight* existed still decodes
    // successfully (synthesized Codable would otherwise fail on the missing keys and
    // silently reset every saved color, not just the new one, back to CustomCardColorGroup()).
    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case bgRed, bgGreen, bgBlue, bgAlpha
        case outlineRed, outlineGreen, outlineBlue, outlineAlpha
        case blackSuitRed, blackSuitGreen, blackSuitBlue, blackSuitAlpha
        case redSuitRed, redSuitGreen, redSuitBlue, redSuitAlpha
        case shadowRed, shadowGreen, shadowBlue, shadowAlpha
        case hintHighlightRed, hintHighlightGreen, hintHighlightBlue, hintHighlightAlpha
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        bgRed = try container.decodeIfPresent(Double.self, forKey: .bgRed) ?? 1.0
        bgGreen = try container.decodeIfPresent(Double.self, forKey: .bgGreen) ?? 1.0
        bgBlue = try container.decodeIfPresent(Double.self, forKey: .bgBlue) ?? 1.0
        bgAlpha = try container.decodeIfPresent(Double.self, forKey: .bgAlpha) ?? 1.0
        outlineRed = try container.decodeIfPresent(Double.self, forKey: .outlineRed) ?? 0.0
        outlineGreen = try container.decodeIfPresent(Double.self, forKey: .outlineGreen) ?? 0.0
        outlineBlue = try container.decodeIfPresent(Double.self, forKey: .outlineBlue) ?? 0.0
        outlineAlpha = try container.decodeIfPresent(Double.self, forKey: .outlineAlpha) ?? 0.85
        blackSuitRed = try container.decodeIfPresent(Double.self, forKey: .blackSuitRed) ?? 0.1
        blackSuitGreen = try container.decodeIfPresent(Double.self, forKey: .blackSuitGreen) ?? 0.1
        blackSuitBlue = try container.decodeIfPresent(Double.self, forKey: .blackSuitBlue) ?? 0.1
        blackSuitAlpha = try container.decodeIfPresent(Double.self, forKey: .blackSuitAlpha) ?? 1.0
        redSuitRed = try container.decodeIfPresent(Double.self, forKey: .redSuitRed) ?? 0.8
        redSuitGreen = try container.decodeIfPresent(Double.self, forKey: .redSuitGreen) ?? 0.1
        redSuitBlue = try container.decodeIfPresent(Double.self, forKey: .redSuitBlue) ?? 0.1
        redSuitAlpha = try container.decodeIfPresent(Double.self, forKey: .redSuitAlpha) ?? 1.0
        shadowRed = try container.decodeIfPresent(Double.self, forKey: .shadowRed) ?? 0.0
        shadowGreen = try container.decodeIfPresent(Double.self, forKey: .shadowGreen) ?? 0.0
        shadowBlue = try container.decodeIfPresent(Double.self, forKey: .shadowBlue) ?? 0.0
        shadowAlpha = try container.decodeIfPresent(Double.self, forKey: .shadowAlpha) ?? 0.15
        hintHighlightRed = try container.decodeIfPresent(Double.self, forKey: .hintHighlightRed) ?? 1.0
        hintHighlightGreen = try container.decodeIfPresent(Double.self, forKey: .hintHighlightGreen) ?? 0.843
        hintHighlightBlue = try container.decodeIfPresent(Double.self, forKey: .hintHighlightBlue) ?? 0.0
        hintHighlightAlpha = try container.decodeIfPresent(Double.self, forKey: .hintHighlightAlpha) ?? 1.0
    }

    public mutating func reset() {
        isEnabled = false
        bgRed = 1.0; bgGreen = 1.0; bgBlue = 1.0; bgAlpha = 1.0
        outlineRed = 0.0; outlineGreen = 0.0; outlineBlue = 0.0; outlineAlpha = 0.85
        blackSuitRed = 0.1; blackSuitGreen = 0.1; blackSuitBlue = 0.1; blackSuitAlpha = 1.0
        redSuitRed = 0.8; redSuitGreen = 0.1; redSuitBlue = 0.1; redSuitAlpha = 1.0
        shadowRed = 0.0; shadowGreen = 0.0; shadowBlue = 0.0; shadowAlpha = 0.15
        hintHighlightRed = 1.0; hintHighlightGreen = 0.843; hintHighlightBlue = 0.0; hintHighlightAlpha = 1.0
    }
}

extension CustomCardColorGroup {
    public var backgroundColor: Color {
        get { Color(red: bgRed, green: bgGreen, blue: bgBlue, opacity: bgAlpha) }
        set {
            if let rgb = rgbaComponents(of: newValue) {
                bgRed = rgb.red
                bgGreen = rgb.green
                bgBlue = rgb.blue
                bgAlpha = rgb.alpha
                isEnabled = true
            }
        }
    }
    
    public var outlineColor: Color {
        get { Color(red: outlineRed, green: outlineGreen, blue: outlineBlue, opacity: outlineAlpha) }
        set {
            if let rgb = rgbaComponents(of: newValue) {
                outlineRed = rgb.red
                outlineGreen = rgb.green
                outlineBlue = rgb.blue
                outlineAlpha = rgb.alpha
                isEnabled = true
            }
        }
    }
    
    public var blackSuitColor: Color {
        get { Color(red: blackSuitRed, green: blackSuitGreen, blue: blackSuitBlue, opacity: blackSuitAlpha) }
        set {
            if let rgb = rgbaComponents(of: newValue) {
                blackSuitRed = rgb.red
                blackSuitGreen = rgb.green
                blackSuitBlue = rgb.blue
                blackSuitAlpha = rgb.alpha
                isEnabled = true
            }
        }
    }
    
    public var redSuitColor: Color {
        get { Color(red: redSuitRed, green: redSuitGreen, blue: redSuitBlue, opacity: redSuitAlpha) }
        set {
            if let rgb = rgbaComponents(of: newValue) {
                redSuitRed = rgb.red
                redSuitGreen = rgb.green
                redSuitBlue = rgb.blue
                redSuitAlpha = rgb.alpha
                isEnabled = true
            }
        }
    }
    
    public var shadowColor: Color {
        get { Color(red: shadowRed, green: shadowGreen, blue: shadowBlue, opacity: shadowAlpha) }
        set {
            if let rgb = rgbaComponents(of: newValue) {
                shadowRed = rgb.red
                shadowGreen = rgb.green
                shadowBlue = rgb.blue
                shadowAlpha = rgb.alpha
                isEnabled = true
            }
        }
    }

    // Does not set isEnabled — the hint highlight applies regardless of whether the
    // rest of the custom card color scheme is toggled on.
    public var hintHighlightColor: Color {
        get { Color(red: hintHighlightRed, green: hintHighlightGreen, blue: hintHighlightBlue, opacity: hintHighlightAlpha) }
        set {
            if let rgb = rgbaComponents(of: newValue) {
                hintHighlightRed = rgb.red
                hintHighlightGreen = rgb.green
                hintHighlightBlue = rgb.blue
                hintHighlightAlpha = rgb.alpha
            }
        }
    }
}
