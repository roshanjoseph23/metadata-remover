import Foundation

/// Renders an argument list as a copy-pasteable shell command (debug output only).
enum CommandFormatter {
    static func shellQuoted(_ arguments: [String]) -> String {
        let special: Set<Character> = [" ", "?", "|", "[", ";", "'", "\""]
        return arguments.map { arg in
            arg.contains(where: special.contains) ? "'" + arg.replacing("'", with: "'\\''") + "'" : arg
        }.joined(separator: " ")
    }
}
