import SwiftUI

/// Dimmed surround, crop border, rule-of-thirds guides and draggable corner handles.
struct CropOverlay: View {
    @Binding var rect: CGRect          // normalised, top-left origin
    let size: CGSize                   // on-screen image size
    let normalizedRatio: Double?

    @State private var moveStart: CGRect?

    var body: some View {
        let frame = CGRect(x: rect.minX * size.width, y: rect.minY * size.height,
                           width: rect.width * size.width, height: rect.height * size.height)
        ZStack(alignment: .topLeading) {
            CropDimming(size: size, cropFrame: frame)
            Rectangle()
                .strokeBorder(.white, lineWidth: 1.5)
                .background { CropGuides() }
                .contentShape(.rect)
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                .gesture(moveGesture)
                .accessibilityLabel("Crop area")
                .accessibilityValue("\(Double(rect.width).formatted(.percent.precision(.fractionLength(0)))) wide, \(Double(rect.height).formatted(.percent.precision(.fractionLength(0)))) high")
                .accessibilityHint("Drag to move the crop. Choose an aspect preset to resize it.")
            ForEach(CropRectMath.Corner.allCases, id: \.self) { corner in
                CropHandle()
                    .position(position(of: corner, in: frame))
                    .gesture(resizeGesture(corner))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .coordinateSpace(.named(Self.space))
    }

    private static let space = "crop"

    private func position(of corner: CropRectMath.Corner, in frame: CGRect) -> CGPoint {
        switch corner {
        case .topLeft: CGPoint(x: frame.minX, y: frame.minY)
        case .topRight: CGPoint(x: frame.maxX, y: frame.minY)
        case .bottomLeft: CGPoint(x: frame.minX, y: frame.maxY)
        case .bottomRight: CGPoint(x: frame.maxX, y: frame.maxY)
        }
    }

    private var moveGesture: some Gesture {
        DragGesture(coordinateSpace: .named(Self.space))
            .onChanged { value in
                let start = moveStart ?? rect
                moveStart = start
                rect = CropRectMath.moved(start, by: CGSize(width: value.translation.width / size.width,
                                                            height: value.translation.height / size.height))
            }
            .onEnded { _ in moveStart = nil }
    }

    private func resizeGesture(_ corner: CropRectMath.Corner) -> some Gesture {
        DragGesture(coordinateSpace: .named(Self.space))
            .onChanged { value in
                let point = CGPoint(x: value.location.x / size.width, y: value.location.y / size.height)
                rect = CropRectMath.resized(rect, corner: corner, to: point, normalizedRatio: normalizedRatio)
            }
    }
}
