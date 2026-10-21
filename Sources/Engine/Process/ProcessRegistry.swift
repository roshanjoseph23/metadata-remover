import Foundation
import os

/// Tracks every running ffmpeg/ffprobe child so they can be stopped when the app quits.
final class ProcessRegistry: Sendable {
    static let shared = ProcessRegistry()
    private let running = OSAllocatedUnfairLock<[ObjectIdentifier: RunningProcess]>(initialState: [:])

    func register(_ process: RunningProcess) {
        running.withLock { $0[ObjectIdentifier(process)] = process }
    }

    func unregister(_ process: RunningProcess) {
        _ = running.withLock { $0.removeValue(forKey: ObjectIdentifier(process)) }
    }

    func terminateAll() {
        let all = running.withLock { Array($0.values) }
        all.forEach { $0.terminateAndCleanUp() }
    }
}
