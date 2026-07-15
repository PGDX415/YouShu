//
//  BudgetManageView.swift
//  YouShu
//

import SwiftUI
import SwiftData

struct BudgetManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var budgets: [Budget]
    @Query private var transactions: [Transaction]

    @State private var showAddSheet = false
    @State private var editingBudget: Budget?
    @State private var showDeleteAlert = false
    @State private var budgetToDelete: Budget?

    private var expenseCategories: [Category] {
        categories.filter { $0.type == .expense }
    }

    /// Current-month spending per category
    private func currentSpending(for category: Category) -> Double {
        let now = Date()
        guard let startOfMonth = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: now)
        ) else { return 0 }
        return transactions
            .filter { $0.type == .expense && $0.category?.id == category.id && $0.date >= startOfMonth }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        List {
            if budgets.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("还没有设置预算")
                            .font(.headline)
                        Text("为支出分类设置月度预算，控制消费。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                Section {
                    ForEach(budgets) { budget in
                        budgetRow(budget)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    budgetToDelete = budget
                                    showDeleteAlert = true
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("已设预算")
                }
            }

            Section {
                ForEach(availableCategories) { category in
                    Button {
                        addBudget(for: category)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(category.color.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: category.icon)
                                    .font(.system(size: 13))
                                    .foregroundColor(category.color)
                            }
                            Text(category.name)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                if availableCategories.isEmpty {
                    Text("所有支出分类都已设置预算")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("添加预算")
            }
        }
        .navigationTitle("月度预算")
        .sheet(item: $editingBudget) { budget in
            BudgetEditView(budget: budget) { limit in
                budget.monthlyLimit = limit
                try? modelContext.save()
            }
        }
        .alert("删除预算", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let budget = budgetToDelete {
                    modelContext.delete(budget)
                    try? modelContext.save()
                }
            }
        } message: {
            if let budget = budgetToDelete, let cat = budget.category {
                Text("确定要删除「\(cat.name)」的月度预算吗？")
            }
        }
    }

    private var categoriesWithBudget: Set<UUID> {
        Set(budgets.compactMap { $0.category?.id })
    }

    private var availableCategories: [Category] {
        expenseCategories.filter { !categoriesWithBudget.contains($0.id) }
    }

    private func addBudget(for category: Category) {
        let budget = Budget(monthlyLimit: 0, category: category)
        modelContext.insert(budget)
        try? modelContext.save()
        editingBudget = budget
    }

    private func budgetRow(_ budget: Budget) -> some View {
        guard let category = budget.category else {
            return AnyView(EmptyView())
        }

        let spent = currentSpending(for: category)
        let limit = budget.monthlyLimit
        let progress = limit > 0 ? min(spent / limit, 1.0) : 0
        let isOverBudget = spent > limit && limit > 0

        return AnyView(
            VStack(spacing: 0) {
                Button {
                    editingBudget = budget
                } label: {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(category.color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: category.icon)
                                    .font(.system(size: 15))
                                    .foregroundColor(category.color)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.name)
                                    .font(.subheadline.weight(.medium))
                                Text(String(format: String(localized: "已花 ¥%@ / 预算 ¥%@"), spent.formattedAmount0, limit.formattedAmount0))
                                    .font(.caption)
                                    .foregroundColor(isOverBudget ? .red : .secondary)
                            }

                            Spacer()

                            if isOverBudget {
                                Text("超支")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Progress bar
                        if limit > 0 {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            isOverBudget
                                                ? Color.red
                                                : progress > 0.8
                                                    ? Color.orange
                                                    : category.color
                                        )
                                        .frame(width: geo.size.width * progress, height: 6)
                                        .animation(.easeOut(duration: 0.5), value: progress)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        )
    }
}

// MARK: - BudgetEditView

struct BudgetEditView: View {
    @Environment(\.dismiss) private var dismiss
    let budget: Budget
    let onSave: (Double) -> Void

    @State private var limitText: String

    init(budget: Budget, onSave: @escaping (Double) -> Void) {
        self.budget = budget
        self.onSave = onSave
        _limitText = State(initialValue: budget.monthlyLimit > 0
            ? String(format: "%.0f", budget.monthlyLimit)
            : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("¥")
                            .foregroundColor(.secondary)
                        TextField("预算金额", text: $limitText)
                            .keyboardType(.numberPad)
                            .font(.title2.weight(.semibold))
                    }
                } header: {
                    Text("每月预算")
                } footer: {
                    if let limit = Double(limitText), limit > 0 {
                        Text(String(format: String(localized: "「%@」分类每月消费上限 ¥%@"), budget.category?.name ?? "", limit.formattedAmount0))
                    }
                }
            }
            .navigationTitle("设置预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let limit = Double(limitText) ?? 0
                        onSave(limit)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BudgetManageView()
            .modelContainer(for: [Budget.self, Category.self, Transaction.self], inMemory: true)
    }
}
