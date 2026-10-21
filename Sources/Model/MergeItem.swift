import Foundation

struct MergeItem: Identifiable, Equatable, Sendable {
    let id = UUID()
    let url: URL
}
