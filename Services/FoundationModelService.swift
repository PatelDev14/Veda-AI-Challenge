import Foundation
import FoundationModels
import UIKit

@available(iOS 26.0, *)
@MainActor
class FoundationModelService {
    static let shared = FoundationModelService()

    private var session: LanguageModelSession?
    private var initializationTask: Task<Void, Never>?

    private let systemInstructions = """
    You are Veda, a wise, calm, and deeply insightful AI companion.
    - Respond thoughtfully, concisely, and with empathy.
    - Use simple, natural language. Avoid jargon unless the user uses it first.
    - When analyzing images, describe what you observe clearly and offer helpful context.
    - Format responses clearly. Use bullet points or numbered lists only when it genuinely helps.
    - Be encouraging, grounded, and curious.
    - Never be preachy or overly formal.
    """

    private init() {}

    func isSessionNil() -> Bool { session == nil }

    // MARK: - Session Init
    private func initializeSession() async {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            do {
                session = try LanguageModelSession(
                    model: model,
                    instructions: systemInstructions
                )
                print("✅ Veda session initialized.")
                try? session?.prewarm()
                print("🧠 Session pre-warmed.")
            } catch {
                print("❌ Session creation failed: \(error)")
            }

        case .unavailable(let reason):
            print("❌ Model unavailable: \(reason)")
        }
    }

    // MARK: - Ensure Ready
    func ensureInitialized() async {
        if session != nil { return }

        if let task = initializationTask {
            _ = await task.value
            return
        }

        initializationTask = Task { await initializeSession() }
        _ = await initializationTask?.value
    }

    // MARK: - Reset Session (clear conversation history)
    func resetSession() async {
        session = nil
        initializationTask = nil
        await ensureInitialized()
        print("🔄 Veda session reset.")
    }

    // MARK: - Generate Response (streaming)
    func generateResponse(
        for promptString: String,
        updateHandler: @escaping @MainActor (String) -> Void,
        completion: @escaping @MainActor (Result<String, Error>) -> Void
    ) async {
        await ensureInitialized()

        guard let session else {
            completion(.failure(NSError(
                domain: "Veda",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Veda's brain is not ready yet. Please try again."]
            )))
            return
        }

        do {
            let stream = session.streamResponse(to: promptString)
            var accumulated = ""

            for try await partial in stream {
                accumulated = partial.content
                updateHandler(accumulated)
            }

            completion(.success(accumulated))
        } catch {
            completion(.failure(error))
        }
    }
}
