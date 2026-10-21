import Foundation

/// Per-clip stream parameters used to decide between a lossless join and a re-encode.
struct ClipInfo: Sendable {
    var url: URL
    var videoCodec = "", profile = "", pixelFormat = "", frameRate = "", transfer = "", videoExtradata = ""
    var width = 0, height = 0, rotation = 0
    var hasAudio = false
    var audioCodec = "", sampleRate = "", audioExtradata = ""
    var channels = 0
    var duration: Double = 0

    var isRotated: Bool { abs(rotation) % 180 == 90 }
    var displayWidth: Int { isRotated ? height : width }
    var displayHeight: Int { isRotated ? width : height }
    var isHDR: Bool { ["smpte2084", "arib-std-b67"].contains(transfer) }
    var isHighBitDepth: Bool { pixelFormat.contains("10") || pixelFormat.contains("12") }
}
