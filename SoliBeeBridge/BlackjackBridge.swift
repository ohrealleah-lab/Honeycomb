import Foundation

// Define the incoming command structure
struct Command: Codable {
    let action: String
    let amount: Int?
}

@main
struct Bridge {
    static func main() {
        // Setup ViewModel
        BlackjackViewModel.isHeadlessMode = true
        let vm = BlackjackViewModel()
        vm.startNewGame() // Ensure we're in a clean state

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Print initial state so the agent knows what's going on
        if let data = try? encoder.encode(vm.state), let str = String(data: data, encoding: .utf8) {
            print(str)
            fflush(stdout)
        }

        // Read commands from standard input
        while let line = readLine() {
            guard let data = line.data(using: .utf8) else { continue }
            
            do {
                let cmd = try decoder.decode(Command.self, from: data)
                switch cmd.action {
                case "deal": vm.deal()
                case "hit": vm.hit()
                case "stand": vm.stand()
                case "doubleDown": vm.doubleDown()
                case "split": vm.split()
                case "addToBet": 
                    if let amt = cmd.amount { vm.addToBet(amt) }
                case "clearBet": vm.clearBet()
                case "rebuy": vm.rebuy()
                case "startNewGame": vm.startNewGame()
                default:
                    print("{\"error\": \"Unknown action: \\(cmd.action)\"}")
                    fflush(stdout)
                    continue
                }
                
                // Output new state
                if let outData = try? encoder.encode(vm.state), let str = String(data: outData, encoding: .utf8) {
                    print(str)
                    fflush(stdout)
                }
            } catch {
                print("{\"error\": \"Invalid JSON or command format\"}")
                fflush(stdout)
            }
        }
    }
}
