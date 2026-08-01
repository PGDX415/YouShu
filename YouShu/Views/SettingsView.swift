//
//  SettingsView.swift
//  YouShu
//

import SwiftUI
import SwiftData
import LocalAuthentication

struct SettingsView: View {
    @AppStorage("appLockEnabled") private var lockEnabled: Bool = false
    @AppStorage("appAppearance") private var appearance: Appearance = .system
    @AppStorage("appPasscode") private var appPasscode: String = ""
    @AppStorage("lockMethod") private var lockMethodRaw: Int = 0
    @State private var showPasscodeSetup = false

    enum Appearance: Int, CaseIterable {
        case system = 0
        case light = 1
        case dark = 2

        var label: String {
            switch self {
            case .system: return "跟随系统"
            case .light:  return "浅色模式"
            case .dark:   return "深色模式"
            }
        }

        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.striped.horizontal"
            case .light:  return "sun.max"
            case .dark:   return "moon"
            }
        }
    }

    private var biometryIcon: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.shield"
        }
    }

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
                    Toggle(isOn: $lockEnabled) {
                        Label("应用锁", systemImage: biometryIcon)
                    }

                    if lockEnabled {
                        Button {
                            showPasscodeSetup = true
                        } label: {
                            HStack {
                                Label(appPasscode.isEmpty ? "设置 App 密码" : "修改 App 密码",
                                      systemImage: "key.fill")
                                Spacer()
                                if !appPasscode.isEmpty {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                } header: {
                    Text("安全")
                }
                .sheet(isPresented: $showPasscodeSetup) {
                    PasscodeSetupView()
                }

                Section {
                    Picker(selection: $appearance) {
                        ForEach(Appearance.allCases, id: \.self) { mode in
                            Label(mode.label, systemImage: mode.icon)
                                .tag(mode)
                        }
                    } label: {
                        Label("外观模式", systemImage: appearance.icon)
                    }

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
                        HelpView()
                    } label: {
                        Label("使用指南", systemImage: "questionmark.circle")
                    }

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
