import Foundation

/// Visit Codable values directly, without encoding and reparsing a complete
/// property list on every tick. Cached nodes reuse escaped field paths and array
/// indices; only block output and changed static content need serialization.
final class ReplayTimelineEncoder {
    fileprivate final class Node {
        let path: String
        var keys: [String] = []
        var count = 0
        var isArray = false
        var tick: Int64 = -1
        var children: [String: Node] = [:]
        var elements: [Node] = []
        var record: ((ReplayTimelineValue, Int64) -> Void)?
        init(_ path: String) { self.path = path }
        func child(_ key: String) -> Node {
            if let node = children[key] { return node }
            let node = Node(LevelReplayTimeline.child(path, key)); children[key] = node
            return node
        }
        func element(_ index: Int) -> Node {
            while elements.count <= index { elements.append(Node(LevelReplayTimeline.child(path, String(elements.count)))) }
            return elements[index]
        }
    }
    private let root = Node("")
    private let makeRecorder: (String) -> (ReplayTimelineValue, Int64) -> Void
    private var containers: [Node] = []
    private var tick: Int64 = -1
    private var tuning: [Int: TowerLevel]?
    private var tuningData: Data?
    private var paths: [Path]?
    private var pathsData: Data?
    private var rules: CombatRules?
    private var rulesData: Data?

    init(makeRecorder: @escaping (String) -> (ReplayTimelineValue, Int64) -> Void) { self.makeRecorder = makeRecorder }

    func append(_ frame: LevelReplayFrame) throws {
        tick = frame.tick
        containers.removeAll(keepingCapacity: true)
        try encode(frame, at: root)
        for node in containers {
            write(node.isArray ? .array(node.count) : .object(node.keys.sorted()), at: node)
        }
    }
    fileprivate func write(_ value: ReplayTimelineValue, at node: Node) {
        if node.record == nil { node.record = makeRecorder(node.path) }
        node.record!(value, tick)
    }
    fileprivate func begin(_ node: Node, array: Bool) {
        if node.tick != tick {
            node.tick = tick; node.keys.removeAll(keepingCapacity: true); node.count = 0
            node.isArray = array; containers.append(node)
        }
    }
    private func document<T: Encodable>(_ value: T) throws -> Data {
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        return try encoder.encode(value)
    }
    fileprivate func encode<T: Encodable>(_ value: T, at node: Node) throws {
        if node.path == "/towerTuning", let value = value as? [Int: TowerLevel] {
            if tuning != value { tuningData = try document(value); tuning = value }
            write(.document(tuningData!), at: node)
        } else if node.path == "/presentation/paths", let value = value as? [Path] {
            if paths != value { pathsData = try document(value); paths = value }
            write(.document(pathsData!), at: node)
        } else if let value = value as? CombatRules {
            // Every enemy carries these authored rules. Preserve the entire
            // document, but visit its fields only when the value changes.
            if rules != value { rulesData = try document(value); rules = value }
            write(.document(rulesData!), at: node)
        } else if let value = value as? Data {
            write(.bytes(value), at: node)
        } else {
            try value.encode(to: Visitor(owner: self, node: node))
        }
    }

