import SwiftUI

/// Video options: re-encode toggle and output folder.
struct OptionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            Toggle("Re-encode (most thorough, slower)", isOn: $model.reencode)
                .help("Re-encodes to H.264/AAC MP4 so nothing embedded in the original video bitstream survives. Slower and slightly lossy.")
            OutputFolderRow(directory: $model.outputDirectory)
        }
    }
}
