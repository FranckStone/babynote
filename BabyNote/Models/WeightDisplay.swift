import Foundation

enum WeightDisplay {
    private static let jinPerKG = 2.0

    static func kgToJin(_ kg: Double) -> Double {
        kg * jinPerKG
    }

    static func jinToKG(_ jin: Double) -> Double {
        jin / jinPerKG
    }

    static func jinText(fromKG kg: Double) -> String {
        String(format: "%.1f 斤", kgToJin(kg))
    }
}
