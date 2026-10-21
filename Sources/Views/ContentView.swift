import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: Layout.sectionSpacing) {
            if let setupError = model.setupError, model.mediaKind == .videos {
                Label(setupError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Picker("Media", selection: $model.mediaKind) {
                Label("Videos", systemImage: "film").tag(MediaKind.videos)
                Label("Images", systemImage: "photo").tag(MediaKind.images)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch model.mediaKind {
            case .videos: VideosPane()
            case .images: ImagesPane()
            }
        }
        .padding()
        .frame(minWidth: Layout.minWindowWidth, minHeight: Layout.minWindowHeight)
    }
}
