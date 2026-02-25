import SwiftUI

@main
struct VedaApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ChatView()
            }
        }
    }
}

// MARK: - Fallback for iOS < 17
struct UnsupportedView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)
                Text("iOS 17 or later required")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Please update your device to use Veda.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(40)
        }
    }
}
