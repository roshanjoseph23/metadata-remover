import SwiftUI

struct MetadataRemoverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared
    @State private var imageModel = ImageModel.shared

    var body: some Scene {
        Window("Metadata Remover", id: "main") {
            ContentView()
                .environment(model)
                .environment(imageModel)
        }
        .windowResizability(.contentMinSize)
    }
}
