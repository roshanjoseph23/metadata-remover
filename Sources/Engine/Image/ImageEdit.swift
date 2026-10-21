/// User edits applied before encoding: quarter-turn rotation (clockwise), horizontal flip, then crop.
struct ImageEdit: Equatable, Sendable {
    var quarterTurns = 0
    var flipHorizontal = false
    var crop: CropSpec?

    var normalizedQuarterTurns: Int { ((quarterTurns % 4) + 4) % 4 }
    var isIdentity: Bool { normalizedQuarterTurns == 0 && !flipHorizontal && crop == nil }

    /// Short description for list rows, e.g. "16:9 crop · rotated".
    var summary: String? {
        var parts: [String] = []
        switch crop {
        case .aspect(let preset): parts.append("\(preset.title) crop")
        case .normalized, .pixels: parts.append("Custom crop")
        case nil: break
        }
        if normalizedQuarterTurns != 0 { parts.append("rotated \(normalizedQuarterTurns * 90)°") }
        if flipHorizontal { parts.append("flipped") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
