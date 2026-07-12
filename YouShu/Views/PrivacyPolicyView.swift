//
//  PrivacyPolicyView.swift
//  YouShu
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("隐私政策")
                    .font(.title2.weight(.bold))
                    .padding(.top, 8)

                Text("最后更新日期：2026 年 7 月 12 日")
                    .font(.caption)
                    .foregroundColor(.secondary)

                privacySection(
                    title: "信息收集",
                    body: """
                    有数 是一款本地优先的家庭记账应用。你的所有财务数据（交易记录、分类、账户、预算等）默认存储在设备本地和你的个人 iCloud 账户中。

                    我们不会收集、上传或存储你的任何个人数据到开发者服务器。所有数据同步均通过 Apple iCloud（CloudKit）完成，数据仅在你授权的 iCloud 账户内的设备间同步。
                    """
                )

                privacySection(
                    title: "数据存储与安全",
                    body: """
                    • 本地存储：所有数据存储在设备本地 SQLite 数据库中。
                    • iCloud 同步：数据通过 Apple CloudKit 在你的 iCloud 账户设备间同步，采用 Apple 提供的端到端加密。
                    • 家庭共享：当你邀请家庭成员共享账本时，共享数据通过 CloudKit CKShare 机制传输，仅有被邀请的成员可以访问共享账本。
                    • 开发者无法访问你的任何数据。
                    """
                )

                privacySection(
                    title: "数据使用",
                    body: """
                    你的数据仅用于以下目的：
                    • 在应用中展示和管理你的财务记录
                    • 通过 iCloud 在你授权的设备间同步
                    • 通过家庭共享功能与家庭成员共享账本数据

                    我们不会将你的数据用于广告、分析、追踪或任何商业目的。
                    """
                )

                privacySection(
                    title: "第三方服务",
                    body: """
                    本应用使用 Apple CloudKit 作为数据同步服务。CloudKit 的使用受 Apple 隐私政策约束。

                    本应用不使用任何第三方分析、广告或追踪 SDK。
                    """
                )

                privacySection(
                    title: "用户权利",
                    body: """
                    你拥有对数据的完全控制权：
                    • 随时在设备上查看、编辑或删除任何数据
                    • 删除应用即可移除所有本地数据
                    • 通过 iCloud 设置管理云端数据
                    • 随时退出家庭共享账本
                    """
                )

                privacySection(
                    title: "儿童隐私",
                    body: """
                    本应用不针对 13 岁以下儿童设计，我们不会有意收集儿童的个人信息。
                    """
                )

                privacySection(
                    title: "政策变更",
                    body: """
                    我们可能会不时更新本隐私政策。如有重大变更，我们会在应用中通知你。
                    """
                )

                privacySection(
                    title: "联系我们",
                    body: """
                    如果你对本隐私政策有任何疑问，请通过以下方式联系我们：
                    邮箱：paul@paulgong.tech
                    """
                )
            }
            .padding(20)
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
