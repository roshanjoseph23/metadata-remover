import CoreGraphics

/// Alpha and HDR helpers used by `ImageCleaner`.
extension CGImage {
    var hasAlpha: Bool {
        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly: true
        default: false
        }
    }

    static func copy(_ image: CGImage, contentHeadroom: Float) -> CGImage? {
        guard #available(macOS 15.0, *) else { return image }
        return CGImageCreateCopyWithContentHeadroom(contentHeadroom, image)
    }
}
