//
//  TransactionFilterView.swift
//  YouShu
//

import SwiftUI
import SwiftData

// MARK: - Filter Criteria

struct FilterCriteria: Equatable {
    var selectedCategory: Category?
    var selectedAccount: Account?
    var minAmount: String = ""
    var maxAmount: String = ""
    var selectedType: TransactionType?
    var startDate: Date?
    var endDate: Date?
    var searchText: String = ""

    var hasActiveFilters: Bool {
        selectedCategory != nil ||
        selectedAccount != nil ||
        !minAmount.isEmpty ||
        !maxAmount.isEmpty ||
        selectedType != nil ||
        startDate != nil ||
        endDate != nil ||
        !searchText.isEmpty
    }

    func apply(to transactions: [Transaction]) -> [Transaction] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return transactions.filter { tx in
            if let cat = selectedCategory, tx.category?.id != cat.id { return false }
            if let acc = selectedAccount, tx.account?.id != acc.id { return false }
            if let type = selectedType, tx.type != type { return false }
            if let min = Double(minAmount), tx.amount < min { return false }
            if let max = Double(maxAmount), tx.amount > max { return false }
            if let start = startDate, tx.date < start { return false }
            if let end = endDate, tx.date > Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end {
                return false
            }
            if !query.isEmpty {
                let matchNote = tx.note.lowercased().contains(query)
                let matchCat = tx.category?.name.lowercased().contains(query) ?? false
                let matchAcc = tx.account?.name.lowercased().contains(query) ?? false
                let matchDest = tx.destinationAccount?.name.lowercased().contains(query) ?? false
                if !matchNote && !matchCat && !matchAcc && !matchDest { return false }
            }
            return true
        }
    }
}

// MARK: - TransactionFilterView

