import SwiftUI

struct JobStatusIcon: View {
    let status: JobStatus

    var body: some View {
        switch status {
        case .ready:
            Image(systemName: "circle.dashed").foregroundStyle(.secondary).accessibilityLabel("Ready")
        case .queued:
            Image(systemName: "clock").foregroundStyle(.secondary).accessibilityLabel("Waiting")
        case .working:
            ProgressView().controlSize(.small).accessibilityLabel("Working")
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("Done")
        case .cancelled:
            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary).accessibilityLabel("Cancelled")
        case .failed:
            Image(systemName: "xmark.octagon.fill").foregroundStyle(.red).accessibilityLabel("Failed")
        }
    }
}
