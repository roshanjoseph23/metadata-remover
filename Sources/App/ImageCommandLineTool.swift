import Foundation

/// Headless image mode for testing and scripting:
/// `MetadataRemover --cli --images [--format original|jpeg] [--quality Q] [--rotate N] [--flip] [--no-hdr]
///  [--crop X,Y,W,H | --crop-norm X,Y,W,H | --aspect 16:9] --out DIR FILES…`
/// Rect values use a top-left origin in the upright image (after rotate/flip). Prints `OK\tIN\tOUT` or `FAIL\tIN\tERROR`.
enum ImageCommandLineTool {
    static func run(_ arguments: [String]) async -> Int32 {
        var format = ImageOutputFormat.jpeg
        var quality = ImageCleaner.defaultQuality
        var edit = ImageEdit()
        var keepHDR = true
        var outputDirectory = ImageModel.defaultOutputDirectory
        var inputs: [URL] = []
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--format":
                guard let value = iterator.next().flatMap(ImageOutputFormat.init(rawValue:)) else { return usage("--format original|jpeg") }
                format = value
            case "--quality":
                guard let value = iterator.next().flatMap(Double.init), (0...1).contains(value) else { return usage("--quality 0…1") }
                quality = value
            case "--rotate":
                guard let value = iterator.next().flatMap(Int.init) else { return usage("--rotate N (quarter turns clockwise)") }
                edit.quarterTurns = value
            case "--flip": edit.flipHorizontal = true
            case "--no-hdr": keepHDR = false
            case "--crop", "--crop-norm":
                guard let rect = iterator.next().flatMap(parseRect) else { return usage("\(argument) X,Y,W,H") }
                edit.crop = argument == "--crop" ? .pixels(rect) : .normalized(rect)
            case "--aspect":
                guard let preset = iterator.next().flatMap(AspectPreset.init(argument:)) else { return usage("--aspect 1:1|4:3|3:2|16:9|9:16|4:5|original|free") }
                edit.crop = preset == .free ? nil : .aspect(preset)
            case "--out":
                guard let path = iterator.next() else { return usage("--out DIR") }
                outputDirectory = URL(filePath: path, directoryHint: .isDirectory)
            default: inputs.append(URL(filePath: argument))
            }
        }

        var failures: Int32 = 0
        for input in inputs {
            do {
                let output = try await ImageCleaner.clean(input, outputDirectory: outputDirectory, format: format,
                                                          quality: quality, keepHDR: keepHDR, edit: edit)
                print("OK\t\(input.path)\t\(output.path)")
            } catch {
                failures += 1
                print("FAIL\t\(input.path)\t\(error)")
            }
        }
        return failures == 0 ? 0 : 1
    }

    private static func parseRect(_ text: String) -> CGRect? {
        let values = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard values.count == 4 else { return nil }
        return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }

    private static func usage(_ hint: String) -> Int32 {
        FileHandle.standardError.write(Data("usage: \(hint)\n".utf8))
        return 64
    }
}
