import SwiftUI

/// Aspect presets, rotate/flip/reset and the resulting pixel size.
struct CropToolbar: View {
    @Binding var preset: AspectPreset
    let pixelSize: String
    let onRotate: () -> Void
    let onFlip: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            Picker("Aspect", selection: $preset) {
                ForEach(AspectPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            Spacer()

            Text(pixelSize)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            Group {
                Button("Rotate 90°", systemImage: "rotate.right", action: onRotate)
                    .help("Rotate 90° clockwise")
                Button("Flip Horizontally", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right", action: onFlip)
                    .help("Flip horizontally")
                Button("Reset", systemImage: "arrow.counterclockwise", action: onReset)
                    .help("Reset crop, rotation and flip")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
        }
    }
}
