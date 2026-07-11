//
//  SettingsView.swift
//  YouShu
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        FamilyView()
                    } label: {
                        Label("家庭共享", systemImage: "person.3.fill")
                    }
                } header: {
                    Text("家庭")
                }

                Section {
                    NavigationLink {
                        CategoryManageView()
                    } label: {
                        Label("分类管理", systemImage: "square.grid.2x2")
                    }

                    NavigationLink {
                        AccountManageView()
                    } label: {
                        Label("账户管理", systemImage: "wallet.pass")
                    }
                } header: {
                    Text("基础设置")
                }

                Section {
                    HStack {
                        Label("版本", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingsView()
}
