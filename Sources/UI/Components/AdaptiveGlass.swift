import SwiftUI

// MARK: - Adaptive Glass Modifier

/// ViewModifier that applies Apple's Liquid Glass effect on macOS 26+,
/// falling back to ultraThinMaterial on earlier versions.
/// Uses a sharp rectangular shape with minimal corner softening.
struct AdaptiveGlassModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Applies Liquid Glass on macOS 26+, ultraThinMaterial fallback otherwise.
    /// Default cornerRadius is 2 for a sharp, rectangular appearance.
    @ViewBuilder
    func adaptiveGlass(cornerRadius: CGFloat = 2) -> some View {
        modifier(AdaptiveGlassModifier(cornerRadius: cornerRadius))
    }
}
