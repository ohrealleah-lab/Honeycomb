import Foundation

struct CustomCardColorsTests {
    static func run() {
        testDefaults()
        testReset()
        testCodable()
        testAutoEnables()
    }
    
    private static func testDefaults() {
        let colors = CustomCardColorGroup()
        assert(!colors.isEnabled, "Custom card colors should be disabled by default")
        
        // Assert some default components
        assert(colors.bgRed == 1.0 && colors.bgGreen == 1.0 && colors.bgBlue == 1.0, "Background should be white by default")
        assert(colors.shadowAlpha == 0.15, "Default shadow opacity should be 0.15")
    }
    
    private static func testReset() {
        var colors = CustomCardColorGroup()
        colors.isEnabled = true
        colors.bgRed = 0.5
        colors.bgGreen = 0.2
        colors.bgBlue = 0.8
        
        colors.reset()
        
        assert(!colors.isEnabled, "isEnabled should be false after reset")
        assert(colors.bgRed == 1.0 && colors.bgGreen == 1.0 && colors.bgBlue == 1.0, "Background should be reset to white")
    }
    
    private static func testCodable() {
        var colors = CustomCardColorGroup()
        colors.isEnabled = true
        colors.outlineRed = 0.1
        colors.outlineGreen = 0.2
        colors.outlineBlue = 0.3
        
        guard let data = try? JSONEncoder().encode(colors) else {
            fatalError("Failed to encode CustomCardColorGroup")
        }
        
        guard let decoded = try? JSONDecoder().decode(CustomCardColorGroup.self, from: data) else {
            fatalError("Failed to decode CustomCardColorGroup")
        }
        
        assert(decoded.isEnabled, "Decoded group should be enabled")
        assert(decoded.outlineRed == 0.1, "Decoded outlineRed should match")
        assert(decoded.outlineGreen == 0.2, "Decoded outlineGreen should match")
        assert(decoded.outlineBlue == 0.3, "Decoded outlineBlue should match")
    }
    
    private static func testAutoEnables() {
        var colors = CustomCardColorGroup()
        assert(!colors.isEnabled, "Should be disabled initially")
        colors.outlineColor = .blue
        assert(colors.isEnabled, "Should be enabled after outlineColor assignment")
        
        colors.reset()
        assert(!colors.isEnabled, "Should be disabled after reset")
        colors.backgroundColor = .red
        assert(colors.isEnabled, "Should be enabled after backgroundColor assignment")
    }
}
