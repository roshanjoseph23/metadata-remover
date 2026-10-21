import SwiftUI

/// Sheet for cropping, rotating and flipping one image.
struct CropEditorView: View {
    let job: ImageJob
    @Environment(ImageModel.self) private var imageModel
    @Environment(\.dismiss) private var dismiss

    @State private var source: ImagePreviewLoader.Preview?
    @State private var displayed: ImagePreviewLoader.Preview?
    @State private var quarterTurns = 0
    @State private var flipHorizontal = false
    @State private var preset = AspectPreset.free
    @State private var rect = CropRectMath.full
    @State private var didLoad = false
    @State private var didFailToLoad = false

    var body: some View {
        VStack(spacing: Layout.sectionSpacing) {
            Text(job.input.lastPathComponent)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)

            CropCanvas(preview: displayed, didFailToLoad: didFailToLoad, rect: $rect, normalizedRatio: normalizedRatio)
                .frame(minWidth: Layout.cropCanvasMinWidth, minHeight: Layout.cropCanvasMinHeight)
                .background(.thickMaterial, in: .rect(cornerRadius: Layout.cardCornerRadius))

            CropToolbar(preset: $preset, pixelSize: pixelSizeText,
                        onRotate: rotate, onFlip: flip, onReset: reset)

            HStack {
                Button("Remove Crop", action: removeCrop)
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Apply", action: apply)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(displayed == nil)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .task { await load() }
        .onChange(of: preset) { _, _ in
            if didLoad { rect = CropRectMath.defaultRect(normalizedRatio: normalizedRatio) }
        }
    }

    private var normalizedRatio: Double? {
        guard let size = displayed?.uprightSize else { return nil }
        return CropRectMath.normalizedRatio(preset.ratio(width: size.width, height: size.height), imageSize: size)
    }

    private var pixelSizeText: String {
        guard let size = displayed?.uprightSize else { return "" }
        let width = Int((rect.width * size.width).rounded()), height = Int((rect.height * size.height).rounded())
        return "\(width) × \(height) px"
    }

    // MARK: Actions

    private func load() async {
        guard let loaded = await ImagePreviewLoader.load(job.input, maxPixelSize: 1600) else {
            didFailToLoad = true
            return
        }
        source = loaded
        quarterTurns = job.edit.normalizedQuarterTurns
        flipHorizontal = job.edit.flipHorizontal
        await refreshDisplayed()
        let size = displayed?.uprightSize ?? loaded.uprightSize
        switch job.edit.crop {
        case .aspect(let saved):
            preset = saved
            rect = CropRectMath.defaultRect(normalizedRatio: CropRectMath.normalizedRatio(
                saved.ratio(width: size.width, height: size.height), imageSize: size))
        case .normalized(let saved):
            rect = saved
        case .pixels(let pixels):
            rect = CGRect(x: pixels.minX / size.width, y: pixels.minY / size.height,
                          width: pixels.width / size.width, height: pixels.height / size.height).intersection(CropRectMath.full)
        case nil:
            rect = CropRectMath.full
        }
        didLoad = true
    }

    /// Re-renders the preview for the current rotation/flip. Rapid clicks can finish out of order,
    /// so a result is only shown if it still matches the current state.
    private func refreshDisplayed() async {
        guard let source else { return }
        let turns = quarterTurns, flip = flipHorizontal
        let result = await ImagePreviewLoader.transformed(source, quarterTurns: turns, flipHorizontal: flip)
        guard turns == quarterTurns, flip == flipHorizontal else { return }
        displayed = result
    }

    private func rotate() {
        quarterTurns = (quarterTurns + 1) % 4
        Task {
            await refreshDisplayed()
            rect = CropRectMath.defaultRect(normalizedRatio: normalizedRatio)   // rotating resets the crop
        }
    }

    private func flip() {
        flipHorizontal.toggle()
        rect = CGRect(x: 1 - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
        Task { await refreshDisplayed() }
    }

    private func reset() {
        quarterTurns = 0
        flipHorizontal = false
        preset = .free
        Task {
            await refreshDisplayed()
            rect = CropRectMath.full
        }
    }

    private func removeCrop() {
        preset = .free
        rect = CropRectMath.full
    }

    private func cancel() { dismiss() }

    private func apply() {
        var edit = ImageEdit(quarterTurns: quarterTurns, flipHorizontal: flipHorizontal)
        if CropRectMath.isApproximatelyEqual(rect, CropRectMath.full) {
            edit.crop = nil
        } else if preset != .free,
                  CropRectMath.isApproximatelyEqual(rect, CropRectMath.defaultRect(normalizedRatio: normalizedRatio)) {
            edit.crop = .aspect(preset)
        } else {
            edit.crop = .normalized(rect)
        }
        imageModel.applyEdit(edit, to: job.id)
        dismiss()
    }
}
