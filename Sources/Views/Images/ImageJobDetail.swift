import SwiftUI

/// The status line under an image row's file name.
struct ImageJobDetail: View {
    let job: ImageJob

    var body: some View {
        switch job.status {
        case .ready:
            Text(job.edit.summary ?? "No crop").font(.callout).foregroundStyle(.secondary)
        case .queued:
            Text("Waiting…").font(.callout).foregroundStyle(.secondary)
        case .working:
            Text("Cleaning…").font(.callout).foregroundStyle(.secondary)
        case .done:
            Text("→ \(job.output?.lastPathComponent ?? "")").font(.callout).foregroundStyle(.secondary)
        case .cancelled:
            Text("Cancelled").font(.callout).foregroundStyle(.secondary)
        case .failed(let reason):
            Text(reason).font(.callout).foregroundStyle(.red).lineLimit(3)
        }
    }
}
