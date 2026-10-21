import SwiftUI

/// The editor's image with the crop overlay, fitted to the available space.
struct CropCanvas: View {
    let preview: ImagePreviewLoader.Preview?
    let didFailToLoad: Bool
    @Binding var rect: CGRect
    let normalizedRatio: Double?

    var body: some View {
        if let preview {
            // GeometryReader is needed here: the overlay's drag maths works in the fitted image's on-screen size.
            GeometryReader { proxy in
                let fitted = Self.fittedSize(preview.uprightSize, in: proxy.size)
                ZStack {
                    Image(decorative: preview.image, scale: 1)
                        .resizable()
                        .frame(width: fitted.width, height: fitted.height)
                    CropOverlay(rect: $rect, size: fitted, normalizedRatio: normalizedRatio)
                        .frame(width: fitted.width, height: fitted.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(Layout.cardPadding * 2)
        } else if didFailToLoad {
            ContentUnavailableView("Can’t Preview Image", systemImage: "exclamationmark.triangle",
                                   description: Text("This image can’t be shown for cropping."))
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private static func fittedSize(_ size: CGSize, in bounds: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
