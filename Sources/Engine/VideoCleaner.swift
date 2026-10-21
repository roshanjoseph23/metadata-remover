import Foundation
import UniformTypeIdentifiers

/// The metadata-stripping engine. Immutable and `Sendable`; all work runs off the main actor.
struct VideoCleaner: Sendable {
    let ffmpeg: String
    let ffprobe: String
    let hasLibx264: Bool

    static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "mkv", "avi", "webm", "3gp", "3g2", "qt", "mts", "m2ts", "ts", "mpg", "mpeg", "wmv", "flv", "ogv", "mxf", "hevc", "dv"]

    /// Locates ffmpeg/ffprobe and checks once whether libx264 is available.
    @concurrent
    static func locate() async throws -> VideoCleaner {
        guard let ffmpeg = FFmpegLocator.find("ffmpeg"), let ffprobe = FFmpegLocator.find("ffprobe") else {
            throw CleanError("ffmpeg/ffprobe not found in /opt/homebrew/bin or /usr/local/bin. Install it with: brew install ffmpeg")
        }
        let encoders = try? await ProcessRunner.run(ffmpeg, ["-hide_banner", "-encoders"])
        return VideoCleaner(ffmpeg: ffmpeg, ffprobe: ffprobe, hasLibx264: encoders?.stdout.contains("libx264") ?? false)
    }

    static func isVideo(_ url: URL) -> Bool {
        if videoExtensions.contains(url.pathExtension.lowercased()) { return true }
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .video)
    }

    func newOutputURL(in directory: URL, fileExtension: String) throws -> URL {
        try OutputNaming.newURL(in: directory, fileExtension: fileExtension)
    }

    @concurrent
    func probe(_ url: URL) async throws -> ProbeInfo {
        let result = try await ProcessRunner.run(ffprobe, ["-v", "error", "-show_entries",
            "stream=codec_type,codec_name:stream_disposition=attached_pic:format=duration",
            "-of", "json", url.path])
        guard result.status == 0, let output = FFprobeOutput.decode(result.stdout) else {
            throw CleanError("Not a readable video (ffprobe failed): " + result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        var info = ProbeInfo()
        for stream in output.streams ?? [] {
            let name = stream.codec_name ?? "unknown"
            if stream.codec_type == "video" && !stream.isAttachedPicture { info.videoCodecs.append(name) }
            if stream.codec_type == "audio" { info.audioCodecs.append(name) }
        }
        info.duration = Double(output.format?.duration ?? "") ?? 0
        if info.videoCodecs.isEmpty { throw CleanError("No video stream found") }
        return info
    }

    /// The metadata-stripping options shared by clean and merge. Do not weaken.
    func stripArguments(for container: OutputContainer) -> [String] {
        var args = ["-map_metadata", "-1", "-map_metadata:s:v", "-1", "-map_metadata:s:a", "-1",
                    "-map_chapters", "-1", "-dn", "-sn",
                    "-fflags", "+bitexact", "-flags:v", "+bitexact", "-flags:a", "+bitexact",
                    "-metadata:s:v", "handler_name=", "-metadata:s:a", "handler_name=",
                    "-metadata:s:v", "vendor_id=", "-metadata:s:a", "vendor_id=",
                    "-metadata:s:v", "encoder=", "-metadata:s:a", "encoder=",
                    "-metadata:s:v", "language=und", "-metadata:s:a", "language=und",
                    "-metadata:s:v", "timecode="]
        if container.isQuickTimeFamily { args += ["-write_tmcd", "0", "-movflags", "+faststart"] }
        return args
    }

    func cleanArguments(input: URL, output: URL, info: ProbeInfo, reencode: Bool) -> [String] {
        let container = OutputContainer.choose(for: input, info: info, reencode: reencode)
        var args = ["-nostdin", "-hide_banner", "-loglevel", "error", "-y",
                    "-i", input.path,
                    "-map", "0:V", "-map", "0:a?"]           // 0:V = real video only (no cover art), audio optional
        if reencode {
            if hasLibx264 {
                args += ["-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p"]
            } else {
                args += ["-c:v", "h264_videotoolbox", "-q:v", "65", "-pix_fmt", "yuv420p"]
            }
            args += ["-c:a", "aac", "-b:a", "192k"]
            args += ["-bsf:v", "filter_units=remove_types=6"]  // drop H.264 SEI (encoder info strings)
        } else {
            args += ["-c", "copy"]
            for (index, codec) in info.videoCodecs.enumerated() {
                if codec == "h264" { args += ["-bsf:v:\(index)", "filter_units=remove_types=6"] }   // SEI
                if codec == "hevc" {
                    args += ["-bsf:v:\(index)", "filter_units=remove_types=39|40"]                    // prefix/suffix SEI
                    if container.isQuickTimeFamily { args += ["-tag:v:\(index)", "hvc1"] }
                }
            }
        }
        args += stripArguments(for: container)
        args += ["-progress", "pipe:1", "-nostats", "-f", container.muxer, output.path]
        return args
    }

    /// Cleans one file into `outputDirectory`. Never touches the input. Returns the output URL.
    @concurrent
    func clean(_ input: URL, outputDirectory: URL, reencode: Bool,
               progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let info = try await probe(input)
        let container = OutputContainer.choose(for: input, info: info, reencode: reencode)
        let output = try newOutputURL(in: outputDirectory, fileExtension: container.fileExtension)
        if output.standardizedFileURL.path == input.standardizedFileURL.path { throw CleanError("Output would overwrite input") }
        let args = cleanArguments(input: input, output: output, info: info, reencode: reencode)
        let result: ProcessResult
        do {
            result = try await ProcessRunner.run(ffmpeg, args, collectStdout: false, cleanupOnQuit: [output],
                                                 duration: info.duration, progress: progress)
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
        guard result.status == 0 else {
            try? FileManager.default.removeItem(at: output)
            let message = result.stderrTail(2)
            throw CleanError("ffmpeg failed (\(result.status)): \(message.isEmpty ? "unknown error" : message)")
        }
        FileScrubber.scrub(output)
        progress(1)
        return output
    }
}
