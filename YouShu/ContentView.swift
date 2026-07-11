//
//  ContentView.swift
//  YouShu
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home = "首页"
        case reports = "报表"
        case settings = "设置"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .reports: return "chart.bar.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPhone Layout (TabView)

    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label(Tab.home.rawValue, systemImage: Tab.home.icon) }
                .tag(Tab.home)

            ReportsView()
                .tabItem { Label(Tab.reports.rawValue, systemImage: Tab.reports.icon) }
                .tag(Tab.reports)

            SettingsView()
                .tabItem { Label(Tab.settings.rawValue, systemImage: Tab.settings.icon) }
                .tag(Tab.settings)
        }
    }

    // MARK: - iPad Layout (NavigationSplitView)

    private var iPadLayout: some View {
        NavigationSplitView {
            List {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .foregroundColor(selectedTab == tab ? .accentColor : .primary)
                    }
                    .listRowBackground(
                        selectedTab == tab
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear
                    )
                }
            }
            .navigationTitle("有数")
        } detail: {
            switch selectedTab {
            case .home:
                HomeView()
            case .reports:
                ReportsView()
            case .settings:
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Transaction.self, Category.self, Account.self], inMemory: true)
}
