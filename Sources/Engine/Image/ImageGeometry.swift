import CoreImage

enum ImageGeometry {
    /// Applies clockwise quarter turns then an optional horizontal flip, with the result's origin at (0, 0).
    static func apply(_ image: CIImage, quarterTurns: Int, flipHorizontal: Bool) -> CIImage {
        var result = image
        for _ in 0..<(((quarterTurns % 4) + 4) % 4) { result = result.oriented(.right) }
        if flipHorizontal { result = result.oriented(.upMirrored) }
        return result.transformed(by: CGAffineTransform(translationX: -result.extent.minX, y: -result.extent.minY))
    }

    /// The largest rectangle of the given width÷height ratio, centred, in whole pixels (top-left origin).
    static func centeredRect(ratio: Double, width: Double, height: Double) -> CGRect {
        var cropWidth = width, cropHeight = (width / ratio).rounded()
        if cropHeight > height {
            cropHeight = height
            cropWidth = (height * ratio).rounded()
        }
        return CGRect(x: ((width - cropWidth) / 2).rounded(.down), y: ((height - cropHeight) / 2).rounded(.down),
                      width: cropWidth, height: cropHeight)
    }

    /// Size after applying `quarterTurns` to an upright image of `size`.
    static func rotatedSize(_ size: CGSize, quarterTurns: Int) -> CGSize {
        ((quarterTurns % 2) + 2) % 2 == 1 ? CGSize(width: size.height, height: size.width) : size
    }
}
