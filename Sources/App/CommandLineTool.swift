import Foundation

/// Hidden headless mode used for testing and scripting:
/// `MetadataRemover --cli [--reencode] [--merge] [--print-args] [--out DIR] FILES…`
/// `MetadataRemover --cli --images …` — see `ImageCommandLineTool`.
enum CommandLineTool {
    static func run(_ arguments: [String]) async -> Int32 {
        if arguments.first == "--images" { return await ImageCommandLineTool.run(Array(arguments.dropFirst())) }
        var reencode = false, printArgs = false, merge = false
        var cancelAfter: Double?
        var outputDirectory = await AppModelDefaults.outputDirectory
        var inputs: [URL] = []
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--reencode": reencode = true
            case "--print-args": printArgs = true
            case "--merge": merge = true
            case "--cancel-after": cancelAfter = iterator.next().flatMap(Double.init)
            case "--out":
                if let path = iterator.next() { outputDirectory = URL(filePath: path, directoryHint: .isDirectory) }
            default: inputs.append(URL(filePath: argument))
            }
        }

        let engine: VideoCleaner
        do {
            engine = try await VideoCleaner.locate()
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            return 2
        }

        if let cancelAfter {
            // Test hook: start the job, cancel it after N seconds, and report what was left behind.
            let job = Task { () -> String in
                if merge {
                    return try await engine.merge(inputs, outputDirectory: outputDirectory, forceReencode: reencode,
                                                  onPlan: { _ in }, progress: { _ in }).output.path
                }
                return try await engine.clean(inputs[0], outputDirectory: outputDirectory, reencode: reencode) { _ in }.path
            }
            try? await Task.sleep(for: .seconds(cancelAfter))
            job.cancel()
            switch await job.result {
            case .success(let path): print("FINISHED-BEFORE-CANCEL\t\(path)"); return 0
            case .failure(let error): print(error is CancellationError ? "CANCELLED" : "FAIL\t\(error)"); return error is CancellationError ? 0 : 1
            }
        }

        if merge {
            if printArgs {
                print("ARGS\t" + (await engine.mergeCommandPreview(inputs, outputDirectory: outputDirectory, forceReencode: reencode)))
            }
            do {
                let result = try await engine.merge(inputs, outputDirectory: outputDirectory, forceReencode: reencode,
                                                    onPlan: { print("PLAN\t\($0)") }, progress: { _ in })
                print("MERGED\t\(result.output.path)")
                return 0
            } catch {
                print("FAIL\t\(error)")
                return 1
            }
        }

        var failures: Int32 = 0
        for input in inputs {
            do {
                if printArgs, let info = try? await engine.probe(input) {
                    let container = OutputContainer.choose(for: input, info: info, reencode: reencode)
                    let placeholder = outputDirectory.appending(path: "RANDOM.\(container.fileExtension)")
                    print("ARGS\t" + CommandFormatter.shellQuoted([engine.ffmpeg] + engine.cleanArguments(
                        input: input, output: placeholder, info: info, reencode: reencode)))
                }
                let output = try await engine.clean(input, outputDirectory: outputDirectory, reencode: reencode) { _ in }
                print("OK\t\(input.path)\t\(output.path)")
            } catch {
                failures += 1
                print("FAIL\t\(input.path)\t\(error)")
            }
        }
        return failures == 0 ? 0 : 1
    }
}
