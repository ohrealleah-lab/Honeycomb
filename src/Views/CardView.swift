import SwiftUI

public struct CardView: View {
    public let card: Card
    @Environment(GameViewModel.self) private var viewModel: GameViewModel?
    
    private var outlineColor: Color {
        if !card.faceUp && (viewModel?.cardBackTheme ?? "Vulpera") == "Dingwall" {
            // Charcoal/grey to match the Dingwall image background and silver hardware
            return Color(red: 0.35, green: 0.35, blue: 0.36)
        }
        return Color.black.opacity(0.85)
    }
    
    public var body: some View {
        ZStack {
            if card.faceUp {
                CardFrontView(card: card)
            } else {
                CardBackView()
            }
        }
        .frame(width: 80, height: 112)
        .background(Color.white)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(outlineColor, lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1.5)
    }
}

// MARK: - Card Front Rendering

struct CardFrontView: View {
    let card: Card
    
    var color: Color {
        card.isRed ? Color(red: 0.8, green: 0.1, blue: 0.1) : Color(red: 0.1, green: 0.1, blue: 0.1)
    }
    
    var body: some View {
        ZStack {
            // Top Left Index (Horizontal, decreased size)
            HStack(alignment: .center, spacing: 1) {
                Text(card.rankString)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Text(card.suit.symbol)
                    .font(.system(size: 9))
            }
            .foregroundColor(color)
            .padding(.leading, 5)
            .padding(.top, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Center Suit Icon(s) (Larger, takes up most of card)
            CardCenterSuitView(suit: card.suit, rank: card.rank, color: color)
                .frame(width: 54, height: 86)
            
            // Bottom Right Index (Horizontal, inverted, decreased size)
            HStack(alignment: .center, spacing: 1) {
                Text(card.rankString)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Text(card.suit.symbol)
                    .font(.system(size: 9))
            }
            .foregroundColor(color)
            .rotationEffect(.degrees(180))
            .padding(.trailing, 5)
            .padding(.bottom, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
}

struct SuitPosition {
    let x: CGFloat
    let y: CGFloat
    let isUpsideDown: Bool
}

struct KingCrownShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - h * 0.25))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.8, y: rect.maxY - h * 0.75))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.62, y: rect.maxY - h * 0.35))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.38, y: rect.maxY - h * 0.35))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.2, y: rect.maxY - h * 0.75))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - h * 0.25))
        path.closeSubpath()
        return path
    }
}

struct QueenTiaraShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: rect.minX + w * 0.1, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - w * 0.1, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - h * 0.3), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.85, y: rect.maxY - h * 0.75))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.65, y: rect.maxY - h * 0.4))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY), control: CGPoint(x: rect.minX + w * 0.58, y: rect.minY + h * 0.2))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.35, y: rect.maxY - h * 0.4), control: CGPoint(x: rect.minX + w * 0.42, y: rect.minY + h * 0.2))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.15, y: rect.maxY - h * 0.75))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.1, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY - h * 0.3))
        path.closeSubpath()
        return path
    }
}

struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let h = rect.height
        
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.5))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.minY + h * 0.85))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.5), control: CGPoint(x: rect.minX, y: rect.minY + h * 0.85))
        path.closeSubpath()
        return path
    }
}

struct CardCenterSuitView: View {
    let suit: Card.Suit
    let rank: Int
    let color: Color
    
    var body: some View {
        Group {
            if rank == 1 {
                // Ace - single large suit
                Text(suit.symbol)
                    .font(.system(size: 38))
                    .foregroundColor(color)
            } else if rank == 11 {
                // Jack - high fidelity shield
                HighFidelityShieldView(color: color, suitSymbol: suit.symbol)
            } else if rank == 12 {
                // Queen - high fidelity tiara
                HighFidelityTiaraView(color: color, suitSymbol: suit.symbol)
            } else if rank == 13 {
                // King - high fidelity crown
                HighFidelityCrownView(color: color, suitSymbol: suit.symbol)
            } else {
                // Numbered cards 2 to 10
                ZStack {
                    ForEach(Array(positionsFor(rank: rank).enumerated()), id: \.offset) { _, pos in
                        Text(suit.symbol)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(color)
                            .rotationEffect(.degrees(pos.isUpsideDown ? 180 : 0))
                            .offset(x: pos.x, y: pos.y)
                    }
                }
                .frame(width: 54, height: 86)
            }
        }
    }
    
