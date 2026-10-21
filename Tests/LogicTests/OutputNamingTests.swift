import Foundation
import Testing
@testable import MetadataRemoverLogic

struct OutputNamingTests {
    @Test func namesAreRandomLowercaseAlphanumerics() {
        let names = (0..<2000).map { _ in OutputNaming.randomName() }
        #expect(names.allSatisfy { $0.count == 12 && $0.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber) } })
        #expect(Set(names).count == names.count)
        #expect(OutputNaming.randomName(length: 5).count == 5)
    }

    @Test func newURLCreatesTheFolderAndNeverReusesAName() throws {
        let folder = URL.temporaryDirectory.appending(path: "mr-naming-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = try OutputNaming.newURL(in: folder, fileExtension: "jpg")
        #expect(FileManager.default.fileExists(atPath: folder.path))
        #expect(first.pathExtension == "jpg" && first.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL)
        try Data().write(to: first)
        let second = try OutputNaming.newURL(in: folder, fileExtension: "jpg")
        #expect(second != first)
    }
}
