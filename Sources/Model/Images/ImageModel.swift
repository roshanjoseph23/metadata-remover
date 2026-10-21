import AppKit
import Observation

/// State for image mode: the batch list, per-image edits, output settings and the cleaning queue.
@MainActor
@Observable
final class ImageModel {
    static let shared = ImageModel()

    private enum DefaultsKey {
        static let outputDirectory = "imageOutDir"
        static let format = "imageFormat"
        static let keepHDR = "imageKeepHDR"
    }

    nonisolated static var defaultOutputDirectory: URL {
        URL.homeDirectory.appending(path: "Pictures/Cleaned Images", directoryHint: .isDirectory)
    }

    var jobs: [ImageJob] = []
    var outputDirectory: URL {
        didSet { UserDefaults.standard.set(outputDirectory.path, forKey: DefaultsKey.outputDirectory) }
    }
    var format: ImageOutputFormat {
        didSet { UserDefaults.standard.set(format.rawValue, forKey: DefaultsKey.format) }
    }
    /// Keep HDR gain maps and PQ/HLG encodings (off flattens to SDR).
    var keepHDR: Bool {
        didSet { UserDefaults.standard.set(keepHDR, forKey: DefaultsKey.keepHDR) }
    }
    /// The job currently open in the crop editor sheet.
    var editingJob: ImageJob?

    var readyCount: Int { jobs.count { $0.status == .ready } }
    var hasActiveJobs: Bool { jobs.contains { $0.status.isActive } }

    @ObservationIgnored private var queueTask: Task<Void, Never>?
    @ObservationIgnored private var current: (id: UUID, task: Task<URL, Error>)?

    private init() {
        let defaults = UserDefaults.standard
        if let path = defaults.string(forKey: DefaultsKey.outputDirectory) {
            outputDirectory = URL(filePath: path, directoryHint: .isDirectory)
        } else {
            outputDirectory = Self.defaultOutputDirectory
        }
        format = ImageOutputFormat(rawValue: defaults.string(forKey: DefaultsKey.format) ?? "") ?? .jpeg
        keepHDR = defaults.object(forKey: DefaultsKey.keepHDR) as? Bool ?? true
    }

    // MARK: List editing

    func add(_ urls: [URL]) {
        jobs.append(contentsOf: Self.imageFiles(in: urls).map { ImageJob(input: $0) })
    }

    private static func imageFiles(in urls: [URL]) -> [URL] {
        var files: [URL] = []
        for url in urls {
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                while let file = enumerator?.nextObject() as? URL {
                    if ImageCleaner.isImage(file) { files.append(file) }
                }
            } else if ImageCleaner.isImage(url) {
                files.append(url)
            }
        }
        return files
    }

    func remove(_ id: UUID) {
        jobs.removeAll { $0.id == id && !$0.status.isActive }
    }

    func clearFinished() {
        jobs.removeAll { !$0.status.isActive && $0.status != .ready }
    }

    func clearAll() {
        cancelAll()
        jobs.removeAll { !$0.status.isActive }
    }

    func beginEditing(_ id: UUID) {
        editingJob = jobs.first { $0.id == id }
    }

    func applyEdit(_ edit: ImageEdit, to id: UUID) {
        update(id) { $0.edit = edit; if $0.status != .ready { $0.status = .ready; $0.output = nil } }
    }

    /// Batch centre-crop: applies the preset to every waiting image that has no manual crop. `nil` removes preset crops.
    func applyAspectToAll(_ preset: AspectPreset?) {
        for index in jobs.indices where jobs[index].status == .ready {
            switch jobs[index].edit.crop {
            case .normalized, .pixels: continue
            case .aspect, nil: jobs[index].edit.crop = preset.flatMap { $0 == .free ? nil : .aspect($0) }
            }
        }
    }

    // MARK: Cleaning

    func startCleaning() {
        let directory = outputDirectory, format = format, keepHDR = keepHDR
        for index in jobs.indices where jobs[index].status == .ready { jobs[index].status = .queued }
        guard queueTask == nil else { return }
        queueTask = Task {
            while let job = jobs.first(where: { $0.status == .queued }) {
                update(job.id) { $0.status = .working }
                let task = Task {
                    try await ImageCleaner.clean(job.input, outputDirectory: directory, format: format, keepHDR: keepHDR, edit: job.edit)
                }
                current = (job.id, task)
                do {
                    let output = try await task.value
                    update(job.id) { $0.status = .done; $0.output = output }
                } catch is CancellationError {
                    update(job.id) { $0.status = .cancelled }
                } catch {
                    update(job.id) { $0.status = .failed("\(error)") }
                }
                current = nil
            }
            queueTask = nil
        }
    }

    func cancel(_ id: UUID) {
        if current?.id == id { current?.task.cancel() }
        else { update(id) { if $0.status == .queued { $0.status = .cancelled } } }
    }

    func cancelAll() {
        for index in jobs.indices where jobs[index].status == .queued { jobs[index].status = .cancelled }
        current?.task.cancel()
    }

    func revealOutputs() {
        let outputs = jobs.compactMap(\.output).filter { FileManager.default.fileExists(atPath: $0.path) }
        if outputs.isEmpty { NSWorkspace.shared.open(outputDirectory) }
        else { NSWorkspace.shared.activateFileViewerSelecting(outputs) }
    }

    private func update(_ id: UUID, _ change: (inout ImageJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        change(&jobs[index])
    }
}
