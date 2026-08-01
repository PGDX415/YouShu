//
//  MonthDetailView.swift
//  YouShu
//

import SwiftUI
import SwiftData
import Charts

struct MonthDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTransactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    let year: Int
    let month: Date

    @State private var showDeleteAlert = false
    @State private var transactionToDelete: Transaction?
    @State private var transactionToEdit: Transaction?

    // MARK: - Date helpers

    private var monthStart: Date {
        month
    }

    private var monthEnd: Date {
        month.endOfMonth
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh-Hans")
        f.dateFormat = "yyyy年M月"
        return f.string(from: month)
    }

    // MARK: - Data

    private var monthTransactions: [Transaction] {
        allTransactions
            .filter { $0.date >= monthStart && $0.date <= monthEnd }
            .sorted { $0.date > $1.date }
    }

    private var monthIncome: Double {
        monthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var monthExpense: Double {
        monthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var expenseCategoryBreakdown: [CategoryBreakdown] {
        let expenses = monthTransactions.filter { $0.type == .expense }
        let total = expenses.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return [] }

        var dict: [UUID: (category: Category, amount: Double)] = [:]
        for tx in expenses {
            guard let cat = tx.category else { continue }
            let existing = dict[cat.id] ?? (cat, 0)
            dict[cat.id] = (cat, existing.amount + tx.amount)
        }
        return dict.values
            .map { CategoryBreakdown(category: $0.category, amount: $0.amount,
                                      percentage: $0.amount / total * 100) }
            .sorted { $0.amount > $1.amount }
    }

    var body: some View {
        List {
            // Summary
            Section {
                VStack(spacing: 12) {
                    Text(monthLabel)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 0) {
                        statItem(title: "收入", amount: monthIncome, color: .green)
                        Divider().frame(height: 36)
                        statItem(title: "支出", amount: monthExpense, color: .red)
                        Divider().frame(height: 36)
                        statItem(title: "结余", amount: monthIncome - monthExpense,
                                 color: monthIncome >= monthExpense ? .blue : .red)
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            // Category breakdown pie
            if !expenseCategoryBreakdown.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("支出分类占比")
                            .font(.headline)

                        Chart(expenseCategoryBreakdown) { item in
                            SectorMark(
                                angle: .value("金额", item.amount),
                                innerRadius: .ratio(0.5),
                                angularInset: 1
                            )
                            .foregroundStyle(item.category.color)
                        }
                        .frame(height: 160)

                        ForEach(expenseCategoryBreakdown) { item in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(item.category.color)
                                    .frame(width: 10, height: 10)
                                Text(item.category.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("¥\(item.amount.formattedAmount0)")
                                    .font(.subheadline.weight(.medium))
                                Text(String(format: "%.1f%%", item.percentage))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 42, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Transactions
            if monthTransactions.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("该月暂无交易")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                Section {
                    ForEach(monthTransactions) { tx in
                        transactionRow(tx)
                            .swipeActions(edge: .leading) {
                                Button {
                                    transactionToEdit = tx
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    transactionToDelete = tx
                                    showDeleteAlert = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("\(monthTransactions.count) 笔交易")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("月度明细")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $transactionToEdit) { tx in
            AddTransactionView(editingTransaction: tx)
        }
        .alert("删除交易", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let tx = transactionToDelete {
                    deleteTransaction(tx)
                }
            }
        } message: {
            if let tx = transactionToDelete {
                Text("确定要删除这笔 ¥\(tx.amount.formattedAmount) 的交易记录吗？")
            }
        }
    }

    // MARK: - Stat Item

    private func statItem(title: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("¥\(amount.formattedAmount0)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Transaction Row

    private func transactionRow(_ tx: Transaction) -> some View {
        let isTransfer = tx.type == .transfer
        let isExpense = tx.type == .expense

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isTransfer
                          ? Color.blue.opacity(0.15)
                          : (tx.category?.color ?? Color(.systemGray4)).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: isTransfer
                       ? "arrow.left.arrow.right"
                       : (tx.category?.icon ?? "questionmark.circle"))
                    .font(.system(size: 14))
                    .foregroundColor(isTransfer ? .blue : (tx.category?.color ?? .gray))
            }

            VStack(alignment: .leading, spacing: 2) {
                if isTransfer {
                    HStack(spacing: 4) {
                        Text(tx.account?.name ?? "?")
                        Image(systemName: "arrow.right").font(.caption2)
                        Text(tx.destinationAccount?.name ?? "?")
                    }
                    .font(.subheadline)
                } else {
                    Text(tx.category?.name ?? "未分类")
                        .font(.subheadline)
                }
                if !tx.note.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(tx.note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(isTransfer
                     ? "¥\(tx.amount.formattedAmount)"
                     : (isExpense
                        ? "-¥\(tx.amount.formattedAmount)"
                        : "+¥\(tx.amount.formattedAmount)"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(isTransfer ? .blue : (isExpense ? .red : .green))
                Text(tx.date, format: .dateTime.month(.twoDigits).day().hour().minute())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Delete

    private func deleteTransaction(_ transaction: Transaction) {
        if transaction.type == .transfer {
            if let src = transaction.account { src.balance += abs(transaction.amount) }
            if let dest = transaction.destinationAccount { dest.balance -= abs(transaction.amount) }
        } else if let account = transaction.account {
            account.balance -= transaction.signedAmount
        }
        modelContext.delete(transaction)
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        MonthDetailView(year: 2026, month: Date())
    }
    .modelContainer(for: [Transaction.self, Category.self, Account.self], inMemory: true)
}