import SwiftUI

public struct CardView: View {
    public let card: Card
    public var isAnimated: Bool = false
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator?
    @Environment(GameViewModel.self) private var viewModel: GameViewModel?

    private var cardBackTheme: String {
        if let coordinator = coordinator {
            switch coordinator.gameMode {
            case .klondike:
                return coordinator.klondikeViewModel.cardBackTheme
            case .beecell:
                return coordinator.beecellViewModel.cardBackTheme
            case .spider:
                return coordinator.spiderViewModel.options.cardBackTheme
            case .videoPoker:
                return coordinator.videoPokerViewModel.options.cardBackTheme
            case .blackjack:
                return coordinator.blackjackViewModel.options.cardBackTheme
            }
        }
        return viewModel?.cardBackTheme ?? "Vulpera"
    }

    private var isDarkMode: Bool {
        if let coordinator = coordinator {
            switch coordinator.gameMode {
            case .klondike:
                return coordinator.klondikeViewModel.options.isDarkMode
            case .beecell:
                return coordinator.beecellViewModel.options.isDarkMode
            case .spider:
                return coordinator.spiderViewModel.options.isDarkMode
            case .videoPoker:
                return coordinator.videoPokerViewModel.options.isDarkMode
            case .blackjack:
                return coordinator.blackjackViewModel.options.isDarkMode
            }
        }
        return viewModel?.options.isDarkMode ?? false
    }

    private var outlineColor: Color {
        if isDarkMode {
            return Color(red: 0.3, green: 0.3, blue: 0.3)
        }
        if !card.faceUp && cardBackTheme == "Dingwall" {
            // Charcoal/grey to match the Dingwall image background and silver hardware
            return Color(red: 0.35, green: 0.35, blue: 0.36)
        }
        return Color.black.opacity(0.85)
    }

    public var body: some View {
        ZStack {
            if card.faceUp {
                CardFrontView(card: card, isDarkMode: isDarkMode)
            } else {
                CardBackView(isAnimated: isAnimated)
            }
        }
        .frame(width: 128, height: 181)
        .background(isDarkMode ? Color(red: 0.118, green: 0.118, blue: 0.118) : Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(outlineColor, lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1.5)
    }
}

// MARK: - Card Front Rendering

struct CardFrontView: View {
    let card: Card
    var isDarkMode: Bool = false

    var color: Color {
        if isDarkMode {
            return card.isRed
                ? Color(red: 1.0, green: 0.267, blue: 0.267)
                : Color(red: 0.753, green: 0.753, blue: 0.753)
        }
        return card.isRed ? Color(red: 0.8, green: 0.1, blue: 0.1) : Color(red: 0.1, green: 0.1, blue: 0.1)
    }
    
    var body: some View {
        ZStack {
            // Top Left Index (Horizontal, decreased size)
            HStack(alignment: .center, spacing: 1) {
                Text(card.rankString)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                Text(card.suit.symbol)
                    .font(.system(size: 14))
            }
            .foregroundColor(color)
            .padding(.leading, 8)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Center Suit Icon(s) (Larger, takes up most of card)
            CardCenterSuitView(suit: card.suit, rank: card.rank, color: color, isDarkMode: isDarkMode)
                .frame(width: 86, height: 138)
            
            // Bottom Right Index (Horizontal, inverted, decreased size)
            HStack(alignment: .center, spacing: 1) {
                Text(card.rankString)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                Text(card.suit.symbol)
                    .font(.system(size: 14))
            }
            .foregroundColor(color)
            .rotationEffect(.degrees(180))
            .padding(.trailing, 8)
            .padding(.bottom, 8)
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

struct FaceCardImageView: View {
    let filename: String
    let absolutePath: String
    let fallbackView: AnyView
    var fillFrame: Bool = false

    var body: some View {
        let nsImage: NSImage? = {
            if let image = NSImage(contentsOfFile: absolutePath) {
                return image
            }
            if let path = Bundle.main.path(forResource: filename, ofType: "png"),
               let image = NSImage(contentsOfFile: path) {
                return image
            }
            return nil
        }()

        if let image = nsImage {
            if fillFrame {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 77, height: 122)
            } else {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 62)
                    .frame(width: 77, height: 122)
                    .clipped()
            }
        } else {
            fallbackView
        }
    }
}

struct CardCenterSuitView: View {
    let suit: Card.Suit
    let rank: Int
    let color: Color
    var isDarkMode: Bool = false

