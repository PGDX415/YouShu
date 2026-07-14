//
//  Double+Formatting.swift
//  YouShu
//

import Foundation

extension Double {
    /// Locale-aware formatted amount with 2 decimal places and grouping (e.g. 1,234.56)
    var formattedAmount: String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: Locale.preferredLanguages.first ?? "zh-Hans")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
    }

    /// Locale-aware formatted amount with 0 decimal places and grouping (e.g. 1,235)
    var formattedAmount0: String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: Locale.preferredLanguages.first ?? "zh-Hans")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: self)) ?? String(format: "%.0f", self)
    }
}
