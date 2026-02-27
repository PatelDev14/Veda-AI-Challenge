import SwiftData
import SwiftUI

// MARK: - Persistent Models

@Model
final class SavedConversation {
    var id: UUID
    var title: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var messages: [SavedMessage] = []

    init(title: String = "New Conversation") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.messages = []
    }
}

@Model
final class SavedMessage {
    var id: UUID
    var role: String        // "user" or "assistant"
    var content: String
    var isError: Bool
    var sortIndex: Int      // preserves message order on restore

    init(role: String, content: String, isError: Bool = false, sortIndex: Int = 0) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.isError = isError
        self.sortIndex = sortIndex
    }
}

// MARK: - ConversationStore
// Stored at: Application Support/VedaChats.store (private, persists across launches)

@MainActor
final class ConversationStore: ObservableObject {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([SavedConversation.self, SavedMessage.self])
        let config = ModelConfiguration("VedaChats", schema: schema, isStoredInMemoryOnly: false)
        // If schema migration fails (e.g. after adding sortIndex), wipe and rebuild
        if let container = try? ModelContainer(for: schema, configurations: config) {
            modelContainer = container
        } else {
            // Delete old store and recreate
            let storeURL = URL.applicationSupportDirectory.appendingPathComponent("VedaChats.store")
            try? FileManager.default.removeItem(at: storeURL)
            modelContainer = try! ModelContainer(for: schema, configurations: config)
        }
    }

    var context: ModelContext { modelContainer.mainContext }

    // MARK: - Save (brand new conversation)
    // Returns the object so ChatViewModel can hold a reference.
    // When the user continues chatting in a restored thread, call updateConversation instead.
    @discardableResult
    func saveConversation(messages: [Message], title: String? = nil) -> SavedConversation? {
        let nonEmpty = messages.filter { !$0.content.isEmpty }
        let userMsgs = nonEmpty.filter { $0.isUser }
        let assistantMsgs = nonEmpty.filter { !$0.isUser }
        guard !userMsgs.isEmpty, !assistantMsgs.isEmpty else { return nil }

        let rawTitle = userMsgs.first?.content ?? "Conversation"
        let autoTitle = String(rawTitle.prefix(60))

        let conversation = SavedConversation(title: title ?? autoTitle)
        conversation.messages = nonEmpty.enumerated().map { idx, msg in
            SavedMessage(
                role: msg.isUser ? "user" : "assistant",
                content: msg.content,
                isError: msg.isError,
                sortIndex: idx
            )
        }
        context.insert(conversation)
        try? context.save()

        SpotlightService.shared.index(
            conversationID: conversation.id.uuidString,
            title: conversation.title,
            preview: userMsgs.first?.content ?? ""
        )
        return conversation
    }

    // MARK: - Update (restored conversation with new messages)
    // Called instead of saveConversation when the user continued chatting
    // in a thread they opened from history. Replaces messages in-place
    // so the message count and content stay accurate.
    func updateConversation(_ conversation: SavedConversation, messages: [Message]) {
        let nonEmpty = messages.filter { !$0.content.isEmpty }
        guard !nonEmpty.isEmpty else { return }

        // Remove all old child messages first
        for msg in conversation.messages {
            context.delete(msg)
        }
        // Re-insert with correct sortIndex
        conversation.messages = nonEmpty.enumerated().map { idx, msg in
            SavedMessage(
                role: msg.isUser ? "user" : "assistant",
                content: msg.content,
                isError: msg.isError,
                sortIndex: idx
            )
        }
        try? context.save()

        SpotlightService.shared.index(
            conversationID: conversation.id.uuidString,
            title: conversation.title,
            preview: nonEmpty.first(where: { $0.isUser })?.content ?? ""
        )
    }

    // MARK: - Fetch (newest first)
    func fetchAll() -> [SavedConversation] {
        let descriptor = FetchDescriptor<SavedConversation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Restore in correct order
    func restoreMessages(from conversation: SavedConversation) -> [Message] {
        conversation.messages
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { Message(role: $0.role == "user" ? .user : .assistant, content: $0.content) }
    }

    // MARK: - Rename
    func rename(_ conversation: SavedConversation, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        conversation.title = trimmed
        try? context.save()
        SpotlightService.shared.index(
            conversationID: conversation.id.uuidString,
            title: trimmed,
            preview: conversation.messages.sorted { $0.sortIndex < $1.sortIndex }.first?.content ?? ""
        )
    }

    // MARK: - Delete
    func delete(_ conversation: SavedConversation) {
        SpotlightService.shared.remove(conversationID: conversation.id.uuidString)
        context.delete(conversation)
        try? context.save()
    }
}