    var body: some View {
        Group {
            if rank == 1 {
                // Ace — use custom art if available and enabled
                if let slot = FaceCardSlot.slot(rank: 1, isRed: suit.isRed),
                   let art = CustomFaceCardArtManager.shared.enabledArt(for: slot) {
                    CustomFaceArtImageView(art: art)
                } else {
                    Text(suit.symbol)
                        .font(.system(size: 61))
                        .foregroundColor(color)
                }
            } else if rank == 11 {
                // Jack — custom art overrides default image
                if let slot = FaceCardSlot.slot(rank: 11, isRed: suit.isRed),
                   let art = CustomFaceCardArtManager.shared.enabledArt(for: slot) {
                    CustomFaceArtImageView(art: art)
                } else if isDarkMode {
                    let name = suit.isRed ? "dark_j_red" : "dark_j_grey"
                    let path = "/Users/leah/SoliBee/\(name).png"
                    FaceCardImageView(filename: name, absolutePath: path,
                        fallbackView: AnyView(HighFidelityShieldView(color: color, suitSymbol: suit.symbol)), fillFrame: true)
                } else {
                    let path = suit.isRed ? "/Users/leah/SoliBee/red j.png" : "/Users/leah/SoliBee/J.png"
                    let name = suit.isRed ? "red j" : "J"
                    FaceCardImageView(
                        filename: name,
                        absolutePath: path,
                        fallbackView: AnyView(HighFidelityShieldView(color: color, suitSymbol: suit.symbol))
                    )
                }
            } else if rank == 12 {
                // Queen
                if let slot = FaceCardSlot.slot(rank: 12, isRed: suit.isRed),
                   let art = CustomFaceCardArtManager.shared.enabledArt(for: slot) {
                    CustomFaceArtImageView(art: art)
                } else if isDarkMode {
                    let name = suit.isRed ? "dark_q_red" : "dark_q_grey"
                    let path = "/Users/leah/SoliBee/\(name).png"
                    FaceCardImageView(filename: name, absolutePath: path,
                        fallbackView: AnyView(HighFidelityTiaraView(color: color, suitSymbol: suit.symbol)), fillFrame: true)
                } else {
                    let path = suit.isRed ? "/Users/leah/SoliBee/red q.png" : "/Users/leah/SoliBee/Q.png"
                    let name = suit.isRed ? "red q" : "Q"
                    FaceCardImageView(
                        filename: name,
                        absolutePath: path,
                        fallbackView: AnyView(HighFidelityTiaraView(color: color, suitSymbol: suit.symbol))
                    )
                }
            } else if rank == 13 {
                // King
                if let slot = FaceCardSlot.slot(rank: 13, isRed: suit.isRed),
                   let art = CustomFaceCardArtManager.shared.enabledArt(for: slot) {
                    CustomFaceArtImageView(art: art)
                } else if isDarkMode {
                    let name = suit.isRed ? "dark_k_red" : "dark_k_grey"
                    let path = "/Users/leah/SoliBee/\(name).png"
                    FaceCardImageView(filename: name, absolutePath: path,
                        fallbackView: AnyView(HighFidelityCrownView(color: color, suitSymbol: suit.symbol)), fillFrame: true)
                } else {
                    let path = suit.isRed ? "/Users/leah/SoliBee/red k.png" : "/Users/leah/SoliBee/K.png"
                    let name = suit.isRed ? "red k" : "K"
                    FaceCardImageView(
                        filename: name,
                        absolutePath: path,
                        fallbackView: AnyView(HighFidelityCrownView(color: color, suitSymbol: suit.symbol))
                    )
                }
            } else {
                // Numbered cards 2 to 10
                ZStack {
                    ForEach(Array(positionsFor(rank: rank).enumerated()), id: \.offset) { _, pos in
                        Text(suit.symbol)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(color)
                            .rotationEffect(.degrees(pos.isUpsideDown ? 180 : 0))
                            .position(x: 43 + pos.x, y: 69 + pos.y)
                    }
                }
                .frame(width: 86, height: 138)
            }
        }
    }
    
