import SwiftUI

/// Shows the output folder with a Change… button.
struct OutputFolderRow: View {
    @Binding var directory: URL

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            Label(directory.path, systemImage: "folder")
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Output folder: \(directory.path)")
            Spacer()
            Button("Change…", action: chooseFolder)
                .buttonStyle(.bordered)
                .accessibilityHint("Choose where cleaned files are saved")
        }
    }

    private func chooseFolder() {
        if let folder = FilePanels.chooseFolder(startingAt: directory) { directory = folder }
    }
}
