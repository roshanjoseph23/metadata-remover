import SwiftUI

/// Per-row buttons: Cancel while active; otherwise Crop and Rotate, Reveal (when done) and Remove.
struct ImageJobActions: View {
    let job: ImageJob
    @Environment(ImageModel.self) private var imageModel

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            if job.status.isActive {
                Button("Cancel", systemImage: "xmark.circle", action: cancel)
                    .help("Cancel")
            } else {
                Button("Crop and Rotate", systemImage: "crop.rotate", action: edit)
                    .help("Crop and rotate…")
                if job.status == .done, job.output != nil {
                    Button("Reveal in Finder", systemImage: "magnifyingglass", action: reveal)
                        .help("Reveal in Finder")
                }
                Button("Remove", systemImage: "trash", action: remove)
                    .help("Remove from list")
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private func cancel() { imageModel.cancel(job.id) }
    private func edit() { imageModel.beginEditing(job.id) }
    private func remove() { imageModel.remove(job.id) }

    private func reveal() {
        if let output = job.output { NSWorkspace.shared.activateFileViewerSelecting([output]) }
    }
}
