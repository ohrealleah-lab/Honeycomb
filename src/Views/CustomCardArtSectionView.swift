import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: NSImage
    let gifData: Data?  // non-nil only when the source was a .gif file
}

struct CardBackPreviewView: View {
    let theme: String
    
    var body: some View {
        ZStack {
            // Background card shape
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(width: 60, height: 85)
            
            // Render the theme
            Group {
                if theme == "Moogle" {
                    if let path = Bundle.main.path(forResource: "moogle", ofType: "jpg") ?? Bundle.main.path(forResource: "moogle", ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: path) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 56, height: 81)
                            .scaleEffect(1.25)
                    } else {
                        Circle().fill(Color.blue.opacity(0.3)).frame(width: 6, height: 6)
                    }
                } else if theme == "Dingwall" {
                    if let path = Bundle.main.path(forResource: "dingwall", ofType: "jpg") ?? Bundle.main.path(forResource: "dingwall", ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: path) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .frame(width: 60, height: 85)
                    } else {
                        Circle().fill(Color.blue.opacity(0.3)).frame(width: 6, height: 6)
                    }
                } else if CardBackView.bundleBackgroundNames.contains(theme) {
                    if let path = Bundle.main.path(forResource: theme, ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: path) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 85)
                    } else {
                        Circle().fill(Color.blue.opacity(0.3)).frame(width: 6, height: 6)
                    }
                } else if let customBack = CustomCardBackManager.shared.customCardBacks.first(where: { $0.name == theme }) {
                    if let nsImage = CustomCardBackManager.shared.thumbnail(for: customBack.relativePath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 56, height: 81)
                            .scaleEffect(CGFloat(customBack.scale))
                            .offset(x: CGFloat(customBack.offsetX) * (60.0 / 128.0), y: CGFloat(customBack.offsetY) * (60.0 / 128.0))
                    } else {
                        Circle().fill(Color.blue.opacity(0.3)).frame(width: 6, height: 6)
                    }
                } else {
                    // Vulpera (Default)
                    if let path = Bundle.main.path(forResource: "priest", ofType: "png") ?? Bundle.main.path(forResource: "priest", ofType: "jpg"),
                       let nsImage = NSImage(contentsOfFile: path) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 56, height: 81)
                    } else {
                        Circle().fill(Color.blue.opacity(0.3)).frame(width: 6, height: 6)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Border outline
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black.opacity(0.85), lineWidth: 0.5)
                .frame(width: 60, height: 85)
        }
        .frame(width: 60, height: 85)
    }
}

struct CustomCardBackEditorView: View {
    let image: NSImage
    let onSave: (String, Double, Double, Double) -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var scale: Double = 1.0
    @State private var offsetX: Double = 0.0
    @State private var offsetY: Double = 0.0
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Custom Card Art")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top)
            
            // Card Preview Frame (128x181 points)
            ZStack {
                // Background card shape
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                    .frame(width: 128, height: 181)
                    .shadow(radius: 4)
                
                // Programmatic content clip shape
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 173)
                        .scaleEffect(CGFloat(scale))
                        .offset(x: CGFloat(offsetX), y: CGFloat(offsetY))
                }
                .frame(width: 128, height: 181)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Border
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.85), lineWidth: 0.75)
                    .frame(width: 128, height: 181)
            }
            .frame(width: 150, height: 200)
            
            // Name input
            VStack(alignment: .leading, spacing: 4) {
                Text("Card Back Name:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                TextField("e.g. My Dog", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            
            // Horizontal Offset Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Horizontal Position:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(String(format: "%.0f px", offsetX))
                        .font(.caption)
                        .foregroundColor(.white)
                        .monospaced()
                }
                Slider(value: $offsetX, in: -100.0...100.0, step: 1.0)
                    .frame(width: 200)
            }
            
            // Vertical Offset Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Vertical Position:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(String(format: "%.0f px", offsetY))
                        .font(.caption)
                        .foregroundColor(.white)
                        .monospaced()
                }
                Slider(value: $offsetY, in: -100.0...100.0, step: 1.0)
                    .frame(width: 200)
            }
            
            // Scale Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Scale Factor:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(String(format: "%.2fx", scale))
                        .font(.caption)
                        .foregroundColor(.white)
                        .monospaced()
                }
                Slider(value: $scale, in: 0.5...3.0, step: 0.05)
                    .frame(width: 200)
            }
            
            if showError {
                Text("Name cannot be empty or already exist!")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanedName.isEmpty || 
                        CustomCardBackManager.shared.defaultThemes.contains(cleanedName) ||
                        CustomCardBackManager.shared.customCardBacks.contains(where: { $0.name == cleanedName }) {
                        showError = true
                    } else {
                        onSave(cleanedName, scale, offsetX, offsetY)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom)
        }
        .frame(width: 320)
        .padding()
        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
        .cornerRadius(12)
    }
}

struct DeckItemView: View {
    let name: String
    let isSelected: Bool
    let activeCount: Int
    @Binding var cardBackTheme: String
    @Binding var feltColor: FeltColorTheme
    let deleteDeckByName: (String) -> Void
    let proxy: ScrollViewProxy

    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // The Card Preview Button
                Button(action: {
                    cardBackTheme = name
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(name, anchor: .center)
                    }
                }) {
                    CardBackPreviewView(theme: name)
                }
                .buttonStyle(.plain)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                        .frame(width: 66, height: 91)
                )

                // Delete Overlay Button (if active count > 1)
                if activeCount > 1 {
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .background(Circle().fill(Color.white))
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 5, y: -5)
                    .help("Delete deck")
                    .alert("Delete Card Back", isPresented: $showingDeleteAlert) {
                        Button("Cancel", role: .cancel) { }
                        Button("Delete", role: .destructive) { deleteDeckByName(name) }
                    } message: {
                        Text("Are you sure you want to delete \"\(name)\"?")
                    }
                }
            }
            .frame(width: 66, height: 91)
            
            Text(name)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 75)
        }
        .id(name)
    }
}

