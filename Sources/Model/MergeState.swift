import Foundation

enum MergeState: Equatable, Sendable {
    case idle
    case working(progress: Double, summary: String)
    case done(output: URL, summary: String)
    case cancelled
    case failed(String)

    var isWorking: Bool {
        if case .working = self { true } else { false }
    }
}
