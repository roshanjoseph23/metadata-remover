import Foundation

/// Runs a child process asynchronously. Cancelling the calling task terminates the process
/// and throws `CancellationError`.
enum ProcessRunner {
    @concurrent
    static func run(
        _ executable: String,
        _ arguments: [String],
        collectStdout: Bool = true,
        cleanupOnQuit: [URL] = [],
        duration: Double = 0,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> ProcessResult {
        try Task.checkCancellation()
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        let outPipe = Pipe(), errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let collector = OutputCollector(collectStdout: collectStdout, duration: duration, progress: progress)
        outPipe.fileHandleForReading.readabilityHandler = { collector.consumeStdout($0.availableData) }
        errPipe.fileHandleForReading.readabilityHandler = { collector.consumeStderr($0.availableData) }

        let running = RunningProcess(process: process, cleanupURLs: cleanupOnQuit)
        ProcessRegistry.shared.register(running)
        defer { ProcessRegistry.shared.unregister(running) }

        let status: Int32
        do {
            status = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, Error>) in
                    process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
                    do {
                        try running.start()
                    } catch {
                        process.terminationHandler = nil
                        continuation.resume(throwing: error is CancellationError
                            ? error
                            : CleanError("Could not launch \(executable): \(error.localizedDescription)"))
                    }
                }
            } onCancel: {
                running.terminate()
            }
        } catch {
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            throw error
        }

        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil
        collector.consumeStdout(outPipe.fileHandleForReading.readDataToEndOfFile())
        collector.consumeStderr(errPipe.fileHandleForReading.readDataToEndOfFile())
        try Task.checkCancellation()
        return collector.result(status: status)
    }
}
