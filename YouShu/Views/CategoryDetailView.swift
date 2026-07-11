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
                        Text("合计 ¥\(String(format: "%.2f", totalAmount))")
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

                            Text("-¥\(String(format: "%.2f", transaction.amount))")
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteTransaction(transaction)
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
    }

    private func deleteTransaction(_ transaction: Transaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
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