    private func positionsFor(rank: Int) -> [SuitPosition] {
        switch rank {
        case 2:
            return [
                SuitPosition(x: 0, y: -42, isUpsideDown: false),
                SuitPosition(x: 0, y: 42, isUpsideDown: true)
            ]
        case 3:
            return [
                SuitPosition(x: 0, y: -42, isUpsideDown: false),
                SuitPosition(x: 0, y: 0, isUpsideDown: false),
                SuitPosition(x: 0, y: 42, isUpsideDown: true)
            ]
        case 4:
            return [
                SuitPosition(x: -26, y: -42, isUpsideDown: false),
                SuitPosition(x: 26, y: -42, isUpsideDown: false),
                SuitPosition(x: -26, y: 42, isUpsideDown: true),
                SuitPosition(x: 26, y: 42, isUpsideDown: true)
            ]
        case 5:
            return [
                SuitPosition(x: -26, y: -42, isUpsideDown: false),
                SuitPosition(x: 26, y: -42, isUpsideDown: false),
                SuitPosition(x: 0, y: 0, isUpsideDown: false),
                SuitPosition(x: -26, y: 42, isUpsideDown: true),
                SuitPosition(x: 26, y: 42, isUpsideDown: true)
            ]
        case 6:
            return [
                SuitPosition(x: -26, y: -42, isUpsideDown: false),
                SuitPosition(x: 26, y: -42, isUpsideDown: false),
                SuitPosition(x: -26, y: 0, isUpsideDown: false),
                SuitPosition(x: 26, y: 0, isUpsideDown: false),
                SuitPosition(x: -26, y: 42, isUpsideDown: true),
                SuitPosition(x: 26, y: 42, isUpsideDown: true)
            ]
        case 7:
            return [
                SuitPosition(x: -26, y: -42, isUpsideDown: false),
                SuitPosition(x: 26, y: -42, isUpsideDown: false),
                SuitPosition(x: -26, y: 0, isUpsideDown: false),
                SuitPosition(x: 26, y: 0, isUpsideDown: false),
                SuitPosition(x: -26, y: 42, isUpsideDown: true),
                SuitPosition(x: 26, y: 42, isUpsideDown: true),
                SuitPosition(x: 0, y: -21, isUpsideDown: false)
            ]
        case 8:
            return [
                SuitPosition(x: -26, y: -42, isUpsideDown: false),
                SuitPosition(x: 26, y: -42, isUpsideDown: false),
                SuitPosition(x: -26, y: 0, isUpsideDown: false),
                SuitPosition(x: 26, y: 0, isUpsideDown: false),
                SuitPosition(x: -26, y: 42, isUpsideDown: true),
                SuitPosition(x: 26, y: 42, isUpsideDown: true),
                SuitPosition(x: 0, y: -21, isUpsideDown: false),
                SuitPosition(x: 0, y: 21, isUpsideDown: true)
            ]
        case 9:
            return [
                SuitPosition(x: -26, y: -42, isUpsideDown: false),
                SuitPosition(x: 26, y: -42, isUpsideDown: false),
                SuitPosition(x: -26, y: -14, isUpsideDown: false),
                SuitPosition(x: 26, y: -14, isUpsideDown: false),
                SuitPosition(x: -26, y: 14, isUpsideDown: true),
                SuitPosition(x: 26, y: 14, isUpsideDown: true),
                SuitPosition(x: -26, y: 42, isUpsideDown: true),
                SuitPosition(x: 26, y: 42, isUpsideDown: true),
                SuitPosition(x: 0, y: 0, isUpsideDown: false)
            ]
        case 10:
            return [
                SuitPosition(x: -26, y: -42, isUpsideDown: false),
                SuitPosition(x: 26, y: -42, isUpsideDown: false),
                SuitPosition(x: -26, y: -14, isUpsideDown: false),
                SuitPosition(x: 26, y: -14, isUpsideDown: false),
                SuitPosition(x: -26, y: 14, isUpsideDown: true),
                SuitPosition(x: 26, y: 14, isUpsideDown: true),
                SuitPosition(x: -26, y: 42, isUpsideDown: true),
                SuitPosition(x: 26, y: 42, isUpsideDown: true),
                SuitPosition(x: 0, y: -27, isUpsideDown: false),
                SuitPosition(x: 0, y: 27, isUpsideDown: true)
            ]
        default:
            return []
        }
    }
}

// MARK: - Card Back Rendering (Custom Bee Theme)

// MARK: - Card Back Rendering (Custom Bee Theme)

struct CardBackView: View {
    var isAnimated: Bool = false

