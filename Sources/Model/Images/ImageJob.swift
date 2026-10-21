import Foundation

struct ImageJob: Identifiable, Equatable, Sendable {
    let id = UUID()
    let input: URL
    var edit = ImageEdit()
    var status: JobStatus = .ready
    var output: URL?
}
