import Foundation

struct ProcessResult: Sendable {
    let status: Int32
    let stdout: String
    let stderr: String

    /// The last few stderr lines, for compact error messages.
    func stderrTail(_ lines: Int) -> String {
        stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n")
            .suffix(lines)
            .joined(separator: " ")
    }
}
