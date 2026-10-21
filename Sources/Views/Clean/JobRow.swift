import SwiftUI

struct JobRow: View {
    let job: Job
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: Layout.rowSpacing + 2) {
            JobStatusIcon(status: job.status)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.input.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                JobDetail(job: job)
            }
            Spacer()
            if job.status.isActive {
                Button("Cancel", systemImage: "xmark.circle", action: cancel)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Cancel")
            } else if job.status == .done, job.output != nil {
                Button("Reveal in Finder", systemImage: "magnifyingglass", action: reveal)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Reveal in Finder")
            }
        }
        .padding(.vertical, 2)
    }

    private func cancel() { model.cancelJob(job.id) }

    private func reveal() {
        if let output = job.output { NSWorkspace.shared.activateFileViewerSelecting([output]) }
    }
}
