import Foundation

/// Reads the saved output folder without creating the GUI model (used by the CLI).
enum AppModelDefaults {
    @MainActor
    static var outputDirectory: URL {
        if let path = UserDefaults.standard.string(forKey: "outDir") {
            return URL(filePath: path, directoryHint: .isDirectory)
        }
        return AppModel.defaultOutputDirectory
    }
}
