import SwiftUI

/// Darkens everything outside the crop rectangle.
struct CropDimming: View {
    let size: CGSize
    let cropFrame: CGRect

    var body: some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            path.addRect(cropFrame)
        }
        .fill(.black.opacity(0.5), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }
}
