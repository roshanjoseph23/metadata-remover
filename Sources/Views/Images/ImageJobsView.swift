import SwiftUI

/// The batch list plus Clean / Cancel / Reveal controls.
struct ImageJobsView: View {
    @Environment(ImageModel.self) private var imageModel

    var body: some View {
        VStack(spacing: Layout.sectionSpacing) {
            List(imageModel.jobs) { job in
                ImageJobRow(job: job)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .frame(minHeight: Layout.listMinHeight)
            .background(.thickMaterial, in: .rect(cornerRadius: Layout.cardCornerRadius))
            .clipShape(.rect(cornerRadius: Layout.cardCornerRadius))
            .overlay {
                if imageModel.jobs.isEmpty {
                    ContentUnavailableView("No Images Yet", systemImage: "photo",
                                           description: Text("Drop images above or click Choose Images…"))
                }
            }

            HStack {
                Button("Clear Finished", action: imageModel.clearFinished)
                    .disabled(imageModel.jobs.isEmpty)
                Button("Cancel All", role: .cancel, action: imageModel.cancelAll)
                    .disabled(!imageModel.hasActiveJobs)
                Button("Reveal in Finder", action: imageModel.revealOutputs)
                    .keyboardShortcut("r")
                Spacer()
                Button("Clean ^[\(imageModel.readyCount) Image](inflect: true)", action: imageModel.startCleaning)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(imageModel.readyCount == 0)
            }
            .buttonStyle(.bordered)
        }
    }
}