struct TransactionFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var criteria = FilterCriteria()
    @State private var showCategoryPicker = false
    @State private var showAccountPicker = false
    @State private var showDatePicker = false
    @State private var showDeleteAlert = false
    @State private var transactionToDelete: Transaction?
    @State private var transactionToEdit: Transaction?

    private var expenseCategories: [Category] { categories.filter { $0.type == .expense } }
    private var incomeCategories: [Category] { categories.filter { $0.type == .income } }

    private var filteredTransactions: (income: Double, expense: Double, list: [Transaction]) {
        let filtered = criteria.apply(to: allTransactions)
        let income = filtered.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expense = filtered.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        return (income, expense, filtered)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                filterBar

                // Summary
                if criteria.hasActiveFilters {
                    filterSummary
                }

                // Results
                if filteredTransactions.list.isEmpty {
                    emptyResult
                } else {
                    resultList
                }
            }
            .navigationTitle("筛选交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if criteria.hasActiveFilters {
                        Button("重置") {
                            criteria = FilterCriteria()
                        }
                    }
                }
            }
            .sheet(item: $transactionToEdit) { tx in
                AddTransactionView(editingTransaction: tx)
            }
            .alert("删除交易", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let tx = transactionToDelete {
                        if tx.type == .transfer {
                            if let src = tx.account { src.balance += abs(tx.amount) }
                            if let dest = tx.destinationAccount { dest.balance -= abs(tx.amount) }
                        } else if let account = tx.account {
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

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 10) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索备注、分类、账户...", text: $criteria.searchText)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                if !criteria.searchText.isEmpty {
                    Button {
                        criteria.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                // Type filter
                Menu {
                    Button { criteria.selectedType = nil } label: {
                        HStack {
                            Text("全部")
                            if criteria.selectedType == nil { Image(systemName: "checkmark") }
                        }
                    }
                    Button { criteria.selectedType = .expense } label: {
                        HStack {
                            Text("支出")
                            if criteria.selectedType == .expense { Image(systemName: "checkmark") }
                        }
                    }
                    Button { criteria.selectedType = .income } label: {
                        HStack {
                            Text("收入")
                            if criteria.selectedType == .income { Image(systemName: "checkmark") }
                        }
                    }
                    Button { criteria.selectedType = .transfer } label: {
                        HStack {
                            Text("转账")
                            if criteria.selectedType == .transfer { Image(systemName: "checkmark") }
                        }
                    }
                } label: {
                    filterChip(
                        label: criteria.selectedType?.displayName ?? "类型",
                        isActive: criteria.selectedType != nil
                    )
                }

                // Category filter
                Menu {
                    Button { criteria.selectedCategory = nil } label: {
                        HStack {
                            Text("全部")
                            if criteria.selectedCategory == nil { Image(systemName: "checkmark") }
                        }
                    }
                    Section("支出") {
                        ForEach(expenseCategories) { cat in
                            Button { criteria.selectedCategory = cat } label: {
                                HStack {
                                    Label(cat.name, systemImage: cat.icon)
                                    if criteria.selectedCategory?.id == cat.id { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                    Section("收入") {
                        ForEach(incomeCategories) { cat in
                            Button { criteria.selectedCategory = cat } label: {
                                HStack {
                                    Label(cat.name, systemImage: cat.icon)
                                    if criteria.selectedCategory?.id == cat.id { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                } label: {
                    filterChip(
                        label: criteria.selectedCategory?.name ?? "分类",
                        isActive: criteria.selectedCategory != nil
                    )
                }

                // Account filter
                Menu {
                    Button { criteria.selectedAccount = nil } label: {
                        HStack {
                            Text("全部")
                            if criteria.selectedAccount == nil { Image(systemName: "checkmark") }
                        }
                    }
                    ForEach(accounts) { acc in
                        Button { criteria.selectedAccount = acc } label: {
                            HStack {
                                Label(acc.name, systemImage: acc.icon)
                                if criteria.selectedAccount?.id == acc.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    filterChip(
                        label: criteria.selectedAccount?.name ?? "账户",
                        isActive: criteria.selectedAccount != nil
                    )
                }

                // Amount filter
                NavigationLink {
                    amountFilterSheet
                } label: {
                    filterChip(
                        label: amountLabel,
                        isActive: !criteria.minAmount.isEmpty || !criteria.maxAmount.isEmpty
                    )
                }

                // Date filter
                NavigationLink {
                    dateFilterSheet
                } label: {
                    filterChip(
                        label: dateLabel,
                        isActive: criteria.startDate != nil || criteria.endDate != nil
                    )
                }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .padding(.horizontal, 16)
        .background(Color(.systemGroupedBackground))
    }

    private func filterChip(label: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.subheadline)
            Image(systemName: isActive ? "line.3.horizontal.decrease.circle.fill" : "chevron.down")
                .font(.caption)
        }
        .foregroundColor(isActive ? .white : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isActive ? Color.accentColor : Color(.systemGray5))
        .clipShape(Capsule())
    }

    // MARK: - Amount Filter Sheet

    private var amountLabel: String {
        if !criteria.minAmount.isEmpty && !criteria.maxAmount.isEmpty {
            return "¥\(criteria.minAmount)-¥\(criteria.maxAmount)"
        } else if !criteria.minAmount.isEmpty {
            return "≥ ¥\(criteria.minAmount)"
        } else if !criteria.maxAmount.isEmpty {
            return "≤ ¥\(criteria.maxAmount)"
        }
        return "金额"
    }

    private var amountFilterSheet: some View {
        Form {
            Section("金额范围") {
                HStack {
                    Text("最低")
                    TextField("¥0", text: $criteria.minAmount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("最高")
                    TextField("¥不限", text: $criteria.maxAmount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                Button("清除金额筛选") {
                    criteria.minAmount = ""
                    criteria.maxAmount = ""
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("金额筛选")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Date Filter Sheet

    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: Locale.preferredLanguages.first ?? "zh-Hans")
        f.dateFormat = "M/d"
        if let start = criteria.startDate, let end = criteria.endDate {
            return "\(f.string(from: start))-\(f.string(from: end))"
        } else if let start = criteria.startDate {
            return "\(f.string(from: start))起"
        } else if let end = criteria.endDate {
            return "至\(f.string(from: end))"
        }
        return "日期"
    }

    private var dateFilterSheet: some View {
        Form {
            Section("日期范围") {
                HStack {
                    Text("开始日期")
                    Spacer()
                    DatePicker("开始日期", selection: Binding(
                        get: { criteria.startDate ?? Date() },
                        set: { criteria.startDate = $0 }
                    ), displayedComponents: .date)
                        .labelsHidden()
                }
                HStack {
                    Text("结束日期")
                    Spacer()
                    DatePicker("结束日期", selection: Binding(
                        get: { criteria.endDate ?? Date() },
                        set: { criteria.endDate = $0 }
                    ), displayedComponents: .date)
                        .labelsHidden()
                }
            }

            Section {
                Button("清除日期筛选") {
                    criteria.startDate = nil
                    criteria.endDate = nil
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("日期筛选")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary

    private var filterSummary: some View {
        let result = filteredTransactions
        return HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("收入").font(.caption).foregroundColor(.secondary)
                Text("¥\(result.income.formattedAmount0)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(.green)
            }
            VStack(spacing: 2) {
                Text("支出").font(.caption).foregroundColor(.secondary)
                Text("¥\(result.expense.formattedAmount0)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(.red)
            }
            VStack(spacing: 2) {
                Text("笔数").font(.caption).foregroundColor(.secondary)
                Text("\(result.list.count)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Results

    private var emptyResult: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            Text("没有符合条件的交易")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private var resultList: some View {
        List {
            ForEach(filteredTransactions.list) { tx in
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
        }
        .listStyle(.plain)
    }

    private func transactionRow(_ tx: Transaction) -> some View {
        let isTransfer = tx.type == .transfer
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
                    .foregroundColor(isTransfer ? .blue : (tx.category?.color ?? Color(.systemGray)))
            }

            VStack(alignment: .leading, spacing: 2) {
                if isTransfer {
                    HStack(spacing: 4) {
                        Text(tx.account?.name ?? "?").font(.system(size: 14, weight: .medium))
                        Image(systemName: "arrow.right").font(.caption2).foregroundColor(.secondary)
                        Text(tx.destinationAccount?.name ?? "?").font(.system(size: 14, weight: .medium))
                    }
                } else {
                    Text(tx.category?.name ?? "未分类")
                        .font(.system(size: 14, weight: .medium))
                }
                let trimmedNote = tx.note.trimmingCharacters(in: .whitespaces)
                if !trimmedNote.isEmpty {
                    Text(trimmedNote)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 4) {
                    if let member = tx.createdByMember {
                        Text(member.avatarInitial.isEmpty
                             ? String(member.name.prefix(1))
                             : member.avatarInitial)
                            .font(.system(size: 9))
                        Text(member.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("·")
                            .foregroundColor(.secondary)
                    }
                    Text(tx.date, format: .dateTime.month().day().hour().minute())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(isTransfer
                 ? "¥\(tx.amount.formattedAmount)"
                 : (tx.type == .expense
                    ? "-¥\(tx.amount.formattedAmount)"
                    : "+¥\(tx.amount.formattedAmount)"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(isTransfer ? .blue : (tx.type == .expense ? .red : .green))
        }.padding(.vertical, 4)
    }
}

#Preview {
    TransactionFilterView()
        .modelContainer(for: [Transaction.self, Category.self, Account.self], inMemory: true)
}
