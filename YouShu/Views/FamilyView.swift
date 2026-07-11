//
//  FamilyView.swift
//  YouShu
//

import SwiftUI
import SwiftData
import CloudKit

struct FamilyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var ledgers: [FamilyLedger]
    @Query private var members: [FamilyMember]

    @State private var showCreateSheet = false
    @State private var newLedgerName = ""
    @State private var showDeleteAlert = false

    private var currentLedger: FamilyLedger? {
        ledgers.first
    }

    private var currentMembers: [FamilyMember] {
        members.filter { $0.ledger?.id == currentLedger?.id }
    }

    var body: some View {
        List {
            if let ledger = currentLedger {
                // Ledger info
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ledger.name)
                                .font(.headline)
                            Text("创建于 \(ledger.createdAt, format: .dateTime.year().month().day())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    Button {
                        presentCloudSharingController(
                            ledgerID: ledger.id,
                            ledgerName: ledger.name,
                            containerID: "iCloud.com.gongdexin.paul.YouShu"
                        )
                    } label: {
                        Label("邀请家庭成员", systemImage: "person.badge.plus")
                    }
                } header: {
                    Text("家庭账本")
                }

                // Members
                Section {
                    ForEach(currentMembers) { member in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(member.role == .creator ? Color.accentColor : Color(.systemGray4))
                                    .frame(width: 36, height: 36)
                                Text(member.avatarInitial.isEmpty
                                     ? String(member.name.prefix(1))
                                     : member.avatarInitial)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .font(.subheadline)
                                Text(member.role == .creator ? "创建者" : "成员")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    if currentMembers.isEmpty {
                        Text("暂无成员，邀请家人一起记账吧")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("成员 (\(currentMembers.count))")
                }

                // Danger zone
                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("删除家庭账本", systemImage: "trash")
                    }
                }
            } else {
                // No ledger yet
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.largeTitle)
                            .foregroundColor(.secondary.opacity(0.4))

                        Text("还没有家庭账本")
                            .font(.headline)

                        Text("创建一个家庭账本，和家人一起记账、实时同步。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            showCreateSheet = true
                        } label: {
                            Label("创建家庭账本", systemImage: "plus.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationTitle("家庭共享")
        .sheet(isPresented: $showCreateSheet) {
            createLedgerSheet
        }
        .alert("删除家庭账本", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { deleteLedger() }
        } message: {
            Text("删除后所有成员的共享数据将丢失。")
        }
    }

    // MARK: - Create Sheet

    private var createLedgerSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("账本名称（如：我们家）", text: $newLedgerName)
                } header: {
                    Text("给家庭账本起个名字")
                }

                Section {
                    Button {
                        createLedger()
                    } label: {
                        HStack {
                            Spacer()
                            Text("创建")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(newLedgerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("新建家庭账本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { showCreateSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func createLedger() {
        let name = newLedgerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let ledger = FamilyLedger(name: name, createdBy: "我")
        let creator = FamilyMember(name: "我", avatarInitial: "我", role: .creator)
        creator.ledger = ledger
        ledger.members = [creator]

        modelContext.insert(ledger)
        modelContext.insert(creator)
        try? modelContext.save()

        newLedgerName = ""
        showCreateSheet = false
    }

    private func deleteLedger() {
        guard let ledger = currentLedger else { return }
        modelContext.delete(ledger)
        try? modelContext.save()
    }

}

#Preview {
    NavigationStack {
        FamilyView()
    }
}
