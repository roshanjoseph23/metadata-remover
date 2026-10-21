import CoreGraphics

/// Pure geometry for the crop editor. Rects are normalised (0…1, top-left origin) in the displayed image.
enum CropRectMath {
    enum Corner: CaseIterable, Sendable { case topLeft, topRight, bottomLeft, bottomRight }

    static let minimumSide = 0.04
    static let full = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// Converts a pixel aspect ratio into the equivalent ratio in normalised units.
    static func normalizedRatio(_ ratio: Double?, imageSize: CGSize) -> Double? {
        guard let ratio, imageSize.width > 0, imageSize.height > 0 else { return nil }
        return ratio * imageSize.height / imageSize.width
    }

    /// The default rect for a preset: the largest centred rect of that ratio, or the full image.
    static func defaultRect(normalizedRatio: Double?) -> CGRect {
        guard let r = normalizedRatio else { return full }
        return r >= 1
            ? CGRect(x: 0, y: (1 - 1 / r) / 2, width: 1, height: 1 / r)
            : CGRect(x: (1 - r) / 2, y: 0, width: r, height: 1)
    }

    static func moved(_ rect: CGRect, by delta: CGSize) -> CGRect {
        var moved = rect.offsetBy(dx: delta.width, dy: delta.height)
        moved.origin.x = min(max(0, moved.minX), 1 - moved.width)
        moved.origin.y = min(max(0, moved.minY), 1 - moved.height)
        return moved
    }

    /// Drags `corner` to `point`, keeping the opposite corner fixed and honouring the ratio.
    static func resized(_ rect: CGRect, corner: Corner, to point: CGPoint, normalizedRatio: Double?) -> CGRect {
        let anchor: CGPoint = switch corner {
        case .topLeft: CGPoint(x: rect.maxX, y: rect.maxY)
        case .topRight: CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomLeft: CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomRight: CGPoint(x: rect.minX, y: rect.minY)
        }
        let p = CGPoint(x: min(max(0, point.x), 1), y: min(max(0, point.y), 1))
        let growsRight = corner == .topRight || corner == .bottomRight
        let growsDown = corner == .bottomLeft || corner == .bottomRight
        let maxWidth = growsRight ? 1 - anchor.x : anchor.x
        let maxHeight = growsDown ? 1 - anchor.y : anchor.y
        var width = min(max(minimumSide, abs(p.x - anchor.x)), maxWidth)
        var height = min(max(minimumSide, abs(p.y - anchor.y)), maxHeight)
        if let r = normalizedRatio {
            height = width / r
            if height > maxHeight { height = maxHeight; width = height * r }
            if width > maxWidth { width = maxWidth; height = width / r }
        }
        return CGRect(x: growsRight ? anchor.x : anchor.x - width,
                      y: growsDown ? anchor.y : anchor.y - height,
                      width: width, height: height)
    }

    static func isApproximatelyEqual(_ a: CGRect, _ b: CGRect, tolerance: Double = 0.001) -> Bool {
        abs(a.minX - b.minX) < tolerance && abs(a.minY - b.minY) < tolerance
            && abs(a.width - b.width) < tolerance && abs(a.height - b.height) < tolerance
    }
}
