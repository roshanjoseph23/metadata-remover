import Foundation

/// Wraps a child `Process` so it can be started, cancelled, and killed safely from any thread.
final class RunningProcess: @unchecked Sendable {
    private let lock = NSLock()
    private let process: Process
    private var cancelled = false
    /// Files to delete if the app quits while this process is running (partial outputs, temp lists).
    let cleanupURLs: [URL]

    init(process: Process, cleanupURLs: [URL]) {
        self.process = process
        self.cleanupURLs = cleanupURLs
    }

    /// Launches the process unless it was cancelled first.
    func start() throws {
        try lock.withLock {
            if cancelled { throw CancellationError() }
            try process.run()
        }
    }

    /// Sends SIGTERM (or prevents launch if not started yet).
    func terminate() {
        lock.withLock {
            cancelled = true
            if process.isRunning { process.terminate() }
        }
    }

    /// Used at app quit: terminate, wait briefly, force-kill if needed, then remove partial files.
    func terminateAndCleanUp(timeout: Duration = .seconds(2)) {
        terminate()
        let deadline = ContinuousClock.now + timeout
        while process.isRunning && ContinuousClock.now < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        for url in cleanupURLs { try? FileManager.default.removeItem(at: url) }
    }
}
