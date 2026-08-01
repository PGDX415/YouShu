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

                VStack(spacing: 14) {
                    // Biometric button (only if biometric available)
                    if !biometryName.isEmpty {
                        Button {
                            isManualAuth = true
                            authenticateWithBiometrics()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: biometryName == "Face ID" ? "faceid" : "touchid")
                                    .font(.title2)
                                Text("使用 \(biometryName)")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
                        }
                    }

                    // Passcode button (always available if device has passcode)
                    Button {
                        isManualAuth = true
                        authenticateWithPasscode()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.title3)
                            Text("使用密码")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(biometryName.isEmpty ? .white : .accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(biometryName.isEmpty ? Color.accentColor : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(biometryName.isEmpty ? Color.clear : Color.accentColor, lineWidth: 1.5)
                        )
                    }
                }
                .padding(.horizontal, 48)

                if authError != nil {
                    Button("重试") {
                        if !biometryName.isEmpty {
                            authenticateWithBiometrics()
                        } else {
                            authenticateWithPasscode()
                        }
                    }
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
            performAuth(auto: true)
        }
    }

    private func cancelAuth() {
        authTask?.cancel()
        authTask = nil
    }

    /// Auto-auth on app launch / foreground. Silently ignores transient errors.
    private func performAuth(auto: Bool = false) {
        evaluate(policy: .deviceOwnerAuthentication,
                 reason: "需要验证身份才能进入有数",
                 isAuto: auto)
    }

    private func authenticateWithBiometrics() {
        cancelAuth()
        authError = nil
        evaluate(policy: .deviceOwnerAuthenticationWithBiometrics,
                 reason: "使用\(biometryName)验证身份",
                 isAuto: false)
    }

    private func authenticateWithPasscode() {
        cancelAuth()
        authError = nil
        // .deviceOwnerAuthentication always supports passcode fallback.
        // When biometric is available, iOS shows biometric first but the
        // system dialog includes a passcode button at the bottom.
        evaluate(policy: .deviceOwnerAuthentication,
                 reason: "输入手机密码以解锁有数",
                 isAuto: false)
    }

    private func evaluate(policy: LAPolicy, reason: String, isAuto: Bool) {
        let context = LAContext()
        context.localizedFallbackTitle = "输入密码"

        var nsError: NSError?
        guard context.canEvaluatePolicy(policy, error: &nsError) else {
            if !isAuto {
                authError = laErrorMessage(nsError)
            }
            return
        }

        context.evaluatePolicy(policy, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    onUnlock()
                    return
                }

                // For .deviceOwnerAuthenticationWithBiometrics with userFallback,
                // retry with .deviceOwnerAuthentication to show passcode
                if policy == .deviceOwnerAuthenticationWithBiometrics,
                   let laError = error as? LAError,
                   laError.code == .userFallback {
                    authenticateWithPasscode()
                    return
                }

                if !isAuto {
                    if let laError = error as? LAError {
                        switch laError.code {
                        case .userCancel, .systemCancel, .appCancel:
                            authError = "已取消验证"
                        default:
                            authError = laErrorMessage(error as NSError?)
                        }
                    } else {
                        authError = laErrorMessage(error as NSError?)
                    }
                }
            }
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