    private func positionsFor(rank: Int) -> [SuitPosition] {
        switch rank {
        case 2:
            return [
                SuitPosition(x: 0, y: -26, isUpsideDown: false),
                SuitPosition(x: 0, y: 26, isUpsideDown: true)
            ]
        case 3:
            return [
                SuitPosition(x: 0, y: -26, isUpsideDown: false),
                SuitPosition(x: 0, y: 0, isUpsideDown: false),
                SuitPosition(x: 0, y: 26, isUpsideDown: true)
            ]
        case 4:
            return [
                SuitPosition(x: -16, y: -26, isUpsideDown: false),
                SuitPosition(x: 16, y: -26, isUpsideDown: false),
                SuitPosition(x: -16, y: 26, isUpsideDown: true),
                SuitPosition(x: 16, y: 26, isUpsideDown: true)
            ]
        case 5:
            return [
                SuitPosition(x: -16, y: -26, isUpsideDown: false),
                SuitPosition(x: 16, y: -26, isUpsideDown: false),
                SuitPosition(x: 0, y: 0, isUpsideDown: false),
                SuitPosition(x: -16, y: 26, isUpsideDown: true),
                SuitPosition(x: 16, y: 26, isUpsideDown: true)
            ]
        case 6:
            return [
                SuitPosition(x: -16, y: -26, isUpsideDown: false),
                SuitPosition(x: 16, y: -26, isUpsideDown: false),
                SuitPosition(x: -16, y: 0, isUpsideDown: false),
                SuitPosition(x: 16, y: 0, isUpsideDown: false),
                SuitPosition(x: -16, y: 26, isUpsideDown: true),
                SuitPosition(x: 16, y: 26, isUpsideDown: true)
            ]
        case 7:
            return [
                SuitPosition(x: -16, y: -26, isUpsideDown: false),
                SuitPosition(x: 16, y: -26, isUpsideDown: false),
                SuitPosition(x: -16, y: 0, isUpsideDown: false),
                SuitPosition(x: 16, y: 0, isUpsideDown: false),
                SuitPosition(x: -16, y: 26, isUpsideDown: true),
                SuitPosition(x: 16, y: 26, isUpsideDown: true),
                SuitPosition(x: 0, y: -13, isUpsideDown: false)
            ]
        case 8:
            return [
                SuitPosition(x: -16, y: -26, isUpsideDown: false),
                SuitPosition(x: 16, y: -26, isUpsideDown: false),
                SuitPosition(x: -16, y: 0, isUpsideDown: false),
                SuitPosition(x: 16, y: 0, isUpsideDown: false),
                SuitPosition(x: -16, y: 26, isUpsideDown: true),
                SuitPosition(x: 16, y: 26, isUpsideDown: true),
                SuitPosition(x: 0, y: -13, isUpsideDown: false),
                SuitPosition(x: 0, y: 13, isUpsideDown: true)
            ]
        case 9:
            return [
                SuitPosition(x: -16, y: -26, isUpsideDown: false),
                SuitPosition(x: 16, y: -26, isUpsideDown: false),
                SuitPosition(x: -16, y: -9, isUpsideDown: false),
                SuitPosition(x: 16, y: -9, isUpsideDown: false),
                SuitPosition(x: -16, y: 9, isUpsideDown: true),
                SuitPosition(x: 16, y: 9, isUpsideDown: true),
                SuitPosition(x: -16, y: 26, isUpsideDown: true),
                SuitPosition(x: 16, y: 26, isUpsideDown: true),
                SuitPosition(x: 0, y: 0, isUpsideDown: false)
            ]
        case 10:
            return [
                SuitPosition(x: -16, y: -26, isUpsideDown: false),
                SuitPosition(x: 16, y: -26, isUpsideDown: false),
                SuitPosition(x: -16, y: -9, isUpsideDown: false),
                SuitPosition(x: 16, y: -9, isUpsideDown: false),
                SuitPosition(x: -16, y: 9, isUpsideDown: true),
                SuitPosition(x: 16, y: 9, isUpsideDown: true),
                SuitPosition(x: -16, y: 26, isUpsideDown: true),
                SuitPosition(x: 16, y: 26, isUpsideDown: true),
                SuitPosition(x: 0, y: -17, isUpsideDown: false),
                SuitPosition(x: 0, y: 17, isUpsideDown: true)
            ]
        default:
            return []
        }
    }
}

// MARK: - Card Back Rendering (Custom Bee Theme)

