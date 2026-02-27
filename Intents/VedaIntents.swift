import AppIntents
import SwiftUI

// MARK: - Ask Veda Intent

@available(iOS 18.0, *)
struct AskVedaIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Veda"
    static let description = IntentDescription("Send a question to Veda AI")

    // openAppWhenRun = true is REQUIRED on iOS 17.
    // Without it, .result() silently does nothing on iOS 17 devices.
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Question", description: "What would you like to ask Veda?")
    var question: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask Veda \(\.$question)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let encoded = question.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "vedaai://ask?q=\(encoded)") else {
            throw NSError(domain: "VedaIntent", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not form URL"])
        }
        return .result(opensIntent: OpenURLIntent(url))
    }
}

// MARK: - Shortcut Provider
@available(iOS 18.0, *)
struct VedaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskVedaIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Talk to \(.applicationName)",
                "Open \(.applicationName)",
                "Chat with \(.applicationName)"
            ],
            shortTitle: "Ask Veda",
            systemImageName: "sparkles"
        )
    }
}
