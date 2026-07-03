import Foundation

enum DateDisplay {
    private static let locale = Locale(identifier: "zh_CN")

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let minuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "H:mm"
        return formatter
    }()

    private static let clockTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    static func dateTime(_ date: Date) -> String {
        "\(shortDate(date)) \(dayPeriodTime(date))"
    }

    static func time(_ date: Date) -> String {
        dayPeriodTime(date)
    }

    static func clockTime(_ date: Date) -> String {
        clockTimeFormatter.string(from: date)
    }

    static func dayPeriod(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 7..<12:
            return "上午"
        case 12..<19:
            return "下午"
        default:
            return "晚上"
        }
    }

    private static func dayPeriodTime(_ date: Date) -> String {
        "\(dayPeriod(date)) \(minuteFormatter.string(from: date))"
    }
}
