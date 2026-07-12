//
//  MemberEditView.swift
//  YouShu
//

import SwiftUI

struct MemberEditView: View {
    @Environment(\.dismiss) private var dismiss

    let member: FamilyMember
    let onSave: () -> Void

    @State private var name: String
    @State private var avatar: String

    private let emojiOptions: [String] = [
        "😊", "😎", "🤩", "🥳", "😇", "🤓", "🧐",
        "👩", "👨", "👧", "👦", "👶", "👵", "👴",
        "👩‍💼", "👨‍💼", "👩‍🍳", "👨‍🍳", "👩‍🎓", "👨‍🎓",
        "🐱", "🐶", "🐼", "🐨", "🐰", "🦊", "🐸",
        "🌸", "🌺", "🌟", "⭐", "🎈", "🎉", "💎",
        "🍎", "🍕", "☕", "🎵", "⚽", "🎮", "📚",
        "❤️", "💙", "💚", "💛", "💜", "🧡", "🩷",
    ]

    init(member: FamilyMember, onSave: @escaping () -> Void) {
        self.member = member
        self.onSave = onSave
        _name = State(initialValue: member.name)
        _avatar = State(initialValue: member.avatarInitial)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar preview
                    ZStack {
                        Circle()
                            .fill(member.role == .creator ? Color.accentColor : Color(.systemGray4))
                            .frame(width: 80, height: 80)
                        Text(avatar.isEmpty ? String(name.prefix(1)) : avatar)
                            .font(avatar.count <= 2 ? .system(size: 36) : .system(size: 28, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 8)

                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("昵称")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        TextField("输入昵称", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 16)
                    }

                    // Emoji picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择头像")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                            spacing: 4
                        ) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Button {
                                    avatar = emoji
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(avatar == emoji
                                                  ? Color.accentColor.opacity(0.15)
                                                  : Color(.systemGray6))
                                            .frame(height: 44)

                                        Text(emoji)
                                            .font(.system(size: 24))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("编辑成员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        member.name = name.trimmingCharacters(in: .whitespaces)
                        member.avatarInitial = avatar
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    MemberEditView(member: FamilyMember(name: "我", avatarInitial: "😊")) {}
}
