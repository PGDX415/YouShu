//
//  TransactionType.swift
//  YouShu
//

import Foundation

enum TransactionType: String, Codable, CaseIterable {
    case expense
    case income
    case transfer

    var displayName: String {
        switch self {
        case .expense: return String(localized: "支出")
        case .income: return String(localized: "收入")
        case .transfer: return String(localized: "转账")
        }
    }
}
