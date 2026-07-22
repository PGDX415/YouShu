//
//  HomeView.swift
//  YouShu
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var transactions: [Transaction]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var budgets: [Budget]
    @Query private var members: [FamilyMember]

    @State private var showAddTransaction: Bool = false
    @State private var editingTransaction: Transaction?
    @State private var showFilter = false
    @State private var showNLInput = false
    @State private var showReceiptScanner = false
    @State private var showInsight = false
    @State private var showMemberOnly: Bool = false
    @State private var showDeleteAlert = false
    @State private var transactionToDelete: Transaction?

    private var currentMember: FamilyMember? {
        members.first(where: { $0.role == .creator })
    }

    /// Transactions filtered by member toggle
    private var filteredTransactions: [Transaction] {
        if showMemberOnly, let me = currentMember {
            return transactions.filter { $0.createdByMember?.id == me.id }
        }
        return transactions
    }

    private var totalBalance: Double {
        accounts.reduce(0) { $0 + $1.balance }
    }

    private var currentMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return []
        }
        return filteredTransactions.filter { $0.date >= startOfMonth }
    }

    private var monthlyIncome: Double {
        currentMonthTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthlyExpense: Double {
        currentMonthTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthlyBalance: Double {
        monthlyIncome - monthlyExpense
    }

    private var recentTransactions: [Transaction] {
        let sorted = filteredTransactions.sorted { $0.date > $1.date }
        return Array(sorted.prefix(10))
    }

    private var groupedTransactions: [(date: String, items: [Transaction])] {
        let calendar = Calendar.current
        var groups: [(date: String, items: [Transaction])] = []
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        for tx in recentTransactions {
            let txDay = calendar.startOfDay(for: tx.date)
            let label: String
            if txDay == today {
                label = "今天"
            } else if txDay == yesterday {
                label = "昨天"
            } else {
                let f = DateFormatter()
                f.locale = Locale(identifier: Locale.preferredLanguages.first ?? "zh-Hans")
                f.dateFormat = "M月d日 EEEE"
                label = f.string(from: tx.date)
            }

            if let index = groups.firstIndex(where: { $0.date == label }) {
                groups[index].items.append(tx)
            } else {
                groups.append((date: label, items: [tx]))
            }
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            List {
                // Monthly summary
                Section {
                    monthlySummaryCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)

                    // Smart actions
                    smartActionsRow
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)

                    quickAddButton
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)

                    if !accounts.isEmpty {
                        accountsSummaryView
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                    }

                    if !budgets.isEmpty {
                        budgetProgressSection
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                    }
                }

                // Recent transactions
                if recentTransactions.isEmpty {
                    Section {
                        emptyState
                            .listRowBackground(Color.clear)
                    } header: {
                        Text("最近交易")
                    }
                } else {
                    ForEach(groupedTransactions, id: \.date) { group in
                        Section {
                            ForEach(group.items) { transaction in
                                transactionRow(transaction)
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            editingTransaction = transaction
                                        } label: {
                                            Label("编辑", systemImage: "pencil")
                                        }
                                        .tint(.orange)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            transactionToDelete = transaction
                                            showDeleteAlert = true
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            HStack {
                                Text(group.date)
                                Spacer()
                                Text("\(group.items.count) 笔")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("有数")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            showFilter = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                        }
                        if currentMember != nil {
                            Button {
                                withAnimation {
                                    showMemberOnly.toggle()
                                }
                            } label: {
                                Image(systemName: showMemberOnly ? "person.fill" : "person.3.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(showMemberOnly ? .accentColor : .secondary)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
            .sheet(item: $editingTransaction) { transaction in
                AddTransactionView(editingTransaction: transaction)
            }
            .sheet(isPresented: $showInsight) {
                InsightView()
            }
            .sheet(isPresented: $showReceiptScanner) {
                ReceiptScanView()
            }
            .sheet(isPresented: $showNLInput) {
                NLInputView()
            }
            .sheet(isPresented: $showFilter) {
                TransactionFilterView()
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
    }

    // MARK: - Smart Actions

    private var smartActionsRow: some View {
        HStack(spacing: 10) {
            smartActionButton(
                icon: "sparkles", color: .purple,
                title: "智能记账",
                subtitle: "自然语言"
            ) { showNLInput = true }

            smartActionButton(
                icon: "camera.fill", color: .blue,
                title: "拍照记账",
                subtitle: "扫描小票"
            ) { showReceiptScanner = true }

            smartActionButton(
                icon: "chart.bar.doc.horizontal.fill", color: .orange,
                title: "月度小结",
                subtitle: "消费洞察"
            ) { showInsight = true }
        }
        .padding(.vertical, 4)
    }

    private func smartActionButton(
        icon: String, color: Color,
        title: String, subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Monthly Summary

    private var monthlySummaryCard: some View {
        let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: Locale.preferredLanguages.first ?? "zh-Hans")
            f.dateFormat = "M月"
            return f
        }()

        return VStack(spacing: 0) {
            Text("\(dateFormatter.string(from: Date())) 财务概览")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 4)

            HStack(spacing: 0) {
                summaryItem(title: "收入", amount: monthlyIncome, color: .green)
                summaryDivider
                summaryItem(title: "支出", amount: monthlyExpense, color: .red)
                summaryDivider
                summaryItem(title: "结余", amount: monthlyBalance, color: monthlyBalance >= 0 ? .blue : .red)
            }
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
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

    // MARK: - Accounts Summary

    private var accountsSummaryView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("账户总资产")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("¥\(totalBalance.formattedAmount)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(totalBalance >= 0 ? .green : .red)
            }

            if accounts.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(accounts) { account in
                            VStack(spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: account.icon)
                                        .font(.system(size: 10))
                                    Text(account.name)
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.secondary)
                                Text("¥\(account.balance.formattedAmount0)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(account.balance >= 0 ? .green : .red)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Budget Progress

    private var budgetProgressSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(budgets) { budget in
                    if let category = budget.category {
                        budgetCard(budget: budget, category: category)
                    }
                }
            }
            .padding(.horizontal, 0)
        }
    }

    private func budgetCard(budget: Budget, category: Category) -> some View {
        let now = Date()
        let startOfMonth = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: now)
        ) ?? now
        let spent = filteredTransactions
            .filter { $0.type == .expense && $0.category?.id == category.id && $0.date >= startOfMonth }
            .reduce(0) { $0 + $1.amount }
        let limit = budget.monthlyLimit
        let progress = limit > 0 ? min(spent / limit, 1.0) : 0
        let isOver = spent > limit && limit > 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 10))
                    .foregroundColor(category.color)
                Text(category.name)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                if isOver {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(isOver ? Color.red : category.color)
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text("¥\(spent.formattedAmount0)/¥\(limit.formattedAmount0)")
                    .font(.system(size: 10))
                    .foregroundColor(isOver ? .red : .secondary)
                Spacer()
                if progress >= 1 && limit > 0 {
                    Text("超支!")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(10)
        .frame(width: 140)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Quick Add Button

    private var quickAddButton: some View {
        Button {
            showAddTransaction = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("记一笔")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accentColor)
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("还没有交易记录")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("点击上方按钮记第一笔账")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func transactionRow(_ transaction: Transaction) -> some View {
        let isTransfer = transaction.type == .transfer
        let isExpense = transaction.type == .expense

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isTransfer
                          ? Color.blue.opacity(0.15)
                          : (transaction.category?.color ?? Color(.systemGray4)).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: isTransfer
                       ? "arrow.left.arrow.right"
                       : (transaction.category?.icon ?? "questionmark.circle"))
                    .font(.system(size: 16))
                    .foregroundColor(isTransfer ? .blue : (transaction.category?.color ?? Color(.systemGray)))
            }

            VStack(alignment: .leading, spacing: 2) {
                if isTransfer {
                    HStack(spacing: 4) {
                        Text(transaction.account?.name ?? "?")
                            .font(.system(size: 15, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(transaction.destinationAccount?.name ?? "?")
                            .font(.system(size: 15, weight: .medium))
                    }
                } else {
                    Text(transaction.category?.name ?? "未分类")
                        .font(.system(size: 15, weight: .medium))
                }
                if let member = transaction.createdByMember {
                    HStack(spacing: 4) {
                        Text(member.avatarInitial.isEmpty
                             ? String(member.name.prefix(1))
                             : member.avatarInitial)
                            .font(.system(size: 10))
                        Text(member.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                let trimmedNote = transaction.note.trimmingCharacters(in: .whitespaces)
                if !trimmedNote.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(isTransfer
                     ? "¥\(transaction.amount.formattedAmount)"
                     : (isExpense
                        ? "-¥\(transaction.amount.formattedAmount)"
                        : "+¥\(transaction.amount.formattedAmount)"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(isTransfer ? .blue : (isExpense ? .red : .green))
                Text(transaction.date, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Delete

    private func deleteTransaction(_ transaction: Transaction) {
        if transaction.type == .transfer {
            // Reverse transfer: add back to source, subtract from destination
            if let src = transaction.account { src.balance += abs(transaction.amount) }
            if let dest = transaction.destinationAccount { dest.balance -= abs(transaction.amount) }
        } else if let account = transaction.account {
            account.balance -= transaction.signedAmount
        }
        modelContext.delete(transaction)
        try? modelContext.save()
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Transaction.self, Category.self, Account.self], inMemory: true)
}
