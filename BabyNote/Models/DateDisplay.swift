import Foundation

enum DateDisplay {
    private static let locale = Locale(identifier: "zh_CN")

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    static func dateTime(_ date: Date) -> String {
        "\(shortDate(date)) \(dayPeriodTime(date))"
    }

    static func time(_ date: Date) -> String {
        dayPeriodTime(date)
    }

    private static func dayPeriodTime(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let minuteFormatter = DateFormatter()
        minuteFormatter.locale = locale
        minuteFormatter.dateFormat = "H:mm"

        let period: String
        switch hour {
        case 7..<12:
            period = "上午"
        case 12..<19:
            period = "下午"
        default:
            period = "晚上"
        }

        return "\(period) \(minuteFormatter.string(from: date))"
    }
}
