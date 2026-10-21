import SwiftUI

struct MergeListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let isBusy = model.mergeState.isWorking
        VStack(spacing: Layout.sectionSpacing - 2) {
            List {
                ForEach(Array(model.mergeItems.enumerated()), id: \.element.id) { index, item in
                    MergeRow(item: item, position: index + 1, isFirst: index == 0,
                             isLast: index == model.mergeItems.count - 1, isBusy: isBusy)
                        .moveDisabled(isBusy)
                }
                .onMove(perform: model.moveMergeItems)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .frame(minHeight: Layout.listMinHeight)
            .background(.thickMaterial, in: .rect(cornerRadius: Layout.cardCornerRadius))
            .clipShape(.rect(cornerRadius: Layout.cardCornerRadius))
            .overlay {
                if model.mergeItems.isEmpty {
                    ContentUnavailableView("No Videos to Merge", systemImage: "rectangle.stack",
                                           description: Text("Add two or more videos, then drag to reorder."))
                }
            }

            MergeStatusView(state: model.mergeState)

            HStack {
                Button("Clear List", action: model.clearMergeList)
                    .buttonStyle(.bordered)
                    .disabled(model.mergeItems.isEmpty || isBusy)
                Spacer()
                Button("Reveal in Finder", action: model.revealMergedFile)
                    .buttonStyle(.bordered)
                if isBusy {
                    Button("Cancel", role: .cancel, action: model.cancelMerge)
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.cancelAction)
                }
                Button(model.mergeItems.count >= 2 ? "Merge \(model.mergeItems.count) Videos" : "Merge",
                       action: model.startMerge)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.mergeItems.count < 2 || isBusy || model.setupError != nil)
            }
        }
    }
}
