import Foundation

/// Minimal stream summary used by clean mode to choose the output container.
struct ProbeInfo: Sendable {
    var videoCodecs: [String] = []   // excludes attached pictures (cover art)
    var audioCodecs: [String] = []
    var duration: Double = 0
}
