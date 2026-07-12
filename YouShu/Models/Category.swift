//
//  Category.swift
//  YouShu
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "questionmark.circle"
    var colorHex: String = "#808080"
    var typeRaw: String = TransactionType.expense.rawValue
    var sortOrder: Int = 0
    var isPreset: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]? = []

    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budgets: [Budget]? = []

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var color: Color {
        Color(hex: colorHex)
    }

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorHex: String,
        type: TransactionType,
        sortOrder: Int = 0,
        isPreset: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.typeRaw = type.rawValue
        self.sortOrder = sortOrder
        self.isPreset = isPreset
    }
}
