import SwiftUI

/// Centralized design tokens for Veda's visual identity.
enum VedaTheme {
    // MARK: - Colors
    static let accent      = Color.orange
    static let accentSoft  = Color.orange.opacity(0.7)
    static let secondary   = Color.indigo
    static let gold        = Color.yellow.opacity(0.75)
    static let surface     = Color.white.opacity(0.05)
    static let textPrimary = Color.white.opacity(0.95)
    static let textMuted   = Color.white.opacity(0.4)

    // MARK: - Gradients
    static var titleGradient: LinearGradient {
        LinearGradient(
            colors: [accent, gold],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var headerBackground: LinearGradient {
        LinearGradient(
            colors: [Color.black.opacity(0.8), secondary.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Shape
    static let bubbleRadius: CGFloat  = 22
    static let cardRadius: CGFloat    = 16
    static let buttonRadius: CGFloat  = 14

    // MARK: - Spacing
    static let horizontalPadding: CGFloat = 18
    static let verticalPadding: CGFloat   = 14
}
