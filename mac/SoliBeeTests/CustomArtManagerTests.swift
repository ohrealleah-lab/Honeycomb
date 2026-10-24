import Foundation
import AppKit

// The custom card back, face-card art and background managers: what a player can import,
// what's refused, what's saved and survives a relaunch, what deleting does to the files,
// and the "file went missing" clean-up. They keep their image files in Application Support,
// so every test points them at a throwaway folder (AppSupportLocation.testOverride) and puts
// each manager's list, and the saved settings, back exactly as it found them.
struct CustomArtManagerTests {
    static let defaultsKeys = [
        "custom_card_backs", "deleted_default_decks", "custom_face_arts", "custom_backgrounds",
        "solibee_themes", "solibee_keep_dingwall"
    ]

    static func run() {
        UISound.isHeadlessMode = true
        func isolated(_ test: () -> Void) {
            withCleanDefaults([], preserving: defaultsKeys) {
                let root = FileManager.default.temporaryDirectory.appendingPathComponent("HoneycombArt_\(UUID().uuidString)")
                try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                let backs = CustomCardBackManager.shared, arts = CustomFaceCardArtManager.shared, bgs = CustomBackgroundManager.shared
                let savedBacks = backs.customCardBacks, savedDeleted = backs.deletedDefaultDecks
                let savedArts = arts.faceArts, savedBgs = bgs.customBackgrounds
                AppSupportLocation.testOverride = root
                backs.customCardBacks = []; backs.deletedDefaultDecks = []
                arts.faceArts = []; bgs.customBackgrounds = []
                defer {
                    AppSupportLocation.testOverride = nil
                    backs.customCardBacks = savedBacks; backs.deletedDefaultDecks = savedDeleted
                    arts.faceArts = savedArts; bgs.customBackgrounds = savedBgs
                    try? FileManager.default.removeItem(at: root)
                }
                test()
            }
        }
        isolated(testCardBackImportRules)
        isolated(testCardBackGifAndUpdate)
        isolated(testCardBackDecksAndDeleting)
        isolated(testCardBackMissingFilesAndSavedList)
        isolated(testCardBackImageCaches)
        isolated(testFaceArtAddReplaceEnableRemove)
        isolated(testFaceArtRestoreAndImages)
        isolated(testBackgroundImportRules)
        isolated(testBackgroundUpdateRemoveAndMissingFiles)
        isolated(testBackgroundImagesAndLargeImports)
    }

    // MARK: - Helpers

