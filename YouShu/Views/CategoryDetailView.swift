//
//  CategoryDetailView.swift
//  YouShu
//

import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTransactions: [Transaction]

    let category: Category
    let period: ReportPeriod

    @State private var showDeleteAlert = false
    @State private var transactionToDelete: Transaction?

    private var filteredTransactions: [Transaction] {
        let start: Date
        switch period {
        case .month: start = Date().startOfMonth
        case .year: start = Date().startOfYear
        }
        return allTransactions
            .filter { $0.category?.id == category.id && $0.date >= start }
            .sorted { $0.date > $1.date }
    }

    private var totalAmount: Double {
        filteredTransactions.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(category.color.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Image(systemName: category.icon)
                                .font(.title2)
                                .foregroundColor(category.color)
                        }
                        Text(category.name)
                            .font(.title3.weight(.semibold))
                        Text("合计 ¥\(totalAmount.formattedAmount)")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            if filteredTransactions.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("该分类下暂无交易")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                Section {
                    ForEach(filteredTransactions) { transaction in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                if !transaction.note.isEmpty {
                                    Text(transaction.note)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                } else {
                                    Text("无备注")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Text(transaction.date, format: .dateTime.month(.twoDigits).day().hour().minute())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("-¥\(transaction.amount.formattedAmount)")
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                transactionToDelete = transaction
                                showDeleteAlert = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("交易明细")
        .navigationBarTitleDisplayMode(.inline)
        .alert("删除交易", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let tx = transactionToDelete {
                    if let account = tx.account {
                        account.balance -= tx.signedAmount
                    }
                    modelContext.delete(tx)
                    try? modelContext.save()
                }
            }
        } message: {
            if let tx = transactionToDelete {
                Text("确定要删除这笔 ¥\(tx.amount.formattedAmount) 的交易记录吗？")
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(
            category: Category(name: "餐饮", icon: "fork.knife", colorHex: "#FF6B35", type: .expense),
            period: .month
        )
    }
}
