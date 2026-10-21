import Foundation

/// A fully prepared ffmpeg merge invocation.
struct MergePlan: Sendable {
    let arguments: [String]
    let output: URL
    /// Human-readable explanation of the path taken (shown in the UI).
    let summary: String
    /// Temporary files (e.g. the concat list) to delete afterwards.
    let temporaryFiles: [URL]
}
