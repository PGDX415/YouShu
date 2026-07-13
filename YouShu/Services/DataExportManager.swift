//
//  DataExportManager.swift
//  YouShu
//
//  完整 JSON 导出 / 合并去重导入
//

import Foundation
import SwiftData
import SwiftUI
import Combine

// MARK: - Export Models (Codable)

struct ExportData: Codable {
    let version: Int
    let exportDate: String
    let categories: [ExportCategory]
    let accounts: [ExportAccount]
    let transactions: [ExportTransaction]
    let budgets: [ExportBudget]
}

struct ExportCategory: Codable {
    let name: String
    let icon: String
    let colorHex: String
    let typeRaw: String
    let sortOrder: Int
    let isPreset: Bool
}

struct ExportAccount: Codable {
    let name: String
    let icon: String
    let balance: Double
    let isDefault: Bool
}

struct ExportTransaction: Codable {
    let id: String
    let amount: Double
    let typeRaw: String
    let date: Date
    let note: String
    let categoryName: String?
    let categoryType: String?
    let accountName: String?
}

struct ExportBudget: Codable {
    let categoryName: String
    let categoryType: String
    let monthlyLimit: Double
}

// MARK: - Export Manager

@MainActor
final class DataExportManager: ObservableObject {
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var lastMessage: String?

    // MARK: - Export

    func exportData(from context: ModelContext) -> URL? {
        isExporting = true
        defer { isExporting = false }

        let allCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let allAccounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let allTransactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let allBudgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []

        let export = ExportData(
            version: 1,
            exportDate: ISO8601DateFormatter().string(from: Date()),
            categories: allCategories.map { ExportCategory(
                name: $0.name, icon: $0.icon, colorHex: $0.colorHex,
                typeRaw: $0.typeRaw, sortOrder: $0.sortOrder, isPreset: $0.isPreset
            )},
            accounts: allAccounts.map { ExportAccount(
                name: $0.name, icon: $0.icon, balance: $0.balance, isDefault: $0.isDefault
            )},
            transactions: allTransactions.map { ExportTransaction(
                id: $0.id.uuidString, amount: $0.amount, typeRaw: $0.typeRaw,
                date: $0.date, note: $0.note,
                categoryName: $0.category?.name, categoryType: $0.category?.typeRaw,
                accountName: $0.account?.name
            )},
            budgets: allBudgets.compactMap { budget in
                guard let cat = budget.category else { return nil }
                return ExportBudget(
                    categoryName: cat.name, categoryType: cat.typeRaw,
                    monthlyLimit: budget.monthlyLimit
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(export) else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Locale.preferredLanguages.first ?? "zh-Hans")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let url = tempDir.appendingPathComponent("youshu_backup_\(timestamp).json")

        try? data.write(to: url)
        return url
    }

    // MARK: - Import (merge-deduplicate)

    struct ImportResult {
        let categoriesAdded: Int
        let accountsAdded: Int
        let transactionsAdded: Int
        let budgetsAdded: Int
    }

    func importData(from url: URL, into context: ModelContext) -> ImportResult? {
        isImporting = true
        defer { isImporting = false }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: url),
              let export = try? decoder.decode(ExportData.self, from: data) else {
            return nil
        }

        let allCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let allAccounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let allTransactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let allBudgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []

        var catsAdded = 0
        var acctsAdded = 0
        var txnsAdded = 0
        var budgetsAdded = 0

        // --- Categories: dedup by (name, type) ---
        for ec in export.categories {
            if allCategories.contains(where: { $0.name == ec.name && $0.typeRaw == ec.typeRaw }) {
                continue
            }
            let cat = Category(
                name: ec.name, icon: ec.icon, colorHex: ec.colorHex,
                type: TransactionType(rawValue: ec.typeRaw) ?? .expense,
                sortOrder: ec.sortOrder, isPreset: ec.isPreset
            )
            context.insert(cat)
            catsAdded += 1
        }

        // --- Accounts: dedup by name ---
        let accountNames = Set(allAccounts.map { $0.name })
        for ea in export.accounts {
            if accountNames.contains(ea.name) { continue }
            let acc = Account(name: ea.name, icon: ea.icon, balance: ea.balance)
            acc.isDefault = ea.isDefault && allAccounts.isEmpty
            context.insert(acc)
            acctsAdded += 1
        }

        // Refresh after inserts so relationships resolve
        try? context.save()
        let updatedCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let updatedAccounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []

        // --- Transactions: dedup by UUID ---
        let existingIDs = Set(allTransactions.map { $0.id })
        for et in export.transactions {
            guard let uuid = UUID(uuidString: et.id), !existingIDs.contains(uuid) else {
                continue
            }
            let cat = et.categoryName.flatMap { name in
                updatedCategories.first { $0.name == name && $0.typeRaw == (et.categoryType ?? "") }
            }
            let acc = et.accountName.flatMap { name in
                updatedAccounts.first { $0.name == name }
            }

            let txn = Transaction(
                id: uuid, amount: et.amount,
                type: TransactionType(rawValue: et.typeRaw) ?? .expense,
                date: et.date, note: et.note,
                category: cat, account: acc
            )
            context.insert(txn)

            // Update account balance
            if let account = acc {
                account.balance += txn.signedAmount
            }

            txnsAdded += 1
        }

        // --- Budgets: dedup by (category name, type) ---
        for eb in export.budgets {
            if allBudgets.contains(where: {
                $0.category?.name == eb.categoryName && $0.category?.typeRaw == eb.categoryType
            }) {
                continue
            }
            guard let cat = updatedCategories.first(where: {
                $0.name == eb.categoryName && $0.typeRaw == eb.categoryType
            }) else {
                continue
            }
            let budget = Budget(monthlyLimit: eb.monthlyLimit, category: cat)
            context.insert(budget)
            budgetsAdded += 1
        }

        try? context.save()

        return ImportResult(
            categoriesAdded: catsAdded,
            accountsAdded: acctsAdded,
            transactionsAdded: txnsAdded,
            budgetsAdded: budgetsAdded
        )
    }
}
