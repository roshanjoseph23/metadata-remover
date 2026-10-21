import Foundation

/// Output file extension plus the ffmpeg muxer that writes it.
struct OutputContainer: Sendable, Equatable {
    let fileExtension: String
    let muxer: String

    var isQuickTimeFamily: Bool { muxer == "mp4" || muxer == "mov" }

    static let mp4 = OutputContainer(fileExtension: "mp4", muxer: "mp4")
    static let mov = OutputContainer(fileExtension: "mov", muxer: "mov")
    static let mkv = OutputContainer(fileExtension: "mkv", muxer: "matroska")
    static let webm = OutputContainer(fileExtension: "webm", muxer: "webm")

    /// Keeps the input's container family where possible; never changes stream data.
    static func choose(for input: URL, info: ProbeInfo, reencode: Bool) -> OutputContainer {
        if reencode { return .mp4 }
        let ext = input.pathExtension.lowercased()
        let mp4Video: Set = ["h264", "hevc", "av1", "mpeg4", "vp9"]
        let mp4Audio: Set = ["aac", "mp3", "alac", "ac3", "eac3", "opus", "flac"]
        let fitsMP4 = info.videoCodecs.allSatisfy(mp4Video.contains) && info.audioCodecs.allSatisfy(mp4Audio.contains)
        if ext == "webm" { return .webm }
        if ext == "mkv" { return .mkv }
        if fitsMP4 { return .mp4 }
        if ["mov", "qt", "mp4", "m4v", "3gp", "3g2"].contains(ext) { return .mov }  // e.g. ProRes / PCM audio
        return .mkv
    }
}
