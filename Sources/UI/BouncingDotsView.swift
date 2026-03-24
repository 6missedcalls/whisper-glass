import SwiftUI

// MARK: - Bouncing Dots Animation

/// Three bouncing dots that convey a processing/transcribing state.
/// Each dot bounces upward with a staggered delay for a ripple effect.
public struct BouncingDotsView: View {

    // MARK: - Constants

    private enum Layout {
        static let dotCount = 3
        static let dotDiameter: CGFloat = 5
        static let bounceOffset: CGFloat = -4
        static let spacing: CGFloat = 3
        static let animationDuration: Double = 0.4
        static let dotOpacity: Double = 0.5
        /// Staggered delay per dot index.
        static let delays: [Double] = [0, 0.15, 0.3]
    }

    // MARK: - State

    @State private var isAnimating = false

    // MARK: - Body

    public var body: some View {
        HStack(spacing: Layout.spacing) {
            ForEach(0..<Layout.dotCount, id: \.self) { index in
                dot(delay: Layout.delays[index])
            }
        }
        .onAppear {
            isAnimating = true
        }
    }

    // MARK: - Subviews

    private func dot(delay: Double) -> some View {
        Circle()
            .fill(Color.primary.opacity(Layout.dotOpacity))
            .frame(width: Layout.dotDiameter, height: Layout.dotDiameter)
            .offset(y: isAnimating ? Layout.bounceOffset : 0)
            .animation(
                .easeInOut(duration: Layout.animationDuration)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isAnimating
            )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    BouncingDotsView()
        .padding()
        .frame(width: 60, height: 30)
}
#endif
