import Foundation

enum RecordType: String, CaseIterable, Identifiable {
    case feeding
    case weight
    case medication
    case checkup
    case fetalMovement

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .feeding: "喂奶"
        case .weight: "体重"
        case .medication: "药物"
        case .checkup: "检查"
        case .fetalMovement: "胎动"
        }
    }

    var symbol: String {
        switch self {
        case .feeding: "drop.fill"
        case .weight: "scalemass.fill"
        case .medication: "pills.fill"
        case .checkup: "cross.case.fill"
        case .fetalMovement: "figure.and.child.holdinghands"
        }
    }
}
