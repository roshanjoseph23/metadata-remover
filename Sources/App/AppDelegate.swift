import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Files dropped on the Dock icon or opened with "Open With": images go to image mode, everything else to video mode.
    @MainActor
    func application(_ application: NSApplication, open urls: [URL]) {
        let images = urls.filter(ImageCleaner.isImage)
        let videos = urls.filter { !ImageCleaner.isImage($0) }
        if !videos.isEmpty { AppModel.shared.add(videos) }
        if !images.isEmpty { ImageModel.shared.add(images) }
        AppModel.shared.mediaKind = images.isEmpty ? .videos : (videos.isEmpty ? .images : AppModel.shared.mediaKind)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Never leave ffmpeg running (or half-written files behind) after quitting.
    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        ImageModel.shared.cancelAll()
        AppModel.shared.shutDown()
    }
}
