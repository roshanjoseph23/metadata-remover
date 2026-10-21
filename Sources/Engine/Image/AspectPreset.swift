import Foundation

/// Crop aspect-ratio presets offered in the crop editor and for batch centre crops.
enum AspectPreset: String, CaseIterable, Identifiable, Sendable {
    case free, original, square, fourThree, threeTwo, sixteenNine, nineSixteen, fourFive

    var id: Self { self }

    var title: String {
        switch self {
        case .free: "Free"
        case .original: "Original"
        case .square: "1:1"
        case .fourThree: "4:3"
        case .threeTwo: "3:2"
        case .sixteenNine: "16:9"
        case .nineSixteen: "9:16"
        case .fourFive: "4:5"
        }
    }

    /// Presets offered by "Crop All To" (a fixed ratio; Free and Original don't crop a batch).
    static let batchPresets = allCases.filter { $0 != .free && $0 != .original }

    /// Width ÷ height, or `nil` for an unconstrained crop.
    func ratio(width: Double, height: Double) -> Double? {
        switch self {
        case .free: nil
        case .original: height > 0 ? width / height : nil
        case .square: 1
        case .fourThree: 4.0 / 3.0
        case .threeTwo: 3.0 / 2.0
        case .sixteenNine: 16.0 / 9.0
        case .nineSixteen: 9.0 / 16.0
        case .fourFive: 4.0 / 5.0
        }
    }

    /// Parses CLI values such as "16:9", "1:1", "free", "original".
    init?(argument: String) {
        guard let match = Self.allCases.first(where: {
            $0.title.lowercased() == argument.lowercased() || $0.rawValue.lowercased() == argument.lowercased()
        }) else { return nil }
        self = match
    }
}
