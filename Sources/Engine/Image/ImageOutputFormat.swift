import Foundation

/// Whether image outputs keep their original container or are converted to JPEG.
enum ImageOutputFormat: String, CaseIterable, Identifiable, Sendable {
    case original, jpeg

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .original: "Keep Original Format"
        case .jpeg: "Convert to JPEG"
        }
    }
}
