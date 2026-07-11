//
//  DataSeeder.swift
//  YouShu
//

import Foundation
import SwiftData

enum DataSeeder {
    private static let hasSeededKey = "com.gongdexin.paul.YouShu.hasSeededDefaults"
    private static let hasDedupedKey = "com.gongdexin.paul.YouShu.hasDedupedCategories"

    static func seedIfNeeded(modelContext: ModelContext) {
        // Deduplicate existing data (one-time cleanup)
        if !UserDefaults.standard.bool(forKey: hasDedupedKey) {
            deduplicateCategories(modelContext: modelContext)
            UserDefaults.standard.set(true, forKey: hasDedupedKey)
        }

        guard !UserDefaults.standard.bool(forKey: hasSeededKey) else { return }

        seedCategoriesIfNeeded(modelContext: modelContext)
        seedDefaultAccountIfNeeded(modelContext: modelContext)

        UserDefaults.standard.set(true, forKey: hasSeededKey)
    }

    /// Remove duplicate categories with the same name + type, keeping only one copy.
    private static func deduplicateCategories(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\Category.createdAt)])
        guard let allCategories = try? modelContext.fetch(descriptor) else { return }

        var seen: [String: Category] = [:]  // key = "name|type"
        var toDelete: [Category] = []

        for cat in allCategories {
            let key = "\(cat.name)|\(cat.typeRaw)"
            if seen[key] != nil {
                toDelete.append(cat)
            } else {
                seen[key] = cat
            }
        }

        guard !toDelete.isEmpty else { return }
        for cat in toDelete {
            modelContext.delete(cat)
        }
        try? modelContext.save()
    }

    // MARK: - Categories

    static func presetExpenseCategories() -> [(name: String, icon: String, colorHex: String)] {
        [
            ("餐饮", "fork.knife", "#FF6B35"),
            ("交通", "car.fill", "#4A90D9"),
            ("购物", "cart.fill", "#AF52DE"),
            ("居住", "house.fill", "#8B6914"),
            ("娱乐", "gamecontroller.fill", "#FF3B30"),
            ("医疗", "cross.case.fill", "#FF6B8A"),
            ("教育", "book.fill", "#5856D6"),
            ("其他", "ellipsis.circle.fill", "#8E8E93"),
        ]
    }

    static func presetIncomeCategories() -> [(name: String, icon: String, colorHex: String)] {
        [
            ("工资", "banknote.fill", "#34C759"),
            ("红包/礼金", "gift.fill", "#FF3B30"),
            ("其他", "ellipsis.circle.fill", "#8E8E93"),
        ]
    }

    private static func seedCategoriesIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        guard let count = try? modelContext.fetchCount(descriptor), count == 0 else {
            return
        }

        // Seed expense categories
        for (index, cat) in presetExpenseCategories().enumerated() {
            let category = Category(
                name: cat.name,
                icon: cat.icon,
                colorHex: cat.colorHex,
                type: .expense,
                sortOrder: index,
                isPreset: true
            )
            modelContext.insert(category)
        }

        // Seed income categories
        for (index, cat) in presetIncomeCategories().enumerated() {
            let category = Category(
                name: cat.name,
                icon: cat.icon,
                colorHex: cat.colorHex,
                type: .income,
                sortOrder: index,
                isPreset: true
            )
            modelContext.insert(category)
        }

        try? modelContext.save()
    }

    // MARK: - Default Account

    private static func seedDefaultAccountIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Account>()
        guard let count = try? modelContext.fetchCount(descriptor), count == 0 else {
            return
        }

        let cashAccount = Account(
            name: "现金",
            icon: "yensign.circle.fill",
            balance: 0,
            isDefault: true
        )
        modelContext.insert(cashAccount)
        try? modelContext.save()
    }
}
