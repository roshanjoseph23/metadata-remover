import Foundation

/// Removes file-system level metadata that could identify the machine (xattrs such as
/// com.apple.provenance, quarantine, kMDItemWhereFroms) and resets dates to "now".
enum FileScrubber {
    static func scrub(_ url: URL) {
        let path = url.path
        let size = listxattr(path, nil, 0, XATTR_NOFOLLOW)
        if size > 0 {
            var buffer = [CChar](repeating: 0, count: size)
            let length = listxattr(path, &buffer, size, XATTR_NOFOLLOW)
            if length > 0 {
                let names = buffer[0..<length]
                    .split(separator: 0)
                    .map { String(decoding: $0.map { UInt8(bitPattern: $0) }, as: UTF8.self) }
                for name in names { removexattr(path, name, XATTR_NOFOLLOW) }
            }
        }
        let now = Date.now
        try? FileManager.default.setAttributes(
            [.creationDate: now, .modificationDate: now, .posixPermissions: 0o644],
            ofItemAtPath: path
        )
    }
}
