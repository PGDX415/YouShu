//
//  HelpView.swift
//  YouShu
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    helpSection(
                        icon: "pencil.circle.fill", color: .blue,
                        title: "手动记账",
                        content: """
                        点击首页「＋记一笔」按钮，填写金额、选择分类即可完成记账。
                        
                        • 支持三种类型：支出、收入、转账
                        • 可添加备注、选择账户、修改日期
                        • 点击「完成」保存，自动更新账户余额
                        """
                    )

                    helpSection(
                        icon: "sparkles", color: .purple,
                        title: "智能记账（自然语言）",
                        content: """
                        点击首页 ✨ 按钮，用自然语言描述消费即可自动识别。
                        
                        试试这样说：
                        •「午饭花了35元」
                        •「工资到账15000块」
                        •「给老婆转了2000」
                        
                        支持中文数字，如「二十五块」。
                        点击识别结果中的分类、账户、备注可手动修改。
                        """
                    )

                    helpSection(
                        icon: "camera.fill", color: .blue,
                        title: "拍照记账",
                        content: """
                        点击首页 📷 按钮，进入拍照识别页面，可选择三种方式：

                        1. 拍照：直接拍摄小票/收据
                        2. 小票/收据：从相册选择小票照片
                        3. 微信/支付宝支付截图：从相册选择支付成功页面截图

                        系统自动识别：
                        • 金额（小票优先「合计/实付」，截图优先 ¥ 金额）
                        • 商户名称（截图识别「向 XX 付款」格式）
                        • 消费日期和分类建议

                        完全使用设备端识别，不上传任何数据。
                        """
                    )

                    helpSection(
                        icon: "doc.on.clipboard", color: .green,
                        title: "从微信/支付宝导入",
                        content: """
                        两种方式导入微信/支付宝支付记录：

                        方式一：粘贴文本
                        支付完成后复制付款信息，打开有数 → ✨ 智能记账 → 点击「粘贴剪贴板内容」。

                        方式二：识别截图（推荐）
                        截取支付成功页面，打开首页 📷 → 选择「微信/支付宝支付截图」，自动识别金额、商户和日期。

                        支持格式：
                        •「微信支付 ¥35.00」
                        •「支付宝 付款成功 ¥89.90」
                        •「向星巴克付款 ¥128.00」
                        """
                    )

                    helpSection(
                        icon: "chart.bar.doc.horizontal.fill", color: .orange,
                        title: "月度小结",
                        content: """
                        点击首页 📊 按钮，生成本月收支洞察。
                        
                        包含：
                        • 总收入、支出、结余
                        • 环比变化（与上月对比）
                        • 分类排名及趋势变化
                        • 单笔最大消费
                        • 日均支出和预算进度
                        
                        完全本地生成，无需联网。
                        """
                    )

                    helpSection(
                        icon: "line.3.horizontal.decrease.circle", color: .gray,
                        title: "筛选交易",
                        content: """
                        点击首页 🔍 按钮，按条件筛选交易记录。
                        
                        支持筛选：
                        • 文本搜索（备注、分类、账户）
                        • 类型（支出/收入/转账）
                        • 分类、账户
                        • 金额范围、日期范围
                        
                        列表中的交易可左滑编辑、右滑删除。
                        """
                    )

                    helpSection(
                        icon: "chart.bar.doc.horizontal", color: .teal,
                        title: "预算管理",
                        content: """
                        在「设置 → 月度预算」中为分类设置预算上限。
                        
                        首页会显示预算进度条：
                        • 蓝色 = 安全范围内
                        • 红色 = 已超支
                        
                        点击预算卡片可查看该分类下的详细支出明细。
                        """
                    )

                    helpSection(
                        icon: "wallet.pass", color: .mint,
                        title: "账户管理",
                        content: """
                        在「设置 → 账户管理」中添加和管理账户（现金、银行卡、支付宝等）。
                        
                        • 设置默认账户：右滑账户 → 设为默认
                        • 转账功能：支持账户间资金转移
                        • 账户余额自动根据交易更新
                        """
                    )

                    helpSection(
                        icon: "lock.shield.fill", color: .indigo,
                        title: "应用锁",
                        content: """
                        在「设置 → 应用锁」中开启身份验证保护。

                        开启后，每次进入 App 需要验证身份。
                        支持 Face ID、Touch ID，也可在验证弹窗中
                        点击「输入密码」使用手机密码解锁。
                        验证使用系统原生机制，不存储任何生物信息。
                        """
                    )

                    helpSection(
                        icon: "person.3.fill", color: .cyan,
                        title: "家庭共享",
                        content: """
                        在「设置 → 家庭共享」中创建或加入家庭账本。
                        
                        家庭成员可以：
                        • 共同记录家庭收支
                        • 查看所有成员交易
                        • 首页可切换「全部 / 仅我」
                        
                        通过 iCloud 同步，数据实时更新。
                        """
                    )
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("使用指南")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    // MARK: - Help Section

    private func helpSection(
        icon: String, color: Color,
        title: String, content: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.headline)
            }

            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    HelpView()
}