// MARK: - Card Back Rendering (Custom Bee Theme)

struct CardBackView: View {
    @Environment(GameViewModel.self) private var viewModel: GameViewModel?
    
    var body: some View {
        let theme = viewModel?.cardBackTheme ?? "Vulpera"
        
        ZStack {
            if theme == "Blue Rose" {
                BlueRoseView()
            } else if theme == "Spooky Castle" {
                SpookyCastleView()
            } else if theme == "Palm Tree" {
                PalmTreeView()
            } else if theme == "Aquarium Fish" {
                AquariumFishView()
            } else if theme == "Moogle" {
                // Moogle image filling the card back (zoomed by 25%)
                if let path = Bundle.main.path(forResource: "moogle", ofType: "jpg") ?? Bundle.main.path(forResource: "moogle", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 104)
                        .scaleEffect(1.25)
                } else {
                    Circle().fill(Color(red: 0.1, green: 0.3, blue: 0.6).opacity(0.3)).frame(width: 10, height: 10)
                }
            } else if theme == "Dingwall" {
                // Dingwall image stretching the full size of the card
                if let path = Bundle.main.path(forResource: "dingwall", ofType: "jpg") ?? Bundle.main.path(forResource: "dingwall", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 80, height: 112)
                } else {
                    Circle().fill(Color(red: 0.1, green: 0.3, blue: 0.6).opacity(0.3)).frame(width: 10, height: 10)
                }
            } else {
                // Priest image filling the card back (Vulpera)
                if let path = Bundle.main.path(forResource: "priest", ofType: "png") ?? Bundle.main.path(forResource: "priest", ofType: "jpg"),
                   let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 104)
                } else {
                    Circle().fill(Color(red: 0.1, green: 0.3, blue: 0.6).opacity(0.3)).frame(width: 10, height: 10)
                }
            }
        }
        .frame(width: 80, height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct BlueRoseView: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.1, green: 0.2, blue: 0.65), Color(red: 0.02, green: 0.05, blue: 0.25)],
                center: .center, startRadius: 5, endRadius: 65
            )
            ZStack {
                Image(systemName: "laurel.leading")
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 0.4).opacity(0.6))
                    .font(.system(size: 40))
                
                ForEach(0..<6) { i in
                    Ellipse()
                        .stroke(Color(red: 0.5, green: 0.75, blue: 1.0), lineWidth: 1.5)
                        .background(Ellipse().fill(Color(red: 0.1, green: 0.35, blue: 0.85).opacity(0.3)))
                        .frame(width: 28 - CGFloat(i * 3), height: 38 - CGFloat(i * 5))
                        .rotationEffect(.degrees(Double(i * 35)))
                }
                
                Circle()
                    .fill(Color(red: 0.7, green: 0.88, blue: 1.0))
                    .frame(width: 6, height: 6)
            }
            .scaleEffect(1.2)
        }
    }
}

struct SpookyCastleView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.1, blue: 0.25), Color(red: 0.05, green: 0.02, blue: 0.1)],
                startPoint: .top, endPoint: .bottom
            )
            
            Circle()
                .fill(Color(red: 0.98, green: 0.98, blue: 0.75))
                .shadow(color: Color(red: 0.98, green: 0.98, blue: 0.75).opacity(0.6), radius: 10)
                .frame(width: 36, height: 36)
                .offset(x: 14, y: -24)
            
            Path { path in
                path.move(to: CGPoint(x: 10, y: 100))
                path.addLine(to: CGPoint(x: 70, y: 100))
                path.addLine(to: CGPoint(x: 70, y: 70))
                path.addLine(to: CGPoint(x: 62, y: 70))
                path.addLine(to: CGPoint(x: 62, y: 40))
                path.addLine(to: CGPoint(x: 58, y: 40))
                path.addLine(to: CGPoint(x: 58, y: 70))
                path.addLine(to: CGPoint(x: 48, y: 70))
                path.addLine(to: CGPoint(x: 48, y: 25))
                path.addLine(to: CGPoint(x: 42, y: 25))
                path.addLine(to: CGPoint(x: 42, y: 15))
                path.addLine(to: CGPoint(x: 38, y: 25))
                path.addLine(to: CGPoint(x: 32, y: 25))
                path.addLine(to: CGPoint(x: 32, y: 70))
                path.addLine(to: CGPoint(x: 22, y: 70))
                path.addLine(to: CGPoint(x: 22, y: 40))
                path.addLine(to: CGPoint(x: 18, y: 40))
                path.addLine(to: CGPoint(x: 18, y: 70))
                path.addLine(to: CGPoint(x: 10, y: 70))
                path.closeSubpath()
            }
            .fill(Color(red: 0.08, green: 0.08, blue: 0.15))
            .offset(x: 0, y: 6)
            
            Group {
                Image(systemName: "bird")
                    .font(.system(size: 8))
                    .foregroundColor(.black)
                    .rotationEffect(.degrees(-15))
                    .offset(x: -16, y: -20)
                
                Image(systemName: "bird")
                    .font(.system(size: 6))
                    .foregroundColor(.black)
                    .rotationEffect(.degrees(10))
                    .offset(x: -8, y: -32)
            }
        }
    }
}