    /// A solid-colour PNG, built without any screen.
    static func png(width: Int = 40, height: Int = 60, red: CGFloat = 0.8, green: CGFloat = 0.1, blue: CGFloat = 0.1) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let color = NSColor(deviceRed: red, green: green, blue: blue, alpha: 1)
        for x in 0..<width { for y in 0..<height { rep.setColor(color, atX: x, y: y) } }
        return rep.representation(using: .png, properties: [:])!
    }

    static func image(width: Int = 40, height: Int = 60) -> NSImage {
        let rep = NSBitmapImageRep(data: png(width: width, height: height))!
        let img = NSImage(size: NSSize(width: width, height: height))
        img.addRepresentation(rep)
        return img
    }

    static func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    static func savedBacks() -> [CustomCardBack] {
        (UserDefaults.standard.data(forKey: "custom_card_backs").flatMap { try? JSONDecoder().decode([CustomCardBack].self, from: $0) }) ?? []
    }

    // MARK: - Card backs

    static func testCardBackImportRules() {
        let m = CustomCardBackManager.shared
        expect(m.addCustomCardBack(name: "  Honey Comb  ", image: image(), scale: 1.25, offsetX: 3, offsetY: -4), "A card back imports")
        guard let added = m.customCardBack(named: "Honey Comb") else { expect(false, "The name is trimmed"); return }
        expect(added.scale == 1.25 && added.offsetX == 3 && added.offsetY == -4, "Scale and offsets are kept")
        let file = m.getFileURL(for: added.relativePath)
        expect(exists(file) && added.relativePath.hasSuffix(".png"), "The image is written as a PNG")
        expect(NSImage(contentsOf: file) != nil, "…and it's a real image")
        expect(file.deletingLastPathComponent().path.hasPrefix(AppSupportLocation.baseDirectory.path), "Files go to the folder tests chose, not the real one")
        expect(savedBacks().map { $0.name } == ["Honey Comb"], "It's saved with the other settings")

        expect(!m.addCustomCardBack(name: "Honey Comb", image: image(), scale: 1), "The same name twice is refused")
        expect(!m.addCustomCardBack(name: "", image: image(), scale: 1), "A blank name is refused")
        expect(!m.addCustomCardBack(name: "   \n", image: image(), scale: 1), "…even spaces")
        expect(!m.addCustomCardBack(name: "Vulpera", image: image(), scale: 1), "A built-in deck's name is refused")
        expect(m.customCardBacks.count == 1, "Refusals add nothing")

        // A huge source is shrunk on the way in (longer edge capped at 1200).
        expect(m.addCustomCardBack(name: "Huge", image: image(width: 2400, height: 600), scale: 1), "A very large image imports")
        // The cap is on the picture's size in points (a high-resolution screen saves twice the pixels).
        let huge = NSImage(contentsOf: m.getFileURL(for: m.customCardBack(named: "Huge")!.relativePath))
        expect((huge?.size.width ?? 99999) <= 1200.5, "…and is saved no more than 1200 points wide (got \(huge?.size.width ?? -1))")
        expect((huge?.size.width ?? 0) > (huge?.size.height ?? 1) * 3, "…keeping its shape")
        let zero = NSImage(size: .zero)
        expect(!m.addCustomCardBack(name: "Empty", image: zero, scale: 1), "An image with nothing in it is refused")
    }

    static func testCardBackGifAndUpdate() {
        let m = CustomCardBackManager.shared
        let gif = Data("GIF89a".utf8) + Data(repeating: 0, count: 20)
        expect(m.addCustomCardBackGIF(name: "Moving", data: gif, scale: 1.5), "A GIF imports as it is")
        let back = m.customCardBack(named: "Moving")!
        expect(back.relativePath.hasSuffix(".gif") && (try? Data(contentsOf: m.getFileURL(for: back.relativePath))) == gif, "Its bytes are kept untouched")
        expect(m.isGIF(for: back.relativePath) && m.isGIF(for: "X.GIF"), "GIFs are recognised by their ending, any case")
        expect(m.gifURL(for: back.relativePath) == m.getFileURL(for: back.relativePath), "A GIF has its file URL")
        expect(m.gifURL(for: "plain.png") == nil, "A PNG has none")
        expect(!m.addCustomCardBackGIF(name: "Moving", data: gif, scale: 1), "A duplicate name is refused for GIFs too")
        expect(!m.addCustomCardBackGIF(name: "Solibee", data: gif, scale: 1), "…and a built-in name")

        var edited = back
        edited.scale = 2.0; edited.offsetX = 9; edited.offsetY = -9
        m.updateCustomCardBack(edited)
        expect(m.customCardBack(named: "Moving")?.scale == 2.0 && m.customCardBack(named: "Moving")?.offsetX == 9, "Updating changes scale and offsets in place")
        expect(savedBacks().first?.scale == 2.0, "…and saves them")
        m.updateCustomCardBack(CustomCardBack(name: "Never added", relativePath: "x.png", scale: 5))
        expect(m.customCardBacks.count == 1, "Updating a deck that isn't there does nothing")
    }

    static func testCardBackDecksAndDeleting() {
        let m = CustomCardBackManager.shared
        _ = m.addCustomCardBack(name: "Mine", image: image(), scale: 1)
        expect(m.activeDecks == m.defaultThemes + ["Mine"], "The carousel is every default deck, then your own")
        expect(m.isDefaultTheme("Vulpera") && !m.isDefaultTheme("Mine"), "Built-in decks are told apart")

        // A saved custom entry that shares a built-in deck's name never shows twice.
        m.customCardBacks.append(CustomCardBack(name: "Moogle", relativePath: "dup.png", scale: 1))
        expect(m.activeDecks.filter { $0 == "Moogle" }.count == 1, "A custom deck named like a built-in one isn't listed twice")
        m.customCardBacks.removeAll { $0.name == "Moogle" }

        expect(m.deleteDeck(name: "Vulpera"), "A built-in deck can be hidden")
        expect(m.deletedDefaultDecks == ["Vulpera"] && !m.activeDecks.contains("Vulpera"), "…and leaves the carousel")
        expect(!m.deleteDeck(name: "Vulpera"), "Hiding it twice does nothing")
        expect((UserDefaults.standard.stringArray(forKey: "deleted_default_decks") ?? []) == ["Vulpera"], "The hidden list is saved")

        let mine = m.customCardBack(named: "Mine")!
        let file = m.getFileURL(for: mine.relativePath)
        expect(exists(file), "The file is there before deleting")
        expect(m.deleteDeck(name: "Mine"), "Your own deck can be deleted")
        expect(m.customCardBack(named: "Mine") == nil && !exists(file), "…its entry and its file are gone")
        expect(savedBacks().isEmpty, "…and the saved list is updated")
        expect(!m.deleteDeck(name: "No such deck"), "Deleting something unknown does nothing")

        m.resetDefaultCardBacks()
        expect(m.deletedDefaultDecks.isEmpty && m.activeDecks == m.defaultThemes, "Reset brings the built-in decks back")

        // The last visible deck can't be deleted.
        let last = m.defaultThemes[0]
        m.deletedDefaultDecks = Array(m.defaultThemes.dropFirst())
        expect(m.activeDecks == [last], "Only one deck left showing")
        expect(!m.deleteDeck(name: last), "The last deck can't be deleted")
        m.resetDefaultCardBacks()
    }

    static func testCardBackMissingFilesAndSavedList() {
        let m = CustomCardBackManager.shared
        _ = m.addCustomCardBack(name: "Keeper", image: image(), scale: 1)
        // A saved entry whose file is gone disappears quietly the next time the list loads.
        let ghost = CustomCardBack(name: "Ghost", relativePath: "\(UUID().uuidString).png", scale: 1)
        let list = m.customCardBacks + [ghost]
        UserDefaults.standard.set(try? JSONEncoder().encode(list), forKey: "custom_card_backs")
        m.loadCustomCardBacks()
        expect(m.customCardBacks.map { $0.name } == ["Keeper"], "A card back whose file was deleted is dropped")
        expect(savedBacks().map { $0.name } == ["Keeper"], "…and the saved list is cleaned up too")

        UserDefaults.standard.removeObject(forKey: "custom_card_backs")
        m.loadCustomCardBacks()
        expect(m.customCardBacks.isEmpty, "No saved list means no custom decks")
        UserDefaults.standard.set(Data("not json".utf8), forKey: "custom_card_backs")
        m.loadCustomCardBacks()
        expect(m.customCardBacks.isEmpty, "A damaged saved list loads as empty instead of crashing")

        // Old saves without offsets still load.
        let old = "[{\"id\":\"\(UUID().uuidString)\",\"name\":\"Old\",\"relativePath\":\"o.png\",\"scale\":1.5}]"
        let decoded = try? JSONDecoder().decode([CustomCardBack].self, from: Data(old.utf8))
        expect(decoded?.first?.offsetX == 0 && decoded?.first?.offsetY == 0 && decoded?.first?.scale == 1.5, "A save from before offsets existed gets zero offsets")
    }

    static func testCardBackImageCaches() {
        let m = CustomCardBackManager.shared
        _ = m.addCustomCardBack(name: "Pic", image: image(width: 300, height: 400), scale: 1)
        let path = m.customCardBack(named: "Pic")!.relativePath
        m.invalidateCache(for: path)
        let before = m.imageLoadTick
        _ = m.image(for: path)   // starts a background load
        pumpRunLoop(timeout: 5) { m.imageLoadTick > before }
        expect(m.imageLoadTick > before, "A finished load tells the screen to redraw")
        guard let img = m.image(for: path) else { expect(false, "The image is cached after loading"); return }
        expect(img.size.width <= 240 + 0.5 && img.size.height <= 346 + 0.5, "The cached copy is capped at the display size, got \(img.size)")
        guard let thumb = m.thumbnail(for: path) else { expect(false, "A thumbnail comes from the cached image"); return }
        expect(thumb.size.width <= 120 + 0.5 && thumb.size.height <= 170 + 0.5, "…at thumbnail size, got \(thumb.size)")

        m.invalidateCache(for: path)
        m.preloadImages(priorityPaths: [path])   // priority paths are loaded straight away
        expect(m.image(for: path) != nil, "A priority preload has the image ready immediately")
        expect(m.image(for: "no-such-file.png") == nil, "An unknown file gives nothing (and doesn't crash)")
    }

    // MARK: - Face-card art

    static func testFaceArtAddReplaceEnableRemove() {
        let m = CustomFaceCardArtManager.shared
        var heard = 0
        let token = NotificationCenter.default.addObserver(forName: .customFaceCardArtDidChange, object: nil, queue: nil) { _ in heard += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        expect(m.add(slot: .spadeKing, imageData: png(), isGIF: false, scale: 1.5, offsetX: 2, offsetY: -3), "Face art imports")
        guard let first = m.art(for: .spadeKing) else { expect(false, "The slot has its art"); return }
        let firstFile = AppSupportLocation.baseDirectory.appendingPathComponent("SoliBee/FaceArt/\(first.relativePath)")
        expect(first.isEnabled && first.scale == 1.5 && first.offsetX == 2 && first.offsetY == -3, "It's on, with its scale and offsets")
        expect(exists(firstFile) && first.relativePath.hasSuffix(".png"), "The file is saved as a PNG in the face-art folder")
        expect(m.art(for: .heartKing) == nil, "Other slots are untouched")
        expect((UserDefaults.standard.data(forKey: "custom_face_arts").flatMap { try? JSONDecoder().decode([CustomFaceArt].self, from: $0) })?.count == 1, "It's saved")
        expect(heard >= 1, "The cards are told to redraw")

        // A second upload for the same slot replaces the first and deletes its file.
        expect(m.add(slot: .spadeKing, imageData: png(red: 0.1, green: 0.8, blue: 0.1), isGIF: true, scale: 1, offsetX: 0, offsetY: 0), "Replacing a slot's art works")
        expect(m.faceArts.count == 1 && m.art(for: .spadeKing)?.id != first.id, "Still one entry for the slot, now the new one")
        expect(!exists(firstFile), "The old file is deleted")
        let gif = m.art(for: .spadeKing)!
        expect(m.isGIF(gif) && m.gifURL(for: gif) != nil, "A GIF upload is recognised")
        expect(m.gifURL(for: first) == nil && !m.isGIF(first), "A PNG isn't")

        m.setEnabled(false, for: .spadeKing)
        expect(m.art(for: .spadeKing) != nil && m.enabledArt(for: .spadeKing) == nil, "Turning art off keeps it but stops using it")
        m.setEnabled(true, for: .spadeKing)
        expect(m.enabledArt(for: .spadeKing) != nil, "…and back on")
        m.setEnabled(true, for: .heartQueen)   // a slot with no art: nothing happens
        expect(m.faceArts.count == 1, "Toggling an empty slot does nothing")

        var edited = m.art(for: .spadeKing)!
        edited.scale = 3; edited.offsetX = 7
        m.update(edited)
        expect(m.art(for: .spadeKing)?.scale == 3 && m.art(for: .spadeKing)?.offsetX == 7, "Updating edits the art in place")
        m.update(CustomFaceArt(slot: .clubAce, relativePath: "x.png"))
        expect(m.art(for: .clubAce) == nil, "Updating a slot with no art adds nothing")

        let file = AppSupportLocation.baseDirectory.appendingPathComponent("SoliBee/FaceArt/\(m.art(for: .spadeKing)!.relativePath)")
        m.remove(slot: .spadeKing, deleteFile: false)
        expect(m.art(for: .spadeKing) == nil && exists(file), "Removing can keep the file")
        _ = m.add(slot: .heartJack, imageData: png(), isGIF: false, scale: 1, offsetX: 0, offsetY: 0)
        let jackFile = AppSupportLocation.baseDirectory.appendingPathComponent("SoliBee/FaceArt/\(m.art(for: .heartJack)!.relativePath)")
        m.remove(slot: .heartJack)
        expect(m.art(for: .heartJack) == nil && !exists(jackFile), "Removing normally deletes the file too")
        m.remove(slot: .clubKing)   // nothing there: harmless
        expect(m.faceArts.isEmpty, "Removing an empty slot does nothing")
    }

    static func testFaceArtRestoreAndImages() {
        let m = CustomFaceCardArtManager.shared
        _ = m.add(slot: .spadeAce, imageData: png(width: 300, height: 300), isGIF: false, scale: 1, offsetX: 0, offsetY: 0)
        _ = m.add(slot: .heartAce, imageData: png(), isGIF: false, scale: 1, offsetX: 0, offsetY: 0)
        let ace = m.art(for: .spadeAce)!
        let other = m.art(for: .heartAce)!
        let backup = [ace, other]

        // Restoring puts a saved set back, skipping any whose file is gone.
        let ghost = CustomFaceArt(slot: .clubQueen, relativePath: "\(UUID().uuidString).png")
        m.restore(backup + [ghost])
        expect(Set(m.faceArts.map { $0.slot }) == [.spadeAce, .heartAce], "Restore skips art whose file is missing")
        m.restore([])
        expect(m.faceArts.isEmpty, "Restoring nothing clears the set")
        m.restore(backup)
        expect(m.faceArts.count == 2, "…and a real set comes back")

        // Images are fitted inside the card frame without stretching.
        guard let img = m.image(for: ace) else { expect(false, "A square upload loads"); return }
        expect(abs(img.size.width - img.size.height) < 1 && img.size.width <= 154.5, "A square stays square and fits 154 wide, got \(img.size)")
        expect(m.image(for: CustomFaceArt(slot: .clubKing, relativePath: "missing.png")) == nil, "A missing file gives no image")
        expect(m.pngData(from: image()) != nil, "An image converts to PNG data")
    }

    // MARK: - Backgrounds

    static func testBackgroundImportRules() {
        let m = CustomBackgroundManager.shared
        expect(m.addCustomBackground(name: " Meadow ", imageData: png(width: 80, height: 50, red: 0.9, green: 0.1, blue: 0.1), scale: 1.2, offsetX: 5, offsetY: 6), "A background imports")
        guard let bg = m.customBackgrounds.first, bg.name == "Meadow" else { expect(false, "The name is trimmed"); return }
        expect(bg.scale == 1.2 && bg.offsetX == 5 && bg.offsetY == 6, "Scale and offsets are kept")
        expect(exists(m.getFileURL(for: bg.relativePath)) && bg.relativePath.hasSuffix(".png"), "It's saved as a PNG")
        expect((bg.dominantColorRed ?? 0) > 0.6 && (bg.dominantColorGreen ?? 1) < 0.4 && (bg.dominantColorBlue ?? 1) < 0.4,
               "Its main colour (red) is worked out at import: \(String(describing: bg.dominantColorRed)),\(String(describing: bg.dominantColorGreen))")
        expect(bg.dominantColor != nil, "…and is available as a colour")
        expect((UserDefaults.standard.data(forKey: "custom_backgrounds").flatMap { try? JSONDecoder().decode([CustomBackground].self, from: $0) })?.count == 1, "It's saved")

        expect(!m.addCustomBackground(name: "Meadow", imageData: png(), scale: 1, offsetX: 0, offsetY: 0), "The same name twice is refused")
        expect(!m.addCustomBackground(name: "", imageData: png(), scale: 1, offsetX: 0, offsetY: 0), "A blank name is refused")
        expect(!m.addCustomBackground(name: "Junk", imageData: Data("not an image".utf8), scale: 1, offsetX: 0, offsetY: 0), "Something that isn't an image is refused")
        let tooBig = Data(count: CustomBackgroundManager.maxImportBytes + 1)
        expect(!m.addCustomBackground(name: "Giant", imageData: tooBig, scale: 1, offsetX: 0, offsetY: 0), "A file over 25 MB is refused")
        expect(m.customBackgrounds.count == 1, "Refusals add nothing")
    }

    static func testBackgroundUpdateRemoveAndMissingFiles() {
        let m = CustomBackgroundManager.shared
        _ = m.addCustomBackground(name: "One", imageData: png(), scale: 1, offsetX: 0, offsetY: 0)
        _ = m.addCustomBackground(name: "Two", imageData: png(red: 0.1, green: 0.1, blue: 0.9), scale: 1, offsetX: 0, offsetY: 0)
        var one = m.customBackgrounds.first { $0.name == "One" }!
        one.scale = 2.5; one.offsetY = 11
        m.updateCustomBackground(one)
        expect(m.customBackgrounds.first { $0.name == "One" }?.scale == 2.5, "Updating changes scale and offsets in place")
        m.updateCustomBackground(CustomBackground(name: "Ghost", relativePath: "g.png"))
        expect(m.customBackgrounds.count == 2, "Updating one that isn't there adds nothing")

        let file = m.getFileURL(for: one.relativePath)
        m.removeCustomBackground(one)
        expect(m.customBackgrounds.map { $0.name } == ["Two"] && !exists(file), "Removing deletes the entry and its file")
        expect((UserDefaults.standard.data(forKey: "custom_backgrounds").flatMap { try? JSONDecoder().decode([CustomBackground].self, from: $0) })?.map { $0.name } == ["Two"], "…and the saved list")

        // A file deleted behind the app's back drops its entry on the next load.
        let two = m.customBackgrounds[0]
        try? FileManager.default.removeItem(at: m.getFileURL(for: two.relativePath))
        m.loadCustomBackgrounds()
        expect(m.customBackgrounds.isEmpty, "A background whose file is gone is dropped")
        UserDefaults.standard.set(Data("junk".utf8), forKey: "custom_backgrounds")
        m.loadCustomBackgrounds()
        expect(m.customBackgrounds.isEmpty, "A damaged saved list loads as empty")

        // Old saves without scale/offsets/colour still load.
        let old = "[{\"id\":\"\(UUID().uuidString)\",\"name\":\"Old\",\"relativePath\":\"o.png\"}]"
        let decoded = try? JSONDecoder().decode([CustomBackground].self, from: Data(old.utf8))
        expect(decoded?.first?.scale == 1.0 && decoded?.first?.offsetX == 0 && decoded?.first?.dominantColor == nil, "A save from before these fields existed gets sensible defaults")
    }

    static func testBackgroundImagesAndLargeImports() {
        let m = CustomBackgroundManager.shared
        _ = m.addCustomBackground(name: "Wide", imageData: png(width: 3000, height: 60), scale: 1, offsetX: 0, offsetY: 0)
        let wide = m.customBackgrounds.first { $0.name == "Wide" }!
        let saved = NSImage(contentsOf: m.getFileURL(for: wide.relativePath))
        // The cap is on the picture's size in points (a high-resolution screen saves twice the pixels).
        expect((saved?.size.width ?? 99999) <= 2400.5, "A very wide import is saved no wider than 2400 points (got \(saved?.size.width ?? -1))")
        expect((saved?.size.width ?? 0) > (saved?.size.height ?? 1) * 10, "…keeping its shape")

        m.invalidateCache(for: wide.relativePath)
        expect(m.image(for: wide.relativePath) == nil, "The first request starts a load and returns nothing yet")
        pumpRunLoop(timeout: 5) { m.image(for: wide.relativePath) != nil }
        guard let img = m.image(for: wide.relativePath) else { expect(false, "The image arrives"); return }
        expect(img.size.width <= 2400.5, "The cached copy is capped, got \(img.size)")
        guard let thumb = m.thumbnail(for: wide.relativePath) else { expect(false, "A thumbnail comes from the cached image"); return }
        expect(max(thumb.size.width, thumb.size.height) <= 240.5, "…at thumbnail size, got \(thumb.size)")
        m.invalidateCache(for: wide.relativePath)
        m.preloadImages(priorityPaths: [wide.relativePath])
        expect(m.image(for: wide.relativePath) != nil, "A priority preload has it ready straight away")
        expect(m.image(for: "no-such-file.png") == nil, "An unknown file gives nothing")
    }
}
