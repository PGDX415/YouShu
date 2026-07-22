//
//  MonthlyInsightEngine.swift
//  YouShu
//

import Foundation

// MARK: - Insight Data

struct MonthlyInsightData {
    let month: String
    let totalIncome: Double
    let totalExpense: Double
    let balance: Double
    let topExpense: (category: String, amount: Double, percent: Double)?
    let topIncome: (category: String, amount: Double, percent: Double)?
    let largestTransaction: (note: String, amount: Double, category: String, day: Int)?
    let transactionCount: Int
    let dailyAverage: Double
    let momChange: Double? // month-over-month expense change %
    let categoryChanges: [(category: String, current: Double, previous: Double, change: Double)]
    let budgetStatus: (name: String, spent: Double, limit: Double, remaining: Double)?
    let mostActiveDay: (day: Int, count: Int)?
    let mostExpensiveDay: (day: Int, amount: Double)?
}

// MARK: - Insight Generator

enum MonthlyInsightEngine {

    /// Generate a human-readable monthly summary.
    static func generate(
        transactions: [Transaction],
        categories: [Category],
        budgets: [Budget],
        previousMonthTransactions: [Transaction]
    ) -> (data: MonthlyInsightData, summary: String) {
        let now = Date()
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!

        let monthTx = transactions.filter { $0.date >= monthStart }
        let prevTx = previousMonthTransactions

        let income = monthTx.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
        let expense = monthTx.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
        let prevIncome = prevTx.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
        let prevExpense = prevTx.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }

        let f = DateFormatter()
        f.locale = Locale(identifier: "zh-Hans")
        f.dateFormat = "M月"
        let monthName = f.string(from: now)

        // Top expense category
        var expenseByCat: [String: Double] = [:]
        for tx in monthTx where tx.type == .expense {
            let catName = tx.category?.name ?? "其他"
            expenseByCat[catName, default: 0] += tx.amount
        }
        let topExp = expenseByCat.max(by: { $0.value < $1.value })
        let topExpPct = expense > 0 ? ((topExp?.value ?? 0) / expense) : 0

        // Top income category
        var incomeByCat: [String: Double] = [:]
        for tx in monthTx where tx.type == .income {
            let catName = tx.category?.name ?? "其他"
            incomeByCat[catName, default: 0] += tx.amount
        }
        let topInc = incomeByCat.max(by: { $0.value < $1.value })
        let topIncPct = income > 0 ? ((topInc?.value ?? 0) / income) : 0

        // Largest single transaction
        let largest = monthTx.filter { $0.type == .expense }.max(by: { $0.amount < $1.amount })
        let largestDay = largest.map { cal.component(.day, from: $0.date) }

        // Daily average
        let daysInMonth = cal.range(of: .day, in: .month, for: now)?.count ?? 30
        let passedDays = min(cal.component(.day, from: now), daysInMonth)
        let dailyAvg = passedDays > 0 ? expense / Double(passedDays) : 0

        // Month-over-month change
        let momChange: Double? = prevExpense > 0 ? ((expense - prevExpense) / prevExpense) : nil

        // Category changes
        var catChanges: [(String, Double, Double, Double)] = []
        for (cat, cur) in expenseByCat {
            let prev = prevTx
                .filter { $0.type == .expense && $0.category?.name == cat }
                .reduce(0.0) { $0 + $1.amount }
            if prev > 0 {
                let change = (cur - prev) / prev
                if abs(change) > 0.1 {
                    catChanges.append((cat, cur, prev, change))
                }
            } else if cur > 0 {
                catChanges.append((cat, cur, 0, 1.0))
            }
        }
        catChanges.sort { abs($0.3) > abs($1.3) }

        // Budget check
        var budgetStatus: (String, Double, Double, Double)?
        if let budget = budgets.first {
            let spent = monthTx.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
            let limit = budget.monthlyLimit
            let remaining = limit - spent
            budgetStatus = (budget.category?.name ?? "预算", spent, limit, remaining)
        }

        // Most active day
        var dayCount: [Int: Int] = [:]
        for tx in monthTx {
            let d = cal.component(.day, from: tx.date)
            dayCount[d, default: 0] += 1
        }
        let mostActive = dayCount.max(by: { $0.value < $1.value })

        // Most expensive day
        var dayAmt: [Int: Double] = [:]
        for tx in monthTx where tx.type == .expense {
            let d = cal.component(.day, from: tx.date)
            dayAmt[d, default: 0] += tx.amount
        }
        let mostExpDay = dayAmt.max(by: { $0.value < $1.value })

