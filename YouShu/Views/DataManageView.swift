//
//  DataManageView.swift
//  YouShu
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

struct DataManageView: View {
    @Environment(\.modelContext) private var modelContext

    @StateObject private var manager = DataExportManager()
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportURL: URL?
    @State private var importResult: DataExportManager.ImportResult?
    @State private var showImportAlert = false
    @State private var importAlertMessage = ""
    @State private var notificationDenied = false

    @AppStorage("backupReminderEnabled") private var reminderEnabled: Bool = false

    var body: some View {
        List {
            // Export section
            Section {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Label("导出数据", systemImage: "square.and.arrow.up")
                        Spacer()
                        if manager.isExporting {
                            ProgressView()
                        }
                    }
                }
                .disabled(manager.isExporting)
            } header: {
                Text("备份")
            } footer: {
                Text("将所有记账数据（分类、账户、交易记录、预算）导出为 JSON 备份文件。可通过文件 App、邮件或微信保存。")
            }

            // Import section
            Section {
                Button {
                    showImporter = true
                } label: {
                    HStack {
                        Label("导入数据", systemImage: "square.and.arrow.down")
                        Spacer()
                        if manager.isImporting {
                            ProgressView()
                        }
                    }
                }
                .disabled(manager.isImporting)
            } header: {
                Text("恢复")
            } footer: {
                Text("选择之前导出的 JSON 备份文件。导入采用合并模式：已有数据不会重复，仅追加新增内容。")
            }

            // Weekly reminder
            Section {
                Toggle(isOn: $reminderEnabled) {
                    Label("每周备份提醒", systemImage: "bell.badge")
                }
                .onChange(of: reminderEnabled) { _, enabled in
                    if enabled {
                        requestNotificationPermission { granted in
                            if granted {
                                scheduleReminder()
                            } else {
                                notificationDenied = true
                                reminderEnabled = false
                            }
                        }
                    } else {
                        cancelReminder()
                    }
                }

                if notificationDenied {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("通知权限被拒绝，请在系统设置中开启通知。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

            } header: {
                Text("提醒")
            } footer: {
                Text("开启后，每周日 10:00 提醒你备份数据，防止数据丢失。测试时请切到后台等待通知。")
            }
        }
        .navigationTitle("数据管理")
        .fileExporter(
            isPresented: $showExporter,
            document: BackupDocument(url: exportURL),
            contentType: .json,
            defaultFilename: defaultFilename
        ) { result in
            exportURL = nil
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("导入完成", isPresented: $showImportAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(importAlertMessage)
        }
    }

    private var defaultFilename: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: Locale.preferredLanguages.first ?? "zh-Hans")
        f.dateFormat = "yyyyMMdd_HHmmss"
        return "youshu_backup_\(f.string(from: Date())).json"
    }

    // MARK: - Notification

    private func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    private func scheduleReminder() {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "有数 — 备份提醒"
        content.body = "已经一周了，记得导出备份数据，防止记账数据丢失。"
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1 // Sunday
        components.hour = 10
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "com.gongdexin.paul.youshu.backupReminder",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule reminder: \(error)")
            }
        }
    }

    private func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["com.gongdexin.paul.youshu.backupReminder"]
        )
    }

    private func exportData() {
        guard let url = manager.exportData(from: modelContext) else { return }
        exportURL = url
        showExporter = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let result = manager.importData(from: url, into: modelContext) else {
            importAlertMessage = "文件格式不正确或已损坏，请检查文件。"
            showImportAlert = true
            return
        }

        var parts: [String] = []
        if result.categoriesAdded > 0 { parts.append("\(result.categoriesAdded) 个分类") }
        if result.accountsAdded > 0 { parts.append("\(result.accountsAdded) 个账户") }
        if result.transactionsAdded > 0 { parts.append("\(result.transactionsAdded) 笔交易") }
        if result.budgetsAdded > 0 { parts.append("\(result.budgetsAdded) 个预算") }

        if parts.isEmpty {
            importAlertMessage = "没有新数据需要导入（全部已存在）。"
        } else {
            importAlertMessage = "成功导入：\n" + parts.joined(separator: "\n")
        }
        showImportAlert = true
    }
}

// MARK: - FileDocument for JSON export

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let url: URL?

    init(url: URL?) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        self.url = nil
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try FileWrapper(url: url)
    }
}

#Preview {
    NavigationStack {
        DataManageView()
            .modelContainer(for: [Transaction.self, Category.self, Account.self, Budget.self], inMemory: true)
    }
}
