import UniformTypeIdentifiers

/// What the chosen output format can carry.
struct OutputTarget {
    let type: UTType
    let quality: Double

    var isLossy: Bool { type == .jpeg || type == .heic || type.identifier == "public.avif" }
    var supportsAlpha: Bool { type != .jpeg }
    /// HEIC/AVIF encode >8-bit sources as 10-bit.
    var supportsHighBitDepthLossy: Bool { type == .heic || type.identifier == "public.avif" }
    /// Formats that can carry PQ/HLG-encoded pixels directly.
    var supportsHDREncoding: Bool { type != .jpeg && type != .gif }
    /// Formats ImageIO can write an HDR gain map into.
    var supportsGainMap: Bool { type == .jpeg || type == .heic }
    /// Formats limited to 8 bits per channel.
    var isEightBitOnly: Bool { type == .jpeg || type == .gif }
    var supportsFloat: Bool { type == .tiff }
}
