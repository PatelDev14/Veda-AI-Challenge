import CoreSpotlight
import UIKit

// MARK: - SpotlightService
// Indexes saved conversations so they appear in iOS Spotlight (home screen search).
// Tapping a result deep-links back into Veda via the vedaai:// URL scheme.

@MainActor
final class SpotlightService {
    static let shared = SpotlightService()
    private init() {}

    private let domainIdentifier = "app.VedaAI.conversations"

    // MARK: - Index a conversation
    func index(conversationID: String, title: String, preview: String) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = title
        attributeSet.contentDescription = preview
        attributeSet.keywords = ["Veda", "AI", "conversation", "chat"]
        attributeSet.thumbnailData = UIImage(systemName: "sparkles")?.pngData()

        let item = CSSearchableItem(
            uniqueIdentifier: conversationID,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
        // Expire after 30 days
        item.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error { print("❌ Spotlight index error: \(error)") }
        }
    }

    // MARK: - Remove a specific conversation
    func remove(conversationID: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [conversationID]) { error in
            if let error { print("❌ Spotlight remove error: \(error)") }
        }
    }

    // MARK: - Remove all Veda conversations
    func removeAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { _ in }
    }

    // MARK: - Handle Spotlight tap (called from SceneDelegate / onContinueUserActivity)
    // Returns the conversation ID if the activity was a Spotlight tap.
    static func conversationID(from userActivity: NSUserActivity) -> String? {
        guard userActivity.activityType == CSSearchableItemActionType else { return nil }
        return userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String
    }
}
