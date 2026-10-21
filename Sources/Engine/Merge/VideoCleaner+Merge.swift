import Foundation

extension VideoCleaner {
    @concurrent
    func probeClip(_ url: URL) async throws -> ClipInfo {
        let result = try await ProcessRunner.run(ffprobe, ["-v", "error", "-show_data_hash", "CRC32", "-show_entries",
            "stream=index,codec_type,codec_name,profile,width,height,pix_fmt,avg_frame_rate,r_frame_rate,sample_rate,channels,color_transfer,extradata_hash,duration:stream_side_data=rotation:stream_disposition=attached_pic:format=duration",
            "-of", "json", url.path])
        guard result.status == 0, let output = FFprobeOutput.decode(result.stdout) else {
            throw CleanError("\(url.lastPathComponent): not a readable video (\(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)))")
        }
        var clip = ClipInfo(url: url)
        var foundVideo = false
        var videoDuration = 0.0
        for stream in output.streams ?? [] {
            if stream.codec_type == "video" && !stream.isAttachedPicture && !foundVideo {
                foundVideo = true
                clip.videoCodec = stream.codec_name ?? "?"
                clip.profile = stream.profile ?? ""
                clip.width = stream.width ?? 0
                clip.height = stream.height ?? 0
                clip.pixelFormat = stream.pix_fmt ?? ""
                var rate = stream.avg_frame_rate ?? "0/0"
                if rate == "0/0" { rate = stream.r_frame_rate ?? "0/0" }
                clip.frameRate = rate
                clip.transfer = stream.color_transfer ?? ""
                clip.videoExtradata = stream.extradata_hash ?? ""
                videoDuration = Double(stream.duration ?? "") ?? 0
                if let rotation = stream.side_data_list?.compactMap(\.rotation).last {
                    clip.rotation = Int(rotation.rounded())
                }
            } else if stream.codec_type == "audio" && !clip.hasAudio {
                clip.hasAudio = true
                clip.audioCodec = stream.codec_name ?? "?"
                clip.sampleRate = stream.sample_rate ?? ""
                clip.channels = stream.channels ?? 0
                clip.audioExtradata = stream.extradata_hash ?? ""
            }
        }
        guard foundVideo else { throw CleanError("\(url.lastPathComponent): no video stream found") }
        let formatDuration = Double(output.format?.duration ?? "") ?? 0
        clip.duration = videoDuration > 0 ? videoDuration : formatDuration
        if clip.duration <= 0 { throw CleanError("\(url.lastPathComponent): could not determine duration") }
        return clip
    }

    static func frameRateValue(_ rate: String) -> Double {
        let parts = rate.split(separator: "/").compactMap { Double($0) }
        if parts.count == 2, parts[1] > 0 { return parts[0] / parts[1] }
        return Double(rate) ?? 0
    }

    /// Reasons why a lossless (concat demuxer, stream copy) join is not possible; empty = copy is OK.
    static func copyBlockers(_ clips: [ClipInfo]) -> [String] {
        guard let first = clips.first else { return [] }
        func differs<T: Equatable>(_ key: (ClipInfo) -> T) -> Bool { clips.contains { key($0) != key(first) } }
        var reasons: [String] = []
        if differs(\.videoCodec) { reasons.append("different video codecs") }
        if differs({ "\($0.width)x\($0.height)" }) { reasons.append("different resolutions") }
        if differs(\.rotation) { reasons.append("different orientations") }
        if differs(\.frameRate) { reasons.append("different frame rates") }
        if differs(\.pixelFormat) || differs(\.transfer) { reasons.append("different pixel formats/colour") }
        if differs(\.hasAudio) {
            reasons.append("some clips have no audio")
        } else if first.hasAudio && (differs(\.audioCodec) || differs(\.sampleRate) || differs(\.channels)) {
            reasons.append("different audio formats")
        }
        if reasons.isEmpty && (differs(\.profile) || differs(\.videoExtradata) || (first.hasAudio && differs(\.audioExtradata))) {
            reasons.append("different encoder settings")
        }
        // The concat demuxer reads a line-based list file; a line break in a path would break (or inject) entries.
        // Such clips go through the filter-graph join instead, where each path is a separate process argument.
        if clips.contains(where: { $0.url.path.contains(where: \.isNewline) }) {
            reasons.append("a file name contains a line break")
        }
        return reasons
    }

