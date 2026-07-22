//
//  InsightView.swift
//  YouShu
//

import SwiftUI
import SwiftData

struct InsightView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var budgets: [Budget]

    private var previousMonthTransactions: [Transaction] {
        let cal = Calendar.current
        let now = Date()
        guard let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let prevMonthStart = cal.date(byAdding: .month, value: -1, to: thisMonthStart) else {
            return []
        }
        return allTransactions.filter { $0.date >= prevMonthStart && $0.date < thisMonthStart }
    }

    private var insight: (data: MonthlyInsightData, summary: String) {
        MonthlyInsightEngine.generate(
            transactions: allTransactions,
            categories: categories,
            budgets: budgets,
            previousMonthTransactions: previousMonthTransactions
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header card
                    headerCard

                    // Summary text card
                    summaryCard

                    // Detail cards
                    if insight.data.topExpense != nil || insight.data.topIncome != nil {
                        detailCards
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(insight.data.month)小结")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.data.month)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("收支总览")
                        .font(.title2.weight(.bold))
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }

            HStack(spacing: 0) {
                statBox(title: "收入", value: insight.data.totalIncome, color: .green)
                Divider().frame(height: 40)
                statBox(title: "支出", value: insight.data.totalExpense, color: .red)
                Divider().frame(height: 40)
                statBox(title: "结余", value: insight.data.totalIncome - insight.data.totalExpense,
                        color: insight.data.totalIncome >= insight.data.totalExpense ? .green : .red)
            }

            HStack(spacing: 24) {
                Label("\(insight.data.transactionCount) 笔", systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("日均 \(insight.data.dailyAverage.formattedAmount)", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statBox(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value.formattedAmount)
                .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Summary Text

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("智能洞察", systemImage: "sparkles")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.accentColor)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            // Render summary with markdown-like formatting
            VStack(alignment: .leading, spacing: 12) {
                let paragraphs = insight.summary.components(separatedBy: "\n\n")
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    attributedText(paragraph)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func attributedText(_ text: String) -> Text {
        var result = Text("")
        var remaining = text
        while let boldStart = remaining.range(of: "**") {
            // Before bold
            if boldStart.lowerBound > remaining.startIndex {
                result = result + Text(String(remaining[remaining.startIndex..<boldStart.lowerBound]))
                    .font(.subheadline)
            }
            let afterStart = remaining.index(boldStart.upperBound, offsetBy: 0)
            guard let boldEnd = remaining[afterStart...].range(of: "**") else { break }
            let boldText = String(remaining[afterStart..<boldEnd.lowerBound])
            result = result + Text(boldText).font(.subheadline.weight(.semibold))
            remaining = String(remaining[boldEnd.upperBound...])
        }
        if !remaining.isEmpty {
            result = result + Text(remaining).font(.subheadline)
        }
        return result
    }

    // MARK: - Detail Cards

    private var detailCards: some View {
        VStack(spacing: 12) {
            // Top expense
            if let top = insight.data.topExpense {
                detailRow(icon: "cart.fill", color: .red,
                          title: "最大开销", value: "\(top.category) \(top.amount.formattedAmount)",
                          subtitle: "占支出 \(String(format: "%.0f%%", top.percent * 100))")
            }

            // Top income
            if let top = insight.data.topIncome, insight.data.totalIncome > 0 {
                detailRow(icon: "banknote.fill", color: .green,
                          title: "主要收入", value: "\(top.category) \(top.amount.formattedAmount)",
                          subtitle: "占收入 \(String(format: "%.0f%%", top.percent * 100))")
            }

            // Month-over-month
            if let mom = insight.data.momChange {
                let arrow = mom > 0.05 ? "↑" : (mom < -0.05 ? "↓" : "→")
                let desc = mom > 0.05 ? "比上月增长" : (mom < -0.05 ? "比上月减少" : "与上月持平")
                detailRow(icon: "arrow.left.arrow.right", color: mom > 0.05 ? .red : .green,
                          title: "环比变化",
                          value: "\(arrow) \(desc) \(String(format: "%.0f%%", abs(mom) * 100))",
                          subtitle: nil)
            }

            // Largest transaction
            if let lt = insight.data.largestTransaction {
                detailRow(icon: "flame.fill", color: .orange,
                          title: "单笔最大",
                          value: "\(lt.category) \(lt.amount.formattedAmount)",
                          subtitle: "\(lt.day)日 · \(lt.note)")
            }

            // Budget
            if let budget = insight.data.budgetStatus {
                let remaining = budget.remaining
                detailRow(icon: "gauge.with.dots.needle.33percent", color: remaining > 0 ? .green : .red,
                          title: "预算执行",
                          value: remaining > 0 ? "剩余 \(remaining.formattedAmount)" : "超支 \(abs(remaining).formattedAmount)",
                          subtitle: "\(budget.spent.formattedAmount) / \(budget.limit.formattedAmount)")
            }
        }
    }

    private func detailRow(
        icon: String, color: Color, title: String,
        value: String, subtitle: String?
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.medium))
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    InsightView()
        .modelContainer(for: [Transaction.self, Category.self, Account.self], inMemory: true)
}
