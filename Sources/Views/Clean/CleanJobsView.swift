import SwiftUI

struct CleanJobsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: Layout.sectionSpacing) {
            List(model.jobs) { job in
                JobRow(job: job)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .frame(minHeight: Layout.listMinHeight)
            .background(.thickMaterial, in: .rect(cornerRadius: Layout.cardCornerRadius))
            .clipShape(.rect(cornerRadius: Layout.cardCornerRadius))
            .overlay {
                if model.jobs.isEmpty {
                    ContentUnavailableView("No Videos Yet", systemImage: "film",
                                           description: Text("Drop videos above or click Choose Videos…"))
                }
            }

            HStack {
                Button("Clear Finished", action: model.clearFinishedJobs)
                    .disabled(model.jobs.isEmpty)
                Button("Cancel All", role: .cancel, action: model.cancelAllJobs)
                    .disabled(!model.hasActiveJobs)
                Spacer()
                Button("Reveal in Finder", action: model.revealCleanedFiles)
                    .keyboardShortcut("r")
            }
            .buttonStyle(.bordered)
        }
    }
}
