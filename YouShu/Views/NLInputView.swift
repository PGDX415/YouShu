//
//  NLInputView.swift
//  YouShu
//

import SwiftUI
import SwiftData

struct NLInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var members: [FamilyMember]
    @AppStorage("defaultExpenseCategoryID") private var defaultExpenseCategoryID: String = ""
    @AppStorage("defaultIncomeCategoryID") private var defaultIncomeCategoryID: String = ""

    @State private var inputText: String = ""
    @State private var showSaveAnimation: Bool = false
    @State private var showReceiptScanner = false
    @FocusState private var isFocused: Bool

    private var currentMember: FamilyMember? {
        members.first(where: { $0.role == .creator })
    }

    private var parsed: ParsedTransaction {
        NLTransactionParser.parse(inputText, categories: categories, accounts: accounts)
    }

    private var isReadyToSave: Bool {
        parsed.amount != nil && parsed.type != nil
    }

    private let examples = [
        "午饭花了35元",
        "工资到账15000块",
        "给老婆转了2000",
        "打车去公司32元",
        "淘宝买了双鞋花了299",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Input area
                inputSection

                // Parsed result
                if !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                    resultCard
                } else {
                    examplesSection
                }

                Spacer()
            }
            .navigationTitle("智能记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("记账") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isReadyToSave)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("完成") { isFocused = false }
                    }
                }
            }
            .onAppear { isFocused = true }
            .sheet(isPresented: $showReceiptScanner) {
                ReceiptScanView()
            }
            .overlay {
                if showSaveAnimation {
                    saveOverlay
                }
            }
        }
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)

                TextField("说说今天花了什么...", text: $inputText, axis: .vertical)
                    .font(.system(size: 18))
                    .focused($isFocused)
                    .lineLimit(1...3)
                    .autocorrectionDisabled(false)

                Button {
                    showReceiptScanner = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack {
                Button {
                    if let text = UIPasteboard.general.string, !text.isEmpty {
                        inputText = text
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.caption)
                        Text("粘贴剪贴板内容")
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }

                Spacer()

                if !inputText.isEmpty {
                    Button {
                        inputText = ""
                    } label: {
                        Text("清空").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Examples

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("试试这样说", systemImage: "lightbulb.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            ForEach(examples, id: \.self) { example in
                Button {
                    inputText = example
                } label: {
                    HStack {
                        Image(systemName: "text.bubble")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        Text(example)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    // MARK: - Result Card

    private var resultCard: some View {
        VStack(spacing: 0) {
            HStack {
                Label("识别结果", systemImage: "sparkles")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
                if let type = parsed.type {
                    typeBadge(type)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            VStack(spacing: 12) {
                // Amount
                amountRow

                Divider()

                // Category
                categoryRow

                // Account
                if let acc = parsed.account {
                    accountRow(acc)
                } else if parsed.type != .transfer {
                    noAccountRow
                }

                // Destination account (transfer)
                if let dest = parsed.destinationAccount {
                    destAccountRow(dest)
                }

                // Note
                if let note = parsed.note, !note.isEmpty {
                    noteRow(note)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var amountRow: some View {
        HStack {
            Image(systemName: "yensign.circle.fill")
                .foregroundColor(amountColor)
                .font(.title3)
            Text("金额")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if let amount = parsed.amount {
                Text("¥\(amount.formattedAmount)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundColor(amountColor)
                    .scaleEffect(showSaveAnimation ? 0 : 1)
                    .animation(.spring(response: 0.3), value: showSaveAnimation)
            } else {
                Text("未识别")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var amountColor: Color {
        switch parsed.type {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .blue
        default: return .primary
        }
    }

    private var categoryRow: some View {
        HStack {
            Image(systemName: "square.grid.2x2")
                .foregroundColor(.accentColor)
            Text("分类")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if let cat = parsed.category {
                HStack(spacing: 6) {
                    Image(systemName: cat.icon)
                        .font(.caption)
                        .foregroundColor(cat.color)
                    Text(cat.name)
                        .font(.subheadline.weight(.medium))
                }
            } else {
                Text(parsed.type == .transfer ? "转账" : "未识别")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func accountRow(_ acc: Account) -> some View {
        HStack {
            Image(systemName: "wallet.pass")
                .foregroundColor(.accentColor)
            Text("账户")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: acc.icon)
                    .font(.caption)
                Text(acc.name)
                    .font(.subheadline.weight(.medium))
            }
        }
    }

    private var noAccountRow: some View {
        HStack {
            Image(systemName: "wallet.pass")
                .foregroundColor(.secondary.opacity(0.5))
            Text("账户")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text("默认账户")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func destAccountRow(_ dest: Account) -> some View {
        HStack {
            Image(systemName: "arrow.right.circle")
                .foregroundColor(.accentColor)
            Text("转入")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: dest.icon)
                    .font(.caption)
                Text(dest.name)
                    .font(.subheadline.weight(.medium))
            }
        }
    }

    private func noteRow(_ note: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "pencil.line")
                .foregroundColor(.secondary.opacity(0.6))
            Text("备注")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(note)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.primary)
        }
    }

    private func typeBadge(_ type: TransactionType) -> some View {
        Text(type.displayName)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                type == .expense ? Color.red
                : type == .income ? Color.green
                : Color.blue
            )
            .clipShape(Capsule())
    }

    // MARK: - Save

    private func save() {
        guard isReadyToSave, let amount = parsed.amount, let type = parsed.type else { return }

        let category: Category? = {
            if type == .transfer { return nil }
            return parsed.category
        }()

        let account: Account? = {
            parsed.account ?? accounts.first(where: { $0.isDefault }) ?? accounts.first
        }()

        let destAccount: Account? = {
            type == .transfer ? parsed.destinationAccount : nil
        }()

        let transaction = Transaction(
            amount: amount,
            type: type,
            date: Date(),
            note: parsed.note ?? "",
            category: category,
            account: account,
            destinationAccount: destAccount,
            createdByMember: currentMember
        )
        modelContext.insert(transaction)

        // Update balances
        if type == .transfer {
            if let src = account { src.balance -= abs(amount) }
            if let dest = destAccount { dest.balance += abs(amount) }
        } else if let acc = account {
            acc.balance += transaction.signedAmount
        }

        // Persist default category
        if type != .transfer, let cat = category {
            let idString = cat.id.uuidString
            if type == .expense {
                defaultExpenseCategoryID = idString
            } else {
                defaultIncomeCategoryID = idString
            }
        }

        try? modelContext.save()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        showSaveAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            dismiss()
        }
    }

    // MARK: - Save Overlay

    private var saveOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
                Text("已记录")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                if let amount = parsed.amount {
                    Text("¥\(amount.formattedAmount)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .transition(.opacity)
    }
}

#Preview {
    NLInputView()
        .modelContainer(for: [Transaction.self, Category.self, Account.self], inMemory: true)
}
