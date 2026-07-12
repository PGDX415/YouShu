//
//  YouShuApp.swift
//  YouShu
//

import SwiftUI
import SwiftData

@main
struct YouShuApp: App {
    @State private var showSplash = true

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Transaction.self,
            Category.self,
            Account.self,
            FamilyLedger.self,
            FamilyMember.self,
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
                    ContentView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showSplash)
        }
        .modelContainer(sharedModelContainer)
    }
}
