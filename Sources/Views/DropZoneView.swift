import SwiftUI
import UniformTypeIdentifiers

/// Material-backed drop target with a Choose… button.
struct DropZoneView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let buttonTitle: String
    let panelMessage: String
    let contentTypes: [UTType]
    let onAdd: ([URL]) -> Void
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: Layout.rowSpacing) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3)
                .bold()
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(buttonTitle, action: choose)
                .buttonStyle(.borderedProminent)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, minHeight: Layout.dropZoneHeight)
        .background(.regularMaterial, in: .rect(cornerRadius: Layout.dropZoneCornerRadius))
        .background(Color.accentColor.opacity(isTargeted ? 0.12 : 0), in: .rect(cornerRadius: Layout.dropZoneCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.dropZoneCornerRadius)
                .strokeBorder(isTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary),
                              style: StrokeStyle(lineWidth: 2, dash: [8]))
        }
        .dropDestination(for: URL.self) { urls, _ in
            onAdd(urls)
            return true
        } isTargeted: { isTargeted = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drop zone: \(title)")
    }

    private func choose() {
        onAdd(FilePanels.chooseFiles(message: panelMessage, contentTypes: contentTypes))
    }
}
