import Foundation

/// Live presentations in the order they opened. A new presentation owns a
/// fresh layer above all existing entries; removing it also removes its views.
public struct PresentationStack<Content: Equatable> {
    public struct Entry: Identifiable {
        public let id = UUID()
        public let content: Content
    }

    public private(set) var entries: [Entry] = []

    public init() {}

    /// Keep existing layers in place as their displayed data refreshes. Only
    /// newly active presentations are appended; no category has a fixed depth.
    public mutating func synchronize(_ active: [Content]) {
        entries.removeAll { !active.contains($0.content) }
        for content in active where !entries.contains(where: { $0.content == content }) {
            entries.append(Entry(content: content))
        }
    }

    public mutating func removeAll() {
        entries.removeAll()
    }
}
