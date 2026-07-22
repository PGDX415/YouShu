//
//  ReceiptScanView.swift
//  YouShu
//

import SwiftUI
import SwiftData
import Vision

struct ReceiptScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var members: [FamilyMember]
    @AppStorage("defaultExpenseCategoryID") private var defaultExpenseCategoryID: String = ""
    @AppStorage("defaultIncomeCategoryID") private var defaultIncomeCategoryID: String = ""

    @State private var capturedImage: UIImage?
    @State private var scanResult: ReceiptScanResult?
    @State private var isScanning = false
    @State private var showInitialScreen = true
    @State private var showSaveAnimation = false
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false

    private var currentMember: FamilyMember? {
        members.first(where: { $0.role == .creator })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showInitialScreen {
                    choiceView
                } else if let result = scanResult {
                    resultView(result)
                }
            }
            .navigationTitle("拍照记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCameraPicker) {
                CameraPickerView(image: $capturedImage) {
                    showCameraPicker = false
                }
            }
            .fullScreenCover(isPresented: $showPhotoPicker) {
                PhotoPickerView(image: $capturedImage) {
                    showPhotoPicker = false
                }
            }
            .onChange(of: capturedImage) { _, newImage in
                if let img = newImage {
                    showInitialScreen = false
                    startScanning(img)
                }
            }
            .overlay {
                if isScanning {
                    scanningOverlay
                }
                if showSaveAnimation {
                    saveOverlay
                }
            }
        }
    }

    // MARK: - Choice View

    private var choiceView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            VStack(spacing: 6) {
                Text("拍照识别小票")
                    .font(.title2.weight(.semibold))
                Text("支持中文和英文收据\n设备端识别，不上传云端")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                Button {
                    showCameraPicker = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("拍照")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    showPhotoPicker = true
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("从相册选择")
                    }
                    .font(.headline)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 32)

            Text("提示：也可以在相册中截取线上小票图片进行识别")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Scanning Overlay

    private var scanningOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("正在识别...")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("使用设备端智能，数据不会上传")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Result View

    private func resultView(_ result: ReceiptScanResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Photo preview
                if let img = capturedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                }

                // Extracted info card
                VStack(spacing: 0) {
                    HStack {
                        Label("识别结果", systemImage: "doc.text.magnifyingglass")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        if result.amount != nil {
                            Text("支出")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    VStack(spacing: 12) {
                        // Amount
                        HStack {
                            Image(systemName: "yensign.circle.fill")
                                .foregroundColor(.red)
                                .font(.title3)
                            Text("金额")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let amount = result.amount {
                                Text("¥\(amount.formattedAmount)")
                                    .font(.title3.weight(.bold).monospacedDigit())
                                    .foregroundColor(.red)
                            } else {
                                Text("未识别").font(.subheadline).foregroundColor(.secondary)
                            }
                        }

                        // Merchant
                        if let merchant = result.merchant, !merchant.isEmpty {
                            Divider()
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(.accentColor)
                                Text("商户")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(merchant)
                                    .font(.subheadline.weight(.medium))
                            }
                        }

                        // Category suggestion
                        if let cat = result.suggestedCategory {
                            Divider()
                            HStack {
                                Image(systemName: "square.grid.2x2")
                                    .foregroundColor(.accentColor)
                                Text("分类建议")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                HStack(spacing: 6) {
                                    Image(systemName: cat.icon)
                                        .font(.caption)
                                        .foregroundColor(cat.color)
                                    Text(cat.name)
                                        .font(.subheadline.weight(.medium))
                                }
                            }
                        }

                        // Date
                        if let date = result.date {
                            Divider()
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.accentColor)
                                Text("日期")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(date, format: .dateTime.year().month().day())
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                    .padding(16)
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)

                // Raw text
                VStack(alignment: .leading, spacing: 6) {
                    Label("识别原文", systemImage: "text.alignleft")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.rawText.isEmpty ? "无" : result.rawText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(8)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20)

                // Actions
                VStack(spacing: 12) {
                    Button {
                        saveFromScan(result)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("确认记账")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            result.amount != nil
                            ? Color.accentColor
                            : Color(.systemGray4)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(result.amount == nil)

                    Button {
                        // Retake
                        capturedImage = nil
                        scanResult = nil
                        showInitialScreen = true
                    } label: {
                        Label("重新选择", systemImage: "arrow.triangle.2.circlepath.camera")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Scanning

    private func startScanning(_ image: UIImage) {
        isScanning = true

        Task {
            let result = await ReceiptScanner.scan(image, categories: categories)
            await MainActor.run {
                scanResult = result
                isScanning = false
            }
        }
    }

    // MARK: - Save

    private func saveFromScan(_ result: ReceiptScanResult) {
        guard let amount = result.amount else { return }

        let category = result.suggestedCategory
        let account = accounts.first(where: { $0.isDefault }) ?? accounts.first

        let note: String = {
            var parts: [String] = []
            if let merchant = result.merchant { parts.append(merchant) }
            return parts.joined(separator: " · ")
        }()

        let transaction = Transaction(
            amount: amount,
            type: .expense,
            date: result.date ?? Date(),
            note: note,
            category: category,
            account: account,
            destinationAccount: nil,
            createdByMember: currentMember
        )
        modelContext.insert(transaction)

        if let acc = account {
            acc.balance += transaction.signedAmount
        }

        if let cat = category {
            defaultExpenseCategoryID = cat.id.uuidString
        }

        try? modelContext.save()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        showSaveAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            dismiss()
        }
    }

    // MARK: - Save Overlay

    private var saveOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
                Text("已记录")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                if let amount = scanResult?.amount {
                    Text("¥\(amount.formattedAmount)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .transition(.opacity)
    }
}

// MARK: - Camera Image Picker

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.image = img }
            picker.dismiss(animated: true) { self.parent.onDismiss() }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { self.parent.onDismiss() }
        }
    }
}

// MARK: - Photo Library Picker

struct PhotoPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoPickerView
        init(_ parent: PhotoPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.image = img }
            picker.dismiss(animated: true) { self.parent.onDismiss() }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { self.parent.onDismiss() }
        }
    }
}

#Preview {
    ReceiptScanView()
        .modelContainer(for: [Transaction.self, Category.self, Account.self], inMemory: true)
}
