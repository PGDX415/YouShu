# CloudKit 配置指南 — 有数 App

本文档说明如何为「有数」App 配置 iCloud / CloudKit 同步和家庭共享功能。

---

## 前置条件

- Apple Developer Program 会员资格（免费账号也可使用 CloudKit 开发测试）
- Xcode 中已登录 Apple ID（Xcode → Settings → Accounts）
- 真机或登录了 iCloud 的模拟器（模拟器需手动登录：Settings → 登录 Apple ID）

---

## 1. Xcode 项目配置

### 1.1 添加 iCloud Capability

1. 在 Xcode 中打开 `YouShu.xcodeproj`
2. 选择 target **YouShu** → **Signing & Capabilities**
3. 点击 **+ Capability** → 搜索 **iCloud** → 双击添加
4. 在 iCloud 服务列表中勾选 **CloudKit**
5. 点击 **+** 添加 container，命名为：
   ```
   iCloud.com.gongdexin.paul.YouShu
   ```
   （与 `YouShuApp.swift` 中的 `cloudKitContainerID` 一致）

### 1.2 验证 Entitlements

项目已包含 `YouShu/YouShu.entitlements` 文件，应包含以下键值：

| Key | Value |
|-----|-------|
| `aps-environment` | `development` |
| `com.apple.developer.icloud-container-identifiers` | `["iCloud.com.gongdexin.paul.YouShu"]` |
| `com.apple.developer.icloud-services` | `["CloudKit"]` |

Xcode 会在添加 Capability 后自动生成/更新此文件。

---

## 2. Apple Developer 后台配置

1. 登录 [developer.apple.com](https://developer.apple.com)
2. 进入 **Certificates, Identifiers & Profiles**
3. 左侧选择 **Identifiers** → 找到 App ID `com.gongdexin.paul.YouShu`
4. 确认 **iCloud** 服务已启用，**CloudKit** 已勾选
5. 如需创建新 container，在 iCloud Containers 中添加

---

## 3. CloudKit Dashboard 部署 Schema

1. 打开 [CloudKit Dashboard](https://icloud.developer.apple.com)
2. 选择 container `iCloud.com.gongdexin.paul.YouShu`
3. 进入 **Schema** → **Record Types**

首次运行 App 后，SwiftData 会自动在 CloudKit 中创建对应的 Record Types：
- `CD_Transaction`
- `CD_Category`
- `CD_Account`
- `CD_FamilyLedger`
- `CD_FamilyMember`

### 3.1 部署到 Production

1. 在 CloudKit Dashboard → **Schema** → 点击 **Deploy to Production**
2. 确认所有 Record Types 已部署
3. 此步骤仅需在 App 发布前执行一次

---

## 4. 模拟器测试 iCloud 同步

1. **模拟器需登录 iCloud**：
   - 启动模拟器 → Settings → 登录 Apple ID
   - 开启 iCloud Drive
2. 运行 App，数据将自动同步到 iCloud
3. **验证同步**：在另一台设备/模拟器上登录同一 Apple ID，数据应自动出现

### 如果同步失败

- 确认 entitlements 已正确配置
- 检查 Xcode 控制台日志中的 CloudKit 错误
- 常见问题：container ID 不匹配、未登录 iCloud、网络问题

---

## 5. CKShare 家庭共享（高级）

### 5.1 前提

- CloudKit container 已在 Production 部署 Schema
- App 使用 CloudKit 私有数据库正常运行
- 所有参与者使用不同的 iCloud 账号

### 5.2 共享流程

1. **创建者**创建 FamilyLedger → 点击「邀请家庭成员」
2. 系统弹出 `UICloudSharingController`
3. 选择分享方式（iMessage / AirDrop）
4. **接收者**点击邀请链接 → App 自动打开并接受共享
5. 共享账本中的交易所有成员可见

### 5.3 代码接入点

`CloudKitShareHelper.swift` 提供了 `UICloudSharingController` 的 SwiftUI 包装。
在 `FamilyView.swift` 的 `presentCloudSharing()` 方法中集成：

```swift
private func presentCloudSharing() {
    // 实际共享逻辑 — 需要在 CloudKit container
    // 完全配置好后才能正常工作
}
```

### 5.4 常见问题

| 问题 | 解决 |
|------|------|
| CKShare 无法创建 | 确认 Schema 已 deploy 到 Production |
| 邀请链接无法打开 | 检查 App 的 URL Scheme 配置 |
| 共享数据不可见 | 确认参与者 iCloud 账号已登录 |
| 权限错误 | 检查 CKShare permissions 设置 |

---

## 6. 当前状态

### 已完成 ✅
- [x] SwiftData 模型（Transaction, Category, Account, FamilyLedger, FamilyMember）
- [x] `YouShuApp.swift` 中 CloudKit container 配置（含自动回退到本地存储）
- [x] `YouShu.entitlements` 文件（iCloud + CloudKit 权限）
- [x] `project.pbxproj` 中 `CODE_SIGN_ENTITLEMENTS` 配置
- [x] 家庭共享 UI（FamilyView）
- [x] CKShare helper 代码框架

### 需要手动操作 ⚠️
- [ ] Xcode → Signing & Capabilities → 添加 iCloud + CloudKit
- [ ] Apple Developer 后台确认 App ID 启用 CloudKit
- [ ] CloudKit Dashboard 部署 Schema
- [ ] 模拟器/真机登录 iCloud 账号
- [ ] 真机测试 iCloud 同步
- [ ] 配置 CKShare（如需家庭共享）

---

## 备用方案

如果 CloudKit 不可用（模拟器未登录 iCloud、网络断开等），App 会自动回退到**纯本地存储**模式，所有功能仍可正常使用，只是不会跨设备同步。日志中会显示：

```
⚠️ CloudKit unavailable, falling back to local storage: ...
```
