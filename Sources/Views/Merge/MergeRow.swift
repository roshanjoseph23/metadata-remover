import SwiftUI

struct MergeRow: View {
    let item: MergeItem
    let position: Int
    let isFirst: Bool
    let isLast: Bool
    let isBusy: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            Text(position, format: .number)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 26, alignment: .trailing)
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text(item.url.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Group {
                Button("Move Up", systemImage: "chevron.up", action: moveUp)
                    .disabled(isFirst || isBusy)
                Button("Move Down", systemImage: "chevron.down", action: moveDown)
                    .disabled(isLast || isBusy)
                Button("Remove", systemImage: "xmark.circle.fill", action: remove)
                    .foregroundStyle(.secondary)
                    .disabled(isBusy)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(position). \(item.url.lastPathComponent)")
    }

    private func moveUp() { model.moveMergeItem(item.id, by: -1) }
    private func moveDown() { model.moveMergeItem(item.id, by: 1) }
    private func remove() { model.removeMergeItem(item.id) }
}
