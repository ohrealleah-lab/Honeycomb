import Foundation

@main
struct TestRunner {
    static func main() {
        print("🚀 Starting SoliBee Test Suite...")
        
        print("🧪 Running GameStateTests...")
        GameStateTests.run()
        print("✅ GameStateTests passed.")
        
        print("🧪 Running GameViewModelTests...")
        GameViewModelTests.run()
        print("✅ GameViewModelTests passed.")
        
        print("🧪 Running AppCoordinatorTests...")
        AppCoordinatorTests.run()
        print("✅ AppCoordinatorTests passed.")
        
        print("🧪 Running SpiderTests...")
        SpiderTests.run()
        print("✅ SpiderTests passed.")
        
        print("🧪 Running CustomCardColorsTests...")
        CustomCardColorsTests.run()
        print("✅ CustomCardColorsTests passed.")
        
        print("🎉 ALL TESTS PASSED SUCCESSFULLY!")
    }
}
