//
//  BudgetDetailView.swift
//  YouShu
//

import SwiftUI
import SwiftData

struct BudgetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allTransactions: [Transaction]

    let budget: Budget
    let category: Category

    private var monthTransactions: [Transaction] {
        let now = Date()
        let startOfMonth = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: now)
        ) ?? now
        return allTransactions
            .filter { $0.type == .expense && $0.category?.id == category.id && $0.date >= startOfMonth }
            .sorted { $0.date > $1.date }
    }

    private var totalSpent: Double {
        monthTransactions.reduce(0) { $0 + $1.amount }
    }

    private var limit: Double {
        budget.monthlyLimit
    }

    private var progress: Double {
        limit > 0 ? min(totalSpent / limit, 1.0) : 0
    }

    private var remaining: Double {
        limit - totalSpent
    }

    private var dailyAverage: Double {
        let passedDays = Calendar.current.component(.day, from: Date())
        return passedDays > 0 ? totalSpent / Double(passedDays) : 0
    }

    private var estimatedDaysLeft: Int {
        guard dailyAverage > 0 && remaining > 0 else { return 0 }
        return max(0, Int(remaining / dailyAverage))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header card
                headerSection

                // Transaction list
                if monthTransactions.isEmpty {
                    emptySection
                } else {
                    transactionList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("预算详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 20) {
            // Category info
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundColor(category.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.title3.weight(.semibold))
                    Text("月度预算 ¥\(limit.formattedAmount0)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 10)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progress >= 1 ? Color.red : category.color,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: progress)

                VStack(spacing: 2) {
                    Text("¥\(totalSpent.formattedAmount0)")
                        .font(.title3.weight(.bold).monospacedDigit())
                    Text("/ ¥\(limit.formattedAmount0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Stats row
            HStack(spacing: 0) {
                statItem(title: "剩余", value: remaining > 0
                         ? "¥\(remaining.formattedAmount0)"
                         : "超 ¥\(abs(remaining).formattedAmount0)",
                         color: remaining >= 0 ? .green : .red)
                Divider().frame(height: 30)
                statItem(title: "日均", value: "¥\(dailyAverage.formattedAmount0)", color: .primary)
                Divider().frame(height: 30)
                statItem(title: "预估", value: estimatedDaysLeft > 0
                         ? "约\(estimatedDaysLeft)天"
                         : remaining <= 0 ? "已用完" : "-",
                         color: estimatedDaysLeft > 7 ? .green : (estimatedDaysLeft > 0 ? .orange : .secondary))
            }
            .padding(.horizontal, 8)
        }
        .padding(20)
        .background(Color(.systemBackground))
    }

    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Transaction List

    private var transactionList: some View {
        List {
            Section {
                ForEach(monthTransactions) { tx in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            if tx.note.isEmpty {
                                Text("无备注")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(tx.note)
                                    .font(.subheadline)
                                    .lineLimit(2)
                            }
                            Text(tx.date, format: .dateTime.month().day().hour().minute())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("-¥\(tx.amount.formattedAmount)")
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                HStack {
                    Text("本月支出明细")
                    Spacer()
                    Text("\(monthTransactions.count) 笔")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty

    private var emptySection: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            Text("本月暂无 \(category.name) 支出")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    BudgetDetailView(
        budget: Budget(monthlyLimit: 3000, category: nil),
        category: Category(name: "餐饮", icon: "fork.knife", colorHex: "#FF6B35", type: .expense)
    )
    .modelContainer(for: [Transaction.self], inMemory: true)
}
