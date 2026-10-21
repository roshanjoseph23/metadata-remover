import Foundation

/// Final byte-level pass over freshly encoded files. ImageIO adds a few automatic blocks of its own
/// (an Exif IFD with ColorSpace and pixel dimensions, an empty Photoshop/IPTC APP13 in JPEG, an `eXIf`
/// chunk in PNG). They hold nothing identifying, but this pass removes them so only image data and
/// the standard colour profile remain.
enum ContainerSanitizer {
    static func sanitize(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        let cleaned: Data? = switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": sanitizeJPEG(data)
        case "png": sanitizePNG(data)
        default: nil
        }
        guard let cleaned, cleaned != data else { return }
        try cleaned.write(to: url, options: .atomic)
    }

    // MARK: JPEG

    /// Keeps APP0 (JFIF), APP2 (ICC profile) and APP14 (Adobe colour transform); drops every other APPn and COM.
    static func sanitizeJPEG(_ data: Data) -> Data? {
        let bytes = [UInt8](data)
        guard bytes.count > 4, bytes[0] == 0xFF, bytes[1] == 0xD8 else { return nil }
        var output: [UInt8] = [0xFF, 0xD8]
        var index = 2
        while index + 4 <= bytes.count {
            guard bytes[index] == 0xFF else { return nil }
            let marker = bytes[index + 1]
            if marker == 0xFF { index += 1; continue }               // fill byte
            if marker == 0xDA || marker == 0xD9 {                     // start of scan: copy the rest verbatim
                output.append(contentsOf: bytes[index...])
                return Data(output)
            }
            if (0xD0...0xD7).contains(marker) || marker == 0x01 {     // standalone markers
                output.append(contentsOf: bytes[index..<index + 2]); index += 2; continue
            }
            let length = Int(bytes[index + 2]) << 8 | Int(bytes[index + 3])
            let end = index + 2 + length
            guard length >= 2, end <= bytes.count else { return nil }
            let isApp = (0xE0...0xEF).contains(marker)
            let keep = !isApp && marker != 0xFE || marker == 0xE0 || marker == 0xE2 || marker == 0xEE
            if keep { output.append(contentsOf: bytes[index..<end]) }
            index = end
        }
        return nil
    }

    // MARK: PNG

    /// Pixel and colour chunks only. Text (tEXt/zTXt/iTXt), eXIf, tIME, caBX (C2PA) and anything unknown are dropped.
    private static let allowedPNGChunks: Set<String> = [
        "IHDR", "PLTE", "tRNS", "IDAT", "IEND", "iCCP", "sRGB", "gAMA", "cHRM", "cICP", "sBIT", "acTL", "fcTL", "fdAT",
    ]

    static func sanitizePNG(_ data: Data) -> Data? {
        let bytes = [UInt8](data)
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard bytes.count > 8, Array(bytes[0..<8]) == signature else { return nil }
        var output = signature
        var index = 8
        while index + 12 <= bytes.count {
            let length = Int(bytes[index]) << 24 | Int(bytes[index + 1]) << 16 | Int(bytes[index + 2]) << 8 | Int(bytes[index + 3])
            let end = index + 12 + length
            guard end <= bytes.count, let type = String(bytes: bytes[index + 4..<index + 8], encoding: .ascii) else { return nil }
            if allowedPNGChunks.contains(type) { output.append(contentsOf: bytes[index..<end]) }
            index = end
            if type == "IEND" { return Data(output) }
        }
        return nil
    }
}
