import Foundation
import Testing
@testable import MetadataRemoverLogic

struct ContainerSanitizerTests {
    private func segment(_ marker: UInt8, _ payload: [UInt8]) -> [UInt8] {
        let length = payload.count + 2
        return [0xFF, marker, UInt8(length >> 8), UInt8(length & 0xFF)] + payload
    }

    @Test func jpegKeepsOnlyJFIFICCAndAdobeSegments() throws {
        let scan: [UInt8] = [0xFF, 0xDA, 0x00, 0x02, 0x11, 0x22, 0xFF, 0xD9]
        let input = [0xFF, 0xD8] + segment(0xE0, Array("JFIF\0".utf8)) + segment(0xE1, Array("Exif\0\0iPhone".utf8))
            + segment(0xE2, Array("ICC_PROFILE\0".utf8)) + segment(0xED, Array("Photoshop".utf8))
            + segment(0xFE, Array("comment".utf8)) + segment(0xEE, Array("Adobe".utf8)) + segment(0xDB, [0, 1, 2]) + scan
        let output = try #require(ContainerSanitizer.sanitizeJPEG(Data(input)))
        let text = String(decoding: output, as: UTF8.self)
        #expect(text.contains("JFIF") && text.contains("ICC_PROFILE") && text.contains("Adobe"))
        #expect(!text.contains("Exif") && !text.contains("iPhone") && !text.contains("Photoshop") && !text.contains("comment"))
        #expect(Array(output.suffix(scan.count)) == scan)
    }

    @Test func malformedJPEGIsRejectedNotOverread() {
        #expect(ContainerSanitizer.sanitizeJPEG(Data([0xFF, 0xD8, 0xFF, 0xE1, 0xFF, 0xFF, 0x00])) == nil)
        #expect(ContainerSanitizer.sanitizeJPEG(Data([0x00, 0x01, 0x02, 0x03, 0x04])) == nil)
        #expect(ContainerSanitizer.sanitizeJPEG(Data()) == nil)
    }

    private func chunk(_ type: String, _ payload: [UInt8]) -> [UInt8] {
        let n = payload.count
        return [UInt8(n >> 24), UInt8((n >> 16) & 0xFF), UInt8((n >> 8) & 0xFF), UInt8(n & 0xFF)] + Array(type.utf8) + payload + [0, 0, 0, 0]
    }

    @Test func pngDropsTextExifTimeAndC2PA() throws {
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let input = signature + chunk("IHDR", Array(repeating: 1, count: 13)) + chunk("tEXt", Array("parameters\0Seed".utf8))
            + chunk("iCCP", Array("icc".utf8)) + chunk("eXIf", Array("MM".utf8)) + chunk("caBX", Array("jumb".utf8))
            + chunk("tIME", [7, 0, 1, 1, 0, 0, 0]) + chunk("IDAT", [1, 2, 3]) + chunk("IEND", [])
        let output = try #require(ContainerSanitizer.sanitizePNG(Data(input)))
        let text = String(decoding: output, as: UTF8.self)
        for kept in ["IHDR", "iCCP", "IDAT", "IEND"] { #expect(text.contains(kept)) }
        for dropped in ["tEXt", "parameters", "eXIf", "caBX", "jumb", "tIME"] { #expect(!text.contains(dropped)) }
    }

    @Test func truncatedPNGIsRejected() {
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        #expect(ContainerSanitizer.sanitizePNG(Data(signature + [0xFF, 0xFF, 0xFF, 0xFF] + Array("IDAT".utf8) + [0, 0, 0, 0])) == nil)
    }
}
