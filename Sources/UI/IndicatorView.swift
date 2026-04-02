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

// MARK: - Observable State Holder

/// Shared observable state for the indicator panel.
/// Using @Observable avoids replacing the NSHostingView's rootView
/// (which triggers a constraint invalidation crash on off-screen windows).
@Observable
public final class IndicatorStateHolder {
    public var current: IndicatorState = .hidden

    public init(_ initial: IndicatorState = .hidden) {
        self.current = initial
    }
}

// MARK: - Indicator View

/// SwiftUI pill that shows the current recording/transcription state.
/// Displays an animated icon alongside a text label inside a
/// capsule-shaped glass container.
public struct IndicatorView: View {

    // MARK: - Constants

    private enum Layout {
        static let pillWidth: CGFloat = 180
        static let pillHeight: CGFloat = 40
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 10
        static let iconLabelSpacing: CGFloat = 8
        static let fontSize: CGFloat = 13
    }

    // MARK: - Properties

    private let stateHolder: IndicatorStateHolder

    public init(stateHolder: IndicatorStateHolder) {
        self.stateHolder = stateHolder
    }

    // MARK: - Body

    public var body: some View {
        pillContent
            .opacity(stateHolder.current == .hidden ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: stateHolder.current)
    }

    // MARK: - Subviews

    private var pillContent: some View {
        HStack(spacing: Layout.iconLabelSpacing) {
            stateIcon
                .frame(width: 20, height: 16)
            Text(displayLabel)
                .font(.system(size: Layout.fontSize, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .frame(width: Layout.pillWidth, height: Layout.pillHeight)
        .adaptiveGlassCapsule()
    }

    private var displayLabel: String {
        switch stateHolder.current {
        case .recording: "Listening..."
        case .transcribing: "Transcribing..."
        case .done: "Done"
        case .hidden: "Listening..."
        }
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch stateHolder.current {
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
    IndicatorView(stateHolder: IndicatorStateHolder(.recording))
        .padding()
}

#Preview("Transcribing") {
    IndicatorView(stateHolder: IndicatorStateHolder(.transcribing))
        .padding()
}

#Preview("Done") {
    IndicatorView(stateHolder: IndicatorStateHolder(.done))
        .padding()
}
#endif