struct PalmTreeView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.3, blue: 0.5), Color(red: 0.95, green: 0.6, blue: 0.2)],
                startPoint: .top, endPoint: .bottom
            )
            
            Circle()
                .fill(Color(red: 0.98, green: 0.85, blue: 0.3))
                .frame(width: 44, height: 44)
                .offset(x: 0, y: 15)
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: 90))
                path.addQuadCurve(to: CGPoint(x: 80, y: 90), control: CGPoint(x: 40, y: 82))
                path.addLine(to: CGPoint(x: 80, y: 112))
                path.addLine(to: CGPoint(x: 0, y: 112))
                path.closeSubpath()
            }
            .fill(Color(red: 0.15, green: 0.05, blue: 0.2))
            
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 35, y: 90))
                    path.addQuadCurve(to: CGPoint(x: 25, y: 45), control: CGPoint(x: 28, y: 70))
                    path.addLine(to: CGPoint(x: 28, y: 45))
                    path.addQuadCurve(to: CGPoint(x: 39, y: 90), control: CGPoint(x: 32, y: 70))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.15, green: 0.05, blue: 0.2))
                
                ForEach(0..<5) { i in
                    Ellipse()
                        .fill(Color(red: 0.15, green: 0.05, blue: 0.2))
                        .frame(width: 24, height: 8)
                        .rotationEffect(.degrees(Double(i * 35 - 70)))
                        .offset(x: -8 + CGFloat(i * 3), y: -15 + CGFloat(abs(i - 2) * 2))
                }
                .offset(x: 26, y: 45)
            }
        }
    }
}

struct AquariumFishView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.3, blue: 0.5), Color(red: 0.01, green: 0.1, blue: 0.35)],
                startPoint: .top, endPoint: .bottom
            )
            
            ForEach(0..<6) { i in
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 0.8)
                    .frame(width: CGFloat(2 + i % 3 * 2), height: CGFloat(2 + i % 3 * 2))
                    .position(
                        x: CGFloat(15 + (i * 12) % 55),
                        y: CGFloat(90 - i * 15)
                    )
            }
            
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 18, y: 0))
                    path.addLine(to: CGPoint(x: 28, y: -10))
                    path.addLine(to: CGPoint(x: 25, y: 0))
                    path.addLine(to: CGPoint(x: 28, y: 10))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.95, green: 0.45, blue: 0.15))
                .offset(x: 10, y: 0)
                
                Ellipse()
                    .fill(Color(red: 0.95, green: 0.45, blue: 0.15))
                    .frame(width: 26, height: 16)
                    .overlay(
                        Ellipse()
                            .stroke(Color(red: 1.0, green: 0.6, blue: 0.3), lineWidth: 1)
                    )
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .overlay(Circle().fill(Color.black).frame(width: 1.5, height: 1.5))
                    .offset(x: -8, y: -2)
                
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addQuadCurve(to: CGPoint(x: 4, y: 6), control: CGPoint(x: 3, y: 3))
                    path.addQuadCurve(to: CGPoint(x: -2, y: 2), control: CGPoint(x: 1, y: 4))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.95, green: 0.55, blue: 0.25))
                .offset(x: -2, y: 3)
            }
            .scaleEffect(1.2)
        }
    }
}

