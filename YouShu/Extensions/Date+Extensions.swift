//
//  Date+Extensions.swift
//  YouShu
//

import Foundation

extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
    }

    var endOfMonth: Date {
        Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
    }

    var startOfYear: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year], from: self))!
    }

    var monthYearString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月"
        return f.string(from: self)
    }

    var shortMonthString: String {
        let f = DateFormatter()
        f.dateFormat = "M月"
        return f.string(from: self)
    }

    static func monthsBack(from date: Date, count: Int) -> [Date] {
        var months: [Date] = []
        let cal = Calendar.current
        for i in (0..<count).reversed() {
            if let d = cal.date(byAdding: .month, value: -i, to: date.startOfMonth) {
                months.append(d)
            }
        }
        return months
    }
}
