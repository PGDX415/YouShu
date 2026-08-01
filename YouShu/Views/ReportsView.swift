//
//  ReportsView.swift
//  YouShu
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Data Types

struct MonthlySummary: Identifiable {
    let id = UUID()
    let month: Date
    let income: Double
    let expense: Double
}

struct CategoryBreakdown: Identifiable {
    let id = UUID()
    let category: Category
    let amount: Double
    let percentage: Double
}

enum ReportPeriod: String, CaseIterable {
    case month = "按月"
    case year = "按年"

    var monthCount: Int {
        switch self {
        case .month: return 6
        case .year: return 12
        }
    }
}

// MARK: - ReportsView

struct ReportsView: View {
    @Query private var transactions: [Transaction]
    @Query private var members: [FamilyMember]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var selectedYear: Int
    @State private var selectedCategory: Category?
    @State private var selectedMonth: Date?
    @State private var showMemberOnly: Bool = false

    private var currentMember: FamilyMember? {
        members.first(where: { $0.role == .creator })
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    init() {
        let year = Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: year)
    }

    // MARK: - Data

    private var filteredTransactions: [Transaction] {
        if showMemberOnly, let me = currentMember {
            return transactions.filter { $0.createdByMember?.id == me.id }
        }
        return transactions
    }

    private var yearTransactions: [Transaction] {
        filteredTransactions.filter {
            Calendar.current.component(.year, from: $0.date) == selectedYear
        }
    }

