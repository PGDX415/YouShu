//
//  Account.swift
//  YouShu
//

import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "wallet.pass.fill"
    var balance: Double = 0
    var createdAt: Date = Date()
    var isDefault: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Transaction.account)
    var transactions: [Transaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \Transaction.destinationAccount)
    var destinationTransactions: [Transaction]? = []

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "wallet.pass.fill",
        balance: Double = 0,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.balance = balance
        self.isDefault = isDefault
    }
}
