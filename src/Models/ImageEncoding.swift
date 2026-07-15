import AppKit

/// Shared by the custom card back / face art / background managers, which all need to
/// convert an imported NSImage to PNG data before writing it to disk.
enum ImageEncoding {
    static func pngData(from image: NSImage) -> Data? {
        for rep in image.representations {
            if let bitmapRep = rep as? NSBitmapImageRep,
               let data = bitmapRep.representation(using: .png, properties: [:]) {
                return data
            }
        }
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData) {
            return bitmap.representation(using: .png, properties: [:])
        }
        return nil
    }
}
