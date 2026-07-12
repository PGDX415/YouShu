//
//  Budget.swift
//  YouShu
//

import Foundation
import SwiftData

@Model
final class Budget {
    var id: UUID = UUID()
    var monthlyLimit: Double = 0
    var createdAt: Date = Date()

    var category: Category?

    init(id: UUID = UUID(), monthlyLimit: Double, category: Category?) {
        self.id = id
        self.monthlyLimit = monthlyLimit
        self.category = category
    }
}
