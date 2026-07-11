//
//  FamilyLedger.swift
//  YouShu
//

import Foundation
import SwiftData

@Model
final class FamilyLedger {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var createdBy: String = ""

    @Relationship(deleteRule: .cascade, inverse: \FamilyMember.ledger)
    var members: [FamilyMember]? = []

    @Relationship(deleteRule: .nullify, inverse: \Transaction.ledger)
    var transactions: [Transaction]? = []

    init(
        id: UUID = UUID(),
        name: String,
        createdBy: String = ""
    ) {
        self.id = id
        self.name = name
        self.createdBy = createdBy
    }
}
