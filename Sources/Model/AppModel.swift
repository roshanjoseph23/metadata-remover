import AppKit
import Observation

/// App-wide state. Main-actor isolated; heavy work runs in the `VideoCleaner` engine off the main actor.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private enum DefaultsKey {
        static let outputDirectory = "outDir"
        static let reencode = "reencode"
        static let mode = "mode"
        static let mediaKind = "mediaKind"
    }

    static var defaultOutputDirectory: URL {
        URL.homeDirectory.appending(path: "Movies/Cleaned Videos", directoryHint: .isDirectory)
    }

    var jobs: [Job] = []
    var outputDirectory: URL {
        didSet { UserDefaults.standard.set(outputDirectory.path, forKey: DefaultsKey.outputDirectory) }
    }
    var reencode: Bool {
        didSet { UserDefaults.standard.set(reencode, forKey: DefaultsKey.reencode) }
    }
    var mode: WorkMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: DefaultsKey.mode) }
    }
    var mediaKind: MediaKind {
        didSet { UserDefaults.standard.set(mediaKind.rawValue, forKey: DefaultsKey.mediaKind) }
    }
    var setupError: String?
    var mergeItems: [MergeItem] = []
    var mergeState: MergeState = .idle

    var hasActiveJobs: Bool { jobs.contains { $0.status.isActive } }

    @ObservationIgnored private var engineTask: Task<VideoCleaner?, Never>?
    @ObservationIgnored private var queueTask: Task<Void, Never>?
    @ObservationIgnored private var currentJob: (id: UUID, task: Task<URL, Error>)?
    @ObservationIgnored private var mergeTask: Task<Void, Never>?

    private init() {
        let defaults = UserDefaults.standard
        if let path = defaults.string(forKey: DefaultsKey.outputDirectory) {
            outputDirectory = URL(filePath: path, directoryHint: .isDirectory)
        } else {
            outputDirectory = Self.defaultOutputDirectory
        }
        reencode = defaults.bool(forKey: DefaultsKey.reencode)
        mode = WorkMode(rawValue: defaults.string(forKey: DefaultsKey.mode) ?? "") ?? .clean
        mediaKind = MediaKind(rawValue: defaults.string(forKey: DefaultsKey.mediaKind) ?? "") ?? .videos
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        engineTask = Task {
            do {
                return try await VideoCleaner.locate()
            } catch {
                setupError = "\(error)"
                return nil
            }
        }
    }

    private func engine() async -> VideoCleaner? {
        await engineTask?.value
    }

    // MARK: Adding files

    /// Accepts files and folders (searched recursively). Routes to the clean queue or the merge list.
    func add(_ urls: [URL]) {
        let files = Self.videoFiles(in: urls)
        guard !files.isEmpty else { return }
        switch mode {
        case .merge:
            mergeItems.append(contentsOf: files.map { MergeItem(url: $0) })
            if !mergeState.isWorking { mergeState = .idle }
        case .clean:
            jobs.append(contentsOf: files.map { Job(input: $0, outputDirectory: outputDirectory, reencode: reencode) })
            startQueueIfNeeded()
        }
    }

    private static func videoFiles(in urls: [URL]) -> [URL] {
        var files: [URL] = []
        for url in urls {
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                while let file = enumerator?.nextObject() as? URL {
                    if VideoCleaner.isVideo(file) { files.append(file) }
                }
            } else if VideoCleaner.isVideo(url) {
                files.append(url)
            }
        }
        return files
    }

    // MARK: Clean queue (one file at a time, in order)

    private func startQueueIfNeeded() {
        guard queueTask == nil else { return }
        queueTask = Task {
            await runQueue()
            queueTask = nil
        }
    }

    private func runQueue() async {
        while let job = jobs.first(where: { $0.status == .queued }) {
            guard let engine = await engine() else {
                updateJob(job.id) { $0.status = .failed(self.setupError ?? "ffmpeg not found") }
                continue
            }
            guard jobs.first(where: { $0.id == job.id })?.status == .queued else { continue }  // cancelled meanwhile
            updateJob(job.id) { $0.status = .working }
            let id = job.id
            let task = Task {
                try await engine.clean(job.input, outputDirectory: job.outputDirectory, reencode: job.reencode) { fraction in
                    Task { @MainActor in self.setProgress(fraction, for: id) }
                }
            }
            currentJob = (id, task)
            do {
                let output = try await task.value
                updateJob(id) { $0.status = .done; $0.output = output; $0.progress = 1 }
            } catch is CancellationError {
                updateJob(id) { $0.status = .cancelled }
            } catch {
                updateJob(id) { $0.status = .failed("\(error)") }
            }
            currentJob = nil
        }
    }

    private func updateJob(_ id: UUID, _ change: (inout Job) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        change(&jobs[index])
    }

    private func setProgress(_ fraction: Double, for id: UUID) {
        updateJob(id) { job in
            if job.status == .working { job.progress = fraction }
        }
    }

    func cancelJob(_ id: UUID) {
        if currentJob?.id == id {
            currentJob?.task.cancel()
        } else {
            updateJob(id) { job in
                if job.status == .queued { job.status = .cancelled }
            }
        }
    }

    func cancelAllJobs() {
        for index in jobs.indices where jobs[index].status == .queued {
            jobs[index].status = .cancelled
        }
        currentJob?.task.cancel()
    }

    func clearFinishedJobs() {
        jobs.removeAll { !$0.status.isActive }
    }

    func revealCleanedFiles() {
        let outputs = jobs.compactMap(\.output).filter { FileManager.default.fileExists(atPath: $0.path) }
        if outputs.isEmpty {
            NSWorkspace.shared.open(outputDirectory)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting(outputs)
        }
    }

    // MARK: Merge

    func moveMergeItems(from source: IndexSet, to destination: Int) {
        guard !mergeState.isWorking else { return }
        mergeItems.move(fromOffsets: source, toOffset: destination)
    }

    func moveMergeItem(_ id: UUID, by offset: Int) {
        guard !mergeState.isWorking,
              let index = mergeItems.firstIndex(where: { $0.id == id }),
              mergeItems.indices.contains(index + offset) else { return }
        mergeItems.swapAt(index, index + offset)
    }

    func removeMergeItem(_ id: UUID) {
        guard !mergeState.isWorking else { return }
        mergeItems.removeAll { $0.id == id }
    }

    func clearMergeList() {
        guard !mergeState.isWorking else { return }
        mergeItems.removeAll()
        mergeState = .idle
    }

    func startMerge() {
        guard !mergeState.isWorking else { return }
        let urls = mergeItems.map(\.url)
        guard urls.count >= 2 else {
            mergeState = .failed("Add at least two videos to merge.")
            return
        }
        let directory = outputDirectory, forceReencode = reencode
        mergeState = .working(progress: 0, summary: "Analysing videos…")
        mergeTask = Task {
            guard let engine = await engine() else {
                mergeState = .failed(setupError ?? "ffmpeg not found")
                return
            }
            do {
                let result = try await engine.merge(urls, outputDirectory: directory, forceReencode: forceReencode,
                    onPlan: { summary in
                        Task { @MainActor in self.updateMergeProgress(summary: summary) }
                    },
                    progress: { fraction in
                        Task { @MainActor in self.updateMergeProgress(fraction: fraction) }
                    })
                mergeState = .done(output: result.output, summary: result.summary)
            } catch is CancellationError {
                mergeState = .cancelled
            } catch {
                mergeState = .failed("\(error)")
            }
            mergeTask = nil
        }
    }

    private func updateMergeProgress(fraction: Double? = nil, summary: String? = nil) {
        guard case .working(let oldFraction, let oldSummary) = mergeState else { return }
        mergeState = .working(progress: fraction ?? oldFraction, summary: summary ?? oldSummary)
    }

    func cancelMerge() {
        mergeTask?.cancel()
    }

    func revealMergedFile() {
        if case .done(let output, _) = mergeState, FileManager.default.fileExists(atPath: output.path) {
            NSWorkspace.shared.activateFileViewerSelecting([output])
        } else {
            NSWorkspace.shared.open(outputDirectory)
        }
    }

    // MARK: Lifecycle

    /// Called at quit: stop the queue, then synchronously kill any ffmpeg still running and delete partial outputs.
    func shutDown() {
        cancelAllJobs()
        cancelMerge()
        ProcessRegistry.shared.terminateAll()
    }
}
