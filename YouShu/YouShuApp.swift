//
//  YouShuApp.swift
//  YouShu
//

import SwiftUI
import SwiftData
import CloudKit

@main
struct YouShuApp: App {
    @AppStorage("appLockEnabled") private var appLockEnabled: Bool = false
    @State private var showSplash = true
    @State private var shareAcceptError: String?

    private var systemLocale: Locale {
        Locale(identifier: Locale.preferredLanguages.first ?? "zh-Hans")
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Transaction.self,
            Category.self,
            Account.self,
            FamilyLedger.self,
            FamilyMember.self,
            Budget.self,
        ])

        let cloudKitContainerID = "iCloud.com.gongdexin.paul.YouShu"

        let config = ModelConfiguration(
            "YouShuStore",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(cloudKitContainerID)
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            Task { @MainActor in
                DataSeeder.seedIfNeeded(modelContext: container.mainContext)
                DataSeeder.observeCloudKitImports(modelContext: container.mainContext)
            }
            return container
        } catch {
            print("⚠️ Failed to load CloudKit store, attempting local fallback: \(error)")
            let localConfig = ModelConfiguration("YouShuStore", schema: schema)
            do {
                let container = try ModelContainer(for: schema, configurations: [localConfig])
                Task { @MainActor in
                    DataSeeder.seedIfNeeded(modelContext: container.mainContext)
                }
                return container
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView(isActive: $showSplash)
                        .transition(.opacity)
                } else {
                    AppLockedContent(lockEnabled: appLockEnabled) {
                        ContentView()
                            .environment(\.locale, systemLocale)
                            .environment(\.calendar, Calendar.current)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showSplash)
            .onOpenURL { url in
                handleShareURL(url)
            }
            .alert("加入失败", isPresented: .constant(shareAcceptError != nil)) {
                Button("确定") { shareAcceptError = nil }
            } message: {
                Text(shareAcceptError ?? "")
            }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - CKShare Acceptance

    private func handleShareURL(_ url: URL) {
        let container = CKContainer(identifier: "iCloud.com.gongdexin.paul.YouShu")

        // First, fetch the share metadata from the URL
        let fetchOp = CKFetchShareMetadataOperation(shareURLs: [url])
        var fetchedMetadata: CKShare.Metadata?

        fetchOp.perShareMetadataResultBlock = { _, result in
            switch result {
            case .success(let metadata):
                fetchedMetadata = metadata
            case .failure(let error):
                DispatchQueue.main.async {
                    shareAcceptError = "无法获取共享信息：\(error.localizedDescription)"
                }
            }
        }

        fetchOp.fetchShareMetadataResultBlock = { _ in
            guard let metadata = fetchedMetadata else { return }

            let acceptOp = CKAcceptSharesOperation(shareMetadatas: [metadata])
            acceptOp.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    print("✅ CKShare accepted")
                case .failure(let error):
                    DispatchQueue.main.async {
                        shareAcceptError = "加入家庭账本失败：\(error.localizedDescription)"
                    }
                }
            }
            container.add(acceptOp)
        }

        container.add(fetchOp)
    }
}

// MARK: - App Lock Wrapper

private struct AppLockedContent<Content: View>: View {
    let lockEnabled: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.scenePhase) private var scenePhase
    @State private var isAuthenticated: Bool = false
    @State private var needsAuth: Bool = true

    var body: some View {
        ZStack {
            content()
                .opacity(isAuthenticated || !lockEnabled ? 1 : 0)

            if lockEnabled && !isAuthenticated {
                LockView {
                    isAuthenticated = true
                }
            }
        }
        .onAppear {
            if lockEnabled {
                isAuthenticated = false
                needsAuth = true
            } else {
                isAuthenticated = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard lockEnabled else { return }
            if phase == .background {
                isAuthenticated = false
            }
        }
    }
}
