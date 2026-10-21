import SwiftUI

/// Video tab: Clean-each vs Merge modes.
struct VideosPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: Layout.sectionSpacing) {
            Picker("Mode", selection: $model.mode) {
                Text("Clean each separately").tag(WorkMode.clean)
                Text("Merge into one video").tag(WorkMode.merge)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            DropZoneView(
                title: model.mode == .merge ? "Drop videos to merge" : "Drop videos here",
                subtitle: model.mode == .merge
                    ? "Arrange them in order below, then click Merge.\nThe result has no metadata and a random name."
                    : "All metadata is removed and each copy gets a random name.\nOriginals are never modified.",
                systemImage: model.mode == .merge ? "rectangle.stack.badge.plus" : "film.stack",
                buttonTitle: "Choose Videos…",
                panelMessage: model.mode == .merge ? "Choose videos to merge" : "Choose videos to clean",
                contentTypes: [.movie, .video],
                onAdd: model.add
            )
            OptionsView()

            switch model.mode {
            case .clean: CleanJobsView()
            case .merge: MergeListView()
            }
        }
    }
}
