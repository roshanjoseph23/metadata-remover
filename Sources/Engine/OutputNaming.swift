import Foundation

/// Random, collision-free output names that share nothing with the input file name.
enum OutputNaming {
    /// 12 random lowercase alphanumerics from the system CSPRNG.
    static func randomName(length: Int = 12) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in alphabet[Int.random(in: 0..<alphabet.count, using: &generator)] })
    }

    static func newURL(in directory: URL, fileExtension: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var url: URL
        repeat { url = directory.appending(path: randomName()).appendingPathExtension(fileExtension) }
        while FileManager.default.fileExists(atPath: url.path)
        return url
    }
}