    func planMerge(_ clips: [ClipInfo], outputDirectory: URL, forceReencode: Bool) throws -> MergePlan {
        let blockers = Self.copyBlockers(clips)
        let base = ["-nostdin", "-hide_banner", "-loglevel", "error", "-y"]
        let first = clips[0]

        if blockers.isEmpty && !forceReencode {
            // Lossless: concat demuxer + stream copy
            var info = ProbeInfo()
            info.videoCodecs = [first.videoCodec]
            info.audioCodecs = first.hasAudio ? [first.audioCodec] : []
            let container = OutputContainer.choose(for: first.url, info: info, reencode: false)
            let output = try newOutputURL(in: outputDirectory, fileExtension: container.fileExtension)
            let list = URL.temporaryDirectory.appending(path: "vmr-concat-\(UUID().uuidString).txt")
            let body = clips
                .map { "file '" + $0.url.path.replacing("'", with: "'\\''") + "'" }
                .joined(separator: "\n") + "\n"
            try body.write(to: list, atomically: true, encoding: .utf8)
            var args = base + ["-f", "concat", "-safe", "0", "-i", list.path,
                               "-map", "0:v:0", "-map", "0:a:0?", "-c", "copy"]
            if first.videoCodec == "h264" { args += ["-bsf:v", "filter_units=remove_types=6"] }
            if first.videoCodec == "hevc" {
                args += ["-bsf:v", "filter_units=remove_types=39|40"]
                if container.isQuickTimeFamily { args += ["-tag:v", "hvc1"] }
            }
            args += stripArguments(for: container) + ["-progress", "pipe:1", "-nostats", "-f", container.muxer, output.path]
            return MergePlan(arguments: args, output: output,
                             summary: "Lossless join (stream copy, no quality loss)", temporaryFiles: [list])
        }

        // Re-encode with the concat filter
        func even(_ value: Int) -> Int { max(2, value - value % 2) }
        let width = even(first.displayWidth), height = even(first.displayHeight)
        var frameRate = first.frameRate
        let rateValue = Self.frameRateValue(frameRate)
        if !(rateValue >= 1 && rateValue <= 120) { frameRate = "30" }
        let anyAudio = clips.contains(where: \.hasAudio)
        var args = base
        for clip in clips { args += ["-i", clip.url.path] }
        var graph: [String] = []
        var concatInputs = ""
        for (index, clip) in clips.enumerated() {
            // Fixed POSIX formatting: this is an ffmpeg argument, not user-visible text.
            let duration = String(format: "%.6f", clip.duration)
            // ffmpeg applies autorotate before the filtergraph, so frames arrive upright.
            var video = "[\(index):v:0]"
            video += "scale=\(width):\(height):force_original_aspect_ratio=decrease:force_divisible_by=2"
            if clip.isHDR || clip.isHighBitDepth || clip.transfer == "bt2020-10" { video += ":out_color_matrix=bt709:out_range=tv" }
            video += ",pad=\(width):\(height):(ow-iw)/2:(oh-ih)/2:black,setsar=1,fps=\(frameRate),format=yuv420p,trim=end=\(duration),setpts=PTS-STARTPTS[v\(index)]"
            graph.append(video)
            concatInputs += "[v\(index)]"
            if anyAudio {
                if clip.hasAudio {
                    graph.append("[\(index):a:0]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,atrim=end=\(duration),apad=whole_dur=\(duration),asetpts=PTS-STARTPTS[a\(index)]")
                } else {
                    graph.append("anullsrc=r=48000:cl=stereo,atrim=end=\(duration),asetpts=PTS-STARTPTS[a\(index)]")
                }
                concatInputs += "[a\(index)]"
            }
        }
        graph.append(concatInputs + "concat=n=\(clips.count):v=1:a=\(anyAudio ? 1 : 0)[vout]" + (anyAudio ? "[aout]" : ""))
        let output = try newOutputURL(in: outputDirectory, fileExtension: "mp4")
        args += ["-filter_complex", graph.joined(separator: ";"), "-map", "[vout]"]
        if anyAudio { args += ["-map", "[aout]"] }
        if hasLibx264 {
            args += ["-c:v", "libx264", "-preset", "medium", "-crf", "18"]
        } else {
            args += ["-c:v", "h264_videotoolbox", "-q:v", "65"]
        }
        args += ["-pix_fmt", "yuv420p", "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
                 "-bsf:v", "filter_units=remove_types=6"]
        if anyAudio { args += ["-c:a", "aac", "-b:a", "192k"] }
        args += stripArguments(for: .mp4) + ["-progress", "pipe:1", "-nostats", "-f", "mp4", output.path]

        let reason = forceReencode && blockers.isEmpty ? "Re-encode option is on" : blockers.joined(separator: ", ")
        let fpsLabel = frameRate.hasSuffix("/1") ? String(frameRate.dropLast(2)) : frameRate
        var summary = "Re-encoded to \(width)×\(height) @ \(fpsLabel) fps H.264/AAC (\(reason))"
        if clips.contains(where: \.isHDR) { summary += "; HDR converted to SDR (colours may look flatter)" }
        return MergePlan(arguments: args, output: output, summary: summary, temporaryFiles: [])
    }

