import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let store: ConversationStore
    let refreshID: UUID  // changes every time the sheet opens, triggering a fresh fetch
    let onRestore: (SavedConversation, [Message]) -> Void

    @State private var conversations: [SavedConversation] = []
    @State private var renameTarget: SavedConversation? = nil
    @State private var renameText: String = ""
    @State private var deleteTarget: SavedConversation? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Conversations")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Button("Done") { dismiss() }
                        .foregroundStyle(.orange)
                        .font(.system(size: 15, weight: .medium))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.9))

                Divider().overlay(Color.white.opacity(0.08))

                if conversations.isEmpty {
                    Spacer()
                    VStack(spacing: 14) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.15))
                        Text("No saved conversations yet")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("Conversations save automatically\nwhen you start a new chat.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.2))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(conversations, id: \.id) { convo in
                            ConversationRow(
                                conversation: convo,
                                onTap: {
                                    let restored = store.restoreMessages(from: convo)
                                    onRestore(convo, restored)
                                    dismiss()
                                },
                                onRename: {
                                    renameText = convo.title
                                    renameTarget = convo
                                },
                                onDelete: {
                                    deleteTarget = convo
                                }
                            )
                            .listRowBackground(Color.white.opacity(0.03))
                            .listRowSeparatorTint(Color.white.opacity(0.06))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { conversations = store.fetchAll() }
        .onChange(of: refreshID) { conversations = store.fetchAll() }

        // MARK: - Rename Alert
        .alert("Rename Conversation", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Title", text: $renameText)
            Button("Save") {
                if let target = renameTarget {
                    store.rename(target, to: renameText)
                    conversations = store.fetchAll()
                }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        } message: {
            Text("Enter a new name for this conversation.")
        }

        // MARK: - Delete Confirmation
        .confirmationDialog(
            "Delete this conversation?",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    store.delete(target)
                    conversations = store.fetchAll()
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("This cannot be undone.")
        }
    }
}

// MARK: - Row
private struct ConversationRow: View {
    let conversation: SavedConversation
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    private func formatDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Today · " + date.formatted(date: .omitted, time: .shortened)
        } else if cal.isDateInYesterday(date) {
            return "Yesterday · " + date.formatted(date: .omitted, time: .shortened)
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    // First user message as a preview line
    private var previewText: String {
        conversation.messages
            .sorted { $0.sortIndex < $1.sortIndex }
            .first(where: { $0.role == "user" })?.content ?? ""
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Text("✦")
                        .font(.system(size: 15))
                        .foregroundStyle(.orange.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)

                    if !previewText.isEmpty {
                        Text(previewText)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }

                    Text(formatDate(conversation.createdAt))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.25))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(conversation.messages.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange.opacity(0.6))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange.opacity(0.12)))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.18))
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onRename() } label: { Label("Rename", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            Button(action: onRename) { Label("Rename", systemImage: "pencil") }.tint(.orange)
        }
    }
}