        let data = MonthlyInsightData(
            month: monthName,
            totalIncome: income,
            totalExpense: expense,
            balance: income - expense,
            topExpense: topExp.map { ($0.key, $0.value, topExpPct) },
            topIncome: topInc.map { ($0.key, $0.value, topIncPct) },
            largestTransaction: largest.map {
                ($0.note.isEmpty ? ($0.category?.name ?? "消费") : $0.note, $0.amount, $0.category?.name ?? "", largestDay ?? 0)
            },
            transactionCount: monthTx.count,
            dailyAverage: dailyAvg,
            momChange: momChange,
            categoryChanges: catChanges,
            budgetStatus: budgetStatus,
            mostActiveDay: mostActive.map { ($0.key, $0.value) },
            mostExpensiveDay: mostExpDay.map { ($0.key, $0.value) }
        )

        let summary = buildSummary(data: data, prevIncome: prevIncome, prevExpense: prevExpense)
        return (data, summary)
    }

    // MARK: - Text Generation

    private static func buildSummary(
        data: MonthlyInsightData,
        prevIncome: Double,
        prevExpense: Double
    ) -> String {
        var lines: [String] = []

        // Opening
        let balance = data.totalIncome - data.totalExpense
        if data.totalIncome > 0 {
            lines.append("📊 \(data.month)总收入 \(fmt(data.totalIncome))，支出 \(fmt(data.totalExpense))，结余 \(fmt(balance))。")
        } else {
            lines.append("📊 \(data.month)总支出 \(fmt(data.totalExpense))。")
        }

        // Top expense
        if let top = data.topExpense {
            let pctStr = String(format: "%.0f%%", top.percent * 100)
            lines.append("最大开销是**\(top.category)** \(fmt(top.amount))，占总支出的 \(pctStr)。")
        }

        // Top income
        if let top = data.topIncome, data.totalIncome > 0 {
            let pctStr = String(format: "%.0f%%", top.percent * 100)
            lines.append("主要收入来自**\(top.category)** \(fmt(top.amount))（\(pctStr)）。")
        }

        // Month-over-month
        if let mom = data.momChange, prevExpense > 0 {
            if mom > 0.05 {
                lines.append("⬆️ 支出比上月增长了 \(pct(abs(mom)))，注意控制哦。")
            } else if mom < -0.05 {
                lines.append("⬇️ 支出比上月减少了 \(pct(abs(mom)))，继续保持！")
            } else {
                lines.append("➡️ 支出与上月基本持平。")
            }
        }

        // Category trend changes
        for change in data.categoryChanges.prefix(3) {
            let (cat, cur, _, chg) = change
            if chg > 0.3 {
                lines.append("🔺 **\(cat)** \(fmt(cur))，比上月多了不少。")
            } else if chg < -0.3 {
                lines.append("🔻 **\(cat)** \(fmt(cur))，比上月明显减少。")
            }
        }

        // Largest transaction
        if let lt = data.largestTransaction {
            let note = lt.note.isEmpty ? lt.category : lt.note
            lines.append("单笔最大：\(note) \(fmt(lt.amount))（\(lt.day)日）。")
        }

        // Daily average
        let dailyStr = fmt(data.dailyAverage)
        lines.append("日均支出约 \(dailyStr)。")

        // Most active day
        if let mad = data.mostActiveDay, mad.count >= 3 {
            lines.append("\(mad.day)日最活跃，当天记了 \(mad.count) 笔。")
        }

        // Budget
        if let budget = data.budgetStatus {
            if budget.remaining > 0 {
                let daysLeft = estimateRemainingDays(budget.remaining, dailyAvg: data.dailyAverage)
                lines.append("💡 预算「\(budget.name)」还剩 \(fmt(budget.remaining))，按当前速度还能撑约 \(daysLeft) 天。")
            } else {
                lines.append("⚠️ 预算「\(budget.name)」已超支 \(fmt(abs(budget.remaining)))！")
            }
        }

        // Encouragement
        if data.totalIncome > data.totalExpense && data.totalIncome > 0 {
            lines.append("💰 这个月存下了 \(fmt(data.totalIncome - data.totalExpense))，不错！")
        }

        return lines.joined(separator: "\n\n")
    }

    private static func fmt(_ value: Double) -> String {
        "¥\(value.formattedAmount)"
    }

    private static func pct(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private static func estimateRemainingDays(_ remaining: Double, dailyAvg: Double) -> Int {
        guard dailyAvg > 0 else { return 30 }
        return max(1, Int(remaining / dailyAvg))
    }
}
