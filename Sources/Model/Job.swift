import Foundation

/// One clean-mode file. Output folder and re-encode choice are captured when the file is added.
struct Job: Identifiable, Equatable, Sendable {
    let id = UUID()
    let input: URL
    let outputDirectory: URL
    let reencode: Bool
    var status: JobStatus = .queued
    var progress: Double = 0
    var output: URL?
}
