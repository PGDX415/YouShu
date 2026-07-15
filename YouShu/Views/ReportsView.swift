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
    @State private var period: ReportPeriod = .month
    @State private var selectedCategory: Category?
    @State private var showMemberOnly: Bool = false

    private var currentMember: FamilyMember? {
        members.first(where: { $0.role == .creator })
    }

    private var filteredTransactions: [Transaction] {
        if showMemberOnly, let me = currentMember {
            return transactions.filter { $0.createdByMember?.id == me.id }
        }
        return transactions
    }

    private var monthlyData: [MonthlySummary] {
        let months = Date.monthsBack(from: Date(), count: period.monthCount)
        return months.map { monthStart in
            let monthEnd = monthStart.endOfMonth
            let monthTxns = filteredTransactions.filter { $0.date >= monthStart && $0.date <= monthEnd }
            return MonthlySummary(
                month: monthStart,
                income: monthTxns.filter { $0.type == .income }.reduce(0) { $0 + $1.amount },
                expense: monthTxns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            )
        }
    }

    private var currentPeriodExpenses: [Transaction] {
        let now = Date()
        let start: Date
        switch period {
        case .month:
            start = now.startOfMonth
        case .year:
            start = now.startOfYear
        }
        return filteredTransactions.filter { $0.type == .expense && $0.date >= start }
    }

    private var categoryBreakdown: [CategoryBreakdown] {
        let total = currentPeriodExpenses.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return [] }

        var dict: [UUID: (category: Category, amount: Double)] = [:]
        for tx in currentPeriodExpenses {
            guard let cat = tx.category else { continue }
            let existing = dict[cat.id] ?? (cat, 0)
            dict[cat.id] = (cat, existing.amount + tx.amount)
        }

        return dict.values
            .map { CategoryBreakdown(
                category: $0.category,
                amount: $0.amount,
                percentage: $0.amount / total * 100
            )}
            .sorted { $0.amount > $1.amount }
    }

    private var totalExpense: Double {
        currentPeriodExpenses.reduce(0) { $0 + $1.amount }
    }

    private var currentPeriodTransactions: [Transaction] {
        let now = Date()
        let start: Date
        switch period {
        case .month: start = now.startOfMonth
        case .year: start = now.startOfYear
        }
        return filteredTransactions.filter { $0.date >= start }
    }

    private var periodLabel: String {
        switch period {
        case .month: return Date().monthYearString
        case .year:
            let f = DateFormatter()
            f.locale = Locale(identifier: Locale.preferredLanguages.first ?? "zh-Hans")
            f.dateFormat = "yyyy年"
            return f.string(from: Date())
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    periodPicker
                    summaryHeader
                    trendChartSection
                    categoryPieSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("报表")
            .navigationDestination(item: $selectedCategory) { category in
                CategoryDetailView(category: category, period: period)
            }
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(periodLabel)
                    .font(.title3.weight(.semibold))
                Text(String(format: String(localized: "共 %lld 笔交易"), currentPeriodTransactions.count))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if currentMember != nil {
                Button {
                    withAnimation {
                        showMemberOnly.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showMemberOnly ? "person.fill" : "person.3.fill")
                            .font(.system(size: 12))
                        Text(showMemberOnly ? "仅我" : "全部")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(showMemberOnly ? .white : .accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(showMemberOnly ? Color.accentColor : Color(.systemGray6))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("时间维度", selection: $period) {
            ForEach(ReportPeriod.allCases, id: \.self) { p in
                Text(p.rawValue).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
    }

    // MARK: - Trend Chart

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("收支趋势")
                .font(.headline)
                .padding(.horizontal, 16)

            Chart {
                ForEach(monthlyData) { item in
                    // 收入曲线 & 面积
                    LineMark(
                        x: .value("月份", item.month.shortMonthString),
                        y: .value("金额", item.income),
                        series: .value("类型", "收入")
                    )
                    .foregroundStyle(by: .value("类型", "收入"))
                    .interpolationMethod(.catmullRom)
                    .symbol(Circle().strokeBorder(lineWidth: 2))

                    AreaMark(
                        x: .value("月份", item.month.shortMonthString),
                        y: .value("金额", item.income),
                        series: .value("类型", "收入-面积")
                    )
                    .foregroundStyle(by: .value("类型", "收入-面积"))
                    .interpolationMethod(.catmullRom)

                    // 支出曲线 & 面积
                    LineMark(
                        x: .value("月份", item.month.shortMonthString),
                        y: .value("金额", -item.expense),
                        series: .value("类型", "支出")
                    )
                    .foregroundStyle(by: .value("类型", "支出"))
                    .interpolationMethod(.catmullRom)
                    .symbol(Circle().strokeBorder(lineWidth: 2))

                    AreaMark(
                        x: .value("月份", item.month.shortMonthString),
                        y: .value("金额", -item.expense),
                        series: .value("类型", "支出-面积")
                    )
                    .foregroundStyle(by: .value("类型", "支出-面积"))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartForegroundStyleScale([
                "收入": Color.green,
                "收入-面积": Color.green.opacity(0.15),
                "支出": Color.red,
                "支出-面积": Color.red.opacity(0.15),
            ])
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text("¥\(Int(amount))")
                        }
                    }
                }
            }
            .frame(height: 250)
            .padding(.horizontal, 8)

            HStack(spacing: 24) {
                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("收入").font(.caption).foregroundColor(.secondary)
                }
                HStack(spacing: 6) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text("支出").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Category Pie

    private var categoryPieSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("支出分类占比")
                    .font(.headline)
                Spacer()
                Text("合计 ¥\(totalExpense.formattedAmount0)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)

            if categoryBreakdown.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("暂无支出数据")
                        .foregroundColor(.secondary)
                    Text("记一笔支出后，分类占比将在这里展示")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                Chart(categoryBreakdown) { item in
                    SectorMark(
                        angle: .value("金额", item.amount),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(item.category.color)
                }
                .frame(height: 200)
                .padding(.horizontal, 8)

                Divider().padding(.horizontal, 16)

                ForEach(categoryBreakdown) { item in
                    categoryRow(item)
                }
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func categoryRow(_ item: CategoryBreakdown) -> some View {
        Button {
            selectedCategory = item.category
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(item.category.color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: item.category.icon)
                        .font(.system(size: 14))
                        .foregroundColor(item.category.color)
                }

                Text(item.category.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("¥\(item.amount.formattedAmount0)")
                        .font(.subheadline.weight(.medium))
                    Text(String(format: "%.1f%%", item.percentage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReportsView()
        .modelContainer(for: [Transaction.self, Category.self, Account.self], inMemory: true)
}
