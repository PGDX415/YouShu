//
//  CategoryManageView.swift
//  YouShu
//

import SwiftUI
import SwiftData

struct CategoryManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Category.typeRaw), SortDescriptor(\Category.sortOrder)]) private var categories: [Category]

    @State private var showAddSheet = false
    @State private var editingCategory: Category?
    @State private var showDeleteAlert = false
    @State private var categoryToDelete: Category?

    private var expenseCategories: [Category] {
        categories.filter { $0.type == .expense }
    }

    private var incomeCategories: [Category] {
        categories.filter { $0.type == .income }
    }

    var body: some View {
        List {
            Section("支出分类") {
                ForEach(expenseCategories) { category in
                    categoryRow(category)
                }
                addButton(type: .expense)
            }

            Section("收入分类") {
                ForEach(incomeCategories) { category in
                    categoryRow(category)
                }
                addButton(type: .income)
            }
        }
        .navigationTitle("分类管理")
        .sheet(isPresented: $showAddSheet) {
            CategoryEditView(mode: .add) { newCategory in
                modelContext.insert(newCategory)
                try? modelContext.save()
            }
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditView(mode: .edit(category)) { updatedCategory in
                category.name = updatedCategory.name
                category.icon = updatedCategory.icon
                category.colorHex = updatedCategory.colorHex
                category.typeRaw = updatedCategory.typeRaw
                try? modelContext.save()
            }
        }
        .alert("删除分类", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let cat = categoryToDelete {
                    modelContext.delete(cat)
                    try? modelContext.save()
                }
            }
        } message: {
            Text("删除后该分类下的交易将变为「未分类」。")
        }
    }

    private func categoryRow(_ category: Category) -> some View {
        Button {
            editingCategory = category
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: category.icon)
                        .font(.system(size: 15))
                        .foregroundColor(category.color)
                }

                Text(category.name)
                    .foregroundColor(.primary)

                Spacer()

                if category.isPreset {
                    Text("预设")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing) {
            if !category.isPreset {
                Button(role: .destructive) {
                    categoryToDelete = category
                    showDeleteAlert = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }

    private func addButton(type: TransactionType) -> some View {
        Button {
            let category = Category(
                name: "新分类",
                icon: "tag.fill",
                colorHex: "#8E8E93",
                type: type,
                sortOrder: categories.filter { $0.type == type }.count,
                isPreset: false
            )
            modelContext.insert(category)
            try? modelContext.save()
            editingCategory = category
        } label: {
            Label(String(format: String(localized: "添加 %@ 分类"), type.displayName), systemImage: "plus.circle")
        }
    }
}

// MARK: - Edit Mode

enum CategoryEditMode {
    case add
    case edit(Category)
}

// MARK: - CategoryEditView

struct CategoryEditView: View {
    @Environment(\.dismiss) private var dismiss
    let mode: CategoryEditMode
    let onSave: (Category) -> Void

    @State private var name: String
    @State private var icon: String
    @State private var colorHex: String
    @State private var type: TransactionType

    private var isNew: Bool {
        if case .add = mode { return true }
        return false
    }

    init(mode: CategoryEditMode, onSave: @escaping (Category) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _icon = State(initialValue: "tag.fill")
            _colorHex = State(initialValue: "#8E8E93")
            _type = State(initialValue: .expense)
        case .edit(let cat):
            _name = State(initialValue: cat.name)
            _icon = State(initialValue: cat.icon)
            _colorHex = State(initialValue: cat.colorHex)
            _type = State(initialValue: cat.type)
        }
    }

    private let iconOptions: [String] = [
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        "car.fill", "bus.fill", "airplane", "bicycle", "fuelpump.fill",
        "cart.fill", "bag.fill", "creditcard.fill", "banknote.fill",
        "house.fill", "bed.double.fill", "bolt.fill", "wrench.fill",
        "gamecontroller.fill", "tv.fill", "film.fill", "music.note",
        "cross.case.fill", "heart.fill", "pills.fill", "bandage.fill",
        "book.fill", "pencil", "graduationcap.fill", "backpack.fill",
        "gift.fill", "party.popper.fill", "balloon.fill",
        "dog.fill", "cat.fill", "leaf.fill", "flame.fill",
        "phone.fill", "laptopcomputer", "camera.fill", "wifi",
        "figure.walk", "figure.run", "dumbbell.fill", "sportscourt.fill",
        "tshirt.fill", "scissors", "paintbrush.fill", "hammer.fill",
        "ellipsis.circle.fill", "tag.fill", "star.fill"
    ]

    private let colorOptions: [(hex: String, name: String)] = [
        ("#FF6B35", "橙色"), ("#4A90D9", "蓝色"), ("#AF52DE", "紫色"),
        ("#8B6914", "棕色"), ("#FF3B30", "红色"), ("#34C759", "绿色"),
        ("#FF6B8A", "粉色"), ("#5856D6", "靛蓝"), ("#8E8E93", "灰色"),
        ("#FFD60A", "黄色"), ("#00C7BE", "青绿"), ("#FF9F0A", "橘红"),
    ]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview
                    previewSection

                    // Name
                    nameField

                    // Type picker (new only)
                    if isNew {
                        typePicker
                    }

                    // Icon picker
                    iconPickerSection

                    // Color picker
                    colorPickerSection
                }
                .padding()
            }
            .navigationTitle(isNew ? "新建分类" : "编辑分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        let category: Category
                        switch mode {
                        case .add:
                            category = Category(name: name.trimmingCharacters(in: .whitespaces), icon: icon, colorHex: colorHex, type: type)
                        case .edit(let existing):
                            category = existing
                        }
                        category.name = name.trimmingCharacters(in: .whitespaces)
                        category.icon = icon
                        category.colorHex = colorHex
                        category.type = type
                        onSave(category)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex).opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(Color(hex: colorHex))
            }

            Text(name.isEmpty ? "分类名称" : name)
                .font(.headline)
                .foregroundColor(name.isEmpty ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Name

    private var nameField: some View {
        HStack {
            Text("名称")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("分类名称", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Type

    private var typePicker: some View {
        HStack {
            Text("类型")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Picker("类型", selection: $type) {
                ForEach(TransactionType.allCases, id: \.self) { t in
                    Text(t.displayName).tag(t)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Icon Picker

    private var iconPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图标")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                ForEach(iconOptions, id: \.self) { iconName in
                    Button {
                        icon = iconName
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(icon == iconName ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                                .frame(width: 36, height: 36)
                            Image(systemName: iconName)
                                .font(.system(size: 14))
                                .foregroundColor(icon == iconName ? Color.accentColor : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Color Picker

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("颜色")
                .font(.subheadline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(colorOptions, id: \.hex) { option in
                    Button {
                        colorHex = option.hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: option.hex))
                                .frame(width: 40, height: 40)
                            if colorHex == option.hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryManageView()
            .modelContainer(for: [Category.self], inMemory: true)
    }
}
