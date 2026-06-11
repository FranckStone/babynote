import Foundation

enum InactivityDimDelay: Int, CaseIterable, Identifiable {
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .oneMinute:
            return "1分钟"
        case .fiveMinutes:
            return "5分钟"
        case .fifteenMinutes:
            return "15分钟"
        }
    }

    static func value(for rawValue: Int) -> InactivityDimDelay {
        InactivityDimDelay(rawValue: rawValue) ?? .fiveMinutes
    }
}