    private var yearIncome: Double {
        yearTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var yearExpense: Double {
        yearTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var yearBalance: Double {
        yearIncome - yearExpense
    }

    private var monthlyData: [MonthlySummary] {
        (1...12).compactMap { month in
            guard let monthDate = dateFor(month: month) else { return nil }
            let start = monthDate
            let end = monthDate.endOfMonth
            let monthTxns = yearTransactions.filter { $0.date >= start && $0.date <= end }
            return MonthlySummary(
                month: monthDate,
                income: monthTxns.filter { $0.type == .income }.reduce(0) { $0 + $1.amount },
                expense: monthTxns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            )
        }
    }

    private var incomeMonthProportions: [(month: String, amount: Double, pct: Double)] {
        let total = yearIncome
        guard total > 0 else { return [] }
        return monthlyData.compactMap { item in
            guard item.income > 0 else { return nil }
            return (item.month.shortMonthString, item.income, item.income / total * 100)
        }
    }

    private var expenseMonthProportions: [(month: String, amount: Double, pct: Double)] {
        let total = yearExpense
        guard total > 0 else { return [] }
        return monthlyData.compactMap { item in
            guard item.expense > 0 else { return nil }
            return (item.month.shortMonthString, item.expense, item.expense / total * 100)
        }
    }

    private var expenseCategoryBreakdown: [CategoryBreakdown] {
        let total = yearExpense
        guard total > 0 else { return [] }
        var dict: [UUID: (category: Category, amount: Double)] = [:]
        for tx in yearTransactions where tx.type == .expense {
            guard let cat = tx.category else { continue }
            let existing = dict[cat.id] ?? (cat, 0)
            dict[cat.id] = (cat, existing.amount + tx.amount)
        }
        return dict.values
            .map { CategoryBreakdown(category: $0.category, amount: $0.amount,
                                      percentage: $0.amount / total * 100) }
            .sorted { $0.amount > $1.amount }
    }

    private func dateFor(month: Int) -> Date? {
        var comps = DateComponents()
        comps.year = selectedYear
        comps.month = month
        comps.day = 1
        return Calendar.current.date(from: comps)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    yearSelector
                    yearlySummaryCard
                    incomeProportionChart
                    expenseProportionChart
                    categoryBreakdownSection
                    monthlyCardsSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("报表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if currentMember != nil {
                        Button {
                            withAnimation { showMemberOnly.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showMemberOnly ? "person.fill" : "person.3.fill")
                                    .font(.system(size: 11))
                                Text(showMemberOnly ? "仅我" : "全部")
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundColor(showMemberOnly ? .white : .accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(showMemberOnly ? Color.accentColor : Color(.systemGray6))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedMonth) { monthDate in
                MonthDetailView(year: selectedYear, month: monthDate)
            }
        }
    }

    // MARK: - Year Selector

    private var yearSelector: some View {
        HStack(spacing: 20) {
            Button {
                withAnimation { selectedYear -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
                    .foregroundColor(.accentColor)
            }

            Text("\(String(selectedYear))年")
                .font(.title2.weight(.bold))
                .frame(minWidth: 100)

            Button {
                withAnimation {
                    if selectedYear < currentYear {
                        selectedYear += 1
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.medium))
                    .foregroundColor(selectedYear < currentYear ? .accentColor : .secondary.opacity(0.4))
            }
            .disabled(selectedYear >= currentYear)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Yearly Summary

    private var yearlySummaryCard: some View {
        VStack(spacing: 12) {
            Text("\(String(selectedYear))年 收支概览")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 0) {
                summaryItem(title: "收入", amount: yearIncome, color: .green)
                summaryDivider
                summaryItem(title: "支出", amount: yearExpense, color: .red)
                summaryDivider
                summaryItem(title: "结余", amount: yearBalance, color: yearBalance >= 0 ? .blue : .red)
            }

            Text("共 \(yearTransactions.count) 笔交易")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private func summaryItem(title: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("¥\(amount.formattedAmount0)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: 1, height: 36)
    }

    // MARK: - Income Proportion Chart

    private var incomeProportionChart: some View {
        proportionChartCard(
            title: "各月收入占比",
            total: yearIncome,
            color: .green,
            data: incomeMonthProportions,
            emptyIcon: "arrow.up.circle",
            emptyText: "暂无收入数据"
        )
    }

    // MARK: - Expense Proportion Chart

    private var expenseProportionChart: some View {
        proportionChartCard(
            title: "各月支出占比",
            total: yearExpense,
            color: .red,
            data: expenseMonthProportions,
            emptyIcon: "arrow.down.circle",
            emptyText: "暂无支出数据"
        )
    }

    private func proportionChartCard(
        title: String,
        total: Double,
        color: Color,
        data: [(month: String, amount: Double, pct: Double)],
        emptyIcon: String,
        emptyText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("合计 ¥\(total.formattedAmount0)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if data.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: emptyIcon)
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(emptyText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                Chart {
                    ForEach(data, id: \.month) { item in
                        SectorMark(
                            angle: .value("金额", item.amount),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.5
                        )
                        .foregroundStyle(color.opacity(0.3 + item.pct / 100 * 0.7))
                    }
                }
                .frame(height: 180)

                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(data.sorted(by: { $0.amount > $1.amount }), id: \.month) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(color.opacity(0.3 + item.pct / 100 * 0.7))
                                .frame(width: 8, height: 8)
                            Text(item.month)
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(String(format: "%.1f%%", item.pct))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        let items = expenseCategoryBreakdown
        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("年度支出分类")
                            .font(.headline)
                        Spacer()
                        Text("\(items.count) 个分类")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)

                    Chart(items) { item in
                        SectorMark(
                            angle: .value("金额", item.amount),
                            innerRadius: .ratio(0.5),
                            angularInset: 1
                        )
                        .foregroundStyle(item.category.color)
                    }
                    .frame(height: 180)
                    .padding(.horizontal, 8)

                    Divider().padding(.horizontal, 16)

                    ForEach(items.prefix(6)) { item in
                        categoryRow(item)
                    }
                }
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
            }
        }
    }

    private func categoryRow(_ item: CategoryBreakdown) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.category.color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: item.category.icon)
                    .font(.system(size: 12))
                    .foregroundColor(item.category.color)
            }
            Text(item.category.name)
                .font(.subheadline)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("¥\(item.amount.formattedAmount0)")
                    .font(.subheadline.weight(.medium))
                Text(String(format: "%.1f%%", item.percentage))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Monthly Cards

    private var monthlyCardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("月度明细")
                .font(.headline)
                .padding(.horizontal, 20)

            ForEach(monthlyData) { item in
                Button {
                    selectedMonth = item.month
                } label: {
                    monthlyCard(item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func monthlyCard(_ item: MonthlySummary) -> some View {
        HStack(spacing: 0) {
            // Month label
            VStack(spacing: 2) {
                Text(item.month.shortMonthString)
                    .font(.system(size: 16, weight: .semibold))
                Text("\(selectedYear)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(width: 44)

            // Bar
            VStack(spacing: 4) {
                // Income bar
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        let maxAmt = max(yearIncome, yearExpense, 1)
                        ZStack(alignment: .trailing) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray6))
                                .frame(width: geo.size.width, height: 10)
                            if item.income > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.green.opacity(0.7))
                                    .frame(width: geo.size.width * (item.income / maxAmt), height: 10)
                            }
                        }
                    }
                    .frame(height: 10)
                    Text("收 ¥\(item.income.formattedAmount0)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(item.income > 0 ? .green : .secondary)
                        .frame(width: 72, alignment: .trailing)
                }

                // Expense bar
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        let maxAmt = max(yearIncome, yearExpense, 1)
                        ZStack(alignment: .trailing) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray6))
                                .frame(width: geo.size.width, height: 10)
                            if item.expense > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.red.opacity(0.7))
                                    .frame(width: geo.size.width * (item.expense / maxAmt), height: 10)
                            }
                        }
                    }
                    .frame(height: 10)
                    Text("支 ¥\(item.expense.formattedAmount0)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(item.expense > 0 ? .red : .secondary)
                        .frame(width: 72, alignment: .trailing)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

#Preview {
    ReportsView()
        .modelContainer(for: [Transaction.self, Category.self, Account.self], inMemory: true)
}
