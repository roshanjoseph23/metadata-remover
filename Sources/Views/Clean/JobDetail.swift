import SwiftUI

struct JobDetail: View {
    let job: Job

    var body: some View {
        switch job.status {
        case .ready:
            Text("Ready").font(.callout).foregroundStyle(.secondary)
        case .queued:
            Text("Waiting…").font(.callout).foregroundStyle(.secondary)
        case .working:
            ProgressView(value: job.progress)
                .progressViewStyle(.linear)
                .accessibilityLabel("Cleaning progress")
        case .done:
            Text("→ \(job.output?.lastPathComponent ?? "")").font(.callout).foregroundStyle(.secondary)
        case .cancelled:
            Text("Cancelled").font(.callout).foregroundStyle(.secondary)
        case .failed(let reason):
            Text(reason).font(.callout).foregroundStyle(.red).lineLimit(3)
        }
    }
}
