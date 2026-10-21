import SwiftUI

/// Image tab: drop zone, options, batch list and crop editor sheet.
struct ImagesPane: View {
    @Environment(ImageModel.self) private var imageModel

    var body: some View {
        @Bindable var imageModel = imageModel
        VStack(spacing: Layout.sectionSpacing) {
            DropZoneView(
                title: "Drop images here",
                subtitle: "Pixels are re-encoded into a new file with a random name —\nno EXIF, GPS, XMP, C2PA or device data. Originals are never modified.",
                systemImage: "photo.stack",
                buttonTitle: "Choose Images…",
                panelMessage: "Choose images to clean",
                contentTypes: [.image],
                onAdd: imageModel.add
            )
            ImageOptionsView()
            ImageJobsView()
        }
        .sheet(item: $imageModel.editingJob, content: CropEditorView.init)
    }
}
