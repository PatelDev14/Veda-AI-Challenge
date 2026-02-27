import SwiftUI
import CoreSpotlight

@main
struct VedaApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ChatView()
            }
            .onOpenURL { url in
                // Parse vedaai://ask?q=...
                guard url.scheme == "vedaai",
                      url.host == "ask",
                      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let q = components.queryItems?.first(where: { $0.name == "q" })?.value
                else { return }
                // Post a notification that ChatView listens to
                NotificationCenter.default.post( //Notification.Name is in Message.swift
                    name: .vedaDeepLink,
                    object: nil,
                    userInfo: ["question": q]
                )
            }
            .onContinueUserActivity(CSSearchableItemActionType) { activity in
                if let id = SpotlightService.conversationID(from: activity) {
                    // Post notification with the id, ChatView restores that conversation
                    NotificationCenter.default.post(
                        name: .vedaSpotlightOpen,
                        object: nil,
                        userInfo: ["id": id]
                    )
                }
            }
        }
    }
}

// MARK: - Fallback for iOS < 17
//struct UnsupportedView: View {
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//            VStack(spacing: 16) {
//                Image(systemName: "exclamationmark.triangle.fill")
//                    .font(.system(size: 44))
//                    .foregroundStyle(.orange)
//                Text("iOS 17 or later required")
//                    .font(.system(size: 18, weight: .semibold, design: .rounded))
//                    .foregroundStyle(.white)
//                Text("Please update your device to use Veda.")
//                    .font(.system(size: 14))
//                    .foregroundStyle(.white.opacity(0.4))
//                    .multilineTextAlignment(.center)
//            }
//            .padding(40)
//        }
//    }
//}
