import CoreGraphics

/// One encoded frame plus anything that rides along with it.
struct EncodedFrame {
    var image: CGImage
    var sourceBits = 8
    var gifDelay: Double?
    var encodeToISOGainMap = false
    var auxiliary: (CFString, [CFString: Any])?

    init(image: CGImage, sourceBits: Int = 8, encodeToISOGainMap: Bool = false) {
        self.image = image
        self.sourceBits = sourceBits
        self.encodeToISOGainMap = encodeToISOGainMap
    }
}
