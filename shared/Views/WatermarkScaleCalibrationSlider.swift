import SwiftUI

// TEMPORARY — dev calibration controls for the bee watermark's per-game scale and
// position. Delete this file and its call sites once final per-game values are known
// (see AppCoordinator's "Bee watermark per-game scale"/"per-game position" sections
// for the values to hardcode).
struct WatermarkScaleCalibrationSlider: View {
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bee Watermark Scale (temporary — dev calibration)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: $coordinator.currentGameWatermarkScale, in: 0.1...5.0)
            Text(String(format: "%.2f", coordinator.currentGameWatermarkScale))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Bee Watermark Horizontal Position (temporary — dev calibration)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: $coordinator.currentGameWatermarkOffsetX, in: -500...500)
            Text(String(format: "%.0f", coordinator.currentGameWatermarkOffsetX))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Bee Watermark Vertical Position (temporary — dev calibration)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: $coordinator.currentGameWatermarkOffsetY, in: -500...500)
            Text(String(format: "%.0f", coordinator.currentGameWatermarkOffsetY))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
