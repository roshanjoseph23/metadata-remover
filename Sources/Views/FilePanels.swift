import AppKit
import UniformTypeIdentifiers

/// Open panels for picking media files and output folders.
@MainActor
enum FilePanels {
    static func chooseFiles(message: String, contentTypes: [UTType]) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = contentTypes
        panel.message = message
        return panel.runModal() == .OK ? panel.urls : []
    }

    static func chooseFolder(startingAt directory: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = directory
        panel.prompt = "Use Folder"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
