import Foundation

@main
struct UniversalBridge {
    static func getKlondikePile(id: String, state: GameState) -> Pile? {
        if state.stock.id == id { return state.stock }
        if state.waste.id == id { return state.waste }
        if let p = state.foundations.first(where: { $0.id == id }) { return p }
        if let p = state.tableau.first(where: { $0.id == id }) { return p }
        return nil
    }

    static func getSpiderPile(id: String, state: SpiderState) -> Pile? {
        if state.stock.id == id { return state.stock }
        if let p = state.foundations.first(where: { $0.id == id }) { return p }
        if let p = state.tableau.first(where: { $0.id == id }) { return p }
        return nil
    }

    static func getBeecellPile(id: String, state: BeecellState) -> Pile? {
        if let p = state.freeCells.first(where: { $0.id == id }) { return p }
        if let p = state.foundations.first(where: { $0.id == id }) { return p }
        if let p = state.tableau.first(where: { $0.id == id }) { return p }
        return nil
    }

    static func main() {
        // Disable UI sounds to prevent headless crashes
        UISound.isHeadlessMode = true

        let args = CommandLine.arguments
        let gameName = args.count > 1 ? args[1] : "Blackjack"
        
        var isVegas = false
        var drawMode = 3
        var noStress = false
        
        var i = 2
        while i < args.count {
            if args[i] == "--vegas" && i + 1 < args.count {
                isVegas = (args[i+1] == "true")
                i += 2
            } else if args[i] == "--drawMode" && i + 1 < args.count {
                drawMode = Int(args[i+1]) ?? 3
                i += 2
            } else if args[i] == "--noStress" && i + 1 < args.count {
                noStress = (args[i+1] == "true")
                i += 2
            } else {
                i += 1
            }
        }

        let encoder = JSONEncoder()
        
        switch gameName {
        case "VideoPoker":
            let vm = VideoPokerViewModel()
            vm.options.noStressMode = noStress
            vm.startNewGame()
            if let data = try? encoder.encode(vm.state), let str = String(data: data, encoding: .utf8) {
                print(str)
                fflush(stdout)
            }
            
            while let line = readLine() {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let action = json["action"] as? String else { continue }
                
                switch action {
                case "deal": vm.deal()
                case "draw": vm.draw()
                case "toggleHold":
                    if let index = json["index"] as? Int { vm.toggleHold(at: index) }
                case "increaseBet": vm.increaseBet()
                case "decreaseBet": vm.decreaseBet()
                case "maxBet": vm.maxBet()
                case "startNewGame": vm.startNewGame()
                default: break
                }
                
                if let data = try? encoder.encode(vm.state), let str = String(data: data, encoding: .utf8) {
                    print(str)
                    fflush(stdout)
                }
            }

        case "Blackjack":
            let vm = BlackjackViewModel()
            vm.options.noStressMode = noStress
            vm.startNewGame()
            if let data = try? encoder.encode(vm.state), let str = String(data: data, encoding: .utf8) {
                print(str)
                fflush(stdout)
            }
            
            while let line = readLine() {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let action = json["action"] as? String else { continue }
                
                switch action {
                case "deal": vm.deal()
                case "hit": vm.hit()
                case "stand": vm.stand()
                case "doubleDown": vm.doubleDown()
                case "split": vm.split()
                case "addToBet": 
                    if let amt = json["amount"] as? Int { vm.addToBet(amt) }
                case "clearBet": vm.clearBet()
                case "startNewGame": vm.startNewGame()
                default: break
                }
                
                if let data = try? encoder.encode(vm.state), let str = String(data: data, encoding: .utf8) {
                    print(str)
                    fflush(stdout)
                }
            }
            
        case "Klondike":
            let vm = GameViewModel()
            vm.options.isVegasScoring = isVegas
            vm.options.drawMode = (drawMode == 1) ? .drawOne : .drawThree
            vm.startNewGame()
            if let data = try? encoder.encode(vm.state), let str = String(data: data, encoding: .utf8) {
                print(str)
                fflush(stdout)
            }
            
            while let line = readLine() {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let action = json["action"] as? String else { continue }
                
                switch action {
                case "draw": vm.drawCard()
                case "startNewGame": vm.startNewGame()
                case "hint":
                    vm.findHint()
                    if let hint = vm.activeHint,
                       let sourcePile = getKlondikePile(id: hint.sourcePileId, state: vm.state),
                       let targetPile = getKlondikePile(id: hint.targetPileId, state: vm.state) {
                        if hint.sourcePileId == "stock" {
                            vm.drawCard()
                        } else if let cardIndex = sourcePile.cards.firstIndex(where: { $0.id == hint.card.id }) {
                            let cardsToMove = Array(sourcePile.cards.suffix(from: cardIndex))
                            vm.moveCards(cardsToMove, from: sourcePile, to: targetPile)
                        }
                    }
                case "move":
                    if let srcId = json["source"] as? String,
                       let tgtId = json["target"] as? String,
                       let count = json["count"] as? Int,
                       let sourcePile = getKlondikePile(id: srcId, state: vm.state),
                       let targetPile = getKlondikePile(id: tgtId, state: vm.state) {
                        let cardsToMove = Array(sourcePile.cards.suffix(count))
                        vm.moveCards(cardsToMove, from: sourcePile, to: targetPile)
                    }
                default: break
                }
                
                if let data = try? encoder.encode(vm.state), let str = String(data: data, encoding: .utf8) {
                    print(str)
                    fflush(stdout)
                }
            }
            
        case "Spider":
            let vm = SpiderViewModel()
            if let data = try? encoder.encode(vm.state), let str = String(data: data, encoding: .utf8) {
                print(str)
                fflush(stdout)
            }
            while let line = readLine() {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let action = json["action"] as? String else { continue }
                switch action {
                case "deal": vm.drawFromStock()
                case "startNewGame": vm.startNewGame()
                case "move":
                    if let srcId = json["source"] as? String,
                       let tgtId = json["target"] as? String,
                       let count = json["count"] as? Int,
                       let sourcePile = getSpiderPile(id: srcId, state: vm.state),
                       let targetPile = getSpiderPile(id: tgtId, state: vm.state) {
                        let cardsToMove = Array(sourcePile.cards.suffix(count))
                        vm.moveCards(cardsToMove, from: sourcePile, to: targetPile)
                    }
                default: break
                }
                if let data = try? encoder.encode(vm.state), let str = String(data: data, encoding: .utf8) {
                    print(str)
                    fflush(stdout)
                }
            }

        case "Beecell":
            let vm = BeecellViewModel()
            if let data = try? encoder.encode(vm.state), let str = String(data: data, encoding: .utf8) {
                print(str)
                fflush(stdout)
            }
            while let line = readLine() {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let action = json["action"] as? String else { continue }
                switch action {
                case "startNewGame": vm.startNewGame()
                case "move":
                    if let srcId = json["source"] as? String,
                       let tgtId = json["target"] as? String,
                       let count = json["count"] as? Int,
                       let sourcePile = getBeecellPile(id: srcId, state: vm.state),
                       let targetPile = getBeecellPile(id: tgtId, state: vm.state) {
                        let cardsToMove = Array(sourcePile.cards.suffix(count))
                        vm.moveCards(cardsToMove, from: sourcePile, to: targetPile)
                    }
                default: break
                }
                if let data = try? encoder.encode(vm.state), let str = String(data: data, encoding: .utf8) {
                    print(str)
                    fflush(stdout)
                }
            }

        case "Honeycomb":
            let vm = HoneycombViewModel()
            vm.options.noStressMode = noStress
            vm.startNewGame()
            if let data = try? encoder.encode(vm.state), let str = String(data: data, encoding: .utf8) {
                print(str)
                fflush(stdout)
            }
            while let line = readLine() {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let action = json["action"] as? String else { continue }
                switch action {
                case "startNewGame": vm.startNewGame()
                case "playCard":
                    if let handIdx = json["handIndex"] as? Int,
                       let boardIdx = json["boardIndex"] as? Int {
                        vm.playerPlayCard(handIndex: handIdx, boardIndex: boardIdx)
                    }
                case "takeCard":
                    if let boardIdx = json["boardIndex"] as? Int,
                       let replaceHandIdx = json["replaceHandIndex"] as? Int {
                        vm.takeCard(boardIndex: boardIdx, replaceHandIndex: replaceHandIdx)
                    }
                default: break
                }
                if let data = try? encoder.encode(vm.state), let str = String(data: data, encoding: .utf8) {
                    print(str)
                    fflush(stdout)
                }
            }

        default:
            print("Unknown game: \(gameName)")
            exit(1)
        }
    }
}
