//
//  TransactionType.swift
//  YouShu
//

import Foundation

enum TransactionType: String, Codable, CaseIterable {
    case expense
    case income

    var displayName: String {
        switch self {
        case .expense: return "支出"
        case .income: return "收入"
        }
    }
}
