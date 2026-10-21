import Foundation

/// Finds the real ffmpeg/ffprobe binaries by absolute path (never via the shell, where aliases/functions may exist).
enum FFmpegLocator {
    static let searchDirectories = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin"]

    static func find(_ name: String) -> String? {
        searchDirectories
            .map { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
