import SwiftUI

struct MergeStatusView: View {
    let state: MergeState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch state {
            case .idle:
                EmptyView()
            case .working(let progress, let summary):
                ProgressView(value: progress) {
                    Text("Merging… \(progress.formatted(.percent.precision(.fractionLength(0))))")
                }
                Text(summary).font(.callout).foregroundStyle(.secondary)
            case .done(let output, let summary):
                Label("Merged → \(output.lastPathComponent)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(summary).font(.callout).foregroundStyle(.secondary)
            case .cancelled:
                Label("Merge cancelled", systemImage: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            case .failed(let reason):
                Label(reason, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                    .lineLimit(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(state == .idle ? 0 : Layout.cardPadding)
        .background(.regularMaterial.opacity(state == .idle ? 0 : 1), in: .rect(cornerRadius: Layout.cardCornerRadius))
    }
}
