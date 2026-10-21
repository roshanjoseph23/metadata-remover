import CoreGraphics
import Testing
@testable import MetadataRemoverLogic

struct CropSpecTests {
    @Test func normalizedCropRoundsToWholePixels() {
        let rect = CropSpec.normalized(CGRect(x: 0.1, y: 0.3, width: 0.6, height: 0.6)).pixelRect(width: 400, height: 600)
        #expect(rect == CGRect(x: 40, y: 180, width: 240, height: 360))
    }

    @Test func outOfBoundsCropsAreClippedOrIgnored() {
        #expect(CropSpec.pixels(CGRect(x: 350, y: 550, width: 100, height: 100)).pixelRect(width: 400, height: 600)
                == CGRect(x: 350, y: 550, width: 50, height: 50))
        #expect(CropSpec.pixels(CGRect(x: 900, y: 900, width: 10, height: 10)).pixelRect(width: 400, height: 600)
                == CGRect(x: 0, y: 0, width: 400, height: 600))
    }

    @Test func aspectCropIsCentred() {
        #expect(CropSpec.aspect(.square).pixelRect(width: 600, height: 400) == CGRect(x: 100, y: 0, width: 400, height: 400))
        #expect(CropSpec.aspect(.sixteenNine).pixelRect(width: 1920, height: 1440) == CGRect(x: 0, y: 180, width: 1920, height: 1080))
        #expect(CropSpec.aspect(.free).pixelRect(width: 10, height: 20) == CGRect(x: 0, y: 0, width: 10, height: 20))
    }

    @Test func aspectPresetParsing() {
        #expect(AspectPreset(argument: "16:9") == .sixteenNine)
        #expect(AspectPreset(argument: "ORIGINAL") == .original)
        #expect(AspectPreset(argument: "7:3") == nil)
        #expect(!AspectPreset.batchPresets.contains(.free) && !AspectPreset.batchPresets.contains(.original))
    }

    @Test func editSummaryAndRotation() {
        var edit = ImageEdit(quarterTurns: -3, flipHorizontal: true, crop: .aspect(.square))
        #expect(edit.normalizedQuarterTurns == 1)
        #expect(edit.summary == "1:1 crop · rotated 90° · flipped")
        edit = ImageEdit()
        #expect(edit.isIdentity && edit.summary == nil)
        #expect(ImageGeometry.rotatedSize(CGSize(width: 3, height: 2), quarterTurns: 3) == CGSize(width: 2, height: 3))
    }
}
