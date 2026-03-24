import SwiftUI

// MARK: - Waveform Animation

/// Animated waveform bars for the recording state.
/// Five vertical bars animate with staggered sinusoidal timing
/// to convey active audio capture.
public struct WaveformAnimation: View {

    // MARK: - Constants

    private enum Layout {
        static let barCount = 5
        static let barWidth: CGFloat = 3.5
        static let barCornerRadius: CGFloat = 1.75
        static let minBarHeight: CGFloat = 5
        static let maxBarHeight: CGFloat = 18
        static let spacing: CGFloat = 2.5
        static let totalHeight: CGFloat = 22
        static let animationDuration: Double = 0.5
        static let barOpacity: Double = 0.6
        /// Staggered delay per bar index for natural wave motion.
        static let delays: [Double] = [0, 0.1, 0.2, 0.1, 0]
    }

    // MARK: - State

    @State private var isAnimating = false

    // MARK: - Body

    public var body: some View {
        HStack(spacing: Layout.spacing) {
            ForEach(0..<Layout.barCount, id: \.self) { index in
                bar(delay: Layout.delays[index])
            }
        }
        .frame(height: Layout.totalHeight)
        .onAppear {
            isAnimating = true
        }
    }

    // MARK: - Subviews

    private func bar(delay: Double) -> some View {
        RoundedRectangle(cornerRadius: Layout.barCornerRadius)
            .fill(Color.primary.opacity(Layout.barOpacity))
            .frame(
                width: Layout.barWidth,
                height: isAnimating ? Layout.maxBarHeight : Layout.minBarHeight
            )
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
    WaveformAnimation()
        .padding()
        .frame(width: 60, height: 40)
}
#endif
