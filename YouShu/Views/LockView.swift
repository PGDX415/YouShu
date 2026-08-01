//
//  LockView.swift
//  YouShu
//

import SwiftUI
import LocalAuthentication

struct LockView: View {
    let onUnlock: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("lockMethod") private var lockMethod: LockMethod = .biometric

    enum LockMethod: Int {
        case biometric = 0
        case passcode = 1
    }

    @State private var authError: String?
    @State private var authTask: Task<Void, Never>?
    @State private var isManualAuth = false

    // Custom passcode
    @AppStorage("appPasscode") private var storedPasscode: String = ""
    @State private var enteredPasscode: String = ""
    @State private var showPasscodeSetup = false
    @State private var passcodeShake = false

    private var biometryName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return ""
        }
    }

    private var hasBiometric: Bool {
        let ctx = LAContext()
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if lockMethod == .passcode && !storedPasscode.isEmpty {
                passcodeEntryView
            } else {
                biometricView
            }
        }
        .onAppear {
            isManualAuth = false
            if lockMethod == .biometric && hasBiometric {
                scheduleAuth(delay: 0.5)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                cancelAuth()
                enteredPasscode = ""
            } else if phase == .active {
                isManualAuth = false
                if lockMethod == .biometric && hasBiometric {
                    scheduleAuth(delay: 0.5)
                }
            }
        }
        .onDisappear {
            cancelAuth()
        }
    }

    // MARK: - Biometric View (system Face ID / Touch ID)

    private var biometricView: some View {
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
                if hasBiometric {
                    Button {
                        isManualAuth = true
                        authError = nil
                        cancelAuth()
                        performBiometricAuth()
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

                if !storedPasscode.isEmpty {
                    Button {
                        lockMethod = .passcode
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.title3)
                            Text("使用密码")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(hasBiometric ? .accentColor : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(hasBiometric ? Color.clear : Color.accentColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(hasBiometric ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                    }
                } else if hasBiometric {
                    // No passcode set yet, offer to create one
                    Button {
                        showPasscodeSetup = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.title3)
                            Text("设置密码")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 48)

            if authError != nil {
                Button("重试") { performBiometricAuth() }
                    .font(.subheadline)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .sheet(isPresented: $showPasscodeSetup) {
            PasscodeSetupView(onComplete: {
                lockMethod = .passcode
            })
        }
    }

    // MARK: - Passcode Entry View (custom in-app passcode)

    private var passcodeEntryView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "key.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
            }

            VStack(spacing: 8) {
                Text("输入密码")
                    .font(.title3.weight(.semibold))
                Text("请输入 App 密码以解锁")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Passcode dots
            HStack(spacing: 20) {
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .strokeBorder(
                            enteredPasscode.count == i ? Color.accentColor : Color(.systemGray4),
                            lineWidth: 2
                        )
                        .background(
                            Circle()
                                .fill(i < enteredPasscode.count ? Color.accentColor : Color.clear)
                        )
                        .frame(width: 16, height: 16)
                }
            }
            .modifier(ShakeEffect(animations: passcodeShake ? 1 : 0))
            .onChange(of: enteredPasscode) { _, newValue in
                if newValue.count == 6 {
                    if newValue == storedPasscode {
                        onUnlock()
                    } else {
                        passcodeShake = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            passcodeShake = false
                            enteredPasscode = ""
                        }
                    }
                }
            }

            if let error = authError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Number pad
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(1...9, id: \.self) { num in
                    passcodeKey("\(num)")
                }
                passcodeKey("biometric").opacity(0)
                passcodeKey("0")
                passcodeKey("delete")
            }
            .frame(maxWidth: 280)
            .padding(.horizontal, 40)

            Spacer()

            // Back to biometric
            if hasBiometric {
                Button {
                    lockMethod = .biometric
                    enteredPasscode = ""
                    scheduleAuth(delay: 0.3)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: biometryName == "Face ID" ? "faceid" : "touchid")
                        Text("使用 \(biometryName) 解锁")
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func passcodeKey(_ value: String) -> some View {
        Button {
            if value == "delete" {
                if !enteredPasscode.isEmpty {
                    enteredPasscode.removeLast()
                }
            } else {
                if enteredPasscode.count < 6 {
                    enteredPasscode.append(value)
                }
            }
        } label: {
            Group {
                if value == "delete" {
                    Image(systemName: "delete.left")
                        .font(.title2)
                        .foregroundColor(.secondary)
                } else {
                    Text(value)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .frame(width: 72, height: 52)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Biometric Auth

    private func scheduleAuth(delay: TimeInterval) {
        cancelAuth()
        authTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            performBiometricAuth(auto: true)
        }
    }

    private func cancelAuth() {
        authTask?.cancel()
        authTask = nil
    }

    private func performBiometricAuth(auto: Bool = false) {
        authError = nil
        let context = LAContext()
        context.localizedFallbackTitle = "输入密码"

        var nsError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &nsError) else {
            if !auto { authError = laErrorMessage(nsError) }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "需要验证身份才能进入有数") { success, error in
            DispatchQueue.main.async {
                if success {
                    onUnlock()
                    return
                }

                if !auto {
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
            return "生物识别不可用"
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

// MARK: - Shake Effect

struct ShakeEffect: GeometryEffect {
    var animations: CGFloat

    var animatableData: CGFloat {
        get { animations }
        set { animations = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animations * .pi * 2), y: 0))
    }
}

// MARK: - Passcode Setup View

struct PasscodeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appPasscode") private var storedPasscode: String = ""
    var onComplete: (() -> Void)?

    @State private var firstPasscode = ""
    @State private var secondPasscode = ""
    @State private var step: SetupStep = .create
    @State private var shake = false
    @State private var errorMessage: String?

    enum SetupStep {
        case create, confirm
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                VStack(spacing: 8) {
                    Text(step == .create ? "设置 App 密码" : "再次输入密码")
                        .font(.title3.weight(.semibold))
                    Text(step == .create
                         ? "设置 6 位数字密码保护 App 安全"
                         : "请再次输入以确认密码")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 20) {
                    let code = step == .create ? firstPasscode : secondPasscode
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .strokeBorder(
                                code.count == i ? Color.accentColor : Color(.systemGray4),
                                lineWidth: 2
                            )
                            .background(
                                Circle().fill(i < code.count ? Color.accentColor : Color.clear)
                            )
                            .frame(width: 16, height: 16)
                    }
                }
                .modifier(ShakeEffect(animations: shake ? 1 : 0))

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(1...9, id: \.self) { num in setupKey("\(num)"); }
                    setupKey("").opacity(0)
                    setupKey("0")
                    setupKey("delete")
                }
                .frame(maxWidth: 280)
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("设置密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func setupKey(_ value: String) -> some View {
        Button {
            if value == "delete" {
                if step == .create && !firstPasscode.isEmpty {
                    firstPasscode.removeLast()
                } else if step == .confirm && !secondPasscode.isEmpty {
                    secondPasscode.removeLast()
                }
            } else {
                if step == .create && firstPasscode.count < 6 {
                    firstPasscode.append(value)
                    if firstPasscode.count == 6 {
                        step = .confirm
                    }
                } else if step == .confirm && secondPasscode.count < 6 {
                    secondPasscode.append(value)
                    if secondPasscode.count == 6 {
                        verifyAndSave()
                    }
                }
            }
        } label: {
            Group {
                if value == "delete" {
                    Image(systemName: "delete.left")
                        .font(.title2)
                        .foregroundColor(.secondary)
                } else {
                    Text(value)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .frame(width: 72, height: 52)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func verifyAndSave() {
        if firstPasscode == secondPasscode {
            storedPasscode = secondPasscode
            onComplete?()
            dismiss()
        } else {
            errorMessage = "两次密码不一致，请重新设置"
            shake = true
            firstPasscode = ""
            secondPasscode = ""
            step = .create
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                shake = false
            }
        }
    }
}

#Preview {
    LockView(onUnlock: {})
}
