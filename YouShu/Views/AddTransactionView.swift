//
//  AddTransactionView.swift
//  YouShu
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @AppStorage("recentAmounts") private var recentAmountsJSON: String = "[]"

    @State private var amountText: String = ""
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var showOptionalFields: Bool = false
    @State private var showSaveAnimation: Bool = false

    @FocusState private var isAmountFocused: Bool

    private var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var canSave: Bool {
        amount > 0 && selectedCategory != nil
    }

    private var filteredCategories: [Category] {
        allCategories.filter { $0.type == selectedType }
    }

    // Recent amounts (last 5 unique, from UserDefaults)
    private var recentAmounts: [Double] {
        guard let data = recentAmountsJSON.data(using: .utf8),
              let arr = try? JSONDecoder().decode([Double].self, from: data) else {
            return []
        }
        return arr
    }

    // Recent categories derived from transaction history
    private var recentCategoriesForType: [Category] {
        var seen = Set<UUID>()
        var result: [Category] = []
        for tx in allTransactions.prefix(30) {
            if let cat = tx.category, cat.type == selectedType, !seen.contains(cat.id) {
                seen.insert(cat.id)
                result.append(cat)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Type Toggle
                    typeToggle

                    // MARK: - Recent Amounts
                    if !recentAmounts.isEmpty {
                        recentAmountsSection
                    }

                    // MARK: - Amount Input
                    amountInput

                    // MARK: - Recent Categories
                    if !recentCategoriesForType.isEmpty {
                        recentCategoriesSection
                    }

                    // MARK: - Category Picker
                    categoryPicker

                    // MARK: - Optional Fields
                    optionalFieldsSection

                    // MARK: - Save Button
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isAmountFocused = true
                selectedAccount = accounts.first(where: { $0.isDefault }) ?? accounts.first
            }
            .overlay {
                if showSaveAnimation {
                    saveSuccessOverlay
                }
            }
        }
    }

    // MARK: - Recent Amounts

    private var recentAmountsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("最近金额")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(recentAmounts.enumerated()), id: \.offset) { _, value in
                        Button {
                            amountText = String(format: "%.0f", value)
                            isAmountFocused = false
                        } label: {
                            Text("¥\(String(format: "%.0f", value))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Recent Categories

    private var recentCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近使用")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                ForEach(recentCategoriesForType.prefix(5)) { category in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            selectedCategory = category
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    selectedCategory?.id == category.id
                                        ? category.color
                                        : category.color.opacity(0.15)
                                )
                                .frame(width: 40, height: 40)
                            Image(systemName: category.icon)
                                .font(.system(size: 16))
                                .foregroundColor(
                                    selectedCategory?.id == category.id
                                        ? .white
                                        : category.color
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Type Toggle

    private var typeToggle: some View {
        HStack(spacing: 0) {
            ForEach(TransactionType.allCases, id: \.self) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedType = type
                        if let first = filteredCategories.first {
                            selectedCategory = first
                        } else {
                            selectedCategory = nil
                        }
                    }
                } label: {
                    Text(type.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedType == type
                                ? (type == .expense ? Color.red : Color.green)
                                : Color.clear
                        )
                        .foregroundColor(selectedType == type ? .white : .primary)
                }
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    // MARK: - Amount Input

    private var amountInput: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("¥")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(selectedType == .expense ? .red : .green)

                TextField("0.00", text: $amountText)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .focused($isAmountFocused)
                    .onChange(of: amountText) { _, newValue in
                        // Filter to allow only valid decimal input
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        // Ensure only one decimal point
                        let parts = filtered.components(separatedBy: ".")
                        if parts.count > 2 {
                            amountText = parts[0] + "." + parts.dropFirst().joined()
                        } else {
                            amountText = filtered
                        }
                    }
            }
            .padding(.vertical, 8)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4))
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择分类")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                spacing: 16
            ) {
                ForEach(filteredCategories) { category in
                    categoryButton(category)
                }
            }
        }
    }

    private func categoryButton(_ category: Category) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                selectedCategory = category
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            selectedCategory?.id == category.id
                                ? category.color
                                : category.color.opacity(0.15)
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: category.icon)
                        .font(.system(size: 22))
                        .foregroundColor(
                            selectedCategory?.id == category.id
                                ? .white
                                : category.color
                        )
                }
                .scaleEffect(selectedCategory?.id == category.id ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedCategory?.id)

                Text(category.name)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Optional Fields

    private var optionalFieldsSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showOptionalFields.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "ellipsis.circle")
                    Text("更多选项（可选）")
                    Spacer()
                    Image(systemName: showOptionalFields ? "chevron.up" : "chevron.down")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            if showOptionalFields {
                VStack(spacing: 16) {
                    Divider()
                        .padding(.top, 8)

                    // Note
                    HStack {
                        Image(systemName: "pencil.line")
                            .frame(width: 24)
                            .foregroundColor(.secondary)
                        TextField("备注", text: $note)
                            .font(.body)
                    }

                    // Account
                    HStack {
                        Image(systemName: "wallet.pass")
                            .frame(width: 24)
                            .foregroundColor(.secondary)
                        Picker("账户", selection: $selectedAccount) {
                            Text("无").tag(nil as Account?)
                            ForEach(accounts) { account in
                                Text(account.name).tag(account as Account?)
                            }
                        }
                        .pickerStyle(.menu)
                        Spacer()
                        if let acc = selectedAccount {
                            Text(acc.name)
                                .foregroundColor(.primary)
                        } else {
                            Text("不选择")
                                .foregroundColor(.secondary)
                        }
                    }

                    // Date
                    HStack {
                        Image(systemName: "calendar")
                            .frame(width: 24)
                            .foregroundColor(.secondary)
                        DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                        Spacer()
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            saveTransaction()
        } label: {
            Text("完成")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canSave ? Color.accentColor : Color(.systemGray4))
                )
        }
        .disabled(!canSave)
        .padding(.top, 8)
    }

    // MARK: - Save

    private func saveTransaction() {
        guard canSave else { return }

        let transaction = Transaction(
            amount: amount,
            type: selectedType,
            date: date,
            note: note.trimmingCharacters(in: .whitespaces),
            category: selectedCategory,
            account: selectedAccount
        )
        modelContext.insert(transaction)

        // Update account balance
        if let account = selectedAccount {
            account.balance += transaction.signedAmount
        }

        try? modelContext.save()

        // Persist recent amount
        saveRecentAmount(amount)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Show success animation then dismiss
        showSaveAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            dismiss()
        }
    }

    private func saveRecentAmount(_ newAmount: Double) {
        var amounts = recentAmounts
        amounts.removeAll { $0 == newAmount }
        amounts.insert(newAmount, at: 0)
        let trimmed = Array(amounts.prefix(5))
        if let data = try? JSONEncoder().encode(trimmed),
           let json = String(data: data, encoding: .utf8) {
            recentAmountsJSON = json
        }
    }

    // MARK: - Save Success Overlay

    private var saveSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)

                Text("已记录")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)

                Text("¥\(String(format: "%.2f", amount))")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .transition(.opacity)
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(for: [Transaction.self, Category.self, Account.self], inMemory: true)
}