    private struct Visitor: Encoder {
        let owner: ReplayTimelineEncoder
        let node: Node
        // Used only for diagnostics; paths are already cached on each node.
        var codingPath: [CodingKey] { [ReplayTimelineEncoder.Key(node.path)] }
        var userInfo: [CodingUserInfoKey: Any] { [:] }
        func container<K: CodingKey>(keyedBy: K.Type) -> KeyedEncodingContainer<K> {
            owner.begin(node, array: false)
            return KeyedEncodingContainer(Keyed<K>(owner: owner, node: node))
        }
        func unkeyedContainer() -> UnkeyedEncodingContainer {
            owner.begin(node, array: true)
            return Unkeyed(owner: owner, node: node)
        }
        func singleValueContainer() -> SingleValueEncodingContainer { Single(owner: owner, node: node) }
    }
    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { Int(stringValue) }
        init(_ value: String) { stringValue = value }
        init?(stringValue: String) { self.init(stringValue) }
        init?(intValue: Int) { self.init(String(intValue)) }
    }
    private struct Keyed<K: CodingKey>: KeyedEncodingContainerProtocol {
        let owner: ReplayTimelineEncoder
        let node: Node
        var codingPath: [CodingKey] { [ReplayTimelineEncoder.Key(node.path)] }
        private func child(_ key: K) -> Node {
            node.keys.append(key.stringValue)
            return node.child(key.stringValue)
        }
        mutating func encodeNil(forKey key: K) throws { owner.write(.null, at: child(key)) }
        mutating func encode<T: Encodable>(_ value: T, forKey key: K) throws { try owner.encode(value, at: child(key)) }
        mutating func encode(_ value: Bool, forKey key: K) throws { owner.write(.flag(value), at: child(key)) }
        mutating func encode(_ value: String, forKey key: K) throws { owner.write(.text(value), at: child(key)) }
        mutating func encode(_ value: Double, forKey key: K) throws { owner.write(.real(value), at: child(key)) }
        mutating func encode(_ value: Float, forKey key: K) throws { owner.write(.real(Double(value)), at: child(key)) }
        mutating func encode(_ value: Int, forKey key: K) throws { owner.write(.integer(Int64(value)), at: child(key)) }
        mutating func encode(_ value: Int8, forKey key: K) throws { owner.write(.integer(Int64(value)), at: child(key)) }
        mutating func encode(_ value: Int16, forKey key: K) throws { owner.write(.integer(Int64(value)), at: child(key)) }
        mutating func encode(_ value: Int32, forKey key: K) throws { owner.write(.integer(Int64(value)), at: child(key)) }
        mutating func encode(_ value: Int64, forKey key: K) throws { owner.write(.integer(Int64(value)), at: child(key)) }
        mutating func encode(_ value: UInt, forKey key: K) throws { owner.write(.unsigned(UInt64(value)), at: child(key)) }
        mutating func encode(_ value: UInt8, forKey key: K) throws { owner.write(.unsigned(UInt64(value)), at: child(key)) }
        mutating func encode(_ value: UInt16, forKey key: K) throws { owner.write(.unsigned(UInt64(value)), at: child(key)) }
        mutating func encode(_ value: UInt32, forKey key: K) throws { owner.write(.unsigned(UInt64(value)), at: child(key)) }
        mutating func encode(_ value: UInt64, forKey key: K) throws { owner.write(.unsigned(UInt64(value)), at: child(key)) }
        mutating func nestedContainer<N: CodingKey>(keyedBy: N.Type, forKey key: K) -> KeyedEncodingContainer<N> {
            Visitor(owner: owner, node: child(key)).container(keyedBy: N.self)
        }
        mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
            Visitor(owner: owner, node: child(key)).unkeyedContainer()
        }
        mutating func superEncoder() -> Encoder {
            node.keys.append("super"); return Visitor(owner: owner, node: node.child("super"))
        }
        mutating func superEncoder(forKey key: K) -> Encoder { Visitor(owner: owner, node: child(key)) }
    }
    private struct Unkeyed: UnkeyedEncodingContainer {
        let owner: ReplayTimelineEncoder
        let node: Node
        var codingPath: [CodingKey] { [ReplayTimelineEncoder.Key(node.path)] }
        var count: Int { node.count }
        private func child() -> Node {
            let child = node.element(node.count); node.count += 1
            return child
        }
        mutating func encodeNil() throws { owner.write(.null, at: child()) }
        mutating func encode<T: Encodable>(_ value: T) throws { try owner.encode(value, at: child()) }
        mutating func encode(_ value: Bool) throws { owner.write(.flag(value), at: child()) }
        mutating func encode(_ value: String) throws { owner.write(.text(value), at: child()) }
        mutating func encode(_ value: Double) throws { owner.write(.real(value), at: child()) }
        mutating func encode(_ value: Float) throws { owner.write(.real(Double(value)), at: child()) }
        mutating func encode(_ value: Int) throws { owner.write(.integer(Int64(value)), at: child()) }
        mutating func encode(_ value: Int8) throws { owner.write(.integer(Int64(value)), at: child()) }
        mutating func encode(_ value: Int16) throws { owner.write(.integer(Int64(value)), at: child()) }
        mutating func encode(_ value: Int32) throws { owner.write(.integer(Int64(value)), at: child()) }
        mutating func encode(_ value: Int64) throws { owner.write(.integer(Int64(value)), at: child()) }
        mutating func encode(_ value: UInt) throws { owner.write(.unsigned(UInt64(value)), at: child()) }
        mutating func encode(_ value: UInt8) throws { owner.write(.unsigned(UInt64(value)), at: child()) }
        mutating func encode(_ value: UInt16) throws { owner.write(.unsigned(UInt64(value)), at: child()) }
        mutating func encode(_ value: UInt32) throws { owner.write(.unsigned(UInt64(value)), at: child()) }
        mutating func encode(_ value: UInt64) throws { owner.write(.unsigned(UInt64(value)), at: child()) }
        mutating func nestedContainer<N: CodingKey>(keyedBy: N.Type) -> KeyedEncodingContainer<N> {
            Visitor(owner: owner, node: child()).container(keyedBy: N.self)
        }
        mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            Visitor(owner: owner, node: child()).unkeyedContainer()
        }
        mutating func superEncoder() -> Encoder { Visitor(owner: owner, node: child()) }
    }
    private struct Single: SingleValueEncodingContainer {
        let owner: ReplayTimelineEncoder
        let node: Node
        var codingPath: [CodingKey] { [ReplayTimelineEncoder.Key(node.path)] }
        func encodeNil() throws { owner.write(.null, at: node) }
        func encode<T: Encodable>(_ value: T) throws { try owner.encode(value, at: node) }
        func encode(_ value: Bool) throws { owner.write(.flag(value), at: node) }
        func encode(_ value: String) throws { owner.write(.text(value), at: node) }
        func encode(_ value: Double) throws { owner.write(.real(value), at: node) }
        func encode(_ value: Float) throws { owner.write(.real(Double(value)), at: node) }
        func encode(_ value: Int) throws { owner.write(.integer(Int64(value)), at: node) }
        func encode(_ value: Int8) throws { owner.write(.integer(Int64(value)), at: node) }
        func encode(_ value: Int16) throws { owner.write(.integer(Int64(value)), at: node) }
        func encode(_ value: Int32) throws { owner.write(.integer(Int64(value)), at: node) }
        func encode(_ value: Int64) throws { owner.write(.integer(Int64(value)), at: node) }
        func encode(_ value: UInt) throws { owner.write(.unsigned(UInt64(value)), at: node) }
        func encode(_ value: UInt8) throws { owner.write(.unsigned(UInt64(value)), at: node) }
        func encode(_ value: UInt16) throws { owner.write(.unsigned(UInt64(value)), at: node) }
        func encode(_ value: UInt32) throws { owner.write(.unsigned(UInt64(value)), at: node) }
        func encode(_ value: UInt64) throws { owner.write(.unsigned(UInt64(value)), at: node) }
    }
}
