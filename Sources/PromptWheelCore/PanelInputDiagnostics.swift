/// Event type, observation stage, and view-label counters only; no user content or coordinates.
public struct PanelInputEventKey: Hashable, Sendable {
    public let eventType: String
    public let stage: String
    public let view: String
    public let windowMatches: Bool

    public init(eventType: String, stage: String, view: String, windowMatches: Bool) {
        self.eventType = eventType
        self.stage = stage
        self.view = view
        self.windowMatches = windowMatches
    }
}

public struct PanelInputEventCount: Equatable, Sendable {
    public let key: PanelInputEventKey
    public let count: Int
}

/// In-memory tally for one app panel lifetime. It is never written to disk.
public struct PanelInputEventTally: Sendable {
    private var counts: [PanelInputEventKey: Int] = [:]

    public init() {}

    public mutating func record(eventType: String, stage: String, view: String, windowMatches: Bool) {
        let key = PanelInputEventKey(eventType: eventType, stage: stage, view: view,
                                     windowMatches: windowMatches)
        counts[key, default: 0] += 1
    }

    public var entries: [PanelInputEventCount] {
        counts.map { PanelInputEventCount(key: $0.key, count: $0.value) }
            .sorted {
                if $0.key.eventType != $1.key.eventType { return $0.key.eventType < $1.key.eventType }
                if $0.key.stage != $1.key.stage { return $0.key.stage < $1.key.stage }
                if $0.key.view != $1.key.view { return $0.key.view < $1.key.view }
                return !$0.key.windowMatches && $1.key.windowMatches
            }
    }
}
