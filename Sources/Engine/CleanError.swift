import Foundation

/// A user-presentable error from the cleaning/merging engine.
struct CleanError: Error, CustomStringConvertible, Sendable {
    let description: String
    init(_ description: String) { self.description = description }
}
