import SwiftUI

// MARK: - Pulsing Recording Indicator

/// Circular indicator that pulses when recording is active.
public struct PulsingIndicator: View {
    private let isRecording: Bool

    @State private var isPulsing = false

    public init(isRecording: Bool) {
        self.isRecording = isRecording
    }

    public var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: 12, height: 12)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .animation(pulseAnimation, value: isPulsing)
            .onChange(of: isRecording) { _, newValue in
                isPulsing = newValue
            }
            .onAppear {
                isPulsing = isRecording
            }
    }

    private var fillColor: Color {
        isRecording ? .red : .gray
    }

    private var pulseAnimation: Animation? {
        guard isRecording else { return .default }
        return .easeInOut(duration: 1.0)
            .repeatForever(autoreverses: true)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    HStack(spacing: 20) {
        PulsingIndicator(isRecording: false)
        PulsingIndicator(isRecording: true)
    }
    .padding()
}
#endif
