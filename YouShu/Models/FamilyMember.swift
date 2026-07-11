//
//  FamilyMember.swift
//  YouShu
//

import Foundation
import SwiftData

enum MemberRole: String, Codable {
    case creator
    case member
}

@Model
final class FamilyMember {
    var id: UUID = UUID()
    var name: String = ""
    var avatarInitial: String = ""
    var roleRaw: String = MemberRole.member.rawValue
    var joinedAt: Date = Date()

    var role: MemberRole {
        get { MemberRole(rawValue: roleRaw) ?? .member }
        set { roleRaw = newValue.rawValue }
    }

    var ledger: FamilyLedger?

    init(
        id: UUID = UUID(),
        name: String,
        avatarInitial: String = "",
        role: MemberRole = .member
    ) {
        self.id = id
        self.name = name
        self.avatarInitial = avatarInitial
        self.roleRaw = role.rawValue
    }
}