struct BeeSideProfile: View {
    var body: some View {
        ZStack {
            // Legs (drawn behind the body)
            ZStack {
                // Front leg
                Path { path in
                    path.move(to: CGPoint(x: 6, y: 0))
                    path.addLine(to: CGPoint(x: 3, y: 7))
                    path.addLine(to: CGPoint(x: 0, y: 11))
                }
                .stroke(Color.black, lineWidth: 1.5)
                .frame(width: 8, height: 12)
                .offset(x: -8, y: 10)
                
                // Middle leg
                Path { path in
                    path.move(to: CGPoint(x: 3, y: 0))
                    path.addLine(to: CGPoint(x: 3, y: 8))
                    path.addLine(to: CGPoint(x: 0, y: 12))
                }
                .stroke(Color.black, lineWidth: 1.5)
                .frame(width: 6, height: 12)
                .offset(x: -1, y: 10)
                
                // Back leg
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 2, y: 8))
                    path.addLine(to: CGPoint(x: 6, y: 12))
                }
                .stroke(Color.black, lineWidth: 1.5)
                .frame(width: 8, height: 12)
                .offset(x: 6, y: 9)
            }
            
            // Abdomen (Gold with Black Stripes & Stinger)
            ZStack {
                // Stinger (triangle pointing right-down)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 5, y: 2))
                    path.addLine(to: CGPoint(x: 0, y: 4))
                    path.closeSubpath()
                }
                .fill(Color.black)
                .offset(x: 12, y: 1)
                
                // Abdomen oval
                Ellipse()
                    .fill(Color(red: 0.95, green: 0.75, blue: 0.15)) // Gold
                    .frame(width: 26, height: 16)
                    .overlay(
                        // Black Stripes
                        HStack(spacing: 3) {
                            Spacer()
                            Rectangle().fill(Color.black).frame(width: 3.5)
                            Rectangle().fill(Color.black).frame(width: 3.5)
                            Rectangle().fill(Color.black).frame(width: 3.5)
                            Spacer()
                        }
                        .clipShape(Ellipse())
                    )
                    .overlay(Ellipse().stroke(Color.black, lineWidth: 1))
            }
            .rotationEffect(.degrees(15))
            .offset(x: 12, y: 3)
            
            // Thorax (fuzzy middle section, black)
            Circle()
                .fill(Color.black)
                .frame(width: 16, height: 16)
                .offset(x: -4, y: 0)
            
            // Head
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 12, height: 12)
                
                // Eye (tiny gold circle)
                Circle()
                    .fill(Color(red: 0.95, green: 0.75, blue: 0.15))
                    .frame(width: 2, height: 2)
                    .offset(x: -3, y: -1)
            }
            .offset(x: -15, y: -1)
            
            // Antenna
            Path { path in
                path.move(to: CGPoint(x: 6, y: 8))
                path.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: 2, y: 5))
            }
            .stroke(Color.black, lineWidth: 1.2)
            .frame(width: 8, height: 8)
            .offset(x: -21, y: -9)
            
            // Wings (pointing up-right)
            ZStack {
                // Back wing
                Ellipse()
                    .fill(Color.white.opacity(0.6))
                    .stroke(Color.black.opacity(0.6), lineWidth: 0.8)
                    .frame(width: 10, height: 18)
                    .rotationEffect(.degrees(-35))
                    .offset(x: -2, y: -14)
                
                // Front wing
                Ellipse()
                    .fill(Color.white.opacity(0.85))
                    .stroke(Color.black, lineWidth: 1)
                    .frame(width: 12, height: 22)
                    .rotationEffect(.degrees(-15))
                    .offset(x: 4, y: -17)
            }
        }
        .frame(width: 60, height: 60)
    }
}

// MARK: - High Fidelity Face Card Icons & Views

struct CapBackingShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - h * 0.25))
        // Curve up to center
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.2), control: CGPoint(x: rect.maxX - w * 0.25, y: rect.maxY - h * 0.5))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - h * 0.25), control: CGPoint(x: rect.minX + w * 0.25, y: rect.maxY - h * 0.5))
        path.closeSubpath()
        return path
    }
}

struct HighFidelityShieldView: View {
    let color: Color
    let suitSymbol: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(color.opacity(0.35), lineWidth: 1.5)
            
