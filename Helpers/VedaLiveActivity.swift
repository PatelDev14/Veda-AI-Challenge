import ActivityKit
import SwiftUI

// MARK: - Live Activity Attributes
// Shown in the Dynamic Island and Lock Screen while Veda is generating.

struct VedaActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String          // e.g. "Thinking...", "Almost done"
        var partialResponse: String // first ~60 chars of streaming response
    }

    var userQuestion: String        // The question that was asked (static)
}

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private var currentActivity: Activity<VedaActivityAttributes>?

    func start(question: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = VedaActivityAttributes(userQuestion: String(question.prefix(80)))
        let state = VedaActivityAttributes.ContentState(
            status: "Veda is thinking...",
            partialResponse: ""
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            print("✅ Live Activity started")
        } catch {
            print("❌ Live Activity failed: \(error)")
        }
    }

    func update(partial: String) {
        guard let activity = currentActivity else { return }
        let preview = String(partial.prefix(80))
        let state = VedaActivityAttributes.ContentState(
            status: "Writing response...",
            partialResponse: preview
        )
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func stop() {
        guard let activity = currentActivity else { return }
        let state = VedaActivityAttributes.ContentState(
            status: "Done ✓",
            partialResponse: ""
        )
        Task {
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .after(.now + 3))
            currentActivity = nil
        }
    }
}
