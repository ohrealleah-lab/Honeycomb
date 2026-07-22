import SwiftUI
import AppKit

struct CustomBackgroundEditorView: View {
    let image: NSImage
    // Non-nil when re-editing a background already in the library (opened via
    // double-click on its preview) — locks the name field and skips the
    // empty/uniqueness check, since renaming isn't supported (matching
    // CustomCardBackManager/CustomFaceCardArtManager, neither of which allow it either).
    let existingBackground: CustomBackground?
    // Reflects the app's existing shared Felt Vignette setting (Options already has a
    // dedicated checkbox for this) — read-only here, just so the preview matches what
    // the real board will actually look like.
    let showFeltVignette: Bool
    let onSave: (String, Double, Double, Double) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var scale: Double
    @State private var offsetX: Double
    @State private var offsetY: Double
    @State private var showError = false

    // Mock board preview — offsets are normalized against a reference board width so
    // the small preview and the real (much wider) board agree proportionally. Same idea
    // CardBackPreviewView already uses for its smaller card thumbnail.
    private static let previewSize = CGSize(width: 280, height: 175)
    private static let referenceBoardWidth: CGFloat = 1400

    init(image: NSImage, existingBackground: CustomBackground? = nil, showFeltVignette: Bool,
         onSave: @escaping (String, Double, Double, Double) -> Void,
         onCancel: @escaping () -> Void) {
        self.image = image
        self.existingBackground = existingBackground
        self.showFeltVignette = showFeltVignette
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: existingBackground?.name ?? "")
        _scale = State(initialValue: existingBackground?.scale ?? 1.0)
        _offsetX = State(initialValue: existingBackground?.offsetX ?? 0.0)
        _offsetY = State(initialValue: existingBackground?.offsetY ?? 0.0)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Custom Background")
                .font(.display(18))
                .foregroundColor(.primary)
                .padding(.top)

            // Mock Board Preview
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.15))
                    .frame(width: Self.previewSize.width, height: Self.previewSize.height)

                CustomBackgroundRenderView(
                    background: CustomBackground(name: "__preview__", relativePath: "", scale: scale,
                                                  offsetX: offsetX, offsetY: offsetY),
                    image: image,
                    offsetScale: Self.previewSize.width / Self.referenceBoardWidth
                )
                .frame(width: Self.previewSize.width, height: Self.previewSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if showFeltVignette {
                    FeltVignetteView(intensity: 0.34)
                        .frame(width: Self.previewSize.width, height: Self.previewSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.85), lineWidth: 0.75)
                    .frame(width: Self.previewSize.width, height: Self.previewSize.height)
            }

            // Name input
            VStack(alignment: .leading, spacing: 4) {
                Text("Background Name:")
                    .font(.display(12))
                    .foregroundColor(.secondary)
                TextField("e.g. My Desk", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .disabled(existingBackground != nil)
            }

            // Horizontal Offset Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Horizontal Position:")
                        .font(.display(12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f px", offsetX))
                        .font(.display(12))
                        .foregroundColor(.primary)
                }
                Slider(value: $offsetX, in: -100.0...100.0, step: 1.0)
                    .frame(width: 260)
            }

            // Vertical Offset Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Vertical Position:")
                        .font(.display(12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f px", offsetY))
                        .font(.display(12))
                        .foregroundColor(.primary)
                }
                Slider(value: $offsetY, in: -100.0...100.0, step: 1.0)
                    .frame(width: 260)
            }

            // Scale Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Scale Factor:")
                        .font(.display(12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2fx", scale))
                        .font(.display(12))
                        .foregroundColor(.primary)
                }
                Slider(value: $scale, in: 0.5...3.0, step: 0.05)
                    .frame(width: 260)
            }

            if showError {
                Text("Name cannot be empty or already exist!")
                    .font(.display(12))
                    .foregroundColor(.red)
            }

            HStack(spacing: 12) {
                themedEditorButton("Cancel", tint: .primary, shortcut: .cancelAction) {
                    onCancel()
                }

                themedEditorButton("Save", tint: .primary, shortcut: .defaultAction) {
                    let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let nameConflict = existingBackground == nil
                        && CustomBackgroundManager.shared.customBackgrounds.contains(where: { $0.name == cleanedName })
                    if cleanedName.isEmpty || nameConflict {
                        showError = true
                    } else {
                        onSave(cleanedName, scale, offsetX, offsetY)
                    }
                }
            }
            .padding(.bottom)
        }
        .frame(width: 340)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
    }
}
