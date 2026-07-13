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
                        BudgetManageView()
                    } label: {
                        Label("月度预算", systemImage: "chart.bar.doc.horizontal")
                    }

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
                    NavigationLink {
                        DataManageView()
                    } label: {
                        Label("数据管理", systemImage: "externaldrive")
                    }

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("隐私政策", systemImage: "hand.raised.fill")
                    }

                    HStack {
                        Label("版本", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("关于")
                }

                Section {
                    VStack(spacing: 8) {
                        Text("有数")
                            .font(.system(.title3, design: .serif).weight(.bold))
                        Text("有数，家的每一笔，心里有数")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    SettingsView()
}
