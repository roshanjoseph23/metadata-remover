import SwiftUI

/// Output format, HDR, batch crop and output folder for image mode.
struct ImageOptionsView: View {
    @Environment(ImageModel.self) private var imageModel

    var body: some View {
        @Bindable var imageModel = imageModel
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            HStack(spacing: Layout.rowSpacing) {
                Picker("Format", selection: $imageModel.format) {
                    ForEach(ImageOutputFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .fixedSize()
                .help("Keep Original preserves bit depth (16-bit PNG/TIFF, 10-bit HEIC/AVIF) and colour space. WebP becomes PNG; RAW becomes JPEG.")

                Toggle("Keep HDR", isOn: $imageModel.keepHDR)
                    .help("Keeps HDR gain maps and PQ/HLG encodings so photos still display in HDR. Turn off to flatten to SDR.")

                Spacer()
                Menu("Crop All To", systemImage: "crop") {
                    ForEach(AspectPreset.batchPresets) { preset in
                        Button(preset.title) { imageModel.applyAspectToAll(preset) }
                    }
                    Divider()
                    Button("No Crop") { imageModel.applyAspectToAll(nil) }
                }
                .fixedSize()
                .disabled(imageModel.readyCount == 0)
                .help("Centre-crops every waiting image without a manual crop")
            }
            Text(formatNote)
                .font(.caption)
                .foregroundStyle(.secondary)
            OutputFolderRow(directory: $imageModel.outputDirectory)
        }
    }

    private var formatNote: LocalizedStringResource {
        switch (imageModel.format, imageModel.keepHDR) {
        case (.original, true): "Bit depth and colour space are preserved. HDR is kept."
        case (.original, false): "Bit depth and colour space are preserved. HDR is flattened to SDR."
        case (.jpeg, true): "JPEG is 8-bit by nature. HDR is kept as a gain map."
        case (.jpeg, false): "JPEG is 8-bit by nature. HDR is flattened to SDR."
        }
    }
}
