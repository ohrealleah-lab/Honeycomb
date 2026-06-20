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
        
        print("🎉 ALL TESTS PASSED SUCCESSFULLY!")
    }
}
