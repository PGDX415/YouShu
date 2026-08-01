//
//  LockView.swift
//  YouShu
//

import SwiftUI
import LocalAuthentication

struct LockView: View {
    let onUnlock: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var authError: String?
    @State private var authTask: Task<Void, Never>?
    @State private var isManualAuth = false

    private var biometryName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return ""
        }
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.accentColor)
                }

                VStack(spacing: 8) {
                    Text("有数")
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                    Text("需要验证身份")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let error = authError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    isManualAuth = true
                    authenticate()
                } label: {
                    HStack(spacing: 8) {
                        if !biometryName.isEmpty {
                            Image(systemName: biometryName == "Face ID" ? "faceid" : "touchid")
                                .font(.title2)
                        } else {
                            Image(systemName: "key.fill")
                                .font(.title2)
                        }
                        Text("解锁")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
                }
                .padding(.horizontal, 48)

                VStack(spacing: 4) {
                    if !biometryName.isEmpty {
                        Text("面容/指纹验证，或点按「输入密码」使用手机密码")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("使用手机密码验证身份")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 32)

                if authError != nil {
                    Button("重试") { authenticate() }
                        .font(.subheadline)
                        .padding(.top, 8)
                }

                Spacer()
            }
        }
        .onAppear {
            isManualAuth = false
            scheduleAuth(delay: 0.5)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                cancelAuth()
            } else if phase == .active {
                isManualAuth = false
                scheduleAuth(delay: 0.5)
            }
        }
        .onDisappear {
            cancelAuth()
        }
    }

    // MARK: - Authentication

    private func scheduleAuth(delay: TimeInterval) {
        cancelAuth()
        authTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            performAuth()
        }
    }

    private func cancelAuth() {
        authTask?.cancel()
        authTask = nil
    }

    @MainActor
    private func performAuth() {
        authError = nil
        let context = LAContext()
        var nsError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &nsError) else {
            if isManualAuth {
                authError = laErrorMessage(nsError)
            }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "需要验证身份才能进入有数") { success, error in
            DispatchQueue.main.async {
                if success {
                    onUnlock()
                } else if let laError = error as? LAError {
                    switch laError.code {
                    case .userCancel, .systemCancel, .appCancel,
                         .biometryNotAvailable, .biometryNotEnrolled:
                        // Transient errors — ignore during auto-auth, show during manual
                        if isManualAuth {
                            authError = laErrorMessage(error as NSError?)
                        }
                    default:
                        authError = laErrorMessage(error as NSError?)
                    }
                } else if isManualAuth {
                    authError = laErrorMessage(error as NSError?)
                }
            }
        }
    }

    private func authenticate() {
        cancelAuth()
        Task { @MainActor in
            performAuth()
        }
    }

    /// Map LAError to a Chinese user-facing message.
    private func laErrorMessage(_ error: NSError?) -> String {
        guard let laError = error as? LAError else {
            return "验证失败，请重试"
        }
        switch laError.code {
        case .userCancel:
            return "已取消验证"
        case .userFallback:
            return "请使用密码验证"
        case .systemCancel:
            return "验证被系统中断，请重试"
        case .passcodeNotSet:
            return "设备未设置密码"
        case .biometryNotAvailable:
            return "生物识别不可用，请使用密码"
        case .biometryNotEnrolled:
            return "未录入\(biometryName)，请在系统设置中添加"
        case .biometryLockout:
            return "\(biometryName)已被锁定，请使用密码解锁"
        case .biometryDisconnected:
            return "\(biometryName)已断开连接"
        default:
            return "验证失败，请重试"
        }
    }
}

#Preview {
    LockView(onUnlock: {})
}
