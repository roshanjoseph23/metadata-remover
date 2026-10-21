// swift-tools-version: 6.0
// Unit tests for the app's pure logic. The app itself is built by build.sh, which ignores this file;
// run the tests with `swift test` (add --scratch-path to keep build products out of the repo).
import Foundation
import PackageDescription

/// The pure-logic files under test; the rest of Sources (UI, engine glue) is excluded.
let logicSources = [
    "Model/Images/CropRectMath.swift",
    "Engine/Image/AspectPreset.swift",
    "Engine/Image/CropSpec.swift",
    "Engine/Image/ImageEdit.swift",
    "Engine/Image/ImageGeometry.swift",
    "Engine/Image/ColorSpaceStandardizer.swift",
    "Engine/Image/ContainerSanitizer.swift",
    "Engine/OutputNaming.swift",
]
let sourcesRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Sources")
let otherSources = (FileManager.default.subpaths(atPath: sourcesRoot.path) ?? [])
    .filter { $0.hasSuffix(".swift") && !logicSources.contains($0) }

let package = Package(
    name: "MetadataRemoverLogic",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "MetadataRemoverLogic",
            path: "Sources",
            exclude: otherSources,
            sources: logicSources
        ),
        .testTarget(name: "LogicTests", dependencies: ["MetadataRemoverLogic"], path: "Tests/LogicTests"),
    ]
)
