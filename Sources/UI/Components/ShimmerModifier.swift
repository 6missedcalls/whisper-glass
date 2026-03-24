import SwiftUI

// MARK: - Shimmer Effect Modifier

/// A subtle shimmer highlight that animates across a view on hover.
struct ShimmerModifier: ViewModifier {
    @State private var isHovered = false
    @State private var animationOffset: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(shimmerOverlay)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    animationOffset = -1.0
                    withAnimation(
                        .easeInOut(duration: 0.8)
                    ) {
                        animationOffset = 2.0
                    }
                }
            }
    }

    @ViewBuilder
    private var shimmerOverlay: some View {
        if isHovered {
            GeometryReader { geometry in
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.08),
                        .white.opacity(0.12),
                        .white.opacity(0.08),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 0.4)
                .offset(x: geometry.size.width * animationOffset)
                .clipped()
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Adds a subtle shimmer highlight effect on hover.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    Text("Hover over me")
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shimmer()
        .padding()
}
#endif
