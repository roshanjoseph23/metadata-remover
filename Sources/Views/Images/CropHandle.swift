import SwiftUI

struct CropHandle: View {
    var body: some View {
        Circle()
            .fill(.white)
            .overlay { Circle().strokeBorder(.black.opacity(0.3), lineWidth: 1) }
            .frame(width: Layout.cropHandleSide, height: Layout.cropHandleSide)
            .shadow(radius: 1)
            .contentShape(.rect.inset(by: -8))
            .accessibilityHidden(true)
    }
}
