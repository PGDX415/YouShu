//
//  LockView.swift
//  YouShu
//

import SwiftUI
import LocalAuthentication

struct LockView: View {
    let onUnlock: () -> Void

    @State private var authError: String?

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
                    if !biometryName.isEmpty {
                        Text("使用 \(biometryName) 解锁")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = authError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    authenticate()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: biometryName == "Face ID" ? "faceid" : "touchid")
                            .font(.title2)
                        Text(biometryName.isEmpty ? "输入密码" : "使用 \(biometryName)")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
                }

                if authError != nil {
                    Button("重试") { authenticate() }
                        .font(.subheadline)
                        .padding(.top, 8)
                }

                Spacer()
            }
        }
        .onAppear { authenticate() }
    }

    private func authenticate() {
        authError = nil
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authError = error?.localizedDescription ?? "设备不支持认证"
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "需要验证身份才能进入有数") { success, error in
            DispatchQueue.main.async {
                if success {
                    onUnlock()
                } else {
                    authError = error?.localizedDescription ?? "验证失败"
                }
            }
        }
    }
}

#Preview {
    LockView(onUnlock: {})
}
