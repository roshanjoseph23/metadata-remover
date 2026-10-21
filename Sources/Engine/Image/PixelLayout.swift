import CoreImage

/// The pixel format to render into for a given source and output.
struct PixelLayout {
    let bits: Int
    let isFloat: Bool
    let gray: Bool
    let alpha: Bool

    init(sourceBits: Int, isFloat sourceFloat: Bool, target: OutputTarget, gray: Bool, alpha: Bool) {
        self.gray = gray
        self.alpha = alpha
        if target.isEightBitOnly || sourceBits <= 8 {
            bits = 8; isFloat = false
        } else if sourceFloat && target.supportsFloat {
            bits = sourceBits >= 32 ? 32 : 16; isFloat = true
        } else {
            bits = 16; isFloat = false
        }
    }

    var ciFormat: CIFormat {
        switch (bits, isFloat, gray, alpha) {
        case (8, _, true, false): .L8
        case (8, _, true, true): .LA8
        case (8, _, false, _): .RGBA8
        case (16, false, true, false): .L16
        case (16, false, true, true): .LA16
        case (16, false, false, _): .RGBA16
        case (16, true, true, false): .Lh
        case (16, true, true, true): .LAh
        case (16, true, false, _): .RGBAh
        case (_, _, true, false): .Lf
        case (_, _, true, true): .LAf
        default: .RGBAf
        }
    }

    /// Whether the decoded image can be written as-is: the output keeps its depth class.
    func matches(_ image: CGImage) -> Bool {
        let bitsPerComponent = image.bitsPerComponent
        if bits == 8 { return bitsPerComponent == 8 }
        return bitsPerComponent > 8
    }
}
