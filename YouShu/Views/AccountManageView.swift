//
//  AccountManageView.swift
//  YouShu
//

import SwiftUI
import SwiftData

struct AccountManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var showEditSheet = false
    @State private var editingAccount: Account?
    @State private var showDeleteAlert = false
    @State private var accountToDelete: Account?

    var body: some View {
        List {
            Section {
                ForEach(accounts) { account in
                    accountRow(account)
                }
            } header: {
                Text("我的账户")
            } footer: {
                Text("账户余额根据交易记录自动计算。")
            }

            Section {
                Button {
                    editingAccount = nil
                    showEditSheet = true
                } label: {
                    Label("添加账户", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("账户管理")
        .sheet(isPresented: $showEditSheet) {
            AccountEditView(account: editingAccount) { name, icon, balance in
                if let existing = editingAccount {
                    existing.name = name
                    existing.icon = icon
                    existing.balance = balance
                    try? modelContext.save()
                } else {
                    let account = Account(name: name, icon: icon, balance: balance)
                    modelContext.insert(account)
                    try? modelContext.save()
                }
            }
        }
        .alert("删除账户", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let acc = accountToDelete {
                    modelContext.delete(acc)
                    try? modelContext.save()
                }
            }
        } message: {
            Text("删除后该账户下的交易将不再关联账户。")
        }
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: account.icon)
                    .font(.system(size: 15))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .foregroundColor(.primary)
                if account.isDefault {
                    Text("默认账户")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text("¥\(account.balance.formattedAmount)")
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundColor(account.balance >= 0 ? .green : .red)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading) {
            Button {
                editingAccount = account
                showEditSheet = true
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            if !account.isDefault {
                Button(role: .destructive) {
                    accountToDelete = account
                    showDeleteAlert = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - AccountEditView

struct AccountEditView: View {
    @Environment(\.dismiss) private var dismiss

    let account: Account?
    let onSave: (String, String, Double) -> Void

    @State private var name: String
    @State private var icon: String
    @State private var initialBalance: Double

    private let iconOptions: [String] = [
        "wallet.pass.fill", "creditcard.fill", "banknote.fill",
        "dollarsign.circle.fill", "yensign.circle.fill", "eurosign.circle.fill",
        "building.columns.fill", "archivebox.fill", "tray.full.fill",
        "envelope.fill", "bag.fill", "backpack.fill",
    ]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(account: Account?, onSave: @escaping (String, String, Double) -> Void) {
        self.account = account
        self.onSave = onSave
        _name = State(initialValue: account?.name ?? "")
        _icon = State(initialValue: account?.icon ?? "wallet.pass.fill")
        _initialBalance = State(initialValue: account?.balance ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    HStack {
                        Text("名称")
                        TextField("账户名称", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(iconOptions, id: \.self) { iconName in
                            Button {
                                icon = iconName
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(icon == iconName ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: iconName)
                                        .font(.system(size: 18))
                                        .foregroundColor(icon == iconName ? .accentColor : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(account == nil ? "初始余额" : "余额") {
                    HStack {
                        Text("¥")
                            .foregroundColor(.secondary)
                        TextField("0.00", value: $initialBalance, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle(account == nil ? "新建账户" : "编辑账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave(name.trimmingCharacters(in: .whitespaces), icon, initialBalance)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountManageView()
            .modelContainer(for: [Account.self], inMemory: true)
    }
}
