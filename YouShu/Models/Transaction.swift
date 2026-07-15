//
//  Transaction.swift
//  YouShu
//

import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID = UUID()
    var amount: Double = 0
    var typeRaw: String = TransactionType.expense.rawValue
    var date: Date = Date()
    var note: String = ""
    var createdAt: Date = Date()

    var category: Category?
    var account: Account?
    var destinationAccount: Account?
    var ledger: FamilyLedger?
    var createdByMember: FamilyMember?

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var signedAmount: Double {
        switch type {
        case .expense: return -abs(amount)
        case .income: return abs(amount)
        case .transfer: return 0
        }
    }

    init(
        id: UUID = UUID(),
        amount: Double,
        type: TransactionType,
        date: Date = Date(),
        note: String = "",
        category: Category? = nil,
        account: Account? = nil,
        destinationAccount: Account? = nil,
        createdByMember: FamilyMember? = nil
    ) {
        self.id = id
        self.amount = abs(amount)
        self.typeRaw = type.rawValue
        self.date = date
        self.note = note
        self.category = category
        self.account = account
        self.destinationAccount = destinationAccount
        self.createdByMember = createdByMember
    }
}
