import CoreGraphics
import Testing
@testable import MetadataRemoverLogic

struct CropRectMathTests {
    @Test func defaultRectIsLargestCentredRect() {
        #expect(CropRectMath.defaultRect(normalizedRatio: nil) == CropRectMath.full)
        let wide = CropRectMath.defaultRect(normalizedRatio: 2)
        #expect(wide == CGRect(x: 0, y: 0.25, width: 1, height: 0.5))
        let tall = CropRectMath.defaultRect(normalizedRatio: 0.5)
        #expect(tall == CGRect(x: 0.25, y: 0, width: 0.5, height: 1))
    }

    @Test func normalizedRatioAccountsForImageShape() {
        // A 16:9 crop of a 1600×900 image fills it exactly, i.e. 1:1 in normalised units.
        let r = CropRectMath.normalizedRatio(16.0 / 9.0, imageSize: CGSize(width: 1600, height: 900))
        #expect(abs((r ?? 0) - 1) < 1e-9)
        #expect(CropRectMath.normalizedRatio(nil, imageSize: CGSize(width: 10, height: 10)) == nil)
        #expect(CropRectMath.normalizedRatio(1, imageSize: .zero) == nil)
    }

    @Test func movingStaysInsideTheImage() {
        let rect = CGRect(x: 0.5, y: 0.5, width: 0.4, height: 0.4)
        let moved = CropRectMath.moved(rect, by: CGSize(width: 1, height: -1))
        #expect(moved == CGRect(x: 0.6, y: 0, width: 0.4, height: 0.4))
    }

    @Test(arguments: CropRectMath.Corner.allCases)
    func resizingKeepsOppositeCornerAndBounds(corner: CropRectMath.Corner) {
        let rect = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        let resized = CropRectMath.resized(rect, corner: corner, to: CGPoint(x: -5, y: 5), normalizedRatio: nil)
        #expect(resized.minX >= 0 && resized.minY >= 0 && resized.maxX <= 1 + 1e-9 && resized.maxY <= 1 + 1e-9)
        #expect(resized.width >= CropRectMath.minimumSide && resized.height >= CropRectMath.minimumSide)
    }

    @Test func resizingHonoursTheRatio() {
        let rect = CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
        let resized = CropRectMath.resized(rect, corner: .bottomRight, to: CGPoint(x: 0.9, y: 0.3), normalizedRatio: 2)
        #expect(abs(resized.width / resized.height - 2) < 1e-9)
        #expect(resized.origin == rect.origin)
    }

    @Test func approximateEquality() {
        #expect(CropRectMath.isApproximatelyEqual(CGRect(x: 0, y: 0, width: 1, height: 1), CGRect(x: 0.0005, y: 0, width: 1, height: 0.9995)))
        #expect(!CropRectMath.isApproximatelyEqual(CGRect(x: 0, y: 0, width: 1, height: 1), CGRect(x: 0.01, y: 0, width: 1, height: 1)))
    }
}
