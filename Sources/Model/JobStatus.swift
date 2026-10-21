enum JobStatus: Equatable, Sendable {
    /// Added but not started (image mode waits for the user to crop and press Clean).
    case ready
    case queued, working, done, cancelled
    case failed(String)

    var isActive: Bool { self == .queued || self == .working }
}
