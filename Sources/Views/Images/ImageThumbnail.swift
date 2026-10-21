import SwiftUI

/// Small upright thumbnail loaded off the main actor.
struct ImageThumbnail: View {
    let url: URL
    @State private var preview: ImagePreviewLoader.Preview?

    var body: some View {
        Group {
            if let preview {
                Image(decorative: preview.image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: Layout.thumbnailSide, height: Layout.thumbnailSide)
        .clipShape(.rect(cornerRadius: Layout.thumbnailCornerRadius))
        .accessibilityHidden(true)
        .task(id: url) {
            preview = await ImagePreviewLoader.load(url, maxPixelSize: Int(Layout.thumbnailSide) * 2)
        }
    }
}
