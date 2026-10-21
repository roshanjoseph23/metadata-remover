import CoreGraphics

/// Maps a source colour space to a standard Apple/ColorSync colour space so the output embeds Apple's
/// standard profile rather than the source's ICC (which may carry device or user strings).
///
/// - Standard spaces (by name, or by matching colourimetry) are kept as that standard space.
/// - Anything else is converted to the nearest standard space that holds its whole gamut
///   (Display P3, then Rec. 2020, then ProPhoto/ROMM), so nothing is clipped.
enum ColorSpaceStandardizer {
    struct Result: Sendable {
        let colorSpace: CGColorSpace
        /// True when the source already uses this colourimetry, so pixels can be retagged without conversion.
        let isExactMatch: Bool
    }

    private static var rgbNames: [CFString] { [
        CGColorSpace.sRGB, CGColorSpace.displayP3, CGColorSpace.adobeRGB1998, CGColorSpace.rommrgb,
        CGColorSpace.itur_2020, CGColorSpace.itur_709, CGColorSpace.dcip3, CGColorSpace.acescgLinear,
        CGColorSpace.itur_2100_PQ, CGColorSpace.itur_2100_HLG, CGColorSpace.displayP3_PQ, CGColorSpace.displayP3_HLG,
        CGColorSpace.linearSRGB, CGColorSpace.linearDisplayP3, CGColorSpace.linearITUR_2020,
        CGColorSpace.extendedSRGB, CGColorSpace.extendedLinearSRGB, CGColorSpace.extendedDisplayP3,
        CGColorSpace.extendedLinearDisplayP3, CGColorSpace.extendedITUR_2020, CGColorSpace.extendedLinearITUR_2020,
        CGColorSpace.genericRGBLinear,
    ] }
    private static var grayNames: [CFString] { [
        CGColorSpace.genericGrayGamma2_2, CGColorSpace.linearGray, CGColorSpace.extendedGray, CGColorSpace.extendedLinearGray,
    ] }

    static func standardize(_ source: CGColorSpace?) -> Result {
        guard let source else { return Result(colorSpace: named(CGColorSpace.sRGB), isExactMatch: false) }
        if let name = source.name, rgbNames.contains(name) || grayNames.contains(name), let standard = CGColorSpace(name: name) {
            return Result(colorSpace: standard, isExactMatch: true)
        }
        switch source.model {
        case .rgb:
            if let match = rgbNames.lazy.compactMap(CGColorSpace.init(name:)).first(where: { matches(source, $0, probes: rgbProbes) }) {
                return Result(colorSpace: match, isExactMatch: true)
            }
            return Result(colorSpace: nearestContaining(source, probes: rgbProbes), isExactMatch: false)
        case .monochrome:
            if let match = grayNames.lazy.compactMap(CGColorSpace.init(name:)).first(where: { matches(source, $0, probes: grayProbes) }) {
                return Result(colorSpace: match, isExactMatch: true)
            }
            return Result(colorSpace: named(CGColorSpace.genericGrayGamma2_2), isExactMatch: false)
        case .cmyk:
            return Result(colorSpace: nearestContaining(source, probes: cmykProbes), isExactMatch: false)
        default:   // Lab, indexed, etc.
            return Result(colorSpace: nearestContaining(source, probes: nil), isExactMatch: false)
        }
    }

    static func isHDR(_ colorSpace: CGColorSpace?) -> Bool {
        guard let colorSpace else { return false }
        return CGColorSpaceUsesITUR_2100TF(colorSpace)
    }

    // MARK: Matching

    private static let rgbProbes: [[CGFloat]] = [
        [1, 0, 0], [0, 1, 0], [0, 0, 1], [1, 1, 1], [0.5, 0.5, 0.5], [0.18, 0.18, 0.18],
        [0.25, 0.75, 0.5], [0.9, 0.2, 0.6], [0.05, 0.1, 0.02], [1, 1, 0], [0, 1, 1], [1, 0, 1],
    ]
    private static let grayProbes: [[CGFloat]] = [[0], [0.05], [0.18], [0.5], [0.8], [1]]
    private static let cmykProbes: [[CGFloat]] = [
        [1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [1, 1, 0, 0], [0, 1, 1, 0], [1, 0, 1, 0], [0, 0, 0, 0],
    ]

    private static func named(_ name: CFString) -> CGColorSpace {
        CGColorSpace(name: name) ?? CGColorSpaceCreateDeviceRGB()
    }

    /// Same colourimetry: probe colours land in the same place in a common linear space.
    private static func matches(_ a: CGColorSpace, _ b: CGColorSpace, probes: [[CGFloat]]) -> Bool {
        guard a.numberOfComponents == b.numberOfComponents, let reference = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) else { return false }
        for probe in probes {
            guard let ca = convert(probe, from: a, to: reference), let cb = convert(probe, from: b, to: reference) else { return false }
            for (x, y) in zip(ca, cb) where abs(x - y) > 0.002 * max(1, abs(x)) { return false }
        }
        return true
    }

    /// Smallest standard gamut (P3 → Rec. 2020 → ProPhoto) that contains every probe colour.
    private static func nearestContaining(_ source: CGColorSpace, probes: [[CGFloat]]?) -> CGColorSpace {
        let candidates: [(CFString, CFString)] = [
            (CGColorSpace.displayP3, CGColorSpace.extendedLinearDisplayP3),
            (CGColorSpace.itur_2020, CGColorSpace.extendedLinearITUR_2020),
        ]
        guard let probes else { return named(CGColorSpace.rommrgb) }
        for (standard, linear) in candidates {
            guard let linearSpace = CGColorSpace(name: linear) else { continue }
            let fits = probes.allSatisfy { probe in
                guard let converted = convert(probe, from: source, to: linearSpace) else { return false }
                return converted.prefix(3).allSatisfy { (-0.002...1.002).contains($0) }
            }
            if fits { return named(standard) }
        }
        return named(CGColorSpace.rommrgb)
    }

    private static func convert(_ components: [CGFloat], from source: CGColorSpace, to target: CGColorSpace) -> [CGFloat]? {
        var values = components + [1]
        guard let color = CGColor(colorSpace: source, components: &values),
              let converted = color.converted(to: target, intent: .relativeColorimetric, options: nil),
              let result = converted.components else { return nil }
        return Array(result.dropLast())
    }
}