    static let bundleBackgroundNames: Set<String> = ["Forest", "On The Water", "Pareidolic", "Pareidolic 2", "Red Sky", "Sunset"]
    @Environment(AppCoordinator.self) private var coordinator: AppCoordinator?
    @Environment(GameViewModel.self) private var viewModel: GameViewModel?
    
    private var cardBackTheme: String {
        if let coordinator = coordinator {
            switch coordinator.gameMode {
            case .klondike:
                return coordinator.klondikeViewModel.cardBackTheme
            case .beecell:
                return coordinator.beecellViewModel.cardBackTheme
            case .spider:
                return coordinator.spiderViewModel.options.cardBackTheme
            case .videoPoker:
                return coordinator.videoPokerViewModel.options.cardBackTheme
            case .blackjack:
                return coordinator.blackjackViewModel.options.cardBackTheme
            }
        }
        return viewModel?.cardBackTheme ?? "Vulpera"
    }

    var body: some View {
        let theme = cardBackTheme
        
        ZStack {
            if theme == "Moogle" {
                // Moogle image filling the card back (zoomed by 25%)
                if let path = Bundle.main.path(forResource: "moogle", ofType: "jpg") ?? Bundle.main.path(forResource: "moogle", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 173)
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
                        .frame(width: 128, height: 181)
                } else {
                    Circle().fill(Color(red: 0.1, green: 0.3, blue: 0.6).opacity(0.3)).frame(width: 10, height: 10)
                }
            } else if Self.bundleBackgroundNames.contains(theme) {
                if let path = Bundle.main.path(forResource: theme, ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 128, height: 181)
                } else {
                    Circle().fill(Color.gray.opacity(0.3)).frame(width: 10, height: 10)
                }
            } else if let customBack = CustomCardBackManager.shared.customCardBacks.first(where: { $0.name == theme }) {
                let manager = CustomCardBackManager.shared
                if isAnimated && manager.isGIF(for: customBack.relativePath),
                   let gifURL = manager.gifURL(for: customBack.relativePath) {
                    ZStack {
                        AnimatedGIFView(url: gifURL)
                            .frame(width: 120, height: 173)
                            .scaleEffect(CGFloat(customBack.scale))
                            .offset(x: CGFloat(customBack.offsetX), y: CGFloat(customBack.offsetY))
                    }
                    .frame(width: 128, height: 181)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let nsImage = manager.image(for: customBack.relativePath) {
                    ZStack {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 173)
                            .scaleEffect(CGFloat(customBack.scale))
                            .offset(x: CGFloat(customBack.offsetX), y: CGFloat(customBack.offsetY))
                    }
                    .frame(width: 128, height: 181)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
                        .frame(width: 120, height: 173)
                } else {
                    Circle().fill(Color(red: 0.1, green: 0.3, blue: 0.6).opacity(0.3)).frame(width: 10, height: 10)
                }
            }
        }
        .frame(width: 128, height: 181)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}



// MARK: - Custom face art image view

struct CustomFaceArtImageView: View {
    let art: CustomFaceArt

    var body: some View {
        if let img = CustomFaceCardArtManager.shared.image(for: art) {
            ZStack {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 77, height: 122)
                    .scaleEffect(CGFloat(art.scale))
                    .offset(x: CGFloat(art.offsetX), y: CGFloat(art.offsetY))
            }
            .frame(width: 86, height: 138)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

// MARK: - Animated GIF support

import AppKit

struct AnimatedGIFView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.animates = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        if let image = NSImage(contentsOf: url) {
            imageView.image = image
        }

        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let imageView = nsView.subviews.first as? NSImageView else { return }
        if imageView.image == nil, let image = NSImage(contentsOf: url) {
            imageView.image = image
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
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.35), lineWidth: 2)
            