            VStack(spacing: 2) {
                ZStack {
                    ShieldShape()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.white, Color(red: 0.9, green: 0.9, blue: 0.95)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    GeometryReader { geo in
                        Path { path in
                            path.move(to: CGPoint(x: 2, y: geo.size.height * 0.4))
                            path.addLine(to: CGPoint(x: geo.size.width - 2, y: geo.size.height * 0.4))
                            path.move(to: CGPoint(x: geo.size.width * 0.5, y: 2))
                            path.addLine(to: CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.85))
                        }
                        .stroke(color.opacity(0.25), lineWidth: 1.5)
                    }
                    
                    ShieldShape()
                        .stroke(color, lineWidth: 2)
                    
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let points = [
                            CGPoint(x: w * 0.15, y: h * 0.1),
                            CGPoint(x: w * 0.5, y: h * 0.1),
                            CGPoint(x: w * 0.85, y: h * 0.1),
                            CGPoint(x: w * 0.08, y: h * 0.35),
                            CGPoint(x: w * 0.92, y: h * 0.35),
                            CGPoint(x: w * 0.18, y: h * 0.65),
                            CGPoint(x: w * 0.82, y: h * 0.65),
                            CGPoint(x: w * 0.5, y: h * 0.9)
                        ]
                        ForEach(0..<points.count, id: \.self) { i in
                            Circle().fill(color).frame(width: 2.5, height: 2.5).position(points[i])
                        }
                    }
                    
                    Text(suitSymbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                        .offset(y: -4)
                }
                .frame(width: 34, height: 32)
                
                Text("J")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
        }
        .frame(width: 48, height: 76)
    }
}

struct HighFidelityTiaraView: View {
    let color: Color
    let suitSymbol: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(color.opacity(0.35), lineWidth: 1.5)
            
            VStack(spacing: 4) {
                ZStack {
                    QueenTiaraShape()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.99, green: 0.88, blue: 0.45), Color(red: 0.95, green: 0.75, blue: 0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    QueenTiaraShape()
                        .stroke(color, lineWidth: 2)
                    
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        
                        Path { path in
                            path.move(to: CGPoint(x: w * 0.2, y: h * 0.95))
                            path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.45), control: CGPoint(x: w * 0.3, y: h * 0.6))
                            path.addQuadCurve(to: CGPoint(x: w * 0.8, y: h * 0.95), control: CGPoint(x: w * 0.7, y: h * 0.6))
                        }
                        .stroke(color.opacity(0.35), lineWidth: 1.2)
                        
                        let peaks = [
                            CGPoint(x: w * 0.15, y: h * 0.25),
                            CGPoint(x: w * 0.35, y: h * 0.6),
                            CGPoint(x: w * 0.5, y: h * 0.0),
                            CGPoint(x: w * 0.65, y: h * 0.6),
                            CGPoint(x: w * 0.85, y: h * 0.25)
                        ]
                        ForEach(0..<peaks.count, id: \.self) { i in
                            Circle().fill(color).frame(width: i == 2 ? 5.5 : 4, height: i == 2 ? 5.5 : 4).position(peaks[i])
                        }
                        
                        Circle().fill(color).frame(width: 4.5, height: 4.5).position(x: w * 0.5, y: h * 0.38)
                    }
                }
                .frame(width: 36, height: 28)
                
                Text(suitSymbol)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }
        }
        .frame(width: 48, height: 76)
    }
}

struct HighFidelityCrownView: View {
    let color: Color
    let suitSymbol: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(color.opacity(0.35), lineWidth: 1.5)
            
            VStack(spacing: 4) {
                ZStack {
                    CapBackingShape()
                        .fill(color.opacity(0.15))
                    
                    KingCrownShape()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.98, green: 0.85, blue: 0.3), Color(red: 0.9, green: 0.7, blue: 0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    KingCrownShape()
                        .stroke(color, lineWidth: 2)
                    
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        
                        Circle().fill(color).frame(width: 5, height: 5).position(x: w * 0.2, y: h * 0.25)
                        Circle().fill(color).frame(width: 5, height: 5).position(x: w * 0.8, y: h * 0.25)
                        Circle().fill(color).frame(width: 5, height: 5).position(x: w * 0.5, y: 0)
                        
                        let baseJewels = [
                            CGPoint(x: w * 0.2, y: h * 0.875),
                            CGPoint(x: w * 0.5, y: h * 0.875),
                            CGPoint(x: w * 0.8, y: h * 0.875)
                        ]
                        ForEach(0..<baseJewels.count, id: \.self) { i in
                            if i == 1 {
                                Rectangle().fill(color).frame(width: 4, height: 4).rotationEffect(.degrees(45)).position(baseJewels[i])
                            } else {
                                Circle().fill(color).frame(width: 3.5, height: 3.5).position(baseJewels[i])
                            }
                        }
                    }
                }
                .frame(width: 38, height: 28)
                
                Text(suitSymbol)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }
        }
        .frame(width: 48, height: 76)
    }
}

