import SwiftUI
import Observation

@Observable
@MainActor
class ChatViewModel {
    var messages: [Message] = []
    var currentInput: String = ""
    var isGenerating: Bool = false
    var isModelLoading: Bool = true
    var selectedImage: UIImage? = nil
    var showErrorBanner: Bool = false
    var errorMessage: String = ""

    // Tracks which SavedConversation is currently loaded (if any).
    // nil  → fresh unsaved chat
    // set  → restored from history; saving must UPDATE this record, not insert new
    var activeConversation: SavedConversation? = nil

    // MARK: - Status Check
    func checkStatus() {
        Task {
            if #available(iOS 26.0, *) {
                await FoundationModelService.shared.ensureInitialized()
            }
            isModelLoading = false
        }
    }

    // MARK: - Send Message
    func sendMessage() {
        let trimmedInput = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty || selectedImage != nil else { return }

        let imageToSend = selectedImage
        var userContent = trimmedInput
        if imageToSend != nil && trimmedInput.isEmpty {
            userContent = "What do you see in this image?"
        }

        var userMessage = Message(role: .user, content: userContent)
        userMessage.attachedImage = imageToSend
        messages.append(userMessage)

        currentInput = ""
        selectedImage = nil

        let placeholderIndex = messages.count
        messages.append(Message(role: .assistant, content: ""))
        isGenerating = true

        Task {
            var finalPrompt = userContent
            if let img = imageToSend {
                do {
                    let description = try await VisionService.shared.describe(image: img)
                    finalPrompt = "[Vision analysis]: \(description)\n\nUser: \(userContent)"
                } catch {
                    finalPrompt = userContent + " (Image analysis failed)"
                }
            }

            if #available(iOS 26.0, *) {
                LiveActivityManager.shared.start(question: userContent)
                await FoundationModelService.shared.generateResponse(
                    for: finalPrompt,
                    updateHandler: { [weak self] partial in
                        guard let self else { return }
                        LiveActivityManager.shared.update(partial: partial)
                        if placeholderIndex < self.messages.count {
                            self.messages[placeholderIndex].content = partial
                        }
                    },
                    completion: { [weak self] result in
                        guard let self else { return }
                        self.isGenerating = false
                        LiveActivityManager.shared.stop()
                        switch result {
                        case .failure(let error):
                            if placeholderIndex < self.messages.count {
                                self.messages[placeholderIndex].content = "Something went wrong. Please try again."
                                self.messages[placeholderIndex].isError = true
                            }
                            self.triggerErrorBanner(error.localizedDescription)
                        case .success:
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                )
            } else {
                isGenerating = false
                if placeholderIndex < messages.count {
                    messages[placeholderIndex].content = "Apple Intelligence requires iOS 26+."
                    messages[placeholderIndex].isError = true
                }
            }
        }
    }
    
    // MARK: - Restore from history
    // Sets activeConversation so ChatView knows to UPDATE on next save.
    func restore(conversation: SavedConversation, messages: [Message]) {
        self.messages = messages
        self.activeConversation = conversation
        if #available(iOS 26.0, *) {
            Task { await FoundationModelService.shared.resetSession() }
        }
    }

    // MARK: - Retry
    func retryLastUserMessage() {
        if let last = messages.last, last.role == .assistant, last.isError {
            messages.removeLast()
        }
        if let lastUser = messages.last(where: { $0.isUser }) {
            currentInput = lastUser.content
            selectedImage = lastUser.attachedImage
            messages.removeLast(messages.count - (messages.lastIndex(where: { $0.isUser }) ?? 0))
            sendMessage()
        }
    }

    // MARK: - Clear
    func clearChat() {
        activeConversation = nil
        messages.removeAll()
        if #available(iOS 26.0, *) {
            Task { await FoundationModelService.shared.resetSession() }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Error Banner
    private func triggerErrorBanner(_ msg: String) {
        errorMessage = msg
        showErrorBanner = true
        Task {
            try? await Task.sleep(for: .seconds(3))
            showErrorBanner = false
        }
    }
}
