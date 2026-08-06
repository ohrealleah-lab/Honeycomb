import Foundation

@main
struct TestRunner {
    static func main() {
        setbuf(stdout, nil) // unbuffered — otherwise a fatalError() trap discards everything printed so far
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
        
        print("🧪 Running BeecellTests...")
        BeecellTests.run()
        print("✅ BeecellTests passed.")

        print("🧪 Running SmartDropTests...")
        SmartDropTests.run()
        print("✅ SmartDropTests passed.")

        print("🧪 Running CustomCardColorsTests...")
        CustomCardColorsTests.run()
        print("✅ CustomCardColorsTests passed.")

        print("🧪 Running HoneycombCardGeneratorTests...")
        HoneycombCardGeneratorTests.run()
        print("✅ HoneycombCardGeneratorTests passed.")

        print("🧪 Running HoneycombBombShelterTests...")
        HoneycombBombShelterTests.run()
        print("✅ HoneycombBombShelterTests passed.")

        print("🧪 Running HoneycombBannerCatalogTests...")
        HoneycombBannerCatalogTests.run()
        print("✅ HoneycombBannerCatalogTests passed.")

        print("🧪 Running HoneycombBannerTriggerTests...")
        HoneycombBannerTriggerTests.run()
        print("✅ HoneycombBannerTriggerTests passed.")

        print("🧪 Running CrossGameRegressionTests...")
        CrossGameRegressionTests.run()
        print("✅ CrossGameRegressionTests passed.")

        VideoPokerAndBlackjackTests.run()
        
        print("🎉 ALL TESTS PASSED SUCCESSFULLY!")
    }
}
