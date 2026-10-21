import CoreGraphics
import Foundation
import Testing
@testable import MetadataRemoverLogic

struct ColorSpaceStandardizerTests {
    @Test(arguments: [CGColorSpace.sRGB, CGColorSpace.displayP3, CGColorSpace.adobeRGB1998, CGColorSpace.rommrgb,
                      CGColorSpace.itur_2100_PQ, CGColorSpace.itur_2100_HLG, CGColorSpace.linearSRGB,
                      CGColorSpace.genericGrayGamma2_2].map { $0 as String })
    func standardSpacesAreKept(nameString: String) throws {
        let name = nameString as CFString
        let space = try #require(CGColorSpace(name: name))
        let result = ColorSpaceStandardizer.standardize(space)
        #expect(result.isExactMatch)
        #expect(result.colorSpace.name == name)
    }

    @Test func renamedStandardProfileMapsToTheStandardSpace() throws {
        // Display P3's ICC data with its description changed: same colourimetry, custom (identifying) text.
        var bytes = [UInt8](try #require(CGColorSpace(name: CGColorSpace.displayP3)?.copyICCData()) as Data)
        let from = Array("Display P3".utf16).flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
        let to = Array("TestMac-01".utf16).flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
        var index = 0
        while index + from.count <= bytes.count {
            if Array(bytes[index..<index + from.count]) == from { bytes.replaceSubrange(index..<index + from.count, with: to) }
            index += 1
        }
        let custom = try #require(CGColorSpace(iccData: Data(bytes) as CFData))
        let result = ColorSpaceStandardizer.standardize(custom)
        #expect(result.isExactMatch)
        #expect(result.colorSpace.name == CGColorSpace.displayP3)
    }

    @Test func unknownWideGamutIsNotClipped() throws {
        let odd = try #require(CGColorSpace(calibratedRGBWhitePoint: [0.9505, 1, 1.089], blackPoint: [0, 0, 0], gamma: [2.2, 2.2, 2.2],
                                            matrix: [0.70, 0.28, 0, 0.10, 0.70, 0.05, 0.15, 0.02, 0.95]))
        let result = ColorSpaceStandardizer.standardize(odd)
        #expect(!result.isExactMatch)
        #expect([CGColorSpace.displayP3, CGColorSpace.itur_2020, CGColorSpace.rommrgb].contains(result.colorSpace.name ?? "" as CFString))
    }

    @Test func hdrDetection() {
        #expect(ColorSpaceStandardizer.isHDR(CGColorSpace(name: CGColorSpace.itur_2100_PQ)))
        #expect(ColorSpaceStandardizer.isHDR(CGColorSpace(name: CGColorSpace.itur_2100_HLG)))
        #expect(!ColorSpaceStandardizer.isHDR(CGColorSpace(name: CGColorSpace.displayP3)))
        #expect(!ColorSpaceStandardizer.isHDR(nil))
        #expect(ColorSpaceStandardizer.standardize(nil).colorSpace.name == CGColorSpace.sRGB)
    }
}
