import Foundation
import SwiftData

enum FeedingType: String, Codable, CaseIterable, Identifiable {
    case leftBreast
    case rightBreast
    case bottle
    case formula

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leftBreast: "左侧母乳"
        case .rightBreast: "右侧母乳"
        case .bottle: "瓶喂"
        case .formula: "奶粉"
        }
    }
}

@Model
final class FeedingRecord {
    var startedAt: Date
    var endedAt: Date?
    var feedingTypeRawValue: String
    var amountML: Double?
    var note: String

    init(
        startedAt: Date,
        endedAt: Date? = nil,
        feedingType: FeedingType,
        amountML: Double? = nil,
        note: String = ""
    ) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.feedingTypeRawValue = feedingType.rawValue
        self.amountML = amountML
        self.note = note
    }

    var feedingType: FeedingType {
        get { FeedingType(rawValue: feedingTypeRawValue) ?? .leftBreast }
        set { feedingTypeRawValue = newValue.rawValue }
    }

    var durationMinutes: Int? {
        guard let endedAt else { return nil }
        return max(Int(endedAt.timeIntervalSince(startedAt) / 60), 0)
    }
}