    @concurrent
    func merge(_ inputs: [URL], outputDirectory: URL, forceReencode: Bool,
               onPlan: @escaping @Sendable (String) -> Void,
               progress: @escaping @Sendable (Double) -> Void) async throws -> MergeResult {
        guard inputs.count >= 2 else { throw CleanError("Add at least two videos to merge") }
        var clips: [ClipInfo] = []
        for input in inputs { clips.append(try await probeClip(input)) }
        let plan = try planMerge(clips, outputDirectory: outputDirectory, forceReencode: forceReencode)
        defer { plan.temporaryFiles.forEach { try? FileManager.default.removeItem(at: $0) } }
        onPlan(plan.summary)
        let total = clips.reduce(0) { $0 + $1.duration }
        let result: ProcessResult
        do {
            result = try await ProcessRunner.run(ffmpeg, plan.arguments, collectStdout: false,
                                                 cleanupOnQuit: [plan.output] + plan.temporaryFiles,
                                                 duration: total, progress: progress)
        } catch {
            try? FileManager.default.removeItem(at: plan.output)
            throw error
        }
        guard result.status == 0 else {
            try? FileManager.default.removeItem(at: plan.output)
            let message = result.stderrTail(3)
            throw CleanError("Merge failed (ffmpeg \(result.status)): \(message.isEmpty ? "unknown error" : message)")
        }
        FileScrubber.scrub(plan.output)
        progress(1)
        return MergeResult(output: plan.output, summary: plan.summary)
    }

    /// For `--print-args` debugging: the exact command a merge would run (nothing is executed).
    @concurrent
    func mergeCommandPreview(_ inputs: [URL], outputDirectory: URL, forceReencode: Bool) async -> String {
        var clips: [ClipInfo] = []
        for input in inputs {
            guard let clip = try? await probeClip(input) else { return "?" }
            clips.append(clip)
        }
        guard let plan = try? planMerge(clips, outputDirectory: outputDirectory, forceReencode: forceReencode) else { return "?" }
        plan.temporaryFiles.forEach { try? FileManager.default.removeItem(at: $0) }
        return CommandFormatter.shellQuoted([ffmpeg] + plan.arguments)
    }
}