            VStack(spacing: 4) {
                ZStack {
                    ShieldShape()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.white, Color(red: 0.9, green: 0.9, blue: 0.95)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    GeometryReader { geo in
                        Path { path in
                            path.move(to: CGPoint(x: 3, y: geo.size.height * 0.4))
                            path.addLine(to: CGPoint(x: geo.size.width - 3, y: geo.size.height * 0.4))
                            path.move(to: CGPoint(x: geo.size.width * 0.5, y: 3))
                            path.addLine(to: CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.85))
                        }
                        .stroke(color.opacity(0.25), lineWidth: 2)
                    }
                    
                    ShieldShape()
                        .stroke(color, lineWidth: 3)
                    
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
                            Circle().fill(color).frame(width: 4, height: 4).position(points[i])
                        }
                    }
                    
                    Text(suitSymbol)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(color)
                        .offset(y: -6)
                }
                .frame(width: 54, height: 51)
                
                Text("J")
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
        }
        .frame(width: 77, height: 122)
    }
}

struct HighFidelityTiaraView: View {
    let color: Color
    let suitSymbol: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.35), lineWidth: 2)
            
            VStack(spacing: 6) {
                ZStack {
                    QueenTiaraShape()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.99, green: 0.88, blue: 0.45), Color(red: 0.95, green: 0.75, blue: 0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    QueenTiaraShape()
                        .stroke(color, lineWidth: 3)
                    
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        
                        Path { path in
                            path.move(to: CGPoint(x: w * 0.2, y: h * 0.95))
                            path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.45), control: CGPoint(x: w * 0.3, y: h * 0.6))
                            path.addQuadCurve(to: CGPoint(x: w * 0.8, y: h * 0.95), control: CGPoint(x: w * 0.7, y: h * 0.6))
                        }
                        .stroke(color.opacity(0.35), lineWidth: 2)
                        
                        let peaks = [
                            CGPoint(x: w * 0.15, y: h * 0.25),
                            CGPoint(x: w * 0.35, y: h * 0.6),
                            CGPoint(x: w * 0.5, y: h * 0.0),
                            CGPoint(x: w * 0.65, y: h * 0.6),
                            CGPoint(x: w * 0.85, y: h * 0.25)
                        ]
                        ForEach(0..<peaks.count, id: \.self) { i in
                            Circle().fill(color).frame(width: i == 2 ? 9 : 6, height: i == 2 ? 9 : 6).position(peaks[i])
                        }
                        
                        Circle().fill(color).frame(width: 7, height: 7).position(x: w * 0.5, y: h * 0.38)
                    }
                }
                .frame(width: 58, height: 45)
                
                Text(suitSymbol)
                    .font(.system(size: 29))
                    .foregroundColor(color)
            }
        }
        .frame(width: 77, height: 122)
    }
}

struct HighFidelityCrownView: View {
    let color: Color
    let suitSymbol: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.35), lineWidth: 3)
            
            VStack(spacing: 6) {
                ZStack {
                    CapBackingShape()
                        .fill(color.opacity(0.15))
                    
                    KingCrownShape()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.98, green: 0.85, blue: 0.3), Color(red: 0.9, green: 0.7, blue: 0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    KingCrownShape()
                        .stroke(color, lineWidth: 3)
                    
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        
                        Circle().fill(color).frame(width: 8, height: 8).position(x: w * 0.2, y: h * 0.25)
                        Circle().fill(color).frame(width: 8, height: 8).position(x: w * 0.8, y: h * 0.25)
                        Circle().fill(color).frame(width: 8, height: 8).position(x: w * 0.5, y: 0)
                        
                        let baseJewels = [
                            CGPoint(x: w * 0.2, y: h * 0.875),
                            CGPoint(x: w * 0.5, y: h * 0.875),
                            CGPoint(x: w * 0.8, y: h * 0.875)
                        ]
                        ForEach(0..<baseJewels.count, id: \.self) { i in
                            if i == 1 {
                                Rectangle().fill(color).frame(width: 6, height: 6).rotationEffect(.degrees(45)).position(baseJewels[i])
                            } else {
                                Circle().fill(color).frame(width: 6, height: 6).position(baseJewels[i])
                            }
                        }
                    }
                }
                .frame(width: 61, height: 45)
                
                Text(suitSymbol)
                    .font(.system(size: 29))
                    .foregroundColor(color)
            }
        }
        .frame(width: 77, height: 122)
    }
}
