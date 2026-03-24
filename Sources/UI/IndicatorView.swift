import SwiftUI

// MARK: - Indicator State

/// Visual states for the floating recording indicator.
public enum IndicatorState: Equatable, Sendable {
    /// Microphone is active, waveform bars animate
    case recording
    /// Audio is being processed, bouncing dots animate
    case transcribing
    /// Transcription completed successfully
    case done
    /// Indicator is not visible
    case hidden

    var label: String {
        switch self {
        case .recording: "Listening..."
        case .transcribing: "Transcribing..."
        case .done: "Done"
        case .hidden: ""
        }
    }
}

// MARK: - Indicator View

/// SwiftUI pill that shows the current recording/transcription state.
/// Displays an animated icon alongside a text label inside a
/// capsule-shaped glass container.
public struct IndicatorView: View {

    // MARK: - Constants

    private enum Layout {
        static let pillHeight: CGFloat = 40
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 10
        static let iconLabelSpacing: CGFloat = 8
        static let fontSize: CGFloat = 13
    }

    // MARK: - Properties

    private let state: IndicatorState

    public init(state: IndicatorState) {
        self.state = state
    }

    // MARK: - Body

    public var body: some View {
        if state != .hidden {
            pillContent
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.8)
                            .combined(with: .opacity),
                        removal: .opacity
                    )
                )
        }
    }

    // MARK: - Subviews

    private var pillContent: some View {
        HStack(spacing: Layout.iconLabelSpacing) {
            stateIcon
            Text(state.label)
                .font(.system(size: Layout.fontSize, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .frame(height: Layout.pillHeight)
        .adaptiveGlassCapsule()
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .recording:
            WaveformAnimation()
        case .transcribing:
            BouncingDotsView()
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: Layout.fontSize, weight: .medium))
                .foregroundStyle(.green)
        case .hidden:
            EmptyView()
        }
    }
}

// MARK: - Adaptive Glass Capsule Modifier

/// Applies Liquid Glass capsule on macOS 26+, ultraThinMaterial fallback.
private struct AdaptiveGlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }
}

private extension View {
    func adaptiveGlassCapsule() -> some View {
        modifier(AdaptiveGlassCapsuleModifier())
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Recording") {
    IndicatorView(state: .recording)
        .padding()
}

#Preview("Transcribing") {
    IndicatorView(state: .transcribing)
        .padding()
}

#Preview("Done") {
    IndicatorView(state: .done)
        .padding()
}
#endif
