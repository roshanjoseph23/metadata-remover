import Foundation

/// Thread-safe sink for a child process's pipes. Parses ffmpeg `-progress` output incrementally
/// (only the trailing partial line is buffered) and reports throttled progress fractions.
final class OutputCollector: @unchecked Sendable {
    private static let progressKey = Array("out_time_us=".utf8)
    private static let minimumStep = 0.005

    private let lock = NSLock()
    private let collectStdout: Bool
    private let duration: Double
    private let progress: (@Sendable (Double) -> Void)?
    private var stdout = Data()
    private var stderr = Data()
    private var partialLine = Data()
    private var lastReported = -1.0

    init(collectStdout: Bool, duration: Double, progress: (@Sendable (Double) -> Void)?) {
        self.collectStdout = collectStdout
        self.duration = duration
        self.progress = progress
    }

    func consumeStdout(_ data: Data) {
        guard !data.isEmpty else { return }
        let fraction: Double? = lock.withLock {
            if collectStdout { stdout.append(data) }
            guard progress != nil, duration > 0 else { return nil }
            partialLine.append(data)
            var latest: Double?
            while let newline = partialLine.firstIndex(of: 0x0A) {
                let line = partialLine[partialLine.startIndex..<newline]
                if line.starts(with: Self.progressKey),
                   let micros = Double(String(decoding: line.dropFirst(Self.progressKey.count), as: UTF8.self)) {
                    latest = min(1, max(0, micros / 1_000_000 / duration))
                }
                partialLine.removeSubrange(partialLine.startIndex...newline)
            }
            guard let latest, latest - lastReported >= Self.minimumStep else { return nil }
            lastReported = latest
            return latest
        }
        if let fraction { progress?(fraction) }
    }

    func consumeStderr(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.withLock { stderr.append(data) }
    }

    func result(status: Int32) -> ProcessResult {
        lock.withLock {
            ProcessResult(status: status,
                          stdout: String(decoding: stdout, as: UTF8.self),
                          stderr: String(decoding: stderr, as: UTF8.self))
        }
    }
}