public struct CardDeckSelectorView: View {
    @Binding var cardBackTheme: String
    @Binding var feltColor: FeltColorTheme
    
    @State private var selectedImageItem: IdentifiableImage? = nil
    @State private var showingDeleteConfirmation = false
    @State private var deckToDelete: String? = nil
    
    public init(cardBackTheme: Binding<String>, feltColor: Binding<FeltColorTheme>) {
        self._cardBackTheme = cardBackTheme
        self._feltColor = feltColor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1: Scrollable Carousel of All Decks in Stable Order
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Card Deck Selection")
                        .font(.system(.body, design: .monospaced).bold())
                    Text("(.jpg, .png, or .gif accepted):")
                        .font(.system(.body, design: .monospaced))
                }
                .foregroundColor(.primary)
                Spacer()
                Button("Add Custom…") { selectImage() }
                    .font(.system(size: 12, design: .monospaced))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }

            ScrollViewReader { proxy in
                HStack(spacing: 4) {
                    let activeDecks = CustomCardBackManager.shared.activeDecks
                    
                    // Left Slide Button
                    Button(action: {
                        slideLeft(proxy: proxy, activeDecks: activeDecks)
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.primary.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    
                    // The stable horizontal carousel
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(activeDecks, id: \.self) { name in
                                DeckItemView(
                                    name: name,
                                    isSelected: (name == cardBackTheme),
                                    activeCount: activeDecks.count,
                                    cardBackTheme: $cardBackTheme,
                                    feltColor: $feltColor,
                                    deleteDeckByName: deleteDeckByName,
                                    proxy: proxy
                                )
                            }
                        }
                        .padding(.top, 5)
                        .padding(.horizontal, 4)
                    }
                    .frame(height: 115)
                    .onAppear {
                        DispatchQueue.main.async {
                            proxy.scrollTo(cardBackTheme, anchor: .center)
                        }
                    }
                    
                    // Right Slide Button
                    Button(action: {
                        slideRight(proxy: proxy, activeDecks: activeDecks)
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.primary.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
        }
        .sheet(item: $selectedImageItem) { item in
            CustomCardBackEditorView(image: item.image) { name, scale, offsetX, offsetY in
                let saved: Bool
                if let gifData = item.gifData {
                    saved = CustomCardBackManager.shared.addCustomCardBackGIF(name: name, data: gifData, scale: scale, offsetX: offsetX, offsetY: offsetY)
                } else {
                    saved = CustomCardBackManager.shared.addCustomCardBack(name: name, image: item.image, scale: scale, offsetX: offsetX, offsetY: offsetY)
                }
                if saved { cardBackTheme = name }
                selectedImageItem = nil
            } onCancel: {
                selectedImageItem = nil
            }
        }
        .alert("Delete Card Back", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                deckToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let name = deckToDelete {
                    deleteDeckByName(name)
                }
                deckToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this card back?")
        }
    }
    
    private func feltColorName(_ theme: FeltColorTheme) -> String {
        switch theme {
        case .feltGreen: return "Green"
        case .crimson: return "Crimson"
        case .royalBlue: return "Blue"
        case .charcoal: return "Charcoal"
        case .desert: return "Desert"
        case .custom: return "Custom"
        }
    }
    
    private func slideRight(proxy: ScrollViewProxy, activeDecks: [String]) {
        if let currentIndex = activeDecks.firstIndex(of: cardBackTheme) {
            let nextIndex = currentIndex + 1
            if nextIndex < activeDecks.count {
                let nextName = activeDecks[nextIndex]
                cardBackTheme = nextName
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(nextName, anchor: .center)
                }
            }
        } else {
            if let first = activeDecks.first {
                cardBackTheme = first
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(first, anchor: .center)
                }
            }
        }
    }
    
    private func slideLeft(proxy: ScrollViewProxy, activeDecks: [String]) {
        if let currentIndex = activeDecks.firstIndex(of: cardBackTheme) {
            let prevIndex = currentIndex - 1
            if prevIndex >= 0 {
                let prevName = activeDecks[prevIndex]
                cardBackTheme = prevName
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(prevName, anchor: .center)
                }
            } else if let first = activeDecks.first {
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(first, anchor: .center)
                }
            }
        } else if let first = activeDecks.first {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(first, anchor: .center)
            }
        }
    }
    
    private func deleteDeckByName(_ name: String) {
        let currentActive = CustomCardBackManager.shared.activeDecks
        guard currentActive.count > 1 else { return }
        
        if cardBackTheme == name {
            if let firstOther = currentActive.first(where: { $0 != name }) {
                cardBackTheme = firstOther
            }
        }
        
        _ = CustomCardBackManager.shared.deleteDeck(name: name)
    }
    
    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png, .gif]

        if panel.runModal() == .OK {
            if let url = panel.url {
                let ext = url.pathExtension.lowercased()
                guard ["jpg", "jpeg", "png", "gif"].contains(ext) else {
                    let alert = NSAlert()
                    alert.messageText = "Error"
                    alert.informativeText = "File must be .jpg, .png, or .gif!"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    return
                }

                if let image = NSImage(contentsOf: url) {
                    let gifData = ext == "gif" ? (try? Data(contentsOf: url)) : nil
                    selectedImageItem = IdentifiableImage(image: image, gifData: gifData)
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Error"
                    alert.informativeText = "Could not load the selected image file."
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
}
